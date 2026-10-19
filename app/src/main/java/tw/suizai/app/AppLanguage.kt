package tw.suizai.app

import android.content.Context
import android.content.res.Configuration
import android.provider.DocumentsContract
import java.util.Locale

internal object AppLanguage {
    private const val PREFS = "app-language"
    private const val KEY = "language"
    const val DEFAULT = "zh-TW"
    val tags = listOf(DEFAULT, "en", "ja")

    fun selected(context: Context): String = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        .getString(KEY, DEFAULT)?.takeIf { it in tags } ?: DEFAULT

    fun localized(context: Context): Context {
        val configuration = Configuration(context.resources.configuration)
        configuration.setLocale(Locale.forLanguageTag(selected(context)))
        return context.createConfigurationContext(configuration)
    }

    fun select(context: Context, tag: String) {
        require(tag in tags)
        if (selected(context) == tag) return
        check(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, tag).commit())
        context.contentResolver.notifyChange(
            DocumentsContract.buildRootsUri("${context.packageName}.documents"), null
        )
    }
}
