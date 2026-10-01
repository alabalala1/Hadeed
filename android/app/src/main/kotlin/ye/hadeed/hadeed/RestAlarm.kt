package ye.hadeed.hadeed

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build

class RestAlarm : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val prefs = context.getSharedPreferences("rest_alarm", Context.MODE_PRIVATE)
        val deadline = prefs.getLong("deadline", 0)
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            if (deadline > System.currentTimeMillis()) schedule(context, deadline,
                prefs.getBoolean("sound", false), prefs.getBoolean("vibration", false))
            else prefs.edit().clear().apply()
            return
        }
        if (deadline == 0L || deadline > System.currentTimeMillis()) return
        prefs.edit().remove("deadline").apply()
        notify(context, prefs.getBoolean("sound", false), prefs.getBoolean("vibration", false))
    }

    companion object {
        private fun pending(context: Context): PendingIntent = PendingIntent.getBroadcast(
            context, 90, Intent(context, RestAlarm::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        fun cancel(context: Context) {
            (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(pending(context))
            context.getSharedPreferences("rest_alarm", Context.MODE_PRIVATE).edit().clear().apply()
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(90)
        }

        fun schedule(context: Context, deadline: Long, sound: Boolean, vibration: Boolean) {
            cancel(context)
            context.getSharedPreferences("rest_alarm", Context.MODE_PRIVATE).edit()
                .putLong("deadline", deadline).putBoolean("sound", sound).putBoolean("vibration", vibration).apply()
            // Inexact background delivery avoids special exact-alarm permission.
            (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager)
                .setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, deadline, pending(context))
        }

        fun notify(context: Context, sound: Boolean, vibration: Boolean) {
            if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channelId = "rest_${sound}_${vibration}"
            if (Build.VERSION.SDK_INT >= 26) {
                val channel = NotificationChannel(channelId, "انتهاء الراحة", NotificationManager.IMPORTANCE_DEFAULT)
                channel.enableVibration(vibration)
                channel.setSound(if (sound) RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION) else null,
                    AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION).build())
                manager.createNotificationChannel(channel)
            }
            val open = PendingIntent.getActivity(context, 91, Intent(context, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, channelId) else Notification.Builder(context)
            builder.setSmallIcon(R.drawable.ic_rest_notification).setContentTitle("انتهت الراحة")
                .setContentText("عد إلى جلسة حديد عندما تكون مستعدًا")
                .setContentIntent(open).setAutoCancel(true)
            if (Build.VERSION.SDK_INT < 26) {
                if (sound) builder.setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION))
                if (vibration) builder.setVibrate(longArrayOf(0, 250, 150, 250))
            }
            manager.notify(90, builder.build())
        }
    }
}
