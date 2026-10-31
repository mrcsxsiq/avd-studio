import AppKit
import Foundation
import Observation

public enum UpdateState: Equatable, Sendable {
    case idle
    case checking
    case upToDate(checkedAt: Date)
    /// The release feed is reachable but nothing has been published yet.
    case noReleases(checkedAt: Date)
    case available(AppRelease)
    case downloading(AppRelease, progress: Double)
    /// `verified` is true when the file's SHA-256 matched the checksum published with the release.
    case downloaded(AppRelease, file: URL, verified: Bool)
    case failed(String)
}

/// Tells the user, outside the app, that a new version exists.
public protocol UpdateNotifier: Sendable {
    func notifyUpdateAvailable(current: AppVersion, latest: AppVersion) async
}

/// Opens things on the user's behalf (injected so tests never open real windows).
public protocol FileOpening: Sendable {
    @MainActor func open(_ url: URL)
    @MainActor func reveal(_ url: URL)
}

public struct WorkspaceFileOpener: FileOpening {
    public init() {}

    @MainActor public func open(_ url: URL) { NSWorkspace.shared.open(url) }
    @MainActor public func reveal(_ url: URL) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
}

/// Checks for new versions, downloads them and tells the user. Independent from `AppModel` on purpose.
@MainActor
@Observable
public final class UpdateModel {
    public let currentVersion: AppVersion
    public let installSource: InstallSource
    public private(set) var state: UpdateState = .idle
    public private(set) var lastChecked: Date?

    /// Whether to look for updates on launch and every few hours, and to notify when one appears.
    public var automaticChecks: Bool {
        didSet {
            defaults.set(automaticChecks, forKey: Keys.automatic)
            // Turning it on should not leave the user waiting for the next scheduled check.
            if automaticChecks && !oldValue { Task { await checkForUpdates(userInitiated: false) } }
        }
    }

    @ObservationIgnored private let source: any ReleaseSource
    @ObservationIgnored private let client: any HTTPClient
    @ObservationIgnored private let notifier: (any UpdateNotifier)?
    @ObservationIgnored private let opener: any FileOpening
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let downloadsDirectory: URL
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var checkLoop: Task<Void, Never>?
    @ObservationIgnored private var downloadTask: Task<Void, Never>?

    public init(
        currentVersion: AppVersion,
        source: any ReleaseSource,
        client: any HTTPClient = URLSessionHTTPClient(),
        notifier: (any UpdateNotifier)? = nil,
        opener: any FileOpening = WorkspaceFileOpener(),
        installSource: InstallSource = .detect(),
        state: UpdateState = .idle,
        defaults: UserDefaults = .standard,
        downloadsDirectory: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.currentVersion = currentVersion
        self.source = source
        self.client = client
        self.notifier = notifier
        self.opener = opener
        self.installSource = installSource
        self.defaults = defaults
        self.downloadsDirectory = downloadsDirectory
        self.now = now
        self.automaticChecks = defaults.object(forKey: Keys.automatic) as? Bool ?? true
        self.state = state
    }

    /// The version found by the last check, when it is newer than the running one.
    public var availableRelease: AppRelease? {
        switch state {
        case .available(let release), .downloading(let release, _), .downloaded(let release, _, _): release
        default: nil
        }
    }

    public var hasUpdate: Bool { availableRelease != nil }

    // MARK: Checking

    /// - Parameter userInitiated: when false (background check) errors stay silent and a new version
    ///   triggers a system notification, once per version.
    public func checkForUpdates(userInitiated: Bool = true) async {
        if case .checking = state { return }
        if case .downloading = state { return }
        let previous = state
        state = .checking
        do {
            let checkedAt = now()
            lastChecked = checkedAt
            guard let latest = try await source.latestRelease() else {
                state = .noReleases(checkedAt: checkedAt)
                return
            }
            if latest.version > currentVersion {
                state = .available(latest)
                if !userInitiated { await notifyOnce(latest) }
            } else {
                state = .upToDate(checkedAt: checkedAt)
            }
        } catch {
            state = userInitiated ? .failed(error.localizedDescription) : previous
        }
    }

    /// Checks right after launch and then every `interval` (while `automaticChecks` is on).
    public func startAutomaticChecks(firstDelay: Duration = .seconds(5), interval: Duration = .seconds(6 * 3600)) {
        guard checkLoop == nil else { return }
        checkLoop = Task { [weak self] in
            try? await Task.sleep(for: firstDelay)
            while !Task.isCancelled {
                if let self, self.automaticChecks { await self.checkForUpdates(userInitiated: false) }
                try? await Task.sleep(for: interval)
            }
        }
    }

    public func stopAutomaticChecks() {
        checkLoop?.cancel()
        checkLoop = nil
    }

    // MARK: Downloading

    /// Starts the download in the background so it can be cancelled.
    public func startDownload() {
        downloadTask = Task { [weak self] in await self?.downloadLatest() }
    }

    public func cancelDownload() {
        downloadTask?.cancel()
    }

    public func downloadLatest() async {
        guard case .available(let release) = state else { return }
        guard let asset = release.asset else {
            state = .failed(UpdateError.noInstaller.localizedDescription)
            return
        }
        state = .downloading(release, progress: 0)
        let destination = downloadsDirectory.appendingPathComponent(asset.name)
        do {
            try? FileManager.default.removeItem(at: destination)
            let actual = try await client.download(asset.url, to: destination) { [weak self] fraction in
                Task { @MainActor in self?.report(progress: fraction, for: release) }
            }
            var verified = false
            if let checksumURL = asset.checksumURL {
                guard try await expectedChecksum(at: checksumURL) == actual else {
                    try? FileManager.default.removeItem(at: destination)
                    state = .failed(UpdateError.checksumMismatch.localizedDescription)
                    return
                }
                verified = true
            }
            state = .downloaded(release, file: destination, verified: verified)
        } catch is CancellationError {
            state = .available(release)
        } catch let error as URLError where error.code == .cancelled {
            state = .available(release)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    public func openInstaller() {
        if case .downloaded(_, let file, _) = state { opener.open(file) }
    }

    public func revealDownload() {
        if case .downloaded(_, let file, _) = state { opener.reveal(file) }
    }

    public func openReleasePage() {
        if let release = availableRelease { opener.open(release.pageURL) }
    }

    /// Goes back to the "update available" screen, e.g. after dismissing an error.
    public func dismissError() {
        if case .failed = state { state = .idle }
    }

    // MARK: Private

    private func report(progress: Double, for release: AppRelease) {
        if case .downloading(let current, _) = state, current == release {
            state = .downloading(release, progress: min(max(progress, 0), 1))
        }
    }

    private func notifyOnce(_ release: AppRelease) async {
        let version = release.version.description
        guard defaults.string(forKey: Keys.lastNotified) != version else { return }
        defaults.set(version, forKey: Keys.lastNotified)
        await notifier?.notifyUpdateAvailable(current: currentVersion, latest: release.version)
    }

    private func expectedChecksum(at url: URL) async throws -> String {
        let (data, response) = try await client.data(for: URLRequest(url: url))
        guard (200..<300).contains(response.statusCode), let text = String(data: data, encoding: .utf8) else {
            throw UpdateError.unreadable
        }
        // `shasum` writes "<hex>  <file name>"; a bare hash is fine too.
        guard let hash = text.split(whereSeparator: \.isWhitespace).first?.lowercased(), hash.count == 64 else {
            throw UpdateError.unreadable
        }
        return hash
    }

    private enum Keys {
        static let automatic = "updates.automaticChecks"
        static let lastNotified = "updates.lastNotifiedVersion"
    }
}
