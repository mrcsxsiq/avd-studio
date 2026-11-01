import AVDStudioCore
import AVDStudioUI
import Foundation
import Testing

@testable import AVDStudioKit

/// Exercises the real Kotlin core through the bridge, against a throw-away home folder.
@Suite("KotlinDeviceService", .serialized)
struct KotlinDeviceServiceTests {
    private let home: URL

    init() throws {
        home = FileManager.default.temporaryDirectory.appendingPathComponent("avdstudio-kit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }

    private func makeService() -> KotlinDeviceService {
        // HOMEBREW_PREFIX is redirected so the real /opt/homebrew SDK on a developer's Mac can never leak into a test.
        KotlinDeviceService(
            environment: StaticEnvironment(
                variables: ["PATH": "/usr/bin:/bin", "HOMEBREW_PREFIX": home.appendingPathComponent("homebrew").path],
                homeDirectory: home.path,
                // Keeps this Mac's real /Library/Java and Android Studio out of the tests.
                systemRoot: home.path
            ))
    }

    private func write(_ relativePath: String, _ text: String = "") throws {
        let url = home.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func installSDK(at relative: String) throws {
        for tool in [
            "cmdline-tools/latest/bin/sdkmanager", "cmdline-tools/latest/bin/avdmanager", "emulator/emulator", "platform-tools/adb",
        ] {
            try write("\(relative)/\(tool)")
        }
    }

    private func createAVD(_ name: String, target: String, config: String) throws {
        try write(".android/avd/\(name).ini", "path=\(home.path)/.android/avd/\(name).avd\ntarget=\(target)\n")
        try write(".android/avd/\(name).avd/config.ini", config)
    }

    @Test func mapsAvdsFromTheKotlinCoreToUiDevices() async throws {
        try installSDK(at: "Library/Android/sdk")
        try write("Library/Android/sdk/system-images/android-34/android-tv/arm64-v8a/system.img")
        try createAVD(
            "Television_4K",
            target: "android-34",
            config: "hw.device.name=tv_4k\ntag.id=android-tv\nabi.type=arm64-v8a\nhw.ramSize=2048\n"
                + "image.sysdir.1=system-images/android-34/android-tv/arm64-v8a/\navd.ini.displayname=Television 4K\n"
        )
        try createAVD(
            "Pixel_Old",
            target: "android-23",
            config: "hw.device.name=pixel_2\nPlayStore.enabled=true\nimage.sysdir.1=system-images/android-23/google_apis/arm64-v8a/\n"
        )

        let snapshot = await makeService().snapshot(locations: Locations())

        let tv = try #require(snapshot.devices.first { $0.id == "Television_4K" })
        #expect(tv.kind == .tv)
        #expect(tv.displayName == "Television 4K")
        #expect(tv.apiLevel == "34")
        #expect(tv.androidVersion == "14")
        #expect(tv.ramMegabytes == 2048)
        #expect(tv.abi == "arm64-v8a")
        #expect(tv.status == .ready)

        let old = try #require(snapshot.devices.first { $0.id == "Pixel_Old" })
        #expect(old.kind == .phone)
        #expect(old.hasPlayStore)
        #expect(old.status == .missingSystemImage)

        #expect(snapshot.toolchain.isConfigured)
        #expect(snapshot.toolchain.sourceDescription == "Android Studio default")
        #expect(snapshot.toolchain.tools.map(\.name) == ["sdkmanager", "avdmanager", "emulator", "adb"])
        #expect(snapshot.avdHome == home.appendingPathComponent(".android/avd").path)
    }

    @Test func explicitLocationsOverrideDetection() async throws {
        try installSDK(at: "elsewhere/sdk")
        try write("custom-avd/Custom.ini", "path=\(home.path)/custom-avd/Custom.avd\ntarget=android-35\n")
        try write("custom-avd/Custom.avd/config.ini", "hw.device.name=pixel_9\n")

        let locations = Locations(
            sdkPath: home.appendingPathComponent("elsewhere/sdk").path, avdHome: home.appendingPathComponent("custom-avd").path)
        let snapshot = await makeService().snapshot(locations: locations)

        #expect(snapshot.devices.map(\.id) == ["Custom"])
        #expect(snapshot.toolchain.sourceDescription == "chosen by you")
        #expect(snapshot.toolchain.isConfigured)
    }

    @Test func reportsAMissingSdkWithoutThrowing() async {
        let snapshot = await makeService().snapshot(locations: Locations())

        #expect(snapshot.devices.isEmpty)
        #expect(snapshot.toolchain.isConfigured == false)
        #expect(snapshot.toolchain.directoryExists == false)
        #expect(snapshot.toolchain.tools.allSatisfy { $0.state == .missing })
    }

    @Test func diagnoseExplainsHowToFixAMissingSdk() async throws {
        let items = await makeService().diagnose(locations: Locations())

        let sdk = try #require(items.first { $0.id == "sdk" })
        #expect(sdk.status == .fail)
        #expect(sdk.hint?.contains("brew install --cask android-commandlinetools") == true)
    }

    @Test func launchSurfacesTheKotlinErrorMessage() async {
        let device = VirtualDevice(id: "Ghost")

        await #expect(throws: ServiceError.self) {
            try await makeService().launch(device, options: LaunchOptions(), locations: Locations())
        }
        do {
            try await makeService().launch(device, options: LaunchOptions(), locations: Locations())
        } catch {
            #expect(error.localizedDescription.contains("emulator is not installed"))
        }
    }

    @Test func stoppingADeviceThatIsNotRunningIsHarmless() async throws {
        try await makeService().stop(VirtualDevice(id: "Definitely_Not_Running_\(UUID().uuidString)"))
    }

    @Test func runningDevicesNeverThrows() async {
        _ = await makeService().runningDevices()
    }

    @Test func setupPlanForAnEmptyMacWithoutHomebrewCannotRunItself() async {
        let plan = await makeService().setupPlan(locations: Locations())

        #expect(plan.steps.map(\.kind).first == .commandLineTools)
        #expect(plan.steps.contains { $0.kind == .sdkPackages })
        #expect(plan.homebrewInstalled == false)
        #expect(plan.canRunAutomatically == false)
        #expect(plan.shellScript.contains("brew install --cask android-commandlinetools"))
        #expect(plan.sdkPath == home.appendingPathComponent("homebrew/share/android-commandlinetools").path)
    }

    @Test func setupPlanIsEmptyForAConfiguredMac() async throws {
        try installSDK(at: "Library/Android/sdk")
        try write(".sdkman/candidates/java/current/bin/java")

        let plan = await makeService().setupPlan(locations: Locations())

        #expect(plan.isEmpty)
    }

    @Test func runSetupStepExecutesTheRealCommandAndReturnsItsOutput() async throws {
        // A fake `brew` under the hermetic prefix records that it ran and succeeds.
        let brew = home.appendingPathComponent("homebrew/bin/brew")
        try write("homebrew/bin/brew", "#!/bin/sh\necho \"brew $@\"\n")
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: brew.path)
        let service = makeService()
        let plan = await service.setupPlan(locations: Locations())
        #expect(plan.homebrewInstalled)
        let step = try #require(plan.steps.first { $0.kind == .commandLineTools })

        let result = try await service.runSetupStep(step, locations: Locations())

        #expect(result.isSuccess)
        #expect(result.output.contains("brew install --cask android-commandlinetools"))
    }

    @Test func runSetupStepReportsACommandThatCannotStart() async throws {
        // Homebrew "exists" but is not executable: the step must fail cleanly, not crash.
        try write("homebrew/bin/brew", "")
        let service = makeService()
        let plan = await service.setupPlan(locations: Locations())
        let step = try #require(plan.steps.first { $0.kind == .commandLineTools })

        await #expect(throws: ServiceError.self) {
            try await service.runSetupStep(step, locations: Locations())
        }
    }

    // MARK: Catalogs, create and delete

    private func installImage(_ platform: String, _ tag: String, _ abi: String) throws {
        try write("Library/Android/sdk/system-images/\(platform)/\(tag)/\(abi)/system.img")
        try write(
            "Library/Android/sdk/system-images/\(platform)/\(tag)/\(abi)/source.properties",
            "AndroidVersion.ApiLevel=\(platform.replacingOccurrences(of: "android-", with: ""))\nSystemImage.TagId=\(tag)\nSystemImage.Abi=\(abi)\n"
        )
    }

    /// Mimics the files `avdmanager create avd` / `delete avd` write, and answers `list device`.
    private func installFakeAvdManager() throws {
        let script = """
            #!/bin/sh
            case "$1 $2" in
              "list device") printf 'id: 54 or "pixel_9"\\n    Name: Pixel 9\\n    OEM : Google\\n---------\\n';;
              "create avd")
                name=""; while [ $# -gt 0 ]; do case "$1" in --name) name="$2"; shift;; esac; shift; done
                mkdir -p "$ANDROID_AVD_HOME/$name.avd"
                printf 'path=%s\\ntarget=android-36\\n' "$ANDROID_AVD_HOME/$name.avd" > "$ANDROID_AVD_HOME/$name.ini"
                printf 'PlayStore.enabled=no\\nhw.device.name=pixel_9\\nimage.sysdir.1=system-images/android-36/google_apis_playstore/arm64-v8a/\\n' > "$ANDROID_AVD_HOME/$name.avd/config.ini";;
              "delete avd")
                name=""; while [ $# -gt 0 ]; do case "$1" in --name) name="$2"; shift;; esac; shift; done
                rm -rf "$ANDROID_AVD_HOME/$name.avd" "$ANDROID_AVD_HOME/$name.ini";;
            esac
            """
        let path = home.appendingPathComponent("Library/Android/sdk/cmdline-tools/latest/bin/avdmanager")
        try write("Library/Android/sdk/cmdline-tools/latest/bin/avdmanager", script)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path.path)
    }

    @Test func listsInstalledSystemImagesWithTheirFamily() async throws {
        try installSDK(at: "Library/Android/sdk")
        try installImage("android-36", "google_apis_playstore", "arm64-v8a")
        try installImage("android-36", "android-tv", "arm64-v8a")

        let images = await makeService().installedSystemImages(locations: Locations())

        #expect(
            images.map(\.packagePath) == [
                "system-images;android-36;google_apis_playstore;arm64-v8a",
                "system-images;android-36;android-tv;arm64-v8a",
            ])
        #expect(images[0].hasPlayStore && images[0].family == .general && images[0].apiLevel == "36")
        #expect(images[1].family == .tv)
    }

    @Test func deviceProfilesNeedJavaAndReportItClearly() async throws {
        try installSDK(at: "Library/Android/sdk")
        try installFakeAvdManager()

        await #expect(throws: ServiceError.self) { try await makeService().deviceProfiles(locations: Locations()) }
        do {
            _ = try await makeService().deviceProfiles(locations: Locations())
        } catch {
            #expect(error.localizedDescription.contains("Java"))
        }
    }

    @Test func createsAndDeletesADeviceThroughTheRealCore() async throws {
        try installSDK(at: "Library/Android/sdk")
        try installFakeAvdManager()
        try installImage("android-36", "google_apis_playstore", "arm64-v8a")
        try write(".sdkman/candidates/java/current/bin/java")
        let service = makeService()
        let profiles = try await service.deviceProfiles(locations: Locations())
        let image = try #require(await service.installedSystemImages(locations: Locations()).first)
        let profile = try #require(profiles.first)
        #expect(profile.id == "pixel_9" && profile.kind == .phone)

        try await service.createDevice(
            CreateDeviceRequest(name: "Pixel_9_API_36", displayName: "Mine", systemImage: image, device: profile, ramMegabytes: 4096),
            locations: Locations()
        )

        let created = try #require(await service.snapshot(locations: Locations()).devices.first { $0.id == "Pixel_9_API_36" })
        #expect(created.displayName == "Mine")
        #expect(created.hasPlayStore)
        #expect(created.ramMegabytes == 4096)
        #expect(await service.validateDeviceName("Pixel_9_API_36", locations: Locations()) != nil)
        #expect(await service.validateDeviceName("Other", locations: Locations()) == nil)

        try await service.deleteDevice(created, locations: Locations())
        #expect(await service.snapshot(locations: Locations()).devices.isEmpty)
    }

    // MARK: System images: list, download and remove

    private var sdkManagerLog: URL { home.appendingPathComponent("sdkmanager.log") }

    /// Answers `--list` with a short canned listing (new column format) and records every other call.
    private func installFakeSdkManager() throws {
        let script = """
            #!/bin/sh
            case "$*" in
              *--list*)
                cat <<'LIST'
            Installed packages:
              emulator    37.2.13    Android Emulator
              system-images/android-36/google_apis_playstore/arm64-v8a    7.0.0    Google Play ARM 64 v8a System Image
            Available packages:
              emulator    37.2.13    Android Emulator
              system-images/android-36/google_apis_playstore/arm64-v8a    7.0.0    Google Play ARM 64 v8a System Image
              system-images/android-37.0/google_apis_playstore/arm64-v8a    8.0.0    Google Play ARM 64 v8a System Image
              system-images/android-37.0/google_apis_playstore/x86_64    8.0.0    Google Play Intel x86_64 Atom System Image
              system-images/android-36/android-wear/arm64-v8a    3.0.0    Wear OS 3 ARM 64 v8a System Image
            LIST
                ;;
              *) echo "$@" >> "\(sdkManagerLog.path)";;
            esac
            """
        let relative = "Library/Android/sdk/cmdline-tools/latest/bin/sdkmanager"
        try write(relative, script)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: home.appendingPathComponent(relative).path)
    }

    private func sdkManagerCalls() -> [String] {
        ((try? String(contentsOf: sdkManagerLog, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    @Test func listsWhatGoogleOffersForAppleSiliconAndMarksTheInstalled() async throws {
        try installSDK(at: "Library/Android/sdk")
        try installFakeSdkManager()
        try write(".sdkman/candidates/java/current/bin/java")

        let images = try await makeService().availableSystemImages(locations: Locations())

        #expect(
            images.map(\.packagePath) == [
                "system-images;android-37.0;google_apis_playstore;arm64-v8a",
                "system-images;android-36;google_apis_playstore;arm64-v8a",
                "system-images;android-36;android-wear;arm64-v8a",
            ], "arm64 only, newest Android first, x86_64 left out")
        #expect(images[0].versionLabel.hasPrefix("Android 17"))
        #expect(images[0].hasPlayStore && !images[0].isInstalled)
        #expect(images[1].isInstalled)
        #expect(images[2].family == .wearOS)
        #expect(images.allSatisfy { $0.isNativeOnAppleSilicon })
    }

    @Test func listingNeedsJavaAndSaysSo() async throws {
        try installSDK(at: "Library/Android/sdk")
        try installFakeSdkManager()

        do {
            _ = try await makeService().availableSystemImages(locations: Locations())
            Issue.record("expected an error without Java")
        } catch {
            #expect(error.localizedDescription.contains("Java"))
        }
    }

    @Test func nothingIsDownloadedUnlessTheUserAcceptedTheLicense() async throws {
        try installSDK(at: "Library/Android/sdk")
        try installFakeSdkManager()
        try write(".sdkman/candidates/java/current/bin/java")
        let package = "system-images;android-37.0;google_apis_playstore;arm64-v8a"

        await #expect(throws: ServiceError.self) {
            try await makeService().installSystemImages([package], licenseAccepted: false, locations: Locations())
        }

        #expect(sdkManagerCalls().isEmpty, "sdkmanager was never started")
    }

    @Test func downloadsAfterAcceptingTheLicensesInThatOrder() async throws {
        try installSDK(at: "Library/Android/sdk")
        try installFakeSdkManager()
        try write(".sdkman/candidates/java/current/bin/java")
        let package = "system-images;android-37.0;google_apis_playstore;arm64-v8a"

        let result = try await makeService().installSystemImages([package], licenseAccepted: true, locations: Locations())

        #expect(result.isSuccess)
        let calls = sdkManagerCalls()
        #expect(calls.count == 2)
        #expect(calls.first?.contains("--licenses") == true, "licenses first")
        #expect(calls.last?.contains(package) == true, "then the package")
    }

    @Test func refusesToDownloadAnythingThatIsNotASystemImage() async throws {
        try installSDK(at: "Library/Android/sdk")
        try installFakeSdkManager()
        try write(".sdkman/candidates/java/current/bin/java")

        await #expect(throws: ServiceError.self) {
            try await makeService().installSystemImages(["platform-tools"], licenseAccepted: true, locations: Locations())
        }

        #expect(sdkManagerCalls().isEmpty)
    }

    @Test func removingAnImageADeviceUsesNeedsForce() async throws {
        try installSDK(at: "Library/Android/sdk")
        try installFakeSdkManager()
        try write(".sdkman/candidates/java/current/bin/java")
        try installImage("android-36", "google_apis_playstore", "arm64-v8a")
        try createAVD(
            "Pixel_9",
            target: "android-36",
            config: "hw.device.name=pixel_9\nimage.sysdir.1=system-images/android-36/google_apis_playstore/arm64-v8a/\n")
        let service = makeService()
        let image = try #require(await service.installedSystemImages(locations: Locations()).first)

        await #expect(throws: ServiceError.self) { try await service.removeSystemImage(image, force: false, locations: Locations()) }
        #expect(sdkManagerCalls().isEmpty, "nothing was removed")

        let result = try await service.removeSystemImage(image, force: true, locations: Locations())

        #expect(result.isSuccess)
        let calls = sdkManagerCalls()
        #expect(calls.count == 1)
        #expect(calls[0].contains("--uninstall") && calls[0].contains(image.packagePath))
    }

    @Test func installedImagesCarryTheirSizeOnDisk() async throws {
        try installSDK(at: "Library/Android/sdk")
        try installImage("android-36", "google_apis_playstore", "arm64-v8a")
        try write(
            "Library/Android/sdk/system-images/android-36/google_apis_playstore/arm64-v8a/userdata.img",
            String(repeating: "x", count: 4096))

        let image = try #require(await makeService().installedSystemImages(locations: Locations()).first)

        #expect((image.sizeBytes ?? 0) >= 4096)
    }

    @Test func devicesKnowWhichImageTheyBootFrom() async throws {
        try installSDK(at: "Library/Android/sdk")
        try createAVD(
            "Television_4K",
            target: "android-34",
            config: "hw.device.name=tv_4k\ntag.id=android-tv\nimage.sysdir.1=system-images/android-34/android-tv/arm64-v8a/\n")

        let snapshot = await makeService().snapshot(locations: Locations())

        let tv = try #require(snapshot.devices.first)
        let package = try #require(tv.systemImagePackage)
        #expect(samePackage(package, "system-images;android-34;android-tv;arm64-v8a"))
    }

    @Test func countsWhatSdkmanagerHasDownloadedSinceTheInstallStarted() async throws {
        try installSDK(at: "Library/Android/sdk")
        try write("Library/Android/sdk/.sdk/arch/old-archive", String(repeating: "x", count: 5_000))
        // File times come from the real clock; leave a margin on both sides of "now".
        try await Task.sleep(for: .milliseconds(1_200))
        let started = Date()
        let service = makeService()
        #expect(await service.downloadedBytes(since: started, locations: Locations()) == 0, "an archive from before does not count")

        try write("Library/Android/sdk/.sdk/arch/new-archive.part", String(repeating: "x", count: 3_000))
        let during = await service.downloadedBytes(since: started, locations: Locations())

        #expect(during == 3_000)
    }

    @Test func deletesADeviceEvenWithoutJavaAndEvenWhenItsImageIsMissing() async throws {
        try installSDK(at: "Library/Android/sdk")  // no Java anywhere: avdmanager cannot run
        // A name nobody else uses: the core asks the real `ps` which emulators run, and a real one with the same name
        // (a developer's own device) would make it refuse.
        let name = "Broken_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"
        try createAVD(
            name, target: "android-33",
            config: "hw.device.name=pixel_2\nimage.sysdir.1=system-images/android-33/google_apis_playstore/arm64-v8a/\n")
        try write(".android/avd/\(name).avd/userdata.img", "x")
        let service = makeService()
        let broken = try #require(await service.snapshot(locations: Locations()).devices.first)
        #expect(broken.id == name)
        #expect(broken.status == .missingSystemImage)

        try await service.deleteDevice(broken, locations: Locations())

        #expect(await service.snapshot(locations: Locations()).devices.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: home.appendingPathComponent(".android/avd/\(name).avd").path))
    }

    @Test func neverDeletesAFolderThatIsNotAnAvdEvenIfTheIniSaysSo() async throws {
        try installSDK(at: "Library/Android/sdk")
        try write("Documents/thesis.txt", "precious")
        let name = "Stray_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"
        try write(".android/avd/\(name).ini", "path=\(home.path)/Documents\ntarget=android-33\n")
        try write(".android/avd/\(name).avd/config.ini", "hw.device.name=pixel_2\n")
        let service = makeService()
        let stray = VirtualDevice(id: name)

        await #expect(throws: ServiceError.self) { try await service.deleteDevice(stray, locations: Locations()) }

        #expect(FileManager.default.fileExists(atPath: home.appendingPathComponent("Documents/thesis.txt").path))
    }
}
