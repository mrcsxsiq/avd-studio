import SwiftUI

/// The kind of device an AVD emulates. Drives the sidebar, icons and the colour of each card.
public enum DeviceKind: String, CaseIterable, Identifiable, Hashable, Sendable {
    case phone
    case foldable
    case tablet
    case wearOS
    case desktop
    case tv
    case automotive
    case xr
    case unknown

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .phone: "Phone"
        case .foldable: "Foldable"
        case .tablet: "Tablet"
        case .wearOS: "Wear OS"
        case .desktop: "Desktop"
        case .tv: "TV"
        case .automotive: "Automotive"
        case .xr: "XR"
        case .unknown: "Other"
        }
    }

    public var pluralTitle: String {
        switch self {
        case .phone: "Phones"
        case .foldable: "Foldables"
        case .tablet: "Tablets"
        case .wearOS: "Wear OS"
        case .desktop: "Desktop"
        case .tv: "TVs"
        case .automotive: "Automotive"
        case .xr: "XR"
        case .unknown: "Other"
        }
    }

    public var symbolName: String {
        switch self {
        case .phone: "iphone"
        case .foldable: "rectangle.split.2x1"
        case .tablet: "ipad.landscape"
        case .wearOS: "applewatch"
        case .desktop: "desktopcomputer"
        case .tv: "tv"
        case .automotive: "car"
        case .xr: "visionpro"
        case .unknown: "questionmark.square.dashed"
        }
    }

    /// Base hue (0...1) of the kind's colour family.
    var hue: Double {
        switch self {
        case .phone: 0.58  // blue
        case .foldable: 0.75  // purple
        case .tablet: 0.47  // teal
        case .wearOS: 0.07  // orange
        case .desktop: 0.66  // indigo
        case .tv: 0.92  // pink
        case .automotive: 0.99  // red
        case .xr: 0.52  // cyan
        case .unknown: 0.0
        }
    }

    /// Flat colour for icons and sidebar badges.
    public var tint: Color {
        self == .unknown ? .gray : Color(hue: hue, saturation: 0.75, brightness: 0.95)
    }
}
