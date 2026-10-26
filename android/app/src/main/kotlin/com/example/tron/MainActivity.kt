package com.example.tron

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

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
    }

    companion object {
        const val CHANNEL = "tron/background"
    }
}
