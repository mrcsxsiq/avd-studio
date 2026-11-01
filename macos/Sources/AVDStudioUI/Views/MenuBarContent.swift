import AppKit
import SwiftUI

/// The popover behind the menu bar item: start, test and stop emulators without opening the main window.
public struct MenuBarContent: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Environment(UpdateModel.self) private var updates: UpdateModel?

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            if let release = updates?.availableRelease { updateBanner(release) }
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
            VStack(spacing: 10) {
                Text("No virtual devices yet.").foregroundStyle(.secondary)
                Button("New Device…") { openCreate() }.buttonStyle(.borderedProminent).disabled(model.needsSetup)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        } else {
            // MenuBarExtra sizes its window from the content's *minimum* size, and a ScrollView's minimum is zero:
            // without an explicit height the whole list disappears. Rows and headers have fixed heights, so the
            // height is exact.
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    newDeviceRow
                    let running = model.devices.filter { model.runState(of: $0) == .running }
                    if !running.isEmpty { section("Running", devices: running) }
                    ForEach(model.availableKinds) { kind in
                        section(kind.pluralTitle, devices: model.devices(of: kind).filter { model.runState(of: $0) != .running })
                    }
                }
                .padding(PopoverLayout.listPadding)
            }
            .frame(height: listHeight)
        }
    }

    /// Height of the list: every row and section header has a fixed height, capped so the popover fits a laptop.
    var listHeight: CGFloat {
        let running = model.devices.contains { model.runState(of: $0) == .running }
        let kindsWithIdleDevices = model.availableKinds.filter { kind in
            model.devices(of: kind).contains { model.runState(of: $0) != .running }
        }
        let sections = (running ? 1 : 0) + kindsWithIdleDevices.count
        let rows = 1 + model.devices.count  // "New Device…" plus one per device
        let content =
            CGFloat(rows) * PopoverLayout.rowHeight + CGFloat(sections) * PopoverLayout.sectionHeaderHeight
            + 2 * PopoverLayout.listPadding
        return min(content, PopoverLayout.maxListHeight)
    }

    @ViewBuilder
    private func section(_ title: String, devices: [VirtualDevice]) -> some View {
        if !devices.isEmpty {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.bottom, 2)
                .frame(height: PopoverLayout.sectionHeaderHeight, alignment: .bottomLeading)
            ForEach(devices) { device in
                MenuBarRow(device: device, runState: model.runState(of: device)) {
                    Task { await model.togglePower(device) }
                }
                .contextMenu { DeviceActions(model: model, device: device) }
            }
        }
    }

    private func updateBanner(_ release: AppRelease) -> some View {
        Button {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "updates")
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill").foregroundStyle(.white)
                Text("Version \(release.version.description) is available").font(.callout.weight(.medium)).foregroundStyle(.white)
                Spacer()
                Text("Update").font(.callout.weight(.semibold)).foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Version \(release.version.description) is available. Open update window.")
    }

    private var newDeviceRow: some View {
        Button {
            openCreate()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text("New Device…").font(.body)
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(height: PopoverLayout.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.needsSetup)
        .accessibilityLabel("Create a new virtual device")
    }

    private func openCreate() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "main")
        model.presentCreateDevice()
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
            iconButton("arrow.down.circle", label: "Check for Updates") { showUpdates() }
            iconButton("info.circle", label: "About AVD Studio") { showAbout() }
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

    /// Opens the update window and looks for a release, unless one is already known (then it just shows it).
    private func showUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "updates")
        if let updates, !updates.hasUpdate { Task { await updates.checkForUpdates() } }
    }

    private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "about")
    }

    private func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
    }

    private var summary: String {
        guard model.hasLoaded else { return "Loading…" }
        let total = model.devices.count
        let noun = total == 1 ? "device" : "devices"
        return model.runningCount > 0 ? "\(model.runningCount) running · \(total) \(noun)" : "\(total) \(noun) · click one to start"
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
                    .background(
                        DevicePalette(kind: device.kind, seed: device.id).gradient,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(device.displayName).font(.body).lineLimit(1)
                    Text(subtitle).font(.caption).foregroundStyle(subtitleColor).lineLimit(1)
                }
                Spacer(minLength: 6)
                trailing
            }
            .padding(.horizontal, 8)
            .frame(height: PopoverLayout.rowHeight)
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

/// Fixed measurements of the menu bar popover (see `MenuBarContent.listHeight`).
enum PopoverLayout {
    static let rowHeight: CGFloat = 44
    static let sectionHeaderHeight: CGFloat = 24
    static let listPadding: CGFloat = 8
    static let maxListHeight: CGFloat = 420
}
