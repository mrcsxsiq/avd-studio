package dev.marcos.avdstudio.core.setup

import dev.marcos.avdstudio.core.avd.Avd
import dev.marcos.avdstudio.core.avd.AvdHealth
import dev.marcos.avdstudio.core.doctor.Doctor
import dev.marcos.avdstudio.core.environment.Environment
import dev.marcos.avdstudio.core.environment.value
import dev.marcos.avdstudio.core.process.Command
import dev.marcos.avdstudio.core.process.shellQuote
import dev.marcos.avdstudio.core.sdk.AndroidTool
import dev.marcos.avdstudio.core.sdk.JavaInstallation
import dev.marcos.avdstudio.core.sdk.ToolchainStatus
import okio.FileSystem
import okio.Path.Companion.toPath

/** Works out what is missing and the commands that install it. Pure planning: nothing runs here. */
internal class SetupPlanner(
    private val fileSystem: FileSystem,
    private val environment: Environment,
) {
    private val homebrewPrefix: String
        get() = environment.value("HOMEBREW_PREFIX") ?: "/opt/homebrew"

    /** An explicit HOMEBREW_PREFIX is trusted as-is; otherwise the two standard locations are tried. */
    fun homebrewPath(): String? {
        val candidates =
            environment.value("HOMEBREW_PREFIX")?.let { listOf("$it/bin/brew") }
                ?: listOf("/opt/homebrew/bin/brew", "/usr/local/bin/brew")
        return candidates.firstOrNull { fileSystem.exists(it.toPath()) }
    }

    fun plan(
        toolchain: ToolchainStatus,
        java: JavaInstallation?,
        avds: List<Avd>,
    ): SetupPlan {
        val brew = homebrewPath()
        val steps = mutableListOf<SetupStep>()

        val commandLineToolsMissing =
            !toolchain.sdkDirectoryExists ||
                listOf(AndroidTool.SDK_MANAGER, AndroidTool.AVD_MANAGER).any { !toolchain.state(it).isAvailable }
        // Homebrew's cask has its own SDK root; everything after it installs into that root.
        val sdkPath = if (commandLineToolsMissing) "$homebrewPrefix/share/android-commandlinetools" else toolchain.sdkPath
        val sdkManager =
            if (commandLineToolsMissing) {
                "$sdkPath/cmdline-tools/latest/bin/sdkmanager"
            } else {
                toolchain.executable(AndroidTool.SDK_MANAGER) ?: "$sdkPath/cmdline-tools/latest/bin/sdkmanager"
            }

        if (commandLineToolsMissing) {
            steps +=
                brewStep(
                    SetupStepKind.COMMAND_LINE_TOOLS,
                    "Install the Android command-line tools",
                    brew,
                    "install",
                    "--cask",
                    "android-commandlinetools",
                )
        }
        if (java == null) {
            steps += brewStep(SetupStepKind.JAVA, "Install Java (OpenJDK 17)", brew, "install", "openjdk@17")
        }

        val packages =
            buildList {
                if (commandLineToolsMissing || !toolchain.state(AndroidTool.EMULATOR).isAvailable) add(AndroidTool.EMULATOR.sdkPackage)
                if (commandLineToolsMissing || !toolchain.state(AndroidTool.ADB).isAvailable) add(AndroidTool.ADB.sdkPackage)
            }
        val images = avds.filter { it.health == AvdHealth.MISSING_SYSTEM_IMAGE }.mapNotNull { it.systemImagePackage }.distinct()

        if (packages.isNotEmpty() || images.isNotEmpty()) {
            steps +=
                SetupStep(
                    kind = SetupStepKind.LICENSES,
                    title = "Accept the Android SDK licenses",
                    displayCommand = "yes | ${shellQuote(sdkManager)} --sdk_root=${shellQuote(sdkPath)} --licenses",
                    // `yes` answers every prompt; the status of the pipeline is sdkmanager's.
                    command = Command("/bin/sh", listOf("-c", "yes | \"$0\" --sdk_root=\"$1\" --licenses", sdkManager, sdkPath)),
                    requiresHomebrew = false,
                    requiresLicenseAcceptance = true,
                )
        }
        if (packages.isNotEmpty()) {
            steps += sdkManagerStep(SetupStepKind.SDK_PACKAGES, "Install the emulator and platform tools", sdkManager, sdkPath, packages)
        }
        if (images.isNotEmpty()) {
            steps += sdkManagerStep(SetupStepKind.SYSTEM_IMAGES, "Install the system images your devices need", sdkManager, sdkPath, images)
        }
        return SetupPlan(steps, brew, sdkPath)
    }

    private fun brewStep(
        kind: SetupStepKind,
        title: String,
        brew: String?,
        vararg arguments: String,
    ) = SetupStep(
        kind = kind,
        title = title,
        displayCommand = "brew ${arguments.joinToString(" ")}",
        command =
            Command(
                executable = brew ?: "/opt/homebrew/bin/brew",
                arguments = arguments.toList(),
                environment = mapOf("HOMEBREW_NO_AUTO_UPDATE" to "1", "NONINTERACTIVE" to "1", "HOMEBREW_NO_ENV_HINTS" to "1"),
            ),
        requiresHomebrew = true,
        requiresLicenseAcceptance = false,
    )

    private fun sdkManagerStep(
        kind: SetupStepKind,
        title: String,
        sdkManager: String,
        sdkPath: String,
        packages: List<String>,
    ) = SetupStep(
        kind = kind,
        title = title,
        displayCommand = "${shellQuote(sdkManager)} --sdk_root=${shellQuote(sdkPath)} ${packages.joinToString(" ") { "\"$it\"" }}",
        command = Command(sdkManager, listOf("--sdk_root=$sdkPath") + packages),
        requiresHomebrew = false,
        requiresLicenseAcceptance = false,
    )

    internal companion object {
        /** Kept here so the CLI and the doctor hints never disagree about the install commands. */
        val INSTALL_COMMAND_LINE_TOOLS = Doctor.INSTALL_COMMAND_LINE_TOOLS
    }
}
