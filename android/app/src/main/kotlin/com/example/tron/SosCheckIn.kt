package com.example.tron

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Hẹn giờ "Báo an toàn": hết giờ mà người dùng chưa bấm "Tôi an toàn" thì tự gửi
 * SMS SOS (kèm vị trí) cho mọi người liên hệ, kể cả khi app đã đóng hoặc máy khóa.
 *
 * Dữ liệu nằm trong SharedPreferences riêng của Android để chạy được khi không có Flutter.
 */
object SosCheckIn {
    private const val PREFS = "tron_sos_checkin"
    private const val KEY_PAYLOAD = "payload"
    private const val KEY_DEADLINE = "deadline"
    private const val KEY_FIRED_AT = "firedAt"
    private const val KEY_SENT = "sent"
    private const val KEY_TOTAL = "total"
    private const val KEY_LOCATED = "located"

    const val ACTION_WARN = "com.example.tron.SOS_CHECKIN_WARN"
    const val ACTION_FIRE = "com.example.tron.SOS_CHECKIN_FIRE"
    const val ACTION_SAFE = "com.example.tron.SOS_CHECKIN_SAFE"

    const val CHANNEL_ONGOING = "sos_checkin"
    const val CHANNEL_ALERT = "sos_alert"
    const val NOTIFICATION_ONGOING = 3001
    const val NOTIFICATION_WARN = 3002
    const val NOTIFICATION_SENT = 3003

    /** Cảnh báo trước khi tự gửi. */
    const val WARN_BEFORE_MS = 60_000L
    private const val LOCATION_TIMEOUT_MS = 10_000L
    private const val SMS_TIMEOUT_MS = 30_000L

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun deadline(context: Context): Long = prefs(context).getLong(KEY_DEADLINE, 0L)

    fun status(context: Context): Map<String, Any> {
        val prefs = prefs(context)
        return mapOf(
            "deadline" to prefs.getLong(KEY_DEADLINE, 0L),
            "firedAt" to prefs.getLong(KEY_FIRED_AT, 0L),
            "sent" to prefs.getInt(KEY_SENT, 0),
            "total" to prefs.getInt(KEY_TOTAL, 0),
            "located" to prefs.getBoolean(KEY_LOCATED, false),
        )
    }

    fun clearResult(context: Context) {
        prefs(context).edit()
            .remove(KEY_FIRED_AT).remove(KEY_SENT).remove(KEY_TOTAL).remove(KEY_LOCATED)
            .apply()
        notificationManager(context).cancel(NOTIFICATION_SENT)
    }

    /** Bắt đầu hoặc gia hạn. Trả về false nếu chỉ đặt được báo thức không chính xác. */
    fun start(context: Context, deadline: Long, payload: String?): Boolean {
        val edit = prefs(context).edit().putLong(KEY_DEADLINE, deadline)
        if (payload != null) {
            edit.putString(KEY_PAYLOAD, payload)
        }
        edit.apply()
        notificationManager(context).cancel(NOTIFICATION_WARN)
        val exact = schedule(context, deadline)
        context.startForegroundService(
            Intent(context, SosCheckInService::class.java)
                .setAction(SosCheckInService.ACTION_START)
                .putExtra(SosCheckInService.EXTRA_FROM_APP, true),
        )
        return exact
    }

    fun cancel(context: Context) {
        prefs(context).edit().putLong(KEY_DEADLINE, 0L).apply()
        val alarms = context.getSystemService(AlarmManager::class.java)
        alarms.cancel(alarmIntent(context, ACTION_WARN))
        alarms.cancel(alarmIntent(context, ACTION_FIRE))
        notificationManager(context).cancel(NOTIFICATION_WARN)
        context.stopService(Intent(context, SosCheckInService::class.java))
    }

    fun schedule(context: Context, deadline: Long): Boolean {
        val alarms = context.getSystemService(AlarmManager::class.java)
        val exact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarms.canScheduleExactAlarms()
        fun set(at: Long, action: String) {
            val pending = alarmIntent(context, action)
            if (exact) {
                alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
            } else {
                alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
            }
        }
        val warnAt = deadline - WARN_BEFORE_MS
        if (warnAt > System.currentTimeMillis()) {
            set(warnAt, ACTION_WARN)
        } else {
            alarms.cancel(alarmIntent(context, ACTION_WARN))
        }
        set(deadline, ACTION_FIRE)
        return exact
    }

    private fun alarmIntent(context: Context, action: String): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            action.hashCode(),
            Intent(context, SosCheckInReceiver::class.java).setAction(action),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    fun safeIntent(context: Context): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            ACTION_SAFE.hashCode(),
            Intent(context, SosCheckInReceiver::class.java).setAction(ACTION_SAFE),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    fun openAppIntent(context: Context): PendingIntent? {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return null
        return PendingIntent.getActivity(
            context,
            0,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun notificationManager(context: Context): NotificationManager =
        context.getSystemService(NotificationManager::class.java)

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = notificationManager(context)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ONGOING, "Hẹn giờ báo an toàn", NotificationManager.IMPORTANCE_LOW),
        )
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ALERT, "Cảnh báo SOS", NotificationManager.IMPORTANCE_HIGH).apply {
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 600, 300, 600, 300, 600)
            },
        )
    }

    fun formatTime(millis: Long): String = SimpleDateFormat("HH:mm", Locale.US).format(Date(millis))

    fun postWarning(context: Context) {
        val deadline = deadline(context)
        if (deadline == 0L) return
        ensureChannels(context)
        val notification = NotificationCompat.Builder(context, CHANNEL_ALERT)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("Sắp tự gửi SOS lúc ${formatTime(deadline)}")
            .setContentText("Bạn có an toàn không? Bấm \"Tôi an toàn\" để huỷ.")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setContentIntent(openAppIntent(context))
            .addAction(0, "Tôi an toàn", safeIntent(context))
            .setTimeoutAfter(WARN_BEFORE_MS)
            .setAutoCancel(true)
            .build()
        notificationManager(context).notify(NOTIFICATION_WARN, notification)
    }

    private data class Contact(val name: String, val phone: String)

    private class Payload(
        val contacts: List<Contact>,
        val template: String,
        val plain: Boolean,
        val autoCall: Boolean,
    )

    private fun payload(context: Context): Payload? {
        val raw = prefs(context).getString(KEY_PAYLOAD, null) ?: return null
        return try {
            val json = JSONObject(raw)
            val list: JSONArray = json.optJSONArray("contacts") ?: JSONArray()
            Payload(
                contacts = (0 until list.length()).map {
                    val item = list.getJSONObject(it)
                    Contact(item.optString("name"), item.getString("phone"))
                }.filter { it.phone.isNotBlank() },
                template = json.optString("template"),
                plain = json.optBoolean("plain", false),
                autoCall = json.optBoolean("autoCall", true),
            )
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Hết giờ: lấy vị trí, gửi SMS cho tất cả, rồi hiện thông báo gọi người đầu tiên.
     * Màn hình khóa / tắt thì thông báo toàn màn hình mở thẳng cuộc gọi.
     */
    fun fire(context: Context, done: () -> Unit) {
        val app = context.applicationContext
        val prefs = prefs(app)
        if (prefs.getLong(KEY_DEADLINE, 0L) == 0L) {
            done()
            return
        }
        // Xóa hạn trước để không bao giờ gửi hai lần.
        prefs.edit().putLong(KEY_DEADLINE, 0L).putLong(KEY_FIRED_AT, System.currentTimeMillis()).apply()
        notificationManager(app).cancel(NOTIFICATION_WARN)
        val wakeLock = (app.getSystemService(Context.POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "tron:sos")
            .apply { acquire(LOCATION_TIMEOUT_MS + SMS_TIMEOUT_MS + 15_000L) }
        val payload = payload(app)
        if (payload == null || payload.contacts.isEmpty()) {
            prefs.edit().putInt(KEY_SENT, 0).putInt(KEY_TOTAL, 0).apply()
            postSent(app, null, 0, 0, false)
            if (wakeLock.isHeld) wakeLock.release()
            done()
            return
        }
        SosTools.locate(app, LOCATION_TIMEOUT_MS) { location ->
            val text = SosTools.render(payload.template, location, SosTools.batteryPercent(app), payload.plain)
            var remaining = payload.contacts.size
            var sent = 0
            for (contact in payload.contacts) {
                SosTools.sendSms(app, contact.phone, text, SMS_TIMEOUT_MS) { error ->
                    if (error == null) sent += 1
                    remaining -= 1
                    if (remaining == 0) {
                        prefs.edit()
                            .putInt(KEY_SENT, sent)
                            .putInt(KEY_TOTAL, payload.contacts.size)
                            .putBoolean(KEY_LOCATED, location != null)
                            .apply()
                        val primary = payload.contacts.first().takeIf { payload.autoCall }
                        postSent(app, primary, sent, payload.contacts.size, location != null)
                        if (wakeLock.isHeld) wakeLock.release()
                        done()
                    }
                }
            }
        }
    }

    private fun postSent(context: Context, call: Contact?, sent: Int, total: Int, located: Boolean) {
        ensureChannels(context)
        val summary = when {
            total == 0 -> "Chưa có người liên hệ nào để gửi."
            sent == total -> "Đã gửi tin cho $sent/$total người" + if (located) " kèm vị trí." else " (không lấy được vị trí)."
            else -> "Chỉ gửi được $sent/$total tin. Mở app để gửi lại."
        }
        val builder = NotificationCompat.Builder(context, CHANNEL_ALERT)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("Đã tự gửi SOS vì chưa báo an toàn")
            .setContentText(summary)
            .setStyle(NotificationCompat.BigTextStyle().bigText(summary))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setContentIntent(openAppIntent(context))
            .setAutoCancel(true)
        if (call != null) {
            val label = call.name.ifBlank { call.phone }
            val callPending = PendingIntent.getActivity(
                context,
                NOTIFICATION_SENT,
                SosTools.callIntent(context, call.phone),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            builder.addAction(0, "Gọi $label", callPending)
            // Máy khóa / tắt màn hình: mở thẳng cuộc gọi. Đang dùng máy: hiện thông báo nổi.
            if (SosTools.hasPermission(context, Manifest.permission.CALL_PHONE)) {
                builder.setFullScreenIntent(callPending, true)
            }
        }
        notificationManager(context).notify(NOTIFICATION_SENT, builder.build())
    }
}

/** Báo thức hẹn giờ, nút "Tôi an toàn" trên thông báo, và khôi phục sau khi khởi động lại máy. */
class SosCheckInReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            SosCheckIn.ACTION_SAFE -> SosCheckIn.cancel(context)
            SosCheckIn.ACTION_WARN -> {
                SosCheckIn.postWarning(context)
                startService(context, SosCheckInService.ACTION_START)
            }
            SosCheckIn.ACTION_FIRE -> fire(context)
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> {
                val deadline = SosCheckIn.deadline(context)
                when {
                    deadline == 0L -> Unit
                    deadline <= System.currentTimeMillis() -> fire(context)
                    else -> {
                        SosCheckIn.schedule(context, deadline)
                        startService(context, SosCheckInService.ACTION_START)
                    }
                }
            }
        }
    }

    private fun startService(context: Context, action: String): Boolean = try {
        context.startForegroundService(Intent(context, SosCheckInService::class.java).setAction(action))
        true
    } catch (_: Exception) {
        false
    }

    private fun fire(context: Context) {
        if (startService(context, SosCheckInService.ACTION_FIRE)) return
        // Android không cho mở dịch vụ lúc này: gửi ngay trong receiver.
        val pending = goAsync()
        SosCheckIn.fire(context) { pending.finish() }
    }
}

/** Thông báo thường trực trong lúc hẹn giờ; giữ quyền vị trí để lấy được vị trí khi hết giờ. */
class SosCheckInService : Service() {
    private var firing = false
    private var foregroundType: Int? = null
    private val handler = Handler(Looper.getMainLooper())

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        SosCheckIn.ensureChannels(this)
        val fromApp = intent?.getBooleanExtra(EXTRA_FROM_APP, false) ?: false
        enterForeground(fromApp)
        val deadline = SosCheckIn.deadline(this)
        val action = intent?.action ?: ACTION_START
        when {
            action == ACTION_FIRE || (deadline != 0L && deadline <= System.currentTimeMillis()) -> fire()
            deadline == 0L && !firing -> stopNow()
            action == ACTION_START -> scheduleFallback(deadline)
        }
        return START_STICKY
    }

    /** Dự phòng khi báo thức chính xác bị chặn: tự kiểm tra lại lúc hết hạn. */
    private fun scheduleFallback(deadline: Long) {
        handler.removeCallbacksAndMessages(null)
        handler.postDelayed({
            if (SosCheckIn.deadline(this) in 1..System.currentTimeMillis()) fire()
        }, (deadline - System.currentTimeMillis()).coerceAtLeast(0L) + 5_000L)
    }

    private fun fire() {
        if (firing) return
        firing = true
        handler.removeCallbacksAndMessages(null)
        SosCheckIn.fire(this) {
            firing = false
            stopNow()
        }
    }

    private fun stopNow() {
        handler.removeCallbacksAndMessages(null)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    private fun enterForeground(fromApp: Boolean) {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            startForeground(SosCheckIn.NOTIFICATION_ONGOING, notification)
            return
        }
        val special = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
        } else {
            0
        }
        // Chỉ xin loại "vị trí" khi app đang mở; từ nền Android không cho và sẽ báo lỗi.
        val wanted = foregroundType ?: if (fromApp && SosTools.hasLocationPermission(this)) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION or special
        } else {
            special
        }
        try {
            startForeground(SosCheckIn.NOTIFICATION_ONGOING, notification, wanted)
            foregroundType = wanted
        } catch (_: Exception) {
            startForeground(SosCheckIn.NOTIFICATION_ONGOING, notification, special)
            foregroundType = special
        }
    }

    private fun buildNotification(): Notification {
        val deadline = SosCheckIn.deadline(this)
        val builder = NotificationCompat.Builder(this, SosCheckIn.CHANNEL_ONGOING)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(SosCheckIn.openAppIntent(this))
        if (deadline == 0L) {
            return builder.setContentTitle("Đang gửi SOS…").build()
        }
        return builder
            .setContentTitle("Đang hẹn giờ báo an toàn")
            .setContentText("Tự gửi SOS lúc ${SosCheckIn.formatTime(deadline)} nếu bạn chưa báo an toàn.")
            .setWhen(deadline)
            .setShowWhen(true)
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .addAction(0, "Tôi an toàn", SosCheckIn.safeIntent(this))
            .build()
    }

    companion object {
        const val ACTION_START = "com.example.tron.SOS_CHECKIN_START"
        const val ACTION_FIRE = SosCheckIn.ACTION_FIRE
        const val EXTRA_FROM_APP = "fromApp"
    }
}
