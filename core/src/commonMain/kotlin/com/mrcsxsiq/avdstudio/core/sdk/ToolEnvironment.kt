package com.mrcsxsiq.avdstudio.core.sdk

import com.mrcsxsiq.avdstudio.core.environment.Environment
import com.mrcsxsiq.avdstudio.core.environment.value

/**
 * Variables Android's command-line tools need. GUI apps start with a minimal environment, so we
 * never rely on the user's shell profile: everything is passed explicitly.
 */
internal class ToolEnvironment(
    private val environment: Environment,
) {
    fun build(
        sdkPath: String,
        avdHome: String,
        java: JavaInstallation?,
    ): Map<String, String> {
        val pathEntries =
            listOfNotNull(
                java?.let { "${it.home}/bin" },
                "$sdkPath/platform-tools",
            ) + (environment.value("PATH") ?: DEFAULT_PATH).split(':')

        return buildMap {
            put("ANDROID_HOME", sdkPath)
            put("ANDROID_SDK_ROOT", sdkPath)
            put("ANDROID_AVD_HOME", avdHome)
            java?.let { put("JAVA_HOME", it.home) }
            put("PATH", pathEntries.distinct().joinToString(":"))
        }
    }

    private companion object {
        const val DEFAULT_PATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    }
}
