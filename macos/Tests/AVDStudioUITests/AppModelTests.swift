import Foundation
import Testing
@testable import AVDStudioUI

@Suite("AppModel")
@MainActor
struct AppModelTests {
    private func makeModel(
        _ fake: FakeDeviceService = FakeDeviceService(),
        clock: TestClock = TestClock(),
        defaults: UserDefaults = UserDefaults(suiteName: "avdstudio.tests.\(UUID())")!
    ) -> AppModel {
        AppModel(service: fake, defaults: defaults, now: { clock.now })
    }

    private var phone: VirtualDevice { SampleData.devices[0] }
    private var brokenPhone: VirtualDevice { SampleData.devices.last! }

    // MARK: Loading

    @Test func refreshLoadsDevicesToolchainAndRunningState() async {
        let fake = FakeDeviceService(running: [RunningDevice(name: "Pixel_9_API_36", processID: 7)])
        let model = makeModel(fake)

        #expect(model.hasLoaded == false)
        await model.refresh()

        #expect(model.hasLoaded)
        #expect(model.devices.count == SampleData.devices.count)
        #expect(model.toolchain?.isConfigured == true)
        #expect(model.runState(of: phone) == .running)
        #expect(model.runningCount == 1)
        #expect(model.avdHome == "/avd")
    }

    @Test func needsSetupOnlyAfterLoadingWithABrokenToolchain() async {
        let model = makeModel(FakeDeviceService(devices: [], toolchain: SampleData.missingToolchain))

        #expect(model.needsSetup == false)
        await model.refresh()
        #expect(model.needsSetup)
    }

    @Test func selectionIsDroppedWhenItsDeviceDisappears() async {
        let fake = FakeDeviceService()
        let model = makeModel(fake)
        await model.refresh()
        model.selection = phone.id

        await fake.setDevices(Array(SampleData.devices.dropFirst()))
        await model.refresh()

        #expect(model.selection == nil)
    }

    // MARK: Filtering

    @Test func filtersBySidebarKindAndKeepsCounts() async {
        let model = makeModel()
        await model.refresh()

        model.sidebarSelection = .kind(.tv)

        #expect(model.visibleDevices.map(\.id) == ["Television_4K"])
        #expect(model.count(for: .all) == SampleData.devices.count)
        #expect(model.count(for: .kind(.phone)) == 2)
        #expect(model.currentTitle == "TVs")
    }

    @Test func searchMatchesNameKindVersionAndProfileIgnoringCase() async {
        let model = makeModel()
        await model.refresh()

        model.searchText = "FOLD"
        #expect(model.visibleDevices.map(\.id) == ["Pixel_9_Pro_Fold"])

        model.searchText = "android 13"
        #expect(model.visibleDevices.map(\.id) == ["Retroid_Pocket_5"])

        model.searchText = "wear"
        #expect(model.visibleDevices.map(\.kind) == [.wearOS])

        model.searchText = "  nothing matches  "
        #expect(model.visibleDevices.isEmpty)
    }

    @Test func searchAndKindFilterCombine() async {
        let model = makeModel()
        await model.refresh()
        model.sidebarSelection = .kind(.phone)
        model.searchText = "retroid"

        #expect(model.visibleDevices.map(\.id) == ["Retroid_Pocket_5"])
    }

    @Test func sidebarOnlyListsKindsThatHaveDevices() async {
        let model = makeModel(FakeDeviceService(devices: [SampleData.devices[0], SampleData.devices[4]]))
        await model.refresh()

        #expect(model.availableKinds == [.phone, .tv])
    }

    // MARK: Launching

    @Test func launchMarksTheDeviceAsStartingUntilItShowsUpAsRunning() async {
        let fake = FakeDeviceService()
        let model = makeModel(fake)
        await model.refresh()

        await model.launch(phone, options: LaunchOptions(coldBoot: true))

        #expect(await fake.launches == [.init(id: phone.id, options: LaunchOptions(coldBoot: true))])
        #expect(model.runState(of: phone) == .starting)

        await fake.setRunning([RunningDevice(name: phone.id, processID: 9)])
        await model.refreshRunning()
        #expect(model.runState(of: phone) == .running)
        #expect(model.startingNames.isEmpty)
    }

    @Test func startingExpiresIfTheEmulatorNeverAppears() async {
        let clock = TestClock()
        let model = makeModel(clock: clock)
        await model.refresh()
        await model.launch(phone)

        clock.advance(by: AppModel.startTimeout + 1)
        await model.refreshRunning()

        #expect(model.runState(of: phone) == .idle)
    }

    @Test func launchingTwiceDoesNotStartTwoEmulators() async {
        let fake = FakeDeviceService()
        let model = makeModel(fake)
        await model.refresh()

        await model.launch(phone)
        await model.launch(phone)

        #expect(await fake.launches.count == 1)
    }

    @Test func refusesToLaunchADeviceThatCannotBoot() async {
        let fake = FakeDeviceService()
        let model = makeModel(fake)
        await model.refresh()

        await model.launch(brokenPhone)

        #expect(await fake.launches.isEmpty)
        #expect(model.errorMessage?.contains("Retroid Pocket 5 can't start") == true)
        #expect(model.runState(of: brokenPhone) == .idle)
    }

    @Test func launchFailureIsReportedAndClearsTheStartingState() async {
        let fake = FakeDeviceService()
        await fake.setLaunchError(ServiceError("The Android emulator is not installed."))
        let model = makeModel(fake)
        await model.refresh()

        await model.launch(phone)

        #expect(model.errorMessage == "The Android emulator is not installed.")
        #expect(model.runState(of: phone) == .idle)
    }

    @Test func wipeNeedsConfirmationAndThenColdBootsWithWipe() async {
        let fake = FakeDeviceService()
        let model = makeModel(fake)
        await model.refresh()

        model.pendingWipe = phone
        #expect(await fake.launches.isEmpty)

        await model.confirmWipe()

        #expect(model.pendingWipe == nil)
        #expect(await fake.launches == [.init(id: phone.id, options: LaunchOptions(coldBoot: true, wipeData: true))])
    }

    // MARK: Stopping and toggling

    @Test func stopAsksTheServiceAndRefreshesRunningState() async {
        let fake = FakeDeviceService(running: [RunningDevice(name: phone.id, processID: 3)])
        let model = makeModel(fake)
        await model.refresh()

        await model.stop(phone)

        #expect(await fake.stops == [phone.id])
        #expect(model.runState(of: phone) == .idle)
    }

    @Test func togglePowerStartsIdleStopsRunningAndIgnoresStarting() async {
        let fake = FakeDeviceService()
        let model = makeModel(fake)
        await model.refresh()

        await model.togglePower(phone)
        #expect(model.runState(of: phone) == .starting)
        await model.togglePower(phone)
        #expect(await fake.launches.count == 1)
        #expect(await fake.stops.isEmpty)

        await fake.setRunning([RunningDevice(name: phone.id, processID: 1)])
        await model.refreshRunning()
        await model.togglePower(phone)
        #expect(await fake.stops == [phone.id])
    }

    // MARK: Locations

    @Test func locationsArePersistedTrimmedAndUsedForTheNextRefresh() async {
        let defaults = UserDefaults(suiteName: "avdstudio.tests.\(UUID())")!
        let fake = FakeDeviceService()
        let model = makeModel(fake, defaults: defaults)

        await model.update(locations: Locations(sdkPath: "  /Volumes/ssd/sdk  ", avdHome: ""))

        #expect(model.locations == Locations(sdkPath: "/Volumes/ssd/sdk", avdHome: nil))
        #expect(await fake.snapshotRequests.last == Locations(sdkPath: "/Volumes/ssd/sdk", avdHome: nil))

        let reopened = makeModel(defaults: defaults)
        #expect(reopened.locations == Locations(sdkPath: "/Volumes/ssd/sdk", avdHome: nil))
    }

    @Test func clearingALocationReturnsToAutomaticDetection() async {
        let defaults = UserDefaults(suiteName: "avdstudio.tests.\(UUID())")!
        let model = makeModel(defaults: defaults)
        await model.update(locations: Locations(sdkPath: "/x", avdHome: "/y"))

        await model.update(locations: Locations(sdkPath: nil, avdHome: nil))

        #expect(makeModel(defaults: defaults).locations == Locations())
    }
}
