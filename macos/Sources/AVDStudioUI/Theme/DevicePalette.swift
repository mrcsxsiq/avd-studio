import SwiftUI

/// Gradient colours of a device card: the family comes from the kind, a small stable offset from the
/// name keeps two phones distinguishable. It is deterministic across launches (Swift's own `hashValue` is not).
public struct DevicePalette: Equatable, Sendable {
    public let hue: Double
    public let accentHue: Double

    public init(kind: DeviceKind, seed: String) {
        let hash = DevicePalette.fnv1a(seed)
        let offset = (Double(hash % 1000) / 1000 - 0.5) * 0.10 // -0.05 ... +0.05
        var hue = kind.hue + offset
        hue -= hue.rounded(.down)
        self.hue = hue
        var accent = hue + 0.07
        accent -= accent.rounded(.down)
        self.accentHue = accent
    }

    public var top: Color { Color(hue: accentHue, saturation: 0.62, brightness: 0.86) }
    public var bottom: Color { Color(hue: hue, saturation: 0.85, brightness: 0.58) }

    public var gradient: LinearGradient {
        LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func fnv1a(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }
}
