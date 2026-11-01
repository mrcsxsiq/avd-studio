import AVDStudioCore
import AVDStudioUI
import Foundation
import Testing

@testable import AVDStudioKit

/// Runs the real installer against real disk images and a fake Homebrew, inside a throw-away folder.
@Suite("SystemUpdateInstaller", .serialized)
struct SystemUpdateInstallerTests {
    private let home: URL
    private let appID = "dev.marcos.avdstudio"

    init() throws {
        home = FileManager.default.temporaryDirectory.appendingPathComponent("avdstudio-installer-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }

    private var applications: URL { home.appendingPathComponent("Applications") }
    private var installedApp: URL { applications.appendingPathComponent("AVD Studio.app") }
    private var brewPrefix: URL { home.appendingPathComponent("homebrew") }
    private var brewLog: URL { home.appendingPathComponent("brew.log") }

    private func makeInstaller() -> SystemUpdateInstaller {
        SystemUpdateInstaller(
            environment: StaticEnvironment(
                variables: ["PATH": "/usr/bin:/bin", "HOMEBREW_PREFIX": brewPrefix.path], homeDirectory: home.path, systemRoot: home.path))
    }

    // MARK: Building real apps and disk images

    @discardableResult
    private func run(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else { throw TestError("\(executable) \(arguments.joined(separator: " ")): \(text)") }
        return text
    }

    private struct TestError: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }

    /// A minimal but real app bundle, optionally signed ad hoc like a release build.
    private func makeApp(at url: URL, id: String? = nil, version: String, signed: Bool = true) throws {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: url)
        try fileManager.createDirectory(at: url.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)
        let executable = url.appendingPathComponent("Contents/MacOS/AVDStudio")
        try "#!/bin/sh\nexit 0\n".write(to: executable, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let info: [String: Any] = [
            "CFBundleIdentifier": id ?? appID, "CFBundleShortVersionString": version, "CFBundleVersion": "1",
            "CFBundleExecutable": "AVDStudio", "CFBundlePackageType": "APPL", "CFBundleName": "AVD Studio",
        ]
        try (info as NSDictionary).write(to: url.appendingPathComponent("Contents/Info.plist"))
        if signed { try run("/usr/bin/codesign", ["--force", "--sign", "-", url.path]) }
    }

    /// A disk image holding `AVD Studio.app`, the way our release script builds it.
    private func makeDiskImage(version: String, id: String? = nil, signed: Bool = true) throws -> URL {
        let source = home.appendingPathComponent("dmg-source-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try makeApp(at: source.appendingPathComponent("AVD Studio.app"), id: id, version: version, signed: signed)
        return try pack(source)
    }

    private func pack(_ source: URL) throws -> URL {
        let image = home.appendingPathComponent("AVD-Studio-\(UUID().uuidString).dmg")
        try run(
            "/usr/bin/hdiutil",
            ["create", "-quiet", "-volname", "AVD Studio", "-srcfolder", source.path, "-format", "UDZO", "-ov", image.path])
        return image
    }

    private func installOldApp(version: String = "1.0.0") throws {
        try FileManager.default.createDirectory(at: applications, withIntermediateDirectories: true)
        try makeApp(at: installedApp, version: version)
    }

    private func leftovers() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: applications.path).filter { $0 != "AVD Studio.app" }
    }

    private func nothingStaysMounted() throws -> Bool {
        !(try run("/usr/bin/hdiutil", ["info"])).contains("avdstudio-update-")
    }

    /// The error a call throws, or nil.
    private func installError(_ installer: SystemUpdateInstaller, image: URL, version: String) async -> InstallError? {
        do {
            try await installer.install(diskImage: image, version: AppVersion(version)!, over: installedApp)
            return nil
        } catch {
            return error as? InstallError
        }
    }

    // MARK: Replacing the app

    @Test func replacesTheInstalledAppWithTheOneInTheDiskImage() async throws {
        try installOldApp(version: "1.0.0")
        let image = try makeDiskImage(version: "2.0.0")
        let installer = makeInstaller()
        #expect(installer.installedVersion(at: installedApp) == AppVersion("1.0.0"))

        try await installer.install(diskImage: image, version: AppVersion("2.0.0")!, over: installedApp)

        #expect(installer.installedVersion(at: installedApp) == AppVersion("2.0.0"))
        let extra = try leftovers()
        #expect(extra.isEmpty, "no staged copy is left in Applications: \(extra)")
        let mounted = try nothingStaysMounted()
        #expect(mounted)
        // The result is a real, intact app.
        try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", installedApp.path])
    }

    @Test func keepsTheOldAppWhenTheDiskImageHoldsAnotherVersion() async throws {
        try installOldApp(version: "1.0.0")
        let image = try makeDiskImage(version: "2.5.0")
        let installer = makeInstaller()

        let error = await installError(installer, image: image, version: "2.0.0")

        guard case .wrongApp(let reason)? = error else {
            Issue.record("expected wrongApp, got \(String(describing: error))")
            return
        }
        #expect(reason.contains("2.5.0"))
        #expect(installer.installedVersion(at: installedApp) == AppVersion("1.0.0"), "the installed app is untouched")
        let mounted = try nothingStaysMounted()
        #expect(mounted)
    }

    @Test func refusesAnAppThatIsNotAVDStudio() async throws {
        try installOldApp()
        let image = try makeDiskImage(version: "2.0.0", id: "com.example.other")
        let installer = makeInstaller()

        let error = await installError(installer, image: image, version: "2.0.0")

        guard case .wrongApp(let reason)? = error else {
            Issue.record("expected wrongApp, got \(String(describing: error))")
            return
        }
        #expect(reason.contains("com.example.other"))
        #expect(installer.installedVersion(at: installedApp) == AppVersion("1.0.0"))
    }

    @Test func refusesAnAppWhoseSignatureIsBroken() async throws {
        try installOldApp()
        let image = try makeDiskImage(version: "2.0.0", signed: false)
        let installer = makeInstaller()

        let error = await installError(installer, image: image, version: "2.0.0")

        #expect(error == .signatureInvalid)
        #expect(installer.installedVersion(at: installedApp) == AppVersion("1.0.0"))
        let extra = try leftovers()
        #expect(extra.isEmpty)
    }

    @Test func refusesADiskImageWithoutAnApp() async throws {
        try installOldApp()
        let source = home.appendingPathComponent("empty-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try "just a file".write(to: source.appendingPathComponent("README.txt"), atomically: true, encoding: .utf8)
        let image = try pack(source)

        let error = await installError(makeInstaller(), image: image, version: "2.0.0")

        guard case .wrongApp(let reason)? = error else {
            Issue.record("expected wrongApp, got \(String(describing: error))")
            return
        }
        #expect(reason.contains("no app"))
    }

    @Test func reportsAFileThatIsNotADiskImage() async throws {
        try installOldApp()
        let bogus = home.appendingPathComponent("not-an-image.dmg")
        try "this is not a disk image".write(to: bogus, atomically: true, encoding: .utf8)

        let error = await installError(makeInstaller(), image: bogus, version: "2.0.0")

        guard case .diskImage? = error else {
            Issue.record("expected diskImage, got \(String(describing: error))")
            return
        }
        #expect(makeInstaller().installedVersion(at: installedApp) == AppVersion("1.0.0"))
    }

    @Test func explainsWhenTheApplicationsFolderCannotBeWrittenTo() async throws {
        try installOldApp()
        let image = try makeDiskImage(version: "2.0.0")
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: applications.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: applications.path) }

        let error = await installError(makeInstaller(), image: image, version: "2.0.0")

        guard case .notWritable(let folder)? = error else {
            Issue.record("expected notWritable, got \(String(describing: error))")
            return
        }
        #expect(folder == applications.path)
    }

    // MARK: Reading the installed version

    @Test func theInstalledVersionIsReadFromTheFileSoAnUpgradeIsSeen() throws {
        try installOldApp(version: "1.0.0")
        let installer = makeInstaller()
        #expect(installer.installedVersion(at: installedApp) == AppVersion("1.0.0"))

        // What `brew upgrade` does: the app at the same path becomes a newer one.
        try makeApp(at: installedApp, version: "1.1.0")

        #expect(installer.installedVersion(at: installedApp) == AppVersion("1.1.0"), "not a stale cached value")
        #expect(installer.installedVersion(at: home.appendingPathComponent("missing.app")) == nil)
    }

    // MARK: Homebrew

    private func installFakeBrew(script: String, caskroom: Bool = true) throws {
        let brew = brewPrefix.appendingPathComponent("bin/brew")
        try FileManager.default.createDirectory(at: brew.deletingLastPathComponent(), withIntermediateDirectories: true)
        try script.write(to: brew, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: brew.path)
        if caskroom {
            try FileManager.default.createDirectory(
                at: brewPrefix.appendingPathComponent("Caskroom/avd-studio/0.2.0"), withIntermediateDirectories: true)
        }
    }

    @Test func usesHomebrewOnlyWhenItManagesTheApp() async throws {
        let installer = makeInstaller()
        #expect(await installer.canUseHomebrew() == false, "no brew at all")

        try installFakeBrew(script: "#!/bin/sh\nexit 0\n", caskroom: false)
        #expect(await installer.canUseHomebrew() == false, "brew exists but did not install this app")

        try FileManager.default.createDirectory(
            at: brewPrefix.appendingPathComponent("Caskroom/avd-studio/0.2.0"), withIntermediateDirectories: true)
        #expect(await installer.canUseHomebrew())
    }

    @Test func upgradesTheQualifiedCaskThroughBrew() async throws {
        try installFakeBrew(script: "#!/bin/sh\necho \"$@\" >> \"\(brewLog.path)\"\nexit 0\n")

        try await makeInstaller().upgradeWithHomebrew()

        let calls = try String(contentsOf: brewLog, encoding: .utf8).split(separator: "\n")
        #expect(calls == ["upgrade --cask mrcsxsiq/avd-studio/avd-studio"])
    }

    @Test func showsWhatBrewSaidWhenItFails() async throws {
        try installFakeBrew(script: "#!/bin/sh\necho 'Error: Cask avd-studio is not installed' >&2\nexit 1\n")

        do {
            try await makeInstaller().upgradeWithHomebrew()
            Issue.record("expected a failure")
        } catch let error as InstallError {
            guard case .homebrewFailed(let output) = error else {
                Issue.record("expected homebrewFailed, got \(error)")
                return
            }
            #expect(output.contains("Cask avd-studio is not installed"))
        }
    }
}
