import AppKit

/// Where AVD Studio shows up: in the Dock (with its windows), in the menu bar, or in both.
///
/// It is never in neither. An app with no Dock icon and no menu bar item keeps running but cannot be reached, so
/// the last place that is switched on cannot be switched off, and a stored "both off" is repaired.
public struct AppPresence: Equatable, Sendable {
    public let showInMenuBar: Bool
    public let showInDock: Bool

    /// A "both off" request (a hand-edited preference, or one written by another build) falls back to the Dock:
    /// from there the window and Settings are one click away.
    public init(showInMenuBar: Bool = true, showInDock: Bool = true) {
        self.showInMenuBar = showInMenuBar
        self.showInDock = showInDock || !showInMenuBar
    }

    /// The menu bar item is the only way in, so its switch must stay on.
    public var menuBarIsLastPlace: Bool { showInMenuBar && !showInDock }

    /// The Dock icon is the only way in, so its switch must stay on.
    public var dockIsLastPlace: Bool { showInDock && !showInMenuBar }

    /// Shows or hides the menu bar item. Hiding it is ignored when it is the last place left.
    public func settingMenuBar(_ visible: Bool) -> AppPresence {
        guard visible || !menuBarIsLastPlace else { return self }
        return AppPresence(showInMenuBar: visible, showInDock: showInDock)
    }

    /// Shows or hides the Dock icon. Hiding it is ignored when it is the last place left.
    public func settingDock(_ visible: Bool) -> AppPresence {
        guard visible || !dockIsLastPlace else { return self }
        return AppPresence(showInMenuBar: showInMenuBar, showInDock: visible)
    }

    /// Without a Dock icon the app is an "accessory": it lives in the menu bar and opens windows on demand.
    public var activationPolicy: NSApplication.ActivationPolicy {
        showInDock ? .regular : .accessory
    }

    /// Applies the Dock preference to the running app right away.
    @MainActor
    public func apply() {
        NSApplication.shared.setActivationPolicy(activationPolicy)
    }

    // MARK: Stored preference

    /// The preference as stored. A missing key means "shown", and an impossible combination is repaired.
    public static func stored(in defaults: UserDefaults = .standard) -> AppPresence {
        AppPresence(
            showInMenuBar: defaults.object(forKey: AppSettings.showMenuBarItemKey) as? Bool ?? true,
            showInDock: defaults.object(forKey: AppSettings.showInDockKey) as? Bool ?? true)
    }

    /// Writes the repair for a stored "both off" back, so everything that reads the keys directly agrees with it.
    public static func repairStored(in defaults: UserDefaults = .standard) {
        let repaired = stored(in: defaults)
        let rawDock = defaults.object(forKey: AppSettings.showInDockKey) as? Bool ?? true
        if repaired.showInDock != rawDock { defaults.set(true, forKey: AppSettings.showInDockKey) }
    }
}
