import SwiftUI

public enum AppSettings {
    /// `@AppStorage` key for the "show in menu bar" toggle.
    public static let showMenuBarItemKey = "showMenuBarItem"
    /// `@AppStorage` key for the theme (`AppearanceMode.rawValue`).
    public static let appearanceKey = "appearance"
    /// `@AppStorage` key for the menu bar icon (`MenuBarIcon.rawValue`).
    public static let menuBarIconKey = "menuBarIcon"
}

public struct SettingsView: View {
    @Bindable var model: AppModel
    @AppStorage(AppSettings.showMenuBarItemKey) private var showMenuBarItem = true
    @AppStorage(AppSettings.appearanceKey) private var appearance = AppearanceMode.system
    @AppStorage(AppSettings.menuBarIconKey) private var menuBarIcon = MenuBarIcon.phone
    @Environment(UpdateModel.self) private var updates: UpdateModel?
    @Environment(\.openWindow) private var openWindow
    @State private var sdkText = ""
    @State private var avdText = ""

    private let height: CGFloat

    public init(model: AppModel) {
        self.init(model: model, height: 720)
    }

    /// `height` is the window height; the form scrolls when it does not all fit (small displays).
    init(model: AppModel, height: CGFloat) {
        self.model = model
        self.height = height
    }

    public var body: some View {
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
                pathRow(title: "Folder", text: $sdkText, placeholder: "Detected automatically") {
                    choose(message: "Choose your Android SDK folder", current: model.toolchain?.sdkPath) { sdkText = $0 }
                }
                if let toolchain = model.toolchain {
                    LabeledContent("In use") {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(toolchain.sdkPath).textSelection(.enabled).lineLimit(1).truncationMode(.middle)
                            Text(toolchain.sourceDescription).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Label(
                        toolchain.summary, systemImage: toolchain.isConfigured ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(toolchain.isConfigured ? .green : .orange)
                }
            } header: {
                Text("Android SDK")
            } footer: {
                Text("Leave empty to use ANDROID_SDK_ROOT, ANDROID_HOME, Android Studio's folder or Homebrew, in that order.")
            }

            Section {
                pathRow(title: "Folder", text: $avdText, placeholder: "~/.android/avd") {
                    choose(message: "Choose the folder that holds your virtual devices", current: model.avdHome) { avdText = $0 }
                }
                LabeledContent("In use") {
                    Text(model.avdHome).textSelection(.enabled).lineLimit(1).truncationMode(.middle)
                }
            } header: {
                Text("Virtual devices")
            } footer: {
                Text("Pick a folder on an external drive to keep large emulators off your Mac. Existing devices are not moved.")
            }

            if let updates { updatesSection(updates) }

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

            Section {
                ForEach(model.diagnostics) { DiagnosticRow(item: $0) }
                Button("Run Diagnostics") { Task { await model.runDiagnostics() } }
            } header: {
                Text("Diagnostics")
            }
        }
        .formStyle(.grouped)
        .frame(width: 600, height: height)
        .onAppear { syncFields() }
        .task { await model.runDiagnostics() }
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

    private func pathRow(
        title: String,
        text: Binding<String>,
        placeholder: String,
        choose: @escaping () -> Void
    ) -> some View {
        LabeledContent(title) {
            HStack {
                TextField(title, text: text, prompt: Text(placeholder))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(apply)
                Button("Choose…", action: choose)
                if !text.wrappedValue.isEmpty {
                    Button {
                        text.wrappedValue = ""
                        apply()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .help("Go back to automatic detection")
                    .accessibilityLabel("Use automatic detection")
                }
            }
        }
    }

    private func choose(message: String, current: String?, assign: (String) -> Void) {
        if let path = FolderPicker.choose(message: message, startingAt: current) {
            assign(path)
            apply()
        }
    }

    private func apply() {
        Task { await model.update(locations: Locations(sdkPath: sdkText, avdHome: avdText)) }
    }

    private func syncFields() {
        sdkText = model.locations.sdkPath ?? ""
        avdText = model.locations.avdHome ?? ""
    }
}

struct DiagnosticRow: View {
    let item: DoctorItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(color).frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.body.weight(.medium))
                Text(item.detail).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                if let hint = item.hint {
                    Text(hint).font(.callout).foregroundStyle(item.status == .fail ? .red : .orange)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch item.status {
        case .pass: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .fail: "xmark.octagon.fill"
        }
    }

    private var color: Color {
        switch item.status {
        case .pass: .green
        case .warning: .orange
        case .fail: .red
        }
    }
}

/// Two rows of icons; the chosen one is outlined. Icons render as templates, so they follow the text colour.
struct MenuBarIconPicker: View {
    @Binding var selection: MenuBarIcon
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(MenuBarIcon.allCases) { icon in
                Button {
                    selection = icon
                } label: {
                    VStack(spacing: 4) {
                        Image(nsImage: icon.image(running: false))
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                        Text(icon.title).font(.caption2).lineLimit(1).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        selection == icon ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(selection == icon ? Color.accentColor : .clear, lineWidth: 2)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(icon.title)
                .accessibilityLabel("\(icon.title) icon")
                .accessibilityAddTraits(selection == icon ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}
