import AVDStudioCore
import AVDStudioUI
import Foundation

/// Adapts the Kotlin core to the UI's `DeviceService`. This is the only file that touches Kotlin types
/// directly; everything is converted to plain Swift values before it leaves.
///
/// Kotlin objects are not `Sendable`, so each call hops to a detached task and only returns value types.
public final class KotlinDeviceService: DeviceService, @unchecked Sendable {
    private let core: AvdStudioCore

    public init() {
        self.core = AvdStudioCore(runner: NativeCommandRunner(), environment: SystemEnvironment())
    }

    /// For tests: lets them point the core at a temporary home folder and environment.
    public init(environment: any AVDStudioCore.Environment) {
        self.core = AvdStudioCore(runner: NativeCommandRunner(), environment: environment)
    }

    public func snapshot(locations: Locations) async -> DeviceSnapshot {
        await Task.detached { [self] in
            let toolchain = core.toolchainStatus(sdkPathOverride: locations.sdkPath)
            let avds = core.listAvds(sdkPathOverride: locations.sdkPath, avdHomeOverride: locations.avdHome)
            return DeviceSnapshot(
                devices: avds.map(Self.device(from:)),
                running: core.runningEmulators().map { RunningDevice(name: $0.avdName, processID: $0.processId) },
                toolchain: Self.summary(from: toolchain),
                avdHome: core.avdHome(avdHomeOverride: locations.avdHome)
            )
        }.value
    }

    public func runningDevices() async -> [RunningDevice] {
        await Task.detached { [self] in
            core.runningEmulators().map { RunningDevice(name: $0.avdName, processID: $0.processId) }
        }.value
    }

    public func diagnose(locations: Locations) async -> [DoctorItem] {
        await Task.detached { [self] in
            core.doctor(sdkPathOverride: locations.sdkPath, avdHomeOverride: locations.avdHome).checks.map {
                DoctorItem(id: $0.id, title: $0.title, status: Self.status(from: $0.status), detail: $0.detail, hint: $0.hint)
            }
        }.value
    }

    public func launch(_ device: VirtualDevice, options: LaunchOptions, locations: Locations) async throws {
        try await Task.detached { [self] in
            let kotlinOptions = EmulatorLaunchOptions(coldBoot: options.coldBoot, wipeData: options.wipeData, extraArguments: [])
            do {
                _ = try core.launchAvd(
                    avdName: device.id,
                    options: kotlinOptions,
                    sdkPathOverride: locations.sdkPath,
                    avdHomeOverride: locations.avdHome
                )
            } catch {
                throw ServiceError(Self.message(for: error))
            }
        }.value
    }

    public func stop(_ device: VirtualDevice) async throws {
        try await Task.detached { [self] in
            do {
                _ = try core.stopAvd(avdName: device.id)
            } catch {
                throw ServiceError(Self.message(for: error))
            }
        }.value
    }

    public func setupPlan(locations: Locations) async -> AVDStudioUI.SetupPlan {
        await Task.detached { [self] in
            Self.plan(from: core.setupPlan(sdkPathOverride: locations.sdkPath, avdHomeOverride: locations.avdHome))
        }.value
    }

    public func runSetupStep(_ step: AVDStudioUI.SetupStep, locations: Locations) async throws -> SetupStepResult {
        try await Task.detached { [self] in
            // Steps are matched by kind: the Kotlin plan is the source of truth for the commands.
            let plan = core.setupPlan(sdkPathOverride: locations.sdkPath, avdHomeOverride: locations.avdHome)
            guard let kotlinStep = plan.steps.first(where: { Self.kind(from: $0.kind) == step.kind }) else {
                return SetupStepResult(exitCode: 0, output: "Nothing left to do for this step.")
            }
            do {
                let result = try core.runSetupStep(step: kotlinStep, sdkPathOverride: locations.sdkPath, avdHomeOverride: locations.avdHome)
                return Self.stepResult(from: result)
            } catch {
                throw ServiceError(Self.message(for: error))
            }
        }.value
    }

    public func availableSystemImages(locations: Locations) async throws -> [RemoteSystemImage] {
        try await Task.detached { [self] in
            do {
                let images = try core.availableSystemImages(sdkPathOverride: locations.sdkPath, includeNonNative: false)
                return images.map(Self.remoteImage(from:))
            } catch {
                throw ServiceError(Self.message(for: error))
            }
        }.value
    }

    public func installSystemImages(_ packages: [String], licenseAccepted: Bool, locations: Locations) async throws -> SetupStepResult {
        try await Task.detached { [self] in
            do {
                let result = try core.installSystemImages(
                    packages: packages, licensesAccepted: licenseAccepted, sdkPathOverride: locations.sdkPath)
                return Self.stepResult(from: result)
            } catch {
                throw ServiceError(Self.message(for: error))
            }
        }.value
    }

    public func removeSystemImage(_ image: AVDStudioUI.SystemImage, force: Bool, locations: Locations) async throws -> SetupStepResult {
        try await Task.detached { [self] in
            do {
                let result = try core.removeSystemImage(
                    packagePath: image.packagePath, sdkPathOverride: locations.sdkPath, avdHomeOverride: locations.avdHome, force: force)
                return Self.stepResult(from: result)
            } catch {
                throw ServiceError(Self.message(for: error))
            }
        }.value
    }

    public func installedSystemImages(locations: Locations) async -> [AVDStudioUI.SystemImage] {
        await Task.detached { [self] in
            core.installedSystemImages(sdkPathOverride: locations.sdkPath).map(Self.image(from:))
        }.value
    }

    public func deviceProfiles(locations: Locations) async throws -> [AVDStudioUI.DeviceProfile] {
        try await Task.detached { [self] in
            do {
                return try core.deviceProfiles(sdkPathOverride: locations.sdkPath).map(Self.profile(from:))
            } catch {
                throw ServiceError(Self.message(for: error))
            }
        }.value
    }

    public func validateDeviceName(_ name: String, locations: Locations) async -> String? {
        await Task.detached { [self] in core.validateAvdName(name: name, avdHomeOverride: locations.avdHome) }.value
    }

    public func createDevice(_ request: CreateDeviceRequest, locations: Locations) async throws {
        try await Task.detached { [self] in
            // Swift values carry ids only; the Kotlin objects are looked up again here.
            guard
                let image = core.installedSystemImages(sdkPathOverride: locations.sdkPath).first(where: {
                    $0.packagePath == request.systemImage.packagePath
                })
            else { throw ServiceError("The system image \(request.systemImage.packagePath) is no longer installed.") }
            let device = AVDStudioCore.DeviceProfile(
                id: request.device.id, name: request.device.name, manufacturer: request.device.manufacturer, tag: nil, formFactor: .unknown
            )
            let kotlinRequest = CreateAvdRequest(
                name: request.name,
                displayName: request.displayName,
                systemImage: image,
                device: device,
                ramMegabytes: request.ramMegabytes.map { KotlinInt(int: Int32($0)) },
                storage: request.storage,
                sdCard: request.sdCard
            )
            do {
                _ = try core.createAvd(request: kotlinRequest, sdkPathOverride: locations.sdkPath, avdHomeOverride: locations.avdHome)
            } catch {
                throw ServiceError(Self.message(for: error))
            }
        }.value
    }

    public func deleteDevice(_ device: VirtualDevice, locations: Locations) async throws {
        try await Task.detached { [self] in
            do {
                try core.deleteAvd(avdName: device.id, sdkPathOverride: locations.sdkPath, avdHomeOverride: locations.avdHome)
            } catch {
                throw ServiceError(Self.message(for: error))
            }
        }.value
    }

    // MARK: Mapping

    static func image(from image: AVDStudioCore.SystemImage) -> AVDStudioUI.SystemImage {
        AVDStudioUI.SystemImage(
            packagePath: image.packagePath,
            apiLevel: image.apiLevel?.label,
            androidVersion: image.apiLevel?.androidVersion,
            versionLabel: image.versionLabel,
            tagDisplay: image.tagDisplay,
            abi: image.abi,
            hasPlayStore: image.hasPlayStore,
            isNativeOnAppleSilicon: image.isNativeOnAppleSilicon,
            family: family(from: image.family),
            sizeBytes: image.sizeBytes?.int64Value
        )
    }

    static func remoteImage(from image: AvailableSystemImage) -> RemoteSystemImage {
        RemoteSystemImage(
            packagePath: image.packagePath,
            apiLevel: image.apiLevel?.label,
            androidVersion: image.apiLevel?.androidVersion,
            // Qualified, so `android-36` and `android-36-ext18` are not two identical rows.
            versionLabel: image.qualifiedVersionLabel,
            tagDisplay: image.tagDisplay,
            abi: image.abi,
            revision: image.revision,
            hasPlayStore: image.hasPlayStore,
            isNativeOnAppleSilicon: image.isNativeOnAppleSilicon,
            isPreview: image.isPreview,
            usesSixteenKbPages: image.usesSixteenKbPages,
            isAutomatedTestImage: image.isAutomatedTestImage,
            family: family(from: image.family),
            isInstalled: image.isInstalled
        )
    }

    static func stepResult(from result: CommandResult) -> SetupStepResult {
        let output = [result.standardOutput, result.standardError].filter { !$0.isEmpty }.joined(separator: "\n")
        return SetupStepResult(exitCode: result.exitCode, output: output)
    }

    static func family(from family: ImageFamily) -> AVDStudioUI.SystemImage.Family {
        switch family.name {
        case "TV": .tv
        case "WEAR_OS": .wearOS
        case "AUTOMOTIVE": .automotive
        case "DESKTOP": .desktop
        case "XR": .xr
        default: .general
        }
    }

    static func profile(from profile: AVDStudioCore.DeviceProfile) -> AVDStudioUI.DeviceProfile {
        AVDStudioUI.DeviceProfile(
            id: profile.id, name: profile.name, manufacturer: profile.manufacturer, kind: kind(from: profile.formFactor))
    }

    static func plan(from plan: AVDStudioCore.SetupPlan) -> AVDStudioUI.SetupPlan {
        AVDStudioUI.SetupPlan(
            steps: plan.steps.map {
                AVDStudioUI.SetupStep(
                    kind: kind(from: $0.kind),
                    title: $0.title,
                    displayCommand: $0.displayCommand,
                    requiresHomebrew: $0.requiresHomebrew,
                    requiresLicenseAcceptance: $0.requiresLicenseAcceptance
                )
            },
            homebrewInstalled: plan.homebrewPath != nil,
            sdkPath: plan.sdkPath,
            shellScript: plan.shellScript
        )
    }

    static func kind(from kind: AVDStudioCore.SetupStepKind) -> AVDStudioUI.SetupStep.Kind {
        switch kind.name {
        case "COMMAND_LINE_TOOLS": .commandLineTools
        case "JAVA": .java
        case "LICENSES": .licenses
        case "SDK_PACKAGES": .sdkPackages
        default: .systemImages
        }
    }

    static func device(from avd: Avd) -> VirtualDevice {
        VirtualDevice(
            id: avd.name,
            displayName: avd.displayName,
            path: avd.path,
            kind: kind(from: avd.formFactor),
            apiLevel: avd.apiLevel?.label,
            androidVersion: avd.apiLevel?.androidVersion,
            deviceProfile: avd.deviceProfile,
            abi: avd.abi,
            hasPlayStore: avd.hasPlayStore,
            ramMegabytes: avd.ramMegabytes?.intValue,
            storage: avd.storage,
            diskUsageBytes: avd.diskUsageBytes,
            status: status(from: avd.health),
            systemImagePackage: avd.systemImagePackage
        )
    }

    static func kind(from formFactor: FormFactor) -> DeviceKind {
        switch formFactor.name {
        case "PHONE": .phone
        case "FOLDABLE": .foldable
        case "TABLET": .tablet
        case "WEAR_OS": .wearOS
        case "DESKTOP": .desktop
        case "TV": .tv
        case "AUTOMOTIVE": .automotive
        case "XR": .xr
        default: .unknown
        }
    }

    static func status(from health: AvdHealth) -> VirtualDevice.Status {
        switch health.name {
        case "READY": .ready
        case "MISSING_SYSTEM_IMAGE": .missingSystemImage
        default: .invalidConfiguration
        }
    }

    static func status(from status: CheckStatus) -> DoctorItem.Status {
        switch status.name {
        case "PASS": .pass
        case "WARNING": .warning
        default: .fail
        }
    }

    static func summary(from toolchain: ToolchainStatus) -> ToolchainSummary {
        ToolchainSummary(
            sdkPath: toolchain.sdkPath,
            sourceDescription: describe(toolchain.source),
            directoryExists: toolchain.sdkDirectoryExists,
            isConfigured: toolchain.isConfigured,
            summary: toolchain.summary,
            tools: toolchain.tools.map { state in
                ToolchainSummary.Tool(name: state.tool.executableName, path: state.path, state: toolState(from: state.availability))
            }
        )
    }

    static func toolState(from availability: ToolAvailability) -> ToolchainSummary.Tool.State {
        switch availability.name {
        case "AVAILABLE": .available
        case "DEPRECATED": .deprecated
        default: .missing
        }
    }

    static func describe(_ source: SdkSource) -> String {
        switch source.name {
        case "EXPLICIT": "chosen by you"
        case "ANDROID_SDK_ROOT": "from ANDROID_SDK_ROOT"
        case "ANDROID_HOME": "from ANDROID_HOME"
        case "ANDROID_STUDIO_DEFAULT": "Android Studio default"
        case "HOMEBREW": "Homebrew"
        default: "default location"
        }
    }

    /// Kotlin exceptions arrive as `NSError`s whose own description is generic; the real text is on the exception.
    static func message(for error: Error) -> String {
        let nsError = error as NSError
        if let exception = nsError.userInfo["KotlinException"] as? KotlinThrowable, let message = exception.message {
            return message
        }
        return error.localizedDescription
    }
}
