import Foundation
import Testing

@testable import AVDStudioUI

@Suite("About")
@MainActor
struct AboutTests {
    @Test func showsTheRunningVersionAndBuild() {
        let info = AppInfo.current(infoDictionary: ["CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "12"])

        #expect(info.versionLine == "Version 0.1.0 (12)")
        #expect(info.name == "AVD Studio")
    }

    @Test func leavesOutAMissingBuildNumber() {
        #expect(AppInfo.current(infoDictionary: ["CFBundleShortVersionString": "1.2.3"]).versionLine == "Version 1.2.3")
        #expect(
            AppInfo.current(infoDictionary: ["CFBundleShortVersionString": "1.2.3", "CFBundleVersion": ""]).versionLine == "Version 1.2.3")
    }

    @Test func aBuildWithoutABundleSaysSoInsteadOfInventingAVersion() {
        #expect(AppInfo.current(infoDictionary: nil).versionLine == "Development build")
        #expect(AppInfo.current(infoDictionary: [:]).versionLine == "Development build")
        #expect(
            AppInfo.current(infoDictionary: ["CFBundleShortVersionString": "", "CFBundleVersion": "7"]).versionLine == "Development build")
    }

    @Test func linksPointAtTheProject() {
        #expect(AppInfo.repository.absoluteString == "https://github.com/mrcsxsiq/avd-studio")
        #expect(AppInfo.changelog.absoluteString.hasPrefix(AppInfo.repository.absoluteString))
        #expect(AppInfo.changelog.lastPathComponent == "CHANGELOG.md")
        #expect(AppInfo.license.absoluteString.hasPrefix(AppInfo.repository.absoluteString))
        #expect(AppInfo.license.lastPathComponent == "LICENSE")
        #expect(AppInfo.website.scheme == "https")
    }

    @Test func theStarButtonOpensTheRepositoryAndNothingElse() {
        let opener = RecordingOpener()
        let model = AboutModel(info: AppInfo(version: "0.1.0"), opener: opener)

        model.starRepository()

        #expect(opener.opened == [AppInfo.repository])
        #expect(opener.revealed.isEmpty)
    }

    @Test func eachLinkOpensItsOwnPage() {
        let opener = RecordingOpener()
        let model = AboutModel(info: AppInfo(version: "0.1.0"), opener: opener)

        model.openWebsite()
        model.openChangelog()
        model.openLicense()

        #expect(opener.opened == [AppInfo.website, AppInfo.changelog, AppInfo.license])
    }
}
