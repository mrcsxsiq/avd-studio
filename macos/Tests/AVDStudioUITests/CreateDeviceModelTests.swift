import Foundation
import Testing

@testable import AVDStudioUI

@Suite("CreateDeviceModel")
@MainActor
struct CreateDeviceModelTests {
    private func makeModel(
        _ fake: FakeDeviceService = FakeDeviceService(), existing: [String] = ["Pixel_9_API_36"], kind: DeviceKind = .phone
    ) async -> CreateDeviceModel {
        let model = CreateDeviceModel(service: fake, locations: Locations(), existingNames: existing, kind: kind)
        await model.load()
        return model
    }

    @Test func loadsCatalogsAndPicksSensibleDefaultsForPhones() async {
        let model = await makeModel()

        #expect(model.phase == .ready)
        #expect(model.availableKinds == [.phone, .foldable, .tablet, .wearOS, .desktop, .tv, .automotive, .xr])
        #expect(model.device?.id == "pixel_9")
        #expect(model.image?.packagePath == "system-images;android-36;google_apis_playstore;arm64-v8a", "newest Play image first")
        #expect(model.imagesForKind.allSatisfy { $0.family == .general })
        #expect(model.name == "Pixel_9_API_36_2", "the suggestion avoids the existing name")
        #expect(model.canCreate)
    }

    @Test func switchingKindUpdatesDeviceImageAndName() async {
        let model = await makeModel()

        model.kind = .tv

        #expect(model.device?.id == "tv_1080p")
        #expect(model.imagesForKind.map(\.packagePath) == ["system-images;android-36;android-tv;arm64-v8a"])
        #expect(model.image?.family == .tv)
        #expect(model.name == "Television_1080p_API_36")
    }

    @Test func picksUpAnImageDownloadedWhileTheSheetIsOpen() async {
        let fake = FakeDeviceService()
        await fake.setImages([])
        let model = await makeModel(fake)
        #expect(model.imagesForKind.isEmpty)
        #expect(model.image == nil)
        #expect(!model.canCreate)

        await fake.setImages(SampleData.systemImages)
        await model.reloadImages()

        #expect(!model.imagesForKind.isEmpty)
        #expect(model.image?.packagePath == "system-images;android-36;google_apis_playstore;arm64-v8a")
        #expect(model.canCreate)
    }

    @Test func keepsTheChosenImageWhenTheListChanges() async {
        let fake = FakeDeviceService()
        let model = await makeModel(fake)
        let older = model.imagesForKind.first { $0.packagePath == "system-images;android-34;google_apis_playstore;arm64-v8a" }!
        model.image = older

        await fake.setImages(Array(SampleData.systemImages.dropLast()))  // something else was removed
        await model.reloadImages()

        #expect(model.image == older, "the user's choice survives a refresh")
    }

    @Test func movesOffAnImageThatWasRemoved() async {
        let fake = FakeDeviceService()
        let model = await makeModel(fake)
        let chosen = model.image!

        await fake.setImages(SampleData.systemImages.filter { $0.packagePath != chosen.packagePath })
        await model.reloadImages()

        #expect(model.image != chosen)
        #expect(model.image != nil, "it falls back to the next image of the same kind")
    }

    @Test func aKindWithoutImagesCannotCreateButExplainsItself() async {
        let model = await makeModel()

        model.kind = .wearOS

        #expect(model.device?.id == "wearos_large_round")
        #expect(model.imagesForKind.isEmpty)
        #expect(model.image == nil)
        #expect(model.canCreate == false)
    }

    @Test func nameValidationMatchesAvdmanagerRules() async {
        let model = await makeModel()

        model.name = "has space"
        #expect(model.nameError == "Use only letters, digits, dots, dashes and underscores (no spaces).")
        model.name = "pixel_9_api_36"
        #expect(model.nameError == "A device called pixel_9_api_36 already exists.")
        model.name = " "
        #expect(model.nameError == "Give the device a name.")
        model.name = "Fresh.Device-1"
        #expect(model.nameError == nil)
        #expect(model.canCreate)
    }

    @Test func aNameTypedByTheUserIsKeptWhenTheDeviceChanges() async {
        let model = await makeModel()
        model.name = "Mine"

        model.device = SampleData.deviceProfiles.first { $0.id == "pixel_9_pro" }

        #expect(model.name == "Mine")
    }

    @Test func createSendsTheFullRequestAndReportsTheName() async {
        let fake = FakeDeviceService()
        let model = await makeModel(fake)
        model.displayName = "  My Pixel  "
        model.ram = .gb4
        model.storage = .gb16
        model.sdCard = .mb512

        await model.create()

        let request = await fake.created.single
        #expect(request?.name == "Pixel_9_API_36_2")
        #expect(request?.displayName == "My Pixel")
        #expect(request?.device.id == "pixel_9")
        #expect(request?.systemImage.hasPlayStore == true)
        #expect(request?.ramMegabytes == 4096)
        #expect(request?.storage == "16G")
        #expect(request?.sdCard == "512M")
        #expect(model.phase == .created(name: "Pixel_9_API_36_2"))
    }

    @Test func defaultsLeaveHardwareValuesToTheDefinition() async {
        let fake = FakeDeviceService()
        let model = await makeModel(fake)

        await model.create()

        let request = await fake.created.single
        #expect(request?.displayName == nil)
        #expect(request?.ramMegabytes == nil)
        #expect(request?.storage == nil)
        #expect(request?.sdCard == nil)
    }

    @Test func createFailuresAreShownAndTheFormStaysEditable() async {
        let fake = FakeDeviceService()
        await fake.setCreateError(ServiceError("Could not create X: No device found matching --device pixel_9."))
        let model = await makeModel(fake)

        await model.create()

        #expect(model.errorMessage?.contains("No device found") == true)
        #expect(model.phase == .ready)
    }

    @Test func missingAvdmanagerMakesTheSheetUnavailable() async {
        let fake = FakeDeviceService()
        await fake.setProfilesError(ServiceError("avdmanager needs a Java runtime and none was found. Run setup first."))
        let model = await makeModel(fake)

        #expect(model.phase == .unavailable("avdmanager needs a Java runtime and none was found. Run setup first."))
        #expect(model.canCreate == false)
    }

    @Test func startsOnTheRequestedKindWhenItExists() async {
        let model = await makeModel(kind: .tablet)

        #expect(model.kind == .tablet)
        #expect(model.device?.id == "pixel_tablet")
    }
}

extension Array {
    var single: Element? { count == 1 ? first : nil }
}

@Suite("AppModel create and delete")
@MainActor
struct AppModelCreateDeleteTests {
    @Test func presentCreateDevicePreselectsTheSidebarKindAndKnowsExistingNames() async {
        let model = AppModel(service: FakeDeviceService(), defaults: UserDefaults(suiteName: "avdstudio.tests.\(UUID())")!)
        await model.refresh()
        model.sidebarSelection = .kind(.tv)

        model.presentCreateDevice()

        #expect(model.creating?.kind == .tv)
        #expect(model.creating?.existingNames.contains("Pixel_9_API_36") == true)
    }

    @Test func deviceCreatedRefreshesSelectsAndShowsIt() async {
        let fake = FakeDeviceService()
        let model = AppModel(service: fake, defaults: UserDefaults(suiteName: "avdstudio.tests.\(UUID())")!)
        await model.refresh()
        model.sidebarSelection = .kind(.tv)
        let request = CreateDeviceRequest(name: "Fresh", systemImage: SampleData.systemImages[0], device: SampleData.deviceProfiles[0])
        try? await fake.createDevice(request, locations: Locations())

        await model.deviceCreated(named: "Fresh")

        #expect(model.selection == "Fresh")
        #expect(model.sidebarSelection == .all, "a phone would be hidden under the TV filter")
        #expect(model.devices.contains { $0.id == "Fresh" })
    }

    @Test func deleteAsksForConfirmationThenRemovesTheDevice() async {
        let fake = FakeDeviceService()
        let model = AppModel(service: fake, defaults: UserDefaults(suiteName: "avdstudio.tests.\(UUID())")!)
        await model.refresh()
        let device = SampleData.devices[0]

        model.pendingDelete = device
        #expect(await fake.deleted.isEmpty)
        await model.confirmDelete()

        #expect(await fake.deleted == [device.id])
        #expect(model.pendingDelete == nil)
        #expect(!model.devices.contains { $0.id == device.id })
    }

    @Test func deleteFailuresAreReported() async {
        let fake = FakeDeviceService()
        await fake.setDeleteError(ServiceError("Pixel_9_API_36 is running. Stop it first."))
        let model = AppModel(service: fake, defaults: UserDefaults(suiteName: "avdstudio.tests.\(UUID())")!)
        await model.refresh()
        model.pendingDelete = SampleData.devices[0]

        await model.confirmDelete()

        #expect(model.errorMessage == "Pixel_9_API_36 is running. Stop it first.")
    }
}
