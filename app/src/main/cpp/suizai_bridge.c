#include <jni.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "suizai_core.h"

static void fail(JNIEnv *env, const char *class_name, const char *message) {
    jclass klass = (*env)->FindClass(env, class_name);
    if (klass != NULL) (*env)->ThrowNew(env, klass, message);
}

JNIEXPORT jlong JNICALL
Java_tw_suizai_app_provider_RustFixture_nativeOpen(JNIEnv *env, jobject self,
                                                    jstring locale, jint delay_ms) {
    (void)self;
    if (locale == NULL || delay_ms < 0 || delay_ms > 500) {
        fail(env, "java/lang/IllegalArgumentException", "Invalid locale or delay");
        return 0;
    }
    const char *tag = (*env)->GetStringUTFChars(env, locale, NULL);
    if (tag == NULL) return 0;
    size_t tag_len = strlen(tag);
    uint64_t handle = 0;
    const uint8_t fixture[] = "bridge-welcome";
    int32_t status = tag_len <= 32
        ? suizai_fixture_open(fixture, sizeof(fixture) - 1,
                              (const uint8_t *)tag, tag_len, (uint32_t)delay_ms, &handle)
        : SUIZAI_INVALID_INPUT;
    (*env)->ReleaseStringUTFChars(env, locale, tag);
    if (status != SUIZAI_OK) {
        fail(env, status == SUIZAI_INVALID_INPUT ? "java/lang/IllegalArgumentException"
                                              : "java/io/IOException", "Rust fixture open failed");
    }
    return (jlong)handle;
}

JNIEXPORT jbyteArray JNICALL
Java_tw_suizai_app_provider_RustFixture_nativeRead(JNIEnv *env, jobject self, jlong handle) {
    (void)self;
    size_t length = 0;
    int32_t status = suizai_fixture_read((uint64_t)handle, NULL, 0, &length);
    if (status == SUIZAI_CANCELLED) {
        fail(env, "android/os/OperationCanceledException", "Rust fixture canceled");
        return NULL;
    }
    if (status != SUIZAI_BUFFER_TOO_SMALL || length == 0 || length > 65536) {
        fail(env, "java/io/IOException", "Rust fixture length unavailable");
        return NULL;
    }
    uint8_t *buffer = malloc(length);
    if (buffer == NULL) {
        fail(env, "java/io/IOException", "Rust fixture allocation failed");
        return NULL;
    }
    size_t written = 0;
    status = suizai_fixture_read((uint64_t)handle, buffer, length, &written);
    jbyteArray result = NULL;
    if (status == SUIZAI_OK && written <= length) {
        result = (*env)->NewByteArray(env, (jsize)written);
        if (result != NULL) (*env)->SetByteArrayRegion(env, result, 0, (jsize)written, (jbyte *)buffer);
    } else if (status == SUIZAI_CANCELLED) {
        fail(env, "android/os/OperationCanceledException", "Rust fixture canceled");
    } else {
        fail(env, "java/io/IOException", "Rust fixture read failed");
    }
    free(buffer);
    return result;
}

JNIEXPORT void JNICALL
Java_tw_suizai_app_provider_RustFixture_nativeCancel(JNIEnv *env, jobject self, jlong handle) {
    (void)env; (void)self;
    if (handle != 0) suizai_fixture_cancel((uint64_t)handle);
}

JNIEXPORT void JNICALL
Java_tw_suizai_app_provider_RustFixture_nativeRelease(JNIEnv *env, jobject self, jlong handle) {
    (void)env; (void)self;
    if (handle != 0) suizai_fixture_release((uint64_t)handle);
}

JNIEXPORT jint JNICALL
Java_tw_suizai_app_provider_RustFixture_nativeActiveHandles(JNIEnv *env, jobject self) {
    (void)env; (void)self;
    return (jint)suizai_fixture_active_handles();
}
