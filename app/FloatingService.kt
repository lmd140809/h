package com.example.dragaim

import android.app.*
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.*
import androidx.core.app.NotificationCompat
import kotlin.math.abs

class FloatingService : Service() {

    private lateinit var windowManager: WindowManager
    private lateinit var floatingView: View
    private lateinit var params: WindowManager.LayoutParams

    companion object {
        const val CHANNEL_ID = "drag_aim_channel"
        const val NOTIF_ID = 1
        var dragDx = 0f
        var dragDy = -300f
        var dragDuration = 250L
        var useCurve = false
    }

    override fun onCreate() {
        super.onCreate()
        startForeground(NOTIF_ID, buildNotification())
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        setupFloatingButton()
    }

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "DragAim Service",
                NotificationManager.IMPORTANCE_LOW
            )
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("DragAim đang chạy")
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setOngoing(true)
            .build()
    }

    private fun setupFloatingButton() {
        floatingView = LayoutInflater.from(this).inflate(R.layout.floating_button, null)
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            WindowManager.LayoutParams.TYPE_PHONE

        params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 50; y = 400
        }

        floatingView.setOnTouchListener(object : View.OnTouchListener {
            private var initX = 0; private var initY = 0
            private var touchX = 0f; private var touchY = 0f
            private var moved = false

            override fun onTouch(v: View, e: MotionEvent): Boolean {
                when (e.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initX = params.x; initY = params.y
                        touchX = e.rawX; touchY = e.rawY
                        moved = false; v.alpha = 0.7f
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = e.rawX - touchX; val dy = e.rawY - touchY
                        if (abs(dx) > 15 || abs(dy) > 15) {
                            moved = true
                            params.x = initX + dx.toInt()
                            params.y = initY + dy.toInt()
                            windowManager.updateViewLayout(floatingView, params)
                        }
                    }
                    MotionEvent.ACTION_UP -> {
                        v.alpha = 1f
                        if (!moved) triggerAim()
                    }
                }
                return true
            }
        })
        windowManager.addView(floatingView, params)
    }

    private fun triggerAim() {
        val svc = DragAccessibilityService.instance ?: return
        val centerX = params.x + floatingView.width / 2f
        val centerY = params.y + floatingView.height / 2f
        if (useCurve) {
            svc.dragCurve(centerX, centerY, dragDx, dragDy, dragDuration)
        } else {
            svc.dragAim(centerX, centerY, dragDx, dragDy, dragDuration)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::floatingView.isInitialized) windowManager.removeView(floatingView)
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
