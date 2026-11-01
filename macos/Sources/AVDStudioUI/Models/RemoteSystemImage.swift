import Foundation

/// A system image Google publishes and `sdkmanager` can download. Only images that run on this Mac are listed.
public struct RemoteSystemImage: Identifiable, Hashable, Sendable {
    /// `system-images;android-36;google_apis_playstore;arm64-v8a` (also the id).
    public let packagePath: String
    public let apiLevel: String?
    public let androidVersion: String?
    /// `Android 16 (API 36)`, or `Android canary-20261007 (preview)` for a preview.
    public let versionLabel: String
    /// `Google Play`, `Google APIs`, `Android TV`, `Wear OS`…
    public let tagDisplay: String
    public let abi: String
    public let revision: String
    public let hasPlayStore: Bool
    public let isNativeOnAppleSilicon: Bool
    public let isPreview: Bool
    public let usesSixteenKbPages: Bool
    /// Headless images for automated testing; not meant for hand use.
    public let isAutomatedTestImage: Bool
    public let family: SystemImage.Family
    public let isInstalled: Bool

    public var id: String { packagePath }

    public init(
        packagePath: String, apiLevel: String?, androidVersion: String? = nil, versionLabel: String, tagDisplay: String,
        abi: String = "arm64-v8a", revision: String = "1", hasPlayStore: Bool = false, isNativeOnAppleSilicon: Bool = true,
        isPreview: Bool = false, usesSixteenKbPages: Bool = false, isAutomatedTestImage: Bool = false,
        family: SystemImage.Family = .general, isInstalled: Bool = false
    ) {
        self.packagePath = packagePath
        self.apiLevel = apiLevel
        self.androidVersion = androidVersion
        self.versionLabel = versionLabel
        self.tagDisplay = tagDisplay
        self.abi = abi
        self.revision = revision
        self.hasPlayStore = hasPlayStore
        self.isNativeOnAppleSilicon = isNativeOnAppleSilicon
        self.isPreview = isPreview
        self.usesSixteenKbPages = usesSixteenKbPages
        self.isAutomatedTestImage = isAutomatedTestImage
        self.family = family
        self.isInstalled = isInstalled
    }

    /// Previews and test images are hidden until the user asks for them.
    public var isAdvanced: Bool { isPreview || isAutomatedTestImage }

    /// `Android 16 (API 36) · Google Play · arm64-v8a`
    public var displayName: String { "\(versionLabel) · \(tagDisplay) · \(abi)" }

    func settingInstalled(_ installed: Bool) -> RemoteSystemImage {
        RemoteSystemImage(
            packagePath: packagePath, apiLevel: apiLevel, androidVersion: androidVersion, versionLabel: versionLabel,
            tagDisplay: tagDisplay, abi: abi, revision: revision, hasPlayStore: hasPlayStore,
            isNativeOnAppleSilicon: isNativeOnAppleSilicon, isPreview: isPreview, usesSixteenKbPages: usesSixteenKbPages,
            isAutomatedTestImage: isAutomatedTestImage, family: family, isInstalled: installed)
    }
}

/// Two spellings of the same package (`;` and `/`, with or without a trailing slash) compare equal.
public func samePackage(_ lhs: String, _ rhs: String) -> Bool {
    func normalized(_ value: String) -> String {
        var result = value.replacingOccurrences(of: "/", with: ";")
        while result.hasSuffix(";") { result.removeLast() }
        return result
    }
    return normalized(lhs) == normalized(rhs)
}
