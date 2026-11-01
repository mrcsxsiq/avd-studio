import Foundation

/// A system image installed in the SDK.
public struct SystemImage: Identifiable, Hashable, Sendable {
    public enum Family: String, Sendable {
        case general, tv, wearOS, automotive, desktop, xr

        public func supports(_ kind: DeviceKind) -> Bool {
            switch self {
            case .general: [.phone, .foldable, .tablet, .unknown].contains(kind)
            case .tv: kind == .tv
            case .wearOS: kind == .wearOS
            case .automotive: kind == .automotive
            case .desktop: kind == .desktop
            case .xr: kind == .xr
            }
        }
    }

    /// `system-images;android-36;google_apis_playstore;arm64-v8a` (also the id).
    public let packagePath: String
    public let apiLevel: String?
    public let androidVersion: String?
    /// `Android 16 (API 36)` or `Android Baklava (preview)`.
    public let versionLabel: String
    public let tagDisplay: String
    public let abi: String
    public let hasPlayStore: Bool
    public let isNativeOnAppleSilicon: Bool
    public let family: Family
    /// Space the image takes on disk, when known.
    public let sizeBytes: Int64?

    public var id: String { packagePath }

    public init(
        packagePath: String, apiLevel: String?, androidVersion: String?, versionLabel: String, tagDisplay: String,
        abi: String, hasPlayStore: Bool, isNativeOnAppleSilicon: Bool, family: Family, sizeBytes: Int64? = nil
    ) {
        self.packagePath = packagePath
        self.apiLevel = apiLevel
        self.androidVersion = androidVersion
        self.versionLabel = versionLabel
        self.tagDisplay = tagDisplay
        self.abi = abi
        self.hasPlayStore = hasPlayStore
        self.isNativeOnAppleSilicon = isNativeOnAppleSilicon
        self.family = family
        self.sizeBytes = sizeBytes
    }

    /// `Android 16 (API 36) · Google Play · arm64-v8a`
    public var displayName: String { "\(versionLabel) · \(tagDisplay) · \(abi)" }
}

/// A hardware definition from `avdmanager list device`.
public struct DeviceProfile: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let manufacturer: String
    public let kind: DeviceKind

    public init(id: String, name: String, manufacturer: String, kind: DeviceKind) {
        self.id = id
        self.name = name
        self.manufacturer = manufacturer
        self.kind = kind
    }
}

public struct CreateDeviceRequest: Equatable, Sendable {
    public var name: String
    public var displayName: String?
    public var systemImage: SystemImage
    public var device: DeviceProfile
    public var ramMegabytes: Int?
    public var storage: String?
    public var sdCard: String?

    public init(
        name: String, displayName: String? = nil, systemImage: SystemImage, device: DeviceProfile,
        ramMegabytes: Int? = nil, storage: String? = nil, sdCard: String? = nil
    ) {
        self.name = name
        self.displayName = displayName
        self.systemImage = systemImage
        self.device = device
        self.ramMegabytes = ramMegabytes
        self.storage = storage
        self.sdCard = sdCard
    }
}

/// Fixed choices offered by the create sheet. `nil` value = keep the hardware definition's default.
public enum RAMPreset: String, CaseIterable, Identifiable, Sendable {
    case `default`, gb2, gb4, gb8
    public var id: String { rawValue }
    public var title: String { megabytes.map { "\($0 / 1024) GB" } ?? "Default" }
    public var megabytes: Int? {
        switch self {
        case .default: nil
        case .gb2: 2048
        case .gb4: 4096
        case .gb8: 8192
        }
    }
}

public enum StoragePreset: String, CaseIterable, Identifiable, Sendable {
    case `default`, gb8, gb16, gb32, gb64
    public var id: String { rawValue }
    public var title: String { value.map { "\($0.dropLast()) GB" } ?? "Default (10 GB)" }
    public var value: String? {
        switch self {
        case .default: nil
        case .gb8: "8G"
        case .gb16: "16G"
        case .gb32: "32G"
        case .gb64: "64G"
        }
    }
}

public enum SDCardPreset: String, CaseIterable, Identifiable, Sendable {
    case none, mb512, gb1, gb2
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .none: "None"
        case .mb512: "512 MB"
        case .gb1: "1 GB"
        case .gb2: "2 GB"
        }
    }
    public var value: String? {
        switch self {
        case .none: nil
        case .mb512: "512M"
        case .gb1: "1024M"
        case .gb2: "2048M"
        }
    }
}
