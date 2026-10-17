/* Installs only the root-owned, bundled Layout Editor shortcut package. */
#define _GNU_SOURCE
#include <fcntl.h>
#include <grp.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static int trusted_parent(void)
{
    const pid_t parent = getppid();
    const char *helper = "/usr/libexec/futo-keyboard-helper";
    char path[64], resolved[PATH_MAX + 1];
    struct stat actual, expected;
    if (snprintf(path, sizeof(path), "/proc/%ld/exe", (long)parent) >= (int)sizeof(path)) return 0;
    const ssize_t length = readlink(path, resolved, PATH_MAX);
    if (length <= 0) return 0;
    resolved[length] = '\0';
    return strcmp(resolved, helper) == 0 && stat(path, &actual) == 0
            && stat(helper, &expected) == 0 && S_ISREG(expected.st_mode)
            && expected.st_uid == 0 && (expected.st_mode & 0022) == 0
            && actual.st_dev == expected.st_dev && actual.st_ino == expected.st_ino
            && getppid() == parent;
}

int main(int argc, char **argv)
{
    (void)argv;
    if (argc != 1) return 64;
    if (geteuid() != 0 || getuid() == 0 || !trusted_parent()) return 77;
    const char *package = "/usr/share/futo-keyboard-sailfish/editor/launcher.rpm";
    struct stat info;
    if (lstat(package, &info) != 0 || !S_ISREG(info.st_mode) || info.st_uid != 0
            || (info.st_mode & 0022) != 0 || info.st_size <= 0 || info.st_size > 1024*1024) return 77;
    if (setgroups(0, NULL) != 0 || setgid(0) != 0 || setuid(0) != 0) return 77;
    const int input = open("/dev/null", O_RDONLY | O_CLOEXEC);
    if (input < 0 || dup2(input, STDIN_FILENO) < 0) return 2;
    if (input != STDIN_FILENO) close(input);
    umask(0022);
    char *const args[] = {"/usr/bin/pkcon", "--plain", "-y", "--allow-untrusted",
                         "install-local", (char *)package, NULL};
    char *const environment[] = {"PATH=/usr/bin:/bin", "LANG=C", "HOME=/root", NULL};
    execve(args[0], args, environment);
    return 2;
}
