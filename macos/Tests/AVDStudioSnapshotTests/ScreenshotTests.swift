import AppKit
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

    /// The size the status item's window gets: the content's own size, not a frame we pick.
    @MainActor
    private func popoverSize(_ model: AppModel, updates: UpdateModel? = nil) -> CGSize {
        let content = MenuBarContent(model: model)
        let host = updates.map { NSHostingView(rootView: AnyView(content.environment($0))) } ?? NSHostingView(rootView: AnyView(content))
        return host.fittingSize
    }

    @MainActor
    func testMenuBarPopover() {
        let model = SampleData.model(running: ["Pixel_9_API_36", "Television_4K"])
        assertScreenshot(of: MenuBarContent(model: model), size: popoverSize(model), named: "menu-bar")
    }

    @MainActor
    func testMenuBarPopoverWhenTheSdkIsMissing() {
        let model = SampleData.model(devices: [], toolchain: SampleData.missingToolchain)
        assertScreenshot(
            of: MenuBarContent(model: model), size: CGSize(width: 340, height: 300), named: "menu-bar-setup", schemes: [.light])
    }

    @MainActor
    private func assertSettingsTab(
        _ tab: SettingsTab, of view: some View, named name: String, file: StaticString = #filePath, testName: String = #function,
        line: UInt = #line
    ) {
        assertScreenshot(of: view, size: tab.size, named: name, file: file, testName: testName, line: line)
    }

    @MainActor
    func testSettingsGeneralTab() {
        let model = SampleData.model()
        let updates = SampleData.updateModel(state: .available(SampleData.release))
        assertSettingsTab(.general, of: GeneralSettingsTab(model: model).environment(updates), named: "settings-general")
    }

    @MainActor
    func testSettingsAndroidTab() {
        let model = SampleData.model()
        model.setSetupPlanForPreview(SampleData.setupPlan)
        assertSettingsTab(.android, of: AndroidSettingsTab(model: model), named: "settings-android")
    }

    @MainActor
    func testSettingsAboutTab() {
        assertSettingsTab(.about, of: AboutSettingsTab(), named: "settings-about")
    }

    @MainActor
    func testMenuBarPopoverWithAnAvailableUpdate() {
        let model = SampleData.model(running: ["Pixel_9_API_36"])
        let updates = SampleData.updateModel(state: .available(SampleData.release))
        assertScreenshot(
            of: MenuBarContent(model: model).environment(updates), size: popoverSize(model, updates: updates), named: "menu-bar-update",
            schemes: [.light])
    }

    @MainActor
    func testMenuBarIconChoices() {
        let gallery = Grid(horizontalSpacing: 16, verticalSpacing: 16) {
            GridRow {
                ForEach(MenuBarIcon.allCases.prefix(5)) { self.iconTile($0) }
            }
            GridRow {
                ForEach(MenuBarIcon.allCases.suffix(5)) { self.iconTile($0) }
            }
        }
        .padding(24)
        assertScreenshot(of: gallery, size: CGSize(width: 500, height: 230), named: "menu-bar-icons")
    }

    @MainActor
    private func iconTile(_ icon: MenuBarIcon) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                Image(nsImage: icon.image(running: false)).renderingMode(.template).resizable().scaledToFit().frame(width: 26, height: 26)
                Image(nsImage: icon.image(running: true)).renderingMode(.template).resizable().scaledToFit().frame(width: 26, height: 26)
            }
            Text(icon.title).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: Software Update

    @MainActor
    private func assertUpdate(
        _ state: UpdateState,
        named name: String,
        installSource: InstallSource = .manual,
        schemes: [ColorScheme] = [.light, .dark],
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) {
        assertScreenshot(
            of: UpdateView(model: SampleData.updateModel(state: state, installSource: installSource)),
            size: CGSize(width: 540, height: 520),
            named: name,
            schemes: schemes,
            file: file,
            testName: testName,
            line: line
        )
    }

    @MainActor
    func testUpdateAvailableShowsInstalledAndNewVersion() {
        assertUpdate(.available(SampleData.release), named: "update-available")
    }

    @MainActor
    func testUpdateUpToDate() {
        assertUpdate(.upToDate(checkedAt: Date(timeIntervalSinceNow: -120)), named: "update-up-to-date")
    }

    @MainActor
    func testUpdateDownloading() {
        assertUpdate(.downloading(SampleData.release, progress: 0.42), named: "update-downloading", schemes: [.light])
    }

    @MainActor
    func testUpdateDownloaded() {
        assertUpdate(
            .downloaded(SampleData.release, file: URL(fileURLWithPath: "/tmp/AVD-Studio-0.2.0.dmg"), verified: true),
            named: "update-downloaded", schemes: [.light])
    }

    @MainActor
    func testUpdateForHomebrewInstalls() {
        assertUpdate(.available(SampleData.release), named: "update-homebrew", installSource: .homebrew, schemes: [.light])
    }

    @MainActor
    func testUpdateFailedAndNoReleases() {
        assertUpdate(.failed(UpdateError.rateLimited.localizedDescription), named: "update-failed", schemes: [.light])
        assertUpdate(.noReleases(checkedAt: Date(timeIntervalSinceNow: -30)), named: "update-no-releases", schemes: [.light])
    }

    // MARK: One-click SDK installation

    @MainActor
    private func installer(_ plan: SetupPlan = SampleData.setupPlan) -> SetupModel {
        SetupModel(plan: plan, service: PreviewDeviceService(), locations: Locations(), opener: NoopOpener())
    }

    @MainActor
    func testSetupInstallSheetBeforeStarting() {
        assertScreenshot(of: SetupInstallView(model: installer()) {}, size: CGSize(width: 560, height: 560), named: "install-ready")
    }

    @MainActor
    func testSetupInstallSheetWithoutHomebrew() {
        assertScreenshot(
            of: SetupInstallView(model: installer(SampleData.setupPlanWithoutHomebrew)) {},
            size: CGSize(width: 560, height: 560),
            named: "install-no-homebrew",
            schemes: [.light]
        )
    }

    @MainActor
    func testSetupInstallSheetAfterAFailure() async {
        let model = SetupModel(
            plan: SampleData.setupPlan, service: FailingSetupService(failAt: .licenses), locations: Locations(), opener: NoopOpener()
        )
        model.acceptedLicense = true
        await model.run()
        assertScreenshot(
            of: SetupInstallView(model: model) {}, size: CGSize(width: 560, height: 560), named: "install-failed", schemes: [.light])
    }

    @MainActor
    func testSetupScreenOffersAutomaticInstall() {
        let model = SampleData.model(devices: [], toolchain: SampleData.missingToolchain)
        model.setSetupPlanForPreview(SampleData.setupPlan)
        assertScreenshot(of: SetupView(model: model), size: CGSize(width: 760, height: 760), named: "setup-automatic", schemes: [.light])
    }

    // MARK: About

    /// The real app icon, so the screenshot shows what users see (a SwiftPM test has no asset catalog).
    @MainActor
    private func appIcon() -> NSImage {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("App/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png")
        return NSImage(contentsOf: url) ?? NSImage()
    }

    @MainActor
    func testAboutWindow() {
        let model = AboutModel(info: AppInfo(version: "0.1.0", build: "1"), opener: NoopOpener())
        let view = AboutView(model: model, icon: appIcon())
        assertScreenshot(of: view, size: NSHostingView(rootView: view).fittingSize, named: "about")
    }

    // MARK: New device

    @MainActor
    private func createModel(
        images: [SystemImage] = SampleData.systemImages,
        profilesError: String? = nil,
        kind: DeviceKind = .phone
    ) async -> CreateDeviceModel {
        let model = CreateDeviceModel(
            service: ConfigurableCatalogService(images: images, profilesError: profilesError),
            locations: Locations(),
            existingNames: ["Pixel_9_API_36"],
            kind: kind
        )
        await model.load()
        return model
    }

    @MainActor
    func testCreateDeviceSheet() async {
        let model = await createModel()
        assertScreenshot(of: CreateDeviceView(model: model) { _ in }, size: CGSize(width: 600, height: 640), named: "create-phone")
    }

    @MainActor
    func testCreateDeviceSheetForAKindWithoutImages() async {
        let model = await createModel(kind: .wearOS)
        assertScreenshot(
            of: CreateDeviceView(model: model) { _ in }, size: CGSize(width: 600, height: 640), named: "create-no-image", schemes: [.light]
        )
    }

    @MainActor
    func testCreateDeviceSheetWhenAvdmanagerIsUnavailable() async {
        let model = await createModel(profilesError: "avdmanager needs a Java runtime and none was found. Run setup first.")
        assertScreenshot(
            of: CreateDeviceView(model: model) { _ in }, size: CGSize(width: 600, height: 640), named: "create-unavailable",
            schemes: [.light]
        )
    }
}

private struct NoopOpener: FileOpening {
    func open(_ url: URL) {}
    func reveal(_ url: URL) {}
}

/// Succeeds until `failAt`, which fails with some output.
private struct FailingSetupService: DeviceService {
    let failAt: SetupStep.Kind

    func snapshot(locations: Locations) async -> DeviceSnapshot { await PreviewDeviceService().snapshot(locations: locations) }
    func runningDevices() async -> [RunningDevice] { [] }
    func diagnose(locations: Locations) async -> [DoctorItem] { [] }
    func launch(_ device: VirtualDevice, options: LaunchOptions, locations: Locations) async throws {}
    func stop(_ device: VirtualDevice) async throws {}
    func setupPlan(locations: Locations) async -> SetupPlan { SampleData.setupPlan }
    func installedSystemImages(locations: Locations) async -> [SystemImage] { [] }
    func deviceProfiles(locations: Locations) async throws -> [DeviceProfile] { [] }
    func validateDeviceName(_ name: String, locations: Locations) async -> String? { nil }
    func createDevice(_ request: CreateDeviceRequest, locations: Locations) async throws {}
    func deleteDevice(_ device: VirtualDevice, locations: Locations) async throws {}

    func runSetupStep(_ step: SetupStep, locations: Locations) async throws -> SetupStepResult {
        step.kind == failAt
            ? SetupStepResult(exitCode: 1, output: "Warning: Could not find sdkmanager\nError: Unknown command line argument --licenses")
            : SetupStepResult(exitCode: 0, output: "")
    }
}

/// Serves the catalogs for the New Device sheet.
private struct ConfigurableCatalogService: DeviceService {
    let images: [SystemImage]
    let profilesError: String?

    func snapshot(locations: Locations) async -> DeviceSnapshot { await PreviewDeviceService().snapshot(locations: locations) }
    func runningDevices() async -> [RunningDevice] { [] }
    func diagnose(locations: Locations) async -> [DoctorItem] { [] }
    func launch(_ device: VirtualDevice, options: LaunchOptions, locations: Locations) async throws {}
    func stop(_ device: VirtualDevice) async throws {}
    func setupPlan(locations: Locations) async -> SetupPlan { .empty }
    func runSetupStep(_ step: SetupStep, locations: Locations) async throws -> SetupStepResult { SetupStepResult(exitCode: 0, output: "") }
    func installedSystemImages(locations: Locations) async -> [SystemImage] { images }

    func deviceProfiles(locations: Locations) async throws -> [DeviceProfile] {
        if let profilesError { throw ServiceError(profilesError) }
        return SampleData.deviceProfiles
    }

    func validateDeviceName(_ name: String, locations: Locations) async -> String? { nil }
    func createDevice(_ request: CreateDeviceRequest, locations: Locations) async throws {}
    func deleteDevice(_ device: VirtualDevice, locations: Locations) async throws {}
}
