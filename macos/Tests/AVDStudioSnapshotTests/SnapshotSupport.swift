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
        freezeVibrancy(in: host)
        defer { window.close() }
        assertSnapshot(
            of: renderAtFixedScale(host, size: size),
            as: .image(precision: 0.98, perceptualPrecision: 0.96),
            named: "\(name)-\(scheme == .dark ? "dark" : "light")",
            file: file,
            testName: testName,
            line: line
        )
    }
}

/// Makes every translucent material (the sidebar's, for one) paint its flat fallback colour.
///
/// A material blends with whatever is behind the window, and for an offscreen window that is the desktop of the machine
/// running the test, or nothing at all on a CI runner. Pinning it to `.inactive` keeps the references independent of
/// the machine. A borderless window never becomes the key window, so on a Mac this does not change the rendering.
@MainActor
private func freezeVibrancy(in view: NSView) {
    if let effect = view as? NSVisualEffectView { effect.state = .inactive }
    for subview in view.subviews { freezeVibrancy(in: subview) }
}

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
