package tw.suizai.app.provider

import android.content.Context
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract

internal object RustFixtureDocument {
    const val ID = "rust:bridge-welcome"
    private const val PREFS = "rust-fixture"

    fun enabled(context: Context): Boolean =
        context.getSharedPreferences(PREFS, 0).getBoolean("enabled", false)

    fun setEnabled(context: Context, enabled: Boolean) {
        check(context.getSharedPreferences(PREFS, 0).edit().putBoolean("enabled", enabled).commit())
        context.contentResolver.notifyChange(
            DocumentsContract.buildChildDocumentsUri("${context.packageName}.documents", "root"), null
        )
    }

    fun openCancelable(context: Context, signal: CancellationSignal): ParcelFileDescriptor {
        val uri = DocumentsContract.buildDocumentUri("${context.packageName}.documents", ID)
        // ContentResolver's read-only typed path drops the signal in DocumentsProvider.
        return requireNotNull(context.contentResolver.acquireContentProviderClient(uri)).use { client ->
            requireNotNull(client.openFile(uri, "r", signal))
        }
    }
}
