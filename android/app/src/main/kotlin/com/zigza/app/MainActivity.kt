package com.zigza.app

import io.flutter.embedding.android.FlutterActivity
import android.os.Build
import android.os.Bundle

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // On Android 12+ (API 31+), immediately dismiss the system splash screen
        // so our Flutter brand splash screen with the exact matching icon appears seamlessly.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setOnExitAnimationListener { splashScreenView ->
                splashScreenView.remove()
            }
        }
    }
}

