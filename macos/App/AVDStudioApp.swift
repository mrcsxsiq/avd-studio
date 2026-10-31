import AVDStudioKit
import AVDStudioUI
import SwiftUI

@main
struct AVDStudioApp: App {
    private let model: AppModel
    private let updates: UpdateModel
    @AppStorage(AppSettings.showMenuBarItemKey) private var showMenuBarItem = true

    init() {
        // Apply the saved theme before the first window appears, so there is no light/dark flash.
        (AppearanceMode(rawValue: UserDefaults.standard.string(forKey: AppSettings.appearanceKey) ?? "") ?? .system).apply()

        let model = AppModel(service: KotlinDeviceService())
        model.startMonitoring()
        self.model = model

        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let updates = UpdateModel(
            currentVersion: shortVersion.flatMap(AppVersion.init) ?? AppVersion(major: 0),
            source: GitHubReleaseSource(owner: "mrcsxsiq", repository: "avd-studio"),
            notifier: SystemUpdateNotifier()
        )
        updates.startAutomaticChecks()
        self.updates = updates
    }

    var body: some Scene {
        Window("AVD Studio", id: "main") {
            RootView(model: model)
                .environment(updates)
        }
        .defaultSize(width: 1040, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Device…") { model.presentCreateDevice() }
                    .keyboardShortcut("n", modifiers: .command)
                    .disabled(model.needsSetup)
            }
            CommandGroup(after: .toolbar) {
                Button("Refresh Devices") { Task { await model.refresh() } }
                    .keyboardShortcut("r", modifiers: .command)
            }
            UpdateCommands(updates: updates)
        }

        Window("Software Update", id: "updates") {
            UpdateView(model: updates)
                .task {
                    if case .idle = updates.state { await updates.checkForUpdates() }
                }
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        MenuBarExtra(isInserted: $showMenuBarItem) {
            MenuBarContent(model: model)
                .environment(updates)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
                .environment(updates)
        }
    }
}

/// "Check for Updates…" right under "About AVD Studio", where Mac users look for it.
struct UpdateCommands: Commands {
    let updates: UpdateModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check for Updates…") {
                openWindow(id: "updates")
                Task { await updates.checkForUpdates() }
            }
        }
    }
}

/// The menu bar icon. It also lives as long as the app does, so it is the place that reacts to a
/// clicked "update available" notification when every window is closed.
struct MenuBarLabel: View {
    let model: AppModel
    @AppStorage(AppSettings.menuBarIconKey) private var icon = MenuBarIcon.phone
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(nsImage: icon.image(running: model.runningCount > 0))
            .accessibilityLabel("AVD Studio")
            .onReceive(NotificationCenter.default.publisher(for: .avdStudioShowUpdates)) { _ in
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "updates")
            }
    }
}
