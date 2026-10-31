import Foundation

/// A published version of the app and what is needed to install it.
public struct AppRelease: Equatable, Sendable {
    public struct Asset: Equatable, Sendable {
        public let name: String
        public let url: URL
        public let size: Int64?
        /// A `.sha256` file published next to the installer, when there is one.
        public let checksumURL: URL?

        public init(name: String, url: URL, size: Int64? = nil, checksumURL: URL? = nil) {
            self.name = name
            self.url = url
            self.size = size
            self.checksumURL = checksumURL
        }
    }

    public let version: AppVersion
    public let title: String
    public let notes: String
    public let pageURL: URL
    public let publishedAt: Date?
    public let asset: Asset?

    public init(version: AppVersion, title: String? = nil, notes: String = "", pageURL: URL, publishedAt: Date? = nil, asset: Asset? = nil) {
        self.version = version
        self.title = title ?? "Version \(version)"
        self.notes = notes
        self.pageURL = pageURL
        self.publishedAt = publishedAt
        self.asset = asset
    }
}

public enum UpdateError: LocalizedError, Equatable, Sendable {
    case network(String)
    case rateLimited
    case badResponse(Int)
    case unreadable
    case checksumMismatch
    case noInstaller

    public var errorDescription: String? {
        switch self {
        case .network(let message): "Could not reach GitHub: \(message)"
        case .rateLimited: "GitHub is limiting requests right now. Try again in a few minutes."
        case .badResponse(let code): "GitHub answered with an unexpected status (\(code))."
        case .unreadable: "The release information could not be read."
        case .checksumMismatch: "The downloaded file is corrupted (its checksum does not match). Please try again."
        case .noInstaller: "This release does not include a downloadable installer."
        }
    }
}
