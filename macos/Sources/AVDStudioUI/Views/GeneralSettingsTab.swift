import SwiftUI

/// Appearance, the menu bar item and updates.
struct GeneralSettingsTab: View {
    @Bindable var model: AppModel
    @AppStorage(AppSettings.showMenuBarItemKey) private var showMenuBarItem = true
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
                Toggle("Show AVD Studio in the menu bar", isOn: $showMenuBarItem)
                MenuBarIconPicker(selection: $menuBarIcon)
                    .disabled(!showMenuBarItem)
                    .opacity(showMenuBarItem ? 1 : 0.5)
            } header: {
                Text("Menu bar")
            } footer: {
                Text("Click a device in the menu bar list to start it right away. A dot on the icon means an emulator is running.")
            }

            if let updates { updatesSection(updates) }
        }
        .formStyle(.grouped)
        .frame(width: SettingsTab.general.size.width, height: SettingsTab.general.size.height)
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
