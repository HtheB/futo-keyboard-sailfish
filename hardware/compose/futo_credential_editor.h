/* Private native-editor channel. Only the packaged helper may connect. */
#ifndef FUTO_CREDENTIAL_EDITOR_H
#define FUTO_CREDENTIAL_EDITOR_H

#include <QObject>
#include <QPointer>
#include <QByteArray>
#include <QJsonObject>
#include <QJSEngine>
#include <QScopedPointer>

class QSocketNotifier;
class QTimer;

class FutoCredentialEditor : public QObject
{
    Q_OBJECT
public:
    explicit FutoCredentialEditor(QObject *parent = nullptr);
    ~FutoCredentialEditor();
    void setFocusObject(QObject *object);
    Q_INVOKABLE void browserReply(int serial, const QString &result);

private:
    void acceptConnection();
    void readRequest();
    void closeConnection();
    void respond(const QJsonObject &result);
    void dispatch(const QJsonObject &request);
    QObject *browserPage() const;
    bool runBrowserRequest(QObject *page, const QJsonObject &request);

    int m_listener = -1;
    int m_client = -1;
    int m_serial = 0;
    QByteArray m_path;
    QByteArray m_request;
    QSocketNotifier *m_accept = nullptr;
    QSocketNotifier *m_read = nullptr;
    QTimer *m_timeout = nullptr;
    QPointer<QObject> m_focus;
    QPointer<QObject> m_browser;
    QString m_browserOrigin;
    QScopedPointer<QJSEngine> m_engine;
};
#endif
