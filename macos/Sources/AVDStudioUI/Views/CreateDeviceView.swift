import SwiftUI

/// The "New Device" sheet.
public struct CreateDeviceView: View {
    @Bindable var model: CreateDeviceModel
    let onCreated: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    public init(model: CreateDeviceModel, onCreated: @escaping (String) -> Void) {
        self.model = model
        self.onCreated = onCreated
    }

    public var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, 24).padding(.vertical, 18)
            Divider()
            content
            Divider()
            footer.padding(.horizontal, 20).padding(.vertical, 14)
        }
        .frame(width: 600, height: 640)
        .task { if model.phase == .loading { await model.load() } }
        .onChange(of: model.phase) { _, phase in
            if case .created(let name) = phase {
                onCreated(name)
                dismiss()
            }
        }
        .alert("Could not create the device", isPresented: errorBinding, presenting: model.errorMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: {
            Text($0)
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "plus.rectangle.on.rectangle")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(
                    DevicePalette(kind: model.kind, seed: model.device?.id ?? "new").gradient,
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("New Virtual Device").font(.title2.weight(.bold))
                Text("Pick a type, a hardware definition and an Android version.").foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            ProgressView("Reading the device catalog…").frame(maxWidth: .infinity, maxHeight: .infinity)
        case .unavailable(let message):
            ContentUnavailableView {
                Label("Can't read the device catalog", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { Task { await model.load() } }
            }
        case .ready, .creating, .created:
            form
        }
    }

    private var form: some View {
        Form {
            Section {
                Picker("Type", selection: $model.kind) {
                    ForEach(model.availableKinds) { kind in
                        Label(kind.title, systemImage: kind.symbolName).tag(kind)
                    }
                }
                .pickerStyle(.menu)

                Picker("Hardware", selection: $model.device) {
                    ForEach(model.devicesForKind) { profile in
                        Text(profile.manufacturer == "Google" ? profile.name : "\(profile.name) · \(profile.manufacturer)").tag(
                            Optional(profile))
                    }
                }

                if model.imagesForKind.isEmpty {
                    noImages
                } else {
                    Picker("Android", selection: $model.image) {
                        ForEach(model.imagesForKind) { image in
                            Text(image.displayName).tag(Optional(image))
                        }
                    }
                    if let image = model.image, !image.isNativeOnAppleSilicon {
                        Label(
                            "\(image.abi) images are emulated on Apple Silicon and run slowly. Prefer arm64-v8a.", systemImage: "tortoise"
                        )
                        .font(.callout)
                        .foregroundStyle(.orange)
                    }
                }
            } header: {
                Text("Device")
            }

            Section {
                TextField("Name", text: $model.name, prompt: Text("Pixel_9_API_36"))
                    .textFieldStyle(.roundedBorder)
                if let error = model.nameError {
                    Text(error).font(.callout).foregroundStyle(.red)
                } else {
                    Text("Used by `emulator -avd` and the CLI. Letters, digits, dots, dashes and underscores.").font(.callout)
                        .foregroundStyle(.secondary)
                }
                TextField("Display name", text: $model.displayName, prompt: Text(model.device?.name ?? "Optional"))
                    .textFieldStyle(.roundedBorder)
            } header: {
                Text("Name")
            }

            Section {
                Picker("RAM", selection: $model.ram) { ForEach(RAMPreset.allCases) { Text($0.title).tag($0) } }
                Picker("Internal storage", selection: $model.storage) { ForEach(StoragePreset.allCases) { Text($0.title).tag($0) } }
                Picker("SD card", selection: $model.sdCard) { ForEach(SDCardPreset.allCases) { Text($0.title).tag($0) } }
            } header: {
                Text("Hardware")
            } footer: {
                Text(
                    "Google Play is included when the image has it. The GPU, keyboard and device frame are enabled, like Android Studio does."
                )
            }
        }
        .formStyle(.grouped)
        .disabled(model.phase == .creating)
    }

    private var noImages: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("No system image for \(model.kind.pluralTitle.lowercased()) is installed", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Install one with sdkmanager, for example:").font(.callout).foregroundStyle(.secondary)
            HStack {
                Text(suggestedPackage).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                Button("Copy") { Clipboard.copy("sdkmanager \"\(suggestedPackage)\"") }.controlSize(.small)
            }
            Text("Then come back and choose it here.").font(.callout).foregroundStyle(.secondary)
        }
    }

    private var suggestedPackage: String {
        let tag: String =
            switch model.kind {
            case .tv: "android-tv"
            case .wearOS: "android-wear"
            case .automotive: "android-automotive"
            case .desktop: "android-desktop"
            case .xr: "android-xr"
            default: "google_apis_playstore"
            }
        return "system-images;android-36;\(tag);arm64-v8a"
    }

    @ViewBuilder
    private var footer: some View {
        HStack {
            if model.phase == .creating {
                ProgressView().controlSize(.small)
                Text("Creating…").foregroundStyle(.secondary)
            }
            Spacer()
            Button("Cancel") { dismiss() }.disabled(model.phase == .creating)
            Button("Create") { Task { await model.create() } }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canCreate)
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
    }
}
