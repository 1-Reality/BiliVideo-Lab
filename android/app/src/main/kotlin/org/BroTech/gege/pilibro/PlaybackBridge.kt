package org.BroTech.gege.pilibro

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * 播放期间和系统打交道的几件事，替代 audio_session 在安卓上的焦点处理：
 * 它会把「可压低」并进「暂停」发给 Dart，分不出来。这里把焦点变化原样转给 Dart，
 * 由设置决定怎么反应；拔耳机的广播只在播放期间注册；另外提供屏幕是否亮着。
 */
class PlaybackBridge(private val context: Context, messenger: BinaryMessenger) {
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val channel = MethodChannel(messenger, "pilibro/playback")
    private val handler = Handler(Looper.getMainLooper())

    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        val name = when (change) {
            AudioManager.AUDIOFOCUS_GAIN -> "gain"
            AudioManager.AUDIOFOCUS_LOSS -> "loss"
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> "transient"
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> "duck"
            else -> null
        }
        if (name != null) channel.invokeMethod("focus", name)
    }

    // 只在 API 26 及以上使用
    private val focusRequest: Any? by lazy {
        if (Build.VERSION.SDK_INT < 26) {
            null
        } else {
            AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MOVIE)
                        .build()
                )
                // 系统不自动压低，把「可压低」交给我们处理
                .setWillPauseWhenDucked(true)
                .setOnAudioFocusChangeListener(focusListener, handler)
                .build()
        }
    }

    private val noisyReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) {
                channel.invokeMethod("noisy", null)
            }
        }
    }
    private var noisyRegistered = false

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    registerNoisy()
                    result.success(if (call.arguments == true) requestFocus() else false)
                }
                "stop" -> {
                    unregisterNoisy()
                    abandonFocus()
                    result.success(null)
                }
                "isInteractive" -> result.success(
                    (context.getSystemService(Context.POWER_SERVICE) as PowerManager).isInteractive
                )
                else -> result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun requestFocus(): Boolean {
        val granted = if (Build.VERSION.SDK_INT >= 26) {
            audioManager.requestAudioFocus(focusRequest as AudioFocusRequest)
        } else {
            audioManager.requestAudioFocus(
                focusListener,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN,
            )
        }
        return granted == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }

    @Suppress("DEPRECATION")
    private fun abandonFocus() {
        if (Build.VERSION.SDK_INT >= 26) {
            audioManager.abandonAudioFocusRequest(focusRequest as AudioFocusRequest)
        } else {
            audioManager.abandonAudioFocus(focusListener)
        }
    }

    private fun registerNoisy() {
        if (noisyRegistered) return
        noisyRegistered = true
        val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
        if (Build.VERSION.SDK_INT >= 33) {
            context.registerReceiver(noisyReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(noisyReceiver, filter)
        }
    }

    private fun unregisterNoisy() {
        if (!noisyRegistered) return
        noisyRegistered = false
        context.unregisterReceiver(noisyReceiver)
    }
}