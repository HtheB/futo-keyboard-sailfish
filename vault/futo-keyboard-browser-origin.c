/*
 * Read the active web origin for FUTO Keyboard.
 *
 * Sailfish Browser stores its active tab in a small SQLite database. Firefox
 * for Android stores the selected AppSupport tab in Android Components'
 * session-state JSON. This restricted set-user-ID helper returns only one
 * http(s) URL; it never exposes cookies, logins, form contents or page data.
 */
#define _GNU_SOURCE

#include <ctype.h>
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

typedef struct sqlite3 sqlite3;
typedef struct sqlite3_stmt sqlite3_stmt;

enum {
    SQLITE_OK = 0,
    SQLITE_ROW = 100,
    SQLITE_OPEN_READONLY = 0x00000001,
    SQLITE_OPEN_NOMUTEX = 0x00008000,
    MAX_SESSION_BYTES = 32 * 1024 * 1024
};

typedef int (*sqlite3_open_v2_fn)(const char *, sqlite3 **, int, const char *);
typedef int (*sqlite3_prepare_v2_fn)(sqlite3 *, const char *, int,
                                    sqlite3_stmt **, const char **);
typedef int (*sqlite3_step_fn)(sqlite3_stmt *);
typedef const unsigned char *(*sqlite3_column_text_fn)(sqlite3_stmt *, int);
typedef int (*sqlite3_finalize_fn)(sqlite3_stmt *);
typedef int (*sqlite3_close_fn)(sqlite3 *);

static const char *const helper_path = "/usr/libexec/futo-keyboard-helper";
static const char *const lxc_attach_path = "/usr/bin/lxc-attach";

static int drop_privileges(void)
{
    const uid_t user = getuid();
    const gid_t group = getgid();
    return setgid(group) == 0 && setuid(user) == 0
            && geteuid() == user && getegid() == group;
}

static int safe_web_url(const char *value)
{
    if (!value || (strncmp(value, "https://", 8) != 0
                   && strncmp(value, "http://", 7) != 0))
        return 0;
    const size_t length = strlen(value);
    if (length == 0 || length > 2048)
        return 0;
    for (size_t index = 0; index < length; ++index) {
        if (iscntrl((unsigned char)value[index]))
            return 0;
    }
    return 1;
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

static int caller_name(char result[256])
{
    struct passwd record;
    struct passwd *found = NULL;
    char storage[4096];

    if (getpwuid_r(getuid(), &record, storage, sizeof(storage), &found) != 0
            || !found || !found->pw_name || found->pw_name[0] == '\0')
        return 0;
    const size_t length = strlen(found->pw_name);
    if (length >= 256)
        return 0;
    memcpy(result, found->pw_name, length + 1);
    return 1;
}

static int firefox_package(const char *value)
{
    static const char *const packages[] = {
        "org.mozilla.firefox", "org.mozilla.firefox_beta",
        "org.mozilla.fenix", "org.mozilla.fenix.nightly",
        "org.mozilla.focus", "org.mozilla.focus.beta",
        "org.mozilla.klar", "org.mozilla.klar.beta",
        "org.mozilla.fennec_fdroid", "us.spotco.fennec_dos",
        "io.github.forkmaintainers.iceraven",
        "net.waterfox.android.release", "org.torproject.torbrowser",
        "org.torproject.torbrowser_alpha"
    };
    if (!value)
        return 0;
    for (size_t index = 0; index < sizeof(packages) / sizeof(packages[0]); ++index) {
        if (strcmp(value, packages[index]) == 0)
            return 1;
    }
    return 0;
}

static char *read_android_state(const char *instance, const char *path)
{
    int descriptors[2];
    if (pipe(descriptors) != 0)
        return NULL;
    const pid_t child = fork();
    if (child < 0) {
        close(descriptors[0]);
        close(descriptors[1]);
        return NULL;
    }
    if (child == 0) {
        close(descriptors[0]);
        if (dup2(descriptors[1], STDOUT_FILENO) < 0)
            _exit(126);
        close(descriptors[1]);
        const int null_descriptor = open("/dev/null", O_WRONLY);
        if (null_descriptor >= 0) {
            (void)dup2(null_descriptor, STDERR_FILENO);
            close(null_descriptor);
        }
        if (setgid(0) != 0 || setuid(0) != 0 || clearenv() != 0
                || setenv("PATH", "/usr/bin:/bin", 1) != 0)
            _exit(126);
        if (path)
            execl(lxc_attach_path, "lxc-attach", "-P", "/tmp/appsupport",
                  "-n", instance, "--", "/system/bin/cat", path, (char *)NULL);
        else
            execl(lxc_attach_path, "lxc-attach", "-P", "/tmp/appsupport",
                  "-n", instance, "--", "/system/bin/dumpsys", "activity",
                  "activities", (char *)NULL);
        _exit(126);
    }

    close(descriptors[1]);
    /* Only the fixed lxc-attach child needs root. Read and parse its output
     * with the caller's credentials, never as a privileged JSON parser. */
    if (!drop_privileges()) {
        close(descriptors[0]);
        (void)waitpid(child, NULL, 0);
        return NULL;
    }
    char *data = malloc(MAX_SESSION_BYTES + 1U);
    if (!data) {
        close(descriptors[0]);
        (void)waitpid(child, NULL, 0);
        return NULL;
    }
    size_t used = 0;
    while (used < MAX_SESSION_BYTES) {
        const ssize_t count = read(descriptors[0], data + used,
                                   MAX_SESSION_BYTES - used);
        if (count < 0 && errno == EINTR)
            continue;
        if (count <= 0)
            break;
        used += (size_t)count;
    }
    char overflow;
    const ssize_t extra = read(descriptors[0], &overflow, 1);
    close(descriptors[0]);
    int status = 0;
    if (waitpid(child, &status, 0) < 0 || !WIFEXITED(status)
            || WEXITSTATUS(status) != 0 || extra > 0 || used == 0) {
        free(data);
        return NULL;
    }
    data[used] = '\0';
    return data;
}

static const char *skip_json_space(const char *cursor)
{
    while (*cursor && isspace((unsigned char)*cursor))
        ++cursor;
    return cursor;
}

static int hex_digit(char value)
{
    if (value >= '0' && value <= '9')
        return value - '0';
    if (value >= 'a' && value <= 'f')
        return value - 'a' + 10;
    if (value >= 'A' && value <= 'F')
        return value - 'A' + 10;
    return -1;
}

static int append_utf8(char *output, size_t capacity, size_t *length,
                       unsigned int codepoint)
{
    unsigned char bytes[3];
    size_t count = 0;
    if (codepoint <= 0x7fU) {
        bytes[count++] = (unsigned char)codepoint;
    } else if (codepoint <= 0x7ffU) {
        bytes[count++] = (unsigned char)(0xc0U | (codepoint >> 6));
        bytes[count++] = (unsigned char)(0x80U | (codepoint & 0x3fU));
    } else if (codepoint <= 0xffffU) {
        bytes[count++] = (unsigned char)(0xe0U | (codepoint >> 12));
        bytes[count++] = (unsigned char)(0x80U | ((codepoint >> 6) & 0x3fU));
        bytes[count++] = (unsigned char)(0x80U | (codepoint & 0x3fU));
    } else {
        return 0;
    }
    if (*length + count >= capacity)
        return 0;
    memcpy(output + *length, bytes, count);
    *length += count;
    return 1;
}

static const char *decode_json_string(const char *cursor, char *output,
                                      size_t capacity)
{
    cursor = skip_json_space(cursor);
    if (*cursor != '"' || capacity == 0)
        return NULL;
    ++cursor;
    size_t length = 0;
    while (*cursor && *cursor != '"') {
        if (*cursor != '\\') {
            if (length + 1 >= capacity)
                return NULL;
            output[length++] = *cursor++;
            continue;
        }
        ++cursor;
        unsigned int codepoint;
        {
            const char escaped = *cursor++;
            if (escaped == '"' || escaped == '\\' || escaped == '/')
                codepoint = (unsigned char)escaped;
            else if (escaped == 'b')
                codepoint = '\b';
            else if (escaped == 'f')
                codepoint = '\f';
            else if (escaped == 'n')
                codepoint = '\n';
            else if (escaped == 'r')
                codepoint = '\r';
            else if (escaped == 't')
                codepoint = '\t';
            else if (escaped == 'u') {
                codepoint = 0;
                for (int index = 0; index < 4; ++index) {
                    if (!*cursor)
                        return NULL;
                    const int digit = hex_digit(*cursor++);
                    if (digit < 0)
                        return NULL;
                    codepoint = (codepoint << 4) | (unsigned int)digit;
                }
                // The selected tab id and web origin do not need surrogate
                // pairs or embedded NUL. Reject them rather than truncating.
                if (!codepoint || (codepoint >= 0xd800U && codepoint <= 0xdfffU))
                    return NULL;
            } else {
                return NULL;
            }
        }
        if (!append_utf8(output, capacity, &length, codepoint))
            return NULL;
    }
    if (*cursor != '"')
        return NULL;
    output[length] = '\0';
    return cursor + 1;
}

static const char *json_field_value(const char *start, const char *limit,
                                    const char *field)
{
    char pattern[96];
    if (snprintf(pattern, sizeof(pattern), "\"%s\"", field)
            >= (int)sizeof(pattern))
        return NULL;
    const size_t pattern_length = strlen(pattern);
    const char *cursor = start;
    while ((cursor = strstr(cursor, pattern)) != NULL
            && (!limit || cursor < limit)) {
        const char *value = skip_json_space(cursor + pattern_length);
        if (*value == ':')
            return skip_json_space(value + 1);
        cursor += pattern_length;
    }
    return NULL;
}

static int firefox_active_url(const char *json, char result[2049])
{
    char selected[128];
    const char *selected_value = json_field_value(json, NULL, "selectedTabId");
    if (!selected_value
            || !decode_json_string(selected_value, selected, sizeof(selected)))
        return 0;

    const char *cursor = json;
    while ((cursor = strstr(cursor, "\"session\"")) != NULL) {
        const char *next = strstr(cursor + 9, "\"session\"");
        const char *uuid_value = json_field_value(cursor, next, "uuid");
        const char *url_value = json_field_value(cursor, next, "url");
        char uuid[128];
        char url[2049];
        if (uuid_value && url_value
                && decode_json_string(uuid_value, uuid, sizeof(uuid))
                && strcmp(uuid, selected) == 0
                && decode_json_string(url_value, url, sizeof(url))
                && safe_web_url(url)) {
            memcpy(result, url, strlen(url) + 1);
            return 1;
        }
        cursor += 9;
    }
    return 0;
}

static int android_firefox_origin(const char *package)
{
    char instance[256];
    char path[PATH_MAX];
    if (!caller_name(instance) || !firefox_package(package)
            || snprintf(path, sizeof(path),
                        "/data/user/0/%s/files/"
                        "mozilla_components_session_storage_gecko.json",
                        package) >= (int)sizeof(path))
        return 1;
    char *json = read_android_state(instance, path);
    if (!json)
        return 1;
    char url[2049];
    const int found = firefox_active_url(json, url);
    free(json);
    if (!found)
        return 1;
    puts(url);
    return 0;
}

static int android_foreground_application(void)
{
    char instance[256];
    if (!caller_name(instance))
        return 1;
    char *state = read_android_state(instance, NULL);
    if (!state)
        return 1;
    char package[241] = {0};
    char *line = state;
    while (line && *line) {
        char *next = strchr(line, '\n');
        if (next)
            *next++ = '\0';
        if (strstr(line, "mResumedActivity:")
                || strstr(line, "topResumedActivity=")) {
            const char *slash = strchr(line, '/');
            if (slash) {
                const char *start = slash;
                while (start > line && (isalnum((unsigned char)start[-1])
                        || start[-1] == '_' || start[-1] == '.'))
                    --start;
                const size_t length = (size_t)(slash - start);
                if (length > 2 && length < sizeof(package)
                        && isalpha((unsigned char)*start)
                        && memchr(start, '.', length)) {
                    memcpy(package, start, length);
                    package[length] = '\0';
                    break;
                }
            }
        }
        line = next;
    }
    free(state);
    if (!*package)
        return 1;
    puts(package);
    return 0;
}

static void *load_sqlite(void)
{
    void *library = dlopen("libsqlite3.so.0", RTLD_NOW | RTLD_LOCAL);
    if (!library)
        library = dlopen("libsqlite3.so", RTLD_NOW | RTLD_LOCAL);
    return library;
}

static int sailfish_browser_origin(void)
{
    /* The native browser database belongs to the caller. SQLite must not
     * open user-controlled files with this helper's elevated credential. */
    if (!drop_privileges())
        return 1;
    struct passwd *caller = getpwuid(getuid());
    const char *home = caller ? caller->pw_dir : NULL;
    if (!home || home[0] != '/' || strlen(home) > PATH_MAX - 96)
        return 1;

    char path[PATH_MAX];
    if (snprintf(path, sizeof(path),
                 "%s/.local/share/org.sailfishos/browser/sailfish-browser.sqlite",
                 home) >= (int)sizeof(path))
        return 1;

    void *library = load_sqlite();
    if (!library)
        return 1;

#define LOAD_SYMBOL(name) name##_fn name = (name##_fn)dlsym(library, #name)
    LOAD_SYMBOL(sqlite3_open_v2);
    LOAD_SYMBOL(sqlite3_prepare_v2);
    LOAD_SYMBOL(sqlite3_step);
    LOAD_SYMBOL(sqlite3_column_text);
    LOAD_SYMBOL(sqlite3_finalize);
    LOAD_SYMBOL(sqlite3_close);
#undef LOAD_SYMBOL
    if (!sqlite3_open_v2 || !sqlite3_prepare_v2 || !sqlite3_step
            || !sqlite3_column_text || !sqlite3_finalize || !sqlite3_close) {
        dlclose(library);
        return 1;
    }

    sqlite3 *database = NULL;
    if (sqlite3_open_v2(path, &database,
                        SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, NULL)
            != SQLITE_OK || !database) {
        if (database)
            sqlite3_close(database);
        dlclose(library);
        return 1;
    }

    static const char query[] =
        "SELECT l.url FROM settings s "
        "JOIN tab t ON t.tab_id=CAST(s.value AS INTEGER) "
        "JOIN tab_history h ON h.id=t.tab_history_id "
        "JOIN link l ON l.link_id=h.link_id "
        "WHERE s.name='activeTabId' LIMIT 1";
    sqlite3_stmt *statement = NULL;
    int result = 1;
    if (sqlite3_prepare_v2(database, query, -1, &statement, NULL) == SQLITE_OK
            && statement && sqlite3_step(statement) == SQLITE_ROW) {
        const char *url = (const char *)sqlite3_column_text(statement, 0);
        if (safe_web_url(url)) {
            puts(url);
            result = 0;
        }
    }
    if (statement)
        sqlite3_finalize(statement);
    sqlite3_close(database);
    dlclose(library);
    return result;
}

int main(int argc, char **argv)
{
    if (geteuid() != 0 || getuid() == 0 || !trusted_parent()) {
        fputs("futo-keyboard-browser-origin: untrusted caller\n", stderr);
        return 77;
    }
    if (argc == 1)
        return sailfish_browser_origin();
    if (argc == 3 && strcmp(argv[1], "--android") == 0)
        return android_firefox_origin(argv[2]);
    if (argc == 2 && strcmp(argv[1], "--android-application") == 0)
        return android_foreground_application();
    fputs("Usage: futo-keyboard-browser-origin [--android PACKAGE | --android-application]\n", stderr);
    return 64;
}
