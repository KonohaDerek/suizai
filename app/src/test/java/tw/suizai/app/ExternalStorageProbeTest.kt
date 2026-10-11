package tw.suizai.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.IOException
import java.nio.file.Files

class ExternalStorageProbeTest {
    @get:Rule val temporary = TemporaryFolder()

    @Test fun rerunKeepsEarlierFiles() {
        val root = temporary.newFolder("external-files")
        val first = ExternalStorageProbe.create(root)
        val userFile = first.resolve("my-notes.txt")
        userFile.writeText("keep me")

        val second = ExternalStorageProbe.create(root)
        assertNotEquals(first, second)
        assertEquals("keep me", userFile.readText())
        assertEquals("Disposable SUIZAI test file\n", second.resolve("SUIZAI-test.txt").readText())
        assertTrue(first.isDirectory)
    }

    @Test fun rejectsInvalidOrOccupiedPathsWithoutChangingThem() {
        val root = temporary.newFolder("external-files")
        val occupied = root.resolve("suizai-external-probe")
        occupied.writeText("existing data")
        assertThrows(IOException::class.java) { ExternalStorageProbe.create(root) }
        assertEquals("existing data", occupied.readText())

        val notDirectory = temporary.newFile("not-a-directory")
        assertThrows(IOException::class.java) { ExternalStorageProbe.create(notDirectory) }
        assertTrue(Files.isRegularFile(notDirectory.toPath()))
    }
}
