/*
 * Minimal device-local key bridge for FUTO Keyboard.
 *
 * The installed program is set-user-ID root so the unprivileged keyboard
 * helper can obtain its encryption key without exposing that key as a normal
 * user-readable file.  It accepts only the trusted packaged helper as its
 * immediate parent and only supports the learned-data key.  Authentication
 * remains the responsibility of the trusted Settings/Maliit callers before
 * they ask the helper to unlock protected data.
 */
#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

static const char *const key_directory = "/var/lib/futo-keyboard-sailfish";
static const char *const helper_path = "/usr/libexec/futo-keyboard-helper";

static void clear_bytes(unsigned char *data, size_t length)
{
    volatile unsigned char *cursor = data;
    while (length-- > 0)
        *cursor++ = 0;
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

static int read_all(int descriptor, unsigned char *data, size_t length)
{
    size_t offset = 0;
    while (offset < length) {
        const ssize_t count = read(descriptor, data + offset, length - offset);
        if (count < 0 && errno == EINTR)
            continue;
        if (count <= 0)
            return 0;
        offset += (size_t)count;
    }
    return 1;
}

static int write_all(int descriptor, const unsigned char *data, size_t length)
{
    size_t offset = 0;
    while (offset < length) {
        const ssize_t count = write(descriptor, data + offset, length - offset);
        if (count < 0 && errno == EINTR)
            continue;
        if (count <= 0)
            return 0;
        offset += (size_t)count;
    }
    return 1;
}

static int validate_key_file(int descriptor)
{
    struct stat info;
    if (fstat(descriptor, &info) != 0)
        return 0;
    return S_ISREG(info.st_mode)
            && info.st_uid == 0
            && (info.st_mode & 0777) == 0600
            && info.st_size == 32;
}

static int load_key(int directory, const char *name, unsigned char key[32])
{
    const int descriptor = openat(directory, name,
                                  O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    if (descriptor < 0)
        return 0;
    const int valid = validate_key_file(descriptor) && read_all(descriptor, key, 32);
    close(descriptor);
    return valid;
}

static int random_key(unsigned char key[32])
{
    const int descriptor = open("/dev/urandom", O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    if (descriptor < 0)
        return 0;
    const int ok = read_all(descriptor, key, 32);
    close(descriptor);
    return ok;
}

static int create_key(int directory, const char *name, unsigned char key[32])
{
    char temporary[96];
    if (!random_key(key))
        return 0;
    if (snprintf(temporary, sizeof(temporary), ".%s.new.%ld", name,
                 (long)getpid()) >= (int)sizeof(temporary))
        return 0;

    const int descriptor = openat(directory, temporary,
                                  O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC
                                  | O_NOFOLLOW, 0600);
    if (descriptor < 0)
        return 0;
    int ok = fchmod(descriptor, 0600) == 0
            && write_all(descriptor, key, 32)
            && fsync(descriptor) == 0;
    close(descriptor);
    if (ok) {
        if (linkat(directory, temporary, directory, name, 0) != 0) {
            if (errno == EEXIST) {
                clear_bytes(key, 32);
                ok = load_key(directory, name, key);
            } else {
                ok = 0;
            }
        }
    }
    unlinkat(directory, temporary, 0);
    return ok;
}

int main(int argc, char **argv)
{
    unsigned char key[32];
    char key_name[64];
    int result = 2;

    if (geteuid() != 0 || getuid() == 0 || !trusted_parent()) {
        fputs("futo-keyboard-keyring: untrusted caller\n", stderr);
        return 77;
    }
    if (argc != 3
            || (strcmp(argv[1], "get") != 0
                && strcmp(argv[1], "ensure") != 0
                && strcmp(argv[1], "prepare") != 0
                && strcmp(argv[1], "unlock") != 0)
            || strcmp(argv[2], "learned") != 0) {
        fputs("Usage: futo-keyboard-keyring get|ensure|prepare|unlock learned\n",
              stderr);
        return 64;
    }
    if (snprintf(key_name, sizeof(key_name), "%lu-learned.key",
                 (unsigned long)getuid()) >= (int)sizeof(key_name))
        return 2;

    if (mkdir(key_directory, 0700) != 0 && errno != EEXIST)
        return 2;
    if (chown(key_directory, 0, 0) != 0 || chmod(key_directory, 0700) != 0)
        return 2;
    const int directory = open(key_directory,
                               O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW);
    if (directory < 0)
        return 2;
    struct stat directory_info;
    if (fstat(directory, &directory_info) != 0
            || !S_ISDIR(directory_info.st_mode)
            || directory_info.st_uid != 0
            || (directory_info.st_mode & 0777) != 0700) {
        close(directory);
        return 2;
    }

    int ok = load_key(directory, key_name, key);
    if (!ok && strcmp(argv[1], "get") != 0)
        ok = create_key(directory, key_name, key);
    close(directory);
    if (ok && write_all(STDOUT_FILENO, key, sizeof(key)))
        result = 0;
    else if (!ok && errno == ENOENT)
        result = 4;
    clear_bytes(key, sizeof(key));
    return result;
}
