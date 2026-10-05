package com.example.pilibro

import android.app.UiModeManager
import android.content.Context
import android.content.ComponentName
import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.BitmapFactory
import android.graphics.drawable.Icon
import android.os.Build
import android.telephony.TelephonyManager
import android.os.Bundle
import android.provider.Settings
import android.view.Surface
import android.view.WindowManager.LayoutParams
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest
import java.util.function.IntConsumer

class MainActivity : AudioServiceActivity() {
    private var proposedRotationSink: EventChannel.EventSink? = null
    private var proposedRotationListener: IntConsumer? = null

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
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "pilibro/orientation_proposed")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    startProposedRotation(events)
                }

                override fun onCancel(arguments: Any?) {
                    stopProposedRotation()
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pilibro/desktop_icon")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCurrentBuiltInIcon" -> {
                        val fileNames = call.argument<List<String>>("fileNames") ?: emptyList()
                        result.success(currentBuiltInLauncherIcon(fileNames))
                    }
                    "setBuiltInIcon" -> {
                        val fileName = call.argument<String>("fileName")
                        result.success(setBuiltInLauncherIcon(fileName))
                    }
                    "setCustomDesktopIcon" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes == null) {
                            result.error("INVALID_ICON", "Missing icon bytes", null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            try {
                                val status = setCustomDesktopIcon(bytes)
                                runOnUiThread { result.success(status) }
                            } catch (e: Throwable) {
                                runOnUiThread {
                                    result.error(
                                        "ICON_ERROR",
                                        e.message ?: e.javaClass.simpleName,
                                        null,
                                    )
                                }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pilibro/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "firstRunHints" -> result.success(firstRunDeviceHints())
                    else -> result.notImplemented()
                }
            }
    }

    private fun startProposedRotation(events: EventChannel.EventSink) {
        stopProposedRotation()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return
        proposedRotationSink = events

        // Resolve the natural display orientation once per subscription. Dart
        // receives portraitUp / landscapeLeft / portraitDown / landscapeRight.
        val rotationOffset = portraitRotationOffset(display?.rotation ?: Surface.ROTATION_0)
        val listener = IntConsumer { rotation ->
            proposedRotationSink?.success((rotation + rotationOffset) and 3)
        }
        proposedRotationListener = listener
        try {
            windowManager.addProposedRotationListener(mainExecutor, listener)
        } catch (_: Throwable) {
            stopProposedRotation()
        }
    }

    private fun stopProposedRotation() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            proposedRotationListener?.let { listener ->
                try {
                    windowManager.removeProposedRotationListener(listener)
                } catch (_: Throwable) {
                }
            }
        }
        proposedRotationListener = null
        proposedRotationSink = null
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
        return when ((rotation + portraitRotationOffset(rotation)) and 3) {
            Surface.ROTATION_0 -> ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            Surface.ROTATION_90 -> ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
            Surface.ROTATION_180 -> ActivityInfo.SCREEN_ORIENTATION_REVERSE_PORTRAIT
            else -> ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE
        }
    }

    private fun portraitRotationOffset(rotation: Int): Int {
        val naturalLandscape =
            ((rotation == Surface.ROTATION_0 || rotation == Surface.ROTATION_180) &&
                resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE) ||
            ((rotation == Surface.ROTATION_90 || rotation == Surface.ROTATION_270) &&
                resources.configuration.orientation == Configuration.ORIENTATION_PORTRAIT)

        return if (naturalLandscape) 1 else 0
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
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
        stopProposedRotation()
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

    private fun desktopIconComponent(fileName: String): ComponentName {
        val packageName = MainActivity::class.java.packageName
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(fileName.toByteArray(Charsets.UTF_8))
        val id = digest.take(12).joinToString("") {
            "%02x".format(it.toInt() and 0xff)
        }
        return ComponentName(
            this.packageName,
            packageName + ".DesktopIcon_" + id,
        )
    }

    @Suppress("DEPRECATION")
    private fun desktopIconComponents(): List<ComponentName> {
        val launcherIntent = Intent(Intent.ACTION_MAIN)
            .addCategory(Intent.CATEGORY_LAUNCHER)
            .setPackage(packageName)
        val classPrefix = MainActivity::class.java.packageName + ".DesktopIcon_"
        return packageManager
            .queryIntentActivities(
                launcherIntent,
                PackageManager.MATCH_DISABLED_COMPONENTS,
            )
            .mapNotNull { info ->
                val name = info.activityInfo?.name ?: return@mapNotNull null
                if (name.startsWith(classPrefix)) {
                    ComponentName(packageName, name)
                } else {
                    null
                }
            }
            .distinct()
    }

    private fun currentBuiltInLauncherIcon(fileNames: List<String>): String? {
        val defaultComponent = ComponentName(
            packageName,
            MainActivity::class.java.packageName + ".DesktopIconDefault",
        )
        if (
            packageManager.getComponentEnabledSetting(defaultComponent) !=
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        ) {
            return null
        }

        val namesByComponent = fileNames.associateBy {
            desktopIconComponent(it).className
        }
        val launcherIntent = Intent(Intent.ACTION_MAIN)
            .addCategory(Intent.CATEGORY_LAUNCHER)
            .setPackage(packageName)
        @Suppress("DEPRECATION")
        val activities = packageManager.queryIntentActivities(
            launcherIntent,
            PackageManager.MATCH_DISABLED_COMPONENTS,
        )
        return activities.firstOrNull { info ->
            val name = info.activityInfo?.name ?: return@firstOrNull false
            if (name !in namesByComponent) return@firstOrNull false
            packageManager.getComponentEnabledSetting(
                ComponentName(packageName, name),
            ) == PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        }?.activityInfo?.name?.let(namesByComponent::get)
    }

    private fun setBuiltInLauncherIcon(fileName: String?): Boolean {
        val defaultComponent = ComponentName(
            packageName,
            MainActivity::class.java.packageName + ".DesktopIconDefault",
        )
        val aliases = desktopIconComponents()
        val target = fileName?.let(::desktopIconComponent)
        if (target != null && target !in aliases) {
            return false
        }

        val settings = buildList {
            add(
                PackageManager.ComponentEnabledSetting(
                    defaultComponent,
                    if (target == null) {
                        PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                    } else {
                        PackageManager.COMPONENT_ENABLED_STATE_DEFAULT
                    },
                    PackageManager.DONT_KILL_APP,
                ),
            )
            aliases.forEach { alias ->
                add(
                    PackageManager.ComponentEnabledSetting(
                        alias,
                        if (alias == target) {
                            PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                        } else {
                            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT
                        },
                        PackageManager.DONT_KILL_APP,
                    ),
                )
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.setComponentEnabledSettings(settings)
        } else {
            settings.forEach {
                packageManager.setComponentEnabledSetting(
                    it.componentName,
                    it.enabledState,
                    it.enabledFlags,
                )
            }
        }
        return true
    }

    private fun setCustomDesktopIcon(bytes: ByteArray): Int {
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            ?: return 0
        val shortcutIntent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            sendBroadcast(Intent("com.android.launcher.action.INSTALL_SHORTCUT").apply {
                putExtra(Intent.EXTRA_SHORTCUT_NAME, "PiliBro")
                putExtra(Intent.EXTRA_SHORTCUT_ICON, bitmap)
                putExtra(Intent.EXTRA_SHORTCUT_INTENT, shortcutIntent)
            })
            return 1
        }

        val manager = getSystemService(ShortcutManager::class.java) ?: return 0
        if (!manager.isRequestPinShortcutSupported) return 0

        val shortcut = ShortcutInfo.Builder(this, "custom_desktop_icon")
            .setShortLabel("PiliBro")
            .setIcon(Icon.createWithAdaptiveBitmap(bitmap))
            .setIntent(shortcutIntent)
            .build()

        val pinned = manager.pinnedShortcuts.any {
            it.id == "custom_desktop_icon"
        }
        return if (pinned) {
            if (manager.updateShortcuts(listOf(shortcut))) 2 else 0
        } else if (manager.requestPinShortcut(shortcut, null)) {
            1
        } else {
            0
        }
    }


}
