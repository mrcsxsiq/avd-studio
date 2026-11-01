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
    /// Putting the new version in place: Homebrew is upgrading it, or the downloaded app is replacing this one.
    case installing(AppRelease, InstallPhase)
    /// The new version is in place and the app is about to reopen itself.
    case installed(AppRelease)
    /// The install did not work. `file` is the downloaded installer when there is one, for installing it by hand.
    case installFailed(AppRelease, reason: String, file: URL?)
    case failed(String)
}

public enum InstallPhase: Equatable, Sendable {
    case homebrew
    case replacing
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
    @ObservationIgnored private let installer: (any UpdateInstaller)?
    @ObservationIgnored private let appURL: URL
    @ObservationIgnored private let quit: @MainActor () -> Void
    @ObservationIgnored private let relaunchDelay: Duration
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let downloadsDirectory: URL
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var checkLoop: Task<Void, Never>?
    @ObservationIgnored private var downloadTask: Task<Void, Never>?
    @ObservationIgnored private var installTask: Task<Void, Never>?

    public init(
        currentVersion: AppVersion,
        source: any ReleaseSource,
        client: any HTTPClient = URLSessionHTTPClient(),
        notifier: (any UpdateNotifier)? = nil,
        opener: any FileOpening = WorkspaceFileOpener(),
        installer: (any UpdateInstaller)? = nil,
        appURL: URL = Bundle.main.bundleURL,
        quit: @escaping @MainActor () -> Void = { NSApp.terminate(nil) },
        relaunchDelay: Duration = .seconds(1),
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
        self.installer = installer
        self.appURL = appURL
        self.quit = quit
        self.relaunchDelay = relaunchDelay
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
        case .available(let release), .downloading(let release, _), .downloaded(let release, _, _), .installing(let release, _),
            .installed(let release), .installFailed(let release, _, _):
            release
        default: nil
        }
    }

    public var hasUpdate: Bool { availableRelease != nil }

    /// True when "Install" can put the new version in place by itself, rather than only downloading it.
    public var canInstallAutomatically: Bool { installer != nil }

    // MARK: Checking

    /// - Parameter userInitiated: when false (background check) errors stay silent and a new version
    ///   triggers a system notification, once per version.
    public func checkForUpdates(userInitiated: Bool = true) async {
        if case .checking = state { return }
        switch state {
        case .downloading, .installing, .installed: return
        default: break
        }
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
        guard let downloaded = await download(release) else { return }
        state = .downloaded(release, file: downloaded.file, verified: downloaded.verified)
    }

    /// Downloads the installer next to the user's other downloads and checks it against the published checksum.
    /// Sets the state itself when it fails or is cancelled and returns nil.
    private func download(_ release: AppRelease) async -> (file: URL, verified: Bool)? {
        guard let asset = release.asset else {
            state = .failed(UpdateError.noInstaller.localizedDescription)
            return nil
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
                    return nil
                }
                verified = true
            }
            return (destination, verified)
        } catch is CancellationError {
            state = .available(release)
        } catch let error as URLError where error.code == .cancelled {
            state = .available(release)
        } catch {
            state = .failed(error.localizedDescription)
        }
        return nil
    }

    // MARK: Installing

    /// Puts the new version in place and reopens the app: through Homebrew when it manages this app, otherwise by
    /// downloading from GitHub and replacing the app. Without an installer (previews) it only downloads.
    public func install() {
        installTask = Task { [weak self] in await self?.performInstall() }
    }

    public func performInstall() async {
        let release: AppRelease
        switch state {
        case .available(let found), .installFailed(let found, _, _), .downloaded(let found, _, _): release = found
        default: return
        }
        guard let installer else {
            if case .available = state { await downloadLatest() }
            return
        }
        if await installer.canUseHomebrew() {
            await installWithHomebrew(release, using: installer)
        } else {
            await installFromGitHub(release, using: installer)
        }
    }

    private func installWithHomebrew(_ release: AppRelease, using installer: any UpdateInstaller) async {
        state = .installing(release, .homebrew)
        do {
            try await installer.upgradeWithHomebrew()
        } catch {
            state = .installFailed(release, reason: describe(error), file: nil)
            return
        }
        // Homebrew's tap is updated a little after a release is published; it can finish "successfully" on the old build.
        guard let installed = installer.installedVersion(at: appURL), installed >= release.version else {
            state = .installFailed(release, reason: InstallError.homebrewBehind(release.version).localizedDescription, file: nil)
            return
        }
        await reopen(after: release, using: installer)
    }

    private func installFromGitHub(_ release: AppRelease, using installer: any UpdateInstaller) async {
        guard let downloaded = await download(release) else { return }
        guard downloaded.verified else {
            state = .installFailed(release, reason: InstallError.noChecksum.localizedDescription, file: downloaded.file)
            return
        }
        state = .installing(release, .replacing)
        do {
            try await installer.install(diskImage: downloaded.file, version: release.version, over: appURL)
        } catch {
            state = .installFailed(release, reason: describe(error), file: downloaded.file)
            return
        }
        try? FileManager.default.removeItem(at: downloaded.file)
        await reopen(after: release, using: installer)
    }

    private func reopen(after release: AppRelease, using installer: any UpdateInstaller) async {
        state = .installed(release)
        // A moment to read "Updated", then the new copy opens and this one quits.
        try? await Task.sleep(for: relaunchDelay)
        do {
            try await installer.relaunch(appAt: appURL)
            quit()
        } catch {
            state = .installFailed(release, reason: describe(InstallError.relaunchFailed(describe(error))), file: nil)
        }
    }

    private func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    public func openInstaller() {
        if let file = downloadedFile { opener.open(file) }
    }

    public func revealDownload() {
        if let file = downloadedFile { opener.reveal(file) }
    }

    /// The installer on disk, when there is one to open by hand.
    public var downloadedFile: URL? {
        switch state {
        case .downloaded(_, let file, _): file
        case .installFailed(_, _, let file): file
        default: nil
        }
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
