package com.example.campuspulse

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createPushChannels()
    }

    /**
     * The channels of push notifications. High importance: they pop up on
     * screen. Users can mute each one in Android's settings. Creating an
     * existing channel does nothing.
     * - Campus updates: the default one (AndroidManifest's
     *   default_notification_channel_id), for the notifications of the feed.
     * - Class reminders: 15 min before each class; the API names it in
     *   those pushes (CLASS_REMINDERS_CHANNEL in class-reminders.ts).
     */
    private fun createPushChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channels = listOf(
            channel(
                R.string.campus_updates_channel_id,
                R.string.campus_updates_channel_name,
                R.string.campus_updates_channel_description,
            ),
            channel(
                R.string.class_reminders_channel_id,
                R.string.class_reminders_channel_name,
                R.string.class_reminders_channel_description,
            ),
        )
        getSystemService(NotificationManager::class.java).createNotificationChannels(channels)
    }

    private fun channel(id: Int, name: Int, description: Int) =
        NotificationChannel(getString(id), getString(name), NotificationManager.IMPORTANCE_HIGH)
            .apply { this.description = getString(description) }
}
