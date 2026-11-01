import Foundation
import Observation

/// Backs the "New Device" sheet: loads the catalogs, keeps the choices consistent and creates the device.
@MainActor
@Observable
public final class CreateDeviceModel {
    public enum Phase: Equatable, Sendable {
        case loading
        case ready
        /// The catalogs could not be loaded (no avdmanager / Java).
        case unavailable(String)
        case creating
        case created(name: String)
    }

    public private(set) var phase: Phase = .loading
    public private(set) var profiles: [DeviceProfile] = []
    public private(set) var images: [SystemImage] = []
    public private(set) var existingNames: [String] = []
    public var errorMessage: String?

    public var kind: DeviceKind = .phone {
        didSet { if kind != oldValue { kindChanged() } }
    }
    public var device: DeviceProfile? {
        didSet { if device != oldValue { refreshSuggestedName() } }
    }
    public var image: SystemImage? {
        didSet { if image != oldValue { refreshSuggestedName() } }
    }
    public var name = "" {
        didSet { if name != suggestedName { nameEditedByUser = true } }
    }
    public var displayName = ""
    public var ram: RAMPreset = .default
    public var storage: StoragePreset = .default
    public var sdCard: SDCardPreset = .none

    @ObservationIgnored private let service: any DeviceService
    @ObservationIgnored private let locations: Locations
    @ObservationIgnored private var suggestedName = ""
    @ObservationIgnored private var nameEditedByUser = false

    public init(service: any DeviceService, locations: Locations, existingNames: [String], kind: DeviceKind = .phone) {
        self.service = service
        self.locations = locations
        self.existingNames = existingNames
        self.kind = kind
    }

    // MARK: Derived

    /// Kinds for which at least one hardware definition exists, in sidebar order.
    public var availableKinds: [DeviceKind] {
        DeviceKind.allCases.filter { kind in kind != .unknown && profiles.contains { $0.kind == kind } }
    }

    public var devicesForKind: [DeviceProfile] { profiles.filter { $0.kind == kind } }

    public var imagesForKind: [SystemImage] { images.filter { $0.family.supports(kind) } }

    public var nameError: String? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "Give the device a name." }
        if trimmed.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) == nil {
            return "Use only letters, digits, dots, dashes and underscores (no spaces)."
        }
        if existingNames.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return "A device called \(trimmed) already exists."
        }
        return nil
    }

    public var canCreate: Bool {
        phase == .ready && device != nil && image != nil && nameError == nil
    }

    public var request: CreateDeviceRequest? {
        guard let device, let image else { return nil }
        let trimmedDisplay = displayName.trimmingCharacters(in: .whitespaces)
        return CreateDeviceRequest(
            name: name.trimmingCharacters(in: .whitespaces),
            displayName: trimmedDisplay.isEmpty ? nil : trimmedDisplay,
            systemImage: image,
            device: device,
            ramMegabytes: ram.megabytes,
            storage: storage.value,
            sdCard: sdCard.value
        )
    }

    // MARK: Loading

    public func load() async {
        phase = .loading
        images = await service.installedSystemImages(locations: locations)
        do {
            profiles = try await service.deviceProfiles(locations: locations)
        } catch {
            phase = .unavailable(error.localizedDescription)
            return
        }
        if !availableKinds.contains(kind) { kind = availableKinds.first ?? .phone }
        kindChanged()
        phase = .ready
    }

    /// Reads the installed images again, after the user downloaded or removed some in Settings. The current choice
    /// is kept while it is still installed.
    public func reloadImages() async {
        let fresh = await service.installedSystemImages(locations: locations)
        guard fresh != images else { return }
        let previous = image
        images = fresh
        if let previous, imagesForKind.contains(previous) { image = previous } else { image = imagesForKind.first }
    }

    // MARK: Actions

    public func create() async {
        guard canCreate, let request else { return }
        phase = .creating
        do {
            try await service.createDevice(request, locations: locations)
            phase = .created(name: request.name)
        } catch {
            errorMessage = error.localizedDescription
            phase = .ready
        }
    }

    // MARK: Private

    private func kindChanged() {
        device = recommendedDevice()
        image = imagesForKind.first
        if device == nil { refreshSuggestedName() }
    }

    private func recommendedDevice() -> DeviceProfile? {
        let candidates = devicesForKind
        let preferred: [String] =
            switch kind {
            case .phone: ["pixel_9", "pixel_8", "medium_phone"]
            case .foldable: ["pixel_9_pro_fold", "pixel_fold"]
            case .tablet: ["pixel_tablet", "medium_tablet"]
            case .wearOS: ["wearos_large_round", "wearos_square"]
            case .tv: ["tv_1080p", "tv_4k"]
            case .automotive: ["automotive_1080p_landscape"]
            case .desktop: ["desktop_medium"]
            case .xr: ["xr_headset_device"]
            case .unknown: []
            }
        return preferred.lazy.compactMap { id in candidates.first { $0.id == id } }.first ?? candidates.first
    }

    /// `Pixel 9` + API 36 → `Pixel_9_API_36`, made unique; stops once the user typed a name of their own.
    private func refreshSuggestedName() {
        guard !nameEditedByUser else { return }
        var base = [device?.name, image?.apiLevel.map { "API_\($0)" }].compactMap { $0 }.joined(separator: "_")
        base = base.replacingOccurrences(of: "[^A-Za-z0-9._-]+", with: "_", options: .regularExpression)
        base = base.replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
        base = base.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        if base.isEmpty { base = "Device" }
        var candidate = base
        var counter = 2
        while existingNames.contains(where: { $0.caseInsensitiveCompare(candidate) == .orderedSame }) {
            candidate = "\(base)_\(counter)"
            counter += 1
        }
        suggestedName = candidate
        name = candidate
        nameEditedByUser = false
    }
}
