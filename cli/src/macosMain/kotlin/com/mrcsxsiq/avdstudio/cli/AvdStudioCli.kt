package com.mrcsxsiq.avdstudio.cli

import com.github.ajalt.clikt.core.CliktCommand
import com.github.ajalt.clikt.core.Context
import com.github.ajalt.clikt.core.ProgramResult
import com.github.ajalt.clikt.core.subcommands
import com.github.ajalt.clikt.parameters.arguments.argument
import com.github.ajalt.clikt.parameters.groups.OptionGroup
import com.github.ajalt.clikt.parameters.groups.provideDelegate
import com.github.ajalt.clikt.parameters.options.flag
import com.github.ajalt.clikt.parameters.options.option
import com.github.ajalt.clikt.parameters.options.versionOption
import com.mrcsxsiq.avdstudio.core.AvdStudioCore
import com.mrcsxsiq.avdstudio.core.emulator.EmulatorLaunchOptions
import com.mrcsxsiq.avdstudio.core.environment.SystemEnvironment
import com.mrcsxsiq.avdstudio.core.process.CommandException
import com.mrcsxsiq.avdstudio.core.process.NativeCommandRunner
import kotlinx.serialization.encodeToString

/** Builds the core; tests inject one wired to a temporary environment. */
typealias CoreFactory = () -> AvdStudioCore

private fun systemCore() = AvdStudioCore(NativeCommandRunner(), SystemEnvironment())

class AvdStudioCli(
    coreFactory: CoreFactory = ::systemCore,
) : CliktCommand(name = "avdstudio") {
    init {
        versionOption(VERSION, names = setOf("--version", "-v"))
        subcommands(
            ListCommand(coreFactory),
            StartCommand(coreFactory),
            DoctorCommand(coreFactory),
            SdkPathCommand(coreFactory),
        )
    }

    override fun help(context: Context) = "Manage Android Virtual Devices from the terminal."

    override fun run() = Unit
}

/** Where the Android SDK and the virtual devices live. Flags beat environment variables, which beat auto-detection. */
class LocationOptions : OptionGroup("Locations") {
    val sdkPath by option(
        "--sdk-path",
        envvar = "AVDSTUDIO_SDK_PATH",
        metavar = "PATH",
        help = "Android SDK folder (default: auto-detect).",
    )
    val avdHome by option(
        "--avd-home",
        envvar = "AVDSTUDIO_AVD_HOME",
        metavar = "PATH",
        help = "Folder holding the virtual devices (default: ~/.android/avd).",
    )
}

class ListCommand(
    private val coreFactory: CoreFactory,
) : CliktCommand(name = "list") {
    private val location by LocationOptions()
    private val json by option("--json", help = "Print machine-readable JSON.").flag()

    override fun help(context: Context) = "List the virtual devices."

    override fun run() {
        val core = coreFactory()
        val avds = core.listAvds(location.sdkPath, location.avdHome)
        when {
            json -> echo(Output.json.encodeToString(avds.map { it.toDto() }))
            avds.isEmpty() -> echo("No virtual devices found in ${core.avdHome(location.avdHome)}.")
            else -> echo(Output.avdTable(avds))
        }
    }
}

class StartCommand(
    private val coreFactory: CoreFactory,
) : CliktCommand(name = "start") {
    private val location by LocationOptions()
    private val name by argument(help = "Name of the virtual device (see `avdstudio list`).")
    private val coldBoot by option("--cold-boot", help = "Ignore the saved snapshot and boot from scratch.").flag()
    private val wipeData by option("--wipe-data", help = "Reset the device to factory state first.").flag()
    private val printCommand by option("--print-command", help = "Only print the emulator command; do not start it.").flag()

    override fun help(context: Context) = "Start a virtual device."

    override fun run() {
        val core = coreFactory()
        val options = EmulatorLaunchOptions(coldBoot = coldBoot, wipeData = wipeData)
        try {
            if (printCommand) {
                echo(core.launchCommand(name, options, location.sdkPath, location.avdHome).displayString)
                return
            }
            val avd =
                core.listAvds(location.sdkPath, location.avdHome).firstOrNull { it.name == name }
                    ?: throw CommandException("No virtual device named '$name'. Run `avdstudio list` to see what is available.")
            if (!avd.isLaunchable) {
                throw CommandException("'$name' cannot start: ${avd.health.explanation()}. Run `avdstudio doctor` for details.")
            }
            val pid = core.launchAvd(name, options, location.sdkPath, location.avdHome)
            echo("Started $name (pid $pid).")
        } catch (error: CommandException) {
            echo(error.message, err = true)
            throw ProgramResult(1)
        }
    }
}

class DoctorCommand(
    private val coreFactory: CoreFactory,
) : CliktCommand(name = "doctor") {
    private val location by LocationOptions()
    private val json by option("--json", help = "Print machine-readable JSON.").flag()

    override fun help(context: Context) = "Check that the Android SDK, Java and virtual device folder are ready."

    override fun run() {
        val report = coreFactory().doctor(location.sdkPath, location.avdHome)
        if (json) echo(Output.json.encodeToString(report.toDto())) else echo(Output.doctor(report))
        if (!report.isHealthy) throw ProgramResult(1)
    }
}

class SdkPathCommand(
    private val coreFactory: CoreFactory,
) : CliktCommand(name = "sdk-path") {
    private val location by LocationOptions()

    override fun help(context: Context) = "Print the Android SDK folder in use (exit 1 if it does not exist)."

    override fun run() {
        val toolchain = coreFactory().toolchainStatus(location.sdkPath)
        echo(toolchain.sdkPath)
        if (!toolchain.sdkDirectoryExists) throw ProgramResult(1)
    }
}
