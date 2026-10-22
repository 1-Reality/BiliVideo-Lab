package org.BroTech.gege.pilibro

import android.annotation.TargetApi
import android.content.ComponentName
import android.content.pm.PackageManager

/** Keeps Android 13-only component-setting types out of MainActivity's bytecode. */
@TargetApi(33)
internal object Android13ComponentEnabledSettings {
    fun apply(
        packageManager: PackageManager,
        enabled: ComponentName,
        disabled: List<ComponentName>,
    ) {
        packageManager.setComponentEnabledSettings(
            (listOf(enabled) + disabled).map { component ->
                PackageManager.ComponentEnabledSetting(
                    component,
                    if (component == enabled) {
                        PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                    } else {
                        PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                    },
                    PackageManager.DONT_KILL_APP,
                )
            },
        )
    }
}
