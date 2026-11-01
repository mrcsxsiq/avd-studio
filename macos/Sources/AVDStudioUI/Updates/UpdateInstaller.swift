import Foundation

/// Why putting a new version in place did not work. Each message says what to do next.
public enum InstallError: LocalizedError, Equatable, Sendable {
    case homebrewFailed(String)
    /// Homebrew finished but still has the old build: the tap is updated a little after a release is published.
    case homebrewBehind(AppVersion)
    case notWritable(String)
    case diskImage(String)
    case wrongApp(String)
    case signatureInvalid
    case noChecksum
    case relaunchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .homebrewFailed(let output):
            "Homebrew could not update AVD Studio.\n\(output)"
        case .homebrewBehind(let version):
            "Homebrew does not have version \(version) yet. Its tap is updated a few minutes after a release, so try again shortly, or install it from GitHub."
        case .notWritable(let folder):
            "AVD Studio cannot replace itself in \(folder) (no permission). Open the installer and drag the app to Applications yourself."
        case .diskImage(let output):
            "The installer could not be opened.\n\(output)"
        case .wrongApp(let reason):
            "The downloaded installer is not the AVD Studio you asked for: \(reason)"
        case .signatureInvalid:
            "The downloaded app failed its signature check, so it was not installed."
        case .noChecksum:
            "This release was published without a checksum, so AVD Studio will not install it on its own. Open the installer yourself if you trust it."
        case .relaunchFailed(let message):
            "The update is installed, but AVD Studio could not reopen itself (\(message)). Open it again from Applications."
        }
    }
}

/// What it takes to put a new version in place: Homebrew when it manages the app, otherwise the downloaded disk image.
/// The real one runs `brew`, `hdiutil` and `ditto` through the core; tests use a fake.
public protocol UpdateInstaller: Sendable {
    /// True when Homebrew is installed and manages this app, so it should be the one to update it.
    func canUseHomebrew() async -> Bool
    /// Runs the Homebrew upgrade and returns when it is done. Can take a minute.
    func upgradeWithHomebrew() async throws
    /// Mounts the disk image, checks the app inside is version `version` of this app and correctly signed, and
    /// swaps it in place of `appURL`. Leaves `appURL` untouched when anything fails.
    func install(diskImage: URL, version: AppVersion, over appURL: URL) async throws
    /// The version of the app installed at `appURL`, read from its Info.plist.
    func installedVersion(at appURL: URL) -> AppVersion?
    /// Opens the app at `appURL` as a new process. The caller quits the old one.
    func relaunch(appAt appURL: URL) async throws
}
