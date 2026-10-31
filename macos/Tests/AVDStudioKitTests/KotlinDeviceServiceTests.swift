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
                homeDirectory: home.path
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
}
