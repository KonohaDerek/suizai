#ifndef SUIZAI_CORE_H
#define SUIZAI_CORE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ABI v1: values are fixed. All strings and fixture bytes are UTF-8. */
typedef enum {
    SUIZAI_OK = 0,
    SUIZAI_INVALID_INPUT = 1,
    SUIZAI_INVALID_HANDLE = 2,
    SUIZAI_CANCELLED = 3,
    SUIZAI_BUFFER_TOO_SMALL = 4,
    SUIZAI_INTERNAL_ERROR = 5
} SuizaiStatus;

/* Only fixture_id "bridge-welcome" exists. locale accepts UTF-8 up to 32
 * bytes: en/en-*, ja/ja-*, or zh-TW; all other valid values default zh-TW.
 * A null locale with length zero also defaults zh-TW. delay_ms is 0..500.
 * out_handle must point to writable uint64_t storage and is zeroed on error.
 * A successful handle must be released exactly once by its owner. */
int32_t suizai_fixture_open(const uint8_t *fixture_id, size_t fixture_id_len,
                            const uint8_t *locale, size_t locale_len,
                            uint32_t delay_ms, uint64_t *out_handle);

/* The caller owns out and out_len; they must not overlap. out_len is set to 0 on entry; on
 * BUFFER_TOO_SMALL it receives the required byte count. out may be null only
 * when capacity is zero. capacity must not exceed 65536. On success bytes are
 * copied to out without a terminator. No caller pointer is retained. */
int32_t suizai_fixture_read(uint64_t handle, uint8_t *out, size_t capacity,
                            size_t *out_len);

/* May be called from another thread. A read that observes cancellation at its
 * final check returns CANCELLED with out_len=0; otherwise that read succeeds.
 * Releasing removes the handle and cancels an in-flight read.
 * Calls after release return INVALID_HANDLE. No registry lock spans a wait or
 * output copy. Run potentially blocking read on a native background queue. */
int32_t suizai_fixture_cancel(uint64_t handle);
int32_t suizai_fixture_release(uint64_t handle);

/* Deterministic diagnostic metric for fixture bridge leak tests. */
size_t suizai_fixture_active_handles(void);

/* All pointer/length pairs must designate accessible memory for their full
 * length. out_handle/out_len must point to writable storage. Violation is
 * caller undefined behavior and cannot be diagnosed by this C ABI. */

#ifdef __cplusplus
}
#endif

#endif
