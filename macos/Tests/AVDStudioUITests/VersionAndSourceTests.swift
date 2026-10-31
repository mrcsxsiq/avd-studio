import Foundation
import Testing

@testable import AVDStudioUI

@Suite("AppVersion")
struct AppVersionTests {
    @Test(arguments: [
        ("1.2.3", "1.2.3"), ("v1.2.3", "1.2.3"), ("V2.0.0", "2.0.0"), ("1.2", "1.2.0"), ("7", "7.0.0"),
        ("1.2.3-beta.1", "1.2.3-beta.1"), ("1.2.3+build.5", "1.2.3"), ("1.0.0-rc.1+sha.abc", "1.0.0-rc.1"),
        ("  v0.1.0\n", "0.1.0"),
    ])
    func parsesCommonShapes(input: String, expected: String) {
        #expect(AppVersion(input)?.description == expected)
    }

    @Test(arguments: ["", "v", "x.y.z", "1.2.3.4", "1..2", "1.-2", "1.2.3-", "1.2.3-a..b", "latest", "1.2.x"])
    func rejectsNonVersions(input: String) {
        #expect(AppVersion(input) == nil)
    }

    @Test func comparesNumericallyNotAsText() {
        #expect(AppVersion("0.9.0")! < AppVersion("0.10.0")!)
        #expect(AppVersion("1.9.9")! < AppVersion("2.0.0")!)
        #expect(AppVersion("1.2.3")! < AppVersion("1.2.10")!)
    }

    @Test func followsTheSemVerPrecedenceExample() {
        // https://semver.org/#spec-item-11
        let ordered = [
            "1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-alpha.beta", "1.0.0-beta", "1.0.0-beta.2", "1.0.0-beta.11", "1.0.0-rc.1", "1.0.0",
        ]
        .map { AppVersion($0)! }
        for (earlier, later) in zip(ordered, ordered.dropFirst()) {
            #expect(earlier < later, "\(earlier) should be older than \(later)")
            #expect(!(later < earlier))
        }
    }

    @Test func buildMetadataDoesNotAffectEquality() {
        #expect(AppVersion("1.0.0+a") == AppVersion("1.0.0+b"))
        #expect(AppVersion("1.0.0")!.isPrerelease == false)
        #expect(AppVersion("1.0.0-rc.1")!.isPrerelease)
    }
}

@Suite("GitHubReleaseSource")
struct GitHubReleaseSourceTests {
    private let payload = """
        {
          "tag_name": "v0.2.0",
          "name": "AVD Studio 0.2.0",
          "body": "## What's new\\n- Faster",
          "html_url": "https://github.com/mrcsxsiq/avd-studio/releases/tag/v0.2.0",
          "draft": false,
          "prerelease": false,
          "published_at": "2026-11-20T12:30:00Z",
          "assets": [
            { "name": "avdstudio-0.2.0-macos-arm64.tar.gz", "size": 1000, "browser_download_url": "https://github.com/x/releases/download/v0.2.0/avdstudio-0.2.0-macos-arm64.tar.gz" },
            { "name": "AVD-Studio-0.2.0.dmg", "size": 48200000, "browser_download_url": "https://github.com/x/releases/download/v0.2.0/AVD-Studio-0.2.0.dmg" },
            { "name": "AVD-Studio-0.2.0.dmg.sha256", "size": 90, "browser_download_url": "https://github.com/x/releases/download/v0.2.0/AVD-Studio-0.2.0.dmg.sha256" }
          ]
        }
        """

    private func source(status: Int, body: String = "", client: StubHTTPClient = StubHTTPClient()) -> (GitHubReleaseSource, StubHTTPClient)
    {
        client.respond(to: URL(string: "https://api.github.com/repos/mrcsxsiq/avd-studio/releases/latest")!, status: status, body: body)
        return (GitHubReleaseSource(owner: "mrcsxsiq", repository: "avd-studio", client: client), client)
    }

    @Test func readsVersionNotesInstallerAndChecksum() async throws {
        let (source, client) = source(status: 200, body: payload)

        let release = try #require(try await source.latestRelease())

        #expect(release.version == AppVersion("0.2.0"))
        #expect(release.title == "AVD Studio 0.2.0")
        #expect(release.notes.contains("Faster"))
        #expect(release.publishedAt != nil)
        #expect(release.asset?.name == "AVD-Studio-0.2.0.dmg")
        #expect(release.asset?.size == 48_200_000)
        #expect(release.asset?.checksumURL?.lastPathComponent == "AVD-Studio-0.2.0.dmg.sha256")

        let request = try #require(client.recordedRequests.first)
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/vnd.github+json")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "AVD-Studio-Updater")
    }

    @Test func releasesWithoutADmgStillParseButHaveNoInstaller() throws {
        let body = payload.replacingOccurrences(of: ".dmg", with: ".zip")
        let release = try #require(try GitHubReleaseSource.parse(Data(body.utf8)))
        #expect(release.asset == nil)
    }

    @Test func draftsAndPrereleasesAreIgnored() throws {
        let draft = payload.replacingOccurrences(of: "\"draft\": false", with: "\"draft\": true")
        let pre = payload.replacingOccurrences(of: "\"prerelease\": false", with: "\"prerelease\": true")
        #expect(try GitHubReleaseSource.parse(Data(draft.utf8)) == nil)
        #expect(try GitHubReleaseSource.parse(Data(pre.utf8)) == nil)
    }

    @Test func aRepositoryWithoutReleasesIsNotAnError() async throws {
        let (source, _) = source(status: 404)
        #expect(try await source.latestRelease() == nil)
    }

    @Test func mapsHttpFailuresToReadableErrors() async {
        await #expect(throws: UpdateError.rateLimited) { try await source(status: 403).0.latestRelease() }
        await #expect(throws: UpdateError.rateLimited) { try await source(status: 429).0.latestRelease() }
        await #expect(throws: UpdateError.badResponse(500)) { try await source(status: 500).0.latestRelease() }
    }

    @Test func malformedPayloadsAreReportedAsUnreadable() async {
        await #expect(throws: UpdateError.unreadable) { try await source(status: 200, body: "<html>").0.latestRelease() }
        let badTag = payload.replacingOccurrences(of: "v0.2.0\",\n  \"name", with: "nightly\",\n  \"name")
        await #expect(throws: UpdateError.unreadable) { try await source(status: 200, body: badTag).0.latestRelease() }
    }

    @Test func transportErrorsMentionTheNetwork() async {
        struct Offline: HTTPClient {
            func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) { throw URLError(.notConnectedToInternet) }
            func download(_ url: URL, to destination: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> String { "" }
        }
        let source = GitHubReleaseSource(owner: "a", repository: "b", client: Offline())
        do {
            _ = try await source.latestRelease()
            Issue.record("expected an error")
        } catch let error as UpdateError {
            if case .network = error {} else { Issue.record("expected .network, got \(error)") }
        } catch {
            Issue.record("unexpected error \(error)")
        }
    }

    @Test func sha256MatchesTheKnownVector() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("sha-\(UUID().uuidString)")
        try Data("abc".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        #expect(try URLSessionHTTPClient.sha256(of: file) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}

@Suite("InstallSource")
struct InstallSourceTests {
    @Test func detectsACaskroomEntryInTheDefaultPrefixes() {
        #expect(InstallSource.detect(environment: [:], exists: { $0 == "/opt/homebrew/Caskroom/avd-studio" }) == .homebrew)
        #expect(InstallSource.detect(environment: [:], exists: { $0 == "/usr/local/Caskroom/avd-studio" }) == .homebrew)
    }

    @Test func honoursACustomHomebrewPrefix() {
        #expect(
            InstallSource.detect(environment: ["HOMEBREW_PREFIX": "/opt/brew"], exists: { $0 == "/opt/brew/Caskroom/avd-studio" })
                == .homebrew)
    }

    @Test func otherwiseTheAppWasInstalledByHand() {
        #expect(InstallSource.detect(environment: [:], exists: { _ in false }) == .manual)
    }
}
