#!/usr/bin/env swift
// Renders the app icon into macos/App/Assets.xcassets/AppIcon.appiconset.
//
//   swift scripts/generate-icon.swift                      # writes the whole icon set
//   swift scripts/generate-icon.swift --preview out.png    # writes one 1024px preview
//
// The art is drawn in code on a 1024-unit canvas so it stays sharp at every size.
import AppKit

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func rounded(_ rect: NSRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func saved(_ body: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    body()
    NSGraphicsContext.restoreGraphicsState()
}

func setShadow(offsetY: CGFloat, blur: CGFloat, color shadowColor: NSColor) {
    let shadow = NSShadow()
    shadow.shadowOffset = NSSize(width: 0, height: offsetY)
    shadow.shadowBlurRadius = blur
    shadow.shadowColor = shadowColor
    shadow.set()
}

func gradient(_ stops: [(UInt32, CGFloat, CGFloat)]) -> NSGradient {
    NSGradient(colors: stops.map { color($0.0, $0.1) }, atLocations: stops.map { $0.2 }, colorSpace: .sRGB)!
}

/// `simplified` drops the fine detail that turns to mud at 16-64 px.
func drawIcon(simplified: Bool) {
    // macOS app icons: an 824pt squircle centred on the 1024pt canvas, leaving room for the shadow.
    let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = rounded(tile, 184)

    saved {
        setShadow(offsetY: -14, blur: 30, color: color(0x000000, 0.4))
        color(0x1B2A6B).setFill()
        tilePath.fill()
    }

    // Background: mint -> electric blue -> violet, lit from the top left.
    saved {
        tilePath.addClip()
        gradient([(0x1BE8A6, 1, 0), (0x1F86FF, 1, 0.52), (0x6B3BFF, 1, 1)]).draw(in: tile, angle: -55)
        NSGradient(colors: [color(0xFFFFFF, 0.42), color(0xFFFFFF, 0)])!
            .draw(fromCenter: NSPoint(x: 330, y: 820), radius: 0, toCenter: NSPoint(x: 330, y: 820), radius: 600, options: [])
        gradient([(0x08002E, 0, 0), (0x08002E, 0.34, 1)]).draw(in: tile, angle: -90)
    }

    // A tablet behind the phone: this app manages a whole fleet of devices, not one.
    if !simplified {
        let tablet = NSRect(x: 392, y: 468, width: 400, height: 292)
        saved {
            setShadow(offsetY: -14, blur: 28, color: color(0x000030, 0.4))
            gradient([(0x2A3350, 1, 0), (0x0A0E1C, 1, 1)]).draw(in: rounded(tablet, 58), angle: -60)
        }
        saved {
            let rim = rounded(tablet.insetBy(dx: 3, dy: 3), 55)
            rim.lineWidth = 6
            color(0xFFFFFF, 0.38).setStroke()
            rim.stroke()
        }
        let tabletScreen = tablet.insetBy(dx: 18, dy: 18)
        saved {
            rounded(tabletScreen, 42).addClip()
            gradient([(0xB48CFF, 1, 0), (0x5C7BFF, 1, 0.55), (0x2CCBFF, 1, 1)]).draw(in: tabletScreen, angle: -35)
            // Little "app grid" so it reads as a screen, not a slab.
            color(0xFFFFFF, 0.28).setFill()
            for column in 0..<4 {
                for row in 0..<2 {
                    rounded(NSRect(x: tabletScreen.minX + 150 + CGFloat(column) * 54, y: tabletScreen.minY + 48 + CGFloat(row) * 54, width: 38, height: 38), 11).fill()
                }
            }
        }
        // Keep the tablet visually behind the phone.
        saved {
            color(0x08002E, 0.18).setFill()
            rounded(tablet, 58).fill()
        }
    }

    // The phone.
    let phone = NSRect(x: 246, y: 222, width: 282, height: 566)
    let bodyRadius: CGFloat = 66
    saved {
        setShadow(offsetY: -20, blur: 38, color: color(0x000020, 0.5))
        gradient([(0x2A3350, 1, 0), (0x0A0E1C, 1, 1)]).draw(in: rounded(phone, bodyRadius), angle: -75)
    }
    saved {
        let rim = rounded(phone.insetBy(dx: 3, dy: 3), bodyRadius - 3)
        rim.lineWidth = 6
        color(0xFFFFFF, 0.5).setStroke()
        rim.stroke()
    }

    let screen = phone.insetBy(dx: 18, dy: 18)
    saved {
        rounded(screen, 50).addClip()
        gradient([(0x9BFFDD, 1, 0), (0x2CCBFF, 1, 0.5), (0x3B63FF, 1, 1)]).draw(in: screen, angle: -72)
        if !simplified {
            // Diagonal glass reflection.
            let gloss = NSBezierPath()
            gloss.move(to: NSPoint(x: screen.minX, y: screen.maxY))
            gloss.line(to: NSPoint(x: screen.maxX, y: screen.maxY))
            gloss.line(to: NSPoint(x: screen.maxX, y: screen.maxY - 150))
            gloss.line(to: NSPoint(x: screen.minX, y: screen.maxY - 300))
            gloss.close()
            color(0xFFFFFF, 0.22).setFill()
            gloss.fill()
        }
    }
    if !simplified {
        color(0x0B1020).setFill()
        rounded(NSRect(x: phone.midX - 40, y: screen.maxY - 40, width: 80, height: 20), 10).fill()
    }

    // The play button: "start this emulator".
    let centre = NSPoint(x: phone.midX + 8, y: screen.midY - 12)
    let triangle = NSBezierPath()
    triangle.move(to: NSPoint(x: centre.x - 46, y: centre.y + 70))
    triangle.line(to: NSPoint(x: centre.x - 46, y: centre.y - 70))
    triangle.line(to: NSPoint(x: centre.x + 70, y: centre.y))
    triangle.close()
    triangle.lineJoinStyle = .round
    triangle.lineWidth = 30
    saved {
        setShadow(offsetY: -10, blur: 24, color: color(0x002A8C, 0.55))
        NSColor.white.setStroke()
        triangle.stroke()
    }
    // The shadow of the stroke lands on the fill, so repaint the shape crisp and white without a shadow.
    NSColor.white.setFill()
    NSColor.white.setStroke()
    triangle.fill()
    triangle.stroke()

    // Soft edge light on the tile so it reads as glass, not paint.
    saved {
        let edge = rounded(tile.insetBy(dx: 2, dy: 2), 182)
        edge.lineWidth = 4
        color(0xFFFFFF, 0.3).setStroke()
        edge.stroke()
    }
}

func render(pixels: Int) -> Data {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    bitmap.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    drawIcon(simplified: pixels <= 64)
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.first == "--preview", arguments.count > 1 {
    try render(pixels: 1024).write(to: URL(fileURLWithPath: arguments[1]))
    print("Wrote preview to \(arguments[1])")
    exit(0)
}

let outputDirectory = URL(fileURLWithPath: arguments.first ?? "macos/App/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
var images: [[String: String]] = []
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(base)x\(base)\(scale == 2 ? "@2x" : "").png"
        try render(pixels: base * scale).write(to: outputDirectory.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(base)x\(base)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: outputDirectory.appendingPathComponent("Contents.json"))
print("Wrote \(images.count) icons to \(outputDirectory.path)")
