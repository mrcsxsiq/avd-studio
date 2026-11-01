import AppKit
import SwiftUI

/// Appearance, where the app shows up (Dock and menu bar) and updates.
struct GeneralSettingsTab: View {
    @Bindable var model: AppModel
    @AppStorage(AppSettings.showMenuBarItemKey) private var showMenuBarItem = true
    @AppStorage(AppSettings.showInDockKey) private var showInDock = true
    @AppStorage(AppSettings.appearanceKey) private var appearance = AppearanceMode.system
    @AppStorage(AppSettings.menuBarIconKey) private var menuBarIcon = MenuBarIcon.phone
    @Environment(UpdateModel.self) private var updates: UpdateModel?
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.symbolName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: appearance) { _, mode in mode.apply() }
            }

            Section {
                Toggle("Show AVD Studio in the Dock", isOn: dockBinding)
                    .disabled(presence.dockIsLastPlace)
                Toggle("Show AVD Studio in the menu bar", isOn: menuBarBinding)
                    .disabled(presence.menuBarIsLastPlace)
            } header: {
                Text("Where AVD Studio appears")
            } footer: {
                Text(presenceFooter)
            }

            Section {
                MenuBarIconPicker(selection: $menuBarIcon)
                    .disabled(!presence.showInMenuBar)
                    .opacity(presence.showInMenuBar ? 1 : 0.5)
            } header: {
                Text("Menu bar icon")
            } footer: {
                Text("Click a device in the menu bar list to start it right away. A dot on the icon means an emulator is running.")
            }

            if let updates { updatesSection(updates) }
        }
        .formStyle(.grouped)
        .frame(width: SettingsTab.general.size.width, height: SettingsTab.general.size.height)
        .onChange(of: showInDock) { _, _ in
            presence.apply()
            // Changing the activation policy sends the app to the background; bring Settings back.
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: Dock and menu bar

    /// The two switches, with the rule that at least one stays on (`AppPresence`).
    private var presence: AppPresence {
        AppPresence(showInMenuBar: showMenuBarItem, showInDock: showInDock)
    }

    private var dockBinding: Binding<Bool> {
        Binding(get: { presence.showInDock }, set: { store(presence.settingDock($0)) })
    }

    private var menuBarBinding: Binding<Bool> {
        Binding(get: { presence.showInMenuBar }, set: { store(presence.settingMenuBar($0)) })
    }

    private func store(_ presence: AppPresence) {
        showMenuBarItem = presence.showInMenuBar
        showInDock = presence.showInDock
    }

    private var presenceFooter: String {
        if presence.dockIsLastPlace {
            "The Dock icon stays on while the menu bar item is hidden, so you can always get back in."
        } else if presence.menuBarIsLastPlace {
            "The menu bar item stays on while the Dock icon is hidden, so you can always get back in."
        } else {
            "Hide either one, never both: AVD Studio always keeps a way back in."
        }
    }

    private func updatesSection(_ updates: UpdateModel) -> some View {
        Section {
            LabeledContent("Version", value: updates.currentVersion.description)
            if let release = updates.availableRelease {
                LabeledContent("Available") {
                    Text(release.version.description).foregroundStyle(Color.accentColor).fontWeight(.semibold)
                }
            }
            Toggle(
                "Check for updates automatically",
                isOn: Binding(get: { updates.automaticChecks }, set: { updates.automaticChecks = $0 })
            )
            Button(updates.hasUpdate ? "View Update…" : "Check for Updates…") {
                openWindow(id: "updates")
                if !updates.hasUpdate { Task { await updates.checkForUpdates() } }
            }
        } header: {
            Text("Updates")
        } footer: {
            Text("AVD Studio looks for new versions when it opens and every few hours, and notifies you when one is released.")
        }
    }
}
