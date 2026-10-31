import AppKit
import SwiftUI

/// The popover behind the menu bar item: start, test and stop emulators without opening the main window.
public struct MenuBarContent: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 340)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                .font(.title2)
                .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom))
            VStack(alignment: .leading, spacing: 0) {
                Text("AVD Studio").font(.headline)
                Text(summary).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var content: some View {
        if !model.hasLoaded {
            ProgressView().padding(30)
        } else if model.needsSetup && model.devices.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").font(.title).foregroundStyle(.orange)
                Text("Android SDK not found").font(.headline)
                Text(model.toolchain?.summary ?? "").font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Open Settings…") { showSettings() }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        } else if model.devices.isEmpty {
            Text("No virtual devices found.").foregroundStyle(.secondary).padding(30)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    let running = model.devices.filter { model.runState(of: $0) == .running }
                    if !running.isEmpty { section("Running", devices: running) }
                    ForEach(model.availableKinds) { kind in
                        section(kind.pluralTitle, devices: model.devices(of: kind).filter { model.runState(of: $0) != .running })
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 400)
        }
    }

    @ViewBuilder
    private func section(_ title: String, devices: [VirtualDevice]) -> some View {
        if !devices.isEmpty {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.top, 6)
            ForEach(devices) { device in
                MenuBarRow(device: device, runState: model.runState(of: device)) {
                    Task { await model.togglePower(device) }
                }
                .contextMenu { DeviceActions(model: model, device: device) }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Button("Open AVD Studio") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            .buttonStyle(.link)
            Spacer()
            iconButton("arrow.clockwise", label: "Refresh") { Task { await model.refresh() } }
            iconButton("gearshape", label: "Settings") { showSettings() }
            iconButton("power", label: "Quit AVD Studio") { NSApp.terminate(nil) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).frame(width: 24, height: 24) }
            .buttonStyle(.borderless)
            .help(label)
            .accessibilityLabel(label)
    }

    private func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
    }

    private var summary: String {
        guard model.hasLoaded else { return "Loading…" }
        let total = model.devices.count
        let noun = total == 1 ? "device" : "devices"
        return model.runningCount > 0 ? "\(model.runningCount) running · \(total) \(noun)" : "\(total) \(noun)"
    }
}

struct MenuBarRow: View {
    let device: VirtualDevice
    let runState: RunState
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: device.kind.symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(DevicePalette(kind: device.kind, seed: device.id).gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(device.displayName).font(.body).lineLimit(1)
                    Text(subtitle).font(.caption).foregroundStyle(subtitleColor).lineLimit(1)
                }
                Spacer(minLength: 6)
                trailing
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isHovering ? Color.primary.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(runState == .starting || (!device.isLaunchable && runState == .idle))
        .onHover { isHovering = $0 }
        .accessibilityLabel(runState == .running ? "Stop \(device.displayName)" : "Start \(device.displayName)")
    }

    @ViewBuilder
    private var trailing: some View {
        switch runState {
        case .running:
            Image(systemName: "stop.circle.fill").font(.title2).foregroundStyle(.red)
        case .starting:
            ProgressView().controlSize(.small)
        case .idle:
            Image(systemName: device.isLaunchable ? "play.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(device.isLaunchable ? Color.accentColor : .orange)
        }
    }

    private var subtitle: String {
        switch runState {
        case .running: "Running · \(device.releaseLabel)"
        case .starting: "Starting…"
        case .idle: device.isLaunchable ? device.releaseLabel : device.status.title
        }
    }

    private var subtitleColor: Color {
        switch runState {
        case .running: .green
        case .starting: .secondary
        case .idle: device.isLaunchable ? .secondary : .orange
        }
    }
}
