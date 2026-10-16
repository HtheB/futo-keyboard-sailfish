#include <QGuiApplication>
#include <QQuickView>
#include <QScopedPointer>
#include <QQmlContext>
#include <QVariant>
#include <sailfishapp.h>

int main(int argc, char **argv)
{
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
    app->setApplicationName(QStringLiteral("futo-layout-editor"));
    app->setOrganizationName(QStringLiteral("HtheB"));
    QScopedPointer<QQuickView> view(SailfishApp::createView());
    view->rootContext()->setContextProperty(QStringLiteral("layoutEditorProcessId"), QVariant::fromValue(QCoreApplication::applicationPid()));
    view->setSource(QUrl(QStringLiteral("file:///usr/share/futo-keyboard-sailfish/editor/main.qml")));
    if (view->status() == QQuickView::Error) return 1;
    view->show();
    return app->exec();
}
