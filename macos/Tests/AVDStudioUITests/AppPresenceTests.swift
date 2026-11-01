import AppKit
import Foundation
import Testing

@testable import AVDStudioUI

@Suite("App presence (Dock and menu bar)")
struct AppPresenceTests {
    private let both = AppPresence(showInMenuBar: true, showInDock: true)
    private let menuBarOnly = AppPresence(showInMenuBar: true, showInDock: false)
    private let dockOnly = AppPresence(showInMenuBar: false, showInDock: true)

    @Test func startsInBothPlaces() {
        #expect(AppPresence() == both)
        #expect(both.showInMenuBar && both.showInDock)
    }

    @Test func eitherPlaceCanBeHiddenWhileTheOtherIsOn() {
        #expect(both.settingMenuBar(false) == dockOnly)
        #expect(both.settingDock(false) == menuBarOnly)
    }

    @Test func theLastPlaceCannotBeSwitchedOff() {
        #expect(dockOnly.settingDock(false) == dockOnly)
        #expect(menuBarOnly.settingMenuBar(false) == menuBarOnly)
    }

    @Test func theLastPlaceIsTheOneThatIsLocked() {
        #expect(dockOnly.dockIsLastPlace && !dockOnly.menuBarIsLastPlace)
        #expect(menuBarOnly.menuBarIsLastPlace && !menuBarOnly.dockIsLastPlace)
        #expect(!both.dockIsLastPlace && !both.menuBarIsLastPlace)
    }

    @Test func switchingTheOtherPlaceBackOnUnlocksTheFirst() {
        let restored = dockOnly.settingMenuBar(true)

        #expect(restored == both)
        #expect(restored.settingDock(false) == menuBarOnly)
    }

    @Test func noSequenceOfTogglesEverLeavesNeither() {
        // Every state, every toggle, up to three steps deep.
        var states: Set<[Bool]> = [[true, true], [true, false], [false, true]]
        for _ in 0..<3 {
            for state in states {
                let presence = AppPresence(showInMenuBar: state[0], showInDock: state[1])
                for next in [
                    presence.settingMenuBar(true), presence.settingMenuBar(false), presence.settingDock(true), presence.settingDock(false),
                ] {
                    states.insert([next.showInMenuBar, next.showInDock])
                }
            }
        }

        #expect(!states.contains([false, false]))
    }

    @Test func bothOffIsRepairedToTheDock() {
        let repaired = AppPresence(showInMenuBar: false, showInDock: false)

        #expect(repaired == dockOnly)
    }

    @Test func theDockDecidesTheActivationPolicy() {
        #expect(both.activationPolicy == .regular)
        #expect(dockOnly.activationPolicy == .regular)
        #expect(menuBarOnly.activationPolicy == .accessory)
    }

    // MARK: Stored preference

    private func isolatedDefaults() -> UserDefaults {
        let name = "AppPresenceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func missingKeysMeanShownInBothPlaces() {
        #expect(AppPresence.stored(in: isolatedDefaults()) == both)
    }

    @Test func readsTheStoredChoice() {
        let defaults = isolatedDefaults()
        defaults.set(false, forKey: AppSettings.showInDockKey)

        #expect(AppPresence.stored(in: defaults) == menuBarOnly)
    }

    @Test func aStoredBothOffIsReadAsTheDockAndRepairedOnDisk() {
        let defaults = isolatedDefaults()
        defaults.set(false, forKey: AppSettings.showMenuBarItemKey)
        defaults.set(false, forKey: AppSettings.showInDockKey)

        #expect(AppPresence.stored(in: defaults) == dockOnly)

        AppPresence.repairStored(in: defaults)

        #expect(defaults.bool(forKey: AppSettings.showInDockKey))
        #expect(!defaults.bool(forKey: AppSettings.showMenuBarItemKey), "the menu bar choice is left as the user made it")
    }

    @Test func repairingAValidChoiceWritesNothing() {
        let defaults = isolatedDefaults()

        AppPresence.repairStored(in: defaults)

        #expect(defaults.object(forKey: AppSettings.showInDockKey) == nil)
        #expect(defaults.object(forKey: AppSettings.showMenuBarItemKey) == nil)
    }
}
