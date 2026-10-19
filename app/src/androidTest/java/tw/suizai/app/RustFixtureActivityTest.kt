package tw.suizai.app

import android.os.SystemClock
import android.os.CancellationSignal
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.TextView
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import tw.suizai.app.provider.RustFixture
import tw.suizai.app.provider.RustFixtureDocument

@RunWith(AndroidJUnit4::class)
class RustFixtureActivityTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    @Test fun buttonsReadCancelAndDestroyWithoutLeakingHandles() {
        val originalLanguage = AppLanguage.selected(context)
        val originalEnabled = RustFixtureDocument.enabled(context)
        try {
            RustFixtureDocument.setEnabled(context, true)
            val payloads = mapOf(
                "zh-TW" to "SUIZAI 共用核心測試檔案",
                "en" to "SUIZAI shared core test file",
                "ja" to "SUIZAI 共通コアのテストファイル"
            )
            for ((language, payload) in payloads) {
                AppLanguage.select(context, language)
                ActivityScenario.launch(MainActivity::class.java).use { scenario ->
                    tap(scenario, R.string.rust_read)
                    awaitText(scenario, AppLanguage.localized(context).getString(R.string.rust_success, payload))
                    tap(scenario, R.string.rust_test_cancel)
                    awaitText(scenario, AppLanguage.localized(context).getString(R.string.rust_canceled))
                }
            }

            AppLanguage.select(context, "zh-TW")
            val scenario = ActivityScenario.launch(MainActivity::class.java)
            var activeSignal: CancellationSignal? = null
            try {
                tap(scenario, R.string.rust_read)
                scenario.onActivity { activity ->
                    // Observe the actual operation without exposing a production test API.
                    val field = MainActivity::class.java.getDeclaredField("activeRustRead")
                    field.isAccessible = true
                    activeSignal = field.get(activity) as CancellationSignal
                }
                awaitHandles(active = true)
            } finally {
                scenario.close()
            }
            assertTrue("Activity destruction must cancel its active read", activeSignal?.isCanceled == true)
            awaitHandles(active = false)
        } finally {
            AppLanguage.select(context, originalLanguage)
            RustFixtureDocument.setEnabled(context, originalEnabled)
        }
    }

    private fun tap(scenario: ActivityScenario<MainActivity>, label: Int) {
        scenario.onActivity { activity ->
            val button = descendants(activity.window.decorView)
                .filterIsInstance<Button>()
                .firstOrNull { it.text == activity.getString(label) }
            assertTrue("Missing or disabled button: ${activity.getString(label)}", button?.isEnabled == true)
            button!!.performClick()
        }
    }

    private fun awaitText(scenario: ActivityScenario<MainActivity>, expected: String) {
        val deadline = SystemClock.elapsedRealtime() + 5000
        var found = false
        while (!found && SystemClock.elapsedRealtime() < deadline) {
            scenario.onActivity { activity ->
                found = descendants(activity.window.decorView)
                    .filterIsInstance<TextView>()
                    .any { it.text.toString() == expected }
            }
            if (!found) Thread.sleep(10)
        }
        assertTrue("UI did not show: $expected", found)
    }

    private fun awaitHandles(active: Boolean) {
        val deadline = SystemClock.elapsedRealtime() + 3000
        while ((RustFixture.nativeActiveHandles() > 0) != active && SystemClock.elapsedRealtime() < deadline) {
            Thread.sleep(10)
        }
        assertEquals("Unexpected Rust handle state", active, RustFixture.nativeActiveHandles() > 0)
    }

    private fun descendants(root: View): Sequence<View> = sequence {
        yield(root)
        if (root is ViewGroup) {
            for (index in 0 until root.childCount) yieldAll(descendants(root.getChildAt(index)))
        }
    }
}
