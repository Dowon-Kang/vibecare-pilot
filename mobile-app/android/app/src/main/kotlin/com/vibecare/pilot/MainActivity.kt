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
import android.provider.Settings
import java.util.Calendar
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val CHANNEL = "com.vibecare.pilot/booking_reminders"
private const val NOTIFICATION_CHANNEL = "visit_bookings"
private fun prefs(context: Context) = context.getSharedPreferences("vibecare_reminders", Context.MODE_PRIVATE)
private fun reminderIntent(context: Context, owner: String, id: String) =
    Intent(context, BookingReminderReceiver::class.java).apply {
        data = Uri.Builder().scheme("vibecare").authority("reminder").appendPath(owner).appendPath(id).build()
        putExtra("owner", owner)
        putExtra("booking_id", id)
    }
private fun pending(context: Context, intent: Intent): PendingIntent = PendingIntent.getBroadcast(
    context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
)
private fun cancel(context: Context, owner: String, id: String) {
    val intents = mutableListOf(0 to reminderIntent(context, owner, id))
    if (owner == "legacy") intents.add(id.hashCode() to Intent(context, BookingReminderReceiver::class.java).apply { data = Uri.parse("vibecare://booking/$id") })
    for ((requestCode, intent) in intents) {
        val token = PendingIntent.getBroadcast(context, requestCode, intent, PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE)
        if (token != null) {
            (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(token)
            token.cancel()
        }
    }
    (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel((owner + ":" + id).hashCode())
}
private fun permitted(context: Context): Boolean {
    if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
    val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    if (Build.VERSION.SDK_INT >= 24 && !manager.areNotificationsEnabled()) return false
    return Build.VERSION.SDK_INT < 26 || manager.getNotificationChannel(NOTIFICATION_CHANNEL)?.importance != NotificationManager.IMPORTANCE_NONE
}

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 1001) {
            permissionResult?.success(null)
            permissionResult = null
        }
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "permission" -> result.success(permitted(this))
                    "requestPermission" -> {
                        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            if (permissionResult != null) result.error("BUSY", "권한 요청을 확인해 주세요.", null)
                            else {
                                permissionResult = result
                                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001)
                            }
                        } else result.success(null)
                    }
                    "openSettings" -> {
                        val intent = if (Build.VERSION.SDK_INT >= 26) Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                        startActivity(intent)
                        result.success(null)
                    }
                    "configure", "cancelOwner" -> {
                        val owner = call.argument<String>("owner") ?: throw IllegalArgumentException("알림 소유자가 없습니다.")
                        val store = prefs(this)
                        val enabled = call.method == "configure"
                        store.edit().putBoolean("$owner:booking", enabled && call.argument<Boolean>("bookings") == true)
                            .putBoolean("$owner:wellness", enabled && call.argument<Boolean>("wellness") == true).apply()
                        if (!enabled) {
                            for (id in store.getStringSet("$owner:ids", emptySet()) ?: emptySet()) cancel(this, owner, id)
                            store.edit().remove("$owner:ids").apply()
                        }
                        result.success(null)
                    }
                    "schedule", "cancel" -> {
                        val id = call.argument<String>("id") ?: throw IllegalArgumentException("예약 ID가 없습니다.")
                        val owner = call.argument<String>("owner") ?: "legacy"
                        if (call.method == "cancel") {
                            cancel(this, owner, id)
                            result.success(null)
                        } else {
                            val startsAt = call.argument<Number>("startsAt")?.toLong() ?: 0L
                            require(startsAt > System.currentTimeMillis()) { "예약 시간을 확인해 주세요." }
                            val kind = call.argument<String>("kind") ?: "booking"
                            require(kind == "booking" || kind == "wellness")
                            if (owner == "legacy") prefs(this).edit().putBoolean("legacy:booking", true).apply()
                            val intent = reminderIntent(this, owner, id).apply {
                                putExtra("kind", kind)
                                putExtra("hour", call.argument<Number>("hour")?.toInt() ?: 19)
                                putExtra("minute", call.argument<Number>("minute")?.toInt() ?: 0)
                            }
                            cancel(this, "legacy", id)
                            (getSystemService(Context.ALARM_SERVICE) as AlarmManager).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, startsAt, pending(this, intent))
                            val ids = (prefs(this).getStringSet("$owner:ids", emptySet()) ?: emptySet()).toMutableSet()
                            ids.add(id)
                            prefs(this).edit().putStringSet("$owner:ids", ids).apply()
                            result.success(permitted(this))
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                result.error("REMINDER_FAILED", "기기 알림 설정을 적용하지 못했습니다.", null)
            }
        }
    }
}

class BookingReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val owner = intent.getStringExtra("owner") ?: return
        val kind = intent.getStringExtra("kind") ?: "booking"
        if (!prefs(context).getBoolean("$owner:$kind", false)) return
        if (kind == "wellness") {
            val next = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, intent.getIntExtra("hour", 19))
                set(Calendar.MINUTE, intent.getIntExtra("minute", 0))
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
            }
            (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP, next.timeInMillis, pending(context, intent),
            )
        }
        if (!permitted(context)) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel(NOTIFICATION_CHANNEL, "참여와 생활 알림", NotificationManager.IMPORTANCE_DEFAULT))
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, NOTIFICATION_CHANNEL) else Notification.Builder(context)
        val open = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = builder.setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(if (kind == "wellness") "VibeCare 생활 돌보기" else "VibeCare 참여 알림")
            .setContentText(if (kind == "wellness") "오늘의 식사와 움직임을 돌아보세요." else "예약한 참여 일정을 앱에서 확인해 주세요.")
            .setContentIntent(open).setVisibility(Notification.VISIBILITY_PRIVATE).setAutoCancel(true).build()
        manager.notify((owner + ":" + intent.getStringExtra("booking_id")).hashCode(), notification)
    }
}
