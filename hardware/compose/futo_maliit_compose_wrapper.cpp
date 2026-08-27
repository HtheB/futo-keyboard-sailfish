#include <QPluginLoader>
#include <QCoreApplication>
#include <QFileInfo>
#include <QKeyEvent>
#include <QLocale>
#include <QPointer>
#include <QRectF>
#include <QScopedPointer>
#include <QStringList>
#include <qpa/qplatforminputcontext.h>
#include <qpa/qplatforminputcontextplugin_p.h>

static bool isLipstickCompositor()
{
    static const bool lipstick = QFileInfo(
                QCoreApplication::applicationFilePath()).fileName()
            .compare(QStringLiteral("lipstick"), Qt::CaseInsensitive) == 0;
    return lipstick;
}

class FutoComposingInputContext : public QPlatformInputContext
{
public:
    FutoComposingInputContext(QPlatformInputContext *maliit,
                              QPlatformInputContext *compose)
        : m_maliit(maliit), m_compose(compose)
    {
    }

    ~FutoComposingInputContext() override
    {
        if (m_focusObject)
            m_focusObject->removeEventFilter(this);
    }

    bool isValid() const override
    {
        return m_maliit && m_maliit->isValid();
    }

    bool hasCapability(Capability capability) const override
    {
        return m_maliit && m_maliit->hasCapability(capability);
    }

    void reset() override
    {
        if (m_compose)
            m_compose->reset();
        if (m_maliit)
            m_maliit->reset();
    }

    void commit() override
    {
        if (m_compose)
            m_compose->reset();
        if (m_maliit)
            m_maliit->commit();
    }

    void update(Qt::InputMethodQueries queries) override
    {
        if (m_compose)
            m_compose->update(queries);
        if (m_maliit)
            m_maliit->update(queries);
    }

    void invokeAction(QInputMethod::Action action, int cursorPosition) override
    {
        if (m_maliit)
            m_maliit->invokeAction(action, cursorPosition);
    }

    bool filterEvent(const QEvent *event) override
    {
        return filterKeyEvent(event);
    }

    bool eventFilter(QObject *watched, QEvent *event) override
    {
        // Lipstick owns the physical keyboard and forwards its key events to
        // the focused Wayland client.  Consuming Compose sequences here makes
        // the entire sequence disappear before the client can receive it.
        if (isLipstickCompositor())
            return false;
        if (watched != m_focusObject)
            return false;
        if (!event || (event->type() != QEvent::KeyPress
                       && event->type() != QEvent::KeyRelease))
            return false;

        const QKeyEvent *keyEvent = static_cast<const QKeyEvent *>(event);
        const quint32 nativeKey = keyEvent->nativeVirtualKey();
        const bool nativeDeadKey = nativeKey >= 0xfe50 && nativeKey <= 0xfe62;

        // QtWayland 5.6 exposes XKB dead keys with key()==0 and only keeps
        // the XKB keysym in nativeVirtualKey().  Qt Compose consequently
        // rejects the event before looking at that native keysym.  Supply the
        // matching Qt::Key_Dead_* value while preserving all native fields.
        if (nativeDeadKey) {
            if (event->type() == QEvent::KeyRelease)
                return true;

            const int qtDeadKey = 0x01001200 | int(nativeKey & 0xff);
            QKeyEvent translated(QEvent::KeyPress,
                                 qtDeadKey,
                                 keyEvent->modifiers(),
                                 keyEvent->nativeScanCode(),
                                 nativeKey,
                                 keyEvent->nativeModifiers(),
                                 QString(),
                                 keyEvent->isAutoRepeat(),
                                 ushort(keyEvent->count()));
            m_waylandComposePending = m_compose
                    && m_compose->filterEvent(&translated);
            // A dead key never inserts text by itself, even if the Compose
            // table could not be initialized.
            return true;
        }

        if (event->type() == QEvent::KeyPress && m_waylandComposePending) {
            m_waylandComposePending = false;
            const bool composed = m_compose && m_compose->filterEvent(event);
            return composed;
        }

        // Do not delegate ordinary events to Maliit from an application event
        // filter.  That re-enters key delivery and can terminate the client.
        return false;
    }

private:
    bool filterKeyEvent(const QEvent *event)
    {
        if (isLipstickCompositor())
            return false;
        const bool composed = m_compose && m_compose->filterEvent(event);
        if (composed)
            return true;
        return m_maliit && m_maliit->filterEvent(event);
    }

    QRectF keyboardRect() const override
    {
        return m_maliit ? m_maliit->keyboardRect() : QRectF();
    }

    bool isAnimating() const override
    {
        return m_maliit && m_maliit->isAnimating();
    }

    void showInputPanel() override
    {
        if (m_maliit)
            m_maliit->showInputPanel();
    }

    void hideInputPanel() override
    {
        if (m_maliit)
            m_maliit->hideInputPanel();
    }

    bool isInputPanelVisible() const override
    {
        return m_maliit && m_maliit->isInputPanelVisible();
    }

    QLocale locale() const override
    {
        return m_maliit ? m_maliit->locale() : QLocale();
    }

    Qt::LayoutDirection inputDirection() const override
    {
        return m_maliit ? m_maliit->inputDirection() : Qt::LeftToRight;
    }

    void setFocusObject(QObject *object) override
    {
        if (m_focusObject == object)
            return;
        if (m_focusObject)
            m_focusObject->removeEventFilter(this);
        m_focusObject = object;
        if (m_focusObject && !isLipstickCompositor())
            m_focusObject->installEventFilter(this);
        if (m_compose)
            m_compose->setFocusObject(object);
        if (m_maliit)
            m_maliit->setFocusObject(object);
    }

    QScopedPointer<QPlatformInputContext> m_maliit;
    QScopedPointer<QPlatformInputContext> m_compose;
    QPointer<QObject> m_focusObject;
    bool m_waylandComposePending = false;
};

class FutoMaliitComposeWrapperPlugin : public QPlatformInputContextPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QPlatformInputContextFactoryInterface_iid
                      FILE "futo-maliit-compose-wrapper.json")

public:
    FutoMaliitComposeWrapperPlugin()
        : m_maliitLoader(QStringLiteral("/usr/lib64/qt5/plugins/platforminputcontexts/libmaliitplatforminputcontextplugin.so")),
          m_composeLoader(QStringLiteral("/usr/lib64/qt5/plugins/platforminputcontexts/libcomposeplatforminputcontextplugin.so"))
    {
        m_maliitLoader.setLoadHints(QLibrary::PreventUnloadHint);
        m_composeLoader.setLoadHints(QLibrary::PreventUnloadHint);
    }

    QPlatformInputContext *create(const QString &system,
                                  const QStringList &parameters) override
    {
        if (system.compare(QStringLiteral("maliit"), Qt::CaseInsensitive) != 0)
            return nullptr;

        QPlatformInputContextPlugin *maliitFactory =
                qobject_cast<QPlatformInputContextPlugin *>(m_maliitLoader.instance());
        if (!maliitFactory)
            return nullptr;

        QPlatformInputContext *maliit = maliitFactory->create(system, parameters);
        if (!maliit)
            return nullptr;

        QPlatformInputContext *compose = nullptr;
        QPlatformInputContextPlugin *composeFactory =
                qobject_cast<QPlatformInputContextPlugin *>(m_composeLoader.instance());
        if (composeFactory)
            compose = composeFactory->create(QStringLiteral("compose"), QStringList());

        return new FutoComposingInputContext(maliit, compose);
    }

private:
    QPluginLoader m_maliitLoader;
    QPluginLoader m_composeLoader;
};

#include "futo_maliit_compose_wrapper.moc"
