import AppKit
import SwiftUI

/// A small About window: who and which version, one thing to do (star the project), and the usual links.
public struct AboutView: View {
    let model: AboutModel
    let icon: NSImage

    public init(model: AboutModel, icon: NSImage = NSApplication.shared.applicationIconImage) {
        self.model = model
        self.icon = icon
    }

    public var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 104, height: 104)
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text(model.info.name)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text(model.info.versionLine)
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Text("Every Android emulator, one click away.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Button {
                    model.starRepository()
                } label: {
                    Label("Star on GitHub", systemImage: "star.fill")
                        .frame(maxWidth: 200)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.large)
                .accessibilityHint("Opens the repository on GitHub, where you can star it")

                Text("Opens GitHub. One click on Star there, and it helps others find the project.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 260)
            }
            .padding(.top, 4)

            Divider().padding(.vertical, 2)

            HStack(spacing: 18) {
                Button("Website", action: model.openWebsite)
                Button("Changelog", action: model.openChangelog)
                Button("License", action: model.openLicense)
            }
            .buttonStyle(.link)

            Text("MIT License · © 2026 Marcos Paulo Farias")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(28)
        .frame(width: 340)
    }
}

/// The About page as a Settings tab: the same view as the About window, centred in the tab.
struct AboutSettingsTab: View {
    @State private var model = AboutModel()

    var body: some View {
        AboutView(model: model)
            .frame(width: SettingsTab.about.size.width, height: SettingsTab.about.size.height)
    }
}
