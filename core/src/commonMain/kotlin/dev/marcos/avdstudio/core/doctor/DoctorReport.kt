package dev.marcos.avdstudio.core.doctor

import dev.marcos.avdstudio.core.avd.Avd
import dev.marcos.avdstudio.core.avd.AvdHealth
import dev.marcos.avdstudio.core.process.shellQuote
import dev.marcos.avdstudio.core.sdk.AndroidTool
import dev.marcos.avdstudio.core.sdk.JavaInstallation
import dev.marcos.avdstudio.core.sdk.ToolAvailability
import dev.marcos.avdstudio.core.sdk.ToolchainStatus

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
    /** What to do, in order, with copy-pasteable commands. Empty when nothing needs fixing. */
    val nextSteps: List<String> = emptyList(),
) {
    public val isHealthy: Boolean
        get() = checks.none { it.status == CheckStatus.FAIL }

    public val hasWarnings: Boolean
        get() = checks.any { it.status == CheckStatus.WARNING }
}

internal object Doctor {
    const val INSTALL_COMMAND_LINE_TOOLS = "brew install --cask android-commandlinetools"

    // The keg-only formula needs no administrator password, unlike the Temurin cask.
    const val INSTALL_JAVA = "brew install openjdk@17"

    fun diagnose(
        toolchain: ToolchainStatus,
        java: JavaInstallation?,
        avdHome: String,
        avdHomeExists: Boolean,
        avds: List<Avd>,
    ): DoctorReport {
        val checks =
            buildList {
                add(sdkCheck(toolchain))
                toolchain.tools.forEach { add(toolCheck(it.tool, toolchain)) }
                add(javaCheck(java))
                add(avdHomeCheck(avdHome, avdHomeExists, avds))
                systemImageCheck(avds)?.let(::add)
            }
        return DoctorReport(checks, nextSteps(toolchain, java, avds))
    }

    /**
     * Ordered so each step can run after the previous one. Without the command-line tools nothing else can
     * be installed, so only the prerequisites are listed; a second `doctor` run then lists the rest.
     */
    private fun nextSteps(
        toolchain: ToolchainStatus,
        java: JavaInstallation?,
        avds: List<Avd>,
    ): List<String> {
        val steps = mutableListOf<String>()
        val cmdlineToolsMissing =
            !toolchain.sdkDirectoryExists ||
                listOf(AndroidTool.SDK_MANAGER, AndroidTool.AVD_MANAGER).any { !toolchain.state(it).isAvailable }
        if (cmdlineToolsMissing) {
            steps += "Install the Android command-line tools with `$INSTALL_COMMAND_LINE_TOOLS` " +
                "(or pick an SDK you already have with --sdk-path)."
        }
        if (java == null) steps += "Install a JDK (17 or newer) with `$INSTALL_JAVA`."
        if (cmdlineToolsMissing) return steps

        val sdkManager = "sdkmanager --sdk_root=${shellQuote(toolchain.sdkPath)}"
        val missingPackages =
            listOf(AndroidTool.EMULATOR, AndroidTool.ADB)
                .filter { !toolchain.state(it).isAvailable }
                .map { it.sdkPackage }
        if (missingPackages.isNotEmpty()) {
            steps += "Install the missing SDK packages with `$sdkManager ${quoted(missingPackages)}`."
        }

        val images =
            avds.filter { it.health == AvdHealth.MISSING_SYSTEM_IMAGE }.mapNotNull { it.systemImagePackage }.distinct()
        if (images.isNotEmpty()) {
            steps += "Install the system image${if (images.size > 1) "s" else ""} your devices need with " +
                "`$sdkManager ${quoted(images)}` (or delete those devices)."
        }
        return steps
    }

    private fun quoted(packages: List<String>): String = packages.joinToString(" ") { "\"$it\"" }

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

    private fun dev.marcos.avdstudio.core.sdk.SdkSource.describe(): String =
        when (this) {
            dev.marcos.avdstudio.core.sdk.SdkSource.EXPLICIT -> "chosen by you"
            dev.marcos.avdstudio.core.sdk.SdkSource.ANDROID_SDK_ROOT -> "from ANDROID_SDK_ROOT"
            dev.marcos.avdstudio.core.sdk.SdkSource.ANDROID_HOME -> "from ANDROID_HOME"
            dev.marcos.avdstudio.core.sdk.SdkSource.ANDROID_STUDIO_DEFAULT -> "Android Studio default"
            dev.marcos.avdstudio.core.sdk.SdkSource.HOMEBREW -> "Homebrew"
            dev.marcos.avdstudio.core.sdk.SdkSource.DEFAULT_LOCATION -> "default location"
        }
}
