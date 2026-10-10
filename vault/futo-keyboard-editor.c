/* Restricted socket broker for native editors inside Sailjail namespaces. */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>

static int trusted_parent(void)
{
    char path[64], resolved[PATH_MAX + 1];
    struct stat actual, expected;
    snprintf(path, sizeof(path), "/proc/%ld/exe", (long)getppid());
    const ssize_t length = readlink(path, resolved, PATH_MAX);
    if (length <= 0) return 0;
    resolved[length] = '\0';
    const char *helper = "/usr/libexec/futo-keyboard-helper";
    return strcmp(resolved, helper) == 0 && stat(path, &actual) == 0
            && stat(helper, &expected) == 0
            && actual.st_dev == expected.st_dev && actual.st_ino == expected.st_ino;
}

static long namespace_pid(long pid)
{
    char path[64], line[4096];
    snprintf(path, sizeof(path), "/proc/%ld/status", pid);
    FILE *file = fopen(path, "r");
    if (!file) return 0;
    long result = pid;
    while (fgets(line, sizeof(line), file)) {
        if (strncmp(line, "NSpid:", 6) != 0) continue;
        char *cursor = line + 6, *end;
        while (*cursor) {
            errno = 0;
            const long value = strtol(cursor, &end, 10);
            if (cursor == end || errno != 0) break;
            if (value <= 0 || value > INT_MAX) { result = 0; break; }
            result = value;
            cursor = end;
        }
        break;
    }
    fclose(file);
    return result;
}

static int transfer_all(int fd, const char *bytes, size_t length)
{
    for (size_t offset = 0; offset < length;) {
        const ssize_t count = write(fd, bytes + offset, length - offset);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) return 0;
        offset += (size_t)count;
    }
    return 1;
}

int main(int argc, char **argv)
{
    if (geteuid() != 0 || getuid() == 0 || !trusted_parent()) return 77;
    if (argc != 2) return 64;
    char *end;
    errno = 0;
    const long pid = strtol(argv[1], &end, 10);
    if (errno != 0 || *end || pid <= 0 || pid > INT_MAX) return 64;
    const uid_t user = getuid();
    char path[PATH_MAX];
    struct stat status;
    snprintf(path, sizeof(path), "/proc/%ld", pid);
    if (stat(path, &status) != 0 || status.st_uid != user) return 77;
    const long local_pid = namespace_pid(pid);
    if (!local_pid) return 2;
    const int length = snprintf(path, sizeof(path),
            "/proc/%ld/root/run/user/%lu/futo-editor-%ld", pid,
            (unsigned long)user, local_pid);
    if (length <= 0 || (size_t)length >= sizeof(path)) return 2;
    if (lstat(path, &status) != 0 || !S_ISSOCK(status.st_mode)
            || status.st_uid != user || (status.st_mode & 0077) != 0) return 77;
    struct sockaddr_un address;
    memset(&address, 0, sizeof(address));
    address.sun_family = AF_UNIX;
    if ((size_t)length >= sizeof(address.sun_path)) return 2;
    memcpy(address.sun_path, path, (size_t)length + 1);
    const int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (fd < 0) return 2;
    struct timeval timeout = { .tv_sec = 2, .tv_usec = 0 };
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));
    if (connect(fd, (struct sockaddr *)&address, sizeof(address)) != 0) {
        close(fd);
        return 2;
    }
    struct ucred peer;
    socklen_t peer_size = sizeof(peer);
    const int trusted = getsockopt(fd, SOL_SOCKET, SO_PEERCRED, &peer, &peer_size) == 0
            && peer_size == sizeof(peer) && peer.pid == pid && peer.uid == user;
    // The connection's peer credentials remain those established at connect.
    // No elevated privilege is needed to relay its tightly bounded request.
    const gid_t group = getgid();
    if (!trusted || setgid(group) != 0 || setuid(user) != 0
            || geteuid() != user || getegid() != group) { close(fd); return 77; }
    char request[32768], response[16384];
    size_t size = 0;
    while (size < sizeof(request)) {
        const ssize_t count = read(STDIN_FILENO, request + size, sizeof(request) - size);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) break;
        size += (size_t)count;
    }
    if (!size || size >= sizeof(request) || request[size - 1] != '\n'
            || !transfer_all(fd, request, size)) { close(fd); return 2; }
    memset(request, 0, sizeof(request));
    size = 0;
    while (size < sizeof(response)) {
        const ssize_t count = read(fd, response + size, sizeof(response) - size);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) break;
        size += (size_t)count;
        if (response[size - 1] == '\n') break;
    }
    close(fd);
    if (!size || size >= sizeof(response) || response[size - 1] != '\n') return 2;
    const int ok = transfer_all(STDOUT_FILENO, response, size);
    memset(response, 0, sizeof(response));
    return ok ? 0 : 2;
}
