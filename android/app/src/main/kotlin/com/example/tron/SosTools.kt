package com.example.tron

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.telephony.SmsManager
import java.text.Normalizer
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.atomic.AtomicInteger

/** Vị trí đã lấy được để gắn vào tin nhắn SOS. */
data class SosLocation(val latitude: Double, val longitude: Double, val accuracy: Float)

/**
 * Các thao tác SOS dùng chung cho kênh Flutter (app đang mở) và dịch vụ
 * "Báo an toàn" (app chạy nền): vị trí, gửi SMS, pin, soạn nội dung.
 */
object SosTools {

    /** Vị trí đủ tốt để dừng chờ sớm. */
    private const val GOOD_ACCURACY_METERS = 50f

    /** Vị trí cũ hơn mức này không dùng làm vị trí dự phòng. */
    private const val MAX_LAST_KNOWN_AGE_MS = 30 * 60 * 1000L

    private val requestCodes = AtomicInteger(5000)

    fun hasPermission(context: Context, permission: String): Boolean =
        context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    fun hasLocationPermission(context: Context): Boolean =
        hasPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ||
            hasPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION)

    /**
     * Lấy vị trí hiện tại trong tối đa [timeoutMs]. Hỏi mọi nguồn đang bật cùng lúc,
     * dừng sớm khi có vị trí đủ chính xác; hết giờ thì dùng vị trí tốt nhất đã nhận,
     * hoặc vị trí gần nhất máy còn nhớ. Không có gì thì trả về null.
     */
    @SuppressLint("MissingPermission")
    fun locate(context: Context, timeoutMs: Long, done: (SosLocation?) -> Unit) {
        val handler = Handler(Looper.getMainLooper())
        if (!hasLocationPermission(context)) {
            handler.post { done(null) }
            return
        }
        val manager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val providers = buildList {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                add(LocationManager.FUSED_PROVIDER)
            }
            add(LocationManager.GPS_PROVIDER)
            add(LocationManager.NETWORK_PROVIDER)
        }.filter { provider ->
            try {
                manager.allProviders.contains(provider) && manager.isProviderEnabled(provider)
            } catch (_: Exception) {
                false
            }
        }

        var best: Location? = null
        var finished = false
        val cleanups = mutableListOf<() -> Unit>()

        fun finish() {
            if (finished) return
            finished = true
            cleanups.forEach { runCatching { it() } }
            val result = best ?: lastKnown(manager)
            done(result?.let { SosLocation(it.latitude, it.longitude, it.accuracy) })
        }

        fun offer(location: Location?) {
            if (finished || location == null) return
            val current = best
            if (current == null || location.accuracy < current.accuracy) {
                best = location
            }
            if (location.hasAccuracy() && location.accuracy <= GOOD_ACCURACY_METERS) {
                finish()
            }
        }

        if (providers.isEmpty()) {
            handler.post { finish() }
            return
        }
        for (provider in providers) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    val signal = CancellationSignal()
                    cleanups.add { signal.cancel() }
                    manager.getCurrentLocation(provider, signal, context.mainExecutor) { offer(it) }
                } else {
                    val listener = object : LocationListener {
                        override fun onLocationChanged(location: Location) = offer(location)
                        @Deprecated("Bắt buộc trên Android cũ")
                        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
                        override fun onProviderEnabled(provider: String) {}
                        override fun onProviderDisabled(provider: String) {}
                    }
                    cleanups.add { manager.removeUpdates(listener) }
                    manager.requestLocationUpdates(provider, 0L, 0f, listener, Looper.getMainLooper())
                }
            } catch (_: Exception) {
                // Nguồn này lỗi hoặc bị tắt giữa chừng: các nguồn khác vẫn chạy.
            }
        }
        handler.postDelayed({ finish() }, timeoutMs)
    }

    @SuppressLint("MissingPermission")
    private fun lastKnown(manager: LocationManager): Location? {
        val now = System.currentTimeMillis()
        return manager.allProviders
            .mapNotNull { provider -> runCatching { manager.getLastKnownLocation(provider) }.getOrNull() }
            .filter { now - it.time <= MAX_LAST_KNOWN_AGE_MS }
            .minByOrNull { it.accuracy }
    }

    fun batteryPercent(context: Context): Int? {
        val manager = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
        val value = manager?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: return null
        return value.takeIf { it in 0..100 }
    }

    fun mapsLink(location: SosLocation): String =
        String.format(Locale.US, "https://maps.google.com/?q=%.6f,%.6f", location.latitude, location.longitude)

    /**
     * Điền mẫu tin nhắn. Phải khớp với `SosMessage.render` bên Dart
     * (lib/features/sos/services/sos_message.dart).
     */
    fun render(template: String, location: SosLocation?, battery: Int?, plain: Boolean, now: Date = Date()): String {
        val text = template
            .replace("{vitri}", location?.let { mapsLink(it) } ?: "(không lấy được vị trí)")
            .replace("{thoigian}", SimpleDateFormat("HH:mm dd/MM", Locale.US).format(now))
            .replace("{pin}", battery?.let { "$it%" } ?: "?")
            .trim()
        return if (plain) stripDiacritics(text) else text
    }

    fun stripDiacritics(text: String): String =
        Normalizer.normalize(text, Normalizer.Form.NFD)
            .replace(Regex("\\p{Mn}+"), "")
            .replace('đ', 'd')
            .replace('Đ', 'D')

    @Suppress("DEPRECATION")
    private fun smsManager(context: Context): SmsManager =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(SmsManager::class.java)
        } else {
            SmsManager.getDefault()
        }

    /**
     * Gửi một tin (tự tách nhiều phần nếu dài) và báo kết quả khi mạng xác nhận đã gửi.
     * [done] nhận null nếu thành công, hoặc mã lỗi.
     */
    fun sendSms(context: Context, phone: String, text: String, timeoutMs: Long, done: (String?) -> Unit) {
        val handler = Handler(Looper.getMainLooper())
        if (!hasPermission(context, Manifest.permission.SEND_SMS)) {
            handler.post { done("permission") }
            return
        }
        val app = context.applicationContext
        val action = "${app.packageName}.SOS_SMS_SENT.${requestCodes.incrementAndGet()}"
        val manager = try {
            smsManager(app)
        } catch (error: Exception) {
            handler.post { done("no_sms") }
            return
        }
        val parts = manager.divideMessage(text)
        var remaining = parts.size
        var failure: String? = null
        var finished = false
        lateinit var receiver: BroadcastReceiver

        fun finish(error: String?) {
            if (finished) return
            finished = true
            runCatching { app.unregisterReceiver(receiver) }
            done(error)
        }

        receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (resultCode != Activity.RESULT_OK) {
                    failure = "send_failed_$resultCode"
                }
                remaining -= 1
                if (remaining <= 0) finish(failure)
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            app.registerReceiver(receiver, IntentFilter(action), Context.RECEIVER_NOT_EXPORTED)
        } else {
            app.registerReceiver(receiver, IntentFilter(action))
        }
        val sent = ArrayList(
            parts.indices.map { index ->
                PendingIntent.getBroadcast(
                    app,
                    requestCodes.incrementAndGet(),
                    Intent(action).setPackage(app.packageName).putExtra("part", index),
                    PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE,
                )
            },
        )
        try {
            if (parts.size == 1) {
                manager.sendTextMessage(phone, null, text, sent[0], null)
            } else {
                manager.sendMultipartTextMessage(phone, null, parts, sent, null)
            }
        } catch (error: Exception) {
            finish("send_error")
            return
        }
        // Máy không báo lại (không có sóng, SIM lỗi...): coi là chưa gửi được.
        handler.postDelayed({ finish("timeout") }, timeoutMs)
    }

    /** Gọi thẳng nếu có quyền, nếu không thì mở sẵn màn quay số. */
    fun callIntent(context: Context, phone: String): Intent {
        val uri = Uri.fromParts("tel", phone, null)
        val canCall = hasPermission(context, Manifest.permission.CALL_PHONE)
        return Intent(if (canCall) Intent.ACTION_CALL else Intent.ACTION_DIAL, uri)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
}
