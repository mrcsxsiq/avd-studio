import Foundation
import Testing

@testable import AVDStudioUI

@Suite("SetupModel")
@MainActor
struct SetupModelTests {
    private let scripts = FileManager.default.temporaryDirectory.appendingPathComponent("avdstudio-setup-\(UUID().uuidString)")

    private func makeModel(_ plan: SetupPlan = SampleData.setupPlan, fake: FakeDeviceService = FakeDeviceService()) -> (
        SetupModel, RecordingOpener
    ) {
        let opener = RecordingOpener()
        try? FileManager.default.createDirectory(at: scripts, withIntermediateDirectories: true)
        return (SetupModel(plan: plan, service: fake, locations: Locations(), opener: opener, scriptsDirectory: scripts), opener)
    }

    @Test func cannotStartUntilTheLicenseIsAccepted() {
        let (model, _) = makeModel()

        #expect(model.canStart == false)
        model.acceptedLicense = true
        #expect(model.canStart)
    }

    @Test func needsNoLicenseWhenNoStepAcceptsOne() {
        let javaOnly = SetupPlan(steps: [SampleData.setupPlan.steps[1]], homebrewInstalled: true, sdkPath: "/sdk", shellScript: "")
        let (model, _) = makeModel(javaOnly)

        #expect(model.canStart)
    }

    @Test func cannotStartWithoutHomebrewWhenAStepNeedsIt() {
        let (model, _) = makeModel(SampleData.setupPlanWithoutHomebrew)
        model.acceptedLicense = true

        #expect(model.canStart == false)
    }

    @Test func runsEveryStepInOrderAndFinishes() async {
        let fake = FakeDeviceService()
        let (model, _) = makeModel(fake: fake)
        model.acceptedLicense = true

        await model.run()

        #expect(await fake.ranSteps == [.commandLineTools, .java, .licenses, .sdkPackages])
        #expect(model.plan.steps.allSatisfy { model.state(of: $0) == .succeeded })
        #expect(model.isFinished)
        #expect(model.failedStep == nil)
    }

    @Test func refusesToRunBeforeTheLicenseIsAccepted() async {
        let fake = FakeDeviceService()
        let (model, _) = makeModel(fake: fake)

        await model.run()

        #expect(await fake.ranSteps.isEmpty)
        #expect(model.isFinished == false)
    }

    @Test func stopsAtTheFirstFailureAndKeepsTheOutputTail() async {
        let fake = FakeDeviceService()
        await fake.setStepExitCodes([.java: 1])
        let (model, _) = makeModel(fake: fake)
        model.acceptedLicense = true

        await model.run()

        #expect(await fake.ranSteps == [.commandLineTools, .java])
        #expect(model.state(of: model.plan.steps[0]) == .succeeded)
        #expect(model.state(of: model.plan.steps[1]) == .failed(output: "line1\nline2\nError: something broke"))
        #expect(model.state(of: model.plan.steps[2]) == .pending)
        #expect(model.failedStep?.kind == .java)
        #expect(model.isFinished == false)
    }

    @Test func retryingSkipsTheStepsThatAlreadySucceeded() async {
        let fake = FakeDeviceService()
        await fake.setStepExitCodes([.java: 1])
        let (model, _) = makeModel(fake: fake)
        model.acceptedLicense = true
        await model.run()

        await fake.setStepExitCodes([:])
        await model.run()

        #expect(await fake.ranSteps == [.commandLineTools, .java, .java, .licenses, .sdkPackages])
        #expect(model.isFinished)
    }

    @Test func aCommandThatCannotStartIsReportedAsAFailure() async {
        let fake = FakeDeviceService()
        await fake.setStartFailures([.commandLineTools])
        let (model, _) = makeModel(fake: fake)
        model.acceptedLicense = true

        await model.run()

        #expect(model.state(of: model.plan.steps[0]) == .failed(output: "Cannot execute brew: file not found."))
        #expect(await fake.ranSteps == [.commandLineTools])
    }

    @Test func openInTerminalWritesAnExecutableCommandFileAndOpensIt() throws {
        let (model, opener) = makeModel(SampleData.setupPlanWithoutHomebrew)

        let file = try #require(model.openInTerminal())

        #expect(file.pathExtension == "command")
        #expect(opener.opened == [file])
        let contents = try String(contentsOf: file, encoding: .utf8)
        #expect(contents.hasPrefix("#!/bin/bash"))
        #expect(contents.contains("install.sh"))
        let permissions = try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int
        #expect(permissions == 0o755)
        try? FileManager.default.removeItem(at: scripts)
    }
}

@Suite("SetupPlan model")
struct SetupPlanModelTests {
    @Test func derivedFlags() {
        #expect(SetupPlan.empty.isEmpty)
        #expect(SetupPlan.empty.canRunAutomatically == false)
        #expect(SampleData.setupPlan.canRunAutomatically)
        #expect(SampleData.setupPlan.needsLicenseAcceptance)
        #expect(SampleData.setupPlanWithoutHomebrew.needsHomebrew)
        #expect(SampleData.setupPlanWithoutHomebrew.canRunAutomatically == false)
    }
}

@Suite("AppModel setup integration")
@MainActor
struct AppModelSetupTests {
    @Test func completeSetupSwitchesToTheInstalledSdkWhenTheOldOneWasUnusable() async {
        let fake = FakeDeviceService(devices: [], toolchain: SampleData.missingToolchain)
        await fake.setPlan(SampleData.setupPlan)
        let defaults = UserDefaults(suiteName: "avdstudio.tests.\(UUID())")!
        let model = AppModel(service: fake, defaults: defaults)
        await model.refresh()
        #expect(model.needsSetup)

        await model.completeSetup(SampleData.setupPlan)

        #expect(model.locations.sdkPath == "/opt/homebrew/share/android-commandlinetools")
        #expect(await fake.snapshotRequests.last?.sdkPath == "/opt/homebrew/share/android-commandlinetools")
    }

    @Test func completeSetupKeepsAWorkingSdkAlone() async {
        let fake = FakeDeviceService()
        let defaults = UserDefaults(suiteName: "avdstudio.tests.\(UUID())")!
        let model = AppModel(service: fake, defaults: defaults)
        await model.refresh()

        await model.completeSetup(SampleData.setupPlan)

        #expect(model.locations.sdkPath == nil)
    }
}
