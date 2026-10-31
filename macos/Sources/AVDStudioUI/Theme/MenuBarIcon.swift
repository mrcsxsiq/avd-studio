import AppKit
import SwiftUI

/// The icons the user can pick for the menu bar item. Every one is a template image, so macOS tints it
/// for light/dark menu bars and for the highlighted state, and every one can show a "running" dot.
public enum MenuBarIcon: String, CaseIterable, Identifiable, Sendable {
    case phone
    case phones
    case tablet
    case watch
    case tv
    case car
    case play
    case terminal
    case bolt
    /// A little robot head drawn for this app (not Google's logo).
    case droid

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .phone: "Phone"
        case .phones: "Phone & Tablet"
        case .tablet: "Tablet"
        case .watch: "Watch"
        case .tv: "TV"
        case .car: "Car"
        case .play: "Play"
        case .terminal: "Terminal"
        case .bolt: "Bolt"
        case .droid: "Droid"
        }
    }

    /// SF Symbol behind the icon; `nil` for the hand-drawn droid.
    var symbolName: String? {
        switch self {
        case .phone: "iphone.gen3"
        case .phones: "ipad.and.iphone"
        case .tablet: "ipad.landscape"
        case .watch: "applewatch"
        case .tv: "tv"
        case .car: "car"
        case .play: "play.rectangle.fill"
        case .terminal: "terminal"
        case .bolt: "bolt.fill"
        case .droid: nil
        }
    }

    static let canvas = NSSize(width: 18, height: 18)

    /// A template image of this icon; with `running` a dot marks the corner (the cut-out ring keeps it legible).
    public func image(running: Bool) -> NSImage {
        let image = NSImage(size: Self.canvas, flipped: false) { rect in
            if let symbolName = self.symbolName {
                Self.drawSymbol(named: symbolName, in: rect)
            } else {
                Self.drawDroid(in: rect)
            }
            if running { Self.drawRunningDot(in: rect) }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = running ? "AVD Studio, emulators running" : "AVD Studio"
        return image
    }

    private static func drawSymbol(named name: String, in rect: NSRect) {
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(configuration) else {
            return
        }
        let size = symbol.size
        let target = NSRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height)
        symbol.draw(in: target)
    }

    private static func drawDroid(in rect: NSRect) {
        NSColor.black.setFill()
        NSColor.black.setStroke()

        // Head: a dome with a flat base.
        let head = NSBezierPath()
        let center = NSPoint(x: rect.midX, y: 9.2)
        head.move(to: NSPoint(x: center.x - 5.6, y: center.y))
        head.appendArc(withCenter: center, radius: 5.6, startAngle: 180, endAngle: 0, clockwise: true)
        head.close()
        head.fill()

        // Antennae.
        for direction in [-1.0, 1.0] {
            let antenna = NSBezierPath()
            antenna.lineWidth = 1.2
            antenna.lineCapStyle = .round
            antenna.move(to: NSPoint(x: center.x + direction * 3.2, y: center.y + 4.6))
            antenna.line(to: NSPoint(x: center.x + direction * 4.6, y: center.y + 6.6))
            antenna.stroke()
        }

        // Body, separated from the head by a thin gap like a real droid.
        NSBezierPath(roundedRect: NSRect(x: center.x - 5.6, y: 1.0, width: 11.2, height: 6.4), xRadius: 1.8, yRadius: 1.8).fill()

        // Eyes are cut out of the head.
        NSGraphicsContext.current?.compositingOperation = .clear
        for direction in [-1.0, 1.0] {
            NSBezierPath(ovalIn: NSRect(x: center.x + direction * 2.4 - 0.9, y: center.y + 1.6, width: 1.8, height: 1.8)).fill()
        }
        NSGraphicsContext.current?.compositingOperation = .sourceOver
    }

    private static func drawRunningDot(in rect: NSRect) {
        let dot = NSRect(x: rect.maxX - 7.5, y: 0.5, width: 6.5, height: 6.5)
        NSGraphicsContext.current?.compositingOperation = .clear
        NSBezierPath(ovalIn: dot.insetBy(dx: -1.3, dy: -1.3)).fill()
        NSGraphicsContext.current?.compositingOperation = .sourceOver
        NSColor.black.setFill()
        NSBezierPath(ovalIn: dot).fill()
    }
}
