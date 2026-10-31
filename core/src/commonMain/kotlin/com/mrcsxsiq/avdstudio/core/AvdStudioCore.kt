package com.mrcsxsiq.avdstudio.core

import com.mrcsxsiq.avdstudio.core.avd.Avd
import com.mrcsxsiq.avdstudio.core.avd.AvdHomeLocator
import com.mrcsxsiq.avdstudio.core.avd.AvdRepository
import com.mrcsxsiq.avdstudio.core.doctor.Doctor
import com.mrcsxsiq.avdstudio.core.doctor.DoctorReport
import com.mrcsxsiq.avdstudio.core.emulator.EmulatorCommands
import com.mrcsxsiq.avdstudio.core.emulator.EmulatorLaunchOptions
import com.mrcsxsiq.avdstudio.core.environment.Environment
import com.mrcsxsiq.avdstudio.core.internal.systemFileSystem
import com.mrcsxsiq.avdstudio.core.process.Command
import com.mrcsxsiq.avdstudio.core.process.CommandException
import com.mrcsxsiq.avdstudio.core.process.CommandRunner
import com.mrcsxsiq.avdstudio.core.sdk.AndroidTool
import com.mrcsxsiq.avdstudio.core.sdk.JavaInstallation
import com.mrcsxsiq.avdstudio.core.sdk.JavaLocator
import com.mrcsxsiq.avdstudio.core.sdk.SdkLocator
import com.mrcsxsiq.avdstudio.core.sdk.ToolEnvironment
import com.mrcsxsiq.avdstudio.core.sdk.ToolchainStatus
import okio.FileSystem
import okio.Path.Companion.toPath

/**
 * Entry point shared by the SwiftUI app and the command-line tool.
 *
 * Every function takes the user's optional overrides (SDK folder, AVD folder) so that both
 * front-ends behave identically: an explicit choice always beats auto-detection.
 */
public class AvdStudioCore internal constructor(
    private val runner: CommandRunner,
    private val environment: Environment,
    private val fileSystem: FileSystem,
) {
    public constructor(runner: CommandRunner, environment: Environment) :
        this(runner, environment, systemFileSystem())

    private val sdkLocator = SdkLocator(fileSystem, environment)
    private val javaLocator = JavaLocator(fileSystem, environment)
    private val avdHomeLocator = AvdHomeLocator(environment)
    private val avdRepository = AvdRepository(fileSystem)

    public fun toolchainStatus(sdkPathOverride: String? = null): ToolchainStatus = sdkLocator.resolve(sdkPathOverride)

    public fun avdHome(avdHomeOverride: String? = null): String = avdHomeLocator.resolve(avdHomeOverride)

    public fun javaInstallation(): JavaInstallation? = javaLocator.locate()

    public fun listAvds(
        sdkPathOverride: String? = null,
        avdHomeOverride: String? = null,
    ): List<Avd> {
        val sdk = toolchainStatus(sdkPathOverride)
        return avdRepository.list(avdHome(avdHomeOverride), sdk.sdkPath.takeIf { sdk.sdkDirectoryExists })
    }

    public fun doctor(
        sdkPathOverride: String? = null,
        avdHomeOverride: String? = null,
    ): DoctorReport {
        val home = avdHome(avdHomeOverride)
        return Doctor.diagnose(
            toolchain = toolchainStatus(sdkPathOverride),
            java = javaInstallation(),
            avdHome = home,
            avdHomeExists = fileSystem.metadataOrNull(home.toPath())?.isDirectory == true,
            avds = listAvds(sdkPathOverride, avdHomeOverride),
        )
    }

    /** The exact command used to start [avdName]; handy for a "copy command" action. */
    @Throws(CommandException::class)
    public fun launchCommand(
        avdName: String,
        options: EmulatorLaunchOptions = EmulatorLaunchOptions(),
        sdkPathOverride: String? = null,
        avdHomeOverride: String? = null,
    ): Command {
        val toolchain = toolchainStatus(sdkPathOverride)
        val emulator =
            toolchain.executable(AndroidTool.EMULATOR)
                ?: throw CommandException("The Android emulator is not installed in ${toolchain.sdkPath}.")
        val toolEnvironment = ToolEnvironment(environment).build(toolchain.sdkPath, avdHome(avdHomeOverride), javaInstallation())
        return EmulatorCommands.launch(emulator, avdName, options, toolEnvironment)
    }

    /** Starts the emulator for [avdName] and returns immediately with the process id. */
    @Throws(CommandException::class)
    public fun launchAvd(
        avdName: String,
        options: EmulatorLaunchOptions = EmulatorLaunchOptions(),
        sdkPathOverride: String? = null,
        avdHomeOverride: String? = null,
    ): Int = runner.launchDetached(launchCommand(avdName, options, sdkPathOverride, avdHomeOverride))
}
