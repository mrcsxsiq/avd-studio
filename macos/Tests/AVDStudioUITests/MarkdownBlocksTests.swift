import Foundation
import Testing

@testable import AVDStudioUI

@Suite("Markdown blocks")
struct MarkdownBlocksTests {
    @Test func readsTheGroupsAndEntriesOfOurOwnReleaseNotes() {
        let notes = """

            ### Added

            - **System Images** tab in Settings. It lists the installed images with the space each takes and the
              devices that use it, and removes images you no longer need.
            - Command line: `avdstudio images --available`.

            ### Fixed

            - Google XR images were classed as phones.
            """

        #expect(
            MarkdownBlocks.parse(notes) == [
                .heading(level: 3, text: "Added"),
                .listItem(
                    depth: 0, marker: "•",
                    text:
                        "**System Images** tab in Settings. It lists the installed images with the space each takes and the devices that use it, and removes images you no longer need."
                ),
                .listItem(depth: 0, marker: "•", text: "Command line: `avdstudio images --available`."),
                .heading(level: 3, text: "Fixed"),
                .listItem(depth: 0, marker: "•", text: "Google XR images were classed as phones."),
            ])
    }

    @Test func joinsTheWrappedLinesOfAParagraphWithASpace() {
        #expect(MarkdownBlocks.parse("first line\nsecond line\n\nnext") == [.paragraph("first line second line"), .paragraph("next")])
    }

    @Test func readsHeadingsOfEveryLevelAndIgnoresClosingHashes() {
        #expect(
            MarkdownBlocks.parse("# One\n## Two ##\n#### Four") == [
                .heading(level: 1, text: "One"), .heading(level: 2, text: "Two"), .heading(level: 4, text: "Four"),
            ])
    }

    @Test func aHashWithoutASpaceIsNotAHeading() {
        #expect(MarkdownBlocks.parse("#hashtag and #1") == [.paragraph("#hashtag and #1")])
    }

    @Test func readsNumberedListsKeepingTheirNumbers() {
        #expect(
            MarkdownBlocks.parse("1. first\n2. second\n10) tenth") == [
                .listItem(depth: 0, marker: "1.", text: "first"), .listItem(depth: 0, marker: "2.", text: "second"),
                .listItem(depth: 0, marker: "10.", text: "tenth"),
            ])
    }

    @Test func nestsListsByIndentWhetherTwoOrFourSpaces() {
        let two = MarkdownBlocks.parse("- a\n  - b\n    - c\n- d")
        let four = MarkdownBlocks.parse("- a\n    - b\n        - c\n- d")

        let expected: [MarkdownBlock] = [
            .listItem(depth: 0, marker: "•", text: "a"), .listItem(depth: 1, marker: "•", text: "b"),
            .listItem(depth: 2, marker: "•", text: "c"), .listItem(depth: 0, marker: "•", text: "d"),
        ]
        #expect(two == expected)
        #expect(four == expected)
    }

    @Test func allBulletMarkersAreBullets() {
        #expect(
            MarkdownBlocks.parse("- a\n* b\n+ c") == [
                .listItem(depth: 0, marker: "•", text: "a"), .listItem(depth: 0, marker: "•", text: "b"),
                .listItem(depth: 0, marker: "•", text: "c"),
            ])
    }

    @Test func aRuleIsNotAnEmptyBullet() {
        #expect(MarkdownBlocks.parse("before\n\n---\n\nafter") == [.paragraph("before"), .rule, .paragraph("after")])
        #expect(MarkdownBlocks.parse("***") == [.rule])
    }

    @Test func keepsFencedCodeVerbatim() {
        let notes = "Run:\n\n```bash\nbrew upgrade --cask avd-studio\n  # indented\n```\n\nDone."

        #expect(
            MarkdownBlocks.parse(notes) == [
                .paragraph("Run:"), .code("brew upgrade --cask avd-studio\n  # indented"), .paragraph("Done."),
            ])
    }

    @Test func codeThatIsNeverClosedStillShows() {
        #expect(MarkdownBlocks.parse("```\nline one\nline two") == [.code("line one\nline two")])
    }

    @Test func readsQuotes() {
        #expect(MarkdownBlocks.parse("> a note\n> that wraps\n\ntext") == [.quote("a note that wraps"), .paragraph("text")])
    }

    @Test func handlesWindowsLineEndingsAndEmptyInput() {
        #expect(
            MarkdownBlocks.parse("- a\r\n- b\r\n") == [
                .listItem(depth: 0, marker: "•", text: "a"), .listItem(depth: 0, marker: "•", text: "b"),
            ])
        #expect(MarkdownBlocks.parse("").isEmpty)
        #expect(MarkdownBlocks.parse("\n\n   \n").isEmpty)
    }

    @Test func aListEndsWhenAParagraphStarts() {
        #expect(MarkdownBlocks.parse("- a\n\nafter") == [.listItem(depth: 0, marker: "•", text: "a"), .paragraph("after")])
    }

    @Test func gitHubGeneratedNotesComeOutReadable() {
        let notes = """
            ## What's Changed
            * Fix the popover height by @marcos in https://github.com/x/y/pull/12
            * Add About page by @marcos in https://github.com/x/y/pull/13

            **Full Changelog**: https://github.com/x/y/compare/v0.1.0...v0.2.0
            """

        let blocks = MarkdownBlocks.parse(notes)

        #expect(blocks.first == .heading(level: 2, text: "What's Changed"))
        #expect(blocks.count == 4)
        #expect(blocks.last == .paragraph("**Full Changelog**: https://github.com/x/y/compare/v0.1.0...v0.2.0"))
    }
}

@Suite("Markdown inline")
struct MarkdownInlineTests {
    @Test func boldItalicAndCodeAreStyled() {
        let text = MarkdownInline.attributed("a **bold** and *slanted* and `code`")

        #expect(String(text.characters) == "a bold and slanted and code")
        #expect(text.runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true })
        #expect(text.runs.contains { $0.inlinePresentationIntent?.contains(.emphasized) == true })
        #expect(text.runs.contains { $0.inlinePresentationIntent?.contains(.code) == true })
    }

    @Test func markdownLinksKeepTheirTarget() {
        let text = MarkdownInline.attributed("see [the site](https://example.com/page) now")

        #expect(String(text.characters) == "see the site now")
        #expect(text.runs.compactMap(\.link) == [URL(string: "https://example.com/page")!])
    }

    @Test func bareWebAddressesBecomeLinks() {
        let text = MarkdownInline.attributed("**Full Changelog**: https://github.com/x/y/compare/v1...v2 done")

        #expect(text.runs.compactMap(\.link) == [URL(string: "https://github.com/x/y/compare/v1...v2")!])
        #expect(String(text.characters).hasSuffix("done"))
    }

    @Test func aMarkdownLinkIsNotLinkedTwice() {
        let text = MarkdownInline.attributed("[https://example.com](https://example.com/real)")

        #expect(text.runs.compactMap(\.link) == [URL(string: "https://example.com/real")!])
    }

    @Test func plainTextIsLeftAlone() {
        let text = MarkdownInline.attributed("nothing special 1 < 2")

        #expect(String(text.characters) == "nothing special 1 < 2")
        #expect(text.runs.allSatisfy { $0.link == nil })
    }
}
