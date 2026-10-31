import Foundation

/// How the app got onto this Mac. Homebrew-managed installs should be updated by Homebrew,
/// otherwise the two package managers fight over the same app.
public enum InstallSource: Equatable, Sendable {
    case homebrew
    case manual

    public static let brewUpgradeCommand = "brew upgrade --cask avd-studio"

    public static func detect(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        exists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) -> InstallSource {
        var prefixes = ["/opt/homebrew", "/usr/local"]
        if let custom = environment["HOMEBREW_PREFIX"], !custom.isEmpty { prefixes.insert(custom, at: 0) }
        return prefixes.contains { exists("\($0)/Caskroom/avd-studio") } ? .homebrew : .manual
    }
}
