import AVDStudioKit
import AVDStudioUI
import SwiftUI

/// Applies the "show in the Dock" preference as the app starts, before the first window appears. Without a Dock
/// icon the app is an accessory that lives in the menu bar; `AppPresence` guarantees one of the two is on.
final class PresenceDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        AppPresence.repairStored()
        AppPresence.stored().apply()
    }
}

extension Scene {
    /// With no Dock icon the app starts quietly in the menu bar instead of opening its window. Needs macOS 15; on
    /// macOS 14 the window still opens at launch.
    func opensWindowAtLaunch(_ opens: Bool) -> some Scene {
        if #available(macOS 15, *) {
            return defaultLaunchBehavior(opens ? .presented : .suppressed)
        } else {
            return self
        }
    }
}

@main
struct AVDStudioApp: App {
    @NSApplicationDelegateAdaptor(PresenceDelegate.self) private var delegate
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
            notifier: SystemUpdateNotifier(),
            installer: SystemUpdateInstaller()
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
        .opensWindowAtLaunch(AppPresence.stored().showInDock)
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
            AppInfoCommands(updates: updates)
        }

        Window("About AVD Studio", id: "about") {
            AboutView(model: AboutModel())
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

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

/// "About AVD Studio" and "Check for Updates…" at the top of the app menu, where Mac users look for them.
struct AppInfoCommands: Commands {
    let updates: UpdateModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About AVD Studio") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "about")
            }
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
