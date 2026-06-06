package com.honeybyte.outalma_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Create the FCM default channel so notifications display on Android 8+.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "high_importance_channel",
                "Notifications",
                NotificationManager.IMPORTANCE_HIGH,
            )
            getSystemService(NotificationManager::class.java)
                ?.createNotificationChannel(channel)
        }
    }
}
