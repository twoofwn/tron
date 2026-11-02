package com.example.tron

import android.content.Context
import android.content.Intent
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var callChannel: MethodChannel? = null

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
        private val VOLUME_KEYS = setOf(
            KeyEvent.KEYCODE_VOLUME_UP,
            KeyEvent.KEYCODE_VOLUME_DOWN,
            KeyEvent.KEYCODE_VOLUME_MUTE,
        )
    }
}
