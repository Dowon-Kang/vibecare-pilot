package com.vibecare.pilot

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val CHANNEL = "com.vibecare.pilot/booking_reminders"
private const val NOTIFICATION_CHANNEL = "visit_bookings"

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "schedule" && call.method != "cancel") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val id = call.argument<String>("id")
            if (id == null) {
                result.error("INVALID_BOOKING", "예약 ID가 없습니다.", null)
                return@setMethodCallHandler
            }
            val startsAt = call.argument<Long>("startsAt")
            if (call.method == "schedule" && (startsAt == null || startsAt <= System.currentTimeMillis())) {
                result.error("INVALID_BOOKING", "예약 시간을 확인해 주세요.", null)
                return@setMethodCallHandler
            }
            val intent = Intent(this, BookingReminderReceiver::class.java).apply {
                data = Uri.parse("vibecare://booking/$id")
                putExtra("booking_id", id)
            }
            val pending = PendingIntent.getBroadcast(
                this,
                id.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val alarm = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            if (call.method == "cancel") {
                alarm.cancel(pending)
                result.success(null)
                return@setMethodCallHandler
            }
            alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, startsAt!!, pending)
            val permissionGranted = Build.VERSION.SDK_INT < 33 ||
                checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
            if (!permissionGranted && Build.VERSION.SDK_INT >= 33) {
                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001)
            }
            result.success(permissionGranted)
        }
    }
}

class BookingReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel(NOTIFICATION_CHANNEL, "참여 예약", NotificationManager.IMPORTANCE_DEFAULT),
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(context, NOTIFICATION_CHANNEL)
        } else {
            Notification.Builder(context)
        }
        val notification = builder
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("VibeCare 참여 시간")
            .setContentText("예약한 시간입니다. 앱에서 출석을 확인해 주세요.")
            .setAutoCancel(true)
            .build()
        manager.notify(intent.getStringExtra("booking_id")?.hashCode() ?: 0, notification)
    }
}
