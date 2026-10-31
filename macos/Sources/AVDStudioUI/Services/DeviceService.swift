import Foundation

/// Where the user told us to look. `nil` means "detect automatically".
public struct Locations: Equatable, Sendable {
    public var sdkPath: String?
    public var avdHome: String?

    public init(sdkPath: String? = nil, avdHome: String? = nil) {
        self.sdkPath = sdkPath
        self.avdHome = avdHome
    }
}

public struct LaunchOptions: Equatable, Sendable {
    public var coldBoot: Bool
    public var wipeData: Bool

    public init(coldBoot: Bool = false, wipeData: Bool = false) {
        self.coldBoot = coldBoot
        self.wipeData = wipeData
    }
}

public struct DeviceSnapshot: Sendable {
    public let devices: [VirtualDevice]
    public let running: [RunningDevice]
    public let toolchain: ToolchainSummary
    public let avdHome: String

    public init(devices: [VirtualDevice], running: [RunningDevice], toolchain: ToolchainSummary, avdHome: String) {
        self.devices = devices
        self.running = running
        self.toolchain = toolchain
        self.avdHome = avdHome
    }
}

public struct ServiceError: LocalizedError, Equatable, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

/// Everything the UI needs from the outside world. The real implementation lives in `AVDStudioKit`
/// and talks to the Kotlin core; tests and previews use in-memory fakes.
public protocol DeviceService: Sendable {
    func snapshot(locations: Locations) async -> DeviceSnapshot
    func runningDevices() async -> [RunningDevice]
    func diagnose(locations: Locations) async -> [DoctorItem]
    func launch(_ device: VirtualDevice, options: LaunchOptions, locations: Locations) async throws
    func stop(_ device: VirtualDevice) async throws
    /// What is missing and how to install it. Nothing runs.
    func setupPlan(locations: Locations) async -> SetupPlan
    /// Runs one step to completion. Throws only when the command cannot be started at all.
    func runSetupStep(_ step: SetupStep, locations: Locations) async throws -> SetupStepResult
}
