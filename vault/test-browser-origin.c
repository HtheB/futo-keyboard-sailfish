#define main browser_origin_main
#include "futo-keyboard-browser-origin.c"
#undef main
#include <assert.h>

int main(void)
{
    char output[2049];
    const char *state = "{\"selectedTabId\":\"second\",\"tabs\":["
        "{\"session\":{\"uuid\":\"first\",\"url\":\"https://wrong.test\"}},"
        "{\"session\":{\"url\":\"https://right.test/path\",\"uuid\":\"second\"}}]}";
    assert(firefox_active_url(state, output));
    assert(strcmp(output, "https://right.test/path") == 0);
    assert(!firefox_active_url("{\"selectedTabId\":\"missing\"}", output));
    assert(!safe_web_url("file:///private"));
    assert(!safe_web_url("https://site.test\nmalformed"));
    assert(!decode_json_string("\"\\u", output, sizeof(output)));
    assert(!decode_json_string("\"\\u1", output, sizeof(output)));
    assert(!decode_json_string("\"\\u12", output, sizeof(output)));
    assert(!decode_json_string("\"\\u123", output, sizeof(output)));
    assert(!decode_json_string("\"\\u0000\"", output, sizeof(output)));
    assert(!decode_json_string("\"\\ud800\"", output, sizeof(output)));
    assert(decode_json_string("\"https:\\/\\/site.test\"", output, sizeof(output)));
    assert(strcmp(output, "https://site.test") == 0);
    puts("Browser-origin parser checks passed");
    return 0;
}
