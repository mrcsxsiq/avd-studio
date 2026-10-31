import Foundation

/// A semantic version (`1.4.0`, `v2.0.0-beta.1`) with SemVer 2.0 precedence rules, so `0.9.0 < 0.10.0`
/// and `1.0.0-rc.1 < 1.0.0`. Build metadata (`+abc`) is accepted and ignored.
public struct AppVersion: Hashable, Sendable, Comparable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let prerelease: [String]

    public init(major: Int, minor: Int = 0, patch: Int = 0, prerelease: [String] = []) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.prerelease = prerelease
    }

    public init?(_ text: String) {
        var rest = Substring(text.trimmingCharacters(in: .whitespacesAndNewlines))
        if rest.first == "v" || rest.first == "V" { rest = rest.dropFirst() }
        if let plus = rest.firstIndex(of: "+") { rest = rest[..<plus] }

        var identifiers: [String] = []
        if let dash = rest.firstIndex(of: "-") {
            identifiers = rest[rest.index(after: dash)...].split(separator: ".", omittingEmptySubsequences: false).map(String.init)
            guard !identifiers.isEmpty, identifiers.allSatisfy({ !$0.isEmpty }) else { return nil }
            rest = rest[..<dash]
        }

        let numbers = rest.split(separator: ".", omittingEmptySubsequences: false).map { Self.number($0) }
        guard (1...3).contains(numbers.count), !numbers.contains(where: { $0 == nil }) else { return nil }
        let values = numbers.compactMap { $0 }
        self.init(
            major: values[0],
            minor: values.count > 1 ? values[1] : 0,
            patch: values.count > 2 ? values[2] : 0,
            prerelease: identifiers
        )
    }

    public var description: String {
        let core = "\(major).\(minor).\(patch)"
        return prerelease.isEmpty ? core : core + "-" + prerelease.joined(separator: ".")
    }

    public var isPrerelease: Bool { !prerelease.isEmpty }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        // A release is newer than any of its pre-releases.
        switch (lhs.prerelease.isEmpty, rhs.prerelease.isEmpty) {
        case (true, true): return false
        case (true, false): return false
        case (false, true): return true
        case (false, false): return comparePrerelease(lhs.prerelease, rhs.prerelease) < 0
        }
    }

    private static func comparePrerelease(_ lhs: [String], _ rhs: [String]) -> Int {
        for (left, right) in zip(lhs, rhs) where left != right {
            switch (number(Substring(left)), number(Substring(right))) {
            case let (l?, r?): return l < r ? -1 : 1
            case (.some, nil): return -1 // numeric identifiers sort before alphanumeric ones
            case (nil, .some): return 1
            case (nil, nil): return left < right ? -1 : 1
            }
        }
        return lhs.count == rhs.count ? 0 : (lhs.count < rhs.count ? -1 : 1)
    }

    private static func number(_ text: Substring) -> Int? {
        guard !text.isEmpty, text.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }) else { return nil }
        return Int(text)
    }
}
