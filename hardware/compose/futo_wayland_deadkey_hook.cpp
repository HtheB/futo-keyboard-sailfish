#include <QEvent>
#include <QString>
#include <QWindow>
#include <qpa/qwindowsysteminterface.h>

#include <dlfcn.h>
#include <elf.h>
#include <link.h>
#include <locale.h>
#include <stdlib.h>
#include <string.h>
#include <xkbcommon/xkbcommon-compose.h>
#include <xkbcommon/xkbcommon-keysyms.h>

namespace {

#ifndef FUTO_WAYLAND_RELOCATION_OFFSET
#error FUTO_WAYLAND_RELOCATION_OFFSET must match the target QtWayland build
#endif

typedef bool (*HandleExtendedKeyEvent)(QWindow *, ulong, QEvent::Type, int,
                                      Qt::KeyboardModifiers, quint32, quint32,
                                      quint32, const QString &, bool, ushort,
                                      bool);

static bool futoHandleExtendedKeyEvent(
        QWindow *window, ulong timestamp, QEvent::Type type, int key,
        Qt::KeyboardModifiers modifiers, quint32 nativeScanCode,
        quint32 nativeVirtualKey, quint32 nativeModifiers,
        const QString &text, bool autorepeat, ushort count,
        bool tryShortcutOverride);

static int patchOriginalWaylandGot(struct dl_phdr_info *info, size_t, void *)
{
    if (!info->dlpi_name
            || !strstr(info->dlpi_name,
                       "libQt5WaylandClientFutoOriginal.so.5")) {
        return 0;
    }

    // The build script derives and verifies this relocation from the exact
    // target QtWayland client. The stock binary is kept unchanged apart from
    // its SONAME. Validate that the slot is writable before touching it so a
    // future or mismatched OS build fails safely.
    const ElfW(Addr) relocationOffset = FUTO_WAYLAND_RELOCATION_OFFSET;
    bool writable = false;
    for (ElfW(Half) i = 0; i < info->dlpi_phnum; ++i) {
        const ElfW(Phdr) &header = info->dlpi_phdr[i];
        if (header.p_type == PT_LOAD && (header.p_flags & PF_W)
                && relocationOffset >= header.p_vaddr
                && relocationOffset + sizeof(void *)
                   <= header.p_vaddr + header.p_memsz) {
            writable = true;
            break;
        }
    }
    if (!writable) {
        return 1;
    }

    void **slot = reinterpret_cast<void **>(info->dlpi_addr
                                             + relocationOffset);
    *slot = reinterpret_cast<void *>(&futoHandleExtendedKeyEvent);
    return 1;
}

__attribute__((constructor)) static void installOriginalWaylandHook()
{
    dl_iterate_phdr(patchOriginalWaylandGot, 0);
}

static HandleExtendedKeyEvent realHandleExtendedKeyEvent()
{
    static HandleExtendedKeyEvent function = 0;
    if (!function) {
        const char symbol[] =
                "_ZN22QWindowSystemInterface22handleExtendedKeyEventEP7QWindowm"
                "N6QEvent4TypeEi6QFlagsIN2Qt16KeyboardModifierEEjjjRK7QStringbtb";
#if defined(__GLIBC__)
        function = reinterpret_cast<HandleExtendedKeyEvent>(
                    dlvsym(RTLD_NEXT, symbol, "Qt_5"));
#endif
        if (!function)
            function = reinterpret_cast<HandleExtendedKeyEvent>(
                        dlsym(RTLD_NEXT, symbol));
    }
    return function;
}

static const char *composeLocale()
{
    const char *locale = setlocale(LC_CTYPE, 0);
    if (locale && *locale && strcmp(locale, "C") != 0
            && strcmp(locale, "POSIX") != 0) {
        return locale;
    }
    const char *variables[] = { "LC_ALL", "LC_CTYPE", "LANG" };
    for (unsigned i = 0; i < sizeof(variables) / sizeof(variables[0]); ++i) {
        const char *value = getenv(variables[i]);
        if (value && *value && strcmp(value, "C") != 0
                && strcmp(value, "POSIX") != 0) {
            return value;
        }
    }
    return "en_US.UTF-8";
}

static QString spacingDeadKey(xkb_keysym_t symbol)
{
    switch (symbol) {
    case XKB_KEY_dead_grave: return QString(QChar(0x0060));
    case XKB_KEY_dead_acute: return QString(QChar(0x0027));
    case XKB_KEY_dead_circumflex: return QString(QChar(0x005e));
    case XKB_KEY_dead_tilde: return QString(QChar(0x007e));
    case XKB_KEY_dead_macron: return QString(QChar(0x00af));
    case XKB_KEY_dead_breve: return QString(QChar(0x02d8));
    case XKB_KEY_dead_abovedot: return QString(QChar(0x02d9));
    case XKB_KEY_dead_diaeresis: return QString(QChar(0x00a8));
    case XKB_KEY_dead_abovering: return QString(QChar(0x02da));
    case XKB_KEY_dead_doubleacute: return QString(QChar(0x02dd));
    case XKB_KEY_dead_caron: return QString(QChar(0x02c7));
    case XKB_KEY_dead_cedilla: return QString(QChar(0x00b8));
    case XKB_KEY_dead_ogonek: return QString(QChar(0x02db));
    default: return QString();
    }
}

static int qtKeyForText(const QString &text)
{
    if (text.size() == 1) {
        const QString upper = text.toUpper();
        if (upper.size() == 1)
            return upper.at(0).unicode();
    }
    return 0;
}

class WaylandComposer
{
public:
    WaylandComposer()
        : context(xkb_context_new(XKB_CONTEXT_NO_FLAGS)), table(0), state(0),
          pendingDeadSymbol(XKB_KEY_NoSymbol), suppressedReleaseScan(0),
          composedReleaseScan(0), composedReleaseKey(0),
          composedReleaseSymbol(XKB_KEY_NoSymbol)
    {
        if (context) {
            table = xkb_compose_table_new_from_locale(
                        context, composeLocale(), XKB_COMPOSE_COMPILE_NO_FLAGS);
            if (table)
                state = xkb_compose_state_new(table, XKB_COMPOSE_STATE_NO_FLAGS);
        }
    }

    ~WaylandComposer()
    {
        if (state)
            xkb_compose_state_unref(state);
        if (table)
            xkb_compose_table_unref(table);
        if (context)
            xkb_context_unref(context);
    }

    bool dispatch(HandleExtendedKeyEvent realFunction, QWindow *window,
                  ulong timestamp, QEvent::Type type, int key,
                  Qt::KeyboardModifiers modifiers, quint32 nativeScanCode,
                  quint32 nativeVirtualKey, quint32 nativeModifiers,
                  const QString &text, bool autorepeat, ushort count,
                  bool tryShortcutOverride)
    {
        if (type == QEvent::KeyRelease) {
            if (suppressedReleaseScan && nativeScanCode == suppressedReleaseScan) {
                suppressedReleaseScan = 0;
                return true;
            }
            if (composedReleaseScan && nativeScanCode == composedReleaseScan) {
                const bool result = realFunction(
                            window, timestamp, type, composedReleaseKey,
                            modifiers, nativeScanCode, composedReleaseSymbol,
                            nativeModifiers, composedReleaseText, autorepeat,
                            count, tryShortcutOverride);
                composedReleaseScan = 0;
                composedReleaseText.clear();
                return result;
            }
            return realFunction(window, timestamp, type, key, modifiers,
                                nativeScanCode, nativeVirtualKey,
                                nativeModifiers, text, autorepeat, count,
                                tryShortcutOverride);
        }

        if (type != QEvent::KeyPress || !state) {
            return realFunction(window, timestamp, type, key, modifiers,
                                nativeScanCode, nativeVirtualKey,
                                nativeModifiers, text, autorepeat, count,
                                tryShortcutOverride);
        }

        const xkb_keysym_t symbol = xkb_keysym_t(nativeVirtualKey);
        const xkb_compose_feed_result feed = xkb_compose_state_feed(state, symbol);
        if (feed != XKB_COMPOSE_FEED_ACCEPTED) {
            return realFunction(window, timestamp, type, key, modifiers,
                                nativeScanCode, nativeVirtualKey,
                                nativeModifiers, text, autorepeat, count,
                                tryShortcutOverride);
        }

        switch (xkb_compose_state_get_status(state)) {
        case XKB_COMPOSE_COMPOSING:
            if (symbol >= XKB_KEY_dead_grave && symbol <= XKB_KEY_dead_currency)
                pendingDeadSymbol = symbol;
            suppressedReleaseScan = nativeScanCode;
            return true;

        case XKB_COMPOSE_COMPOSED: {
            char buffer[128];
            const int length = xkb_compose_state_get_utf8(state, buffer,
                                                           sizeof(buffer));
            const QString composedText = length > 0
                    ? QString::fromUtf8(buffer) : QString();
            const xkb_keysym_t composedSymbol =
                    xkb_compose_state_get_one_sym(state);
            xkb_compose_state_reset(state);
            pendingDeadSymbol = XKB_KEY_NoSymbol;
            const int composedKey = qtKeyForText(composedText);
            composedReleaseScan = nativeScanCode;
            composedReleaseKey = composedKey;
            composedReleaseSymbol = composedSymbol;
            composedReleaseText = composedText;
            return realFunction(window, timestamp, type, composedKey,
                                modifiers, nativeScanCode, composedSymbol,
                                nativeModifiers, composedText, autorepeat,
                                count, tryShortcutOverride);
        }

        case XKB_COMPOSE_CANCELLED: {
            xkb_compose_state_reset(state);
            const QString spacing = spacingDeadKey(pendingDeadSymbol);
            pendingDeadSymbol = XKB_KEY_NoSymbol;
            if (!spacing.isEmpty()) {
                const int spacingKey = qtKeyForText(spacing);
                realFunction(window, timestamp, QEvent::KeyPress, spacingKey,
                             Qt::NoModifier, 0, spacing.at(0).unicode(), 0,
                             spacing, false, 1, false);
                realFunction(window, timestamp, QEvent::KeyRelease, spacingKey,
                             Qt::NoModifier, 0, spacing.at(0).unicode(), 0,
                             spacing, false, 1, false);
            }
            return realFunction(window, timestamp, type, key, modifiers,
                                nativeScanCode, nativeVirtualKey,
                                nativeModifiers, text, autorepeat, count,
                                tryShortcutOverride);
        }

        case XKB_COMPOSE_NOTHING:
        default:
            return realFunction(window, timestamp, type, key, modifiers,
                                nativeScanCode, nativeVirtualKey,
                                nativeModifiers, text, autorepeat, count,
                                tryShortcutOverride);
        }
    }

private:
    xkb_context *context;
    xkb_compose_table *table;
    xkb_compose_state *state;
    xkb_keysym_t pendingDeadSymbol;
    quint32 suppressedReleaseScan;
    quint32 composedReleaseScan;
    int composedReleaseKey;
    xkb_keysym_t composedReleaseSymbol;
    QString composedReleaseText;
};

static bool futoHandleExtendedKeyEvent(
        QWindow *window, ulong timestamp, QEvent::Type type, int key,
        Qt::KeyboardModifiers modifiers, quint32 nativeScanCode,
        quint32 nativeVirtualKey, quint32 nativeModifiers,
        const QString &text, bool autorepeat, ushort count,
        bool tryShortcutOverride)
{
    HandleExtendedKeyEvent realFunction = realHandleExtendedKeyEvent();
    if (!realFunction)
        return false;
    static WaylandComposer composer;
    return composer.dispatch(realFunction, window, timestamp, type, key,
                             modifiers, nativeScanCode, nativeVirtualKey,
                             nativeModifiers, text, autorepeat, count,
                             tryShortcutOverride);
}

} // namespace

bool QWindowSystemInterface::handleExtendedKeyEvent(
        QWindow *window, ulong timestamp, QEvent::Type type, int key,
        Qt::KeyboardModifiers modifiers, quint32 nativeScanCode,
        quint32 nativeVirtualKey, quint32 nativeModifiers,
        const QString &text, bool autorepeat, ushort count,
        bool tryShortcutOverride)
{
    return futoHandleExtendedKeyEvent(
                window, timestamp, type, key, modifiers, nativeScanCode,
                nativeVirtualKey, nativeModifiers, text, autorepeat, count,
                tryShortcutOverride);
}
