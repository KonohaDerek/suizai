package tw.suizai.app.provider

internal object RustFixture {
    init { System.loadLibrary("suizai_bridge") }

    external fun nativeOpen(locale: String, delayMs: Int): Long
    external fun nativeRead(handle: Long): ByteArray
    external fun nativeCancel(handle: Long)
    external fun nativeRelease(handle: Long)
    external fun nativeActiveHandles(): Int
}
