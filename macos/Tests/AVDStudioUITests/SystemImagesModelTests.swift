import Foundation
import Testing

@testable import AVDStudioUI

@Suite("System images")
@MainActor
struct SystemImagesModelTests {
    private let playStore36 = "system-images;android-36;google_apis_playstore;arm64-v8a"
    private let play37 = "system-images;android-37.0;google_apis_playstore;arm64-v8a"
    private let apis37 = "system-images;android-37.0;google_apis;arm64-v8a"
    private let wear36 = "system-images;android-36;android-wear;arm64-v8a"

    private func make(
        service: FakeDeviceService = FakeDeviceService(), devices: [VirtualDevice] = SampleData.devices
    ) -> (SystemImagesModel, FakeDeviceService) {
        let model = SystemImagesModel(service: service)
        model.devices = devices
        return (model, service)
    }

    private func loadedModel() async -> (SystemImagesModel, FakeDeviceService) {
        let (model, service) = make()
        await model.loadInstalled()
        await model.loadCatalog()
        return (model, service)
    }

    private func image(_ package: String) -> RemoteSystemImage {
        SampleData.availableImages.first { $0.packagePath == package }!
    }

    // MARK: Installed

    @Test func listsTheInstalledImagesAndAddsUpTheirSize() async {
        let (model, _) = make()
        #expect(!model.hasLoadedInstalled)

        await model.loadInstalled()

        #expect(model.hasLoadedInstalled)
        #expect(model.installed.count == SampleData.systemImages.count)
        #expect(model.installedBytes == SampleData.systemImages.compactMap(\.sizeBytes).reduce(0, +))
        #expect(model.installedBytes > 0)
    }

    @Test func anImageSizeThatIsUnknownCountsAsZero() async {
        let service = FakeDeviceService()
        let unknown = SystemImage(
            packagePath: playStore36, apiLevel: "36", androidVersion: "16", versionLabel: "Android 16 (API 36)",
            tagDisplay: "Google Play", abi: "arm64-v8a", hasPlayStore: true, isNativeOnAppleSilicon: true, family: .general)
        await service.setImages([unknown])
        let (model, _) = make(service: service)

        await model.loadInstalled()

        #expect(model.installedBytes == 0)
    }

    @Test func knowsWhichDevicesBootFromAnImage() async {
        let (model, _) = make()
        await model.loadInstalled()
        let play36 = model.installed.first { $0.packagePath == playStore36 }!

        #expect(model.devices(using: play36).map(\.id) == ["Pixel_9_API_36"])
    }

    @Test func matchesAnImageNoMatterHowItsPackageIsSpelled() async {
        let slash = VirtualDevice(id: "A", systemImagePackage: "system-images/android-36/google_apis_playstore/arm64-v8a/")
        let (model, _) = make(devices: [slash])
        await model.loadInstalled()
        let play36 = model.installed.first { $0.packagePath == playStore36 }!

        #expect(model.devices(using: play36).map(\.id) == ["A"])
        #expect(samePackage("system-images;android-36;x;arm64-v8a", "system-images/android-36/x/arm64-v8a/"))
        #expect(!samePackage("system-images;android-36;x;arm64-v8a", "system-images;android-35;x;arm64-v8a"))
    }

    // MARK: Available

    @Test func asksGoogleOnlyWhenTheUserAsks() async {
        let (model, service) = make()
        await model.loadInstalled()

        #expect(model.catalog == .notLoaded)
        #expect(await service.availableRequests == 0)

        await model.loadCatalog()

        #expect(await service.availableRequests == 1)
        guard case .loaded(let images) = model.catalog else {
            Issue.record("expected a loaded catalog, got \(model.catalog)")
            return
        }
        #expect(images.count == SampleData.availableImages.count)
    }

    @Test func explainsWhyTheListCouldNotBeLoaded() async {
        let (model, service) = make()
        await service.setAvailableError(ServiceError("sdkmanager needs Java. Run `avdstudio setup`."))

        await model.loadCatalog()

        #expect(model.catalog == .failed("sdkmanager needs Java. Run `avdstudio setup`."))
        #expect(model.downloadable.isEmpty)
    }

    @Test func offersOnlyWhatIsNotInstalledAndHidesPreviewsAndTestImages() async {
        let (model, _) = await loadedModel()

        let offered = Set(model.downloadable.map(\.packagePath))

        #expect(!offered.contains(playStore36), "already installed")
        #expect(offered.contains(play37))
        #expect(offered.contains(apis37))
        #expect(!model.downloadable.contains { $0.isPreview }, "previews are hidden by default")
        #expect(!model.downloadable.contains { $0.isAutomatedTestImage }, "test images are hidden by default")
    }

    @Test func showsPreviewsAndTestImagesOnRequest() async {
        let (model, _) = await loadedModel()

        model.showAdvanced = true

        #expect(model.downloadable.contains { $0.isPreview })
        #expect(model.downloadable.contains { $0.isAutomatedTestImage })
    }

    @Test func narrowsTheListToOneKindOfDevice() async {
        let (model, _) = await loadedModel()

        model.familyFilter = .wearOS

        #expect(model.downloadable.map(\.packagePath) == [wear36])
        model.familyFilter = .tv
        #expect(model.downloadable.isEmpty)
        model.familyFilter = .all
        #expect(model.downloadable.count > 1)
    }

    @Test func groupsTheListByAndroidVersionNewestFirst() async {
        let (model, _) = await loadedModel()

        let titles = model.downloadableGroups.map(\.title)

        #expect(titles == ["Android 17 (API 37)", "Android 16 (API 36)", "Android 15 (API 35)"])
        #expect(model.downloadableGroups[0].images.count == 3)
        #expect(model.downloadableGroups[1].images.map(\.packagePath) == [wear36], "the installed Play image is not offered")
    }

    // MARK: Download

    @Test func nothingIsDownloadedWithoutTheLicenseBox() async {
        let (model, service) = await loadedModel()
        model.toggle(image(play37))

        #expect(!model.canInstall, "an image is selected but the license is not accepted")
        await model.install()

        #expect(await service.installs.isEmpty)
        #expect(model.work == .idle)
    }

    @Test func nothingIsDownloadedWithoutAnImage() async {
        let (model, service) = await loadedModel()
        model.acceptedLicense = true

        #expect(!model.canInstall)
        await model.install()

        #expect(await service.installs.isEmpty)
    }

    @Test func downloadsTheSelectedImagesOneByOneAfterTheLicenseIsAccepted() async {
        let (model, service) = await loadedModel()
        model.toggle(image(play37))
        model.toggle(image(apis37))
        model.acceptedLicense = true
        #expect(model.canInstall)
        #expect(model.selectedImages.count == 2)

        await model.install()

        let installs = await service.installs
        #expect(installs.map { $0.packages } == [[apis37], [play37]], "one image per call, in a stable order, so progress can say which")
        #expect(installs.allSatisfy { $0.licenseAccepted }, "the service is only ever told the user accepted")
        #expect(model.work == .idle)
        #expect(model.notice == "Downloaded 2 images.")
        #expect(model.selection.isEmpty)
        #expect(model.installed.contains { $0.packagePath == play37 }, "the installed list is read again")
        #expect(!model.downloadable.contains { $0.packagePath == play37 }, "an installed image is no longer offered")
    }

    @Test func whenOneImageFailsTheOnesThatArrivedStayInstalled() async {
        let (model, service) = await loadedModel()
        await service.setFailingPackages([play37])
        model.toggle(image(play37))
        model.toggle(image(apis37))
        model.acceptedLicense = true

        await model.install()

        guard case .failed(let output) = model.work else {
            Issue.record("expected a failure, got \(model.work)")
            return
        }
        #expect(output.contains("download failed"))
        #expect(model.installed.contains { $0.packagePath == apis37 }, "the first image made it")
        #expect(!model.installed.contains { $0.packagePath == play37 })
        #expect(model.selection == [play37], "only the one that failed stays selected for another try")
        #expect(!model.downloadable.contains { $0.packagePath == apis37 })
    }

    @Test func stopsAtTheFirstFailureInsteadOfTryingTheRest() async {
        let (model, service) = await loadedModel()
        await service.setFailingPackages([apis37])  // sorts first
        model.toggle(image(play37))
        model.toggle(image(apis37))
        model.acceptedLicense = true

        await model.install()

        #expect(await service.installs.map { $0.packages } == [[apis37]], "the second image is not attempted after the first failed")
        #expect(model.work.isFailedForTest)
    }

    // MARK: Progress

    @Test func showsWhichImageIsComingAndHowManyBytesArrived() async {
        let service = FakeDeviceService()
        await service.setInstallDelay(.milliseconds(250))
        await service.setBytesScript([0, 400_000_000, 1_500_000_000])
        let model = SystemImagesModel(service: service, pollInterval: .milliseconds(10))
        await model.loadInstalled()
        await model.loadCatalog()
        model.toggle(image(wear36))
        model.acceptedLicense = true

        let run = Task { await model.install() }
        let sawBytes = await eventually {
            if case .installing(let progress) = model.work { progress.bytesDownloaded >= 1_500_000_000 } else { false }
        }

        #expect(sawBytes, "the bar's text follows the bytes that reached the disk")
        if case .installing(let progress) = model.work {
            #expect(progress.imageIndex == 1 && progress.imageCount == 1)
            #expect(progress.imageName == "Android 16 (API 36) · Wear OS")
        }
        await run.value
        #expect(model.work == .idle)
    }

    @Test func theByteCountNeverGoesBackwards() async {
        let service = FakeDeviceService()
        await service.setInstallDelay(.milliseconds(200))
        await service.setBytesScript([900, 100, 100])  // a file being replaced can look smaller for a moment
        let model = SystemImagesModel(service: service, pollInterval: .milliseconds(10))
        await model.loadInstalled()
        await model.loadCatalog()
        model.toggle(image(wear36))
        model.acceptedLicense = true

        let run = Task { await model.install() }
        _ = await eventually { if case .installing(let progress) = model.work { progress.bytesDownloaded >= 900 } else { false } }
        try? await Task.sleep(for: .milliseconds(60))

        if case .installing(let progress) = model.work { #expect(progress.bytesDownloaded == 900) }
        await run.value
    }

    @Test func countsOnlyWhatArrivesAfterTheInstallStarted() async {
        let started = Date(timeIntervalSince1970: 1_800_000_000)
        let service = FakeDeviceService()
        let model = SystemImagesModel(service: service, pollInterval: .milliseconds(5), now: { started })
        await model.loadInstalled()
        await model.loadCatalog()
        model.toggle(image(wear36))
        model.acceptedLicense = true

        await model.install()

        let since = await service.bytesRequests
        #expect(!since.isEmpty)
        #expect(since.allSatisfy { $0 == started.addingTimeInterval(-1) }, "a little slack for the file system's coarser clock")
    }

    // MARK: The dialog

    @Test func openingTheDialogAsksGoogleForTheListOnce() async {
        let (model, service) = make()

        model.openPicker()
        #expect(model.isPickerPresented)
        let loaded = await eventually { if case .loaded = model.catalog { true } else { false } }
        #expect(loaded)

        model.closePicker()
        #expect(!model.isPickerPresented)
        model.openPicker()
        try? await Task.sleep(for: .milliseconds(30))
        #expect(await service.availableRequests == 1, "reopening shows the list it already has")
    }

    @Test func openingTheDialogAfterAFailureTriesAgain() async {
        let (model, service) = make()
        await service.setAvailableError(ServiceError("offline"))
        model.openPicker()
        _ = await eventually { model.catalog == .failed("offline") }

        await service.setAvailableError(nil)
        model.closePicker()
        model.openPicker()

        let recovered = await eventually { if case .loaded = model.catalog { true } else { false } }
        #expect(recovered)
    }

    @Test func aDownloadKeepsGoingWhileTheDialogIsClosed() async {
        let service = FakeDeviceService()
        await service.setInstallDelay(.milliseconds(150))
        let model = SystemImagesModel(service: service, pollInterval: .milliseconds(10))
        await model.loadInstalled()
        await model.loadCatalog()
        model.openPicker()
        model.toggle(image(wear36))
        model.acceptedLicense = true

        let run = Task { await model.install() }
        _ = await eventually { model.work.isBusy }
        model.closePicker()

        #expect(!model.isPickerPresented)
        #expect(model.work.isBusy, "closing the dialog does not stop the download")
        await run.value
        #expect(model.notice == "Downloaded 1 image.")
    }

    @Test func aSingleImageGetsASingularNotice() async {
        let (model, _) = await loadedModel()
        model.toggle(image(wear36))
        model.acceptedLicense = true

        await model.install()

        #expect(model.notice == "Downloaded 1 image.")
    }

    @Test func showsTheEndOfTheOutputWhenTheDownloadFails() async {
        let (model, service) = await loadedModel()
        await service.setInstall(exitCode: 1)
        model.toggle(image(play37))
        model.acceptedLicense = true

        await model.install()

        guard case .failed(let output) = model.work else {
            Issue.record("expected a failure, got \(model.work)")
            return
        }
        #expect(output.contains("download failed"))
        #expect(model.selection == [play37], "the choice is kept so the user can try again")
        #expect(model.downloadable.contains { $0.packagePath == play37 })

        model.dismissFailure()
        #expect(model.work == .idle)
    }

    @Test func showsTheMessageWhenTheDownloadCannotStart() async {
        let (model, service) = await loadedModel()
        await service.setInstall(error: ServiceError("sdkmanager was not found."))
        model.toggle(image(play37))
        model.acceptedLicense = true

        await model.install()

        #expect(model.work == .failed("sdkmanager was not found."))
    }

    @Test func togglingTwiceUnselects() async {
        let (model, _) = await loadedModel()

        model.toggle(image(play37))
        #expect(model.isSelected(image(play37)))
        model.toggle(image(play37))
        #expect(!model.isSelected(image(play37)))
        model.toggle(image(apis37))
        model.clearSelection()
        #expect(model.selection.isEmpty)
    }

    // MARK: Remove

    @Test func removalNamesTheDevicesThatWouldStopWorking() async {
        let (model, _) = make()
        await model.loadInstalled()
        let play36 = model.installed.first { $0.packagePath == playStore36 }!

        model.requestRemoval(of: play36)

        #expect(model.pendingRemoval?.image == play36)
        #expect(model.pendingRemoval?.devices.map(\.id) == ["Pixel_9_API_36"])
        let message = SystemImagesSettingsTab.removalMessage(model.pendingRemoval!)
        #expect(message.contains("Pixel 9"))
        #expect(message.contains("will not start until you download it again"))
        #expect(message.contains("frees"))

        model.cancelRemoval()
        #expect(model.pendingRemoval == nil)
    }

    @Test func removalOfAnUnusedImageSaysNothingAboutDevices() async {
        let (model, _) = make()
        await model.loadInstalled()
        let tv = model.installed.first { $0.family == .tv }!

        model.requestRemoval(of: tv)

        #expect(model.pendingRemoval?.devices.isEmpty == true)
        #expect(!SystemImagesSettingsTab.removalMessage(model.pendingRemoval!).contains("will not start"))
    }

    @Test func removingAnImageADeviceUsesIsForcedAfterTheUserSawTheList() async {
        let (model, service) = await loadedModel()
        let play36 = model.installed.first { $0.packagePath == playStore36 }!
        model.requestRemoval(of: play36)

        await model.confirmRemoval(model.pendingRemoval!)

        let removals = await service.removals
        #expect(removals.count == 1)
        #expect(removals[0].package == playStore36)
        #expect(removals[0].force)
        #expect(model.pendingRemoval == nil)
        #expect(!model.installed.contains { $0.packagePath == playStore36 })
        #expect(model.notice?.hasPrefix("Removed ") == true)
        #expect(model.downloadable.contains { $0.packagePath == playStore36 }, "it can be downloaded again")
    }

    @Test func removingAnUnusedImageIsNotForced() async {
        let (model, service) = await loadedModel()
        let tv = model.installed.first { $0.family == .tv }!
        model.requestRemoval(of: tv)

        await model.confirmRemoval(model.pendingRemoval!)

        #expect(await service.removals.map(\.force) == [false])
    }

    @Test func confirmingStillWorksAfterTheDialogClearedThePendingRemoval() async {
        let (model, service) = await loadedModel()
        let tv = model.installed.first { $0.family == .tv }!
        model.requestRemoval(of: tv)
        let removal = model.pendingRemoval!

        model.cancelRemoval()  // closing the dialog does this before the button's task runs
        await model.confirmRemoval(removal)

        #expect(await service.removals.count == 1)
    }

    @Test func aFailedRemovalKeepsTheImageAndShowsWhy() async {
        let (model, service) = await loadedModel()
        await service.setRemove(exitCode: 1)
        let tv = model.installed.first { $0.family == .tv }!
        model.requestRemoval(of: tv)

        await model.confirmRemoval(model.pendingRemoval!)

        #expect(model.work == .failed("Error: could not remove"))
        #expect(model.installed.contains { $0.packagePath == tv.packagePath })
    }

    @Test func aRunningEmulatorBlocksTheRemoval() async {
        let (model, service) = await loadedModel()
        await service.setRemove(error: ServiceError("Pixel_9_API_36 is running. Stop it first."))
        let play36 = model.installed.first { $0.packagePath == playStore36 }!
        model.requestRemoval(of: play36)

        await model.confirmRemoval(model.pendingRemoval!)

        #expect(model.work == .failed("Pixel_9_API_36 is running. Stop it first."))
        #expect(model.installed.contains { $0.packagePath == playStore36 })
    }

    // MARK: Locations

    @Test func switchingSdkFoldersForgetsWhatWasLoaded() async {
        let (model, _) = await loadedModel()
        model.toggle(image(play37))

        model.locations = Locations(sdkPath: "/other/sdk")

        #expect(model.catalog == .notLoaded)
        #expect(model.installed.isEmpty)
        #expect(!model.hasLoadedInstalled)
        #expect(model.selection.isEmpty)
    }

    @Test func theAppModelKeepsTheImagesModelInSync() async {
        let service = FakeDeviceService()
        let app = AppModel(service: service, defaults: UserDefaults(suiteName: "images.\(UUID())")!)

        await app.refresh()
        #expect(app.systemImages.devices.count == SampleData.devices.count, "it learns the devices from every refresh")

        await app.update(locations: Locations(sdkPath: "/elsewhere", avdHome: nil))
        #expect(app.systemImages.locations.sdkPath == "/elsewhere")
    }

    // MARK: Settings

    @Test func theTabsKeepTheAboutPageLast() {
        #expect(SettingsTab.allCases == [.general, .android, .images, .updates, .about])
        #expect(SettingsTab.images.title == "System Images")
    }

    @Test func settingsOpensOnTheTabTheModelNames() {
        let app = AppModel(service: FakeDeviceService(), defaults: UserDefaults(suiteName: "tab.\(UUID())")!)
        #expect(app.settingsTab == .general)

        app.settingsTab = .images
        _ = SettingsView(model: app)

        #expect(app.settingsTab == .images, "building the view must not reset the tab")
    }
}

extension SystemImagesModel.Work {
    fileprivate var isFailedForTest: Bool {
        if case .failed = self { true } else { false }
    }
}
