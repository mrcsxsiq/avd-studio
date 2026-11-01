import SwiftUI

/// "What's new": a release's notes with their Markdown drawn (headings, lists, links, bold, code, quotes).
struct ReleaseNotesView: View {
    let markdown: String
    private let blocks: [MarkdownBlock]

    init(markdown: String) {
        self.markdown = markdown
        self.blocks = MarkdownBlocks.parse(markdown)
    }

    var isEmpty: Bool { blocks.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                view(for: block, isFirst: index == 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func view(for block: MarkdownBlock, isFirst: Bool) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(MarkdownInline.attributed(text))
                .font(Self.font(forHeading: level))
                .padding(.top, isFirst ? 0 : 8)
                .accessibilityAddTraits(.isHeader)
        case .paragraph(let text):
            Text(MarkdownInline.attributed(text)).font(.callout)
        case .listItem(let depth, let marker, let text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(marker).font(.callout).foregroundStyle(.secondary).frame(minWidth: 14, alignment: .trailing)
                Text(MarkdownInline.attributed(text)).font(.callout)
            }
            .padding(.leading, CGFloat(depth) * 18)
        case .code(let code):
            Text(code)
                .font(.system(.caption, design: .monospaced))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        case .quote(let text):
            HStack(spacing: 8) {
                Capsule().fill(.secondary.opacity(0.5)).frame(width: 3)
                Text(MarkdownInline.attributed(text)).font(.callout).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        case .rule:
            Divider().padding(.vertical, 4)
        }
    }

    static func font(forHeading level: Int) -> Font {
        switch level {
        case 1: .title3.weight(.bold)
        case 2: .headline.weight(.bold)
        case 3: .subheadline.weight(.semibold)
        default: .callout.weight(.semibold)
        }
    }
}

/// The card around the notes: title, then the rendered Markdown.
struct ReleaseNotesCard: View {
    let notes: String

    var body: some View {
        let content = ReleaseNotesView(markdown: notes)
        if !content.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("What's new").font(.headline)
                content
                    .padding(14)
                    .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .frame(maxWidth: 460, alignment: .leading)
        }
    }
}
