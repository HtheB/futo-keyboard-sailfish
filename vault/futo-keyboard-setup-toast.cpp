// Short-lived, non-interactive setup feedback across the AppSupport handoff.
// This ordinary user process does not authenticate or handle any vault data.
#include <QtCore/QTimer>
#include <QtGui/QGuiApplication>
#include <QtGui/QRegion>
#include <QtGui/QScreen>
#include <QtGui/qpa/qplatformnativeinterface.h>
#include <QtQml/QQmlComponent>
#include <QtQuick/QQuickItem>
#include <QtQuick/QQuickView>

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("futo-keyboard-setup-toast"));
    QQuickView view;
    view.setColor(Qt::transparent);
    view.setFlags(Qt::ToolTip | Qt::FramelessWindowHint
                  | Qt::WindowDoesNotAcceptFocus | Qt::WindowTransparentForInput);
    QQmlComponent component(view.engine());
    component.setData(R"QML(
import QtQuick 2.6
import Sailfish.Silica 1.0
Item {
    width: Screen.width
    height: Screen.height
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.itemSizeLarge
        width: parent.width - 2 * Theme.horizontalPageMargin
        height: message.height + 2 * Theme.paddingLarge
        radius: Theme.paddingMedium
        color: Theme.highlightDimmerColor
        Label {
            id: message
            x: Theme.paddingLarge
            y: Theme.paddingLarge
            width: parent.width - 2 * x
            text: qsTr("Select FUTO Autofill in Android's autofill settings.")
            color: Theme.primaryColor
            font.pixelSize: Theme.fontSizeSmall
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
    }
}
)QML", QUrl());
    QObject *content = component.create();
    if (!content) return 2;
    view.setContent(QUrl(), &component, content);
    const QRect screen = app.primaryScreen()->geometry();
    view.setGeometry(screen);
    view.create();
    // A nonempty region outside the surface becomes an empty Wayland input
    // region. An empty QRegion would instead restore the default input area.
    view.setMask(QRegion(-1, -1, 1, 1));
    auto *native = QGuiApplication::platformNativeInterface();
    if (!native || !view.handle()) return 2;
    native->setWindowProperty(view.handle(), QStringLiteral("CATEGORY"), QStringLiteral("overlay"));
    native->setWindowProperty(view.handle(), QStringLiteral("BACKGROUND_VISIBLE"), false);
    native->setWindowProperty(view.handle(), QStringLiteral("TRANSPARENT"), true);
    view.show();
    QTimer::singleShot(15000, &app, &QCoreApplication::quit);
    return app.exec();
}
