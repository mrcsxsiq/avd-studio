package dev.marcos.avdstudio.cli

import com.github.ajalt.clikt.core.CliktCommand
import com.github.ajalt.clikt.core.Context
import com.github.ajalt.clikt.core.ProgramResult
import com.github.ajalt.clikt.core.UsageError
import com.github.ajalt.clikt.core.findObject
import com.github.ajalt.clikt.core.findOrSetObject
import com.github.ajalt.clikt.core.subcommands
import com.github.ajalt.clikt.core.terminal
import com.github.ajalt.clikt.parameters.arguments.argument
import com.github.ajalt.clikt.parameters.arguments.multiple
import com.github.ajalt.clikt.parameters.groups.OptionGroup
import com.github.ajalt.clikt.parameters.groups.provideDelegate
import com.github.ajalt.clikt.parameters.options.flag
import com.github.ajalt.clikt.parameters.options.option
import com.github.ajalt.clikt.parameters.options.required
import com.github.ajalt.clikt.parameters.options.versionOption
import com.github.ajalt.clikt.parameters.types.choice
import com.github.ajalt.clikt.parameters.types.int
import dev.marcos.avdstudio.core.AvdStudioCore
import dev.marcos.avdstudio.core.avd.CreateAvdRequest
import dev.marcos.avdstudio.core.avd.FormFactor
import dev.marcos.avdstudio.core.emulator.EmulatorLaunchOptions
import dev.marcos.avdstudio.core.environment.SystemEnvironment
import dev.marcos.avdstudio.core.process.CommandException
import dev.marcos.avdstudio.core.process.NativeCommandRunner
import dev.marcos.avdstudio.core.setup.SetupPlan
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
            SetupCommand(coreFactory),
            ImagesCommand(coreFactory),
            DevicesCommand(coreFactory),
            CreateCommand(coreFactory),
            DeleteCommand(coreFactory),
            SdkPathCommand(coreFactory),
        )
    }

    override fun help(context: Context) = "Manage Android Virtual Devices from the terminal."

    override fun helpEpilog(context: Context) =
        "Something not working? Run `avdstudio doctor`: it checks your setup and tells you exactly how to fix it."

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

    override fun help(context: Context) = "Check that everything AVD Studio needs is in place, and say how to fix what is not."

    override fun helpEpilog(context: Context) =
        """
        What it checks:
          - the Android SDK folder and its tools: sdkmanager, avdmanager, emulator, adb
          - a Java runtime (sdkmanager and avdmanager need one)
          - the virtual device folder, and devices whose system image is not installed

        For every problem it prints numbered next steps with commands you can copy.

        Exit status: 0 when everything required is ready (warnings are allowed), 1 when something required is missing.

        Examples:
          avdstudio doctor
          avdstudio doctor --sdk-path /Volumes/ssd/android-sdk
          avdstudio doctor --json
        """.trimIndent()

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

class SetupCommand(
    private val coreFactory: CoreFactory,
) : CliktCommand(name = "setup") {
    private val location by LocationOptions()
    private val dryRun by option("--dry-run", help = "Show what would be installed and stop.").flag()
    private val script by option("--script", help = "Print the equivalent shell script instead of running anything.").flag()
    private val acceptLicenses by
        option(
            "--accept-licenses",
            help = "Accept the Android SDK License Agreement (${SetupPlan.LICENSE_URL}) so sdkmanager can install packages.",
        ).flag()

    override fun help(context: Context) = "Install what is missing: command-line tools, Java, the emulator and system images."

    override fun helpEpilog(context: Context) =
        """
        Uses Homebrew for the Android command-line tools and Java, and sdkmanager for everything else.
        Without Homebrew it cannot run the steps itself; use --script to get a script to run in a terminal,
        or install the tools from ${SetupPlan.COMMAND_LINE_TOOLS_URL} and pass --sdk-path.

        Steps that already succeeded are skipped when you run it again.

        Examples:
          avdstudio setup --dry-run
          avdstudio setup --accept-licenses
          avdstudio setup --script > setup.sh
        """.trimIndent()

    override fun run() {
        val core = coreFactory()
        val plan = core.setupPlan(location.sdkPath, location.avdHome)
        if (script) {
            echo(plan.shellScript, trailingNewline = false)
            return
        }
        if (plan.isEmpty) {
            echo(Output.success("Nothing to install: your Android SDK is ready."))
            return
        }

        echo(Output.heading("This will:"))
        plan.steps.forEachIndexed { index, step ->
            echo("  ${index + 1}. ${step.title}")
            echo(Output.dim("     ${step.displayCommand}"))
        }
        echo("Into: ${plan.sdkPath}")
        echo()
        if (dryRun) return

        if (!plan.canRunAutomatically) {
            echo("Homebrew is not installed, so avdstudio cannot run these steps itself.", err = true)
            echo("  - Install Homebrew (${SetupPlan.HOMEBREW_URL}) and run `avdstudio setup` again, or", err = true)
            echo("  - run the equivalent script:  avdstudio setup --script > setup.sh && bash setup.sh, or", err = true)
            echo("  - download the tools from ${SetupPlan.COMMAND_LINE_TOOLS_URL} and use --sdk-path.", err = true)
            throw ProgramResult(1)
        }
        if (plan.needsLicenseAcceptance && !acceptLicenses) {
            echo("Installing SDK packages means accepting the Android SDK License Agreement:", err = true)
            echo("  ${SetupPlan.LICENSE_URL}", err = true)
            echo("Run again with --accept-licenses once you have read it.", err = true)
            throw ProgramResult(1)
        }

        plan.steps.forEachIndexed { index, step ->
            echo("[${index + 1}/${plan.steps.size}] ${step.title}…")
            val result =
                try {
                    core.runSetupStep(step, location.sdkPath, location.avdHome)
                } catch (error: CommandException) {
                    echo(Output.failure("    ✗ ${error.message}"), err = true)
                    throw ProgramResult(1)
                }
            if (!result.isSuccess) {
                echo(Output.failure("    ✗ failed (exit ${result.exitCode})"), err = true)
                result.standardError
                    .ifBlank { result.standardOutput }
                    .trim()
                    .lines()
                    .takeLast(20)
                    .forEach { echo("      $it", err = true) }
                echo(Output.dim("    Fix the problem and run `avdstudio setup` again; finished steps are skipped."), err = true)
                throw ProgramResult(1)
            }
            echo(Output.success("    ✓ done"))
        }
        echo()

        // The tools may have landed in Homebrew's own SDK root, which an explicit --sdk-path would hide.
        val sdkPath = location.sdkPath?.takeIf { it == plan.sdkPath } ?: location.sdkPath?.let { plan.sdkPath }
        if (location.sdkPath != null && location.sdkPath != plan.sdkPath) {
            echo(Output.dim("Installed into ${plan.sdkPath}. Use --sdk-path ${plan.sdkPath} (or AVDSTUDIO_SDK_PATH) from now on."))
        }
        val report = core.doctor(sdkPath, location.avdHome)
        echo(Output.doctor(report))
        if (!report.isHealthy) throw ProgramResult(1)
    }
}

private val TYPE_CHOICES =
    mapOf(
        "phone" to FormFactor.PHONE,
        "foldable" to FormFactor.FOLDABLE,
        "tablet" to FormFactor.TABLET,
        "wear" to FormFactor.WEAR_OS,
        "tv" to FormFactor.TV,
        "automotive" to FormFactor.AUTOMOTIVE,
        "desktop" to FormFactor.DESKTOP,
        "xr" to FormFactor.XR,
    )

/**
 * Clikt re-wraps help text and folds single newlines into spaces; only a NEL (U+0085) is a hard line break.
 * Lines of an example block are joined with it so every command stays on its own line.
 */
private fun hardBreaks(vararg lines: String): String = lines.joinToString("\u0085")

/** What `avdstudio images --sdk-path … install` hands down to its subcommand, so the flag works on either side. */
private class InheritedLocations(
    val sdkPath: String?,
    val avdHome: String?,
)

private fun CliktCommand.inherited(): InheritedLocations? = currentContext.findObject<InheritedLocations>()

class ImagesCommand(
    private val coreFactory: CoreFactory,
) : CliktCommand(name = "images") {
    init {
        subcommands(ImagesInstallCommand(coreFactory), ImagesRemoveCommand(coreFactory))
    }

    override val invokeWithoutSubcommand = true

    private val location by LocationOptions()
    private val available by option(
        "--available",
        help = "List the system images you can download (needs Java and a network connection) instead of the installed ones.",
    ).flag()
    private val allAbis by option(
        "--all-abis",
        help = "With --available: include x86 and 32-bit images too. They run slowly on Apple Silicon.",
    ).flag()
    private val json by option("--json", help = "Print machine-readable JSON.").flag()

    override fun help(context: Context) = "List, download and remove system images (the installed ones by default)."

    override fun helpEpilog(context: Context) =
        """
        Without a subcommand this lists the system images installed in the SDK: what `create --image` accepts.
        With --available it lists what Google offers for download and marks the ones you already have.
        Only arm64-v8a images run at full speed on Apple Silicon, so the others are hidden unless you pass --all-abis.

        Examples:
        """.trimIndent() +
            hardBreaks(
                "",
                "  avdstudio images",
                "  avdstudio images --available",
                "  avdstudio images --available --all-abis --json",
                "  avdstudio images install \"system-images;android-36;google_apis_playstore;arm64-v8a\" --accept-licenses",
                "  avdstudio images remove \"system-images;android-34;google_apis;arm64-v8a\"",
            )

    override fun run() {
        currentContext.findOrSetObject { InheritedLocations(location.sdkPath, location.avdHome) }
        if (currentContext.invokedSubcommand != null) return
        if (allAbis && !available) throw UsageError("--all-abis only works together with --available.")
        val core = coreFactory()
        if (available) {
            listAvailable(core)
            return
        }
        val images = core.installedSystemImages(location.sdkPath)
        when {
            json -> {
                echo(Output.json.encodeToString(images.map { it.toDto() }))
            }

            images.isEmpty() -> {
                echo(
                    "No system images installed. Run `avdstudio images --available` to see what you can download, " +
                        "then `avdstudio images install <package>`.",
                )
            }

            else -> {
                echo(Output.imageTable(images))
            }
        }
    }

    private fun listAvailable(core: AvdStudioCore) {
        val images =
            try {
                core.availableSystemImages(location.sdkPath, includeNonNative = allAbis)
            } catch (error: CommandException) {
                echo(error.message, err = true)
                throw ProgramResult(1)
            }
        when {
            json -> {
                echo(Output.json.encodeToString(images.map { it.toDto() }))
            }

            images.isEmpty() -> {
                echo("sdkmanager offers no system images for this Mac.")
            }

            else -> {
                echo(Output.availableImageTable(images))
                echo()
                echo(Output.dim("Install one with: avdstudio images install <package> --accept-licenses"))
            }
        }
    }
}

class ImagesInstallCommand(
    private val coreFactory: CoreFactory,
) : CliktCommand(name = "install") {
    private val location by LocationOptions()
    private val packages by argument(
        name = "PACKAGE",
        help = "A system image from `avdstudio images --available`, e.g. system-images;android-36;google_apis_playstore;arm64-v8a.",
    ).multiple(required = true)
    private val acceptLicenses by
        option(
            "--accept-licenses",
            help = "Accept the Android SDK License Agreement (${SetupPlan.LICENSE_URL}) so sdkmanager can install packages.",
        ).flag()

    override fun help(context: Context) = "Download and install system images with sdkmanager."

    override fun helpEpilog(context: Context) =
        """
        Packages can be written with ';' (quote them, the shell treats ';' specially) or with '/'. Installing
        something that is already installed updates it. Only system images are accepted here.

        Downloading means accepting the Android SDK License Agreement (${SetupPlan.LICENSE_URL}).
        avdstudio never does that for you: read it, then pass --accept-licenses.

        Examples:
        """.trimIndent() +
            hardBreaks(
                "",
                "  avdstudio images install \"system-images;android-36;google_apis_playstore;arm64-v8a\" --accept-licenses",
                "  avdstudio images install system-images/android-36/google_apis/arm64-v8a --accept-licenses",
            )

    override fun run() {
        val core = coreFactory()
        val sdkPath = location.sdkPath ?: inherited()?.sdkPath
        val names = packages.map { core.normalizedSystemImagePackage(it) ?: refuse(it) }.distinct()

        echo(Output.heading("This will download and install:"))
        names.forEach { echo("  $it") }
        echo(Output.dim("Into: ${core.toolchainStatus(sdkPath).sdkPath}"))
        echo()
        if (!acceptLicenses) {
            echo("Installing system images means accepting the Android SDK License Agreement:", err = true)
            echo("  ${SetupPlan.LICENSE_URL}", err = true)
            echo("Run again with --accept-licenses once you have read it.", err = true)
            throw ProgramResult(1)
        }

        echo("Accepting the licenses and downloading. This can take a few minutes…")
        val result =
            try {
                core.installSystemImages(names, licensesAccepted = true, sdkPathOverride = sdkPath)
            } catch (error: CommandException) {
                echo(Output.failure("✗ ${error.message}"), err = true)
                throw ProgramResult(1)
            }
        if (!result.isSuccess) {
            echo(Output.failure("✗ sdkmanager failed (exit ${result.exitCode})"), err = true)
            Output.sdkManagerTail(result).forEach { echo("    $it", err = true) }
            throw ProgramResult(1)
        }
        echo(Output.success("✓ Installed ${names.size} system image${if (names.size == 1) "" else "s"}."))
        echo(Output.dim("Create a device with: avdstudio create -n NAME -i \"${names.first()}\" -d <device>   (see `avdstudio devices`)"))
    }

    private fun refuse(value: String): Nothing {
        echo("\"$value\" is not a system image. Use a package from `avdstudio images --available`.", err = true)
        throw ProgramResult(1)
    }
}

class ImagesRemoveCommand(
    private val coreFactory: CoreFactory,
) : CliktCommand(name = "remove") {
    private val location by LocationOptions()
    private val image by argument(
        name = "PACKAGE",
        help = "An installed system image from `avdstudio images`.",
    )
    private val yes by option("--yes", "-y", help = "Do not ask for confirmation.").flag()
    private val force by option(
        "--force",
        help = "Remove the image even though virtual devices use it. They will not start until it is installed again.",
    ).flag()

    override fun help(context: Context) = "Uninstall a system image and free its disk space."

    override fun helpEpilog(context: Context) =
        """
        Refuses while a virtual device still uses the image (list them with `avdstudio list`), unless you pass --force.
        An image used by a running emulator is never removed: stop the device first.

        Examples:
        """.trimIndent() +
            hardBreaks(
                "",
                "  avdstudio images remove \"system-images;android-34;google_apis;x86_64\"",
                "  avdstudio images remove system-images/android-34/google_apis/x86_64 --yes",
            )

    override fun run() {
        val core = coreFactory()
        val sdkPath = location.sdkPath ?: inherited()?.sdkPath
        val avdHome = location.avdHome ?: inherited()?.avdHome
        val name =
            core.normalizedSystemImagePackage(image)
                ?: fail("\"$image\" is not a system image. Run `avdstudio images` to see what is installed.")
        val installed =
            core.installedSystemImages(sdkPath).firstOrNull { it.packagePath == name }
                ?: fail("The system image \"$name\" is not installed. Run `avdstudio images` to see what is.")

        val users = core.devicesUsingSystemImage(name, sdkPath, avdHome)
        val running = core.runningEmulators().map { it.avdName }.filter { it in users }
        if (running.isNotEmpty()) fail("${running.joinToString(", ")} is running with this system image. Stop it first.")
        if (users.isNotEmpty()) {
            echo("Used by: ${users.joinToString(", ")}", err = !force)
            if (!force) {
                fail("Delete those devices first (`avdstudio delete NAME`), or run again with --force to remove the image anyway.")
            }
        }

        if (!yes) {
            if (!currentContext.terminal.terminalInfo.interactive) {
                echo("Removing a system image deletes its files. Run again with --yes to confirm.", err = true)
                throw ProgramResult(1)
            }
            val size = installed.sizeBytes?.let { " (${Output.formatBytes(it)})" }.orEmpty()
            val confirmed =
                com.github.ajalt.mordant.terminal
                    .YesNoPrompt("Remove $name$size?", currentContext.terminal, default = false)
                    .ask()
            if (confirmed != true) throw ProgramResult(1)
        }

        val result =
            try {
                core.removeSystemImage(name, sdkPath, avdHome, force)
            } catch (error: CommandException) {
                fail(error.message.orEmpty())
            }
        if (!result.isSuccess) {
            echo(Output.failure("✗ sdkmanager failed (exit ${result.exitCode})"), err = true)
            Output.sdkManagerTail(result).forEach { echo("    $it", err = true) }
            throw ProgramResult(1)
        }
        echo(Output.success("Removed $name.") + (installed.sizeBytes?.let { " Freed about ${Output.formatBytes(it)}." } ?: ""))
    }

    private fun fail(message: String): Nothing {
        echo(message, err = true)
        throw ProgramResult(1)
    }
}

class DevicesCommand(
    private val coreFactory: CoreFactory,
) : CliktCommand(name = "devices") {
    private val location by LocationOptions()
    private val type by option("--type", help = "Only this kind of device.").choice(*TYPE_CHOICES.keys.toTypedArray())
    private val json by option("--json", help = "Print machine-readable JSON.").flag()

    override fun help(context: Context) = "List the hardware definitions avdmanager knows (what `create --device` accepts)."

    override fun run() {
        val profiles =
            try {
                coreFactory().deviceProfiles(location.sdkPath)
            } catch (error: CommandException) {
                echo(error.message, err = true)
                throw ProgramResult(1)
            }.filter { type == null || it.formFactor == TYPE_CHOICES.getValue(type!!) }
        if (json) echo(Output.json.encodeToString(profiles.map { it.toDto() })) else echo(Output.profileTable(profiles))
    }
}

class CreateCommand(
    private val coreFactory: CoreFactory,
) : CliktCommand(name = "create") {
    private val location by LocationOptions()
    private val name by option(
        "--name",
        "-n",
        metavar = "NAME",
        help = "Identifier: letters, digits, dots, dashes, underscores.",
    ).required()
    private val image by option("--image", "-i", metavar = "PACKAGE", help = "A system image package from `avdstudio images`.").required()
    private val device by option("--device", "-d", metavar = "ID", help = "A hardware definition id from `avdstudio devices`.").required()
    private val displayName by option("--display-name", metavar = "TEXT", help = "Name shown in the app (default: the name with spaces).")
    private val ram by option("--ram", metavar = "MB", help = "RAM in megabytes (default: the definition's).").int()
    private val storage by option("--storage", metavar = "SIZE", help = "Internal storage, e.g. 16G (default: 10G).")
    private val sdCard by option("--sdcard", metavar = "SIZE", help = "SD card size, e.g. 512M (default: none).")

    override fun help(context: Context) = "Create a virtual device."

    override fun helpEpilog(context: Context) =
        """
        Examples:
          avdstudio create -n Pixel_9_API_36 -i "system-images;android-36;google_apis_playstore;arm64-v8a" -d pixel_9
          avdstudio create -n TV -i "system-images;android-36;android-tv;arm64-v8a" -d tv_1080p --ram 4096 --storage 16G

        Like Android Studio, the GPU, keyboard and device frame are enabled and Google Play is switched on
        when the image has it.
        """.trimIndent()

    override fun run() {
        val core = coreFactory()
        try {
            val systemImage =
                core.installedSystemImages(location.sdkPath).firstOrNull { it.packagePath == image }
                    ?: throw CommandException(
                        "No installed system image called \"$image\". Run `avdstudio images` to see what is available.",
                    )
            val profile =
                core.deviceProfiles(location.sdkPath).firstOrNull { it.id == device }
                    ?: throw CommandException(
                        "No hardware definition called \"$device\". Run `avdstudio devices` to see what is available.",
                    )
            val request =
                CreateAvdRequest(
                    name = name,
                    displayName = displayName,
                    systemImage = systemImage,
                    device = profile,
                    ramMegabytes = ram,
                    storage = storage,
                    sdCard = sdCard,
                )
            val path = core.createAvd(request, location.sdkPath, location.avdHome)
            echo(Output.success("Created $name") + " in $path")
            echo(Output.dim("Start it with: avdstudio start $name"))
        } catch (error: CommandException) {
            echo(error.message, err = true)
            throw ProgramResult(1)
        }
    }
}

class DeleteCommand(
    private val coreFactory: CoreFactory,
) : CliktCommand(name = "delete") {
    private val location by LocationOptions()
    private val name by argument(help = "Name of the virtual device (see `avdstudio list`).")
    private val yes by option("--yes", "-y", help = "Do not ask for confirmation.").flag()

    override fun help(context: Context) = "Delete a virtual device and everything stored on it."

    override fun run() {
        val core = coreFactory()
        if (core.listAvds(location.sdkPath, location.avdHome).none { it.name == name }) {
            echo("No virtual device named '$name'. Run `avdstudio list` to see what is available.", err = true)
            throw ProgramResult(1)
        }
        if (!yes) {
            if (!currentContext.terminal.terminalInfo.interactive) {
                echo("Deleting is permanent. Run again with --yes to confirm.", err = true)
                throw ProgramResult(1)
            }
            val confirmed =
                com.github.ajalt.mordant.terminal
                    .YesNoPrompt(
                        "Delete $name and all its data?",
                        currentContext.terminal,
                        default = false,
                    ).ask()
            if (confirmed != true) throw ProgramResult(1)
        }
        try {
            core.deleteAvd(name, location.sdkPath, location.avdHome)
            echo(Output.success("Deleted $name."))
        } catch (error: CommandException) {
            echo(error.message, err = true)
            throw ProgramResult(1)
        }
    }
}
