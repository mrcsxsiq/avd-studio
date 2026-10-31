import SwiftUI
import XCTest
@testable import AVDStudioUI

final class ScreenshotTests: SnapshotTestCase {
    private var samples: [VirtualDevice] { SampleData.devices }

    @MainActor
    func testDeviceCardStates() {
        let cards: [(VirtualDevice, RunState, Bool)] = [
            (samples[0], .idle, false),
            (samples[0], .running, false),
            (samples[0], .starting, false),
            (samples[1], .idle, true),
            (samples[2], .idle, false),
            (samples[3], .idle, false),
            (samples[4], .idle, false),
            (samples[5], .idle, false),
            (samples[8], .idle, false),
        ]
        let gallery = Grid(horizontalSpacing: 18, verticalSpacing: 18) {
            ForEach(0..<3, id: \.self) { row in
                GridRow {
                    ForEach(0..<3, id: \.self) { column in
                        let card = cards[row * 3 + column]
                        DeviceCard(device: card.0, runState: card.1, isSelected: card.2)
                            .frame(width: 270)
                    }
                }
            }
        }
        .padding(24)

        assertScreenshot(of: gallery, size: CGSize(width: 930, height: 640), named: "card-gallery")
    }

    @MainActor
    func testEveryDeviceKindHasItsOwnColourFamily() {
        let kinds = DeviceKind.allCases.map { VirtualDevice(id: "Sample_\($0.rawValue)", kind: $0, apiLevel: "34", androidVersion: "14") }
        let rainbow = Grid(horizontalSpacing: 14, verticalSpacing: 14) {
            ForEach(0..<3, id: \.self) { row in
                GridRow {
                    ForEach(0..<3, id: \.self) { column in
                        DeviceCard(device: kinds[row * 3 + column], runState: .idle).frame(width: 250)
                    }
                }
            }
        }
        .padding(20)

        assertScreenshot(of: rainbow, size: CGSize(width: 840, height: 640), named: "kinds", schemes: [.light])
    }

    @MainActor
    func testDeviceGrid() {
        let model = SampleData.model(running: ["Pixel_9_API_36"])
        assertScreenshot(of: DeviceGridView(model: model), size: CGSize(width: 900, height: 640), named: "grid")
    }

    @MainActor
    func testDeviceGridWithNoDevices() {
        let model = SampleData.model(devices: [])
        assertScreenshot(of: DeviceGridView(model: model), size: CGSize(width: 700, height: 420), named: "grid-empty")
    }

    @MainActor
    func testSidebar() {
        let model = SampleData.model(running: ["Pixel_9_API_36"])
        // An offscreen window does not paint the selection highlight, so show the list with nothing selected.
        model.sidebarSelection = nil
        assertScreenshot(of: SidebarView(model: model), size: CGSize(width: 250, height: 520), named: "sidebar")
    }

    @MainActor
    func testSidebarWhenTheSdkNeedsSetup() {
        let model = SampleData.model(devices: SampleData.devices, toolchain: SampleData.missingToolchain)
        model.sidebarSelection = nil
        assertScreenshot(of: SidebarView(model: model), size: CGSize(width: 250, height: 520), named: "sidebar-setup", schemes: [.light])
    }

    @MainActor
    func testSetupScreen() {
        let model = SampleData.model(devices: [], toolchain: SampleData.missingToolchain)
        assertScreenshot(of: SetupView(model: model), size: CGSize(width: 760, height: 760), named: "setup")
    }

    @MainActor
    func testMenuBarPopover() {
        let model = SampleData.model(running: ["Pixel_9_API_36", "Television_4K"])
        assertScreenshot(of: MenuBarContent(model: model), size: CGSize(width: 340, height: 600), named: "menu-bar")
    }

    @MainActor
    func testMenuBarPopoverWhenTheSdkIsMissing() {
        let model = SampleData.model(devices: [], toolchain: SampleData.missingToolchain)
        assertScreenshot(of: MenuBarContent(model: model), size: CGSize(width: 340, height: 300), named: "menu-bar-setup", schemes: [.light])
    }

    @MainActor
    func testSettings() {
        let model = SampleData.model()
        assertScreenshot(of: SettingsView(model: model), size: CGSize(width: 600, height: 640), named: "settings")
    }
}
