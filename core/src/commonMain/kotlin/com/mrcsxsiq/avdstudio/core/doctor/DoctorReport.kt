package com.mrcsxsiq.avdstudio.core.doctor

import com.mrcsxsiq.avdstudio.core.avd.Avd
import com.mrcsxsiq.avdstudio.core.avd.AvdHealth
import com.mrcsxsiq.avdstudio.core.sdk.AndroidTool
import com.mrcsxsiq.avdstudio.core.sdk.JavaInstallation
import com.mrcsxsiq.avdstudio.core.sdk.ToolAvailability
import com.mrcsxsiq.avdstudio.core.sdk.ToolchainStatus

public enum class CheckStatus { PASS, WARNING, FAIL }

public data class DoctorCheck(
    val id: String,
    val title: String,
    val status: CheckStatus,
    val detail: String,
    /** What the user can do about it, when there is something to do. */
    val hint: String? = null,
)

public data class DoctorReport(
    val checks: List<DoctorCheck>,
) {
    public val isHealthy: Boolean
        get() = checks.none { it.status == CheckStatus.FAIL }

    public val hasWarnings: Boolean
        get() = checks.any { it.status == CheckStatus.WARNING }
}

internal object Doctor {
    const val INSTALL_COMMAND_LINE_TOOLS = "brew install --cask android-commandlinetools"
    const val INSTALL_JAVA = "brew install --cask temurin"

    fun diagnose(
        toolchain: ToolchainStatus,
        java: JavaInstallation?,
        avdHome: String,
        avdHomeExists: Boolean,
        avds: List<Avd>,
    ): DoctorReport =
        DoctorReport(
            buildList {
                add(sdkCheck(toolchain))
                toolchain.tools.forEach { add(toolCheck(it.tool, toolchain)) }
                add(javaCheck(java))
                add(avdHomeCheck(avdHome, avdHomeExists, avds))
                systemImageCheck(avds)?.let(::add)
            },
        )

    private fun sdkCheck(toolchain: ToolchainStatus) =
        if (toolchain.sdkDirectoryExists) {
            DoctorCheck("sdk", "Android SDK", CheckStatus.PASS, "${toolchain.sdkPath} (${toolchain.source.describe()})")
        } else {
            DoctorCheck(
                id = "sdk",
                title = "Android SDK",
                status = CheckStatus.FAIL,
                detail = "No SDK folder at ${toolchain.sdkPath}.",
                hint = "Install the command-line tools with `$INSTALL_COMMAND_LINE_TOOLS`, or point to an existing SDK with --sdk-path.",
            )
        }

    private fun toolCheck(
        tool: AndroidTool,
        toolchain: ToolchainStatus,
    ): DoctorCheck {
        val state = toolchain.state(tool)
        val required = tool != AndroidTool.ADB
        return when (state.availability) {
            ToolAvailability.AVAILABLE -> {
                DoctorCheck(tool.executableName, tool.executableName, CheckStatus.PASS, state.path)
            }

            ToolAvailability.DEPRECATED -> {
                DoctorCheck(
                    id = tool.executableName,
                    title = tool.executableName,
                    status = CheckStatus.FAIL,
                    detail = "Only the deprecated copy in tools/bin was found (${state.path}).",
                    hint = installHint(tool),
                )
            }

            ToolAvailability.MISSING -> {
                DoctorCheck(
                    id = tool.executableName,
                    title = tool.executableName,
                    status = if (required) CheckStatus.FAIL else CheckStatus.WARNING,
                    detail = "Not found (expected at ${state.path}).",
                    hint = installHint(tool),
                )
            }
        }
    }

    private fun installHint(tool: AndroidTool): String =
        when (tool) {
            AndroidTool.SDK_MANAGER, AndroidTool.AVD_MANAGER -> {
                "Install the Android command-line tools: `$INSTALL_COMMAND_LINE_TOOLS`."
            }

            else -> {
                "Install it with `sdkmanager \"${tool.sdkPackage}\"`."
            }
        }

    private fun javaCheck(java: JavaInstallation?) =
        if (java != null) {
            DoctorCheck("java", "Java runtime", CheckStatus.PASS, java.home)
        } else {
            DoctorCheck(
                id = "java",
                title = "Java runtime",
                status = CheckStatus.WARNING,
                detail = "No JDK found. sdkmanager and avdmanager need one.",
                hint = "Install one with `$INSTALL_JAVA`.",
            )
        }

    private fun avdHomeCheck(
        avdHome: String,
        exists: Boolean,
        avds: List<Avd>,
    ) = if (exists) {
        DoctorCheck("avd-home", "Virtual device folder", CheckStatus.PASS, "$avdHome — ${avds.size} device(s)")
    } else {
        DoctorCheck(
            id = "avd-home",
            title = "Virtual device folder",
            status = CheckStatus.WARNING,
            detail = "$avdHome does not exist yet.",
            hint = "It is created with your first virtual device.",
        )
    }

    private fun systemImageCheck(avds: List<Avd>): DoctorCheck? {
        val broken = avds.filter { it.health == AvdHealth.MISSING_SYSTEM_IMAGE }
        if (broken.isEmpty()) return null
        return DoctorCheck(
            id = "system-images",
            title = "System images",
            status = CheckStatus.WARNING,
            detail =
                "${broken.size} of ${avds.size} device(s) need a system image that is not installed: " +
                    broken.joinToString { it.name },
            hint = "Install the matching image with sdkmanager, or delete the device.",
        )
    }

    private fun com.mrcsxsiq.avdstudio.core.sdk.SdkSource.describe(): String =
        when (this) {
            com.mrcsxsiq.avdstudio.core.sdk.SdkSource.EXPLICIT -> "chosen by you"
            com.mrcsxsiq.avdstudio.core.sdk.SdkSource.ANDROID_SDK_ROOT -> "from ANDROID_SDK_ROOT"
            com.mrcsxsiq.avdstudio.core.sdk.SdkSource.ANDROID_HOME -> "from ANDROID_HOME"
            com.mrcsxsiq.avdstudio.core.sdk.SdkSource.ANDROID_STUDIO_DEFAULT -> "Android Studio default"
            com.mrcsxsiq.avdstudio.core.sdk.SdkSource.HOMEBREW -> "Homebrew"
            com.mrcsxsiq.avdstudio.core.sdk.SdkSource.DEFAULT_LOCATION -> "default location"
        }
}
