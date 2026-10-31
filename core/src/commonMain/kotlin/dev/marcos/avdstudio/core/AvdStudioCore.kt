package dev.marcos.avdstudio.core

import dev.marcos.avdstudio.core.avd.Avd
import dev.marcos.avdstudio.core.avd.AvdHomeLocator
import dev.marcos.avdstudio.core.avd.AvdRepository
import dev.marcos.avdstudio.core.doctor.Doctor
import dev.marcos.avdstudio.core.doctor.DoctorReport
import dev.marcos.avdstudio.core.emulator.EmulatorCommands
import dev.marcos.avdstudio.core.emulator.EmulatorLaunchOptions
import dev.marcos.avdstudio.core.emulator.RunningEmulator
import dev.marcos.avdstudio.core.emulator.RunningEmulators
import dev.marcos.avdstudio.core.environment.Environment
import dev.marcos.avdstudio.core.internal.systemFileSystem
import dev.marcos.avdstudio.core.process.Command
import dev.marcos.avdstudio.core.process.CommandException
import dev.marcos.avdstudio.core.process.CommandResult
import dev.marcos.avdstudio.core.process.CommandRunner
import dev.marcos.avdstudio.core.sdk.AndroidTool
import dev.marcos.avdstudio.core.sdk.JavaInstallation
import dev.marcos.avdstudio.core.sdk.JavaLocator
import dev.marcos.avdstudio.core.sdk.SdkLocator
import dev.marcos.avdstudio.core.sdk.ToolEnvironment
import dev.marcos.avdstudio.core.sdk.ToolchainStatus
import dev.marcos.avdstudio.core.setup.SetupPlan
import dev.marcos.avdstudio.core.setup.SetupPlanner
import dev.marcos.avdstudio.core.setup.SetupStep
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
    private val setupPlanner = SetupPlanner(fileSystem, environment)

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

    /** Emulators currently running on this Mac, however they were started. Never throws. */
    public fun runningEmulators(): List<RunningEmulator> =
        try {
            val result = runner.run(RunningEmulators.listProcesses)
            if (result.isSuccess) RunningEmulators.parse(result.standardOutput) else emptyList()
        } catch (_: CommandException) {
            emptyList()
        }

    /**
     * Asks the emulator running [avdName] to shut down (SIGTERM). The process id is looked up again
     * right now so a stale id can never signal an unrelated process. Returns false if it is not running.
     */
    @Throws(CommandException::class)
    public fun stopAvd(avdName: String): Boolean {
        val running = runningEmulators().firstOrNull { it.avdName == avdName } ?: return false
        val result = runner.run(Command("/bin/kill", listOf("-TERM", running.processId.toString())))
        if (!result.isSuccess) {
            throw CommandException("Could not stop $avdName: ${result.standardError.trim().ifEmpty { "kill failed" }}")
        }
        return true
    }

    /** What is missing on this Mac and how to install it. Nothing runs. */
    public fun setupPlan(
        sdkPathOverride: String? = null,
        avdHomeOverride: String? = null,
    ): SetupPlan =
        setupPlanner.plan(
            toolchain = toolchainStatus(sdkPathOverride),
            java = javaInstallation(),
            avds = listAvds(sdkPathOverride, avdHomeOverride),
        )

    /**
     * Runs one step of a [SetupPlan] to completion. The environment (JAVA_HOME, PATH, ANDROID_HOME) is
     * resolved now, not when the plan was made, so a JDK installed by an earlier step is picked up.
     */
    @Throws(CommandException::class)
    public fun runSetupStep(
        step: SetupStep,
        sdkPathOverride: String? = null,
        avdHomeOverride: String? = null,
    ): CommandResult {
        val plan = setupPlanner.plan(toolchainStatus(sdkPathOverride), javaInstallation(), emptyList())
        val toolEnvironment = ToolEnvironment(environment).build(plan.sdkPath, avdHome(avdHomeOverride), javaInstallation())
        val brewBin = setupPlanner.homebrewPath()?.substringBeforeLast('/')
        val path = listOfNotNull(brewBin, toolEnvironment["PATH"]).joinToString(":")
        return runner.run(step.command.copy(environment = toolEnvironment + step.command.environment + ("PATH" to path)))
    }
}
