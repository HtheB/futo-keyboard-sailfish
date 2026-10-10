// Request Sailfish device authentication in a system overlay, not an app card.
// This set-group-ID bridge returns only success/failure, never codes or keys.
#include <QtCore/QCoreApplication>
#include <QtCore/QTimer>
#include <QtCore/QLocale>
#include <QtCore/QTranslator>
#include <QtGui/QGuiApplication>
#include <QtQml/QQmlComponent>
#include <QtQml/QQmlContext>
#include <QtQml/QQmlEngine>

#include <cstdio>
#include <cstdlib>
#include <grp.h>
#include <limits.h>
#include <pwd.h>
#include <sys/prctl.h>
#include <sys/stat.h>
#include <unistd.h>

#ifndef FUTO_QT_DIRECTORY
#define FUTO_QT_DIRECTORY "/usr/lib64/qt5"
#endif

static bool trustedParent()
{
    const gid_t elevatedGroup = getegid();
    const group *privileged = getgrnam("privileged");
    if (getuid() == 0 || geteuid() != getuid() || !privileged
            || elevatedGroup != privileged->gr_gid || elevatedGroup == getgid())
        return false;
    // Temporarily use the parent's normal credentials for /proc inspection.
    if (setegid(getgid()) != 0)
        return false;
    char path[64], target[PATH_MAX + 1];
    std::snprintf(path, sizeof(path), "/proc/%ld/exe", long(getppid()));
    const ssize_t length = readlink(path, target, PATH_MAX);
    if (length >= 0) target[length] = '\0';
    const char *expected = "/usr/libexec/futo-keyboard-helper";
    struct stat parentInfo, packagedInfo;
    const bool trusted = length > 0 && QByteArray(target, int(length)) == expected
            && stat(path, &parentInfo) == 0 && stat(expected, &packagedInfo) == 0
            && parentInfo.st_dev == packagedInfo.st_dev
            && parentInfo.st_ino == packagedInfo.st_ino
            && packagedInfo.st_uid == 0 && !(packagedInfo.st_mode & 0022);
    return setegid(elevatedGroup) == 0 && trusted;
}

static bool trustedFile(const char *path)
{
    struct stat info;
    return stat(path, &info) == 0 && S_ISREG(info.st_mode)
            && info.st_uid == 0 && !(info.st_mode & 0022);
}

static bool configureSession()
{
    const passwd *user = getpwuid(getuid());
    if (!user || !user->pw_dir || user->pw_dir[0] != '/') return false;
    const QByteArray home(user->pw_dir);
    // QLocale canonicalizes the locale; no environment-provided filename is used.
    const QByteArray locale = QLocale::system().name().toLatin1() + ".UTF-8";
    char runtime[64], bus[128];
    std::snprintf(runtime, sizeof(runtime), "/run/user/%lu", (unsigned long)getuid());
    struct stat info;
    if (lstat(runtime, &info) != 0 || !S_ISDIR(info.st_mode)
            || info.st_uid != getuid() || (info.st_mode & 0022)) return false;
    std::snprintf(bus, sizeof(bus), "unix:path=%s/dbus/user_bus_socket", runtime);
    clearenv();
    // Reconstruct only the fixed session endpoints and required Qt settings.
    // In particular, never inherit user-supplied plugin/import/preload paths.
    return setenv("HOME", home.constData(), 1) == 0
            && setenv("LANG", locale.constData(), 1) == 0
            && setenv("XDG_RUNTIME_DIR", runtime, 1) == 0
            && setenv("DBUS_SESSION_BUS_ADDRESS", bus, 1) == 0
            && setenv("WAYLAND_DISPLAY", "/run/display/wayland-0", 1) == 0
            && setenv("QT_QPA_PLATFORM", "wayland", 1) == 0
            && setenv("QT_QPA_PLATFORM_PLUGIN_PATH", FUTO_QT_DIRECTORY "/plugins", 1) == 0
            && setenv("QT_IM_MODULE", "Maliit", 1) == 0
            && setenv("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1", 1) == 0
            && setenv("QML_DISABLE_DISK_CACHE", "1", 1) == 0;
}

int main(int argc, char **argv)
{
    const bool useLogin = argc == 2 && QByteArray(argv[1]) == "--use-login";
    if ((argc != 1 && !useLogin) || !trustedParent()) {
        std::fputs("Device authentication: untrusted caller\n", stderr);
        return 77;
    }
    // No user-controlled import/plugin paths or Qt settings may run with the
    // privileged group. The dynamic loader already applies secure-exec rules.
    if (!configureSession()) return 2;
    prctl(PR_SET_DUMPABLE, 0);
    const pid_t helperPid = getppid();
    QCoreApplication::setLibraryPaths({QStringLiteral(FUTO_QT_DIRECTORY "/plugins")});
    QGuiApplication app(argc, argv);
    app.setQuitOnLastWindowClosed(false);
    app.setApplicationName(QStringLiteral("futo-keyboard-device-auth"));
    QTranslator settingsStrings, systemStrings, silicaStrings;
    const struct { QTranslator *translator; const char *prefix; } translations[] = {
        {&settingsStrings, "settings"}, {&systemStrings, "qml_plugin_systemsettings"},
        {&silicaStrings, "sailfishsilica-qt5"}
    };
    for (const auto &entry : translations) {
        if (entry.translator->load(QLocale::system(), QString::fromLatin1(entry.prefix),
                              QStringLiteral("-"), QStringLiteral("/usr/share/translations")))
            app.installTranslator(entry.translator);
    }
    QQmlEngine engine;
    engine.setImportPathList({QStringLiteral(FUTO_QT_DIRECTORY "/qml")});
    engine.rootContext()->setContextProperty(QStringLiteral("authenticationPid"), int(getpid()));
    engine.rootContext()->setContextProperty(QStringLiteral("authenticationMessage"),
        useLogin ? QStringLiteral("Use a saved FUTO login")
                 : QStringLiteral("Save this login in FUTO Keyboard"));
    QObject::connect(&engine, &QQmlEngine::quit, &app, &QCoreApplication::quit);
    QQmlComponent component(&engine);
    QByteArray qml(R"QML(
import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Lipstick 1.0
import com.jolla.settings.system 1.0
import org.nemomobile.devicelock 1.0
SystemDialog {
    id: request
    property bool started: false
    property bool granted: false
    property bool inputConfirmed: false
    property bool finishing: false
    readonly property var pageStack: __silica_applicationwindow_instance.pageStack
    readonly property var palette: __silica_applicationwindow_instance.palette
    title: "FUTO Keyboard"
    contentHeight: screenHeight
    autoDismiss: false
    onDismissed: cancel()
    onClosed: if (!finishing) cancel()

    function finish() {
        if (finishing) return
        finishing = true
        close()
        Qt.quit()
    }
    function tryFinish() {
        if (granted && inputConfirmed) finish()
    }
    Authenticator {
        id: authenticator
        onPermissionGranted: {
            request.granted = method === Authenticator.SecurityCode
                           || method === Authenticator.Fingerprint
            if (request.granted) request.tryFinish()
            else request.cancel()
        }
        onAborted: request.cancel()
    }
    AuthenticationInput {
        id: authentication
        signal reset()
        registered: request.started && !request.finishing
        active: registered
        onAuthenticationStarted: {
            // This temporary input must never display or approve another
            // process's authentication request.
            if (authentication.authenticatingProcess !== authenticationPid) {
                request.cancel()
                return
            }
            reset()
            authentication.feedback(feedback, data)
            request.activate()
            unlockInput.forceActiveFocus()
            // A transparent Android autofill editor may still have its IME
            // open. The pattern grid/native keypad must own the whole screen.
            if (typeof unlockInput.usePattern !== "undefined"
                    && (unlockInput.usePattern || unlockInput._showKeypad))
                Qt.inputMethod.hide()
        }
        onAuthenticationUnavailable: request.cancel()
        onAuthenticationEnded: {
            reset()
            if (confirmed) {
                request.inputConfirmed = true
                request.tryFinish()
            } else request.cancel()
        }
    }
    Timer {
        id: dispatch
        interval: 100
        onTriggered: authenticator.requestPermission(authenticationMessage, {},
                         Authenticator.SecurityCode | Authenticator.Fingerprint)
    }
    function begin() {
        var methods = Authenticator.SecurityCode | Authenticator.Fingerprint
        if (!started && (authenticator.availableMethods & methods)) {
            started = true
            // Register our input before dispatching the challenge.
            dispatch.start()
        }
    }
    function cancel() {
        if (finishing) return
        granted = false
        dispatch.stop()
        authenticator.cancel()
        finish()
    }
    Item {
        width: parent.width
        height: request.screenHeight
        Rectangle { anchors.fill: parent; color: Theme.overlayBackgroundColor }
        __UNLOCK_INPUT__
    }
})QML");
    // Pattern Lock is an optional system component. Reuse it if installed;
    // its own configuration decides whether to show a pattern or the keypad.
    // Do not ship a private copy or modify the system-wide unlock components.
    const bool pattern = trustedFile(FUTO_QT_DIRECTORY "/qml/com/jolla/settings/system/PatternLockInput.qml");
    qml.replace("__UNLOCK_INPUT__", pattern ? R"QML(
        PatternLockInput {
            id: unlockInput
            anchors.fill: parent
            property alias securityCode: unlockInput.enteredPin
            property alias requireSecurityCode: unlockInput.requirePin
            property bool enteringNewCode: false
            property string descriptionText
            subTitleText: descriptionText
            minimumLength: enteringNewCode ? authentication.minimumCodeLength : 1
            maximumLength: authentication.maximumCodeLength
            busy: authentication.status === AuthenticationInput.Evaluating
            enabled: authentication.status !== AuthenticationInput.Idle && !busy
            showOkButton: authentication.status === AuthenticationInput.Authenticating
            showEmergencyButton: false
            digitInputOnly: false
            enableInputMethodChange: true
            passwordMaskDelay: 0
            pasteDisabled: true
            suggestionsEnforced: authentication.codeGeneration === AuthenticationInput.MandatoryCodeGeneration
            onEnteringNewCodeChanged: setPatternCodeChangeActive(enteringNewCode)
            onPinConfirmed: {
                if (authentication.status !== AuthenticationInput.Authenticating || feedbackHandler.submitted) return
                feedbackHandler.submitted = true
                authentication.enterSecurityCode(enteredPin)
            }
            onPinEntryCanceled: request.cancel()
            onSuggestionRequested: authentication.requestSecurityCode()
            function suggestSecurityCode(code) { suggestPin(code) }
            DeviceLockFeedback {
                id: feedbackHandler
                agent: authentication
                ui: unlockInput
            }
            Connections {
                target: authentication
                onReset: unlockInput.prepareForAuthentication()
            }
        }
    )QML" : R"QML(
        DeviceLockInput {
            id: unlockInput
            anchors.fill: parent
            authenticationInput: authentication
            showEmergencyButton: false
            pasteDisabled: true
        }
    )QML");
    component.setData(qml, QUrl());
    QObject *request = component.create();
    if (!request) {
        std::fputs("Device authentication is unavailable\n", stderr);
        return 2;
    }
    QTimer available;
    int attempts = 0;
    QObject::connect(&available, &QTimer::timeout, [&] {
        QMetaObject::invokeMethod(request, "begin");
        if (request->property("started").toBool()) available.stop();
        else if (++attempts >= 30) app.quit();
    });
    available.start(100);
    QTimer parentLifetime;
    QObject::connect(&parentLifetime, &QTimer::timeout, [&] {
        if (getppid() != helperPid) app.quit();
    });
    parentLifetime.start(1000);
    QTimer::singleShot(90000, &app, &QCoreApplication::quit);
    app.exec();
    const bool granted = request->property("granted").toBool()
            && request->property("inputConfirmed").toBool();
    const bool started = request->property("started").toBool();
    if (!granted) QMetaObject::invokeMethod(request, "cancel");
    delete request;
    return granted ? 0 : started ? 1 : 2;
}
