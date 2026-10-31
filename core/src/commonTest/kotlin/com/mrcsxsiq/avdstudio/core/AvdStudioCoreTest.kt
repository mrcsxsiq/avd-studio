package com.mrcsxsiq.avdstudio.core

import com.mrcsxsiq.avdstudio.core.doctor.CheckStatus
import com.mrcsxsiq.avdstudio.core.emulator.EmulatorLaunchOptions
import com.mrcsxsiq.avdstudio.core.process.Command
import com.mrcsxsiq.avdstudio.core.process.CommandException
import com.mrcsxsiq.avdstudio.core.process.CommandResult
import com.mrcsxsiq.avdstudio.core.process.CommandRunner
import okio.fakefilesystem.FakeFileSystem
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertTrue

private class RecordingRunner : CommandRunner {
    val detached = mutableListOf<Command>()

    override fun run(command: Command) = CommandResult(0, "", "")

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
}
