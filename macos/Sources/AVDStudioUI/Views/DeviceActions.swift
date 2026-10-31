import AppKit
import SwiftUI

/// The actions available for one device; shared by the card's context menu and the menu bar.
struct DeviceActions: View {
    let model: AppModel
    let device: VirtualDevice

    var body: some View {
        let state = model.runState(of: device)

        if state == .running {
            Button("Stop", systemImage: "stop.fill") { Task { await model.stop(device) } }
        } else {
            Button("Start", systemImage: "play.fill") { Task { await model.launch(device) } }
                .disabled(!device.isLaunchable || state == .starting)
            Button("Cold Boot", systemImage: "snowflake") {
                Task { await model.launch(device, options: LaunchOptions(coldBoot: true)) }
            }
            .disabled(!device.isLaunchable || state == .starting)
            Button("Wipe Data and Start…", systemImage: "trash", role: .destructive) { model.pendingWipe = device }
                .disabled(!device.isLaunchable || state == .starting)
        }

        Divider()
        Button("Show in Finder", systemImage: "folder") {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: device.path)])
        }
        .disabled(device.path.isEmpty)
        Button("Copy Name", systemImage: "doc.on.doc") { Clipboard.copy(device.id) }
    }
}

enum Clipboard {
    @MainActor
    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

enum FolderPicker {
    @MainActor
    static func choose(message: String, startingAt path: String? = nil) -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.showsHiddenFiles = true
        panel.message = message
        panel.prompt = "Choose"
        if let path, !path.isEmpty { panel.directoryURL = URL(fileURLWithPath: path) }
        return panel.runModal() == .OK ? panel.url?.path : nil
    }
}
