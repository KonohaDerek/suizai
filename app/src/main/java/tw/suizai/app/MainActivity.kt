package tw.suizai.app

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class MainActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val density = resources.displayMetrics.density
        val padding = (24 * density).toInt()

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(padding, padding, padding, padding)
            setBackgroundColor(0xFFF4FBF8.toInt())
        }

        layout.addView(TextView(this).apply {
            text = getString(R.string.poc_title)
            textSize = 28f
            setTextColor(0xFF12372F.toInt())
        })

        layout.addView(TextView(this).apply {
            text = getString(R.string.poc_description)
            textSize = 16f
            setTextColor(0xFF35574F.toInt())
            setPadding(0, (16 * density).toInt(), 0, (24 * density).toInt())
        })

        layout.addView(Button(this).apply {
            text = getString(R.string.open_picker)
            setOnClickListener {
                startActivity(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "*/*"
                })
            }
        }, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)

        layout.addView(Button(this).apply {
            text = "Open storage settings"
            setOnClickListener { startActivity(Intent(Settings.ACTION_INTERNAL_STORAGE_SETTINGS)) }
        }, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)

        setContentView(layout)
    }
}
