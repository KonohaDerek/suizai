package tw.suizai.app

import java.io.File
import java.io.IOException
import java.nio.file.Files
import java.util.UUID

/** Creates a fresh fixture below a trusted app-specific external-files directory. */
internal object ExternalStorageProbe {
    class Failure(val messageRes: Int, val path: File? = null) : IOException()

    fun create(root: File, fileContent: String): File {
        val rootPath = root.toPath()
        if (Files.isSymbolicLink(rootPath) || !Files.isDirectory(rootPath)) {
            throw Failure(R.string.probe_error_unavailable)
        }
        val parent = rootPath.resolve("suizai-external-probe")
        if (Files.exists(parent) && (Files.isSymbolicLink(parent) || !Files.isDirectory(parent))) {
            throw Failure(R.string.probe_error_occupied)
        }
        if (!Files.exists(parent)) Files.createDirectory(parent)

        // Each run gets a new child; existing test or user files are never replaced.
        val run = Files.createDirectory(parent.resolve("run-${UUID.randomUUID()}"))
        val draft = run.resolve("self-check.tmp")
        val renamed = run.resolve("self-check-renamed.tmp")
        try {
            Files.write(draft, fileContent.toByteArray(Charsets.UTF_8))
            Files.move(draft, renamed)
            if (String(Files.readAllBytes(renamed), Charsets.UTF_8) != fileContent) {
                throw Failure(R.string.probe_error_mismatch)
            }
            Files.delete(renamed)
            Files.write(run.resolve("SUIZAI-test.txt"), fileContent.toByteArray(Charsets.UTF_8))
        } catch (error: Exception) {
            // Keep the newly created run for inspection; never delete or alter an older run.
            throw Failure(R.string.probe_error_file_check, run.toFile()).apply { initCause(error) }
        }
        return run.toFile()
    }
}
