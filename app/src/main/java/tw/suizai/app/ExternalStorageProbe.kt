package tw.suizai.app

import java.io.File
import java.io.IOException
import java.nio.file.Files
import java.util.UUID

/** Creates a fresh fixture below a trusted app-specific external-files directory. */
internal object ExternalStorageProbe {
    fun create(root: File): File {
        val rootPath = root.toPath()
        if (Files.isSymbolicLink(rootPath) || !Files.isDirectory(rootPath)) {
            throw IOException("App storage directory is unavailable")
        }
        val parent = rootPath.resolve("suizai-external-probe")
        if (Files.exists(parent) && (Files.isSymbolicLink(parent) || !Files.isDirectory(parent))) {
            throw IOException("Test folder name is already in use")
        }
        if (!Files.exists(parent)) Files.createDirectory(parent)

        // Each run gets a new child; existing test or user files are never replaced.
        val run = Files.createDirectory(parent.resolve("run-${UUID.randomUUID()}"))
        val draft = run.resolve("self-check.tmp")
        val renamed = run.resolve("self-check-renamed.tmp")
        try {
            Files.write(draft, "SUIZAI external storage check\n".toByteArray())
            Files.move(draft, renamed)
            if (String(Files.readAllBytes(renamed)) != "SUIZAI external storage check\n") {
                throw IOException("Reopened file did not match")
            }
            Files.delete(renamed)
            Files.write(run.resolve("SUIZAI-test.txt"), "Disposable SUIZAI test file\n".toByteArray())
        } catch (error: Exception) {
            // Keep the newly created run for inspection; never delete or alter an older run.
            throw IOException("Test folder created, but the file check failed at $run", error)
        }
        return run.toFile()
    }
}
