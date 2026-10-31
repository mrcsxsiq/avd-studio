package dev.marcos.avdstudio.cli

import com.github.ajalt.clikt.testing.test
import dev.marcos.avdstudio.core.AvdStudioCore
import dev.marcos.avdstudio.core.environment.StaticEnvironment
import dev.marcos.avdstudio.core.process.NativeCommandRunner
import kotlinx.cinterop.ExperimentalForeignApi
import okio.FileSystem
import okio.Path
import platform.posix.chmod
import kotlin.random.Random
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertContains
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

@OptIn(ExperimentalForeignApi::class)
class AvdStudioCliTest {
    private val fs = FileSystem.SYSTEM
    private val root: Path = FileSystem.SYSTEM_TEMPORARY_DIRECTORY / "avdstudio-cli-test-${Random.nextLong().toULong()}"
    private val sdk = root / "sdk"
    private val avdHome = root / "avd"

    private val cli =
        AvdStudioCli {
            AvdStudioCore(
                NativeCommandRunner(),
                StaticEnvironment(
                    mapOf("HOMEBREW_PREFIX" to (root / "homebrew").toString()),
                    root.toString(),
                ),
            )
        }

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

    @Test
    fun doctorEndsWithNumberedNextStepsAndTellsYouToRunItAgain() {
        val result = cli.test(arrayOf("doctor") + locations)

        assertEquals(1, result.statusCode)
        assertContains(result.stdout, "Next steps")
        assertContains(result.stdout, "1. Install the Android command-line tools with `brew install --cask android-commandlinetools`")
        assertContains(result.stdout, "Then run `avdstudio doctor` again")
    }

    @Test
    fun doctorJsonIncludesTheNextSteps() {
        val stdout = cli.test(arrayOf("doctor", "--json") + locations).stdout

        assertContains(stdout, "\"nextSteps\": [")
        assertContains(stdout, "brew install --cask android-commandlinetools")
    }

    @Test
    fun doctorHelpExplainsWhatItChecksTheExitCodesAndGivesExamples() {
        val help = cli.test("doctor --help").stdout

        assertContains(help, "What it checks")
        assertContains(help, "Exit status")
        assertContains(help, "avdstudio doctor --sdk-path")
    }

    @Test
    fun theMainHelpPointsToDoctorWhenSomethingIsWrong() {
        assertContains(cli.test("--help").stdout, "Run `avdstudio doctor`")
    }

    // MARK: setup

    private val brewPrefix get() = root / "homebrew"
    private val brewSdk get() = brewPrefix / "share/android-commandlinetools"

    private fun executable(
        path: Path,
        script: String,
    ) {
        write(path, script)
        chmod(path.toString(), 0b111_101_101u)
    }

    /** A `brew` that logs its arguments and, for the cask, lays out the command-line tools with a fake sdkmanager. */
    private fun installFakeHomebrew() {
        // '¤' stands for '$' so the shell scripts can live in raw strings without Kotlin templating.
        val sdkManager =
            """
            #!/bin/sh
            echo "sdkmanager ¤*" >> "$root/sdkmanager.log"
            sdk=""
            for a in "¤@"; do case "¤a" in --sdk_root=*) sdk="¤{a#--sdk_root=}";; esac; done
            for a in "¤@"; do
              case "¤a" in
                emulator) mkdir -p "¤sdk/emulator" && touch "¤sdk/emulator/emulator";;
                platform-tools) mkdir -p "¤sdk/platform-tools" && touch "¤sdk/platform-tools/adb";;
                system-images*) dir="¤sdk/¤(echo "¤a" | tr ';' '/')"; mkdir -p "¤dir" && touch "¤dir/system.img";;
              esac
            done
            """.trimIndent().replace('¤', '$')
        executable(root / "fake-sdkmanager", sdkManager)
        val brew =
            """
            #!/bin/sh
            echo "brew ¤*" >> "$root/brew.log"
            case "¤*" in
              *android-commandlinetools*)
                mkdir -p "$brewSdk/cmdline-tools/latest/bin"
                cp "$root/fake-sdkmanager" "$brewSdk/cmdline-tools/latest/bin/sdkmanager"
                touch "$brewSdk/cmdline-tools/latest/bin/avdmanager";;
            esac
            """.trimIndent().replace('¤', '$')
        executable(brewPrefix / "bin/brew", brew)
    }

    private fun installJava() = write(root / ".sdkman/candidates/java/current/bin/java")

    @Test
    fun setupDryRunListsTheStepsAndWhereTheyInstall() {
        installJava()

        val result = cli.test(arrayOf("setup", "--dry-run") + locations)

        assertEquals(0, result.statusCode)
        assertContains(result.stdout, "1. Install the Android command-line tools")
        assertContains(result.stdout, "brew install --cask android-commandlinetools")
        assertContains(result.stdout, "Into: $brewSdk")
        assertFalse(result.stdout.contains("openjdk"), "Java is installed, so no Java step")
    }

    @Test
    fun setupWithoutHomebrewExplainsTheAlternatives() {
        val result = cli.test(arrayOf("setup") + locations)

        assertEquals(1, result.statusCode)
        assertContains(result.stderr, "Homebrew is not installed")
        assertContains(result.stderr, "avdstudio setup --script")
        assertContains(result.stderr, "--sdk-path")
    }

    @Test
    fun setupScriptPrintsARunnableScriptThatInstallsHomebrewFirst() {
        val result = cli.test(arrayOf("setup", "--script") + locations)

        assertEquals(0, result.statusCode)
        assertTrue(result.stdout.startsWith("#!/bin/bash"))
        assertContains(result.stdout, "install.sh")
        assertContains(result.stdout, "brew install --cask android-commandlinetools")
    }

    @Test
    fun setupRefusesToAcceptTheLicensesOnTheUsersBehalf() {
        installFakeHomebrew()
        installJava()

        val result = cli.test(arrayOf("setup") + locations)

        assertEquals(1, result.statusCode)
        assertContains(result.stderr, "--accept-licenses")
        assertContains(result.stderr, "developer.android.com/studio/terms")
        assertFalse(fs.exists(root / "brew.log"), "nothing may run before the license is accepted")
    }

    @Test
    fun setupInstallsEverythingThenReportsAHealthySdk() {
        installFakeHomebrew()
        installJava()
        fs.createDirectories(avdHome)

        val result = cli.test(arrayOf("setup", "--accept-licenses") + locations)

        assertEquals(0, result.statusCode, result.stdout + result.stderr)
        assertContains(result.stdout, "[1/3] Install the Android command-line tools")
        assertContains(result.stdout, "[2/3] Accept the Android SDK licenses")
        assertContains(result.stdout, "[3/3] Install the emulator and platform tools")
        assertContains(result.stdout, "Everything looks good.")
        assertEquals("brew install --cask android-commandlinetools\n", fs.read(root / "brew.log") { readUtf8() })
        val sdkManagerLog = fs.read(root / "sdkmanager.log") { readUtf8() }
        assertContains(sdkManagerLog, "--sdk_root=$brewSdk --licenses")
        assertContains(sdkManagerLog, "--sdk_root=$brewSdk emulator platform-tools")
        assertTrue(fs.exists(brewSdk / "emulator/emulator"))
        assertContains(result.stdout, "Installed into $brewSdk. Use --sdk-path")
    }

    @Test
    fun setupIsANoOpOnceEverythingIsInstalled() {
        installSdk()
        installJava()

        val result = cli.test(arrayOf("setup", "--accept-licenses") + locations)

        assertEquals(0, result.statusCode)
        assertContains(result.stdout, "Nothing to install")
    }

    @Test
    fun setupStopsAtAFailingStepAndShowsItsOutput() {
        installFakeHomebrew()
        installJava()
        executable(brewPrefix / "bin/brew", "#!/bin/sh\necho 'Error: No available formula' >&2\nexit 1\n")

        val result = cli.test(arrayOf("setup", "--accept-licenses") + locations)

        assertEquals(1, result.statusCode)
        assertContains(result.stderr, "failed (exit 1)")
        assertContains(result.stderr, "No available formula")
        assertContains(result.stderr, "run `avdstudio setup` again")
    }
}
