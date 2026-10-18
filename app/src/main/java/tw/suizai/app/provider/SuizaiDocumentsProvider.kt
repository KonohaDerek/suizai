package tw.suizai.app.provider

import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import android.provider.DocumentsContract.Root
import android.provider.DocumentsProvider
import android.webkit.MimeTypeMap
import tw.suizai.app.R
import tw.suizai.app.AppLanguage
import java.io.File
import java.io.FileNotFoundException
import java.io.IOException
import java.util.UUID

class SuizaiDocumentsProvider : DocumentsProvider() {
    private val rootDirectory: File
        get() = File(requireNotNull(context).filesDir, ROOT_DIRECTORY_NAME)

    override fun onCreate(): Boolean {
        val root = rootDirectory
        if (!root.exists() && !root.mkdirs()) return false
        seedDemoContent(root)
        return true
    }

    override fun queryRoots(projection: Array<out String>?): Cursor {
        val root = rootDirectory
        return MatrixCursor(projection.orDefault(ROOT_PROJECTION)).apply {
            addProjectedRow(
                this,
                listOf(
                    Root.COLUMN_ROOT_ID to ROOT_ID,
                    Root.COLUMN_DOCUMENT_ID to ROOT_ID,
                    Root.COLUMN_TITLE to AppLanguage.localized(requireNotNull(context)).getString(R.string.app_name),
                    Root.COLUMN_SUMMARY to AppLanguage.localized(requireNotNull(context)).getString(R.string.provider_summary),
                    Root.COLUMN_FLAGS to (
                        Root.FLAG_SUPPORTS_CREATE or Root.FLAG_LOCAL_ONLY or Root.FLAG_SUPPORTS_IS_CHILD
                    ),
                    Root.COLUMN_MIME_TYPES to "*/*",
                    Root.COLUMN_AVAILABLE_BYTES to root.usableSpace,
                    Root.COLUMN_ICON to R.drawable.ic_storage
                )
            )
            setNotificationUri(requireNotNull(context).contentResolver, rootsUri())
        }
    }

    @Synchronized
    override fun queryDocument(documentId: String, projection: Array<out String>?): Cursor =
        MatrixCursor(projection.orDefault(DOCUMENT_PROJECTION)).apply {
            includeDocument(this, resolveFile(documentId))
            setNotificationUri(
                requireNotNull(context).contentResolver,
                DocumentsContract.buildDocumentUri(authority(), documentId)
            )
        }

    @Synchronized
    override fun queryChildDocuments(
        parentDocumentId: String,
        projection: Array<out String>?,
        sortOrder: String?
    ): Cursor = MatrixCursor(projection.orDefault(DOCUMENT_PROJECTION)).apply {
        val parent = resolveFile(parentDocumentId)
        if (!parent.isDirectory) throw FileNotFoundException("Not a directory: $parentDocumentId")
        parent.listFiles().orEmpty()
            .sortedWith(compareBy<File>({ !it.isDirectory }, { it.name.lowercase() }))
            .forEach { includeDocument(this, it) }
        setNotificationUri(
            requireNotNull(context).contentResolver,
            DocumentsContract.buildChildDocumentsUri(authority(), parentDocumentId)
        )
    }

    @Synchronized
    override fun isChildDocument(parentDocumentId: String, documentId: String): Boolean {
        val parent = try {
            resolveFile(parentDocumentId).canonicalFile
        } catch (_: FileNotFoundException) {
            return false
        }
        val child = try {
            resolveFile(documentId).canonicalFile
        } catch (_: FileNotFoundException) {
            return false
        }
        if (!parent.isDirectory || parent == child) return false
        return child.path.startsWith(parent.path + File.separator)
    }

    @Synchronized
    override fun openDocument(
        documentId: String,
        mode: String,
        signal: CancellationSignal?
    ): ParcelFileDescriptor {
        signal?.throwIfCanceled()
        val file = resolveFile(documentId)
        if (file.isDirectory) throw FileNotFoundException("Cannot open a directory")
        val parentDocumentId = idForFile(requireNotNull(file.parentFile))
        val writes = 'w' in mode || 'a' in mode
        return ParcelFileDescriptor.open(
            file,
            ParcelFileDescriptor.parseMode(mode),
            Handler(Looper.getMainLooper())
        ) { _ ->
            if (writes) notifyDocumentAndParent(documentId, parentDocumentId)
        }
    }

    @Synchronized
    override fun createDocument(parentDocumentId: String, mimeType: String, displayName: String): String {
        val parent = resolveFile(parentDocumentId)
        if (!parent.isDirectory) throw FileNotFoundException("Parent is not a directory")
        val safeName = sanitizeDisplayName(displayName)
        val target = uniqueChild(parent, safeName)
        val created = if (mimeType == Document.MIME_TYPE_DIR) target.mkdir() else target.createNewFile()
        if (!created) throw FileNotFoundException("Unable to create $displayName")
        val documentId = try {
            idForFile(target)
        } catch (error: IOException) {
            target.delete()
            throw error
        }
        notifyDocumentAndParent(documentId, parentDocumentId)
        return documentId
    }

    @Synchronized
    override fun deleteDocument(documentId: String) {
        val file = resolveFile(documentId)
        if (file.canonicalFile == rootDirectory.canonicalFile) {
            throw FileNotFoundException("Cannot delete provider root")
        }
        val parentDocumentId = idForFile(requireNotNull(file.parentFile))
        val deleted = if (file.isDirectory) file.deleteRecursively() else file.delete()
        if (!deleted) throw FileNotFoundException("Unable to delete $documentId")
        val path = pathForId(documentId)
        val editor = idIndex.edit()
        idIndex.all.forEach { (id, value) ->
            if (value == path || (value is String && value.startsWith("$path/"))) editor.remove(id)
        }
        if (!editor.commit()) throw IOException("Unable to update document index")
        notifyDocumentAndParent(documentId, parentDocumentId)
    }

    @Synchronized
    override fun renameDocument(documentId: String, displayName: String): String? {
        val source = resolveFile(documentId)
        if (source.canonicalFile == rootDirectory.canonicalFile) {
            throw FileNotFoundException("Cannot rename provider root")
        }
        val parent = requireNotNull(source.parentFile)
        val parentDocumentId = idForFile(parent)
        val safeName = sanitizeDisplayName(displayName)
        if (source.name == safeName) return null
        val oldPath = pathForId(documentId)
        val target = uniqueChild(parent, safeName)
        if (!source.renameTo(target)) throw FileNotFoundException("Unable to rename $documentId")
        val newPath = relativePath(target)
        val oldPaths = idIndex.all.mapNotNull { (id, value) ->
            if (value is String && remapPath(value, oldPath, newPath) != null) id to value else null
        }.toMap()
        val editor = idIndex.edit()
        oldPaths.forEach { (id, path) ->
            editor.putString(id, requireNotNull(remapPath(path, oldPath, newPath)))
        }
        if (!editor.commit()) {
            if (target.renameTo(source)) {
                val restore = idIndex.edit()
                oldPaths.forEach { (id, path) -> restore.putString(id, path) }
                if (!restore.commit()) {
                    throw IOException("Filesystem rename rolled back, but index restoration was not persisted")
                }
                throw IOException("Document rename rolled back after index write failure")
            }
            val invalidate = idIndex.edit()
            oldPaths.keys.forEach { invalidate.remove(it) }
            if (!invalidate.commit()) {
                throw IOException("Filesystem rollback failed; document IDs invalidated only in memory")
            }
            throw IOException("Document rename failed to persist and filesystem rollback failed")
        }
        notifyDocumentAndParent(documentId, parentDocumentId)
        return null
    }

    private fun includeDocument(cursor: MatrixCursor, file: File) {
        val isRoot = file.canonicalFile == rootDirectory.canonicalFile
        val flags = if (file.isDirectory) {
            Document.FLAG_DIR_SUPPORTS_CREATE or (if (isRoot) 0 else (
                Document.FLAG_SUPPORTS_DELETE or Document.FLAG_SUPPORTS_RENAME
            ))
        } else {
            Document.FLAG_SUPPORTS_WRITE or
                Document.FLAG_SUPPORTS_DELETE or
                Document.FLAG_SUPPORTS_RENAME
        }

        addProjectedRow(
            cursor,
            listOf(
                Document.COLUMN_DOCUMENT_ID to idForFile(file),
                Document.COLUMN_DISPLAY_NAME to if (isRoot) {
                    AppLanguage.localized(requireNotNull(context)).getString(R.string.app_name)
                } else {
                    file.name
                },
                Document.COLUMN_MIME_TYPE to mimeType(file),
                Document.COLUMN_FLAGS to flags,
                Document.COLUMN_SIZE to if (file.isFile) file.length() else null,
                Document.COLUMN_LAST_MODIFIED to file.lastModified()
            )
        )
    }

    private fun addProjectedRow(cursor: MatrixCursor, values: List<Pair<String, Any?>>) {
        val row = cursor.newRow()
        values.forEach { (columnName, value) ->
            val columnIndex = cursor.getColumnIndex(columnName)
            if (columnIndex >= 0) row.add(columnName, value)
        }
    }

    private val idIndex by lazy {
        requireNotNull(context).getSharedPreferences("document-ids", 0)
    }

    private fun pathForId(documentId: String): String =
        idIndex.getString(documentId, null) ?: throw FileNotFoundException("Unknown document ID")

    private fun resolveFile(documentId: String): File {
        val root = rootDirectory.canonicalFile
        val relative = if (documentId == ROOT_ID) "" else pathForId(documentId)
        val candidate = File(root, relative).canonicalFile
        if (candidate != root && !candidate.path.startsWith(root.path + File.separator)) {
            throw FileNotFoundException("Document escapes provider root")
        }
        if (!candidate.exists()) throw FileNotFoundException("Document not found")
        return candidate
    }

    @Synchronized
    private fun idForFile(file: File): String {
        val root = rootDirectory.canonicalFile
        val candidate = file.canonicalFile
        if (candidate == root) return ROOT_ID
        if (!candidate.path.startsWith(root.path + File.separator)) {
            throw FileNotFoundException("Document escapes provider root")
        }
        if (!candidate.exists()) throw FileNotFoundException("Document not found")
        val path = candidate.relativeTo(root).invariantSeparatorsPath
        idIndex.all.entries.firstOrNull { it.value == path }?.let { return it.key }
        val id = UUID.randomUUID().toString()
        if (!idIndex.edit().putString(id, path).commit()) {
            idIndex.edit().remove(id).commit()
            throw IOException("Unable to update document index")
        }
        return id
    }

    private fun relativePath(file: File): String =
        file.canonicalFile.relativeTo(rootDirectory.canonicalFile).invariantSeparatorsPath

    private fun mimeType(file: File): String {
        if (file.isDirectory) return Document.MIME_TYPE_DIR
        val extension = file.extension.lowercase()
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
            ?: "application/octet-stream"
    }

    private fun sanitizeDisplayName(displayName: String): String {
        val sanitized = displayName.trim().replace('/', '_').replace('\\', '_')
        if (sanitized.isBlank() || sanitized == "." || sanitized == "..") {
            throw FileNotFoundException("Invalid display name")
        }
        return sanitized
    }

    private fun uniqueChild(parent: File, requestedName: String): File {
        var candidate = File(parent, requestedName)
        if (!candidate.exists()) return candidate
        val extensionSeparator = requestedName.lastIndexOf('.').takeIf { it > 0 }
        val base = if (extensionSeparator == null) requestedName else requestedName.substring(0, extensionSeparator)
        val extension = if (extensionSeparator == null) "" else requestedName.substring(extensionSeparator + 1)
        var suffix = 1
        do {
            val name = if (extension.isEmpty()) "$base ($suffix)" else "$base ($suffix).$extension"
            candidate = File(parent, name)
            suffix += 1
        } while (candidate.exists())
        return candidate
    }

    private fun notifyDocumentAndParent(documentId: String, parentDocumentId: String) {
        val appContext = requireNotNull(context)
        appContext.contentResolver.notifyChange(
            DocumentsContract.buildDocumentUri(authority(), documentId),
            null
        )
        appContext.contentResolver.notifyChange(
            DocumentsContract.buildChildDocumentsUri(authority(), parentDocumentId),
            null
        )
    }

    private fun authority(): String = "${requireNotNull(context).packageName}.documents"

    private fun rootsUri(): Uri = DocumentsContract.buildRootsUri(authority())

    private fun seedDemoContent(root: File) {
        val books = File(root, "Books").apply { mkdirs() }
        val sample = File(books, "README.txt")
        if (!sample.exists()) {
            try {
                sample.writeText(AppLanguage.localized(requireNotNull(context)).getString(R.string.provider_readme) + "\n")
            } catch (_: IOException) {
                // The provider remains usable even if demo content cannot be seeded.
            }
        }
    }

    private fun Array<out String>?.orDefault(default: Array<String>): Array<out String> = this ?: default

    private companion object {
        const val ROOT_ID = "root"
        const val ROOT_DIRECTORY_NAME = "suizai-root"

        val ROOT_PROJECTION = arrayOf(
            Root.COLUMN_ROOT_ID,
            Root.COLUMN_MIME_TYPES,
            Root.COLUMN_FLAGS,
            Root.COLUMN_ICON,
            Root.COLUMN_TITLE,
            Root.COLUMN_SUMMARY,
            Root.COLUMN_DOCUMENT_ID,
            Root.COLUMN_AVAILABLE_BYTES
        )

        val DOCUMENT_PROJECTION = arrayOf(
            Document.COLUMN_DOCUMENT_ID,
            Document.COLUMN_MIME_TYPE,
            Document.COLUMN_DISPLAY_NAME,
            Document.COLUMN_LAST_MODIFIED,
            Document.COLUMN_FLAGS,
            Document.COLUMN_SIZE
        )
    }
}

internal fun remapPath(path: String, oldPrefix: String, newPrefix: String): String? = when {
    path == oldPrefix -> newPrefix
    path.startsWith("$oldPrefix/") -> newPrefix + path.removePrefix(oldPrefix)
    else -> null
}
