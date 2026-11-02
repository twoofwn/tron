package com.example.tron

import android.content.Context
import android.content.Intent
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.provider.ContactsContract
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var callChannel: MethodChannel? = null

    // Kết quả đang chờ của bảng chọn danh bạ hệ thống.
    private var pendingContact: MethodChannel.Result? = null

    // Bật khi màn gọi đang đổ chuông: phím âm lượng tắt chuông thay vì đổi âm lượng.
    private var silenceKeys = false

    private val audioManager by lazy { getSystemService(Context.AUDIO_SERVICE) as AudioManager }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                val service = Intent(this, ArmedService::class.java)
                when (call.method) {
                    "start" -> try {
                        startForegroundService(service)
                        result.success(true)
                    } catch (error: Exception) {
                        // Android có thể chặn khởi động service từ nền; báo về Dart để hiện thông báo.
                        result.error("start_failed", error.message, null)
                    }
                    "stop" -> {
                        stopService(service)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SOS_CHANNEL)
            .setMethodCallHandler { call, result -> handleSos(call, result) }
        callChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_CHANNEL).also {
            it.setMethodCallHandler { call, result ->
                val enabled = call.arguments as? Boolean ?: false
                try {
                    when (call.method) {
                        "setSilenceKeys" -> silenceKeys = enabled
                        "startCallAudio" -> startCallAudio(enabled)
                        "setSpeaker" -> routeSpeaker(enabled)
                        "endCallAudio" -> endCallAudio()
                        else -> {
                            result.notImplemented()
                            return@setMethodCallHandler
                        }
                    }
                    result.success(null)
                } catch (error: Exception) {
                    result.error("call_audio_failed", error.message, null)
                }
            }
        }
    }

    private fun handleSos(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "pickContact" -> {
                    pendingContact?.success(null)
                    pendingContact = result
                    startActivityForResult(
                        Intent(Intent.ACTION_PICK, ContactsContract.CommonDataKinds.Phone.CONTENT_URI),
                        PICK_CONTACT,
                    )
                }
                "locate" -> {
                    val timeout = (call.argument<Number>("timeoutMs") ?: 8000).toLong()
                    SosTools.locate(this, timeout) { location ->
                        result.success(
                            location?.let {
                                mapOf(
                                    "latitude" to it.latitude,
                                    "longitude" to it.longitude,
                                    "accuracy" to it.accuracy.toDouble(),
                                )
                            },
                        )
                    }
                }
                "sendSms" -> {
                    val phone = call.argument<String>("phone").orEmpty()
                    val text = call.argument<String>("text").orEmpty()
                    SosTools.sendSms(this, phone, text, 30_000L) { error -> result.success(error) }
                }
                "call" -> {
                    val intent = SosTools.callIntent(this, call.argument<String>("phone").orEmpty())
                    startActivity(intent)
                    result.success(if (intent.action == Intent.ACTION_CALL) "call" else "dial")
                }
                "dial" -> {
                    val phone = call.argument<String>("phone").orEmpty()
                    startActivity(Intent(Intent.ACTION_DIAL, Uri.fromParts("tel", phone, null)))
                    result.success("dial")
                }
                "battery" -> result.success(SosTools.batteryPercent(this))
                "startCheckIn" -> {
                    val deadline = (call.argument<Number>("deadline") ?: 0).toLong()
                    result.success(SosCheckIn.start(this, deadline, call.argument<String>("payload")))
                }
                "cancelCheckIn" -> {
                    SosCheckIn.cancel(this)
                    result.success(null)
                }
                "checkInStatus" -> result.success(SosCheckIn.status(this))
                "clearCheckInResult" -> {
                    SosCheckIn.clearResult(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error("sos_failed", error.message, null)
        }
    }

    @Deprecated("FlutterActivity vẫn chuyển kết quả qua hàm này")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_CONTACT) return
        val result = pendingContact ?: return
        pendingContact = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            contentResolver.query(
                uri,
                arrayOf(
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Phone.NUMBER,
                ),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    result.success(mapOf("name" to (cursor.getString(0) ?: ""), "phone" to (cursor.getString(1) ?: "")))
                    return
                }
            }
            result.success(null)
        } catch (error: Exception) {
            result.error("contact_failed", error.message, null)
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (silenceKeys && event.keyCode in VOLUME_KEYS) {
            if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) {
                callChannel?.invokeMethod("volumeKey", null)
            }
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    // Chế độ cuộc gọi: tiếng ra loa trong (hoặc tai nghe), phím âm lượng chỉnh âm lượng cuộc gọi.
    private fun startCallAudio(speaker: Boolean) {
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
        routeSpeaker(speaker)
    }

    private fun routeSpeaker(on: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val speaker = audioManager.availableCommunicationDevices
                .firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }
            if (on && speaker != null) {
                audioManager.setCommunicationDevice(speaker)
            } else {
                // Bỏ chọn thiết bị: hệ thống tự dùng loa trong, hoặc tai nghe nếu đang cắm.
                audioManager.clearCommunicationDevice()
            }
        } else {
            @Suppress("DEPRECATION")
            audioManager.isSpeakerphoneOn = on
        }
    }

    private fun endCallAudio() {
        routeSpeaker(false)
        audioManager.mode = AudioManager.MODE_NORMAL
    }

    companion object {
        const val CHANNEL = "tron/background"
        const val CALL_CHANNEL = "tron/call"
        const val SOS_CHANNEL = "tron/sos"
        private const val PICK_CONTACT = 7301
        private val VOLUME_KEYS = setOf(
            KeyEvent.KEYCODE_VOLUME_UP,
            KeyEvent.KEYCODE_VOLUME_DOWN,
            KeyEvent.KEYCODE_VOLUME_MUTE,
        )
    }
}
