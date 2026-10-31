import AVDStudioKit
import AVDStudioUI
import SwiftUI

@main
struct AVDStudioApp: App {
    private let model: AppModel
    @AppStorage(AppSettings.showMenuBarItemKey) private var showMenuBarItem = true

    init() {
        let model = AppModel(service: KotlinDeviceService())
        model.startMonitoring()
        self.model = model
    }

    var body: some Scene {
        Window("AVD Studio", id: "main") {
            RootView(model: model)
        }
        .defaultSize(width: 1040, height: 700)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Refresh Devices") { Task { await model.refresh() } }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }

        MenuBarExtra(isInserted: $showMenuBarItem) {
            MenuBarContent(model: model)
        } label: {
            Image(systemName: model.runningCount > 0 ? "iphone.gen3.radiowaves.left.and.right" : "iphone.gen3")
                .accessibilityLabel("AVD Studio")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
    }
}
