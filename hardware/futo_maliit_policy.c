/*
 * Optional Maliit hardware-keyboard policy override.
 *
 * Sailfish's Maliit build calls the exported MImHwKeyboardTracker::isOpen()
 * through the shared-library PLT.  When the user explicitly requests a
 * simultaneous virtual keyboard, this preload shim reports the hardware
 * keyboard as closed to Maliit's input-source selector.  The physical device
 * remains visible to Lipstick/Wayland and continues to deliver key events.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <limits.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

typedef bool (*is_open_function)(const void *tracker);

static bool keep_virtual_keyboard(void)
{
    const char *home = getenv("HOME");
    char marker[PATH_MAX];
    int length;

    if (!home || !*home)
        return false;
    length = snprintf(marker, sizeof(marker),
                      "%s/.local/share/futo-keyboard-sailfish/keep-virtual-hardware",
                      home);
    if (length > 0 && (size_t)length < sizeof(marker)
            && access(marker, F_OK) == 0)
        return true;
    /* The tightly restricted focus bridge is not a physical keyboard.
     * Keep the current on-screen input source during its short gesture. */
    length = snprintf(marker, sizeof(marker),
                      "%s/.local/share/futo-keyboard-sailfish/autofill-focus-active",
                      home);
    struct stat status;
    const time_t now = time(NULL);
    return length > 0 && (size_t)length < sizeof(marker)
           && stat(marker, &status) == 0 && S_ISREG(status.st_mode)
           && status.st_uid == getuid() && status.st_mtime <= now
           && now - status.st_mtime <= 3;
}

extern bool futo_maliit_hardware_keyboard_is_open(const void *tracker)
    __asm__("_ZNK20MImHwKeyboardTracker6isOpenEv");

bool futo_maliit_hardware_keyboard_is_open(const void *tracker)
{
    static is_open_function original;

    if (keep_virtual_keyboard())
        return false;
    if (!original)
        original = (is_open_function)dlsym(
                    RTLD_NEXT, "_ZNK20MImHwKeyboardTracker6isOpenEv");
    return original ? original(tracker) : false;
}
