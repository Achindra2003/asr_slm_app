package com.example.my_agent_app

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import com.example.my_agent_app.native_tools.SystemSettings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.myagent.tools/system"
    private lateinit var systemSettings: SystemSettings

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        systemSettings = SystemSettings(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableDnd" -> {
                    val duration = call.argument<Int>("duration") ?: 0
                    val success = systemSettings.enableDoNotDisturb(duration)
                    result.success(success)
                }
                "requestDndPermission" -> {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                    startActivity(intent)
                    result.success(null)
                }
                "toggleFlashlight" -> {
                    val enable = call.argument<Boolean>("enable") ?: false
                    val success = systemSettings.toggleFlashlight(enable)
                    result.success(success)
                }
                "setVolume" -> {
                    val volumePercent = call.argument<Int>("volumePercent") ?: 50
                    val success = systemSettings.setVolume(volumePercent)
                    result.success(success)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
