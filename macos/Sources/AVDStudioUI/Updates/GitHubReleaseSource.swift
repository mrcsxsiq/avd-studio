import Foundation

/// Where the app learns about new versions.
public protocol ReleaseSource: Sendable {
    /// The newest published, non-draft, non-pre-release version, or nil when none has been published yet.
    func latestRelease() async throws -> AppRelease?
}

/// Reads the "latest release" of a GitHub repository (public repositories only, no token needed).
public struct GitHubReleaseSource: ReleaseSource {
    public let owner: String
    public let repository: String
    private let client: any HTTPClient

    public init(owner: String, repository: String, client: any HTTPClient = URLSessionHTTPClient()) {
        self.owner = owner
        self.repository = repository
        self.client = client
    }

    public func latestRelease() async throws -> AppRelease? {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(owner)/\(repository)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("AVD-Studio-Updater", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await client.data(for: request)
        } catch let error as UpdateError {
            throw error
        } catch {
            throw UpdateError.network(error.localizedDescription)
        }

        switch response.statusCode {
        case 200: return try Self.parse(data)
        case 404: return nil // no release has been published (or the repository is not public yet)
        case 403, 429: throw UpdateError.rateLimited
        default: throw UpdateError.badResponse(response.statusCode)
        }
    }

    static func parse(_ data: Data) throws -> AppRelease? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        guard let payload = try? decoder.decode(Payload.self, from: data),
              let version = AppVersion(payload.tagName)
        else { throw UpdateError.unreadable }
        guard !payload.draft, !payload.prerelease else { return nil }

        let installer = payload.assets.first { $0.name.lowercased().hasSuffix(".dmg") }
        let asset = installer.map { dmg in
            AppRelease.Asset(
                name: dmg.name,
                url: dmg.browserDownloadUrl,
                size: dmg.size,
                checksumURL: payload.assets.first { $0.name == dmg.name + ".sha256" }?.browserDownloadUrl
            )
        }
        return AppRelease(
            version: version,
            title: payload.name?.isEmpty == false ? payload.name : nil,
            notes: payload.body ?? "",
            pageURL: payload.htmlUrl,
            publishedAt: payload.publishedAt,
            asset: asset
        )
    }

    private struct Payload: Decodable {
        struct Asset: Decodable {
            let name: String
            let size: Int64?
            let browserDownloadUrl: URL
        }

        let tagName: String
        let name: String?
        let body: String?
        let htmlUrl: URL
        let draft: Bool
        let prerelease: Bool
        let publishedAt: Date?
        let assets: [Asset]
    }
}
