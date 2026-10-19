package tw.suizai.app.provider

import android.content.ContentResolver
import android.os.CancellationSignal
import android.os.Debug
import android.os.OperationCanceledException
import android.os.ParcelFileDescriptor
import android.os.SystemClock
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import tw.suizai.app.AppLanguage
import java.io.FileNotFoundException
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

@RunWith(AndroidJUnit4::class)
class RustFixtureProviderTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = instrumentation.targetContext
    private val resolver: ContentResolver = context.contentResolver
    private val authority = "${context.packageName}.documents"
    private val fixture = DocumentsContract.buildDocumentUri(authority, RustFixtureDocument.ID)
    private val root = DocumentsContract.buildDocumentUri(authority, "root")
    private var originalLanguage = "zh-TW"
    private var originalEnabled = false

    @Before fun setup() {
        instrumentation.uiAutomation.adoptShellPermissionIdentity("android.permission.MANAGE_DOCUMENTS")
        originalLanguage = AppLanguage.selected(context)
        originalEnabled = RustFixtureDocument.enabled(context)
        RustFixtureDocument.setEnabled(context, true)
    }

    @After fun cleanup() {
        try {
            AppLanguage.select(context, originalLanguage)
            RustFixtureDocument.setEnabled(context, originalEnabled)
            val deadline = SystemClock.elapsedRealtime() + 3000
            while (RustFixture.nativeActiveHandles() != 0 && SystemClock.elapsedRealtime() < deadline) {
                Thread.sleep(10)
            }
            assertEquals(0, RustFixture.nativeActiveHandles())
        } finally {
            instrumentation.uiAutomation.dropShellPermissionIdentity()
        }
    }

    @Test fun readAllLocalesThroughProviderAndKeepFixtureReadOnly() {
        val expected = mapOf(
            "zh-TW" to "SUIZAI 共用核心測試檔案\n",
            "en" to "SUIZAI shared core test file\n",
            "ja" to "SUIZAI 共通コアのテストファイル\n"
        )
        for ((locale, text) in expected) {
            AppLanguage.select(context, locale)
            assertEquals(text, read(fixture))
        }
        resolver.query(fixture, arrayOf(Document.COLUMN_DOCUMENT_ID, Document.COLUMN_FLAGS), null, null, null)!!.use {
            assertTrue(it.moveToFirst())
            assertEquals(RustFixtureDocument.ID, it.getString(0))
            assertEquals(0, it.getInt(1))
        }
        assertTrue(childIds(root).contains(RustFixtureDocument.ID))
        assertThrows(FileNotFoundException::class.java) { resolver.openFileDescriptor(fixture, "w")!!.close() }
    }

    @Test fun disabledAndInvalidDocumentsNeverOpen() {
        RustFixtureDocument.setEnabled(context, false)
        assertFalse(childIds(root).contains(RustFixtureDocument.ID))
        assertThrows(FileNotFoundException::class.java) { resolver.openFileDescriptor(fixture, "r")!!.close() }
        val unknown = DocumentsContract.buildDocumentUri(authority, "rust:unknown")
        assertThrows(FileNotFoundException::class.java) { resolver.openFileDescriptor(unknown, "r")!!.close() }
    }

    @Test fun cancellationBeforeAndDuringReadReleasesHandle() {
        val canceled = CancellationSignal().apply { cancel() }
        assertThrows(OperationCanceledException::class.java) {
            resolver.openFileDescriptor(fixture, "r", canceled)!!.close()
        }
        val signal = CancellationSignal()
        val pool = Executors.newSingleThreadExecutor()
        try {
            val result = pool.submit<Boolean> {
                try {
                    resolver.openFileDescriptor(fixture, "r", signal)!!.let { descriptor ->
                        ParcelFileDescriptor.AutoCloseInputStream(descriptor).use { it.readBytes() }
                    }
                    false
                } catch (_: OperationCanceledException) {
                    true
                }
            }
            val deadline = SystemClock.elapsedRealtime() + 3000
            while (RustFixture.nativeActiveHandles() == 0 && SystemClock.elapsedRealtime() < deadline) {
                Thread.sleep(5)
            }
            assertTrue("Rust read never opened a handle", RustFixture.nativeActiveHandles() > 0)
            signal.cancel()
            assertTrue(result.get(3, TimeUnit.SECONDS))
        } finally {
            pool.shutdownNow()
        }
    }

    @Test fun singleReadMeasurementLogsNativeAndRustWorkloads() {
        val books = childId(root, "Books")
        val nativeReadme = DocumentsContract.buildDocumentUri(authority, childId(
            DocumentsContract.buildDocumentUri(authority, books), "README.txt"))
        measure("native_readme", nativeReadme)
        measure("rust_fixture", fixture)
        measureZeroDelayBridge()
    }

    private fun measure(source: String, uri: android.net.Uri) {
        val before = Debug.MemoryInfo().also { Debug.getMemoryInfo(it) }.totalPss
        val start = SystemClock.elapsedRealtimeNanos()
        val bytes = resolver.openFileDescriptor(uri, "r")!!.let { descriptor ->
            ParcelFileDescriptor.AutoCloseInputStream(descriptor).use { it.readBytes() }
        }
        val elapsedMs = (SystemClock.elapsedRealtimeNanos() - start) / 1_000_000.0
        val after = Debug.MemoryInfo().also { Debug.getMemoryInfo(it) }.totalPss
        assertTrue(bytes.isNotEmpty())
        val delay = if (source == "rust_fixture") 500 else 0
        Log.i("SUIZAI_METRIC", "workload=single_content_resolver_read source=$source configured_delay_ms=$delay bytes=${bytes.size} elapsed_ms=$elapsedMs pss_before_kb=$before pss_after_kb=$after")
    }

    private fun measureZeroDelayBridge() {
        val payload = "SUIZAI shared core test file\n".toByteArray(Charsets.UTF_8)
        fun sample(source: String, block: () -> ByteArray) {
            val before = Debug.MemoryInfo().also { Debug.getMemoryInfo(it) }.totalPss
            val start = SystemClock.elapsedRealtimeNanos()
            repeat(100) { assertArrayEquals(payload, block()) }
            val elapsedMs = (SystemClock.elapsedRealtimeNanos() - start) / 1_000_000.0
            val after = Debug.MemoryInfo().also { Debug.getMemoryInfo(it) }.totalPss
            Log.i("SUIZAI_METRIC", "workload=utf8_fixture_copy source=$source iterations=100 configured_delay_ms=0 bytes_each=${payload.size} elapsed_ms=$elapsedMs pss_before_kb=$before pss_after_kb=$after")
        }
        sample("java_byte_copy") { payload.copyOf() }
        sample("rust_ffi_open_read_release") {
            val handle = RustFixture.nativeOpen("en", 0)
            try { RustFixture.nativeRead(handle) } finally { RustFixture.nativeRelease(handle) }
        }
        assertEquals(0, RustFixture.nativeActiveHandles())
    }

    private fun read(uri: android.net.Uri): String = resolver.openFileDescriptor(uri, "r")!!.let { descriptor ->
        ParcelFileDescriptor.AutoCloseInputStream(descriptor).use { input ->
            input.bufferedReader(Charsets.UTF_8).readText()
        }
    }

    private fun childId(parent: android.net.Uri, name: String): String {
        val parentId = DocumentsContract.getDocumentId(parent)
        return resolver.query(DocumentsContract.buildChildDocumentsUri(authority, parentId),
            arrayOf(Document.COLUMN_DOCUMENT_ID, Document.COLUMN_DISPLAY_NAME), null, null, null)!!.use { cursor ->
            var id: String? = null
            while (cursor.moveToNext()) if (cursor.getString(1) == name) id = cursor.getString(0)
            requireNotNull(id) { "Missing child: $name" }
        }
    }

    private fun childIds(parent: android.net.Uri): List<String> = resolver.query(
        DocumentsContract.buildChildDocumentsUri(authority, DocumentsContract.getDocumentId(parent)),
        arrayOf(Document.COLUMN_DOCUMENT_ID), null, null, null)!!.use { cursor ->
        buildList { while (cursor.moveToNext()) add(cursor.getString(0)) }
    }
}
