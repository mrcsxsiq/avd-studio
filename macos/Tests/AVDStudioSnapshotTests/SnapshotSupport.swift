import AppKit
import SnapshotTesting
import SwiftUI
import XCTest

/// Shared plumbing for the screenshot tests.
///
/// - First run on a new machine: references are recorded (`.missing`) and the test fails once, by design.
/// - `SNAPSHOT_RECORD=1`: re-record everything (after an intentional UI change).
/// - `CI` set: never record, a missing reference is a failure.
class SnapshotTestCase: XCTestCase {
    override func invokeTest() {
        let environment = ProcessInfo.processInfo.environment
        let record: SnapshotTestingConfiguration.Record =
            environment["SNAPSHOT_RECORD"] == "1" ? .all : (environment["CI"] != nil ? .never : .missing)
        withSnapshotTesting(record: record) { super.invokeTest() }
    }
}

@MainActor
func assertScreenshot(
    of view: some View,
    size: CGSize,
    named name: String,
    schemes: [ColorScheme] = [.light, .dark],
    file: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line
) {
    for scheme in schemes {
        let content =
            view
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, scheme)
            // Sizes and dates read the same on every Mac, so the references do not depend on the machine's language.
            .environment(\.locale, Locale(identifier: "en_US"))
        let host = NSHostingView(rootView: content)
        host.frame = CGRect(origin: .zero, size: size)
        // AppKit-backed controls (List, Form) only lay out and draw once they live in a window, even an invisible one.
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        host.layoutSubtreeIfNeeded()
        defer { window.close() }
        assertSnapshot(
            of: host,
            as: .image(precision: 0.98, perceptualPrecision: 0.96, size: size),
            named: "\(name)-\(scheme == .dark ? "dark" : "light")",
            file: file,
            testName: testName,
            line: line
        )
    }
}
