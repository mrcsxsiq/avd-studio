import SwiftUI

public enum AppSettings {
    /// `@AppStorage` key for the "show in menu bar" toggle.
    public static let showMenuBarItemKey = "showMenuBarItem"
}

public struct SettingsView: View {
    @Bindable var model: AppModel
    @AppStorage(AppSettings.showMenuBarItemKey) private var showMenuBarItem = true
    @State private var sdkText = ""
    @State private var avdText = ""

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        Form {
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
                    Label(toolchain.summary, systemImage: toolchain.isConfigured ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
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

            Section("Menu bar") {
                Toggle("Show AVD Studio in the menu bar", isOn: $showMenuBarItem)
            }

            Section {
                ForEach(model.diagnostics) { DiagnosticRow(item: $0) }
                Button("Run Diagnostics") { Task { await model.runDiagnostics() } }
            } header: {
                Text("Diagnostics")
            }
        }
        .formStyle(.grouped)
        .frame(width: 600, height: 640)
        .onAppear { syncFields() }
        .task { await model.runDiagnostics() }
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
