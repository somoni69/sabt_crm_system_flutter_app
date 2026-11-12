package com.webrand.app

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestHighestRefreshRate()
    }

    /**
     * Many OEM skins (Samsung, Xiaomi, Oppo) keep apps at 60 Hz unless they
     * ask for a faster mode. Pick the highest-refresh mode that keeps the
     * current resolution, so no mode switch / screen flicker happens.
     */
    @Suppress("DEPRECATION")
    private fun requestHighestRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        try {
            val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                display
            } else {
                windowManager.defaultDisplay
            } ?: return
            val current = display.mode
            val best = display.supportedModes
                .filter {
                    it.physicalWidth == current.physicalWidth &&
                        it.physicalHeight == current.physicalHeight
                }
                .maxByOrNull { it.refreshRate } ?: return
            if (best.modeId != current.modeId) {
                val attrs = window.attributes
                attrs.preferredDisplayModeId = best.modeId
                window.attributes = attrs
            }
        } catch (_: Throwable) {
            // Never block startup over a display hint.
        }
    }
}
