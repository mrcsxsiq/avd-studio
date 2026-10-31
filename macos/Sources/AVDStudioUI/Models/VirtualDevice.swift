import Foundation

public struct VirtualDevice: Identifiable, Hashable, Sendable {
    public enum Status: Hashable, Sendable {
        case ready
        case missingSystemImage
        case invalidConfiguration

        public var title: String {
            switch self {
            case .ready: "Ready"
            case .missingSystemImage: "Needs system image"
            case .invalidConfiguration: "Invalid configuration"
            }
        }
    }

    /// The AVD name (what `emulator -avd` expects).
    public let id: String
    public let displayName: String
    public let path: String
    public let kind: DeviceKind
    public let apiLevel: String?
    public let androidVersion: String?
    public let deviceProfile: String?
    public let abi: String?
    public let hasPlayStore: Bool
    public let ramMegabytes: Int?
    public let storage: String?
    public let diskUsageBytes: Int64
    public let status: Status

    public init(
        id: String,
        displayName: String? = nil,
        path: String = "",
        kind: DeviceKind = .phone,
        apiLevel: String? = nil,
        androidVersion: String? = nil,
        deviceProfile: String? = nil,
        abi: String? = nil,
        hasPlayStore: Bool = false,
        ramMegabytes: Int? = nil,
        storage: String? = nil,
        diskUsageBytes: Int64 = 0,
        status: Status = .ready
    ) {
        self.id = id
        self.displayName = displayName ?? id.replacingOccurrences(of: "_", with: " ")
        self.path = path
        self.kind = kind
        self.apiLevel = apiLevel
        self.androidVersion = androidVersion
        self.deviceProfile = deviceProfile
        self.abi = abi
        self.hasPlayStore = hasPlayStore
        self.ramMegabytes = ramMegabytes
        self.storage = storage
        self.diskUsageBytes = diskUsageBytes
        self.status = status
    }

    public var name: String { id }
    public var isLaunchable: Bool { status == .ready }

    /// `Android 14`, falling back to `API 34`.
    public var releaseLabel: String {
        if let androidVersion { return "Android \(androidVersion)" }
        if let apiLevel { return "API \(apiLevel)" }
        return "Unknown version"
    }

    public var ramLabel: String? {
        guard let ramMegabytes else { return nil }
        return ramMegabytes >= 1024 && ramMegabytes % 1024 == 0 ? "\(ramMegabytes / 1024) GB RAM" : "\(ramMegabytes) MB RAM"
    }

    /// Text the search field matches against.
    var searchableText: String {
        [id, displayName, kind.title, releaseLabel, deviceProfile ?? ""].joined(separator: " ")
    }
}

public struct RunningDevice: Hashable, Sendable {
    public let name: String
    public let processID: Int32

    public init(name: String, processID: Int32) {
        self.name = name
        self.processID = processID
    }
}
