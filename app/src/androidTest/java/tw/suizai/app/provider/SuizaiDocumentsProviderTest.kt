package tw.suizai.app.provider

import android.content.ContentResolver
import android.database.ContentObserver
import android.net.Uri
import android.os.CancellationSignal
import android.os.OperationCanceledException
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import android.provider.DocumentsContract.Root
import tw.suizai.app.AppLanguage
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.FileNotFoundException
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

@RunWith(AndroidJUnit4::class)
class SuizaiDocumentsProviderTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val resolver: ContentResolver = instrumentation.targetContext.contentResolver
    private val authority = "${instrumentation.targetContext.packageName}.documents"
    private val root = DocumentsContract.buildDocumentUri(authority, "root")
    private val created = mutableListOf<Uri>()

    @Before
    fun grantAccess() {
        instrumentation.uiAutomation.adoptShellPermissionIdentity("android.permission.MANAGE_DOCUMENTS")
    }

    @After
    fun cleanup() {
        created.asReversed().forEach { uri ->
            try { DocumentsContract.deleteDocument(resolver, uri) } catch (_: FileNotFoundException) { }
        }
        instrumentation.uiAutomation.dropShellPermissionIdentity()
    }

    @Test
    fun rootAndProjection() {
        resolver.query(DocumentsContract.buildRootsUri(authority), arrayOf(Root.COLUMN_ROOT_ID, Root.COLUMN_DOCUMENT_ID), null, null, null)!!.use {
            assertArrayEquals(arrayOf(Root.COLUMN_ROOT_ID, Root.COLUMN_DOCUMENT_ID), it.columnNames)
            assertTrue(it.moveToFirst())
            assertEquals("root", it.getString(0))
            assertEquals("root", it.getString(1))
        }
        resolver.query(root, arrayOf(Document.COLUMN_DOCUMENT_ID, Document.COLUMN_MIME_TYPE, "unknown"), null, null, null)!!.use {
            assertArrayEquals(arrayOf(Document.COLUMN_DOCUMENT_ID, Document.COLUMN_MIME_TYPE, "unknown"), it.columnNames)
            assertTrue(it.moveToFirst())
            assertEquals("root", it.getString(0))
            assertEquals(Document.MIME_TYPE_DIR, it.getString(1))
            assertTrue(it.isNull(2))
        }
    }

    @Test
    fun languagePersistsAndProviderRootUpdatesWithoutChangingReadme() {
        val context = instrumentation.targetContext
        val original = AppLanguage.selected(context)
        val rootsUri = DocumentsContract.buildRootsUri(authority)
        resolver.query(rootsUri, null, null, null, null)?.close()
        val readme = context.filesDir.resolve("suizai-root/Books/README.txt")
        val originalReadme = readme.readText()
        val changed = CountDownLatch(1)
        val observer = object : ContentObserver(null) {
            override fun onChange(selfChange: Boolean, uri: Uri?) { changed.countDown() }
        }
        // Always make the observed switch a change, including on Japanese test devices.
        AppLanguage.select(context, "zh-TW")
        resolver.registerContentObserver(rootsUri, false, observer)
        try {
            AppLanguage.select(context, "ja")
            assertEquals("ja", AppLanguage.selected(context))
            assertTrue(changed.await(5, TimeUnit.SECONDS))
            resolver.query(rootsUri, arrayOf(Root.COLUMN_SUMMARY), null, null, null)!!.use {
                assertTrue(it.moveToFirst())
                assertEquals("Phase 0 のローカル模擬ストレージ", it.getString(0))
            }
            AppLanguage.select(context, "en")
            resolver.query(rootsUri, arrayOf(Root.COLUMN_SUMMARY), null, null, null)!!.use {
                assertTrue(it.moveToFirst())
                assertEquals("Phase 0 local mock storage", it.getString(0))
            }
            assertEquals(originalReadme, readme.readText())
        } finally {
            resolver.unregisterContentObserver(observer)
            AppLanguage.select(context, original)
        }
    }

    @Test
    fun firstLaunchUsesTaiwaneseRegardlessOfDeviceLanguage() {
        val context = instrumentation.targetContext
        val preferences = context.getSharedPreferences("app-language", 0)
        val previous = preferences.getString("language", null)
        try {
            assertTrue(preferences.edit().remove("language").commit())
            assertEquals("zh-TW", AppLanguage.selected(context))
            assertEquals("語言", AppLanguage.localized(context).getString(tw.suizai.app.R.string.language_label))
            resolver.query(DocumentsContract.buildRootsUri(authority), arrayOf(Root.COLUMN_SUMMARY), null, null, null)!!.use {
                assertTrue(it.moveToFirst())
                assertEquals("Phase 0 本機模擬儲存空間", it.getString(0))
            }
        } finally {
            val editor = preferences.edit()
            if (previous == null) editor.remove("language") else editor.putString("language", previous)
            assertTrue(editor.commit())
        }
    }

    @Test
    fun createWriteRenameReopenAndDeleteKeepsIds() {
        val dir = create(root, Document.MIME_TYPE_DIR, "contract-dir")
        val file = create(dir, "text/plain", "first.txt")
        resolver.openOutputStream(file, "wt")!!.use { it.write("hello".toByteArray()) }
        val renamed = DocumentsContract.renameDocument(resolver, file, "second.txt")
        assertEquals(file, renamed)
        assertEquals("hello", resolver.openInputStream(file)!!.bufferedReader().use { it.readText() })
        assertEquals("second.txt", displayName(file))
        assertEquals(dir, DocumentsContract.renameDocument(resolver, dir, "renamed-dir"))
        assertEquals("hello", resolver.openInputStream(file)!!.bufferedReader().use { it.readText() })
        assertTrue(childIds(dir).contains(DocumentsContract.getDocumentId(file)))
        assertTrue(DocumentsContract.isChildDocument(resolver, dir, file))
        assertTrue(DocumentsContract.deleteDocument(resolver, dir))
        assertThrows(FileNotFoundException::class.java) { resolver.openInputStream(file)!!.close() }
    }

    @Test
    fun unsafeIdsAndCanceledOpenAreRejected() {
        for (id in listOf("../outside", "path:Li4v", "missing")) {
            assertNull(resolver.query(DocumentsContract.buildDocumentUri(authority, id), null, null, null, null))
        }
        val file = create(root, "text/plain", "cancel.txt")
        val canceled = CancellationSignal().apply { cancel() }
        assertThrows(OperationCanceledException::class.java) { resolver.openFileDescriptor(file, "r", canceled)!!.close() }
    }

    @Test
    fun childCursorReceivesMutationNotification() {
        val childUri = DocumentsContract.buildChildDocumentsUri(authority, "root")
        val changed = CountDownLatch(1)
        val observer = object : ContentObserver(null) {
            override fun onChange(selfChange: Boolean, uri: Uri?) { changed.countDown() }
        }
        resolver.query(childUri, null, null, null, null)!!.use {
            assertEquals(childUri, it.notificationUri)
        }
        resolver.registerContentObserver(childUri, false, observer)
        try {
            create(root, "text/plain", "notify.txt")
            assertTrue(changed.await(5, TimeUnit.SECONDS))
        } finally {
            resolver.unregisterContentObserver(observer)
        }
    }

    @Test
    fun concurrentRenameAndQueriesNeverIssueAnotherId() {
        val prefix = "race-${UUID.randomUUID()}"
        val file = create(root, "text/plain", "$prefix-a.txt")
        val expectedId = DocumentsContract.getDocumentId(file)
        val start = CountDownLatch(1)
        val pool = Executors.newFixedThreadPool(2)
        try {
            val renames = pool.submit {
                start.await()
                repeat(100) { index ->
                    assertEquals(file, DocumentsContract.renameDocument(
                        resolver, file, if (index % 2 == 0) "$prefix-b.txt" else "$prefix-a.txt"
                    ))
                }
            }
            val queries = pool.submit {
                start.await()
                repeat(100) {
                    resolver.query(file, arrayOf(Document.COLUMN_DOCUMENT_ID), null, null, null)!!.use { cursor ->
                        assertTrue(cursor.moveToFirst())
                        assertEquals(expectedId, cursor.getString(0))
                    }
                    resolver.query(
                        DocumentsContract.buildChildDocumentsUri(authority, "root"),
                        arrayOf(Document.COLUMN_DOCUMENT_ID, Document.COLUMN_DISPLAY_NAME), null, null, null
                    )!!.use { cursor ->
                        while (cursor.moveToNext()) {
                            if (cursor.getString(1).startsWith(prefix)) assertEquals(expectedId, cursor.getString(0))
                        }
                    }
                }
            }
            start.countDown()
            renames.get(60, TimeUnit.SECONDS)
            queries.get(60, TimeUnit.SECONDS)
            resolver.openInputStream(file)!!.close()
        } finally {
            pool.shutdownNow()
        }
    }

    private fun create(parent: Uri, mimeType: String, name: String): Uri =
        requireNotNull(DocumentsContract.createDocument(resolver, parent, mimeType, name)).also { created += it }

    private fun displayName(uri: Uri): String = resolver.query(uri, arrayOf(Document.COLUMN_DISPLAY_NAME), null, null, null)!!.use {
        assertTrue(it.moveToFirst())
        it.getString(0)
    }

    private fun childIds(parent: Uri): List<String> = resolver.query(
        DocumentsContract.buildChildDocumentsUri(authority, DocumentsContract.getDocumentId(parent)),
        arrayOf(Document.COLUMN_DOCUMENT_ID), null, null, null
    )!!.use { cursor ->
        buildList { while (cursor.moveToNext()) add(cursor.getString(0)) }
    }
}
