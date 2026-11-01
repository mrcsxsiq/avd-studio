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
    var images: [SystemImage] = SampleData.systemImages
    var profiles: [DeviceProfile] = SampleData.deviceProfiles
    var profilesError: ServiceError?
    var createError: ServiceError?
    var deleteError: ServiceError?
    private(set) var created: [CreateDeviceRequest] = []
    private(set) var deleted: [String] = []
    private(set) var launches: [Launch] = []
    private(set) var stops: [String] = []
    private(set) var snapshotRequests: [Locations] = []
    var availableImages: [RemoteSystemImage] = SampleData.availableImages
    var availableError: ServiceError?
    /// Exit code of the next install / removal; the output is made up from it.
    var installExitCode: Int32 = 0
    var installError: ServiceError?
    var removeExitCode: Int32 = 0
    var removeError: ServiceError?
    private(set) var availableRequests = 0
    /// How long an install takes, so a test can look at the model while it runs.
    var installDelay: Duration = .zero
    /// Packages whose install fails with exit code 1; every other one succeeds.
    var failingPackages: Set<String> = []
    /// What `downloadedBytes` reports, per call, then the last value again.
    var bytesScript: [Int64] = [0]
    private(set) var bytesRequests: [Date] = []
    private(set) var installs: [(packages: [String], licenseAccepted: Bool)] = []
    private(set) var removals: [(package: String, force: Bool)] = []

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
    func setImages(_ images: [SystemImage]) { self.images = images }
    func setProfiles(_ profiles: [DeviceProfile]) { self.profiles = profiles }
    func setProfilesError(_ error: ServiceError?) { profilesError = error }
    func setCreateError(_ error: ServiceError?) { createError = error }
    func setDeleteError(_ error: ServiceError?) { deleteError = error }
    func setAvailableImages(_ images: [RemoteSystemImage]) { availableImages = images }
    func setAvailableError(_ error: ServiceError?) { availableError = error }
    func setInstallDelay(_ delay: Duration) { installDelay = delay }
    func setFailingPackages(_ packages: Set<String>) { failingPackages = packages }
    func setBytesScript(_ script: [Int64]) { bytesScript = script }
    func setInstall(exitCode: Int32 = 0, error: ServiceError? = nil) {
        installExitCode = exitCode
        installError = error
    }
    func setRemove(exitCode: Int32 = 0, error: ServiceError? = nil) {
        removeExitCode = exitCode
        removeError = error
    }

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

    func installedSystemImages(locations: Locations) async -> [SystemImage] { images }

    func availableSystemImages(locations: Locations) async throws -> [RemoteSystemImage] {
        availableRequests += 1
        if let availableError { throw availableError }
        return availableImages
    }

    func installSystemImages(_ packages: [String], licenseAccepted: Bool, locations: Locations) async throws -> SetupStepResult {
        installs.append((packages, licenseAccepted))
        if installDelay > .zero { try? await Task.sleep(for: installDelay) }
        if let installError { throw installError }
        guard installExitCode == 0, failingPackages.isDisjoint(with: packages) else {
            return SetupStepResult(
                exitCode: installExitCode == 0 ? 1 : installExitCode, output: "Warning: something\nError: download failed")
        }
        // The downloaded images show up as installed, like they would on disk.
        for package in packages {
            guard let remote = availableImages.first(where: { $0.packagePath == package }) else { continue }
            images.append(
                SystemImage(
                    packagePath: remote.packagePath, apiLevel: remote.apiLevel, androidVersion: remote.androidVersion,
                    versionLabel: remote.versionLabel, tagDisplay: remote.tagDisplay, abi: remote.abi,
                    hasPlayStore: remote.hasPlayStore, isNativeOnAppleSilicon: remote.isNativeOnAppleSilicon, family: remote.family))
        }
        return SetupStepResult(exitCode: 0, output: "done")
    }

    func downloadedBytes(since: Date, locations: Locations) async -> Int64 {
        bytesRequests.append(since)
        return bytesScript.count > 1 ? bytesScript.removeFirst() : (bytesScript.first ?? 0)
    }

    func removeSystemImage(_ image: SystemImage, force: Bool, locations: Locations) async throws -> SetupStepResult {
        removals.append((image.packagePath, force))
        if let removeError { throw removeError }
        guard removeExitCode == 0 else { return SetupStepResult(exitCode: removeExitCode, output: "Error: could not remove") }
        images.removeAll { $0.packagePath == image.packagePath }
        return SetupStepResult(exitCode: 0, output: "")
    }

    func deviceProfiles(locations: Locations) async throws -> [DeviceProfile] {
        if let profilesError { throw profilesError }
        return profiles
    }

    func validateDeviceName(_ name: String, locations: Locations) async -> String? {
        devices.contains { $0.id == name } ? "A device called \(name) already exists." : nil
    }

    func createDevice(_ request: CreateDeviceRequest, locations: Locations) async throws {
        if let createError { throw createError }
        created.append(request)
        devices.append(
            VirtualDevice(
                id: request.name, displayName: request.displayName, kind: request.device.kind, apiLevel: request.systemImage.apiLevel))
    }

    func deleteDevice(_ device: VirtualDevice, locations: Locations) async throws {
        if let deleteError { throw deleteError }
        deleted.append(device.id)
        devices.removeAll { $0.id == device.id }
    }

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
