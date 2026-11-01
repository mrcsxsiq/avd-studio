import Foundation

/// Realistic in-memory data for SwiftUI previews and screenshot tests.
public enum SampleData {
    public static let devices: [VirtualDevice] = [
        VirtualDevice(
            id: "Pixel_9_API_36", displayName: "Pixel 9", kind: .phone, apiLevel: "36", androidVersion: "16",
            deviceProfile: "pixel_9", abi: "arm64-v8a", hasPlayStore: true, ramMegabytes: 4096, storage: "16G",
            diskUsageBytes: 9_600_000_000, systemImagePackage: "system-images;android-36;google_apis_playstore;arm64-v8a"
        ),
        VirtualDevice(
            id: "Pixel_9_Pro_Fold", displayName: "Pixel 9 Pro Fold", kind: .foldable, apiLevel: "35", androidVersion: "15",
            deviceProfile: "pixel_9_pro_fold", abi: "arm64-v8a", hasPlayStore: true, ramMegabytes: 4096, storage: "16G",
            diskUsageBytes: 7_200_000_000
        ),
        VirtualDevice(
            id: "Pixel_Tablet_API_34", displayName: "Pixel Tablet", kind: .tablet, apiLevel: "34", androidVersion: "14",
            deviceProfile: "pixel_tablet", abi: "arm64-v8a", ramMegabytes: 8192, storage: "32G", diskUsageBytes: 6_700_000_000,
            systemImagePackage: "system-images;android-34;google_apis_playstore;arm64-v8a"
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

    /// The plan for a Mac that has Homebrew but nothing Android-related.
    public static let setupPlan = SetupPlan(
        steps: [
            SetupStep(
                kind: .commandLineTools, title: "Install the Android command-line tools",
                displayCommand: "brew install --cask android-commandlinetools", requiresHomebrew: true, requiresLicenseAcceptance: false),
            SetupStep(
                kind: .java, title: "Install Java (OpenJDK 17)", displayCommand: "brew install openjdk@17", requiresHomebrew: true,
                requiresLicenseAcceptance: false),
            SetupStep(
                kind: .licenses, title: "Accept the Android SDK licenses", displayCommand: "yes | sdkmanager --licenses",
                requiresHomebrew: false, requiresLicenseAcceptance: true),
            SetupStep(
                kind: .sdkPackages, title: "Install the emulator and platform tools",
                displayCommand: "sdkmanager \"emulator\" \"platform-tools\"", requiresHomebrew: false, requiresLicenseAcceptance: false),
        ],
        homebrewInstalled: true,
        sdkPath: "/opt/homebrew/share/android-commandlinetools",
        shellScript: "#!/bin/bash\nset -euo pipefail\nbrew install --cask android-commandlinetools\nbrew install openjdk@17\n"
    )

    public static let setupPlanWithoutHomebrew = SetupPlan(
        steps: setupPlan.steps,
        homebrewInstalled: false,
        sdkPath: setupPlan.sdkPath,
        shellScript:
            "#!/bin/bash\nset -euo pipefail\n/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"\nbrew install --cask android-commandlinetools\n"
    )

    public static let systemImages: [SystemImage] = [
        SystemImage(
            packagePath: "system-images;android-36;google_apis_playstore;arm64-v8a", apiLevel: "36", androidVersion: "16",
            versionLabel: "Android 16 (API 36)", tagDisplay: "Google Play", abi: "arm64-v8a", hasPlayStore: true,
            isNativeOnAppleSilicon: true, family: .general, sizeBytes: 1_900_000_000),
        SystemImage(
            packagePath: "system-images;android-36;google_apis;arm64-v8a", apiLevel: "36", androidVersion: "16",
            versionLabel: "Android 16 (API 36)", tagDisplay: "Google APIs", abi: "arm64-v8a", hasPlayStore: false,
            isNativeOnAppleSilicon: true, family: .general, sizeBytes: 1_800_000_000),
        SystemImage(
            packagePath: "system-images;android-36;android-tv;arm64-v8a", apiLevel: "36", androidVersion: "16",
            versionLabel: "Android 16 (API 36)", tagDisplay: "Android TV", abi: "arm64-v8a", hasPlayStore: false,
            isNativeOnAppleSilicon: true, family: .tv, sizeBytes: 1_400_000_000),
        SystemImage(
            packagePath: "system-images;android-34;google_apis_playstore;arm64-v8a", apiLevel: "34", androidVersion: "14",
            versionLabel: "Android 14 (API 34)", tagDisplay: "Google Play", abi: "arm64-v8a", hasPlayStore: true,
            isNativeOnAppleSilicon: true, family: .general, sizeBytes: 1_600_000_000),
        SystemImage(
            packagePath: "system-images;android-34;google_apis;x86_64", apiLevel: "34", androidVersion: "14",
            versionLabel: "Android 14 (API 34)", tagDisplay: "Google APIs", abi: "x86_64", hasPlayStore: false,
            isNativeOnAppleSilicon: false, family: .general, sizeBytes: 1_500_000_000),
    ]

    /// What `sdkmanager --list` offers for Apple Silicon, newest first (one of them already installed).
    public static let availableImages: [RemoteSystemImage] = [
        RemoteSystemImage(
            packagePath: "system-images;android-37.0;google_apis_playstore;arm64-v8a", apiLevel: "37", androidVersion: "17",
            versionLabel: "Android 17 (API 37)", tagDisplay: "Google Play", revision: "8.0.0", hasPlayStore: true),
        RemoteSystemImage(
            packagePath: "system-images;android-37.0;google_apis_playstore_ps16k;arm64-v8a", apiLevel: "37", androidVersion: "17",
            versionLabel: "Android 17 (API 37)", tagDisplay: "Google Play (16 KB pages)", revision: "8.0.0", hasPlayStore: true,
            usesSixteenKbPages: true),
        RemoteSystemImage(
            packagePath: "system-images;android-37.0;google_apis;arm64-v8a", apiLevel: "37", androidVersion: "17",
            versionLabel: "Android 17 (API 37)", tagDisplay: "Google APIs", revision: "8.0.0"),
        RemoteSystemImage(
            packagePath: "system-images;android-36;google_apis_playstore;arm64-v8a", apiLevel: "36", androidVersion: "16",
            versionLabel: "Android 16 (API 36)", tagDisplay: "Google Play", revision: "7.0.0", hasPlayStore: true, isInstalled: true),
        RemoteSystemImage(
            packagePath: "system-images;android-36;android-wear;arm64-v8a", apiLevel: "36", androidVersion: "16",
            versionLabel: "Android 16 (API 36)", tagDisplay: "Wear OS", revision: "3.0.0", family: .wearOS),
        RemoteSystemImage(
            packagePath: "system-images;android-35;google_apis_playstore;arm64-v8a", apiLevel: "35", androidVersion: "15",
            versionLabel: "Android 15 (API 35)", tagDisplay: "Google Play", revision: "9.0.0", hasPlayStore: true),
        RemoteSystemImage(
            packagePath: "system-images;android-35;google_apis;arm64-v8a", apiLevel: "35", androidVersion: "15",
            versionLabel: "Android 15 (API 35)", tagDisplay: "Google APIs", revision: "9.0.0"),
        RemoteSystemImage(
            packagePath: "system-images;android-35;default;arm64-v8a", apiLevel: "35", androidVersion: "15",
            versionLabel: "Android 15 (API 35)", tagDisplay: "Default Android", revision: "5.0.0"),
        RemoteSystemImage(
            packagePath: "system-images;android-canary-20261007;google_apis_playstore_ps16k;arm64-v8a", apiLevel: nil,
            versionLabel: "Android canary-20261007 (preview)", tagDisplay: "Google Play (16 KB pages)", revision: "17.0.0",
            hasPlayStore: true, isPreview: true, usesSixteenKbPages: true),
        RemoteSystemImage(
            packagePath: "system-images;android-30;aosp_atd;arm64-v8a", apiLevel: "30", androidVersion: "11",
            versionLabel: "Android 11 (API 30)", tagDisplay: "Automated test device", revision: "2.0.0", isAutomatedTestImage: true),
    ]

    public static let deviceProfiles: [DeviceProfile] = [
        DeviceProfile(id: "pixel_9", name: "Pixel 9", manufacturer: "Google", kind: .phone),
        DeviceProfile(id: "pixel_9_pro", name: "Pixel 9 Pro", manufacturer: "Google", kind: .phone),
        DeviceProfile(id: "medium_phone", name: "Medium Phone", manufacturer: "Generic", kind: .phone),
        DeviceProfile(id: "pixel_9_pro_fold", name: "Pixel 9 Pro Fold", manufacturer: "Google", kind: .foldable),
        DeviceProfile(id: "pixel_tablet", name: "Pixel Tablet", manufacturer: "Google", kind: .tablet),
        DeviceProfile(id: "wearos_large_round", name: "Wear OS Large Round", manufacturer: "Google", kind: .wearOS),
        DeviceProfile(id: "tv_1080p", name: "Television (1080p)", manufacturer: "Google", kind: .tv),
        DeviceProfile(id: "tv_4k", name: "Television (4K)", manufacturer: "Google", kind: .tv),
        DeviceProfile(id: "automotive_1080p_landscape", name: "Automotive (1080p landscape)", manufacturer: "Google", kind: .automotive),
        DeviceProfile(id: "desktop_medium", name: "Medium Desktop", manufacturer: "Google", kind: .desktop),
        DeviceProfile(id: "xr_headset_device", name: "XR Headset", manufacturer: "Google", kind: .xr),
    ]

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
    public func setupPlan(locations: Locations) async -> SetupPlan { SampleData.setupPlan }
    public func runSetupStep(_ step: SetupStep, locations: Locations) async throws -> SetupStepResult {
        SetupStepResult(exitCode: 0, output: "")
    }
    public func installedSystemImages(locations: Locations) async -> [SystemImage] { SampleData.systemImages }
    public func availableSystemImages(locations: Locations) async throws -> [RemoteSystemImage] { SampleData.availableImages }
    public func installSystemImages(_ packages: [String], licenseAccepted: Bool, locations: Locations) async throws -> SetupStepResult {
        SetupStepResult(exitCode: 0, output: "")
    }
    public func removeSystemImage(_ image: SystemImage, force: Bool, locations: Locations) async throws -> SetupStepResult {
        SetupStepResult(exitCode: 0, output: "")
    }
    public func deviceProfiles(locations: Locations) async throws -> [DeviceProfile] { SampleData.deviceProfiles }
    public func validateDeviceName(_ name: String, locations: Locations) async -> String? { nil }
    public func createDevice(_ request: CreateDeviceRequest, locations: Locations) async throws {}
    public func deleteDevice(_ device: VirtualDevice, locations: Locations) async throws {}
}

/// Always reports "nothing published"; backs previews.
public struct PreviewReleaseSource: ReleaseSource {
    public init() {}
    public func latestRelease() async throws -> AppRelease? { nil }
}
