import Foundation

@testable import AVDStudioUI

/// Returns whatever the test sets, and counts how often it was asked.
final class StubReleaseSource: ReleaseSource, @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<AppRelease?, Error>
    private var calls = 0

    init(_ result: Result<AppRelease?, Error> = .success(nil)) { self.result = result }

    var callCount: Int { lock.withLock { calls } }
    func set(_ newResult: Result<AppRelease?, Error>) { lock.withLock { result = newResult } }

    func latestRelease() async throws -> AppRelease? {
        let current = lock.withLock { () -> Result<AppRelease?, Error> in
            calls += 1
            return result
        }
        return try current.get()
    }
}

/// Canned HTTP: `responses` for `data(for:)`, and a scripted `download`.
final class StubHTTPClient: HTTPClient, @unchecked Sendable {
    enum DownloadBehavior: Sendable {
        case succeed(sha256: String)
        case fail(UpdateError)
        /// Reports `progress`, then waits until the surrounding task is cancelled.
        case hang(progress: Double)
    }

    private let lock = NSLock()
    private var responses: [URL: (Int, Data)] = [:]
    private var requests: [URLRequest] = []
    var download: DownloadBehavior = .succeed(sha256: String(repeating: "a", count: 64))

    func respond(to url: URL, status: Int = 200, body: String) {
        lock.withLock { responses[url] = (status, Data(body.utf8)) }
    }

    var recordedRequests: [URLRequest] { lock.withLock { requests } }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (status, body) = lock.withLock { () -> (Int, Data) in
            requests.append(request)
            return responses[request.url!] ?? (404, Data())
        }
        return (body, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }

    func download(_ url: URL, to destination: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> String {
        switch download {
        case .succeed(let sha256):
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("installer".utf8).write(to: destination)
            progress(1)
            return sha256
        case .fail(let error):
            throw error
        case .hang(let value):
            progress(value)
            try await Task.sleep(for: .seconds(30))
            return ""
        }
    }
}

actor RecordingNotifier: UpdateNotifier {
    private(set) var notified: [AppVersion] = []

    func notifyUpdateAvailable(current: AppVersion, latest: AppVersion) async {
        notified.append(latest)
    }
}

final class RecordingOpener: FileOpening, @unchecked Sendable {
    private(set) var opened: [URL] = []
    private(set) var revealed: [URL] = []

    @MainActor func open(_ url: URL) { opened.append(url) }
    @MainActor func reveal(_ url: URL) { revealed.append(url) }
}

func release(
    _ version: String,
    notes: String = "",
    installer: Bool = true,
    checksum: Bool = true
) -> AppRelease {
    let base = "https://example.com/dl/\(version)/"
    return AppRelease(
        version: AppVersion(version)!,
        notes: notes,
        pageURL: URL(string: "https://example.com/releases/\(version)")!,
        asset: installer
            ? AppRelease.Asset(
                name: "AVD-Studio-\(version).dmg",
                url: URL(string: base + "AVD-Studio-\(version).dmg")!,
                size: 1_000,
                checksumURL: checksum ? URL(string: base + "AVD-Studio-\(version).dmg.sha256")! : nil
            )
            : nil
    )
}

/// Polls until `condition` holds (or a second passes) so tests can wait for work started in a `Task`.
@MainActor
func eventually(_ condition: @MainActor () -> Bool) async -> Bool {
    for _ in 0..<200 {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return condition()
}

/// A scripted `UpdateInstaller` that records what the model asked of it.
final class FakeInstaller: UpdateInstaller, @unchecked Sendable {
    private let lock = NSLock()
    private var homebrew = false
    private var brewError: InstallError?
    private var versionAfterBrew: AppVersion?
    private var installError: InstallError?
    private var relaunchError: InstallError?
    private var brewCalls = 0
    private var installCalls: [(file: URL, version: AppVersion, app: URL)] = []
    private var relaunchCalls: [URL] = []

    init(homebrew: Bool = false) { self.homebrew = homebrew }

    /// What `installedVersion(at:)` reports after Homebrew ran (nil = unreadable).
    func setVersionAfterBrew(_ version: AppVersion?) { lock.withLock { versionAfterBrew = version } }
    func failBrew(_ error: InstallError) { lock.withLock { brewError = error } }
    func failInstall(_ error: InstallError) { lock.withLock { installError = error } }
    func failRelaunch(_ error: InstallError) { lock.withLock { relaunchError = error } }

    var brewUpgrades: Int { lock.withLock { brewCalls } }
    var installs: [(file: URL, version: AppVersion, app: URL)] { lock.withLock { installCalls } }
    var relaunches: [URL] { lock.withLock { relaunchCalls } }

    func canUseHomebrew() async -> Bool { lock.withLock { homebrew } }

    func upgradeWithHomebrew() async throws {
        let error = lock.withLock { () -> InstallError? in
            brewCalls += 1
            return brewError
        }
        if let error { throw error }
    }

    func install(diskImage: URL, version: AppVersion, over appURL: URL) async throws {
        let error = lock.withLock { () -> InstallError? in
            installCalls.append((diskImage, version, appURL))
            return installError
        }
        if let error { throw error }
    }

    func installedVersion(at appURL: URL) -> AppVersion? { lock.withLock { versionAfterBrew } }

    func relaunch(appAt appURL: URL) async throws {
        let error = lock.withLock { () -> InstallError? in
            relaunchCalls.append(appURL)
            return relaunchError
        }
        if let error { throw error }
    }
}

/// Counts how often the model asked the app to quit.
final class QuitCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var quits: Int { lock.withLock { count } }
    @MainActor func quit() { lock.withLock { count += 1 } }
}
