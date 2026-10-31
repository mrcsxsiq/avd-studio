package dev.marcos.avdstudio.core

import dev.marcos.avdstudio.core.doctor.CheckStatus
import dev.marcos.avdstudio.core.emulator.EmulatorLaunchOptions
import dev.marcos.avdstudio.core.process.Command
import dev.marcos.avdstudio.core.process.CommandException
import dev.marcos.avdstudio.core.process.CommandResult
import dev.marcos.avdstudio.core.process.CommandRunner
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

    override fun run(command: Command): CommandResult {
        executed += command
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
}
