/*
 * Restricted focus-navigation bridge for FUTO Keyboard.
 *
 * Some Wayland clients deliberately ignore Tab keysyms delivered through the
 * text-input protocol.  A short-lived uinput device makes the same navigation
 * request through the hardware-keyboard path.  This set-user-ID helper accepts
 * only the packaged FUTO helper as its immediate parent and can emit only one
 * Tab or Shift+Tab gesture.
 */
#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <linux/input.h>
#include <linux/uinput.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

static const char *const helper_path = "/usr/libexec/futo-keyboard-helper";

static int trusted_parent(void)
{
    char proc_path[64];
    char resolved[PATH_MAX + 1];
    struct stat actual;
    struct stat expected;
    const pid_t parent = getppid();

    if (snprintf(proc_path, sizeof(proc_path), "/proc/%ld/exe",
                 (long)parent) >= (int)sizeof(proc_path))
        return 0;
    const ssize_t length = readlink(proc_path, resolved, PATH_MAX);
    if (length <= 0 || length > PATH_MAX)
        return 0;
    resolved[length] = '\0';
    if (strcmp(resolved, helper_path) != 0)
        return 0;
    if (stat(proc_path, &actual) != 0 || stat(helper_path, &expected) != 0)
        return 0;
    return actual.st_dev == expected.st_dev && actual.st_ino == expected.st_ino;
}

static int write_all(int descriptor, const void *data, size_t length)
{
    const unsigned char *cursor = data;
    size_t offset = 0;
    while (offset < length) {
        const ssize_t count = write(descriptor, cursor + offset,
                                    length - offset);
        if (count < 0 && errno == EINTR)
            continue;
        if (count <= 0)
            return 0;
        offset += (size_t)count;
    }
    return 1;
}

static void short_pause(long nanoseconds)
{
    struct timespec duration = { .tv_sec = 0, .tv_nsec = nanoseconds };
    while (nanosleep(&duration, &duration) != 0 && errno == EINTR) {
    }
}

static int emit_event(int descriptor, unsigned short type,
                      unsigned short code, int value)
{
    struct input_event event;
    memset(&event, 0, sizeof(event));
    /* uinput supplies the event timestamp.  Leaving the timestamp fields at
     * zero also keeps this bridge source-compatible with both the legacy
     * timeval ABI and 32-bit time64 input_event headers. */
    event.type = type;
    event.code = code;
    event.value = value;
    return write_all(descriptor, &event, sizeof(event));
}

static int emit_key(int descriptor, unsigned short code, int value)
{
    return emit_event(descriptor, EV_KEY, code, value)
            && emit_event(descriptor, EV_SYN, SYN_REPORT, 0);
}

static int drop_privileges(void)
{
    const uid_t user = getuid();
    const gid_t group = getgid();
    /* With an effective uid of root, setgid/setuid set all saved IDs too. */
    return setgid(group) == 0
            && setuid(user) == 0
            && geteuid() == user && getegid() == group;
}

int main(int argc, char **argv)
{
    if (geteuid() != 0 || getuid() == 0 || !trusted_parent()) {
        fputs("futo-keyboard-focus: untrusted caller\n", stderr);
        return 77;
    }
    if (argc != 2 || (strcmp(argv[1], "next") != 0
            && strcmp(argv[1], "previous") != 0)) {
        fputs("Usage: futo-keyboard-focus next|previous\n", stderr);
        return 64;
    }

    const int descriptor = open("/dev/uinput",
                                O_WRONLY | O_NONBLOCK | O_CLOEXEC | O_NOFOLLOW);
    if (descriptor < 0)
        return 2;

    int created = 0;
    int ok = ioctl(descriptor, UI_SET_EVBIT, EV_KEY) == 0
            && ioctl(descriptor, UI_SET_KEYBIT, KEY_TAB) == 0
            && ioctl(descriptor, UI_SET_KEYBIT, KEY_LEFTSHIFT) == 0;
    struct uinput_user_dev device;
    memset(&device, 0, sizeof(device));
    snprintf(device.name, UINPUT_MAX_NAME_SIZE, "FUTO Autofill Focus");
    device.id.bustype = BUS_USB;
    device.id.vendor = 0x1209;
    device.id.product = 0x4655;
    device.id.version = 1;
    if (ok)
        ok = write_all(descriptor, &device, sizeof(device));
    if (ok) {
        ok = ioctl(descriptor, UI_DEV_CREATE) == 0;
        created = ok;
    }
	/* Device creation requires the elevated credential. Drop it permanently
	 * before the bridge can emit the restricted gesture. */
	if (ok)
		ok = drop_privileges();

    if (ok) {
        /* Allow Lipstick to bind the device before emitting the one gesture. */
        short_pause(350000000L);
        if (strcmp(argv[1], "previous") == 0)
            ok = emit_key(descriptor, KEY_LEFTSHIFT, 1);
        if (ok)
            ok = emit_key(descriptor, KEY_TAB, 1);
        short_pause(30000000L);
        if (ok)
            ok = emit_key(descriptor, KEY_TAB, 0);
        if (strcmp(argv[1], "previous") == 0) {
            short_pause(15000000L);
            if (ok)
                ok = emit_key(descriptor, KEY_LEFTSHIFT, 0);
        }
        short_pause(120000000L);
    }
    if (created)
        ioctl(descriptor, UI_DEV_DESTROY);
    close(descriptor);
    return ok ? 0 : 2;
}
