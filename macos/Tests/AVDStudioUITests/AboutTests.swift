import AppKit
import Foundation
import SwiftUI
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

@Suite("Settings tabs")
@MainActor
struct SettingsTabTests {
    @Test func settingsHasGeneralAndroidSystemImagesAndAboutInThatOrder() {
        #expect(SettingsTab.allCases == [.general, .android, .images, .about])
        #expect(SettingsTab.allCases.map(\.title) == ["General", "Android", "System Images", "About"])
        #expect(Set(SettingsTab.allCases.map(\.symbolName)).count == 4)
    }

    @Test func theAboutTabIsBigEnoughForTheAboutPage() {
        let natural = NSHostingView(rootView: AboutView(model: AboutModel(info: AppInfo(version: "0.1.0", build: "1")), icon: NSImage()))
            .fittingSize
        let tab = SettingsTab.about.size

        #expect(natural.height <= tab.height, "About needs \(natural.height) pt but its tab is \(tab.height) pt: it would be clipped")
        #expect(natural.width <= tab.width)
    }

    @Test func everyTabHasARoomySize() {
        for tab in SettingsTab.allCases {
            #expect(tab.size.width >= 500 && tab.size.height >= 400, "\(tab)")
        }
        #expect(SettingsTab.allCases.allSatisfy { $0.size.height <= 760 }, "a Settings window must fit a laptop screen")
    }
}
