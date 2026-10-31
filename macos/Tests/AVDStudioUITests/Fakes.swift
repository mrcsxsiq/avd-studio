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
