import Foundation
import Testing

@testable import AVDStudioUI

@Suite("Installing an update")
@MainActor
struct UpdateInstallTests {
    private let current = AppVersion("0.2.0")!
    private let app = URL(fileURLWithPath: "/Applications/AVD Studio.app")
    private let hash = String(repeating: "a", count: 64)

    private struct Harness {
        let model: UpdateModel
        let installer: FakeInstaller
        let client: StubHTTPClient
        let opener: RecordingOpener
        let quitter: QuitCounter
        let downloads: URL
    }

    private func makeHarness(
        _ found: AppRelease? = nil, homebrew: Bool = false, installSource: InstallSource? = nil, withInstaller: Bool = true
    ) async -> Harness {
        let installer = FakeInstaller(homebrew: homebrew)
        let client = StubHTTPClient()
        let opener = RecordingOpener()
        let quitter = QuitCounter()
        let downloads = FileManager.default.temporaryDirectory.appendingPathComponent("avdstudio-install-\(UUID().uuidString)")
        let model = UpdateModel(
            currentVersion: current,
            source: StubReleaseSource(.success(found)),
            client: client,
            opener: opener,
            installer: withInstaller ? installer : nil,
            appURL: app,
            quit: { quitter.quit() },
            relaunchDelay: .zero,
            installSource: installSource ?? (homebrew ? .homebrew : .manual),
            defaults: UserDefaults(suiteName: "avdstudio.install.\(UUID())")!,
            downloadsDirectory: downloads
        )
        if found != nil { await model.checkForUpdates() }
        return Harness(model: model, installer: installer, client: client, opener: opener, quitter: quitter, downloads: downloads)
    }

    /// The release's checksum file says the download is `hash`, as the stub client reports it.
    private func publishChecksum(_ h: Harness, for release: AppRelease) {
        h.client.respond(to: release.asset!.checksumURL!, body: "\(hash)  \(release.asset!.name)")
    }

    // MARK: Homebrew

    @Test func upgradesThroughHomebrewWhenItManagesTheApp() async {
        let h = await makeHarness(release("0.3.0"), homebrew: true)
        h.installer.setVersionAfterBrew(AppVersion("0.3.0"))

        await h.model.performInstall()

        #expect(h.installer.brewUpgrades == 1)
        #expect(h.installer.relaunches == [app])
        #expect(h.quitter.quits == 1)
        #expect(h.client.recordedRequests.isEmpty, "nothing is downloaded from GitHub when Homebrew does the work")
        #expect(h.model.state == .installed(release("0.3.0")))
    }

    @Test func saysSoWhenHomebrewIsStillOnTheOldBuild() async {
        let h = await makeHarness(release("0.3.0"), homebrew: true)
        h.installer.setVersionAfterBrew(AppVersion("0.2.0"))

        await h.model.performInstall()

        guard case .installFailed(let found, let reason, let file) = h.model.state else {
            Issue.record("expected installFailed, got \(h.model.state)")
            return
        }
        #expect(found.version == AppVersion("0.3.0"))
        #expect(reason.contains("does not have version 0.3.0"))
        #expect(file == nil)
        #expect(h.installer.relaunches.isEmpty)
        #expect(h.quitter.quits == 0, "the old version keeps running")
    }

    @Test func showsWhatHomebrewSaidWhenItFails() async {
        let h = await makeHarness(release("0.3.0"), homebrew: true)
        h.installer.failBrew(.homebrewFailed("Error: cask not found"))

        await h.model.performInstall()

        guard case .installFailed(_, let reason, _) = h.model.state else {
            Issue.record("expected installFailed, got \(h.model.state)")
            return
        }
        #expect(reason.contains("Error: cask not found"))
        #expect(h.quitter.quits == 0)
    }

    @Test func anUnreadableInstalledVersionCountsAsNotUpdated() async {
        let h = await makeHarness(release("0.3.0"), homebrew: true)
        h.installer.setVersionAfterBrew(nil)

        await h.model.performInstall()

        #expect(h.model.state != .installed(release("0.3.0")))
        #expect(h.quitter.quits == 0)
    }

    // MARK: GitHub

    @Test func withoutHomebrewItDownloadsChecksAndInstallsTheNewApp() async {
        let new = release("0.3.0")
        let h = await makeHarness(new)
        publishChecksum(h, for: new)

        await h.model.performInstall()

        #expect(h.installer.brewUpgrades == 0)
        let install = h.installer.installs.first
        #expect(h.installer.installs.count == 1)
        #expect(install?.file.lastPathComponent == "AVD-Studio-0.3.0.dmg")
        #expect(install?.version == AppVersion("0.3.0"))
        #expect(install?.app == app)
        #expect(h.installer.relaunches == [app])
        #expect(h.quitter.quits == 1)
        #expect(h.model.state == .installed(new))
        #expect(!FileManager.default.fileExists(atPath: install!.file.path), "the installer is cleaned up once installed")
    }

    @Test func aCorruptedDownloadIsNeverInstalled() async {
        let new = release("0.3.0")
        let h = await makeHarness(new)
        h.client.respond(to: new.asset!.checksumURL!, body: String(repeating: "b", count: 64))

        await h.model.performInstall()

        #expect(h.installer.installs.isEmpty)
        #expect(h.model.state == .failed(UpdateError.checksumMismatch.localizedDescription))
        #expect(h.quitter.quits == 0)
    }

    @Test func aReleaseWithoutAChecksumIsNotInstalledOnItsOwn() async {
        let new = release("0.3.0", checksum: false)
        let h = await makeHarness(new)

        await h.model.performInstall()

        #expect(h.installer.installs.isEmpty)
        guard case .installFailed(_, let reason, let file) = h.model.state else {
            Issue.record("expected installFailed, got \(h.model.state)")
            return
        }
        #expect(reason.contains("without a checksum"))
        #expect(file != nil, "the file stays so the user can open it by hand")
    }

    @Test func whenTheAppCannotReplaceItselfTheInstallerStaysForTheUser() async {
        let new = release("0.3.0")
        let h = await makeHarness(new)
        publishChecksum(h, for: new)
        h.installer.failInstall(.notWritable("/Applications"))

        await h.model.performInstall()

        guard case .installFailed(_, let reason, let file) = h.model.state else {
            Issue.record("expected installFailed, got \(h.model.state)")
            return
        }
        #expect(reason.contains("/Applications"))
        let installer = try? #require(file)
        #expect(installer?.lastPathComponent == "AVD-Studio-0.3.0.dmg")
        #expect(h.model.downloadedFile == installer)
        h.model.openInstaller()
        h.model.revealDownload()
        #expect(h.opener.opened == [installer].compactMap { $0 })
        #expect(h.opener.revealed == [installer].compactMap { $0 })
        #expect(h.quitter.quits == 0)
    }

    @Test func aWrongOrBrokenAppInTheInstallerIsReported() async {
        let new = release("0.3.0")
        let h = await makeHarness(new)
        publishChecksum(h, for: new)
        h.installer.failInstall(.wrongApp("it is version 0.2.5"))

        await h.model.performInstall()

        guard case .installFailed(_, let reason, _) = h.model.state else {
            Issue.record("expected installFailed, got \(h.model.state)")
            return
        }
        #expect(reason.contains("0.2.5"))
    }

    // MARK: After installing

    @Test func ifTheAppCannotReopenItselfItSaysTheUpdateIsInstalled() async {
        let new = release("0.3.0")
        let h = await makeHarness(new)
        publishChecksum(h, for: new)
        h.installer.failRelaunch(.relaunchFailed("no permission"))

        await h.model.performInstall()

        guard case .installFailed(_, let reason, _) = h.model.state else {
            Issue.record("expected installFailed, got \(h.model.state)")
            return
        }
        #expect(reason.contains("The update is installed"))
        #expect(h.quitter.quits == 0, "never quit when the new copy did not open")
    }

    @Test func tryAgainInstallsAfterAFailure() async {
        let new = release("0.3.0")
        let h = await makeHarness(new)
        publishChecksum(h, for: new)
        h.installer.failInstall(.notWritable("/Applications"))
        await h.model.performInstall()
        #expect(h.installer.relaunches.isEmpty)

        h.installer.failInstall(.diskImage("busy"))  // still failing: the attempt is repeated, not remembered
        await h.model.performInstall()

        #expect(h.installer.installs.count == 2, "each try runs the whole install again")
    }

    // MARK: Guards

    @Test func withoutAnInstallerItOnlyDownloads() async {
        let new = release("0.3.0")
        let h = await makeHarness(new, withInstaller: false)
        publishChecksum(h, for: new)

        await h.model.performInstall()

        guard case .downloaded(let found, _, let verified) = h.model.state else {
            Issue.record("expected downloaded, got \(h.model.state)")
            return
        }
        #expect(found == new && verified)
        #expect(!h.model.canInstallAutomatically)
    }

    @Test func installDoesNothingUntilAnUpdateIsAvailable() async {
        let h = await makeHarness(nil)

        await h.model.performInstall()

        #expect(h.model.state == .idle)
        #expect(h.installer.brewUpgrades == 0 && h.installer.installs.isEmpty)
    }

    @Test func aCheckDoesNotInterruptAnInstall() async {
        let new = release("0.3.0")
        let h = await makeHarness(new, homebrew: true)
        h.installer.setVersionAfterBrew(AppVersion("0.3.0"))
        await h.model.performInstall()
        #expect(h.model.state == .installed(new))

        await h.model.checkForUpdates()

        #expect(h.model.state == .installed(new), "once installed the state is kept until the app reopens")
    }

    @Test func theReleaseStaysAvailableWhileInstallingOrAfterAFailure() async {
        let new = release("0.3.0")
        let h = await makeHarness(new, homebrew: true)
        h.installer.failBrew(.homebrewFailed("nope"))

        await h.model.performInstall()

        #expect(h.model.availableRelease == new)
        #expect(h.model.hasUpdate)
    }

    @Test func theBrewCommandWeShowIsFullyQualified() {
        #expect(InstallSource.brewUpgradeCommand == "brew upgrade --cask mrcsxsiq/avd-studio/avd-studio")
    }
}
