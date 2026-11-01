import SwiftUI

/// The dialog for downloading Android system images: pick the versions, accept Google's license, press Download.
/// The download runs in the background, so the dialog can be closed while it goes on.
struct DownloadImagesView: View {
    @Bindable var images: SystemImagesModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, 24).padding(.vertical, 16)
            Divider()
            content
            Divider()
            footer.padding(.horizontal, 24).padding(.vertical, 14)
        }
        .frame(width: 540, height: 620)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "square.and.arrow.down.on.square.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Download Android system images").font(.title3.weight(.semibold))
                Text("Pick the Android versions you want to create devices with.").font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: List

    @ViewBuilder
    private var content: some View {
        switch images.catalog {
        case .notLoaded, .loading:
            VStack(spacing: 10) {
                ProgressView()
                Text("Asking Google for the list. This takes a few seconds.").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundStyle(.orange)
                Text(message).multilineTextAlignment(.center).textSelection(.enabled).frame(maxWidth: 400)
                Button("Try Again") { Task { await images.loadCatalog() } }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        case .loaded:
            loaded
        }
    }

    private var loaded: some View {
        VStack(spacing: 0) {
            Form {
                Picker("Show", selection: $images.familyFilter) {
                    ForEach(SystemImagesModel.FamilyFilter.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Include previews and test images", isOn: $images.showAdvanced)
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .frame(height: 124)

            let groups = images.downloadableGroups
            if groups.isEmpty {
                Text("Everything that matches is already installed.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(groups, id: \.title) { group in
                            Text(group.title).font(.subheadline.weight(.semibold)).padding(.top, 10).padding(.bottom, 2)
                            ForEach(group.images) { image in
                                RemoteImageRow(
                                    image: image,
                                    isSelected: Binding(get: { images.isSelected(image) }, set: { _ in images.toggle(image) })
                                )
                                .disabled(images.work.isBusy)
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            if case .installing(let progress) = images.work {
                DownloadProgressView(progress: progress)
                Text("You can close this window. The download keeps going and shows up in Settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if case .failed(let output) = images.work {
                Label("That did not work", systemImage: "xmark.octagon.fill").foregroundStyle(.red).fontWeight(.medium)
                Text(output).font(.system(.caption, design: .monospaced)).textSelection(.enabled).foregroundStyle(.secondary)
                    .lineLimit(5)
            } else if let notice = images.notice {
                Label(notice, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            }

            if case .loaded = images.catalog {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Toggle(isOn: $images.acceptedLicense) {
                            Text("I have read and accept the Android SDK License Agreement")
                        }
                        .toggleStyle(.checkbox)
                        Button("Read the agreement") { openURL(SetupPlan.licenseURL) }.buttonStyle(.link).padding(.leading, 20)
                    }
                    Spacer(minLength: 8)
                }
            }

            HStack {
                Text(SystemImagesSettingsTab.selectionSummary(count: images.selection.count)).foregroundStyle(.secondary)
                Spacer()
                Button(images.work.isBusy ? "Close" : "Cancel") { images.closePicker() }.keyboardShortcut(.cancelAction)
                Button(SystemImagesSettingsTab.downloadTitle(count: images.selection.count)) { Task { await images.install() } }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!images.canInstall)
            }
        }
    }
}

/// One image Google offers, with a checkbox.
struct RemoteImageRow: View {
    let image: RemoteSystemImage
    @Binding var isSelected: Bool

    var body: some View {
        Toggle(isOn: $isSelected) {
            HStack(spacing: 6) {
                Text(image.tagDisplay)
                if image.hasPlayStore { Image(systemName: "play.square.fill").foregroundStyle(.green).help("Includes Google Play") }
                if image.isPreview { badge("Preview", color: .orange) }
                if image.isAutomatedTestImage { badge("Test image", color: .gray) }
                Spacer(minLength: 8)
                Text(image.revision).font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .toggleStyle(.checkbox)
        .accessibilityLabel(image.displayName)
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .foregroundStyle(color)
            .background(color.opacity(0.15), in: Capsule())
    }
}
