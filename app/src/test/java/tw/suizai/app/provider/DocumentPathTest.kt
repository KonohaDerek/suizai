package tw.suizai.app.provider

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class DocumentPathTest {
    @Test
    fun renameKeepsDescendantIdentityWithoutTouchingSiblingPaths() {
        assertEquals("renamed", remapPath("folder", "folder", "renamed"))
        assertEquals("renamed/sub/file.txt", remapPath("folder/sub/file.txt", "folder", "renamed"))
        assertNull(remapPath("folder-other/file.txt", "folder", "renamed"))
    }
}
