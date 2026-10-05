package tw.suizai.app.provider

import java.nio.charset.StandardCharsets
import java.util.Base64

internal object DocumentIdCodec {
    const val ROOT_ID = "root"
    private const val PREFIX = "path:"

    fun encode(relativePath: String): String {
        if (relativePath.isEmpty()) return ROOT_ID
        val bytes = relativePath.toByteArray(StandardCharsets.UTF_8)
        return PREFIX + Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)
    }

    fun decode(documentId: String): String {
        if (documentId == ROOT_ID) return ""
        require(documentId.startsWith(PREFIX)) { "Unsupported document ID" }
        val bytes = Base64.getUrlDecoder().decode(documentId.removePrefix(PREFIX))
        return String(bytes, StandardCharsets.UTF_8)
    }
}
