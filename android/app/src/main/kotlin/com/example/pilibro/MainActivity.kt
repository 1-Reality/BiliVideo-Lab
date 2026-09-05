package com.example.pilibro

import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.telephony.TelephonyManager
import android.os.Bundle
import android.os.SystemClock
import android.provider.Settings
import android.view.Surface
import android.view.WindowManager.LayoutParams
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.function.IntConsumer

class MainActivity : AudioServiceActivity() {
    private var orientationProbeSink: EventChannel.EventSink? = null
    private var proposedRotationListener: IntConsumer? = null
    private var lastProposedRotation: Int? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pilibro/orientation")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "systemAutoRotate" -> result.success(
                        Settings.System.getInt(
                            contentResolver,
                            Settings.System.ACCELEROMETER_ROTATION,
                            0
                        ) == 1
                    )
                    "setRequestedOrientation" -> {
                        requestedOrientation = call.arguments as Int
                        result.success(null)
                    }
                    "currentOrientation" -> result.success(currentOrientationRequest())
                    "orientationProbeSnapshot" -> result.success(orientationProbeSnapshot("manualSnapshot"))
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "pilibro/orientation_probe")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    startOrientationProbe(events)
                }

                override fun onCancel(arguments: Any?) {
                    stopOrientationProbe()
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pilibro/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "firstRunHints" -> result.success(firstRunDeviceHints())
                    else -> result.notImplemented()
                }
            }
    }

    private fun startOrientationProbe(events: EventChannel.EventSink) {
        stopOrientationProbe()
        orientationProbeSink = events
        emitOrientationProbe("listenStarted")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val listener = IntConsumer { rotation ->
                lastProposedRotation = rotation
                emitOrientationProbe("proposedRotation")
            }
            proposedRotationListener = listener
            try {
                windowManager.addProposedRotationListener(mainExecutor, listener)
            } catch (error: Throwable) {
                events.error("PROPOSED_ROTATION", error.toString(), null)
            }
        } else {
            emitOrientationProbe("proposedRotationUnsupported")
        }
    }

    private fun stopOrientationProbe() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            proposedRotationListener?.let { listener ->
                try {
                    windowManager.removeProposedRotationListener(listener)
                } catch (_: Throwable) {
                }
            }
        }
        proposedRotationListener = null
        orientationProbeSink = null
    }

    private fun emitOrientationProbe(event: String) {
        orientationProbeSink?.success(orientationProbeSnapshot(event))
    }

    @Suppress("DEPRECATION")
    private fun orientationProbeSnapshot(event: String): Map<String, Any?> {
        val rotation = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display?.rotation
        } else {
            windowManager.defaultDisplay.rotation
        }
        return mapOf(
            "event" to event,
            "elapsedRealtimeMs" to SystemClock.elapsedRealtime(),
            "proposedRotation" to lastProposedRotation,
            "displayRotation" to rotation,
            "configurationOrientation" to resources.configuration.orientation,
            "requestedOrientation" to requestedOrientation,
            "systemAutoRotate" to (
                Settings.System.getInt(
                    contentResolver,
                    Settings.System.ACCELEROMETER_ROTATION,
                    0
                ) == 1
            ),
        )
    }

    @Suppress("DEPRECATION")
    private fun firstRunDeviceHints(): Map<String, Boolean> {
        val pm = packageManager
        val hasTelephony = pm.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)
        val telephonyManager =
            getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
        val voiceCapable = hasTelephony && telephonyManager?.let {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
                it.isDeviceVoiceCapable
            } else {
                it.isVoiceCapable
            }
        } == true
        val telephonyCalling =
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                pm.hasSystemFeature(PackageManager.FEATURE_TELEPHONY_CALLING)
        val televisionUiMode =
            (getSystemService(Context.UI_MODE_SERVICE) as UiModeManager)
                .currentModeType == Configuration.UI_MODE_TYPE_TELEVISION

        return mapOf(
            "leanback" to pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK),
            "televisionUiMode" to televisionUiMode,
            "touchscreen" to pm.hasSystemFeature(PackageManager.FEATURE_TOUCHSCREEN),
            "hingeAngle" to (
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
                    pm.hasSystemFeature(PackageManager.FEATURE_SENSOR_HINGE_ANGLE)
                ),
            "telephony" to hasTelephony,
            "telephonyCalling" to telephonyCalling,
            "voiceCapable" to voiceCapable,
        )
    }

    @Suppress("DEPRECATION")
    private fun currentOrientationRequest(): Int {
        val rotation = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display?.rotation ?: Surface.ROTATION_0
        } else {
            windowManager.defaultDisplay.rotation
        }
        val naturalLandscape =
            ((rotation == Surface.ROTATION_0 || rotation == Surface.ROTATION_180) &&
                resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE) ||
            ((rotation == Surface.ROTATION_90 || rotation == Surface.ROTATION_270) &&
                resources.configuration.orientation == Configuration.ORIENTATION_PORTRAIT)

        return if (naturalLandscape) {
            when (rotation) {
                Surface.ROTATION_0 -> ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
                Surface.ROTATION_90 -> ActivityInfo.SCREEN_ORIENTATION_REVERSE_PORTRAIT
                Surface.ROTATION_180 -> ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE
                else -> ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            }
        } else {
            when (rotation) {
                Surface.ROTATION_0 -> ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
                Surface.ROTATION_90 -> ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
                Surface.ROTATION_180 -> ActivityInfo.SCREEN_ORIENTATION_REVERSE_PORTRAIT
                else -> ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE
            }
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        emitOrientationProbe("configurationChanged")
        if (AndroidHelper.isFoldable) {
            AndroidHelper.ToDart.onConfigurationChanged?.run()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode =
                LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
    }

    override fun onDestroy() {
        stopService(Intent(this, com.ryanheise.audioservice.AudioService::class.java))
        super.onDestroy()
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        AndroidHelper.ToDart.onUserLeaveHint?.run()
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration?) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        AndroidHelper.isPipMode = isInPictureInPictureMode
    }
}
