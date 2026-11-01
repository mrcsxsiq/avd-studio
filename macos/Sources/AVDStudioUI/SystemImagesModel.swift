import Foundation
import Observation

/// Backs the "System Images" tab in Settings: what is installed and how big it is, what can be downloaded, and
/// removing what is no longer needed.
///
/// The list of downloadable images comes from Google's servers (through `sdkmanager`), so it is only fetched when
/// the user asks for it. Nothing is downloaded until they tick the licence box and press the button.
@MainActor
@Observable
public final class SystemImagesModel {
    /// The list Google publishes.
    public enum Catalog: Equatable, Sendable {
        case notLoaded
        case loading
        case loaded([RemoteSystemImage])
        case failed(String)
    }

    /// Something that takes a while and blocks other changes.
    public enum Work: Equatable, Sendable {
        case idle
        case installing(count: Int)
        case removing(String)
        /// The last install or removal failed; the text is the tail of the tool's output.
        case failed(String)

        public var isBusy: Bool {
            switch self {
            case .installing, .removing: true
            case .idle, .failed: false
            }
        }
    }

    /// Which kind of device the downloadable list is narrowed to.
    public enum FamilyFilter: String, CaseIterable, Identifiable, Sendable {
        case all
        case general
        case tv
        case wearOS
        case automotive
        case desktop
        case xr

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .all: "All types"
            case .general: "Phones, foldables and tablets"
            case .tv: "TV"
            case .wearOS: "Wear OS"
            case .automotive: "Automotive"
            case .desktop: "Desktop"
            case .xr: "XR"
            }
        }

        func matches(_ family: SystemImage.Family) -> Bool {
            switch self {
            case .all: true
            case .general: family == .general
            case .tv: family == .tv
            case .wearOS: family == .wearOS
            case .automotive: family == .automotive
            case .desktop: family == .desktop
            case .xr: family == .xr
            }
        }
    }

    /// An image the user asked to remove, with the devices that boot from it, waiting for confirmation.
    public struct Removal: Identifiable, Equatable, Sendable {
        public let image: SystemImage
        public let devices: [VirtualDevice]
        public var id: String { image.id }
    }

    public private(set) var installed: [SystemImage] = []
    public private(set) var hasLoadedInstalled = false
    public private(set) var catalog: Catalog = .notLoaded
    public private(set) var work: Work = .idle
    /// A short confirmation after something worked ("Downloaded 2 images.").
    public private(set) var notice: String?

    public var familyFilter: FamilyFilter = .all
    /// Previews and automated-test images.
    public var showAdvanced = false
    public private(set) var selection: Set<String> = []
    /// The user, never the app, agrees to Google's licence.
    public var acceptedLicense = false
    public var pendingRemoval: Removal?

    /// The devices of the app, to warn before removing an image they use. Set by `AppModel`.
    public var devices: [VirtualDevice] = []
    public var locations: Locations {
        didSet {
            guard locations != oldValue else { return }
            reset()
        }
    }

    @ObservationIgnored private let service: any DeviceService

    public init(service: any DeviceService, locations: Locations = Locations()) {
        self.service = service
        self.locations = locations
    }

    // MARK: Installed

    public func loadInstalled() async {
        installed = await service.installedSystemImages(locations: locations)
        hasLoadedInstalled = true
    }

    public var installedBytes: Int64 { installed.reduce(0) { $0 + ($1.sizeBytes ?? 0) } }

    public func devices(using image: SystemImage) -> [VirtualDevice] {
        devices.filter { $0.systemImagePackage.map { samePackage($0, image.packagePath) } ?? false }
    }

    // MARK: Download

    public func loadCatalog() async {
        guard catalog != .loading, !work.isBusy else { return }
        catalog = .loading
        do {
            catalog = .loaded(try await service.availableSystemImages(locations: locations))
        } catch {
            catalog = .failed(error.localizedDescription)
        }
    }

    /// Images that can still be downloaded, narrowed by the filters, newest Android first.
    public var downloadable: [RemoteSystemImage] {
        guard case .loaded(let all) = catalog else { return [] }
        return all.filter { image in
            !image.isInstalled && familyFilter.matches(image.family) && (showAdvanced || !image.isAdvanced)
        }
    }

    /// `downloadable`, grouped by Android version in the order Google lists them.
    public var downloadableGroups: [(title: String, images: [RemoteSystemImage])] {
        var groups: [(title: String, images: [RemoteSystemImage])] = []
        for image in downloadable {
            if let index = groups.firstIndex(where: { $0.title == image.versionLabel }) {
                groups[index].images.append(image)
            } else {
                groups.append((image.versionLabel, [image]))
            }
        }
        return groups
    }

    public var selectedImages: [RemoteSystemImage] {
        guard case .loaded(let all) = catalog else { return [] }
        return all.filter { selection.contains($0.id) }
    }

    public func isSelected(_ image: RemoteSystemImage) -> Bool { selection.contains(image.id) }

    public func toggle(_ image: RemoteSystemImage) {
        if selection.contains(image.id) { selection.remove(image.id) } else { selection.insert(image.id) }
    }

    public func clearSelection() { selection = [] }

    /// Nothing is downloaded until the user has agreed to the licence.
    public var canInstall: Bool { !selection.isEmpty && acceptedLicense && !work.isBusy }

    public func install() async {
        guard canInstall else { return }
        let packages = selectedImages.map(\.packagePath).sorted()
        work = .installing(count: packages.count)
        notice = nil
        do {
            let result = try await service.installSystemImages(packages, licenseAccepted: acceptedLicense, locations: locations)
            guard result.isSuccess else {
                work = .failed(Self.tail(of: result.output, exitCode: result.exitCode))
                return
            }
            mark(packages, installed: true)
            selection = []
            work = .idle
            notice = packages.count == 1 ? "Downloaded 1 image." : "Downloaded \(packages.count) images."
            await loadInstalled()
        } catch {
            work = .failed(error.localizedDescription)
        }
    }

    // MARK: Remove

    public func requestRemoval(of image: SystemImage) {
        guard !work.isBusy else { return }
        pendingRemoval = Removal(image: image, devices: devices(using: image))
    }

    public func cancelRemoval() { pendingRemoval = nil }

    /// Removes the image the user confirmed. Devices that boot from it are listed in the confirmation, so the removal
    /// is forced; a running emulator still refuses it. Takes the removal as an argument because closing the
    /// confirmation dialog clears `pendingRemoval` before the button's task gets to run.
    public func confirmRemoval(_ removal: Removal) async {
        guard !work.isBusy else { return }
        pendingRemoval = nil
        work = .removing(removal.image.versionLabel)
        notice = nil
        do {
            let result = try await service.removeSystemImage(removal.image, force: !removal.devices.isEmpty, locations: locations)
            guard result.isSuccess else {
                work = .failed(Self.tail(of: result.output, exitCode: result.exitCode))
                return
            }
            mark([removal.image.packagePath], installed: false)
            work = .idle
            notice = "Removed \(removal.image.displayName)."
            await loadInstalled()
        } catch {
            work = .failed(error.localizedDescription)
        }
    }

    public func dismissFailure() {
        if case .failed = work { work = .idle }
    }

    /// Forgets what was loaded (the SDK folder changed) so the next look asks again.
    public func reset() {
        installed = []
        hasLoadedInstalled = false
        catalog = .notLoaded
        selection = []
        work = .idle
        notice = nil
        pendingRemoval = nil
    }

    /// For previews and screenshot tests only: shows a state without asking the service.
    public func setStateForPreview(
        installed: [SystemImage]? = nil, catalog: Catalog? = nil, work: Work? = nil, notice: String? = nil,
        selection: Set<String>? = nil, acceptedLicense: Bool? = nil
    ) {
        if let installed {
            self.installed = installed
            hasLoadedInstalled = true
        }
        if let catalog { self.catalog = catalog }
        if let work { self.work = work }
        if let notice { self.notice = notice }
        if let selection { self.selection = selection }
        if let acceptedLicense { self.acceptedLicense = acceptedLicense }
    }

    // MARK: Private

    private func mark(_ packages: [String], installed: Bool) {
        guard case .loaded(let all) = catalog else { return }
        catalog = .loaded(
            all.map { image in
                packages.contains { samePackage($0, image.packagePath) } ? image.settingInstalled(installed) : image
            })
    }

    private static func tail(of output: String, exitCode: Int32, lines: Int = 12) -> String {
        let kept = output.split(separator: "\n", omittingEmptySubsequences: false).suffix(lines).joined(separator: "\n")
        let trimmed = kept.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "The command failed with exit code \(exitCode)." : trimmed
    }
}
