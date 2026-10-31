// Generates website/assets/og.png (1200x630), the Open Graph / Twitter card image.
//
// Standalone on purpose: it needs only the macOS Swift toolchain, not the Swift package or any build.
//
//   swift website/tools/make-og.swift              # writes website/assets/og.png
//   swift website/tools/make-og.swift /tmp/og.png  # writes somewhere else
//
// It reads website/assets/icon-512.png, so regenerate the icons first if the app icon changes.

import AppKit

let width = 1200
let height = 630

// Resolve paths relative to this file so the script works from any directory.
let scriptURL = URL(fileURLWithPath: #filePath).standardizedFileURL
let websiteURL = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let iconURL = websiteURL.appendingPathComponent("assets/icon-512.png")
let outputURL: URL =
    CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : websiteURL.appendingPathComponent("assets/og.png")

guard let icon = NSImage(contentsOf: iconURL) else {
    FileHandle.standardError.write(Data("Cannot read \(iconURL.path)\n".utf8))
    exit(1)
}

guard
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ),
    let context = NSGraphicsContext(bitmapImageRep: rep)
else {
    FileHandle.standardError.write(Data("Cannot create the bitmap\n".utf8))
    exit(1)
}
rep.size = NSSize(width: width, height: height)  // 1 point == 1 pixel, so no @2x surprises

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        deviceRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

let mint = color(0x1BE8A6)
let blue = color(0x1F86FF)
let violet = color(0x6B3BFF)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high
let canvas = NSRect(x: 0, y: 0, width: width, height: height)

// 1. Brand gradient: mint (top left) through electric blue to violet (bottom right).
NSGradient(colors: [mint, blue, violet], atLocations: [0, 0.5, 1], colorSpace: .deviceRGB)!
    .draw(in: canvas, angle: -32)

// 2. A gentle scrim so white type keeps strong contrast across the whole gradient.
NSGradient(colors: [color(0x050818, alpha: 0.0), color(0x050818, alpha: 0.34)])!
    .draw(in: canvas, angle: 0)

// 3. Echo the app: a few soft, rounded "device cards" in the background.
func card(_ rect: NSRect, alpha: CGFloat) {
    let path = NSBezierPath(roundedRect: rect, xRadius: 44, yRadius: 44)
    color(0xFFFFFF, alpha: alpha).setFill()
    path.fill()
    color(0xFFFFFF, alpha: alpha * 1.6).setStroke()
    path.lineWidth = 2
    path.stroke()
}
card(NSRect(x: 800, y: 380, width: 340, height: 220), alpha: 0.07)
card(NSRect(x: 900, y: 70, width: 260, height: 260), alpha: 0.06)
card(NSRect(x: 560, y: 36, width: 300, height: 120), alpha: 0.05)

// 4. The app icon, with a soft drop shadow.
let iconSize: CGFloat = 330
let iconRect = NSRect(x: 96, y: (CGFloat(height) - iconSize) / 2, width: iconSize, height: iconSize)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = color(0x02051A, alpha: 0.45)
shadow.shadowBlurRadius = 36
shadow.shadowOffset = NSSize(width: 0, height: -14)
shadow.set()
icon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1)
NSGraphicsContext.restoreGraphicsState()

// 5. Text. Rendered with the system font, which is SF on a Mac.
func draw(_ text: String, at point: NSPoint, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat, kern: CGFloat = 0) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color(0xFFFFFF, alpha: alpha),
        .kern: kern,
    ]
    NSAttributedString(string: text, attributes: attributes).draw(at: point)
}

let textX: CGFloat = 480
draw("AVD Studio", at: NSPoint(x: textX - 4, y: 318), size: 118, weight: .bold, alpha: 1, kern: -3.5)
draw("Every Android emulator,", at: NSPoint(x: textX, y: 236), size: 44, weight: .semibold, alpha: 0.98, kern: -0.6)
draw("one click away.", at: NSPoint(x: textX, y: 184), size: 44, weight: .semibold, alpha: 0.98, kern: -0.6)
draw("Native macOS app and command-line tool. Open source.", at: NSPoint(x: textX, y: 112), size: 25, weight: .medium, alpha: 0.92)

NSGraphicsContext.restoreGraphicsState()

// Re-encode without an alpha channel: the card is fully opaque, and RGB compresses much better than RGBA.
func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}
guard
    let rendered = rep.cgImage,
    let rgb = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: rendered.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )
else { fail("Cannot create the RGB context") }
rgb.draw(rendered, in: CGRect(x: 0, y: 0, width: width, height: height))
guard
    let opaque = rgb.makeImage(),
    let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, "public.png" as CFString, 1, nil)
else { fail("Cannot create the PNG encoder") }
CGImageDestinationAddImage(destination, opaque, nil)
guard CGImageDestinationFinalize(destination) else { fail("Cannot write \(outputURL.path)") }

let size = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int) ?? 0
print("Wrote \(outputURL.path) (\(width)x\(height), \(size / 1024) KB)")
