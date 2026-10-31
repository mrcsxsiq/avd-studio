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
                    // Keeps the real /Library/Java and Android Studio of this Mac out of every test.
                    systemRoot = root.toString(),
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

    // MARK: images / devices / create / delete

    /** An avdmanager that answers `list device`, and creates/deletes AVD files like the real one. */
    private fun installFakeAvdManager() {
        val script =
            """
            #!/bin/sh
            echo "avdmanager ¤*" >> "$root/avdmanager.log"
            case "¤1 ¤2" in
              "list device")
                printf 'Available devices definitions:\nid: 54 or "pixel_9"\n    Name: Pixel 9\n    OEM : Google\n---------\nid: 69 or "tv_4k"\n    Name: Television (4K)\n    OEM : Google\n    Tag : android-tv\n---------\n';;
              "create avd")
                name=""; pkg=""
                while [ ¤# -gt 0 ]; do case "¤1" in --name) name="¤2"; shift;; --package) pkg="¤2"; shift;; esac; shift; done
                dir="¤ANDROID_AVD_HOME/¤name.avd"; mkdir -p "¤dir"
                printf 'avd.ini.encoding=UTF-8\npath=%s\ntarget=android-36\n' "¤dir" > "¤ANDROID_AVD_HOME/¤name.ini"
                printf 'PlayStore.enabled=no\nhw.device.name=pixel_9\nimage.sysdir.1=%s/\ntag.id=google_apis_playstore\nhw.gpu.enabled=no\n' "¤(echo "¤pkg" | tr ';' '/')" > "¤dir/config.ini"
                echo "Auto-selecting single ABI arm64-v8a";;
              "delete avd")
                name=""; while [ ¤# -gt 0 ]; do case "¤1" in --name) name="¤2"; shift;; esac; shift; done
                rm -rf "¤ANDROID_AVD_HOME/¤name.avd" "¤ANDROID_AVD_HOME/¤name.ini"; echo "AVD '¤name' deleted.";;
            esac
            """.trimIndent().replace('¤', '$')
        executable(sdk / "cmdline-tools/latest/bin/avdmanager", script)
    }

    private val playImage = "system-images;android-36;google_apis_playstore;arm64-v8a"

    private fun installImage(
        platform: String,
        tag: String,
        abi: String,
        properties: String,
    ) {
        write(sdk / "system-images/$platform/$tag/$abi/system.img")
        write(sdk / "system-images/$platform/$tag/$abi/source.properties", properties)
    }

    private fun readyToCreate() {
        installSdk()
        installJava()
        installFakeAvdManager()
        fs.createDirectories(avdHome)
        installImage(
            "android-36",
            "google_apis_playstore",
            "arm64-v8a",
            "AndroidVersion.ApiLevel=36\nSystemImage.TagId=google_apis_playstore\nSystemImage.TagDisplay=Google Play\nSystemImage.Abi=arm64-v8a\n",
        )
        installImage(
            "android-34",
            "google_apis",
            "x86_64",
            "AndroidVersion.ApiLevel=34\nSystemImage.TagId=google_apis\nSystemImage.TagDisplay=Google APIs\nSystemImage.Abi=x86_64\n",
        )
    }

    @Test
    fun imagesListsInstalledSystemImagesNewestFirst() {
        readyToCreate()

        val result = cli.test(arrayOf("images") + locations)

        assertEquals(0, result.statusCode)
        assertContains(result.stdout, "ANDROID")
        assertTrue(result.stdout.indexOf("Android 16 (API 36)") < result.stdout.indexOf("Android 14 (API 34)"))
        assertContains(result.stdout, "x86_64 (slow)")
        assertContains(result.stdout, playImage)
        assertContains(cli.test(arrayOf("images", "--json") + locations).stdout, "\"package\": \"$playImage\"")
    }

    @Test
    fun imagesExplainsHowToInstallOneWhenThereAreNone() {
        installSdk()

        assertContains(cli.test(arrayOf("images") + locations).stdout, "No system images installed")
    }

    @Test
    fun devicesListsAndFiltersHardwareDefinitions() {
        readyToCreate()

        val all = cli.test(arrayOf("devices") + locations)
        val tv = cli.test(arrayOf("devices", "--type", "tv") + locations)

        assertEquals(0, all.statusCode)
        assertContains(all.stdout, "pixel_9")
        assertContains(all.stdout, "Television (4K)")
        assertContains(tv.stdout, "tv_4k")
        assertFalse(tv.stdout.contains("pixel_9"))
        assertContains(cli.test(arrayOf("devices", "--json", "--type", "phone") + locations).stdout, "\"type\": \"Phone\"")
    }

    @Test
    fun devicesFailsClearlyWithoutJava() {
        installSdk()
        installFakeAvdManager()

        val result = cli.test(arrayOf("devices") + locations)

        assertEquals(1, result.statusCode)
        assertContains(result.stderr, "Java")
    }

    @Test
    fun createMakesADeviceThatListShowsRightAway() {
        readyToCreate()

        val result =
            cli.test(
                arrayOf(
                    "create",
                    "-n",
                    "Pixel_9_API_36",
                    "-i",
                    playImage,
                    "-d",
                    "pixel_9",
                    "--display-name",
                    "My Pixel",
                    "--ram",
                    "4096",
                    "--sdcard",
                    "512M",
                ) +
                    locations,
            )

        assertEquals(0, result.statusCode, result.stderr)
        assertContains(result.stdout, "Created Pixel_9_API_36")
        assertContains(result.stdout, "avdstudio start Pixel_9_API_36")
        val log = fs.read(root / "avdmanager.log") { readUtf8() }
        assertContains(log, "create avd --name Pixel_9_API_36 --package $playImage --device pixel_9 --sdcard 512M")
        val config = fs.read(avdHome / "Pixel_9_API_36.avd/config.ini") { readUtf8() }
        assertContains(config, "PlayStore.enabled=true")
        assertContains(config, "hw.gpu.enabled=yes")
        assertContains(config, "hw.ramSize=4096")
        assertContains(config, "avd.ini.displayname=My Pixel")
        val list = cli.test(arrayOf("list", "--json") + locations).stdout
        assertContains(list, "\"displayName\": \"My Pixel\"")
        assertContains(list, "\"playStore\": true")
    }

    @Test
    fun createRejectsUnknownImagesDevicesAndTakenNames() {
        readyToCreate()

        val badImage =
            cli.test(arrayOf("create", "-n", "A", "-i", "system-images;android-99;default;arm64-v8a", "-d", "pixel_9") + locations)
        assertEquals(1, badImage.statusCode)
        assertContains(badImage.stderr, "avdstudio images")

        val badDevice = cli.test(arrayOf("create", "-n", "A", "-i", playImage, "-d", "flip_phone") + locations)
        assertEquals(1, badDevice.statusCode)
        assertContains(badDevice.stderr, "avdstudio devices")

        cli.test(arrayOf("create", "-n", "Taken", "-i", playImage, "-d", "pixel_9") + locations)
        val taken = cli.test(arrayOf("create", "-n", "taken", "-i", playImage, "-d", "pixel_9") + locations)
        assertEquals(1, taken.statusCode)
        assertContains(taken.stderr, "already exists")
    }

    @Test
    fun deleteNeedsConfirmationUnlessYesIsGiven() {
        readyToCreate()
        cli.test(arrayOf("create", "-n", "Gone", "-i", playImage, "-d", "pixel_9") + locations)

        val refused = cli.test(arrayOf("delete", "Gone") + locations)
        assertEquals(1, refused.statusCode)
        assertContains(refused.stderr, "--yes")
        assertTrue(fs.exists(avdHome / "Gone.ini"))

        val deleted = cli.test(arrayOf("delete", "Gone", "--yes") + locations)
        assertEquals(0, deleted.statusCode, deleted.stderr)
        assertContains(deleted.stdout, "Deleted Gone.")
        assertFalse(fs.exists(avdHome / "Gone.ini"))
        assertFalse(fs.exists(avdHome / "Gone.avd"))

        assertEquals(1, cli.test(arrayOf("delete", "Gone", "--yes") + locations).statusCode)
    }
}
