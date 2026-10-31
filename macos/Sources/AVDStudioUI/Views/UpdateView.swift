import SwiftUI

/// "Software Update": what you have, what is available, and how to get it.
public struct UpdateView: View {
    @Bindable var model: UpdateModel
    @Environment(\.dismissWindow) private var dismissWindow

    public init(model: UpdateModel) {
        self.model = model
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                content
                    .padding(28)
                    .frame(maxWidth: .infinity)
            }
            Divider()
            footer
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
        }
        .frame(width: 540, height: 520)
        .animation(.default, value: model.state)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle, .checking:
            VStack(spacing: 16) {
                HeroIcon(symbol: "arrow.triangle.2.circlepath", colors: [.blue, .indigo])
                ProgressView().controlSize(.small)
                Text("Checking for updates…").font(.title2.weight(.semibold))
                Text("AVD Studio \(model.currentVersion.description)").foregroundStyle(.secondary)
            }
        case .upToDate(let date):
            status(
                symbol: "checkmark.seal.fill",
                colors: [.green, .teal],
                title: "You're up to date",
                message: "AVD Studio \(model.currentVersion.description) is the latest version.",
                caption: "Last checked \(Self.relative(date))"
            )
        case .noReleases(let date):
            status(
                symbol: "tray.fill",
                colors: [.gray, .blue],
                title: "No releases published yet",
                message: "You're running AVD Studio \(model.currentVersion.description). New versions will show up here.",
                caption: "Last checked \(Self.relative(date))"
            )
        case .available(let release):
            available(release)
        case .downloading(let release, let progress):
            downloading(release, progress: progress)
        case .downloaded(let release, _, let verified):
            downloaded(release, verified: verified)
        case .failed(let message):
            status(symbol: "exclamationmark.triangle.fill", colors: [.orange, .red], title: "Something went wrong", message: message)
        }
    }

    private func status(symbol: String, colors: [Color], title: String, message: String, caption: String? = nil) -> some View {
        VStack(spacing: 14) {
            HeroIcon(symbol: symbol, colors: colors)
            Text(title).font(.title.weight(.bold))
            Text(message)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            if let caption { Text(caption).font(.callout).foregroundStyle(.tertiary) }
        }
    }

    private func available(_ release: AppRelease) -> some View {
        VStack(spacing: 18) {
            HeroIcon(symbol: "arrow.down.circle.fill", colors: [.blue, .purple])
            Text("A new version is available").font(.title.weight(.bold))
            VersionComparison(current: model.currentVersion, new: release.version)
            releaseDetails(release)
            if model.installSource == .homebrew { homebrewNote }
            ReleaseNotes(text: release.notes)
        }
    }

    private func downloading(_ release: AppRelease, progress: Double) -> some View {
        VStack(spacing: 18) {
            HeroIcon(symbol: "arrow.down.circle.fill", colors: [.blue, .purple])
            Text("Downloading \(release.version.description)…").font(.title.weight(.bold))
            VersionComparison(current: model.currentVersion, new: release.version)
            VStack(spacing: 6) {
                ProgressView(value: progress)
                Text(progress.formatted(.percent.precision(.fractionLength(0))))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 380)
        }
    }

    private func downloaded(_ release: AppRelease, verified: Bool) -> some View {
        VStack(spacing: 18) {
            HeroIcon(symbol: "checkmark.circle.fill", colors: [.green, .teal])
            Text("Version \(release.version.description) downloaded").font(.title.weight(.bold))
            VersionComparison(current: model.currentVersion, new: release.version)
            Label(
                verified ? "Checksum verified" : "No checksum was published for this release",
                systemImage: verified ? "lock.shield.fill" : "exclamationmark.shield.fill"
            )
            .foregroundStyle(verified ? .green : .orange)
            Text("Open the installer, drag AVD Studio to Applications to replace the old version, then launch it again.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
    }

    private func releaseDetails(_ release: AppRelease) -> some View {
        let parts = [
            release.publishedAt.map { "Released " + $0.formatted(date: .abbreviated, time: .omitted) },
            release.asset?.size.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) },
        ].compactMap { $0 }
        return Text(parts.joined(separator: " · ")).font(.callout).foregroundStyle(.secondary)
    }

    private var homebrewNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Installed with Homebrew", systemImage: "mug.fill").font(.headline)
            Text("Let Homebrew update it so both stay in sync:").foregroundStyle(.secondary)
            Text(InstallSource.brewUpgradeCommand)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(14)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(maxWidth: 440)
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        HStack {
            if model.availableRelease != nil {
                Button("View on GitHub") { model.openReleasePage() }.buttonStyle(.link)
            }
            Spacer()
            switch model.state {
            case .idle, .checking:
                Button("Check Again") {}.disabled(true)
            case .upToDate, .noReleases:
                Button("Check Again") { Task { await model.checkForUpdates() } }
            case .failed:
                Button("Try Again") { Task { await model.checkForUpdates() } }
            case .available(let release):
                Button("Not Now") { dismissWindow(id: "updates") }
                if model.installSource == .homebrew {
                    Button("Copy Brew Command") { Clipboard.copy(InstallSource.brewUpgradeCommand) }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button(downloadTitle(release)) { model.startDownload() }
                        .keyboardShortcut(.defaultAction)
                }
            case .downloading:
                Button("Cancel") { model.cancelDownload() }
            case .downloaded:
                Button("Show in Finder") { model.revealDownload() }
                Button("Open Installer") { model.openInstaller() }.keyboardShortcut(.defaultAction)
            }
        }
    }

    private func downloadTitle(_ release: AppRelease) -> String {
        guard release.asset != nil else { return "Open Release Page" }
        return "Download \(release.version.description)"
    }

    private static func relative(_ date: Date) -> String {
        date.formatted(.relative(presentation: .named))
    }
}

struct VersionComparison: View {
    let current: AppVersion
    let new: AppVersion

    var body: some View {
        HStack(spacing: 16) {
            badge(title: "Installed", version: current, tint: .secondary)
            Image(systemName: "arrow.right").font(.title2.weight(.semibold)).foregroundStyle(.secondary).accessibilityHidden(true)
            badge(title: "New", version: new, tint: .accentColor)
        }
    }

    private func badge(title: String, version: AppVersion, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(title.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(version.description).font(.system(.title2, design: .rounded).weight(.bold)).monospacedDigit()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(tint.opacity(0.35)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) version \(version.description)")
    }
}

private struct ReleaseNotes: View {
    let text: String

    var body: some View {
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("What's new").font(.headline)
                Text(attributed)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .frame(maxWidth: 460)
        }
    }

    private var attributed: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

private struct HeroIcon: View {
    let symbol: String
    let colors: [Color]

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 44, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 92, height: 92)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .shadow(color: (colors.last ?? .blue).opacity(0.4), radius: 12, y: 6)
            .accessibilityHidden(true)
    }
}
