package dev.marcos.avdstudio.core.avd

import dev.marcos.avdstudio.core.environment.Environment
import dev.marcos.avdstudio.core.environment.value

/** Where virtual devices are stored; mirrors how the emulator itself resolves it. */
internal class AvdHomeLocator(
    private val environment: Environment,
) {
    fun resolve(explicitPath: String?): String {
        explicitPath?.trim()?.takeIf { it.isNotEmpty() }?.let { return it }
        environment.value("ANDROID_AVD_HOME")?.let { return it }
        (environment.value("ANDROID_EMULATOR_HOME") ?: environment.value("ANDROID_USER_HOME"))
            ?.let { return it.trimEnd('/') + "/avd" }
        return "${environment.homeDirectory}/.android/avd"
    }
}
