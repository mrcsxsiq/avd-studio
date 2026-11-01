package dev.marcos.avdstudio.core

import dev.marcos.avdstudio.core.avd.Avd
import dev.marcos.avdstudio.core.avd.AvdCreator
import dev.marcos.avdstudio.core.avd.AvdHomeLocator
import dev.marcos.avdstudio.core.avd.AvdNames
import dev.marcos.avdstudio.core.avd.AvdRepository
import dev.marcos.avdstudio.core.avd.CreateAvdRequest
import dev.marcos.avdstudio.core.catalog.AvailableSystemImage
import dev.marcos.avdstudio.core.catalog.AvailableSystemImages
import dev.marcos.avdstudio.core.catalog.DeviceProfile
import dev.marcos.avdstudio.core.catalog.DeviceProfileCatalog
import dev.marcos.avdstudio.core.catalog.SystemImage
import dev.marcos.avdstudio.core.catalog.SystemImageCatalog
import dev.marcos.avdstudio.core.catalog.SystemImagePackage
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
import dev.marcos.avdstudio.core.sdk.SdkDownloadMonitor
import dev.marcos.avdstudio.core.sdk.SdkLocator
import dev.marcos.avdstudio.core.sdk.SdkManagerListParser
import dev.marcos.avdstudio.core.sdk.ToolEnvironment
import dev.marcos.avdstudio.core.sdk.ToolchainStatus
import dev.marcos.avdstudio.core.setup.SetupPlan
import dev.marcos.avdstudio.core.setup.SetupPlanner
import dev.marcos.avdstudio.core.setup.SetupStep
import dev.marcos.avdstudio.core.update.AppUpdater
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
    private val systemImageCatalog = SystemImageCatalog(fileSystem)
    private val avdCreator = AvdCreator(fileSystem, runner)
    private val appUpdater = AppUpdater(runner, fileSystem, setupPlanner)
    private val downloadMonitor = SdkDownloadMonitor(fileSystem)

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

    // MARK: Creating and deleting devices

    /** System images installed in the SDK, newest first. Needs no Java. */
    public fun installedSystemImages(sdkPathOverride: String? = null): List<SystemImage> {
        val toolchain = toolchainStatus(sdkPathOverride)
        return if (toolchain.sdkDirectoryExists) systemImageCatalog.installed(toolchain.sdkPath) else emptyList()
    }

    /** Hardware definitions from `avdmanager list device`. Needs avdmanager and Java. */
    @Throws(CommandException::class)
    public fun deviceProfiles(sdkPathOverride: String? = null): List<DeviceProfile> {
        val (avdManager, environment) = avdManagerOrThrow(sdkPathOverride, null)
        val result = runner.run(Command(avdManager, listOf("list", "device"), environment))
        if (!result.isSuccess) {
            throw CommandException(
                "avdmanager could not list devices: ${result.standardError.trim().ifEmpty { "exit code ${result.exitCode}" }}",
            )
        }
        return DeviceProfileCatalog.parse(result.standardOutput)
    }

    /** A message when [name] cannot be used for a new device, or null when it can. */
    public fun validateAvdName(
        name: String,
        avdHomeOverride: String? = null,
    ): String? = AvdNames.validate(name, listAvds(null, avdHomeOverride).map { it.name })

    /** Creates the device and returns its folder. */
    @Throws(CommandException::class)
    public fun createAvd(
        request: CreateAvdRequest,
        sdkPathOverride: String? = null,
        avdHomeOverride: String? = null,
    ): String {
        validateAvdName(request.name, avdHomeOverride)?.let { throw CommandException(it) }
        val (avdManager, environment) = avdManagerOrThrow(sdkPathOverride, avdHomeOverride)
        return avdCreator.create(request, avdManager, toolchainStatus(sdkPathOverride).sdkPath, avdHome(avdHomeOverride), environment)
    }

    /** Deletes the device and its files. Refuses while it is running. */
    @Throws(CommandException::class)
    public fun deleteAvd(
        avdName: String,
        sdkPathOverride: String? = null,
        avdHomeOverride: String? = null,
    ) {
        if (runningEmulators().any { it.avdName == avdName }) throw CommandException("$avdName is running. Stop it first.")
        // Without avdmanager or Java the device can still be deleted: it is just a .ini and a folder.
        val tool =
            try {
                avdManagerOrThrow(sdkPathOverride, avdHomeOverride)
            } catch (_: CommandException) {
                null
            }
        avdCreator.delete(avdName, tool?.first, avdHome(avdHomeOverride), tool?.second.orEmpty())
    }

    // MARK: Downloading and removing system images

    /**
     * The system images `sdkmanager` can download, with the ones already installed marked. Runs
     * `sdkmanager --list`, so it needs Java and the network. Newest Android first; within a version
     * Play > Google APIs > default. With [includeNonNative] false only arm64-v8a images are returned,
     * the only ones that run at full speed on Apple Silicon.
     */
    @Throws(CommandException::class)
    public fun availableSystemImages(
        sdkPathOverride: String? = null,
        includeNonNative: Boolean = false,
    ): List<AvailableSystemImage> {
        val tool = sdkManagerOrThrow(sdkPathOverride)
        val result = runner.run(Command(tool.executable, listOf("--sdk_root=${tool.sdkPath}", "--list"), tool.environment))
        if (!result.isSuccess) {
            val problem = sdkManagerComplaint(result.standardError.ifBlank { result.standardOutput })
            throw CommandException("sdkmanager could not list the system images: ${problem.ifEmpty { "exit code ${result.exitCode}" }}")
        }
        val listing = SdkManagerListParser.parse(result.standardOutput)
        if (listing.available.isEmpty()) {
            // Offline, sdkmanager still lists what is installed but exits normally.
            throw CommandException(
                "sdkmanager did not list any downloadable packages. Check your internet connection and try again." +
                    sdkManagerComplaint(result.standardError).takeIf { it.isNotEmpty() }?.let { " ($it)" }.orEmpty(),
            )
        }
        return AvailableSystemImages.from(listing).filter { includeNonNative || it.isNativeOnAppleSilicon }
    }

    /** The `;` form of a system image package (`/` and a trailing separator are accepted), or null when it is not one. */
    public fun normalizedSystemImagePackage(value: String): String? = SystemImagePackage.normalize(value)

    /**
     * Accepts the Android SDK licenses and then downloads and installs [packages] with `sdkmanager`.
     * [licensesAccepted] must be true: the person has to have read and agreed to the license first,
     * this never decides for them. Only system images are accepted (`system-images;android-36;...`, or
     * with `/`). Returns the result of the command that failed, or of the install when everything worked.
     */
    @Throws(CommandException::class)
    public fun installSystemImages(
        packages: List<String>,
        licensesAccepted: Boolean,
        sdkPathOverride: String? = null,
    ): CommandResult {
        if (!licensesAccepted) {
            throw CommandException(
                "Installing system images means accepting the Android SDK License Agreement (${SetupPlan.LICENSE_URL}). " +
                    "Read it, then agree to continue.",
            )
        }
        if (packages.isEmpty()) throw CommandException("Choose at least one system image to install.")
        val names = packages.map { SystemImagePackage.normalize(it) ?: throw CommandException(notASystemImage(it)) }.distinct()

        val tool = sdkManagerOrThrow(sdkPathOverride)
        // `yes` answers every prompt; the status of the pipeline is sdkmanager's. Paths travel as positional
        // parameters, never spliced into the script.
        val licenses = runner.run(Command("/bin/sh", listOf("-c", ACCEPT_LICENSES_SCRIPT, tool.executable, tool.sdkPath), tool.environment))
        if (!licenses.isSuccess) return licenses
        val install = runner.run(Command(tool.executable, listOf("--sdk_root=${tool.sdkPath}") + names, tool.environment))
        // sdkmanager does not always fail loudly for a package it cannot find.
        val notFound = install.isSuccess && MISSING_PACKAGE.containsMatchIn(install.standardOutput + install.standardError)
        return CommandResult(
            exitCode = if (notFound) 1 else install.exitCode,
            standardOutput = licenses.standardOutput + install.standardOutput,
            standardError = licenses.standardError + install.standardError,
        )
    }

    /**
     * How many bytes `sdkmanager` has downloaded since [sinceEpochMillis] into this SDK, read from the files it is
     * writing (it prints no percentage when it is not in a terminal). Poll it while [installSystemImages] runs.
     */
    public fun sdkDownloadedBytes(
        sinceEpochMillis: Long,
        sdkPathOverride: String? = null,
    ): Long = downloadMonitor.downloadedBytes(toolchainStatus(sdkPathOverride).sdkPath, sinceEpochMillis)

    /** Names of the virtual devices whose configuration points at [packagePath] (`;` or `/` form). */
    public fun devicesUsingSystemImage(
        packagePath: String,
        sdkPathOverride: String? = null,
        avdHomeOverride: String? = null,
    ): List<String> {
        val image = SystemImagePackage.normalize(packagePath) ?: return emptyList()
        return listAvds(sdkPathOverride, avdHomeOverride)
            .filter { avd -> avd.systemImagePackage?.let { SystemImagePackage.same(it, image) } == true }
            .map { it.name }
    }

    /**
     * Uninstalls a system image with `sdkmanager --uninstall`. Refuses while an emulator started from a
     * device that uses it is running (always), and while any device still uses it unless [force] is true.
     */
    @Throws(CommandException::class)
    public fun removeSystemImage(
        packagePath: String,
        sdkPathOverride: String? = null,
        avdHomeOverride: String? = null,
        force: Boolean = false,
    ): CommandResult {
        val image = SystemImagePackage.normalize(packagePath) ?: throw CommandException(notASystemImage(packagePath))
        val devices = devicesUsingSystemImage(image, sdkPathOverride, avdHomeOverride)
        val running = runningEmulators().map { it.avdName }.filter { it in devices }
        if (running.isNotEmpty()) {
            val verb = if (running.size == 1) "is" else "are"
            throw CommandException("${running.joinToString(", ")} $verb running with this system image. Stop it first.")
        }
        if (devices.isNotEmpty() && !force) {
            throw CommandException("Devices use this system image: ${devices.joinToString(", ")}. Delete them first, or remove it anyway.")
        }
        val tool = sdkManagerOrThrow(sdkPathOverride)
        return runner.run(Command(tool.executable, listOf("--sdk_root=${tool.sdkPath}", "--uninstall", image), tool.environment))
    }

    // MARK: Updating the app itself

    /** True when Homebrew is installed and manages AVD Studio, so it should be the one to update it. */
    public fun canUpdateAppWithHomebrew(): Boolean = appUpdater.canUpdateWithHomebrew()

    /** Runs `brew upgrade --cask mrcsxsiq/avd-studio/avd-studio`. Can take a minute: brew refreshes its taps first. */
    @Throws(CommandException::class)
    public fun upgradeAppWithHomebrew(): CommandResult = appUpdater.upgradeWithHomebrew()

    /** Mounts a downloaded disk image read-only at [mountPoint] (an absolute path), hidden from the Finder. */
    @Throws(CommandException::class)
    public fun mountDiskImage(
        dmgPath: String,
        mountPoint: String,
    ): CommandResult = appUpdater.mountDiskImage(dmgPath, mountPoint)

    @Throws(CommandException::class)
    public fun unmountDiskImage(mountPoint: String): CommandResult = appUpdater.unmountDiskImage(mountPoint)

    /**
     * Copies an app bundle with `ditto`, which keeps everything its code signature depends on. Not called `copy…`:
     * Objective-C gives methods with that prefix special memory rules and Kotlin/Native does not export them.
     */
    @Throws(CommandException::class)
    public fun duplicateApplication(
        source: String,
        destination: String,
    ): CommandResult = appUpdater.copyApplication(source, destination)

    /** Checks that an app bundle is complete and its code signature is intact (`codesign --verify --deep --strict`). */
    @Throws(CommandException::class)
    public fun verifyApplicationSignature(path: String): CommandResult = appUpdater.verifyApplication(path)

    private fun avdManagerOrThrow(
        sdkPathOverride: String?,
        avdHomeOverride: String?,
    ): Pair<String, Map<String, String>> {
        val toolchain = toolchainStatus(sdkPathOverride)
        val avdManager =
            toolchain.executable(AndroidTool.AVD_MANAGER)
                ?: throw CommandException("avdmanager is not installed in ${toolchain.sdkPath}. Run setup first.")
        val java = javaInstallation() ?: throw CommandException("avdmanager needs a Java runtime and none was found. Run setup first.")
        return avdManager to ToolEnvironment(environment).build(toolchain.sdkPath, avdHome(avdHomeOverride), java)
    }

    private class SdkManagerTool(
        val executable: String,
        val sdkPath: String,
        val environment: Map<String, String>,
    )

    private fun sdkManagerOrThrow(sdkPathOverride: String?): SdkManagerTool {
        val toolchain = toolchainStatus(sdkPathOverride)
        val sdkManager =
            toolchain.executable(AndroidTool.SDK_MANAGER)
                ?: throw CommandException(
                    "sdkmanager is not installed in ${toolchain.sdkPath}. Run `avdstudio setup` to install it, " +
                        "or `avdstudio doctor` to see what is missing.",
                )
        val java =
            javaInstallation()
                ?: throw CommandException(
                    "sdkmanager needs a Java runtime and none was found. Run `avdstudio setup` to install one, " +
                        "or `avdstudio doctor` to see what is missing.",
                )
        return SdkManagerTool(sdkManager, toolchain.sdkPath, ToolEnvironment(environment).build(toolchain.sdkPath, avdHome(null), java))
    }

    private fun notASystemImage(value: String) =
        "\"$value\" is not a system image. Use a package like system-images;android-36;google_apis_playstore;arm64-v8a."

    /** The last lines sdkmanager printed, without its deprecation banner. */
    private fun sdkManagerComplaint(text: String): String =
        text
            .lines()
            .map { it.trim() }
            .filter { it.isNotEmpty() && !DEPRECATION_NOTICE.containsMatchIn(it) }
            .takeLast(3)
            .joinToString(" ")

    private companion object {
        const val ACCEPT_LICENSES_SCRIPT = "/usr/bin/yes | \"\$0\" --sdk_root=\"\$1\" --licenses"
        val DEPRECATION_NOTICE = Regex("sdkmanager\\) is deprecated|The 'android' binary|documentation \\(https://d.android.com")
        val MISSING_PACKAGE = Regex("Failed to find package|^Package .+ not found", RegexOption.MULTILINE)
    }
}
