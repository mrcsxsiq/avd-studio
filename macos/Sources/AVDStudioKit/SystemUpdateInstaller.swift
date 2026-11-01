import AVDStudioCore
import AVDStudioUI
import AppKit
import Foundation

/// The real `UpdateInstaller`: asks Homebrew to upgrade, or mounts the downloaded disk image, checks the app inside
/// and swaps it in. The commands run through the Kotlin core; this file only decides what to ask and checks the result.
public final class SystemUpdateInstaller: UpdateInstaller, @unchecked Sendable {
    // Kotlin objects are not Sendable; like `KotlinDeviceService`, this only uses the core from detached tasks.
    private let core: AvdStudioCore
    private let bundleIdentifier: String

    public init(bundleIdentifier: String = "dev.marcos.avdstudio") {
        self.core = AvdStudioCore(runner: NativeCommandRunner(), environment: SystemEnvironment())
        self.bundleIdentifier = bundleIdentifier
    }

    /// For tests: points the core at a temporary home folder, Homebrew prefix and environment.
    init(environment: any AVDStudioCore.Environment, bundleIdentifier: String = "dev.marcos.avdstudio") {
        self.core = AvdStudioCore(runner: NativeCommandRunner(), environment: environment)
        self.bundleIdentifier = bundleIdentifier
    }

    // MARK: Homebrew

    public func canUseHomebrew() async -> Bool {
        await Task.detached { [core] in core.canUpdateAppWithHomebrew() }.value
    }

    public func upgradeWithHomebrew() async throws {
        try await Task.detached { [core] in
            let result: CommandResult
            do {
                result = try core.upgradeAppWithHomebrew()
            } catch {
                throw InstallError.homebrewFailed(Self.message(for: error))
            }
            guard result.exitCode == 0 else { throw InstallError.homebrewFailed(Self.tail(of: result)) }
        }.value
    }

    // MARK: Disk image

    public func install(diskImage: URL, version: AppVersion, over appURL: URL) async throws {
        try await Task.detached { [core, bundleIdentifier] in
            try Self.replace(appURL, withAppIn: diskImage, version: version, bundleIdentifier: bundleIdentifier, core: core)
        }.value
    }

    private static func replace(
        _ appURL: URL, withAppIn diskImage: URL, version: AppVersion, bundleIdentifier: String, core: AvdStudioCore
    ) throws {
        let fileManager = FileManager.default
        let folder = appURL.deletingLastPathComponent()
        guard fileManager.isWritableFile(atPath: folder.path), fileManager.isWritableFile(atPath: appURL.path) else {
            throw InstallError.notWritable(folder.path)
        }

        let work = fileManager.temporaryDirectory.appendingPathComponent("avdstudio-update-\(UUID().uuidString)")
        let mountPoint = work.appendingPathComponent("mount")
        try fileManager.createDirectory(at: mountPoint, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: work) }

        try run(core) { try core.mountDiskImage(dmgPath: diskImage.path, mountPoint: mountPoint.path) }
            .orThrow { InstallError.diskImage($0) }
        defer { _ = try? core.unmountDiskImage(mountPoint: mountPoint.path) }

        let contents = (try? fileManager.contentsOfDirectory(at: mountPoint, includingPropertiesForKeys: nil)) ?? []
        guard let source = contents.first(where: { $0.pathExtension == "app" }) else {
            throw InstallError.wrongApp("the disk image has no app in it.")
        }
        let info = infoDictionary(of: source)
        guard info?["CFBundleIdentifier"] as? String == bundleIdentifier else {
            throw InstallError.wrongApp("it is \(info?["CFBundleIdentifier"] as? String ?? "an unknown app").")
        }
        let found = (info?["CFBundleShortVersionString"] as? String).flatMap { AppVersion($0) }
        guard found == version else {
            throw InstallError.wrongApp("it is version \(found?.description ?? "unknown"), not \(version).")
        }
        guard try verifies(source, core: core) else { throw InstallError.signatureInvalid }

        // Copy next to the destination so the final swap stays on one volume and is atomic.
        let staged = folder.appendingPathComponent(
            ".\(appURL.deletingPathExtension().lastPathComponent) update \(UUID().uuidString.prefix(8)).app")
        defer { try? fileManager.removeItem(at: staged) }
        try run(core) { try core.duplicateApplication(source: source.path, destination: staged.path) }
            .orThrow { InstallError.diskImage("Could not copy the new version: \($0)") }
        guard try verifies(staged, core: core) else { throw InstallError.signatureInvalid }

        do {
            _ = try fileManager.replaceItemAt(appURL, withItemAt: staged, backupItemName: nil, options: [])
        } catch {
            throw InstallError.notWritable(folder.path)
        }
    }

    // MARK: Version and restart

    public func installedVersion(at appURL: URL) -> AppVersion? {
        // Read the file, not `Bundle`: Cocoa keeps the Info.plist of the running app cached and would still say the old version.
        (Self.infoDictionary(of: appURL)?["CFBundleShortVersionString"] as? String).flatMap { AppVersion($0) }
    }

    public func relaunch(appAt appURL: URL) async throws {
        do {
            try await Self.open(appURL)
        } catch {
            throw InstallError.relaunchFailed(error.localizedDescription)
        }
    }

    @MainActor
    private static func open(_ appURL: URL) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.activates = true
        _ = try await NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
    }

    // MARK: Helpers

    static func infoDictionary(of app: URL) -> [String: Any]? {
        let plist = app.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plist) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
    }

    private static func verifies(_ app: URL, core: AvdStudioCore) throws -> Bool {
        do { return try core.verifyApplicationSignature(path: app.path).exitCode == 0 } catch { return false }
    }

    /// Runs a core command and turns a launch failure or a non-zero exit into the text to show.
    private static func run(_ core: AvdStudioCore, _ command: () throws -> CommandResult) throws -> Outcome {
        do {
            let result = try command()
            return result.exitCode == 0 ? .success : .failure(tail(of: result))
        } catch {
            return .failure(message(for: error))
        }
    }

    private enum Outcome {
        case success
        case failure(String)

        func orThrow(_ make: (String) -> InstallError) throws {
            if case .failure(let text) = self { throw make(text) }
        }
    }

    private static func tail(of result: CommandResult, lines: Int = 12) -> String {
        let text =
            [result.standardError, result.standardOutput].first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? ""
        let kept = text.split(separator: "\n", omittingEmptySubsequences: false).suffix(lines).joined(separator: "\n")
        let trimmed = kept.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "The command failed with exit code \(result.exitCode)." : trimmed
    }

    private static func message(for error: Error) -> String {
        (error as NSError).localizedDescription
    }
}
