import Foundation

/// One block of a release's notes, as the "What's new" view draws it.
public enum MarkdownBlock: Equatable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(String)
    /// `marker` is `•` for bullets and `1.` for numbered items; `depth` is 0 for a top-level item.
    case listItem(depth: Int, marker: String, text: String)
    case code(String)
    case quote(String)
    case rule
}

/// A small Markdown reader for GitHub release notes: headings, paragraphs, bullet and numbered lists (nested),
/// block quotes, fenced code and rules. The text inside a block keeps its inline Markdown (bold, code, links), which
/// `MarkdownInline` turns into styled text.
///
/// Release notes are usually hard-wrapped, so the lines of a paragraph or of one list item are joined with a space.
public enum MarkdownBlocks {
    public static func parse(_ markdown: String) -> [MarkdownBlock] {
        var parser = Parser()
        for line in markdown.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
        {
            parser.feed(String(line))
        }
        return parser.finish()
    }

    private struct Parser {
        private var blocks: [MarkdownBlock] = []
        private var paragraph: [String] = []
        private var quote: [String] = []
        private var item: (depth: Int, marker: String, indent: Int, text: String)?
        private var indentStack: [Int] = []
        private var fence: String?
        private var code: [String] = []

        mutating func feed(_ line: String) {
            if let open = fence {
                if line.trimmingCharacters(in: .whitespaces).hasPrefix(open) {
                    blocks.append(.code(code.joined(separator: "\n")))
                    code = []
                    fence = nil
                } else {
                    code.append(line)
                }
                return
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                flushText()
                return
            }
            if let marker = ["```", "~~~"].first(where: { trimmed.hasPrefix($0) }) {
                flushText()
                fence = marker
                return
            }
            if let heading = Self.heading(trimmed) {
                flushText()
                blocks.append(heading)
                return
            }
            if Self.isRule(trimmed) {
                flushText()
                blocks.append(.rule)
                return
            }
            if trimmed.hasPrefix(">") {
                flushParagraph()
                flushItem()
                quote.append(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
                return
            }
            if let (indent, marker, text) = Self.listItem(line) {
                flushText()
                let depth = depth(forIndent: indent)
                item = (depth, marker, indent, text)
                return
            }

            // A line that is not structure continues whatever is open.
            flushQuoteIfNeeded()
            if item != nil {
                item?.text += " " + trimmed
            } else {
                paragraph.append(trimmed)
            }
        }

        mutating func finish() -> [MarkdownBlock] {
            if fence != nil { blocks.append(.code(code.joined(separator: "\n"))) }
            flushText()
            return blocks
        }

        // MARK: Flushing

        private mutating func flushText() {
            flushParagraph()
            flushItem()
            flushQuote()
        }

        private mutating func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append(.paragraph(paragraph.joined(separator: " ")))
            paragraph = []
        }

        private mutating func flushItem() {
            guard let item else { return }
            blocks.append(.listItem(depth: item.depth, marker: item.marker, text: item.text))
            self.item = nil
        }

        private mutating func flushQuote() {
            guard !quote.isEmpty else { return }
            blocks.append(.quote(quote.joined(separator: " ")))
            quote = []
        }

        private mutating func flushQuoteIfNeeded() {
            // A plain line right after a quote is a lazy continuation of it.
            if !quote.isEmpty, item == nil, paragraph.isEmpty { return }
            flushQuote()
        }

        /// Items indented deeper than the previous one nest under it; going back out pops to the matching level.
        private mutating func depth(forIndent indent: Int) -> Int {
            if indentStack.isEmpty { indentStack = [indent] }
            while let last = indentStack.last, indent < last, indentStack.count > 1 { indentStack.removeLast() }
            if let last = indentStack.last, indent > last { indentStack.append(indent) }
            return indentStack.count - 1
        }

        // MARK: Recognising lines

        private static func heading(_ trimmed: String) -> MarkdownBlock? {
            let hashes = trimmed.prefix { $0 == "#" }
            guard (1...6).contains(hashes.count) else { return nil }
            let rest = trimmed.dropFirst(hashes.count)
            guard rest.first == " " else { return nil }
            var text = rest.trimmingCharacters(in: .whitespaces)
            while text.hasSuffix("#") { text.removeLast() }
            return .heading(level: hashes.count, text: text.trimmingCharacters(in: .whitespaces))
        }

        private static func isRule(_ trimmed: String) -> Bool {
            let compact = trimmed.replacingOccurrences(of: " ", with: "")
            guard compact.count >= 3, let first = compact.first, "-*_".contains(first) else { return false }
            return compact.allSatisfy { $0 == first }
        }

        private static func listItem(_ line: String) -> (indent: Int, marker: String, text: String)? {
            let indent = line.prefix { $0 == " " || $0 == "\t" }.reduce(0) { $0 + ($1 == "\t" ? 4 : 1) }
            let body = line.trimmingCharacters(in: .whitespaces)
            if let first = body.first, "-*+".contains(first), body.dropFirst().first == " " {
                return (indent, "•", body.dropFirst(2).trimmingCharacters(in: .whitespaces))
            }
            let digits = body.prefix { $0.isNumber }
            if !digits.isEmpty, digits.count <= 9, let separator = body.dropFirst(digits.count).first, ".)".contains(separator),
                body.dropFirst(digits.count + 1).first == " "
            {
                return (indent, "\(digits).", body.dropFirst(digits.count + 2).trimmingCharacters(in: .whitespaces))
            }
            return nil
        }
    }
}

/// Inline Markdown (bold, italic, `code`, links) as styled text, with bare web addresses made clickable too.
public enum MarkdownInline {
    public static func attributed(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        var result = (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
        linkBareAddresses(in: &result)
        return result
    }

    /// GitHub turns plain `https://…` text into links; Markdown parsing alone does not.
    private static func linkBareAddresses(in text: inout AttributedString) {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return }
        let plain = String(text.characters)
        for match in detector.matches(in: plain, range: NSRange(plain.startIndex..., in: plain)) {
            guard let url = match.url, ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                let range = Range(match.range, in: plain),
                let start = AttributedString.Index(range.lowerBound, within: text),
                let end = AttributedString.Index(range.upperBound, within: text)
            else { continue }
            let span = start..<end
            // Leave alone anything Markdown already linked.
            if text[span].runs.contains(where: { $0.link != nil }) { continue }
            text[span].link = url
        }
    }
}
