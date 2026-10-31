import Foundation

@testable import AVDStudioUI

/// A controllable `DeviceService` that records what the model asks of it.
actor FakeDeviceService: DeviceService {
    struct Launch: Equatable {
        let id: String
        let options: LaunchOptions
    }

    var devices: [VirtualDevice]
    var toolchain: ToolchainSummary
    var running: [RunningDevice]
    var launchError: ServiceError?
    var plan: SetupPlan = .empty
    /// exit code per step kind; missing = 0. A step kind in `startFailures` throws instead.
    var stepExitCodes: [SetupStep.Kind: Int32] = [:]
    var startFailures: Set<SetupStep.Kind> = []
    private(set) var ranSteps: [SetupStep.Kind] = []
    private(set) var launches: [Launch] = []
    private(set) var stops: [String] = []
    private(set) var snapshotRequests: [Locations] = []

    init(
        devices: [VirtualDevice] = SampleData.devices,
        toolchain: ToolchainSummary = SampleData.readyToolchain,
        running: [RunningDevice] = []
    ) {
        self.devices = devices
        self.toolchain = toolchain
        self.running = running
    }

    func setRunning(_ running: [RunningDevice]) { self.running = running }
    func setDevices(_ devices: [VirtualDevice]) { self.devices = devices }
    func setLaunchError(_ error: ServiceError?) { launchError = error }
    func setPlan(_ plan: SetupPlan) { self.plan = plan }
    func setStepExitCodes(_ codes: [SetupStep.Kind: Int32]) { stepExitCodes = codes }
    func setStartFailures(_ kinds: Set<SetupStep.Kind>) { startFailures = kinds }

    func snapshot(locations: Locations) async -> DeviceSnapshot {
        snapshotRequests.append(locations)
        return DeviceSnapshot(devices: devices, running: running, toolchain: toolchain, avdHome: "/avd")
    }

    func runningDevices() async -> [RunningDevice] { running }
    func diagnose(locations: Locations) async -> [DoctorItem] { SampleData.diagnostics }

    func launch(_ device: VirtualDevice, options: LaunchOptions, locations: Locations) async throws {
        if let launchError { throw launchError }
        launches.append(Launch(id: device.id, options: options))
    }

    func stop(_ device: VirtualDevice) async throws {
        stops.append(device.id)
        running.removeAll { $0.name == device.id }
    }

    func setupPlan(locations: Locations) async -> SetupPlan { plan }

    func runSetupStep(_ step: SetupStep, locations: Locations) async throws -> SetupStepResult {
        ranSteps.append(step.kind)
        if startFailures.contains(step.kind) { throw ServiceError("Cannot execute brew: file not found.") }
        let code = stepExitCodes[step.kind] ?? 0
        return SetupStepResult(exitCode: code, output: code == 0 ? "ok" : "line1\nline2\nError: something broke")
    }
}

/// A clock the tests move by hand.
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current = Date(timeIntervalSince1970: 1_700_000_000)

    var now: Date {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    func advance(by seconds: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        current = current.addingTimeInterval(seconds)
    }
}
