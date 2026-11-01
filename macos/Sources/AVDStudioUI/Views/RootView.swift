import AppKit
import SwiftUI

public struct RootView: View {
    @Bindable var model: AppModel
    @Environment(UpdateModel.self) private var updates: UpdateModel?
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        NavigationSplitView {
            SidebarView(model: model)
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 300)
        } detail: {
            detail
                .navigationTitle(model.currentTitle)
                .navigationSubtitle(subtitle)
        }
        .searchable(text: $model.searchText, placement: .toolbar, prompt: "Search devices")
        .toolbar {
            ToolbarItem {
                Button {
                    model.presentCreateDevice()
                } label: {
                    Label("New Device", systemImage: "plus")
                }
                .help("Create a virtual device (⌘N)")
                .disabled(model.needsSetup)
            }
            if let release = updates?.availableRelease {
                ToolbarItem {
                    Button {
                        openWindow(id: "updates")
                    } label: {
                        Label("Update to \(release.version.description)", systemImage: "arrow.down.circle.fill")
                            .symbolRenderingMode(.multicolor)
                    }
                    .help("Version \(release.version.description) is available")
                }
            }
            ToolbarItem {
                Button {
                    Task { await model.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Reload devices (⌘R)")
                .disabled(model.isRefreshing)
            }
        }
        .frame(minWidth: 820, minHeight: 540)
        .alert("Something went wrong", isPresented: errorBinding, presenting: model.errorMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
        .sheet(item: $model.creating) { creating in
            CreateDeviceView(
                model: creating,
                onManageImages: {
                    model.settingsTab = .images
                    openSettings()
                }
            ) { name in Task { await model.deviceCreated(named: name) } }
        }
        // Images downloaded or removed in Settings show up in an open "New Device" sheet.
        .onChange(of: model.systemImages.installed) {
            if let creating = model.creating { Task { await creating.reloadImages() } }
        }
        .confirmationDialog(
            "Delete \(model.pendingDelete?.displayName ?? "this device")?",
            isPresented: deleteBinding,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { Task { await model.confirmDelete() } }
            Button("Cancel", role: .cancel) { model.pendingDelete = nil }
        } message: {
            Text("The device and everything stored on it are removed from \(model.pendingDelete?.path ?? "disk"). This cannot be undone.")
        }
        .confirmationDialog(
            "Wipe all data on \(model.pendingWipe?.displayName ?? "this device")?",
            isPresented: wipeBinding,
            titleVisibility: .visible
        ) {
            Button("Wipe Data and Start", role: .destructive) { Task { await model.confirmWipe() } }
            Button("Cancel", role: .cancel) { model.pendingWipe = nil }
        } message: {
            Text("The device is reset to factory state: apps, accounts and files on it are deleted. This cannot be undone.")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await model.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .avdStudioShowUpdates)) { _ in
            openWindow(id: "updates")
        }
    }

    @ViewBuilder
    private var detail: some View {
        if !model.hasLoaded {
            ProgressView("Looking for virtual devices…")
        } else if model.needsSetup && model.devices.isEmpty {
            SetupView(model: model)
        } else {
            VStack(spacing: 0) {
                if model.needsSetup, let toolchain = model.toolchain {
                    SetupBanner(summary: toolchain.summary)
                }
                DeviceGridView(model: model)
            }
        }
    }

    private var subtitle: String {
        let count = model.visibleDevices.count
        return count == 1 ? "1 device" : "\(count) devices"
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { model.pendingDelete != nil }, set: { if !$0 { model.pendingDelete = nil } })
    }

    private var wipeBinding: Binding<Bool> {
        Binding(get: { model.pendingWipe != nil }, set: { if !$0 { model.pendingWipe = nil } })
    }
}

struct SetupBanner: View {
    let summary: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(summary).font(.callout)
            Spacer()
            SettingsLink { Text("Open Settings") }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.orange.opacity(0.12))
        .overlay(alignment: .bottom) { Divider() }
    }
}

extension CreateDeviceModel: Identifiable {}
