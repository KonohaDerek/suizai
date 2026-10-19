package tw.suizai.app

import android.view.View
import android.view.ViewGroup
import android.widget.Spinner
import android.widget.TextView
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class MainActivityLanguageTest {
    @Test
    fun selectedLanguageRendersAcrossRecreateAndRelaunch() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val preferences = context.getSharedPreferences("app-language", 0)
        val original = preferences.getString("language", null)
        val cases = listOf(
            listOf("zh-TW", "語言", "開啟系統檔案選擇器", "開啟儲存空間設定", "建立測試資料夾", "台灣正體中文"),
            listOf("en", "Language", "Open system file picker", "Open storage settings", "Create test folders", "English"),
            listOf("ja", "言語", "システムのファイル選択画面を開く", "ストレージ設定を開く", "テストフォルダーを作成", "日本語")
        )
        try {
            for (case in cases) {
                AppLanguage.select(context, case[0])
                val scenario = ActivityScenario.launch(MainActivity::class.java)
                try {
                    assertRendered(scenario, case)
                    scenario.recreate()
                    assertRendered(scenario, case)
                } finally {
                    scenario.close()
                }
                assertEquals(case[0], AppLanguage.selected(context))
                val relaunched = ActivityScenario.launch(MainActivity::class.java)
                try {
                    assertRendered(relaunched, case)
                } finally {
                    relaunched.close()
                }
            }
        } finally {
            if (original == null) {
                assertTrue(preferences.edit().remove("language").commit())
            } else {
                AppLanguage.select(context, original)
            }
        }
    }

    private fun assertRendered(scenario: ActivityScenario<MainActivity>, expected: List<String>) {
        scenario.onActivity { activity ->
            val texts = mutableListOf<String>()
            var spinner: Spinner? = null
            fun collect(view: View) {
                if (view is TextView) texts += view.text.toString()
                if (view is Spinner) spinner = view
                if (view is ViewGroup) {
                    for (index in 0 until view.childCount) collect(view.getChildAt(index))
                }
            }
            collect(activity.window.decorView)
            expected.subList(1, 5).forEach { assertTrue("Missing $it: $texts", it in texts) }
            assertEquals(expected[5], spinner?.selectedItem?.toString())
        }
    }
}
