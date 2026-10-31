import Foundation

public struct SetupStep: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable {
        case commandLineTools
        case java
        case licenses
        case sdkPackages
        case systemImages
    }

    public let kind: Kind
    public let title: String
    /// The command as the user would type it.
    public let displayCommand: String
    public let requiresHomebrew: Bool
    public let requiresLicenseAcceptance: Bool

    public var id: String { kind.rawValue }

    public init(kind: Kind, title: String, displayCommand: String, requiresHomebrew: Bool, requiresLicenseAcceptance: Bool) {
        self.kind = kind
        self.title = title
        self.displayCommand = displayCommand
        self.requiresHomebrew = requiresHomebrew
        self.requiresLicenseAcceptance = requiresLicenseAcceptance
    }
}

/// What has to be installed on this Mac and whether the app can do it by itself.
public struct SetupPlan: Equatable, Sendable {
    public static let licenseURL = URL(string: "https://developer.android.com/studio/terms")!
    public static let homebrewURL = URL(string: "https://brew.sh")!
    public static let commandLineToolsURL = URL(string: "https://developer.android.com/studio#command-line-tools-only")!
    public static let empty = SetupPlan(steps: [], homebrewInstalled: false, sdkPath: "", shellScript: "")

    public let steps: [SetupStep]
    public let homebrewInstalled: Bool
    /// The SDK folder the steps install into.
    public let sdkPath: String
    /// Equivalent shell script, for "open in Terminal" and copy-and-paste.
    public let shellScript: String

    public init(steps: [SetupStep], homebrewInstalled: Bool, sdkPath: String, shellScript: String) {
        self.steps = steps
        self.homebrewInstalled = homebrewInstalled
        self.sdkPath = sdkPath
        self.shellScript = shellScript
    }

    public var isEmpty: Bool { steps.isEmpty }
    public var needsHomebrew: Bool { steps.contains { $0.requiresHomebrew } }
    public var needsLicenseAcceptance: Bool { steps.contains { $0.requiresLicenseAcceptance } }
    public var canRunAutomatically: Bool { !steps.isEmpty && (!needsHomebrew || homebrewInstalled) }
}

public struct SetupStepResult: Equatable, Sendable {
    public let exitCode: Int32
    public let output: String

    public init(exitCode: Int32, output: String) {
        self.exitCode = exitCode
        self.output = output
    }

    public var isSuccess: Bool { exitCode == 0 }
}
