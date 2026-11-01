package dev.marcos.avdstudio.core

import dev.marcos.avdstudio.core.avd.CreateAvdRequest
import dev.marcos.avdstudio.core.doctor.CheckStatus
import dev.marcos.avdstudio.core.emulator.EmulatorLaunchOptions
import dev.marcos.avdstudio.core.process.Command
import dev.marcos.avdstudio.core.process.CommandException
import dev.marcos.avdstudio.core.process.CommandResult
import dev.marcos.avdstudio.core.process.CommandRunner
import okio.Path.Companion.toPath
import okio.fakefilesystem.FakeFileSystem
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertTrue

private class RecordingRunner : CommandRunner {
    val detached = mutableListOf<Command>()
    val executed = mutableListOf<Command>()
    var psOutput = ""
    var killExitCode = 0

    /** Scripted answers for any other executable (avdmanager in the create/delete tests). */
    var onRun: ((Command) -> CommandResult)? = null

    override fun run(command: Command): CommandResult {
        executed += command
        onRun?.let { return it(command) }
        return when (command.executable) {
            "/bin/ps" -> CommandResult(0, psOutput, "")
            "/opt/homebrew/bin/brew" -> CommandResult(0, "brewed", "")
            "/bin/kill" -> CommandResult(killExitCode, "", if (killExitCode == 0) "" else "No such process")
            else -> CommandResult(0, "", "")
        }
    }

    override fun launchDetached(command: Command): Int {
        detached += command
        return 4242
    }
}

class AvdStudioCoreTest {
    private val fs = FakeFileSystem()
    private val runner = RecordingRunner()
    private val sdk = "$HOME/Library/Android/sdk"

    private fun core(vararg env: Pair<String, String>) = AvdStudioCore(runner, fakeEnvironment(*env), fs)

    @Test
    fun launchesTheEmulatorWithTheResolvedToolchainEnvironment() {
        fs.installSdk(sdk)
        fs.touch("/jdk/bin/java")

        val pid =
            core("JAVA_HOME" to "/jdk", "PATH" to "/usr/bin")
                .launchAvd("Pixel_9", EmulatorLaunchOptions(coldBoot = true))

        val command = runner.detached.single()
        assertEquals(4242, pid)
        assertEquals("$sdk/emulator/emulator", command.executable)
        assertEquals(listOf("-avd", "Pixel_9", "-no-snapshot-load"), command.arguments)
        assertEquals(sdk, command.environment["ANDROID_SDK_ROOT"])
        assertEquals("$HOME/.android/avd", command.environment["ANDROID_AVD_HOME"])
        assertEquals("/jdk", command.environment["JAVA_HOME"])
    }

    @Test
    fun explicitSdkAndAvdFolderOverrideDetection() {
        fs.installSdk("/Volumes/ssd/sdk")

        val command = core().launchCommand("A", sdkPathOverride = "/Volumes/ssd/sdk", avdHomeOverride = "/Volumes/ssd/avd")

        assertEquals("/Volumes/ssd/sdk/emulator/emulator", command.executable)
        assertEquals("/Volumes/ssd/avd", command.environment["ANDROID_AVD_HOME"])
    }

    @Test
    fun refusesToLaunchWithoutAnEmulator() {
        val error = assertFailsWith<CommandException> { core().launchAvd("Pixel_9") }

        assertTrue(error.message.orEmpty().contains("emulator is not installed"))
        assertTrue(runner.detached.isEmpty())
    }

    @Test
    fun doctorFailsOnAnEmptyMachineAndExplainsHowToFixIt() {
        val report = core().doctor()

        assertFalse(report.isHealthy)
        val sdkCheck = report.checks.first { it.id == "sdk" }
        assertEquals(CheckStatus.FAIL, sdkCheck.status)
        assertTrue(sdkCheck.hint.orEmpty().contains("brew install --cask android-commandlinetools"))
        assertEquals(CheckStatus.WARNING, report.checks.first { it.id == "java" }.status)
        assertEquals(CheckStatus.WARNING, report.checks.first { it.id == "avd-home" }.status)
    }

    @Test
    fun doctorIsHealthyWithACompleteSetupAndWarnsAboutMissingSystemImages() {
        fs.installSdk(sdk)
        fs.touch("/jdk/bin/java")
        fs.touch("$HOME/.android/avd/Old.ini", "path=$HOME/.android/avd/Old.avd\ntarget=android-23")
        fs.touch(
            "$HOME/.android/avd/Old.avd/config.ini",
            "hw.device.name=pixel_2\nimage.sysdir.1=system-images/android-23/google_apis/arm64-v8a/",
        )

        val report = core("JAVA_HOME" to "/jdk").doctor()

        assertTrue(report.isHealthy)
        assertTrue(report.hasWarnings)
        val images = report.checks.first { it.id == "system-images" }
        assertEquals(CheckStatus.WARNING, images.status)
        assertTrue(images.detail.contains("Old"))
        assertEquals(CheckStatus.PASS, report.checks.first { it.id == "avd-home" }.status)
    }

    @Test
    fun missingAdbIsAWarningButMissingEmulatorIsAFailure() {
        fs.touch("$sdk/cmdline-tools/latest/bin/sdkmanager")
        fs.touch("$sdk/cmdline-tools/latest/bin/avdmanager")

        val checks = core().doctor().checks.associateBy { it.id }

        assertEquals(CheckStatus.FAIL, checks.getValue("emulator").status)
        assertEquals(CheckStatus.WARNING, checks.getValue("adb").status)
        assertEquals("Install it with `sdkmanager \"emulator\"`.", checks.getValue("emulator").hint)
    }

    @Test
    fun reportsRunningEmulatorsFromTheProcessList() {
        runner.psOutput = "77 /x/qemu-system-aarch64 -avd Pixel_9 -netdelay none\n1 /sbin/launchd"

        val running = core().runningEmulators()

        assertEquals(listOf("Pixel_9"), running.map { it.avdName })
        assertEquals(77, running.single().processId)
    }

    @Test
    fun stopSignalsOnlyTheProcessLookedUpByName() {
        runner.psOutput = "77 /x/qemu-system-aarch64 -avd Pixel_9\n78 /x/qemu-system-aarch64 -avd Other"

        assertTrue(core().stopAvd("Pixel_9"))

        val kill = runner.executed.single { it.executable == "/bin/kill" }
        assertEquals(listOf("-TERM", "77"), kill.arguments)
    }

    @Test
    fun stopDoesNothingWhenTheDeviceIsNotRunning() {
        runner.psOutput = "1 /sbin/launchd"

        assertFalse(core().stopAvd("Pixel_9"))
        assertTrue(runner.executed.none { it.executable == "/bin/kill" })
    }

    @Test
    fun stopSurfacesKillFailures() {
        runner.psOutput = "77 /x/qemu-system-aarch64 -avd Pixel_9"
        runner.killExitCode = 1

        val error = assertFailsWith<CommandException> { core().stopAvd("Pixel_9") }

        assertTrue(error.message.orEmpty().contains("No such process"))
    }

    @Test
    fun nextStepsForAnEmptyMachineListOnlyThePrerequisites() {
        val steps = core().doctor().nextSteps

        assertEquals(2, steps.size)
        assertTrue(steps[0].contains("brew install --cask android-commandlinetools"))
        assertTrue(steps[1].contains("brew install openjdk@17"))
    }

    @Test
    fun nextStepsGiveExactSdkmanagerCommandsForMissingPackagesAndSystemImages() {
        fs.touch("$sdk/cmdline-tools/latest/bin/sdkmanager")
        fs.touch("$sdk/cmdline-tools/latest/bin/avdmanager")
        fs.touch("/jdk/bin/java")
        fs.touch("$HOME/.android/avd/TV.ini", "path=$HOME/.android/avd/TV.avd\ntarget=android-34")
        fs.touch(
            "$HOME/.android/avd/TV.avd/config.ini",
            "hw.device.name=tv_4k\nimage.sysdir.1=system-images/android-34/android-tv/arm64-v8a/",
        )
        fs.touch("$HOME/.android/avd/Phone.ini", "path=$HOME/.android/avd/Phone.avd\ntarget=android-34")
        fs.touch(
            "$HOME/.android/avd/Phone.avd/config.ini",
            "hw.device.name=pixel_9\nimage.sysdir.1=system-images/android-34/google_apis/arm64-v8a/",
        )

        val steps = core("JAVA_HOME" to "/jdk").doctor().nextSteps

        assertEquals(
            listOf(
                "Install the missing SDK packages with `sdkmanager --sdk_root=$sdk \"emulator\" \"platform-tools\"`.",
                "Install the system images your devices need with `sdkmanager --sdk_root=$sdk " +
                    "\"system-images;android-34;google_apis;arm64-v8a\" \"system-images;android-34;android-tv;arm64-v8a\"` " +
                    "(or delete those devices).",
            ),
            steps,
        )
    }

    @Test
    fun nextStepsAreEmptyWhenEverythingIsReady() {
        fs.installSdk(sdk)
        fs.touch("/jdk/bin/java")

        assertTrue(core("JAVA_HOME" to "/jdk").doctor().nextSteps.isEmpty())
    }

    @Test
    fun runSetupStepResolvesTheEnvironmentAtRunTimeAndKeepsHomebrewOnThePath() {
        fs.touch("/opt/homebrew/bin/brew")
        fs.touch("/jdk/bin/java")
        val core = core("JAVA_HOME" to "/jdk", "PATH" to "/usr/bin", "HOMEBREW_PREFIX" to "/opt/homebrew")
        val step = core.setupPlan().steps.first { it.kind == dev.marcos.avdstudio.core.setup.SetupStepKind.COMMAND_LINE_TOOLS }

        val result = core.runSetupStep(step)

        assertEquals("brewed", result.standardOutput)
        val executed = runner.executed.single { it.executable == "/opt/homebrew/bin/brew" }
        assertEquals("/jdk", executed.environment["JAVA_HOME"])
        assertEquals("1", executed.environment["NONINTERACTIVE"])
        assertEquals("/opt/homebrew/share/android-commandlinetools", executed.environment["ANDROID_HOME"])
        assertTrue(executed.environment.getValue("PATH").startsWith("/opt/homebrew/bin:"))
    }

    // MARK: Creating and deleting devices

    private val avdManager get() = "$sdk/cmdline-tools/latest/bin/avdmanager"
    private val avdHome get() = "$HOME/.android/avd"

    private fun readyForAvdManager(): AvdStudioCore {
        fs.installSdk(sdk)
        fs.touch("/jdk/bin/java")
        return core("JAVA_HOME" to "/jdk")
    }

    private val playImage =
        dev.marcos.avdstudio.core.catalog.SystemImage(
            packagePath = "system-images;android-36;google_apis_playstore;arm64-v8a",
            directory = "system-images/android-36/google_apis_playstore/arm64-v8a",
            apiLevel =
                dev.marcos.avdstudio.core.avd
                    .ApiLevel(36),
            codeName = null,
            tags = listOf("google_apis_playstore"),
            tagDisplay = "Google Play",
            abi = "arm64-v8a",
        )
    private val pixel9 =
        dev.marcos.avdstudio.core.catalog.DeviceProfile(
            "pixel_9",
            "Pixel 9",
            "Google",
            null,
            dev.marcos.avdstudio.core.avd.FormFactor.PHONE,
        )

    /** What a real `avdmanager create avd` leaves behind (trimmed). */
    private fun fakeAvdManagerThatCreates(): (Command) -> CommandResult =
        { command ->
            val name = command.arguments[command.arguments.indexOf("--name") + 1]
            fs.touch("$avdHome/$name.ini", "avd.ini.encoding=UTF-8\npath=$avdHome/$name.avd\ntarget=android-36\n")
            fs.touch(
                "$avdHome/$name.avd/config.ini",
                "PlayStore.enabled=no\nabi.type=arm64-v8a\nhw.device.name=pixel_9\nhw.gpu.enabled=no\nhw.keyboard=no\n" +
                    "hw.ramSize=2G\ndisk.dataPartition.size=10G\nimage.sysdir.1=system-images/android-36/google_apis_playstore/arm64-v8a/\ntag.id=google_apis_playstore\n",
            )
            CommandResult(0, "Loading local repository...\nAuto-selecting single ABI arm64-v8a\n", "")
        }

    @Test
    fun createRunsAvdManagerWithTheRightArgumentsAndEnvironment() {
        val core = readyForAvdManager()
        runner.onRun = fakeAvdManagerThatCreates()

        val folder =
            core.createAvd(
                CreateAvdRequest(name = "Pixel_9_API_36", systemImage = playImage, device = pixel9, sdCard = "512M"),
            )

        val command = runner.executed.single { it.executable == avdManager }
        assertEquals(
            listOf(
                "create",
                "avd",
                "--name",
                "Pixel_9_API_36",
                "--package",
                playImage.packagePath,
                "--device",
                "pixel_9",
                "--sdcard",
                "512M",
            ),
            command.arguments,
        )
        assertEquals("/jdk", command.environment["JAVA_HOME"])
        assertEquals(avdHome, command.environment["ANDROID_AVD_HOME"])
        assertEquals("$avdHome/Pixel_9_API_36.avd", folder)
    }

    @Test
    fun createFixesUpConfigLikeAndroidStudioDoes() {
        val core = readyForAvdManager()
        fs.touch("$sdk/skins/pixel_9/layout")
        runner.onRun = fakeAvdManagerThatCreates()

        core.createAvd(
            CreateAvdRequest(
                name = "Pixel_9_API_36",
                displayName = "My Pixel",
                systemImage = playImage,
                device = pixel9,
                ramMegabytes = 4096,
                storage = "16G",
            ),
        )

        val config =
            dev.marcos.avdstudio.core.internal.IniParser.parse(
                fs.read("$avdHome/Pixel_9_API_36.avd/config.ini".toPath()) { readUtf8() },
            )
        assertEquals("true", config["PlayStore.enabled"])
        assertEquals("yes", config["hw.gpu.enabled"])
        assertEquals("auto", config["hw.gpu.mode"])
        assertEquals("yes", config["hw.keyboard"])
        assertEquals("My Pixel", config["avd.ini.displayname"])
        assertEquals("4096", config["hw.ramSize"])
        assertEquals("16G", config["disk.dataPartition.size"])
        assertEquals("pixel_9", config["skin.name"])
        assertEquals("$sdk/skins/pixel_9", config["skin.path"])
        assertEquals("yes", config["showDeviceFrame"])
        assertEquals("pixel_9", config["hw.device.name"], "untouched keys survive")
        // The new device is visible to the reader right away.
        val created = core.listAvds().single()
        assertEquals("My Pixel", created.displayName)
        assertTrue(created.hasPlayStore)
    }

    @Test
    fun createTreatsErrorTextAsFailureEvenWithExitCodeZero() {
        val core = readyForAvdManager()
        runner.onRun = { CommandResult(0, "Error: No device found matching --device nope.\nnull\n", "") }

        val error =
            assertFailsWith<CommandException> { core.createAvd(CreateAvdRequest(name = "X", systemImage = playImage, device = pixel9)) }

        assertEquals("Could not create X: No device found matching --device nope.", error.message)
    }

    @Test
    fun createRefusesBadOrDuplicateNamesWithoutRunningAnything() {
        val core = readyForAvdManager()
        fs.touch("$avdHome/Taken.ini", "path=$avdHome/Taken.avd")
        fs.touch("$avdHome/Taken.avd/config.ini", "")

        assertFailsWith<CommandException> { core.createAvd(CreateAvdRequest(name = "has space", systemImage = playImage, device = pixel9)) }
        assertFailsWith<CommandException> { core.createAvd(CreateAvdRequest(name = "taken", systemImage = playImage, device = pixel9)) }
        assertTrue(runner.executed.none { it.executable == avdManager })
        assertEquals("A device called taken already exists.", core.validateAvdName("taken"))
        assertEquals(null, core.validateAvdName("Fresh_1"))
    }

    @Test
    fun createNeedsAvdManagerAndJava() {
        fs.installSdk(sdk)

        val error =
            assertFailsWith<CommandException> { core().createAvd(CreateAvdRequest(name = "X", systemImage = playImage, device = pixel9)) }

        assertTrue(error.message.orEmpty().contains("Java"))
    }

    @Test
    fun deleteRemovesTheIniAndTheFolderWithoutStartingAvdManager() {
        val core = readyForAvdManager()
        fs.touch("$avdHome/Old.ini", "path=$avdHome/Old.avd")
        fs.touch("$avdHome/Old.avd/config.ini", "")
        fs.touch("$avdHome/Old.avd/userdata.img", "x")

        core.deleteAvd("Old")

        assertFalse(fs.exists("$avdHome/Old.ini".toPath()))
        assertFalse(fs.exists("$avdHome/Old.avd".toPath()))
        // avdmanager would delete whatever path= or path.rel= says, unchecked, so it is never asked to.
        assertTrue(runner.executed.none { it.executable == avdManager }, "avdmanager never ran")
    }

    @Test
    fun deleteWorksWithoutJavaAndWithoutTheCommandLineTools() {
        fs.touch("$avdHome/Old.ini", "path=$avdHome/Old.avd")
        fs.touch("$avdHome/Old.avd/config.ini", "")
        fs.touch("$avdHome/NoImage.ini", "path=$avdHome/NoImage.avd")
        fs.touch("$avdHome/NoImage.avd/config.ini", "image.sysdir.1=system-images/android-99/x/arm64-v8a/")

        core().deleteAvd("Old")
        core().deleteAvd("NoImage")

        assertFalse(fs.exists("$avdHome/Old.avd".toPath()))
        assertFalse(fs.exists("$avdHome/NoImage.avd".toPath()), "a device whose system image is missing is deleted too")
    }

    @Test
    fun deleteSaysSoWhenThereIsNoSuchDevice() {
        val error = assertFailsWith<CommandException> { core().deleteAvd("Ghost") }

        assertTrue(error.message.orEmpty().contains("No device called Ghost"), error.message)
    }

    @Test
    fun deleteRemovesAFolderLeftWithoutItsIni() {
        fs.touch("$avdHome/Orphan.avd/config.ini", "")

        core().deleteAvd("Orphan")

        assertFalse(fs.exists("$avdHome/Orphan.avd".toPath()))
    }

    @Test
    fun deleteRemovesADeviceKeptInAnotherFolder() {
        // avdmanager create avd -p ~/myavds/Custom writes an absolute path= and a folder with a config.ini.
        fs.touch("$avdHome/Custom.ini", "path=$HOME/myavds/Custom")
        fs.touch("$HOME/myavds/Custom/config.ini", "")
        fs.touch("$HOME/myavds/Custom/userdata.img", "x")

        core().deleteAvd("Custom")

        assertFalse(fs.exists("$HOME/myavds/Custom".toPath()))
        assertFalse(fs.exists("$avdHome/Custom.ini".toPath()))
    }

    @Test
    fun deleteFollowsPathRelLikeTheDeviceList() {
        // path.rel is relative to the parent of the AVD home ($HOME/.android), and path= may be stale.
        fs.touch("$avdHome/Moved.ini", "path=/gone/Moved.avd\npath.rel=elsewhere/Moved")
        fs.touch("$HOME/.android/elsewhere/Moved/config.ini", "")

        core().deleteAvd("Moved")

        assertFalse(fs.exists("$HOME/.android/elsewhere/Moved".toPath()))
    }

    @Test
    fun deleteRefusesAPathThatIsNotAnAvdFolderWhateverTheIniSays() {
        fs.touch("$avdHome/Bad.ini", "path=$HOME/Documents")
        fs.touch("$HOME/Documents/thesis.txt", "precious")

        val error = assertFailsWith<CommandException> { core().deleteAvd("Bad") }

        assertTrue(error.message.orEmpty().contains("does not look like an AVD folder"), error.message)
        assertTrue(fs.exists("$HOME/Documents/thesis.txt".toPath()), "the folder the path pointed at is untouched")
        assertTrue(fs.exists("$avdHome/Bad.ini".toPath()), "nothing was removed")
    }

    @Test
    fun deleteRefusesPathRelPointingOutsideToo() {
        // Reproduced with the real avdmanager: path= missing or stale and path.rel=../Documents deleted Documents.
        fs.touch("$avdHome/Rel.ini", "path=/nonexistent/Rel.avd\npath.rel=../Documents")
        // $HOME/.android/avd is the AVD home, so ../Documents from its parent ($HOME/.android) is $HOME/Documents.
        fs.touch("$HOME/Documents/thesis.txt", "precious")
        fs.touch("$avdHome/OnlyRel.ini", "path.rel=../Documents")

        for (name in listOf("Rel", "OnlyRel")) {
            assertFailsWith<CommandException>(name) { core().deleteAvd(name) }
        }

        assertTrue(fs.exists("$HOME/Documents/thesis.txt".toPath()))
        assertTrue(fs.exists("$avdHome/Rel.ini".toPath()) && fs.exists("$avdHome/OnlyRel.ini".toPath()), "nothing was removed")
    }

    @Test
    fun aFolderCalledAvdIsNotEnoughToBeDeleted() {
        fs.touch("$avdHome/Sneaky.ini", "path=$HOME/Documents/stuff.avd")
        fs.touch("$HOME/Documents/stuff.avd/notes.txt", "mine")

        assertFailsWith<CommandException> { core().deleteAvd("Sneaky") }

        assertTrue(fs.exists("$HOME/Documents/stuff.avd/notes.txt".toPath()))
    }

    @Test
    fun deleteNeverRemovesTheAvdHomeOrAFolderAboveIt() {
        // Even with a config.ini inside, these are not one device's folder.
        fs.touch("$avdHome/Home.ini", "path=$avdHome")
        fs.touch("$avdHome/config.ini", "")
        fs.touch("$avdHome/Above.ini", "path=$HOME/.android")
        fs.touch("$HOME/.android/config.ini", "")

        for (name in listOf("Home", "Above")) assertFailsWith<CommandException>(name) { core().deleteAvd(name) }

        assertTrue(fs.exists("$avdHome/Home.ini".toPath()) && fs.exists("$avdHome/Above.ini".toPath()))
    }

    @Test
    fun deleteRefusesNamesThatAreNotDeviceNames() {
        fs.touch("$HOME/outside.ini", "path=$HOME/outside.avd")
        fs.touch("$HOME/outside.avd/config.ini", "")

        for (name in listOf("../../outside", "a/b", "a\\b", "..", "", "  ")) {
            val error = assertFailsWith<CommandException>("\"$name\"") { core().deleteAvd(name) }
            assertEquals("\"$name\" is not a device name.", error.message, "the name guard itself answers, not a later lookup")
        }

        assertTrue(fs.exists("$HOME/outside.avd/config.ini".toPath()))
    }

    @Test
    fun deleteRefusesARunningDevice() {
        val core = readyForAvdManager()
        runner.psOutput = "77 /x/qemu-system-aarch64 -avd Busy"

        val error = assertFailsWith<CommandException> { core.deleteAvd("Busy") }

        assertEquals("Busy is running. Stop it first.", error.message)
        assertTrue(runner.executed.none { it.executable == avdManager })
    }

    @Test
    fun deviceProfilesComeFromAvdManagerListDevice() {
        val core = readyForAvdManager()
        runner.onRun = { CommandResult(0, "id: 54 or \"pixel_9\"\n    Name: Pixel 9\n    OEM : Google\n---------\n", "") }

        val profiles = core.deviceProfiles()

        assertEquals(listOf("pixel_9"), profiles.map { it.id })
        assertEquals(listOf("list", "device"), runner.executed.single { it.executable == avdManager }.arguments)
    }

    @Test
    fun installedSystemImagesAreReadFromTheSdkFolder() {
        fs.installSdk(sdk)
        fs.touch("$sdk/system-images/android-36/google_apis_playstore/arm64-v8a/system.img")

        assertEquals(
            listOf("system-images;android-36;google_apis_playstore;arm64-v8a"),
            core().installedSystemImages().map { it.packagePath },
        )
        assertTrue(core().installedSystemImages("/nowhere").isEmpty())
    }

    // MARK: Downloading and removing system images

    private val sdkManager get() = "$sdk/cmdline-tools/latest/bin/sdkmanager"
    private val playImagePackage = "system-images;android-36;google_apis_playstore;arm64-v8a"

    private fun readyForSdkManager(): AvdStudioCore {
        fs.installSdk(sdk)
        fs.touch("/jdk/bin/java")
        return core("JAVA_HOME" to "/jdk")
    }

    private fun usedBy(
        name: String,
        image: String,
    ) {
        fs.touch("$avdHome/$name.ini", "path=$avdHome/$name.avd\ntarget=android-36")
        fs.touch("$avdHome/$name.avd/config.ini", "hw.device.name=pixel_9\nimage.sysdir.1=$image")
    }

    @Test
    fun availableImagesComeFromSdkmanagerListAndOnlyTheNativeOnesByDefault() {
        val core = readyForSdkManager()
        runner.onRun = { CommandResult(0, SDKMANAGER_LIST, "WARNING: The SDK Manager CLI tool (sdkmanager) is deprecated.\n") }

        val native = core.availableSystemImages()

        val command = runner.executed.single()
        assertEquals(sdkManager, command.executable)
        assertEquals(listOf("--sdk_root=$sdk", "--list"), command.arguments)
        assertEquals("/jdk", command.environment["JAVA_HOME"])
        assertEquals(sdk, command.environment["ANDROID_HOME"])
        assertTrue(native.isNotEmpty() && native.all { it.isNativeOnAppleSilicon })
        assertEquals("system-images;android-canary-20261007;google_apis_playstore_ps16k;arm64-v8a", native.first().packagePath)
        assertEquals(
            setOf(
                playImagePackage,
                "system-images;android-23;default;armeabi-v7a",
            ),
            core
                .availableSystemImages(includeNonNative = true)
                .filter {
                    it.isInstalled
                }.map { it.packagePath }
                .toSet(),
        )
        assertEquals(19, core.availableSystemImages(includeNonNative = true).size)
    }

    @Test
    fun availableImagesUseTheExplicitSdkFolder() {
        fs.installSdk("/Volumes/ssd/sdk")
        fs.touch("/jdk/bin/java")
        runner.onRun = { CommandResult(0, SDKMANAGER_LIST, "") }

        core("JAVA_HOME" to "/jdk").availableSystemImages(sdkPathOverride = "/Volumes/ssd/sdk")

        val command = runner.executed.single()
        assertEquals("/Volumes/ssd/sdk/cmdline-tools/latest/bin/sdkmanager", command.executable)
        assertEquals(listOf("--sdk_root=/Volumes/ssd/sdk", "--list"), command.arguments)
    }

    @Test
    fun sdkmanagerToolsAreRequiredAndTheErrorsSayHowToFixThat() {
        val noSdk = assertFailsWith<CommandException> { core().availableSystemImages() }
        assertTrue(noSdk.message.orEmpty().contains("sdkmanager is not installed"))
        assertTrue(noSdk.message.orEmpty().contains("avdstudio setup"))
        assertTrue(noSdk.message.orEmpty().contains("avdstudio doctor"))

        fs.installSdk(sdk)
        val noJava = assertFailsWith<CommandException> { core().installSystemImages(listOf(playImagePackage), licensesAccepted = true) }
        assertTrue(noJava.message.orEmpty().contains("Java"))
        assertTrue(noJava.message.orEmpty().contains("avdstudio setup"))
        assertTrue(runner.executed.isEmpty())
    }

    @Test
    fun availableImagesReportWhatSdkmanagerComplainedAboutWithoutItsBanner() {
        val core = readyForSdkManager()
        runner.onRun = {
            CommandResult(
                1,
                "",
                "WARNING: The SDK Manager CLI tool (sdkmanager) is deprecated. Android CLI will be used instead.\n" +
                    "The 'android' binary can also be found in the cmdline-tools directory.\n" +
                    "Error: Could not determine SDK root.\n",
            )
        }

        val error = assertFailsWith<CommandException> { core.availableSystemImages() }

        assertEquals("sdkmanager could not list the system images: Error: Could not determine SDK root.", error.message)
    }

    @Test
    fun availableImagesExplainAnOfflineListing() {
        val core = readyForSdkManager()
        runner.onRun = {
            CommandResult(
                0,
                "Installed packages:\n  emulator  37.2.13  Android Emulator\n",
                "Warning: Failed to download any source lists!\n",
            )
        }

        val error = assertFailsWith<CommandException> { core.availableSystemImages() }

        assertTrue(error.message.orEmpty().contains("internet connection"))
        assertTrue(error.message.orEmpty().contains("Failed to download any source lists"))
    }

    @Test
    fun installNeverAcceptsTheLicenseOnItsOwn() {
        val core = readyForSdkManager()

        val error = assertFailsWith<CommandException> { core.installSystemImages(listOf(playImagePackage), licensesAccepted = false) }

        assertTrue(error.message.orEmpty().contains("developer.android.com/studio/terms"))
        assertTrue(runner.executed.isEmpty())
    }

    @Test
    fun installRefusesAnythingButSystemImages() {
        val core = readyForSdkManager()
        val refused =
            listOf(
                emptyList<String>(),
                listOf("emulator"),
                listOf(playImagePackage, "platform-tools"),
                listOf("system-images;android-36"),
                listOf("system-images;android-36;google_apis;arm64-v8a; rm -rf ~"),
                listOf("system-images/../../emulator/x/y"),
                listOf("\"$playImagePackage\""),
            )

        for (packages in refused) {
            assertFailsWith<CommandException>(packages.toString()) { core.installSystemImages(packages, licensesAccepted = true) }
        }
        assertTrue(runner.executed.isEmpty())
    }

    @Test
    fun installAcceptsTheLicensesThenInstallsTheNormalisedPackages() {
        val core = readyForSdkManager()
        runner.onRun = { command ->
            if (command.executable == "/bin/sh") {
                CommandResult(0, "All SDK package licenses accepted.\n", "")
            } else {
                CommandResult(0, "[=======] 100% Unzipping...\n", "")
            }
        }

        val result =
            core.installSystemImages(
                listOf(
                    "system-images/android-36/google_apis_playstore/arm64-v8a/",
                    playImagePackage,
                    "system-images;android-35;default;arm64-v8a",
                ),
                licensesAccepted = true,
            )

        val (licenses, install) = runner.executed
        assertEquals("/bin/sh", licenses.executable)
        assertEquals(
            listOf("-c", "/usr/bin/yes | \"\$0\" --sdk_root=\"\$1\" --licenses", sdkManager, sdk),
            licenses.arguments,
            "paths are positional parameters, never part of the script",
        )
        assertEquals(sdkManager, install.executable)
        assertEquals(
            listOf("--sdk_root=$sdk", playImagePackage, "system-images;android-35;default;arm64-v8a"),
            install.arguments,
        )
        assertEquals("/jdk", install.environment["JAVA_HOME"])
        assertEquals("/jdk", licenses.environment["JAVA_HOME"])
        assertTrue(result.isSuccess)
        assertTrue(result.standardOutput.contains("All SDK package licenses accepted."))
        assertTrue(result.standardOutput.contains("Unzipping"))
    }

    @Test
    fun installStopsAndReportsTheFailingLicenseStep() {
        val core = readyForSdkManager()
        runner.onRun = { CommandResult(1, "", "License for package Android SDK Platform-Tools not accepted.") }

        val result = core.installSystemImages(listOf(playImagePackage), licensesAccepted = true)

        assertEquals(1, result.exitCode)
        assertTrue(result.standardError.contains("not accepted"))
        assertEquals(1, runner.executed.size)
    }

    @Test
    fun installReportsAFailedDownload() {
        val core = readyForSdkManager()
        runner.onRun = { command ->
            if (command.executable ==
                "/bin/sh"
            ) {
                CommandResult(0, "", "")
            } else {
                CommandResult(1, "", "Warning: Failed to download https://dl.google.com/x.zip")
            }
        }

        val result = core.installSystemImages(listOf(playImagePackage), licensesAccepted = true)

        assertFalse(result.isSuccess)
        assertTrue(result.standardError.contains("Failed to download"))
    }

    @Test
    fun installCountsAPackageSdkmanagerCouldNotFindAsAFailureEvenWithExitCodeZero() {
        val core = readyForSdkManager()
        runner.onRun = { command ->
            if (command.executable ==
                "/bin/sh"
            ) {
                CommandResult(0, "", "")
            } else {
                CommandResult(0, "Package system-images;android-99;default;arm64-v8a not found.\n", "")
            }
        }

        val result = core.installSystemImages(listOf("system-images;android-99;default;arm64-v8a"), licensesAccepted = true)

        assertEquals(1, result.exitCode)
    }

    @Test
    fun findsTheDevicesThatUseAnImageWhicheverWayItIsWritten() {
        usedBy("Pixel_9", "system-images/android-36/google_apis_playstore/arm64-v8a/")
        usedBy("Tablet", "system-images/android-36/google_apis_playstore/arm64-v8a")
        usedBy("Other", "system-images/android-34/google_apis/arm64-v8a/")
        fs.touch("$avdHome/Broken.ini", "path=$avdHome/Broken.avd")

        val core = core()

        assertEquals(listOf("Pixel_9", "Tablet"), core.devicesUsingSystemImage(playImagePackage))
        assertEquals(listOf("Pixel_9", "Tablet"), core.devicesUsingSystemImage("system-images/android-36/google_apis_playstore/arm64-v8a/"))
        assertEquals(listOf("Other"), core.devicesUsingSystemImage("system-images;android-34;google_apis;arm64-v8a"))
        assertTrue(core.devicesUsingSystemImage("system-images;android-30;default;arm64-v8a").isEmpty())
        assertTrue(core.devicesUsingSystemImage("emulator").isEmpty())
    }

    @Test
    fun removeUninstallsTheImageWithSdkmanager() {
        val core = readyForSdkManager()
        runner.onRun = { CommandResult(0, "Uninstalling...", "") }

        val result = core.removeSystemImage("system-images/android-36/google_apis_playstore/arm64-v8a")

        assertTrue(result.isSuccess)
        val command = runner.executed.single { it.executable == sdkManager }
        assertEquals(listOf("--sdk_root=$sdk", "--uninstall", playImagePackage), command.arguments)
        assertEquals("/jdk", command.environment["JAVA_HOME"])
    }

    @Test
    fun removeRefusesAnythingButSystemImages() {
        val core = readyForSdkManager()

        for (name in listOf("emulator", "platform-tools", "cmdline-tools;latest", "system-images", "platforms;android-36")) {
            assertFailsWith<CommandException>(name) { core.removeSystemImage(name, force = true) }
        }
        assertTrue(runner.executed.none { it.executable == sdkManager })
    }

    @Test
    fun removeRefusesWhileDevicesUseTheImageUnlessForced() {
        val core = readyForSdkManager()
        usedBy("Pixel_9", "system-images/android-36/google_apis_playstore/arm64-v8a/")
        usedBy("Tablet", "system-images/android-36/google_apis_playstore/arm64-v8a/")

        val error = assertFailsWith<CommandException> { core.removeSystemImage(playImagePackage) }

        assertTrue(error.message.orEmpty().contains("Pixel_9, Tablet"))
        assertTrue(runner.executed.none { it.executable == sdkManager })

        core.removeSystemImage(playImagePackage, force = true)

        assertEquals(
            listOf("--sdk_root=$sdk", "--uninstall", playImagePackage),
            runner.executed.last { it.executable == sdkManager }.arguments,
        )
    }

    @Test
    fun removeNeverTouchesAnImageARunningEmulatorWasStartedFrom() {
        val core = readyForSdkManager()
        usedBy("Busy", "system-images/android-36/google_apis_playstore/arm64-v8a/")
        usedBy("Idle", "system-images/android-36/google_apis_playstore/arm64-v8a/")
        usedBy("Elsewhere", "system-images/android-34/google_apis/arm64-v8a/")
        runner.psOutput = "77 /x/qemu-system-aarch64 -avd Busy\n78 /x/qemu-system-aarch64 -avd Elsewhere"

        val error = assertFailsWith<CommandException> { core.removeSystemImage(playImagePackage, force = true) }

        assertEquals("Busy is running with this system image. Stop it first.", error.message)
        assertTrue(runner.executed.none { it.executable == sdkManager })
    }
}
