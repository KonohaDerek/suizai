package tw.suizai.app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.Spinner
import android.widget.ArrayAdapter
import android.widget.TextView

class MainActivity : Activity() {
    override fun attachBaseContext(newBase: Context) {
        super.attachBaseContext(AppLanguage.localized(newBase))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val density = resources.displayMetrics.density
        val padding = (24 * density).toInt()

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
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

        layout.addView(TextView(this).apply { text = getString(R.string.language_label) })
        val languageSelector = Spinner(this)
        languageSelector.adapter = ArrayAdapter(
            this, android.R.layout.simple_spinner_dropdown_item,
            listOf("台灣正體中文", "English", "日本語")
        )
        languageSelector.setSelection(AppLanguage.tags.indexOf(AppLanguage.selected(this)))
        languageSelector.onItemSelectedListener = object : android.widget.AdapterView.OnItemSelectedListener {
            override fun onNothingSelected(parent: android.widget.AdapterView<*>?) = Unit
            override fun onItemSelected(parent: android.widget.AdapterView<*>?, view: android.view.View?, position: Int, id: Long) {
                val tag = AppLanguage.tags[position]
                if (tag != AppLanguage.selected(this@MainActivity)) {
                    AppLanguage.select(this@MainActivity, tag)
                    recreate()
                }
            }
        }
        layout.addView(languageSelector)

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
            text = getString(R.string.open_storage_settings)
            setOnClickListener { startActivity(Intent(Settings.ACTION_INTERNAL_STORAGE_SETTINGS)) }
        }, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)

        layout.addView(TextView(this).apply {
            text = getString(R.string.external_probe_title)
            textSize = 22f
            setTextColor(0xFF12372F.toInt())
            setPadding(0, (24 * density).toInt(), 0, (8 * density).toInt())
        })
        layout.addView(TextView(this).apply {
            text = getString(R.string.external_probe_description)
            textSize = 16f
            setTextColor(0xFF35574F.toInt())
        })

        val report = TextView(this).apply {
            text = getString(R.string.external_probe_pending)
            textSize = 14f
            setTextColor(0xFF12372F.toInt())
            setTextIsSelectable(true)
            setPadding(0, (16 * density).toInt(), 0, 0)
        }
        val probeButton = Button(this).apply { text = getString(R.string.external_probe_button) }
        probeButton.setOnClickListener {
            probeButton.isEnabled = false
            languageSelector.isEnabled = false
            val fixtureContent = getString(R.string.external_probe_fixture)
            Thread {
                val results = getExternalFilesDirs(null).mapIndexed { index, dir ->
                    if (dir == null) {
                        getString(R.string.external_probe_unavailable, index + 1)
                    } else {
                        val state = Environment.getExternalStorageState(dir)
                        val stateLabel = if (state == Environment.MEDIA_MOUNTED) {
                            getString(R.string.external_probe_state_mounted, state)
                        } else {
                            getString(R.string.external_probe_state_unavailable, state)
                        }
                        val location = getString(R.string.external_probe_volume, index + 1, stateLabel, dir.absolutePath)
                        if (state != Environment.MEDIA_MOUNTED) location
                        else try {
                            "$location\n${getString(R.string.external_probe_created, ExternalStorageProbe.create(dir, fixtureContent).absolutePath)}"
                        } catch (error: Exception) {
                            val detail = if (error is ExternalStorageProbe.Failure) {
                                if (error.path == null) getString(error.messageRes)
                                else getString(error.messageRes, error.path.absolutePath)
                            } else getString(R.string.external_probe_unknown_error)
                            "$location\n${getString(R.string.external_probe_failed, detail)}"
                        }
                    }
                }
                runOnUiThread {
                    report.text = results.joinToString("\n\n")
                    probeButton.isEnabled = true
                    languageSelector.isEnabled = true
                }
            }.start()
        }
        layout.addView(probeButton, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        layout.addView(report, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)

        setContentView(ScrollView(this).apply { addView(layout) })
    }
}
