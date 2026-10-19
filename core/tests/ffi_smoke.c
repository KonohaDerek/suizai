#include "suizai_core.h"

#include <assert.h>
#include <string.h>

static void check_fixture(const char *locale, const char *expected) {
    const char *id = "bridge-welcome";
    uint64_t handle = 0;
    assert(suizai_fixture_open((const uint8_t *)id, strlen(id),
                               (const uint8_t *)locale, strlen(locale), 0,
                               &handle) == SUIZAI_OK);
    assert(handle != 0);
    size_t length = 0;
    assert(suizai_fixture_read(handle, NULL, 0, &length) == SUIZAI_BUFFER_TOO_SMALL);
    assert(length == strlen(expected));
    uint8_t output[128] = {0};
    assert(suizai_fixture_read(handle, output, sizeof(output), &length) == SUIZAI_OK);
    assert(length == strlen(expected));
    assert(memcmp(output, expected, length) == 0);
    assert(suizai_fixture_release(handle) == SUIZAI_OK);
    assert(suizai_fixture_release(handle) == SUIZAI_INVALID_HANDLE);
}

int main(void) {
    check_fixture("zh-TW", "SUIZAI 共用核心測試檔案\n");
    check_fixture("en", "SUIZAI shared core test file\n");
    check_fixture("ja", "SUIZAI 共通コアのテストファイル\n");
    assert(suizai_fixture_active_handles() == 0);
    return 0;
}
