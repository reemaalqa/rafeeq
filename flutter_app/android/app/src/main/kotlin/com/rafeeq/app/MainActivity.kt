package com.rafeeq.app

import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val volumeChannel = "com.rafeeq.app/volume"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            volumeChannel,
        ).setMethodCallHandler { call, result ->
            val audio = getSystemService(AUDIO_SERVICE) as AudioManager
            when (call.method) {
                "volumeUp" -> {
                    audio.adjustStreamVolume(
                        AudioManager.STREAM_MUSIC,
                        AudioManager.ADJUST_RAISE,
                        AudioManager.FLAG_SHOW_UI,
                    )
                    audio.adjustStreamVolume(
                        AudioManager.STREAM_RING,
                        AudioManager.ADJUST_RAISE,
                        AudioManager.FLAG_SHOW_UI,
                    )
                    result.success(null)
                }
                "volumeDown" -> {
                    audio.adjustStreamVolume(
                        AudioManager.STREAM_MUSIC,
                        AudioManager.ADJUST_LOWER,
                        AudioManager.FLAG_SHOW_UI,
                    )
                    audio.adjustStreamVolume(
                        AudioManager.STREAM_RING,
                        AudioManager.ADJUST_LOWER,
                        AudioManager.FLAG_SHOW_UI,
                    )
                    result.success(null)
                }
                "mute" -> {
                    audio.adjustStreamVolume(
                        AudioManager.STREAM_MUSIC,
                        AudioManager.ADJUST_MUTE,
                        AudioManager.FLAG_SHOW_UI,
                    )
                    result.success(null)
                }
                "unmute" -> {
                    audio.adjustStreamVolume(
                        AudioManager.STREAM_MUSIC,
                        AudioManager.ADJUST_UNMUTE,
                        AudioManager.FLAG_SHOW_UI,
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
