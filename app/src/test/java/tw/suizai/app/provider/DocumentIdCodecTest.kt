package tw.suizai.app.provider

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class DocumentIdCodecTest {
    @Test
    fun rootRoundTrip() {
        assertEquals("", DocumentIdCodec.decode(DocumentIdCodec.encode("")))
    }

    @Test
    fun unicodePathRoundTrip() {
        val path = "Books/台灣漫畫/第一冊.epub"
        assertEquals(path, DocumentIdCodec.decode(DocumentIdCodec.encode(path)))
    }

    @Test
    fun rejectsUnknownDocumentId() {
        assertThrows(IllegalArgumentException::class.java) {
            DocumentIdCodec.decode("unknown")
        }
    }
}
