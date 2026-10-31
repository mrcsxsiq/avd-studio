import SwiftUI

/// Shown when no usable Android SDK is found: explains what is missing and offers the ways out.
struct SetupView: View {
    @Bindable var model: AppModel

    static let brewCommand = "brew install --cask android-commandlinetools"

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.white)
                    .padding(22)
                    .background(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .shadow(color: .indigo.opacity(0.4), radius: 14, y: 8)

                VStack(spacing: 6) {
                    Text("Android SDK not found").font(.largeTitle.weight(.bold))
                    Text(
                        "AVD Studio manages emulators with Google's command-line tools. Point it to an SDK you already have, or install the tools."
                    )
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
                }

                if let toolchain = model.toolchain {
                    ToolList(toolchain: toolchain)
                }

                VStack(spacing: 10) {
                    Button {
                        if let path = FolderPicker.choose(message: "Choose your Android SDK folder", startingAt: model.toolchain?.sdkPath) {
                            Task { await model.update(locations: Locations(sdkPath: path, avdHome: model.locations.avdHome)) }
                        }
                    } label: {
                        Label("Choose SDK Folder…", systemImage: "folder.badge.gearshape").frame(maxWidth: 260)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        Clipboard.copy(Self.brewCommand)
                    } label: {
                        Label("Copy Homebrew Install Command", systemImage: "terminal").frame(maxWidth: 260)
                    }
                    .controlSize(.large)

                    Button("Check Again") { Task { await model.refresh() } }
                        .buttonStyle(.link)
                }

                Text(Self.brewCommand)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(40)
            .frame(maxWidth: .infinity)
        }
    }
}

struct ToolList: View {
    let toolchain: ToolchainSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(toolchain.tools) { tool in
                HStack(spacing: 10) {
                    Image(systemName: symbol(for: tool.state)).foregroundStyle(color(for: tool.state)).frame(width: 18)
                    Text(tool.name).font(.system(.body, design: .monospaced))
                    Spacer()
                    Text(label(for: tool.state)).font(.callout).foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                if tool.id != toolchain.tools.last?.id { Divider() }
            }
        }
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(maxWidth: 420)
        .accessibilityElement(children: .contain)
    }

    private func symbol(for state: ToolchainSummary.Tool.State) -> String {
        state == .available ? "checkmark.circle.fill" : "xmark.circle.fill"
    }

    private func color(for state: ToolchainSummary.Tool.State) -> Color {
        state == .available ? .green : .red
    }

    private func label(for state: ToolchainSummary.Tool.State) -> String {
        switch state {
        case .available: "Found"
        case .missing: "Missing"
        case .deprecated: "Outdated location"
        }
    }
}
