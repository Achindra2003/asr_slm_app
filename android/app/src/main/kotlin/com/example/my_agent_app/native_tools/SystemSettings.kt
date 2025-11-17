package com.example.my_agent_app.native_tools

import android.app.NotificationManager
import android.content.Context
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.os.Handler
import android.os.Looper

class SystemSettings(private val context: Context) {
    
    fun enableDoNotDisturb(durationMinutes: Int): Boolean {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        // Check if the app has ACCESS_NOTIFICATION_POLICY permission
        if (!notificationManager.isNotificationPolicyAccessGranted) {
            return false
        }
        
        // Enable Do Not Disturb by setting interruption filter to PRIORITY
        notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
        
        // If duration is greater than 0, schedule turning off DND after the duration
        if (durationMinutes > 0) {
            val handler = Handler(Looper.getMainLooper())
            val delayMillis = durationMinutes * 60 * 1000L
            
            handler.postDelayed({
                notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
            }, delayMillis)
        }
        
        return true
    }
    
    fun toggleFlashlight(enable: Boolean): Boolean {
        return try {
            val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val cameraId = cameraManager.cameraIdList[0]
            cameraManager.setTorchMode(cameraId, enable)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
    
    fun setVolume(volumePercent: Int): Boolean {
        return try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val volume = (maxVolume * volumePercent / 100).coerceIn(0, maxVolume)
            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, volume, 0)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}
