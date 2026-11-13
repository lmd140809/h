package com.example.dragaim

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.view.accessibility.AccessibilityEvent

class DragAccessibilityService : AccessibilityService() {

    companion object {
        var instance: DragAccessibilityService? = null
            private set
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    // Kéo tâm theo đường thẳng
    fun dragAim(startX: Float, startY: Float, dx: Float, dy: Float, duration: Long = 250) {
        val path = Path().apply {
            moveTo(startX, startY)
            lineTo(startX + dx, startY + dy)
        }
        dispatchPath(path, duration)
    }

    // Kéo tâm theo đường cong (mượt hơn, phù hợp để giả lập thao tác người thật)
    fun dragCurve(startX: Float, startY: Float, dx: Float, dy: Float, duration: Long = 300) {
        val path = Path().apply {
            moveTo(startX, startY)
            quadTo(
                startX + dx * 0.7f, startY + dy * 0.3f,
                startX + dx, startY + dy
            )
        }
        dispatchPath(path, duration)
    }

    private fun dispatchPath(path: Path, duration: Long) {
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, duration))
            .build()
        try {
            dispatchGesture(gesture, null, null)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}
    override fun onInterrupt() {}
}
