import SwiftUI

public enum AppSettings {
    /// `@AppStorage` key for the "show in menu bar" toggle.
    public static let showMenuBarItemKey = "showMenuBarItem"
    /// `@AppStorage` key for the "show in the Dock" toggle. At least one of this and the menu bar toggle is always on
    /// (see `AppPresence`).
    public static let showInDockKey = "showInDock"
    /// `@AppStorage` key for the theme (`AppearanceMode.rawValue`).
    public static let appearanceKey = "appearance"
    /// `@AppStorage` key for the menu bar icon (`MenuBarIcon.rawValue`).
    public static let menuBarIconKey = "menuBarIcon"
}

/// The tabs of the Settings window.
public enum SettingsTab: String, CaseIterable, Identifiable, Sendable {
    case general
    case android
    case about

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .general: "General"
        case .android: "Android"
        case .about: "About"
        }
    }

    public var symbolName: String {
        switch self {
        case .general: "gearshape"
        case .android: "wrench.and.screwdriver"
        case .about: "info.circle"
        }
    }

    /// Window size of the tab (the Settings window resizes to the tab shown).
    var size: CGSize {
        switch self {
        case .general: CGSize(width: 560, height: 760)
        case .android: CGSize(width: 560, height: 700)
        case .about: CGSize(width: 560, height: 470)
        }
    }
}

public struct SettingsView: View {
    @Bindable var model: AppModel
    @State private var tab: SettingsTab

    public init(model: AppModel) {
        self.init(model: model, tab: .general)
    }

    init(model: AppModel, tab: SettingsTab) {
        self.model = model
        self._tab = State(initialValue: tab)
    }

    public var body: some View {
        TabView(selection: $tab) {
            ForEach(SettingsTab.allCases) { tab in
                content(for: tab)
                    .tabItem { Label(tab.title, systemImage: tab.symbolName) }
                    .tag(tab)
            }
        }
    }

    @ViewBuilder
    private func content(for tab: SettingsTab) -> some View {
        switch tab {
        case .general: GeneralSettingsTab(model: model)
        case .android: AndroidSettingsTab(model: model)
        case .about: AboutSettingsTab()
        }
    }
}
