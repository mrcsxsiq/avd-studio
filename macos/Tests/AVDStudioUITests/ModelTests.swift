import AppKit
import Foundation
import Testing
@testable import AVDStudioUI

@Suite("Models and theme")
struct ModelTests {
    @Test func releaseLabelPrefersTheAndroidVersionThenTheApiLevel() {
        #expect(VirtualDevice(id: "a", apiLevel: "34", androidVersion: "14").releaseLabel == "Android 14")
        #expect(VirtualDevice(id: "a", apiLevel: "99").releaseLabel == "API 99")
        #expect(VirtualDevice(id: "a").releaseLabel == "Unknown version")
    }

    @Test func displayNameDefaultsToTheIdWithSpaces() {
        #expect(VirtualDevice(id: "Medium_Phone_2").displayName == "Medium Phone 2")
        #expect(VirtualDevice(id: "x", displayName: "Custom").displayName == "Custom")
    }

    @Test func ramIsShownInGigabytesWhenItIsRound() {
        #expect(VirtualDevice(id: "a", ramMegabytes: 4096).ramLabel == "4 GB RAM")
        #expect(VirtualDevice(id: "a", ramMegabytes: 1536).ramLabel == "1536 MB RAM")
        #expect(VirtualDevice(id: "a").ramLabel == nil)
    }

    @Test func onlyReadyDevicesAreLaunchable() {
        #expect(VirtualDevice(id: "a", status: .ready).isLaunchable)
        #expect(!VirtualDevice(id: "a", status: .missingSystemImage).isLaunchable)
        #expect(!VirtualDevice(id: "a", status: .invalidConfiguration).isLaunchable)
    }

    @Test func everyKindHasATitleAndASymbol() {
        for kind in DeviceKind.allCases {
            #expect(!kind.title.isEmpty)
            #expect(!kind.pluralTitle.isEmpty)
            #expect(!kind.symbolName.isEmpty)
        }
    }

    @Test func paletteIsDeterministicAcrossRuns() {
        // FNV-1a is specified, so these values never change between launches (unlike Swift's hashValue).
        #expect(DevicePalette.fnv1a("") == 0xcbf2_9ce4_8422_2325)
        #expect(DevicePalette.fnv1a("a") == 0xaf63_dc4c_8601_ec8c)
        #expect(DevicePalette(kind: .phone, seed: "Pixel_9") == DevicePalette(kind: .phone, seed: "Pixel_9"))
    }

    @Test func paletteKeepsDevicesOfTheSameKindRecognisableButDistinct() {
        let a = DevicePalette(kind: .phone, seed: "Pixel_9")
        let b = DevicePalette(kind: .phone, seed: "Pixel_8")

        #expect(a != b)
        #expect(abs(a.hue - b.hue) <= 0.1 + 1e-9)
        #expect((0...1).contains(a.hue) && (0...1).contains(a.accentHue))
    }

    @Test func paletteSeparatesKindsByHue() {
        let hues = DeviceKind.allCases.filter { $0 != .unknown }.map { DevicePalette(kind: $0, seed: "x").hue }
        #expect(Set(hues.map { ($0 * 20).rounded() }).count == hues.count)
    }

    @Test func serviceErrorExposesItsMessage() {
        #expect(ServiceError("boom").localizedDescription == "boom")
    }
}

@Suite("Appearance")
struct AppearanceTests {
    @Test func offersSystemLightAndDarkInThatOrder() {
        #expect(AppearanceMode.allCases == [.system, .light, .dark])
    }

    @Test func mapsToSwiftUIColorSchemes() {
        #expect(AppearanceMode.system.colorScheme == nil)
        #expect(AppearanceMode.light.colorScheme == .light)
        #expect(AppearanceMode.dark.colorScheme == .dark)
    }

    @Test func mapsToAppKitAppearances() {
        #expect(AppearanceMode.system.appKitAppearance == nil)
        #expect(AppearanceMode.light.appKitAppearance?.name == .aqua)
        #expect(AppearanceMode.dark.appKitAppearance?.name == .darkAqua)
    }

    @Test func storedRawValuesRoundTripAndUnknownOnesFallBackToSystem() {
        for mode in AppearanceMode.allCases {
            #expect(AppearanceMode(rawValue: mode.rawValue) == mode)
        }
        #expect(AppearanceMode(rawValue: "sepia") == nil)
    }
}

@Suite("Menu bar icons")
struct MenuBarIconTests {
    @Test func offersTenChoicesIncludingTheDroid() {
        #expect(MenuBarIcon.allCases.count == 10)
        #expect(MenuBarIcon.allCases.contains(.droid))
        #expect(Set(MenuBarIcon.allCases.map(\.rawValue)).count == 10)
        #expect(Set(MenuBarIcon.allCases.map(\.title)).count == 10)
    }

    @Test func everySymbolBackedIconUsesARealSymbol() {
        for icon in MenuBarIcon.allCases {
            if let name = icon.symbolName {
                #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil, "\(icon) uses a missing symbol \(name)")
            }
        }
        #expect(MenuBarIcon.droid.symbolName == nil)
    }

    @Test func everyIconIsAnEighteenPointTemplateImage() {
        for icon in MenuBarIcon.allCases {
            let image = icon.image(running: false)
            #expect(image.isTemplate, "\(icon) must be a template so macOS can tint it")
            #expect(image.size == NSSize(width: 18, height: 18))
        }
    }

    @Test func theRunningDotChangesThePixels() throws {
        for icon in MenuBarIcon.allCases {
            let idle = try #require(icon.image(running: false).tiffRepresentation)
            let running = try #require(icon.image(running: true).tiffRepresentation)
            #expect(idle != running, "\(icon) must look different while an emulator is running")
        }
    }

    @Test func iconsActuallyDrawSomething() throws {
        for icon in MenuBarIcon.allCases {
            let tiff = try #require(icon.image(running: false).tiffRepresentation)
            let bitmap = try #require(NSBitmapImageRep(data: tiff))
            var opaque = 0
            for x in 0..<bitmap.pixelsWide {
                for y in 0..<bitmap.pixelsHigh where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 { opaque += 1 }
            }
            #expect(opaque > 20, "\(icon) rendered blank")
        }
    }

    @Test func unknownStoredValuesFallBackToTheDefault() {
        #expect(MenuBarIcon(rawValue: "unicorn") == nil)
        #expect(MenuBarIcon(rawValue: "droid") == .droid)
    }
}
