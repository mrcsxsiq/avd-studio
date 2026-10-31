import Foundation
import Testing

@testable import AVDStudioUI

@Suite("UpdateModel")
@MainActor
struct UpdateModelTests {
    private let current = AppVersion("0.1.0")!
    private let checkedAt = Date(timeIntervalSince1970: 1_800_000_000)

    private struct Harness {
        let model: UpdateModel
        let source: StubReleaseSource
        let client: StubHTTPClient
        let notifier: RecordingNotifier
        let opener: RecordingOpener
        let defaults: UserDefaults
        let downloads: URL
    }

    private func makeHarness(
        _ result: Result<AppRelease?, Error> = .success(nil),
        installSource: InstallSource = .manual,
        defaults: UserDefaults = UserDefaults(suiteName: "avdstudio.updates.\(UUID())")!
    ) -> Harness {
        let source = StubReleaseSource(result)
        let client = StubHTTPClient()
        let notifier = RecordingNotifier()
        let opener = RecordingOpener()
        let downloads = FileManager.default.temporaryDirectory.appendingPathComponent("avdstudio-dl-\(UUID().uuidString)")
        let at = checkedAt
        let model = UpdateModel(
            currentVersion: current,
            source: source,
            client: client,
            notifier: notifier,
            opener: opener,
            installSource: installSource,
            defaults: defaults,
            downloadsDirectory: downloads,
            now: { at }
        )
        return Harness(
            model: model, source: source, client: client, notifier: notifier, opener: opener, defaults: defaults, downloads: downloads)
    }

    // MARK: Checking

    @Test func saysYouAreUpToDateWhenTheLatestReleaseIsTheRunningVersion() async {
        let h = makeHarness(.success(release("0.1.0")))
        await h.model.checkForUpdates()

        #expect(h.model.state == .upToDate(checkedAt: checkedAt))
        #expect(h.model.hasUpdate == false)
        #expect(h.model.lastChecked == checkedAt)
    }

    @Test func aDevelopmentBuildNewerThanTheLatestReleaseIsStillUpToDate() async {
        let h = makeHarness(.success(release("0.0.9")))
        await h.model.checkForUpdates()

        #expect(h.model.state == .upToDate(checkedAt: checkedAt))
    }

    @Test func offersANewerVersionWithBothVersionsAvailableToShow() async {
        let newer = release("0.2.0", notes: "Faster")
        let h = makeHarness(.success(newer))
        await h.model.checkForUpdates()

        #expect(h.model.state == .available(newer))
        #expect(h.model.availableRelease?.version == AppVersion("0.2.0"))
        #expect(h.model.currentVersion == current)
        #expect(h.model.hasUpdate)
    }

    @Test func a0_10VersionIsNewerThan0_9() async {
        let h = makeHarness(.success(release("0.10.0")))
        let model = UpdateModel(currentVersion: AppVersion("0.9.0")!, source: h.source, client: h.client, defaults: h.defaults)
        await model.checkForUpdates()

        #expect(model.hasUpdate)
    }

    @Test func reportsWhenNothingHasBeenPublishedYet() async {
        let h = makeHarness(.success(nil))
        await h.model.checkForUpdates()

        #expect(h.model.state == .noReleases(checkedAt: checkedAt))
    }

    @Test func aManualCheckShowsTheErrorButABackgroundCheckStaysQuiet() async {
        let h = makeHarness(.failure(UpdateError.rateLimited))

        await h.model.checkForUpdates(userInitiated: false)
        #expect(h.model.state == .idle)

        await h.model.checkForUpdates(userInitiated: true)
        #expect(h.model.state == .failed(UpdateError.rateLimited.localizedDescription))

        h.model.dismissError()
        #expect(h.model.state == .idle)
    }

    // MARK: Notifications

    @Test func aManualCheckNeverNotifies() async {
        let h = makeHarness(.success(release("0.2.0")))
        await h.model.checkForUpdates(userInitiated: true)

        #expect(await h.notifier.notified.isEmpty)
    }

    @Test func aBackgroundCheckNotifiesOncePerVersion() async {
        let h = makeHarness(.success(release("0.2.0")))

        await h.model.checkForUpdates(userInitiated: false)
        await h.model.checkForUpdates(userInitiated: false)
        await h.model.checkForUpdates(userInitiated: false)
        #expect(await h.notifier.notified == [AppVersion("0.2.0")!])

        h.source.set(.success(release("0.3.0")))
        await h.model.checkForUpdates(userInitiated: false)
        #expect(await h.notifier.notified == [AppVersion("0.2.0")!, AppVersion("0.3.0")!])
    }

    @Test func theNotifiedVersionSurvivesARelaunch() async {
        let defaults = UserDefaults(suiteName: "avdstudio.updates.\(UUID())")!
        await makeHarness(.success(release("0.2.0")), defaults: defaults).model.checkForUpdates(userInitiated: false)

        let relaunched = makeHarness(.success(release("0.2.0")), defaults: defaults)
        await relaunched.model.checkForUpdates(userInitiated: false)

        #expect(await relaunched.notifier.notified.isEmpty)
    }

    @Test func nothingIsNotifiedWhenAlreadyUpToDate() async {
        let h = makeHarness(.success(release("0.1.0")))
        await h.model.checkForUpdates(userInitiated: false)

        #expect(await h.notifier.notified.isEmpty)
    }

    // MARK: Automatic checks setting

    @Test func automaticChecksAreOnByDefaultAndTheChoiceIsRemembered() {
        let defaults = UserDefaults(suiteName: "avdstudio.updates.\(UUID())")!
        let first = makeHarness(defaults: defaults)
        #expect(first.model.automaticChecks)

        first.model.automaticChecks = false
        let relaunched = makeHarness(defaults: defaults)
        #expect(relaunched.model.automaticChecks == false)
    }

    @Test func turningTheSettingOffStopsBackgroundChecksAndTurningItOnChecksRightAway() async {
        let h = makeHarness(.success(release("0.2.0")))
        h.model.automaticChecks = false
        h.model.startAutomaticChecks(firstDelay: .milliseconds(5), interval: .milliseconds(10))

        try? await Task.sleep(for: .milliseconds(120))
        #expect(h.source.callCount == 0, "no network traffic while automatic checks are off")
        #expect(await h.notifier.notified.isEmpty)

        h.model.automaticChecks = true
        #expect(await eventually { h.model.hasUpdate })
        #expect(await h.notifier.notified == [AppVersion("0.2.0")!])
        h.model.stopAutomaticChecks()
    }

    @Test func aManualCheckStillWorksWhenAutomaticChecksAreOff() async {
        let h = makeHarness(.success(release("0.2.0")))
        h.model.automaticChecks = false

        await h.model.checkForUpdates(userInitiated: true)

        #expect(h.model.hasUpdate)
        #expect(await h.notifier.notified.isEmpty)
    }

    // MARK: Downloading

    private func available(_ h: Harness, _ version: String = "0.2.0", checksum: Bool = true, installer: Bool = true) async -> AppRelease {
        let r = release(version, installer: installer, checksum: checksum)
        h.source.set(.success(r))
        await h.model.checkForUpdates()
        return r
    }

    @Test func downloadsAndVerifiesTheChecksum() async throws {
        let h = makeHarness()
        let r = await available(h)
        let hash = String(repeating: "ab", count: 32)
        h.client.download = .succeed(sha256: hash)
        h.client.respond(to: r.asset!.checksumURL!, body: "\(hash.uppercased())  AVD-Studio-0.2.0.dmg\n")

        await h.model.downloadLatest()

        let file = h.downloads.appendingPathComponent("AVD-Studio-0.2.0.dmg")
        #expect(h.model.state == .downloaded(r, file: file, verified: true))
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test func aCorruptedDownloadIsRejectedAndDeleted() async {
        let h = makeHarness()
        let r = await available(h)
        h.client.download = .succeed(sha256: String(repeating: "a", count: 64))
        h.client.respond(to: r.asset!.checksumURL!, body: String(repeating: "b", count: 64))

        await h.model.downloadLatest()

        #expect(h.model.state == .failed(UpdateError.checksumMismatch.localizedDescription))
        #expect(!FileManager.default.fileExists(atPath: h.downloads.appendingPathComponent("AVD-Studio-0.2.0.dmg").path))
    }

    @Test func aReleaseWithoutAChecksumDownloadsButIsNotMarkedVerified() async {
        let h = makeHarness()
        _ = await available(h, checksum: false)

        await h.model.downloadLatest()

        guard case .downloaded(_, _, let verified) = h.model.state else {
            Issue.record("expected .downloaded, got \(h.model.state)")
            return
        }
        #expect(verified == false)
    }

    @Test func aReleaseWithoutAnInstallerCannotBeDownloaded() async {
        let h = makeHarness()
        _ = await available(h, installer: false)

        await h.model.downloadLatest()

        #expect(h.model.state == .failed(UpdateError.noInstaller.localizedDescription))
    }

    @Test func downloadFailuresAreReported() async {
        let h = makeHarness()
        _ = await available(h)
        h.client.download = .fail(.badResponse(503))

        await h.model.downloadLatest()

        #expect(h.model.state == .failed(UpdateError.badResponse(503).localizedDescription))
    }

    @Test func downloadingShowsProgressAndCancellingGoesBackToTheOffer() async {
        let h = makeHarness()
        let r = await available(h)
        h.client.download = .hang(progress: 0.42)

        h.model.startDownload()
        #expect(await eventually { h.model.state == .downloading(r, progress: 0.42) })

        h.model.cancelDownload()
        #expect(await eventually { h.model.state == .available(r) })
    }

    @Test func downloadLatestDoesNothingUnlessAnUpdateIsOffered() async {
        let h = makeHarness()
        await h.model.downloadLatest()

        #expect(h.model.state == .idle)
    }

    // MARK: Opening

    @Test func opensTheInstallerRevealsItAndOpensTheReleasePage() async {
        let h = makeHarness()
        let r = await available(h)
        h.model.openReleasePage()
        #expect(h.opener.opened == [r.pageURL])

        let hash = String(repeating: "c", count: 64)
        h.client.download = .succeed(sha256: hash)
        h.client.respond(to: r.asset!.checksumURL!, body: hash)
        await h.model.downloadLatest()
        h.model.openInstaller()
        h.model.revealDownload()

        let file = h.downloads.appendingPathComponent("AVD-Studio-0.2.0.dmg")
        #expect(h.opener.opened.last == file)
        #expect(h.opener.revealed == [file])
    }
}
