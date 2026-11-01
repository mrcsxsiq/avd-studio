import SwiftUI

/// Settings > Updates: the installed and latest versions, automatic checks, what's new, and Install.
struct UpdatesSettingsTab: View {
    @Environment(UpdateModel.self) private var updates: UpdateModel?
    @Environment(\.openWindow) private var openWindow
    @Environment(\.locale) private var locale

    var body: some View {
        Group {
            if let updates {
                Form {
                    versionSection(updates)
                    actionSection(updates)
                    if let release = updates.availableRelease, !release.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        notesSection(release)
                    }
                    automaticSection(updates)
                }
                .formStyle(.grouped)
            } else {
                Text("Updates are not available in this build.").foregroundStyle(.secondary)
            }
        }
        .frame(width: SettingsTab.updates.size.width, height: SettingsTab.updates.size.height)
    }

    // MARK: Sections

    private func versionSection(_ updates: UpdateModel) -> some View {
        Section {
            LabeledContent("Installed", value: updates.currentVersion.description)
            LabeledContent("Latest") { latest(updates).font(.body) }
            if let checked = updates.lastChecked {
                LabeledContent("Last checked", value: checked.formatted(.relative(presentation: .named).locale(locale)))
            }
        } header: {
            Text("AVD Studio")
        }
    }

    @ViewBuilder
    private func latest(_ updates: UpdateModel) -> some View {
        switch updates.state {
        case .idle, .noReleases:
            Text("Not checked yet").foregroundStyle(.secondary)
        case .checking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Checking…").foregroundStyle(.secondary)
            }
        case .upToDate:
            Label("Up to date", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
        case .failed:
            Label("Could not check", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        default:
            if let release = updates.availableRelease {
                Text(release.version.description).foregroundStyle(Color.accentColor).fontWeight(.semibold)
            }
        }
    }

    private func automaticSection(_ updates: UpdateModel) -> some View {
        Section {
            Toggle(
                "Check for updates automatically",
                isOn: Binding(get: { updates.automaticChecks }, set: { updates.automaticChecks = $0 })
            )
        } footer: {
            Text("AVD Studio looks for new versions when it opens and every few hours, and notifies you when one is released.")
        }
    }

    private func notesSection(_ release: AppRelease) -> some View {
        Section {
            ScrollView {
                ReleaseNotesView(markdown: release.notes).padding(.vertical, 4)
            }
            .frame(height: 170)
        } header: {
            HStack {
                Text("What's new in \(release.version.description)")
                Spacer()
                Button("View on GitHub") { updates?.openReleasePage() }.buttonStyle(.link).font(.callout)
            }
        }
    }

    // MARK: Actions

    @ViewBuilder
    private func actionSection(_ updates: UpdateModel) -> some View {
        Section {
            switch updates.state {
            case .idle, .noReleases, .upToDate:
                Button("Check for Updates") { Task { await updates.checkForUpdates() } }
            case .checking:
                Button("Check for Updates") {}.disabled(true)
            case .failed(let message):
                problem(message)
                Button("Try Again") { Task { await updates.checkForUpdates() } }
            case .available(let release):
                available(release, updates)
            case .downloading(_, let progress):
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: progress)
                    Text("Downloading… \(progress.formatted(.percent.precision(.fractionLength(0))))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Button("Cancel") { updates.cancelDownload() }
            case .downloaded(_, _, let verified):
                Label(
                    verified ? "Downloaded, checksum verified" : "Downloaded, no checksum was published",
                    systemImage: verified ? "lock.shield.fill" : "exclamationmark.shield.fill"
                )
                .foregroundStyle(verified ? .green : .orange)
                HStack {
                    Button("Show in Finder") { updates.revealDownload() }
                    Button("Open Installer") { updates.openInstaller() }.buttonStyle(.borderedProminent)
                }
            case .installing(_, let phase):
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView().progressViewStyle(.linear)
                    Text(
                        phase == .homebrew
                            ? "Homebrew is updating AVD Studio. This can take a minute." : "Replacing AVD Studio with the new version."
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
            case .installed(let release):
                Label("Version \(release.version.description) is installed. AVD Studio is reopening…", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .installFailed(_, let reason, _):
                problem(reason)
                HStack {
                    if updates.downloadedFile != nil {
                        Button("Show in Finder") { updates.revealDownload() }
                        Button("Open Installer") { updates.openInstaller() }
                    }
                    if updates.canInstallFromGitHubInstead {
                        Button("Install from GitHub") { updates.installFromGitHub() }
                    }
                    if updates.installSource == .homebrew {
                        Button("Copy Brew Command") { Clipboard.copy(InstallSource.brewUpgradeCommand) }
                    }
                    Spacer()
                    Button("Try Again") { updates.install() }.buttonStyle(.borderedProminent)
                }
            }
        } header: {
            Text("Software Update")
        } footer: {
            if case .available = updates.state, updates.canInstallAutomatically {
                Text(
                    updates.installSource == .homebrew
                        ? "AVD Studio is managed by Homebrew, so Install runs the Homebrew upgrade for you and reopens the app."
                        : "Install downloads the new version from GitHub, checks it, replaces this copy and reopens AVD Studio."
                )
            }
        }
    }

    @ViewBuilder
    private func available(_ release: AppRelease, _ updates: UpdateModel) -> some View {
        let details = [
            release.publishedAt.map { "Released " + $0.formatted(.dateTime.day().month(.abbreviated).year().locale(locale)) },
            release.asset?.size.map { $0.formatted(ByteCountFormatStyle(style: .file, locale: locale)) },
        ].compactMap { $0 }
        if !details.isEmpty { Text(details.joined(separator: " · ")).foregroundStyle(.secondary) }
        HStack {
            Button("Not Now") {}.hidden()
            Spacer()
            if updates.canInstallAutomatically {
                if release.asset == nil && updates.installSource != .homebrew {
                    Button("Open Release Page") { updates.openReleasePage() }.buttonStyle(.borderedProminent)
                } else {
                    Button("Install \(release.version.description)") { updates.install() }.buttonStyle(.borderedProminent)
                }
            } else if updates.installSource == .homebrew {
                Button("Copy Brew Command") { Clipboard.copy(InstallSource.brewUpgradeCommand) }.buttonStyle(.borderedProminent)
            } else {
                Button("Download \(release.version.description)") { updates.startDownload() }.buttonStyle(.borderedProminent)
            }
        }
    }

    private func problem(_ text: String) -> some View {
        Label {
            Text(text).textSelection(.enabled)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
    }
}
