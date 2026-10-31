import AppKit
import Foundation
import Observation

/// What the About window shows: the name, the running version and where to find the project.
public struct AppInfo: Equatable, Sendable {
    public static let repository = URL(string: "https://github.com/mrcsxsiq/avd-studio")!
    public static let website = URL(string: "https://mrcsxsiq.github.io/avd-studio/")!
    public static let changelog = URL(string: "https://github.com/mrcsxsiq/avd-studio/blob/main/CHANGELOG.md")!
    public static let license = URL(string: "https://github.com/mrcsxsiq/avd-studio/blob/main/LICENSE")!

    public var name: String
    public var version: String
    public var build: String?

    public init(name: String = "AVD Studio", version: String, build: String? = nil) {
        self.name = name
        self.version = version
        self.build = build
    }

    /// `Version 0.1.0 (12)`; a build without a bundle (tests, `swift run`) says so instead of inventing a number.
    public var versionLine: String {
        guard version != Self.developmentVersion else { return "Development build" }
        return build.map { "Version \(version) (\($0))" } ?? "Version \(version)"
    }

    static let developmentVersion = "development"

    public static func current(infoDictionary: [String: Any]? = Bundle.main.infoDictionary) -> AppInfo {
        let version = (infoDictionary?["CFBundleShortVersionString"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let build = (infoDictionary?["CFBundleVersion"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        return AppInfo(version: version ?? developmentVersion, build: version == nil ? nil : build)
    }
}

/// Opens the pages the About window links to.
@MainActor
@Observable
public final class AboutModel {
    public let info: AppInfo
    @ObservationIgnored private let opener: any FileOpening

    public init(info: AppInfo = .current(), opener: any FileOpening = WorkspaceFileOpener()) {
        self.info = info
        self.opener = opener
    }

    /// The app has no GitHub account or token (by design), so it cannot star the repository itself: it opens the
    /// page, where one click on "Star" does it.
    public func starRepository() { opener.open(AppInfo.repository) }
    public func openWebsite() { opener.open(AppInfo.website) }
    public func openChangelog() { opener.open(AppInfo.changelog) }
    public func openLicense() { opener.open(AppInfo.license) }
}
