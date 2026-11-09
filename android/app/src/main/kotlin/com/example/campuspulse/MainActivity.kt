package com.example.campuspulse

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createPushChannel()
    }

    /**
     * The channel of push notifications (AndroidManifest's
     * default_notification_channel_id). High importance: they pop up on
     * screen. Creating an existing channel does nothing.
     */
    private fun createPushChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            getString(R.string.campus_updates_channel_id),
            getString(R.string.campus_updates_channel_name),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply { description = getString(R.string.campus_updates_channel_description) }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }
}
