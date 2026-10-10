/* Private, event-driven editor access; no polling or clipboard use. */
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include "futo_credential_editor.h"
#include "futo_browser_script.h"
#include <QCoreApplication>
#include <QGuiApplication>
#include <QWindow>
#include <QFile>
#include <QJsonDocument>
#include <QSocketNotifier>
#include <QTimer>
#include <QInputMethod>
#include <QInputMethodEvent>
#include <QInputMethodQueryEvent>
#include <QUrl>
#include <qpa/qwindowsysteminterface.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>
#include <cstring>

static bool trustedPeer(int descriptor)
{
    struct ucred peer;
    socklen_t length = sizeof(peer);
    if (getsockopt(descriptor, SOL_SOCKET, SO_PEERCRED, &peer, &length) != 0
            || length != sizeof(peer))
        return false;
    // The packaged setuid broker connects before dropping its privilege.
    // This also works when the browser cannot see the helper's host PID in
    // its Sailjail PID namespace. Root already controls the editor process.
    if (peer.uid == 0) return true;
    if (peer.uid != getuid()) return false;
    const QByteArray path = "/proc/" + QByteArray::number(peer.pid) + "/exe";
    char resolved[4096];
    const ssize_t count = readlink(path.constData(), resolved, sizeof(resolved) - 1);
    if (count <= 0) return false;
    resolved[count] = '\0';
    const char *helper = "/usr/libexec/futo-keyboard-helper";
    struct stat actual, expected;
    return std::strcmp(resolved, helper) == 0
            && stat(path.constData(), &actual) == 0 && stat(helper, &expected) == 0
            && actual.st_dev == expected.st_dev && actual.st_ino == expected.st_ino;
}

FutoCredentialEditor::FutoCredentialEditor(QObject *parent) : QObject(parent)
{
    // Lipstick and the keyboard must never expose an editor endpoint.
    const QString executable = QCoreApplication::applicationFilePath();
    if (executable.endsWith("/lipstick") || executable.endsWith("/maliit-server"))
        return;
    const QByteArray directory = qgetenv("XDG_RUNTIME_DIR");
    struct stat status;
    if (directory.isEmpty() || stat(directory.constData(), &status) != 0
            || !S_ISDIR(status.st_mode) || status.st_uid != getuid()
            || (status.st_mode & 0077) != 0)
        return;
    m_path = directory + "/futo-editor-" + QByteArray::number(getpid());
    struct sockaddr_un address;
    std::memset(&address, 0, sizeof(address));
    address.sun_family = AF_UNIX;
    if (m_path.size() >= int(sizeof(address.sun_path))) return;
    std::memcpy(address.sun_path, m_path.constData(), m_path.size() + 1);
    m_listener = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC | SOCK_NONBLOCK, 0);
    if (m_listener < 0) return;
    unlink(m_path.constData());
    if (bind(m_listener, reinterpret_cast<sockaddr *>(&address), sizeof(address)) != 0
            || chmod(m_path.constData(), 0600) != 0 || listen(m_listener, 1) != 0) {
        close(m_listener);
        m_listener = -1;
        unlink(m_path.constData());
        return;
    }
    m_accept = new QSocketNotifier(m_listener, QSocketNotifier::Read, this);
    connect(m_accept, &QSocketNotifier::activated, this,
            [this](int) { acceptConnection(); });
    m_timeout = new QTimer(this);
    m_timeout->setSingleShot(true);
    connect(m_timeout, &QTimer::timeout, this, [this]() { closeConnection(); });
}

FutoCredentialEditor::~FutoCredentialEditor()
{
    closeConnection();
    if (m_listener >= 0) close(m_listener);
    if (!m_path.isEmpty()) unlink(m_path.constData());
}

void FutoCredentialEditor::setFocusObject(QObject *object) { m_focus = object; }

void FutoCredentialEditor::acceptConnection()
{
    const int descriptor = accept4(m_listener, nullptr, nullptr,
                                   SOCK_CLOEXEC | SOCK_NONBLOCK);
    if (descriptor < 0) return;
    if (m_client >= 0 || !trustedPeer(descriptor)) {
        close(descriptor);
        return;
    }
    m_client = descriptor;
    m_request.clear();
    m_read = new QSocketNotifier(m_client, QSocketNotifier::Read, this);
    connect(m_read, &QSocketNotifier::activated, this, [this](int) { readRequest(); });
    m_timeout->start(1800);
}

void FutoCredentialEditor::readRequest()
{
    char buffer[4096];
    ssize_t count;
    while ((count = recv(m_client, buffer, sizeof(buffer), 0)) > 0) {
        m_request.append(buffer, int(count));
        if (m_request.size() > 32768) { closeConnection(); return; }
        if (m_request.contains('\n')) {
            m_read->setEnabled(false);
            QJsonParseError error;
            const QJsonDocument document = QJsonDocument::fromJson(m_request.trimmed(), &error);
            m_request.fill('\0');
            m_request.clear();
            if (error.error != QJsonParseError::NoError || !document.isObject()) {
                closeConnection();
                return;
            }
            dispatch(document.object());
            return;
        }
    }
    if (count == 0 || (errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR))
        closeConnection();
}

void FutoCredentialEditor::closeConnection()
{
    ++m_serial;
    if (m_timeout) m_timeout->stop();
    if (m_read) { m_read->setEnabled(false); m_read->deleteLater(); m_read = nullptr; }
    if (m_client >= 0) close(m_client);
    m_client = -1;
    m_browser.clear();
    m_browserOrigin.clear();
    m_request.fill('\0');
    m_request.clear();
}

void FutoCredentialEditor::respond(const QJsonObject &result)
{
    if (m_client < 0) return;
    const QByteArray bytes = QJsonDocument(result).toJson(QJsonDocument::Compact) + '\n';
    // Responses contain metadata only and fit in the local socket buffer.
    send(m_client, bytes.constData(), size_t(bytes.size()), MSG_NOSIGNAL);
    closeConnection();
}

QObject *FutoCredentialEditor::browserPage() const
{
    if (m_focus && m_focus->inherits("QMozOpenGLWebPage")) return m_focus;
    {
        for (QWindow *window : QGuiApplication::allWindows()) {
            if (!window->inherits("DeclarativeWebContainer")
                    || !window->property("foreground").toBool()) continue;
            QObject *page = window->property("contentItem").value<QObject *>();
            if (page && page->inherits("QMozOpenGLWebPage")) return page;
        }
    }
    return nullptr;
}

bool FutoCredentialEditor::runBrowserRequest(QObject *page, const QJsonObject &request)
{
    const QUrl url(page->property("url").toString());
    if (!page->property("privateMode").isValid()
            || page->property("privateMode").toBool()
            || (url.scheme() != "http" && url.scheme() != "https")
            || !url.userName().isEmpty() || url.host().isEmpty()) return false;
    const QString origin = url.scheme().toLower() + "://" + url.host().toLower()
            + (url.port() >= 0 ? ":" + QString::number(url.port()) : QString());
    if (request.value("operation").toString() != "context"
            && request.value("origin").toString().toLower() != origin) return false;
    m_browser = page;
    m_browserOrigin = origin;
    if (!m_engine) {
        m_engine.reset(new QJSEngine);
        m_engine->globalObject().setProperty("editor", m_engine->newQObject(this));
    }
    // Sailjail deliberately hides other applications' data directories. Keep
    // this fixed adapter in the signed-in-process plugin, not a readable file.
    const QString source = QStringLiteral("return (")
            + QString::fromUtf8(futoBrowserCredentialScript) + QStringLiteral("\n)(")
            + QString::fromUtf8(QJsonDocument(request).toJson(QJsonDocument::Compact)) + ")";
    const int serial = ++m_serial;
    const QJSValue callback = m_engine->evaluate(QStringLiteral(
                "(function(result) { editor.browserReply(%1, typeof result === 'string'"
                " ? result : JSON.stringify(result)); })").arg(serial));
    const QJSValue failed = m_engine->evaluate(QStringLiteral(
                "(function() { editor.browserReply(%1, '{\"reason\":\"script\"}'); })").arg(serial));
    return QMetaObject::invokeMethod(page, "runJavaScript", Qt::DirectConnection,
                                    Q_ARG(QString, source), Q_ARG(QJSValue, callback),
                                    Q_ARG(QJSValue, failed));
}

void FutoCredentialEditor::browserReply(int serial, const QString &result)
{
    if (serial != m_serial || m_client < 0 || result.size() > 16384) return;
    const QJsonDocument document = QJsonDocument::fromJson(result.toUtf8());
    const QJsonObject response = document.object();
    const QUrl url(m_browser ? m_browser->property("url").toString() : QString());
    const QString origin = url.scheme().toLower() + "://" + url.host().toLower()
            + (url.port() >= 0 ? ":" + QString::number(url.port()) : QString());
    if (document.isObject() && m_browser && origin == m_browserOrigin
            && response.value("origin").toString() == origin
            && response.value("restored").toBool()) {
        const QPointer<QObject> page = m_browser;
        const QString expectedOrigin = m_browserOrigin;
        // DOM focus can be restored before Gecko renews the Qt input context.
        // Refresh that context once, after its focus event has been delivered.
        QTimer::singleShot(150, this, [page, expectedOrigin]() {
            if (!page || page->property("privateMode").toBool()
                    || QGuiApplication::applicationState() != Qt::ApplicationActive) return;
            const QUrl currentUrl(page->property("url").toString());
            const QString currentOrigin = currentUrl.scheme().toLower() + "://"
                    + currentUrl.host().toLower()
                    + (currentUrl.port() >= 0 ? ":" + QString::number(currentUrl.port()) : QString());
            if (currentOrigin != expectedOrigin) return;
            QWindow *foreground = nullptr;
            for (QWindow *window : QGuiApplication::allWindows()) {
                if (window->inherits("DeclarativeWebContainer")
                        && window->property("foreground").toBool()
                        && window->property("contentItem").value<QObject *>() == page)
                    foreground = window;
            }
            if (!foreground) return;
            foreground->requestActivate();
            // Sailfish Browser renders its chrome and page in separate Qt
            // windows. The authorization overlay can return focus to chrome
            // even though the compositor already considers the page active.
            // Renew Qt's page-window focus only for this foreground form.
            QWindowSystemInterface::handleWindowActivated(foreground);
            if (page->metaObject()->indexOfMethod("forceActiveFocus()") >= 0)
                QMetaObject::invokeMethod(page, "forceActiveFocus", Qt::DirectConnection);
            QGuiApplication::inputMethod()->update(Qt::ImQueryAll);
            QGuiApplication::inputMethod()->show();
        });
    }
    QJsonObject unavailable;
    unavailable.insert("reason", response.value("reason").toString().isEmpty()
                       ? (!document.isObject() ? QStringLiteral("invalid-json")
                          : QStringLiteral("wrong-origin")) : response.value("reason").toString());
    respond(document.isObject() && m_browser && !m_browser->property("privateMode").toBool()
            && origin == m_browserOrigin && response.value("origin").toString() == origin
            ? response : unavailable);
}

void FutoCredentialEditor::dispatch(const QJsonObject &request)
{
    const QString operation = request.value("operation").toString();
    if (operation != "context" && operation != "restore" && operation != "fill") {
        respond(QJsonObject());
        return;
    }
    QObject *page = browserPage();
    if (page) {
        // Never resolve a private tab from a previously persisted normal tab.
        if (page->property("privateMode").toBool()
                || !runBrowserRequest(page, request)) {
            QJsonObject unavailable;
            unavailable.insert("reason", QStringLiteral("page"));
            respond(unavailable);
        }
        return;
    }
    // A custom native editor must report its own text range before replacement
    // can be safe. Browsers are handled atomically through their form adapter.
    if (!m_focus || QGuiApplication::applicationState() != Qt::ApplicationActive) {
        respond(QJsonObject());
        return;
    }
    QInputMethodQueryEvent query(Qt::ImEnabled | Qt::ImHints | Qt::ImSurroundingText
                                | Qt::ImCursorPosition);
    QCoreApplication::sendEvent(m_focus, &query);
    const bool enabled = query.value(Qt::ImEnabled).toBool();
    const int hints = query.value(Qt::ImHints).toInt();
    QJsonObject result;
    result.insert("available", enabled);
    result.insert("password", bool(hints & Qt::ImhHiddenText));
    result.insert("field", QString::number(quintptr(m_focus.data()), 16));
    if (operation == "context") { respond(result); return; }
    if (!enabled || result.value("field").toString() != request.value("field").toString()) {
        respond(QJsonObject());
        return;
    }
    if (operation == "restore") {
        QGuiApplication::inputMethod()->show();
        result.insert("restored", true);
    } else if (request.value("password").toBool() == bool(hints & Qt::ImhHiddenText)
               && query.value(Qt::ImSurroundingText).isValid()
               && query.value(Qt::ImCursorPosition).isValid()) {
        const QString text = query.value(Qt::ImSurroundingText).toString();
        const int cursor = query.value(Qt::ImCursorPosition).toInt();
        if (cursor >= 0 && cursor <= text.size()) {
            QInputMethodEvent event;
            event.setCommitString(request.value("value").toString(), -cursor, text.size());
            QCoreApplication::sendEvent(m_focus, &event);
            result.insert("filled", event.isAccepted());
        }
    }
    respond(result);
}
