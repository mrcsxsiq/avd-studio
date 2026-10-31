import Foundation
import Observation

public enum SidebarItem: Hashable, Sendable {
    case all
    case kind(DeviceKind)
}

public enum RunState: Equatable, Sendable {
    case idle
    case starting
    case running
}

/// The single source of truth for the window, the settings and the menu bar item.
@MainActor
@Observable
public final class AppModel {
    @ObservationIgnored private let service: any DeviceService
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var startedAt: [String: Date] = [:]
    @ObservationIgnored private var monitorTask: Task<Void, Never>?

    /// How long we show "Starting…" before assuming the emulator never came up.
    static let startTimeout: TimeInterval = 90

    public private(set) var devices: [VirtualDevice] = []
    public private(set) var runningNames: Set<String> = []
    public private(set) var startingNames: Set<String> = []
    public private(set) var toolchain: ToolchainSummary?
    public private(set) var avdHome = ""
    public private(set) var diagnostics: [DoctorItem] = []
    public private(set) var setupPlan: SetupPlan = .empty
    public private(set) var hasLoaded = false
    public private(set) var isRefreshing = false

    public var sidebarSelection: SidebarItem? = .all
    public var searchText = ""
    public var selection: VirtualDevice.ID?
    public var errorMessage: String?
    /// Set while the user is confirming a destructive "wipe data" start.
    public var pendingWipe: VirtualDevice?
    /// Set while the user is confirming a deletion.
    public var pendingDelete: VirtualDevice?
    /// The sheet for a new device, while it is open.
    public var creating: CreateDeviceModel?

    public var locations: Locations {
        didSet { saveLocations() }
    }

    public init(
        service: any DeviceService,
        defaults: UserDefaults = .standard,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.service = service
        self.defaults = defaults
        self.now = now
        self.locations = Locations(
            sdkPath: Self.clean(defaults.string(forKey: Keys.sdkPath)),
            avdHome: Self.clean(defaults.string(forKey: Keys.avdHome))
        )
    }

    // MARK: Derived state

    public var needsSetup: Bool { hasLoaded && toolchain?.isConfigured == false }
    public var runningCount: Int { runningNames.count }

    public var visibleDevices: [VirtualDevice] {
        let kind: DeviceKind? = if case .kind(let selected) = sidebarSelection { selected } else { nil }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return devices.filter { device in
            (kind == nil || device.kind == kind)
                && (query.isEmpty || device.searchableText.lowercased().contains(query))
        }
    }

    /// Kinds that have at least one device, in the order the sidebar shows them.
    public var availableKinds: [DeviceKind] {
        DeviceKind.allCases.filter { kind in devices.contains { $0.kind == kind } }
    }

    public func count(for item: SidebarItem) -> Int {
        switch item {
        case .all: devices.count
        case .kind(let kind): devices.filter { $0.kind == kind }.count
        }
    }

    public var currentTitle: String {
        if case .kind(let kind) = sidebarSelection { kind.pluralTitle } else { "All Devices" }
    }

    public func runState(of device: VirtualDevice) -> RunState {
        if runningNames.contains(device.id) { return .running }
        if startingNames.contains(device.id) { return .starting }
        return .idle
    }

    public func devices(of kind: DeviceKind) -> [VirtualDevice] {
        devices.filter { $0.kind == kind }
    }

    // MARK: Loading

    public func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        load(await service.snapshot(locations: locations))
    }

    /// Applies a snapshot. Public so previews and tests can show a fully loaded model without async work.
    public func load(_ snapshot: DeviceSnapshot) {
        devices = snapshot.devices
        toolchain = snapshot.toolchain
        avdHome = snapshot.avdHome
        runningNames = Set(snapshot.running.map(\.name))
        pruneStarting()
        if let selection, !devices.contains(where: { $0.id == selection }) { self.selection = nil }
        hasLoaded = true
    }

    public func refreshRunning() async {
        runningNames = Set(await service.runningDevices().map(\.name))
        pruneStarting()
    }

    public func runDiagnostics() async {
        diagnostics = await service.diagnose(locations: locations)
        setupPlan = await service.setupPlan(locations: locations)
    }

    public func loadSetupPlan() async {
        setupPlan = await service.setupPlan(locations: locations)
    }

    /// For previews and screenshot tests only: shows a plan without asking the service.
    public func setSetupPlanForPreview(_ plan: SetupPlan) {
        setupPlan = plan
    }

    public func makeSetupModel() -> SetupModel {
        SetupModel(plan: setupPlan, service: service, locations: locations)
    }

    /// After a successful installation: reload, and switch to the SDK the steps installed into when the
    /// previous one was unusable (Homebrew's tools live in their own folder).
    public func completeSetup(_ plan: SetupPlan) async {
        let wasConfigured = toolchain?.isConfigured == true
        await refresh()
        if !wasConfigured, toolchain?.isConfigured != true, !plan.sdkPath.isEmpty, plan.sdkPath != toolchain?.sdkPath {
            await update(locations: Locations(sdkPath: plan.sdkPath, avdHome: locations.avdHome))
        }
        await loadSetupPlan()
    }

    /// Polls for running emulators so the window and the menu bar stay truthful, even for emulators
    /// started elsewhere (Android Studio, a terminal).
    public func startMonitoring(interval: Duration = .seconds(3)) {
        guard monitorTask == nil else { return }
        monitorTask = Task { [weak self] in
            await self?.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                await self?.refreshRunning()
            }
        }
    }

    public func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    // MARK: Actions

    public func launch(_ device: VirtualDevice, options: LaunchOptions = LaunchOptions()) async {
        guard device.isLaunchable else {
            errorMessage = "\(device.displayName) can't start: \(device.status.title.lowercased())."
            return
        }
        guard runState(of: device) == .idle else { return }
        startingNames.insert(device.id)
        startedAt[device.id] = now()
        do {
            try await service.launch(device, options: options, locations: locations)
        } catch {
            startingNames.remove(device.id)
            startedAt[device.id] = nil
            errorMessage = error.localizedDescription
        }
    }

    public func stop(_ device: VirtualDevice) async {
        do {
            try await service.stop(device)
            await refreshRunning()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Start or stop depending on the current state; what the card's round button does.
    public func togglePower(_ device: VirtualDevice) async {
        switch runState(of: device) {
        case .idle: await launch(device)
        case .running: await stop(device)
        case .starting: break
        }
    }

    /// Opens the "New Device" sheet, preselecting the sidebar's type when one is chosen.
    public func presentCreateDevice() {
        let kind: DeviceKind = if case .kind(let selected) = sidebarSelection { selected } else { .phone }
        creating = CreateDeviceModel(service: service, locations: locations, existingNames: devices.map(\.id), kind: kind)
    }

    public func deviceCreated(named name: String) async {
        await refresh()
        selection = name
        if case .kind(let kind) = sidebarSelection, devices.first(where: { $0.id == name })?.kind != kind {
            sidebarSelection = .all
        }
    }

    public func confirmDelete() async {
        guard let device = pendingDelete else { return }
        pendingDelete = nil
        do {
            try await service.deleteDevice(device, locations: locations)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func confirmWipe() async {
        guard let device = pendingWipe else { return }
        pendingWipe = nil
        await launch(device, options: LaunchOptions(coldBoot: true, wipeData: true))
    }

    public func update(locations newValue: Locations) async {
        locations = Locations(sdkPath: Self.clean(newValue.sdkPath), avdHome: Self.clean(newValue.avdHome))
        await refresh()
        await runDiagnostics()
    }

    // MARK: Private

    private func pruneStarting() {
        let cutoff = now().addingTimeInterval(-Self.startTimeout)
        for name in startingNames where runningNames.contains(name) || (startedAt[name] ?? .distantPast) < cutoff {
            startingNames.remove(name)
            startedAt[name] = nil
        }
    }

    private func saveLocations() {
        defaults.set(locations.sdkPath, forKey: Keys.sdkPath)
        defaults.set(locations.avdHome, forKey: Keys.avdHome)
    }

    private static func clean(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private enum Keys {
        static let sdkPath = "locations.sdkPath"
        static let avdHome = "locations.avdHome"
    }
}
