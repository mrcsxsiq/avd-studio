import SwiftUI

struct SidebarView: View {
    @Bindable var model: AppModel

    var body: some View {
        List(selection: $model.sidebarSelection) {
            Section("Library") {
                row(.all, title: "All Devices", symbol: "square.grid.2x2.fill", tint: .accentColor)
                ForEach(model.availableKinds) { kind in
                    row(.kind(kind), title: kind.pluralTitle, symbol: kind.symbolName, tint: kind.tint)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) { SDKStatusFooter(toolchain: model.toolchain, running: model.runningCount) }
    }

    private func row(_ item: SidebarItem, title: String, symbol: String, tint: Color) -> some View {
        Label {
            HStack {
                Text(title)
                Spacer()
                Text("\(model.count(for: item))")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: symbol).foregroundStyle(tint)
        }
        .tag(item)
    }
}

struct SDKStatusFooter: View {
    let toolchain: ToolchainSummary?
    let running: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            HStack(spacing: 8) {
                Image(systemName: statusSymbol).foregroundStyle(statusColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text(statusTitle).font(.callout.weight(.medium))
                    if running > 0 {
                        Text("\(running) running").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .background(.bar)
    }

    private var isReady: Bool { toolchain?.isConfigured == true }
    private var statusSymbol: String { isReady ? "checkmark.seal.fill" : "exclamationmark.triangle.fill" }
    private var statusColor: Color { isReady ? .green : .orange }
    private var statusTitle: String { toolchain == nil ? "Checking Android SDK…" : isReady ? "Android SDK ready" : "Android SDK setup needed" }
}
