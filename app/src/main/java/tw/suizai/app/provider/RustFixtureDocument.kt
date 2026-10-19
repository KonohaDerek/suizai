package tw.suizai.app.provider

import android.content.Context
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
}
