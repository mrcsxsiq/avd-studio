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
            of: renderAtFixedScale(host, size: size),
            as: .image(precision: snapshotPrecision, perceptualPrecision: snapshotPerceptualPrecision),
            named: "\(name)-\(scheme == .dark ? "dark" : "light")",
            file: file,
            testName: testName,
            line: line
        )
    }
}

/// How close a screenshot has to be to its reference.
///
/// A GitHub runner (macOS 26; the references are recorded on macOS 27) draws glyph edges differently: layout, icons
/// and colours match, but 2 to 6 % of the pixels of every screen differ, and the dark sidebar's background is a few
/// shades off. Measured against the runner's own images, the worst screen has 95 % of its pixels within a Lab delta E
/// of 15, so asking for 93 % within 15 leaves a margin.
///
/// The price: a one-letter text change or a status dot turning red no longer fails a test. Layout shifts, size
/// changes and anything that moves a block of text still do, which is what a regression in a view usually does.
private let snapshotPrecision: Float = 0.93
private let snapshotPerceptualPrecision: Float = 0.85

/// The pixel density every reference image is drawn at.
private let snapshotScale: CGFloat = 2

/// Draws `view` into a bitmap of `snapshotScale` pixels per point, tagged Display P3, on any machine.
///
/// SnapshotTesting's own NSView strategy sizes the bitmap from the display the window is on. The references are
/// recorded on a Retina Mac (2x, Display P3), but a GitHub runner has a 1x virtual display, so the same view came out
/// at half the pixels and no reference ever matched there. Drawing into a bitmap we size and tag ourselves removes the
/// display from the equation.
@MainActor
private func renderAtFixedScale(_ view: NSView, size: CGSize) -> NSImage {
    guard
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * snapshotScale),
            pixelsHigh: Int(size.height * snapshotScale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
    else { fatalError("Could not allocate a \(size) bitmap at \(snapshotScale)x.") }
    // Retagging keeps the (still empty) pixels and only changes the colour space everything is drawn into.
    let rep = bitmap.retagging(with: .displayP3) ?? bitmap
    rep.size = size  // points, so the pixel size is `size * snapshotScale`
    view.cacheDisplay(in: view.bounds, to: rep)
    let image = NSImage(size: size)
    image.addRepresentation(rep)
    return image
}
