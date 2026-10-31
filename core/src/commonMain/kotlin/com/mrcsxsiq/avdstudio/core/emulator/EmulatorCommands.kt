package com.mrcsxsiq.avdstudio.core.emulator

import com.mrcsxsiq.avdstudio.core.process.Command

public data class EmulatorLaunchOptions(
    /** Skip the saved snapshot and boot from scratch (`-no-snapshot-load`). */
    val coldBoot: Boolean = false,
    /** Reset the device to factory state before booting (`-wipe-data`). */
    val wipeData: Boolean = false,
    val extraArguments: List<String> = emptyList(),
)

internal object EmulatorCommands {
    fun launch(
        emulatorPath: String,
        avdName: String,
        options: EmulatorLaunchOptions,
        environment: Map<String, String>,
    ): Command {
        val arguments =
            buildList {
                add("-avd")
                add(avdName)
                if (options.coldBoot) add("-no-snapshot-load")
                if (options.wipeData) add("-wipe-data")
                addAll(options.extraArguments)
            }
        return Command(executable = emulatorPath, arguments = arguments, environment = environment)
    }
}
