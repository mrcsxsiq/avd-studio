package dev.marcos.avdstudio.cli

import com.github.ajalt.clikt.testing.test
import dev.marcos.avdstudio.core.AvdStudioCore
import dev.marcos.avdstudio.core.environment.StaticEnvironment
import dev.marcos.avdstudio.core.process.NativeCommandRunner
import okio.FileSystem
import okio.Path
import kotlin.random.Random
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertContains
import kotlin.test.assertEquals
import kotlin.test.assertFalse

class AvdStudioCliTest {
    private val fs = FileSystem.SYSTEM
    private val root: Path = FileSystem.SYSTEM_TEMPORARY_DIRECTORY / "avdstudio-cli-test-${Random.nextLong().toULong()}"
    private val sdk = root / "sdk"
    private val avdHome = root / "avd"

    private val cli = AvdStudioCli { AvdStudioCore(NativeCommandRunner(), StaticEnvironment(emptyMap(), root.toString())) }

    @AfterTest
    fun cleanUp() {
        fs.deleteRecursively(root)
    }

    private fun write(
        path: Path,
        text: String = "",
    ) {
        path.parent?.let(fs::createDirectories)
        fs.write(path) { writeUtf8(text) }
    }

    private fun installSdk() {
        write(sdk / "cmdline-tools/latest/bin/sdkmanager")
        write(sdk / "cmdline-tools/latest/bin/avdmanager")
        write(sdk / "emulator/emulator")
        write(sdk / "platform-tools/adb")
    }

    private fun createAvd(
        name: String,
        config: String,
    ) {
        write(avdHome / "$name.ini", "path=${avdHome / "$name.avd"}\ntarget=android-34")
        write(avdHome / "$name.avd/config.ini", config)
    }

    private val locations get() = arrayOf("--sdk-path", sdk.toString(), "--avd-home", avdHome.toString())

    @Test
    fun listPrintsATableOfDevices() {
        installSdk()
        createAvd("Pixel_9", "hw.device.name=pixel_9\ntag.id=google_apis\nimage.sysdir.1=system-images/android-34/google_apis/arm64-v8a/")
        fs.createDirectories(sdk / "system-images/android-34/google_apis/arm64-v8a")

        val result = cli.test(arrayOf("list") + locations)

        assertEquals(0, result.statusCode)
        assertContains(result.stdout, "NAME")
        assertContains(result.stdout, "Pixel_9")
        assertContains(result.stdout, "Android 14")
        assertContains(result.stdout, "ready")
    }

    @Test
    fun listFlagsDevicesThatNeedASystemImage() {
        installSdk()
        createAvd("Old", "hw.device.name=pixel_2\nimage.sysdir.1=system-images/android-34/google_apis/arm64-v8a/")

        assertContains(cli.test(arrayOf("list") + locations).stdout, "needs system image")
    }

    @Test
    fun listJsonIsMachineReadable() {
        installSdk()
        createAvd("TV_4K", "hw.device.name=tv_4k\ntag.id=android-tv")

        val stdout = cli.test(arrayOf("list", "--json") + locations).stdout

        assertContains(stdout, "\"name\": \"TV_4K\"")
        assertContains(stdout, "\"type\": \"TV\"")
        assertContains(stdout, "\"api\": \"34\"")
    }

    @Test
    fun listExplainsWhenThereAreNoDevices() {
        val result = cli.test(arrayOf("list") + locations)

        assertEquals(0, result.statusCode)
        assertContains(result.stdout, "No virtual devices found in $avdHome")
    }

    @Test
    fun doctorFailsWithAnExitCodeWhenTheSdkIsMissing() {
        val result = cli.test(arrayOf("doctor") + locations)

        assertEquals(1, result.statusCode)
        assertContains(result.stdout, "brew install --cask android-commandlinetools")
    }

    @Test
    fun doctorSucceedsWithACompleteSdkAndReportsJson() {
        installSdk()

        val result = cli.test(arrayOf("doctor", "--json") + locations)

        assertContains(result.stdout, "\"id\": \"sdk\"")
        assertContains(result.stdout, "\"id\": \"sdkmanager\"")
        assertContains(result.stdout, "\"status\": \"pass\"")
    }

    @Test
    fun startCanPrintTheEmulatorCommandWithoutRunningIt() {
        installSdk()

        val result = cli.test(arrayOf("start", "Pixel_9", "--cold-boot", "--print-command") + locations)

        assertEquals(0, result.statusCode)
        assertEquals("${sdk / "emulator/emulator"} -avd Pixel_9 -no-snapshot-load", result.stdout.trim())
    }

    @Test
    fun startRefusesUnknownDevices() {
        installSdk()

        val result = cli.test(arrayOf("start", "Ghost") + locations)

        assertEquals(1, result.statusCode)
        assertContains(result.stderr, "No virtual device named 'Ghost'")
    }

    @Test
    fun startRefusesDevicesThatCannotBoot() {
        installSdk()
        createAvd("Old", "image.sysdir.1=system-images/android-34/google_apis/arm64-v8a/")

        val result = cli.test(arrayOf("start", "Old") + locations)

        assertEquals(1, result.statusCode)
        assertContains(result.stderr, "system image is not installed")
    }

    @Test
    fun sdkPathPrintsTheFolderAndSignalsWhenItDoesNotExist() {
        assertEquals(1, cli.test(arrayOf("sdk-path") + locations).statusCode)

        installSdk()
        val ok = cli.test(arrayOf("sdk-path") + locations)
        assertEquals(0, ok.statusCode)
        assertEquals(sdk.toString(), ok.stdout.trim())
    }

    @Test
    fun printsTheVersion() {
        assertContains(cli.test("--version").stdout, VERSION)
    }

    @Test
    fun formatsByteSizesLikeFinder() {
        assertEquals("512 B", Output.formatBytes(512))
        assertEquals("1.5 KB", Output.formatBytes(1_500))
        assertEquals("9.6 GB", Output.formatBytes(9_623_615_492))
        assertFalse(Output.formatBytes(2_000_000_000_000).contains("GB"))
        assertEquals("2.0 TB", Output.formatBytes(2_000_000_000_000))
    }
}
