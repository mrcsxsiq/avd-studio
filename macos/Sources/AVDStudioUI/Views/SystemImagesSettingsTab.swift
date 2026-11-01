import SwiftUI

/// Settings > System Images: what is installed and how much room it takes, downloading more Android versions, and
/// removing the ones no longer needed.
struct SystemImagesSettingsTab: View {
    @Bindable var model: AppModel
    @Environment(\.openURL) private var openURL
    @Environment(\.locale) private var locale

    private var images: SystemImagesModel { model.systemImages }

    var body: some View {
        @Bindable var images = model.systemImages
        Form {
            if let status = statusMessage { Section { status } }
            installedSection
            downloadSection
        }
        .formStyle(.grouped)
        .frame(width: SettingsTab.images.size.width, height: SettingsTab.images.size.height)
        // Read again every time the tab opens: Android Studio or a terminal may have changed the folder.
        .task { await images.loadInstalled() }
        .sheet(isPresented: $images.isPickerPresented) { DownloadImagesView(images: images) }
        .confirmationDialog(
            "Remove this system image?",
            isPresented: Binding(get: { images.pendingRemoval != nil }, set: { if !$0 { images.cancelRemoval() } }),
            titleVisibility: .visible,
            presenting: images.pendingRemoval
        ) { removal in
            Button("Remove", role: .destructive) { Task { await images.confirmRemoval(removal) } }
            Button("Cancel", role: .cancel) { images.cancelRemoval() }
        } message: { removal in
            Text(Self.removalMessage(removal, locale: locale))
        }
    }

    // MARK: Installed

    private var installedSection: some View {
        Section {
            if !images.hasLoadedInstalled {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Looking at the SDK…").foregroundStyle(.secondary)
                }
            } else if images.installed.isEmpty {
                Text("No system images are installed yet. Download one below to create virtual devices.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(images.installed) { image in
                    InstalledImageRow(
                        image: image, usedBy: images.devices(using: image).count, canRemove: !images.work.isBusy
                    ) { images.requestRemoval(of: image) }
                }
            }
        } header: {
            HStack {
                Text("Installed")
                Spacer()
                if images.installedBytes > 0 {
                    Text(Self.size(images.installedBytes, locale: locale)).foregroundStyle(.secondary).monospacedDigit()
                }
            }
        } footer: {
            Text(
                "Each virtual device boots from one of these. Removing an image frees its space; "
                    + "devices that use it stop working until you download it again.")
        }
    }

    // MARK: Download

    private var downloadSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text(
                    "Pick other Android versions from the list Google publishes for Apple Silicon: Google Play, Google APIs, TV, Wear OS and more."
                )
                Button("Download More Images…") { images.openPicker() }
                    .buttonStyle(.borderedProminent)
            }
        } header: {
            Text("Download more")
        } footer: {
            Text(
                "Images are large, often over 1 GB each. AVD Studio asks Google's servers (through sdkmanager) "
                    + "only when you open the list. The download keeps going if you close the window.")
        }
    }

    // MARK: Status

    private var statusMessage: AnyView? {
        switch images.work {
        case .installing(let progress):
            return AnyView(DownloadProgressView(progress: progress))
        case .removing(let name):
            return AnyView(
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Removing \(name)…")
                })
        case .failed(let output):
            return AnyView(
                VStack(alignment: .leading, spacing: 6) {
                    Label("That did not work", systemImage: "xmark.octagon.fill").foregroundStyle(.red).fontWeight(.medium)
                    Text(output)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                    Button("Dismiss") { images.dismissFailure() }.controlSize(.small)
                })
        case .idle:
            guard let notice = images.notice else { return nil }
            return AnyView(Label(notice, systemImage: "checkmark.circle.fill").foregroundStyle(.green))
        }
    }

    // MARK: Text

    /// `1.9 GB`, in the user's language.
    static func size(_ bytes: Int64, locale: Locale) -> String {
        bytes.formatted(ByteCountFormatStyle(style: .file, locale: locale))
    }

    static func selectionSummary(count: Int) -> String {
        count == 0 ? "Nothing selected" : (count == 1 ? "1 image selected" : "\(count) images selected")
    }

    static func downloadTitle(count: Int) -> String {
        count <= 1 ? "Download" : "Download \(count) Images"
    }

    static func removalMessage(_ removal: SystemImagesModel.Removal, locale: Locale = .current) -> String {
        var message = removal.image.displayName
        if let bytes = removal.image.sizeBytes {
            message += " frees \(size(bytes, locale: locale))."
        } else {
            message += " will be removed."
        }
        guard !removal.devices.isEmpty else { return message }
        let names = removal.devices.map(\.displayName).formatted(.list(type: .and))
        let noun = removal.devices.count == 1 ? "device boots" : "devices boot"
        return message + " These \(noun) from it and will not start until you download it again: \(names)."
    }
}

/// One installed image.
struct InstalledImageRow: View {
    @Environment(\.locale) private var locale
    let image: SystemImage
    let usedBy: Int
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: Self.kind(of: image).symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(
                    DevicePalette(kind: Self.kind(of: image), seed: image.id).gradient,
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(image.versionLabel)
                Text(subtitle).font(.callout).foregroundStyle(.secondary)
                if !image.isNativeOnAppleSilicon {
                    Text("Does not run on Apple Silicon").font(.caption).foregroundStyle(.orange)
                }
            }
            Spacer(minLength: 8)
            if usedBy > 0 {
                Text(usedBy == 1 ? "Used by 1 device" : "Used by \(usedBy) devices").font(.caption).foregroundStyle(.secondary)
            }
            Button(action: onRemove) { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .disabled(!canRemove)
                .help("Remove this image")
                .accessibilityLabel("Remove \(image.displayName)")
        }
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        var parts = [image.tagDisplay, image.abi]
        if let bytes = image.sizeBytes { parts.append(SystemImagesSettingsTab.size(bytes, locale: locale)) }
        return parts.joined(separator: " · ")
    }

    static func kind(of image: SystemImage) -> DeviceKind {
        switch image.family {
        case .general: .phone
        case .tv: .tv
        case .wearOS: .wearOS
        case .automotive: .automotive
        case .desktop: .desktop
        case .xr: .xr
        }
    }
}
