package com.example.dragaim

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.widget.*
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {

    private lateinit var seekDx: SeekBar
    private lateinit var seekDy: SeekBar
    private lateinit var seekDuration: SeekBar
    private lateinit var switchCurve: Switch

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        seekDx = findViewById(R.id.seekDx)
        seekDy = findViewById(R.id.seekDy)
        seekDuration = findViewById(R.id.seekDuration)
        switchCurve = findViewById(R.id.switchCurve)

        // Thiết lập phạm vi thanh trượt
        seekDx.max = 400  // -200 đến 200
        seekDy.max = 400  // 0 đến -400
        seekDuration.max = 700

        val prefs = getSharedPreferences("dragaim", MODE_PRIVATE)
        seekDx.progress = prefs.getInt("dx", 200)
        seekDy.progress = prefs.getInt("dy", 150)
        seekDuration.progress = prefs.getInt("duration", 250)
        switchCurve.isChecked = prefs.getBoolean("curve", false)

        val listener = object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(sb: SeekBar?, p: Int, fromUser: Boolean) {
                if (fromUser) updateSettings()
            }
            override fun onStartTrackingTouch(sb: SeekBar?) {}
            override fun onStopTrackingTouch(sb: SeekBar?) {}
        }
        seekDx.setOnSeekBarChangeListener(listener)
        seekDy.setOnSeekBarChangeListener(listener)
        seekDuration.setOnSeekBarChangeListener(listener)
        switchCurve.setOnCheckedChangeListener { _, _ -> updateSettings() }

        findViewById<Button>(R.id.btnOverlay).setOnClickListener {
            if (!Settings.canDrawOverlays(this)) {
                startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")))
            } else {
                Toast.makeText(this, "Đã có quyền Overlay", Toast.LENGTH_SHORT).show()
            }
        }

        findViewById<Button>(R.id.btnAccess).setOnClickListener {
            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
        }

        findViewById<Button>(R.id.btnStart).setOnClickListener {
            if (!Settings.canDrawOverlays(this) || DragAccessibilityService.instance == null) {
                Toast.makeText(this, "Vui lòng cấp quyền Overlay và Trợ năng trước", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }
            startForegroundService(Intent(this, FloatingService::class.java))
        }

        findViewById<Button>(R.id.btnStop).setOnClickListener {
            stopService(Intent(this, FloatingService::class.java))
        }
    }

    private fun updateSettings() {
        val dx = seekDx.progress - 200
        val dy = -seekDy.progress
        val dur = seekDuration.progress.coerceAtLeast(50)

        FloatingService.dragDx = dx.toFloat()
        FloatingService.dragDy = dy.toFloat()
        FloatingService.dragDuration = dur.toLong()
        FloatingService.useCurve = switchCurve.isChecked

        getSharedPreferences("dragaim", MODE_PRIVATE).edit().apply {
            putInt("dx", seekDx.progress)
            putInt("dy", seekDy.progress)
            putInt("duration", dur)
            putBoolean("curve", switchCurve.isChecked)
            apply()
        }
    }
}
