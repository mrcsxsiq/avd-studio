import Foundation

/// Realistic in-memory data for SwiftUI previews and screenshot tests.
public enum SampleData {
    public static let devices: [VirtualDevice] = [
        VirtualDevice(
            id: "Pixel_9_API_36", displayName: "Pixel 9", kind: .phone, apiLevel: "36", androidVersion: "16",
            deviceProfile: "pixel_9", abi: "arm64-v8a", hasPlayStore: true, ramMegabytes: 4096, storage: "16G",
            diskUsageBytes: 9_600_000_000
        ),
        VirtualDevice(
            id: "Pixel_9_Pro_Fold", displayName: "Pixel 9 Pro Fold", kind: .foldable, apiLevel: "35", androidVersion: "15",
            deviceProfile: "pixel_9_pro_fold", abi: "arm64-v8a", hasPlayStore: true, ramMegabytes: 4096, storage: "16G",
            diskUsageBytes: 7_200_000_000
        ),
        VirtualDevice(
            id: "Pixel_Tablet_API_34", displayName: "Pixel Tablet", kind: .tablet, apiLevel: "34", androidVersion: "14",
            deviceProfile: "pixel_tablet", abi: "arm64-v8a", ramMegabytes: 8192, storage: "32G", diskUsageBytes: 6_700_000_000
        ),
        VirtualDevice(
            id: "Wear_Large_Round", displayName: "Wear OS Large Round", kind: .wearOS, apiLevel: "34", androidVersion: "14",
            deviceProfile: "wearos_large_round", abi: "arm64-v8a", ramMegabytes: 2048, diskUsageBytes: 3_100_000_000
        ),
        VirtualDevice(
            id: "Television_4K", displayName: "Television 4K", kind: .tv, apiLevel: "34", androidVersion: "14",
            deviceProfile: "tv_4k", abi: "arm64-v8a", ramMegabytes: 2048, diskUsageBytes: 7_000_000_000
        ),
        VirtualDevice(
            id: "Automotive_1080p", displayName: "Automotive 1080p", kind: .automotive, apiLevel: "34", androidVersion: "14",
            deviceProfile: "automotive_1080p_landscape", abi: "arm64-v8a", hasPlayStore: true, diskUsageBytes: 5_400_000_000
        ),
        VirtualDevice(
            id: "Desktop_Medium", displayName: "Desktop Medium", kind: .desktop, apiLevel: "36", androidVersion: "16",
            deviceProfile: "desktop_medium", abi: "arm64-v8a", ramMegabytes: 8192, diskUsageBytes: 8_800_000_000
        ),
        VirtualDevice(
            id: "XR_Headset", displayName: "XR Headset", kind: .xr, apiLevel: "36", androidVersion: "16",
            deviceProfile: "xr_headset_device", abi: "arm64-v8a", ramMegabytes: 8192, diskUsageBytes: 9_900_000_000
        ),
        VirtualDevice(
            id: "Retroid_Pocket_5", displayName: "Retroid Pocket 5", kind: .phone, apiLevel: "33", androidVersion: "13",
            deviceProfile: "pixel_2", abi: "arm64-v8a", hasPlayStore: true, ramMegabytes: 2048, diskUsageBytes: 7_000_000_000,
            status: .missingSystemImage
        ),
    ]

    public static let readyToolchain = ToolchainSummary(
        sdkPath: "/Users/you/Library/Android/sdk",
        sourceDescription: "Android Studio default",
        directoryExists: true,
        isConfigured: true,
        summary: "Android SDK ready.",
        tools: [
            .init(name: "sdkmanager", path: "/Users/you/Library/Android/sdk/cmdline-tools/latest/bin/sdkmanager", state: .available),
            .init(name: "avdmanager", path: "/Users/you/Library/Android/sdk/cmdline-tools/latest/bin/avdmanager", state: .available),
            .init(name: "emulator", path: "/Users/you/Library/Android/sdk/emulator/emulator", state: .available),
            .init(name: "adb", path: "/Users/you/Library/Android/sdk/platform-tools/adb", state: .available),
        ]
    )

    public static let missingToolchain = ToolchainSummary(
        sdkPath: "/Users/you/Library/Android/sdk",
        sourceDescription: "default location",
        directoryExists: false,
        isConfigured: false,
        summary: "No Android SDK found at /Users/you/Library/Android/sdk.",
        tools: [
            .init(name: "sdkmanager", path: "/Users/you/Library/Android/sdk/cmdline-tools/latest/bin/sdkmanager", state: .missing),
            .init(name: "avdmanager", path: "/Users/you/Library/Android/sdk/cmdline-tools/latest/bin/avdmanager", state: .missing),
            .init(name: "emulator", path: "/Users/you/Library/Android/sdk/emulator/emulator", state: .missing),
            .init(name: "adb", path: "/Users/you/Library/Android/sdk/platform-tools/adb", state: .missing),
        ]
    )

    /// A newer version than the one the tests and previews pretend to run (0.1.0).
    public static let release = AppRelease(
        version: AppVersion(major: 0, minor: 2, patch: 0),
        title: "AVD Studio 0.2.0",
        notes: """
            **Highlights**
            - Create virtual devices from the app
            - Install system images without opening Android Studio
            - Faster start-up when you have many devices

            Fixes: the menu bar item now updates right after an emulator exits.
            """,
        pageURL: URL(string: "https://github.com/mrcsxsiq/avd-studio/releases/tag/v0.2.0")!,
        publishedAt: Date(timeIntervalSince1970: 1_793_000_000),
        asset: AppRelease.Asset(
            name: "AVD-Studio-0.2.0.dmg",
            url: URL(string: "https://github.com/mrcsxsiq/avd-studio/releases/download/v0.2.0/AVD-Studio-0.2.0.dmg")!,
            size: 48_200_000,
            checksumURL: URL(string: "https://github.com/mrcsxsiq/avd-studio/releases/download/v0.2.0/AVD-Studio-0.2.0.dmg.sha256")!
        )
    )

    /// An `UpdateModel` frozen in `state`, for previews and screenshot tests. It never touches the network.
    @MainActor
    public static func updateModel(state: UpdateState, installSource: InstallSource = .manual) -> UpdateModel {
        UpdateModel(
            currentVersion: AppVersion(major: 0, minor: 1, patch: 0),
            source: PreviewReleaseSource(),
            installSource: installSource,
            state: state,
            defaults: UserDefaults(suiteName: "avdstudio.sample.updates.\(UUID())")!
        )
    }

    public static let diagnostics: [DoctorItem] = [
        .init(id: "sdk", title: "Android SDK", status: .pass, detail: "/Users/you/Library/Android/sdk (Android Studio default)"),
        .init(id: "emulator", title: "emulator", status: .pass, detail: "/Users/you/Library/Android/sdk/emulator/emulator"),
        .init(
            id: "java", title: "Java runtime", status: .warning, detail: "No JDK found. sdkmanager and avdmanager need one.",
            hint: "Install one with `brew install --cask temurin`."),
        .init(id: "avd-home", title: "Virtual device folder", status: .pass, detail: "/Users/you/.android/avd — 9 device(s)"),
    ]

    /// A model that is already loaded, with no background work. Handy for `#Preview` and snapshot tests.
    @MainActor
    public static func model(
        devices: [VirtualDevice] = SampleData.devices,
        running: [String] = [],
        toolchain: ToolchainSummary = SampleData.readyToolchain
    ) -> AppModel {
        let model = AppModel(service: PreviewDeviceService(), defaults: UserDefaults(suiteName: "avdstudio.sample.\(UUID())")!)
        model.load(
            DeviceSnapshot(
                devices: devices,
                running: running.map { RunningDevice(name: $0, processID: 100) },
                toolchain: toolchain,
                avdHome: "/Users/you/.android/avd"
            ))
        return model
    }
}

/// Does nothing and never fails; backs previews.
public struct PreviewDeviceService: DeviceService {
    public init() {}

    public func snapshot(locations: Locations) async -> DeviceSnapshot {
        DeviceSnapshot(devices: SampleData.devices, running: [], toolchain: SampleData.readyToolchain, avdHome: "/Users/you/.android/avd")
    }

    public func runningDevices() async -> [RunningDevice] { [] }
    public func diagnose(locations: Locations) async -> [DoctorItem] { SampleData.diagnostics }
    public func launch(_ device: VirtualDevice, options: LaunchOptions, locations: Locations) async throws {}
    public func stop(_ device: VirtualDevice) async throws {}
}

/// Always reports "nothing published"; backs previews.
public struct PreviewReleaseSource: ReleaseSource {
    public init() {}
    public func latestRelease() async throws -> AppRelease? { nil }
}
