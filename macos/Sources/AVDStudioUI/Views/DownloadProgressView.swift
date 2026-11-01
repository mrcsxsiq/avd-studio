import SwiftUI

/// How a download is going: a moving bar (the total size is not known), which image, and the bytes received so far.
struct DownloadProgressView: View {
    let progress: SystemImagesModel.DownloadProgress
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView().progressViewStyle(.linear)
            HStack {
                Text(progress.imageName).fontWeight(.medium)
                Spacer()
                if progress.imageCount > 1 {
                    Text("\(progress.imageIndex) of \(progress.imageCount)").foregroundStyle(.secondary).monospacedDigit()
                }
            }
            Text(bytesText).font(.callout).foregroundStyle(.secondary).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Downloading \(progress.imageName). \(bytesText)")
    }

    var bytesText: String {
        progress.bytesDownloaded == 0
            ? "Starting…"
            : "\(progress.bytesDownloaded.formatted(ByteCountFormatStyle(style: .file, locale: locale))) downloaded"
    }
}
