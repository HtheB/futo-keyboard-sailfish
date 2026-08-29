/*
 * Restricted Android AppSupport keyboard bridge for FUTO Keyboard.
 *
 * A few Android applications focus an editable field but explicitly suppress
 * Android's IME request.  AppSupport consequently leaves every Sailfish
 * keyboard hidden.  This set-user-ID helper permits the packaged FUTO helper
 * to issue the fixed Binder request that shows the AppSupport keyboard or,
 * while that compatibility mode is active, inject a tightly validated word,
 * printable character, or control key.  It cannot select a package or run
 * arbitrary caller-supplied commands.
 */
#define _GNU_SOURCE

#include <errno.h>
#include <limits.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

static const char *const helper_path = "/usr/libexec/futo-keyboard-helper";
static const char *const lxc_attach_path = "/usr/bin/lxc-attach";

static int valid_text(const char *value)
{
    size_t index;
    size_t length;

    if (value == NULL)
        return 0;
    length = strlen(value);
    if (length == 0 || length > 256)
        return 0;
    for (index = 0; index < length; ++index) {
        const unsigned char byte = (unsigned char)value[index];
        if (byte <= 0x20 || byte == 0x7f)
            return 0;
    }
    return 1;
}

static int valid_key(const char *value)
{
    static const char *const keys[] = {
        "KEYCODE_DEL", "KEYCODE_FORWARD_DEL", "KEYCODE_ENTER",
        "KEYCODE_SPACE", "KEYCODE_TAB", "KEYCODE_ESCAPE",
        "KEYCODE_DPAD_LEFT", "KEYCODE_DPAD_UP", "KEYCODE_DPAD_RIGHT",
        "KEYCODE_DPAD_DOWN", "KEYCODE_MOVE_HOME", "KEYCODE_MOVE_END",
        "KEYCODE_PAGE_UP", "KEYCODE_PAGE_DOWN"
    };
    size_t index;

    if (value == NULL)
        return 0;
    for (index = 0; index < sizeof(keys) / sizeof(keys[0]); ++index) {
        if (strcmp(value, keys[index]) == 0)
            return 1;
    }
    return 0;
}

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

static int user_name(char result[256])
{
    struct passwd record;
    struct passwd *found = NULL;
    char storage[4096];

    if (getpwuid_r(getuid(), &record, storage, sizeof(storage), &found) != 0
            || found == NULL || found->pw_name == NULL
            || found->pw_name[0] == '\0')
        return 0;
    const size_t length = strlen(found->pw_name);
    if (length >= 256)
        return 0;
    memcpy(result, found->pw_name, length + 1);
    return 1;
}

int main(int argc, char **argv)
{
    char instance[256];

    if (geteuid() != 0 || getuid() == 0 || !trusted_parent()) {
        fputs("futo-keyboard-appsupport: untrusted caller\n", stderr);
        return 77;
    }
    if (argc != 1 && argc != 2 && argc != 3) {
        fputs("Usage: futo-keyboard-appsupport [hide|text TEXT|keyevent KEYCODE]\n",
              stderr);
        return 64;
    }
    if (argc == 2 && strcmp(argv[1], "hide") != 0) {
        fputs("futo-keyboard-appsupport: invalid keyboard request\n", stderr);
        return 64;
    }
    if (argc == 3 && !((strcmp(argv[1], "text") == 0 && valid_text(argv[2]))
            || (strcmp(argv[1], "keyevent") == 0 && valid_key(argv[2])))) {
        fputs("futo-keyboard-appsupport: invalid input request\n", stderr);
        return 64;
    }
    if (!user_name(instance))
        return 2;

    /* lxc-attach expects a fully privileged caller.  All arguments below are
     * fixed except the account name read from the root-owned passwd database.
     */
    if (setgid(0) != 0 || setuid(0) != 0)
        return 2;
    if (clearenv() != 0 || setenv("PATH", "/usr/bin:/bin", 1) != 0)
        return 2;

    if (argc == 1 || argc == 2) {
        execl(lxc_attach_path, "lxc-attach",
              "-P", "/tmp/appsupport", "-n", instance, "--",
              "/system/bin/service", "call", "AlienKeyboardService",
              argc == 1 ? "1" : "2",
              (char *)NULL);
    } else {
        execl(lxc_attach_path, "lxc-attach",
              "-P", "/tmp/appsupport", "-n", instance, "--",
              "/system/bin/input", argv[1], argv[2], (char *)NULL);
    }
    fprintf(stderr, "futo-keyboard-appsupport: lxc-attach failed: %s\n",
            strerror(errno));
    return 2;
}
