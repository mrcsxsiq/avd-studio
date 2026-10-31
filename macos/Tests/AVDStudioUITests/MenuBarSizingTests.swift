import AppKit
import SwiftUI
import Testing

@testable import AVDStudioUI

/// Reports how a view answers different size proposals.
private struct SizeProbe<Content: View>: View {
    let content: Content
    let report: (_ minimum: CGSize, _ ideal: CGSize) -> Void

    var body: some View {
        let layout = Prober(report: report)
        return layout { content }
    }

    private struct Prober: Layout {
        let report: (CGSize, CGSize) -> Void

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            guard let subview = subviews.first else { return .zero }
            let minimum = subview.sizeThatFits(.zero)
            let ideal = subview.sizeThatFits(.unspecified)
            report(minimum, ideal)
            return ideal
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
        }
    }
}

/// `MenuBarExtra` sizes its window from the content's *minimum* size. Every screenshot test hands the view a
/// frame and an earlier version of this test measured the ideal size, so neither noticed that the device list
/// had no height of its own: in the real app the popover was 340 x 95 pt, a header and a footer and no devices.
@Suite("Menu bar popover sizing")
@MainActor
struct MenuBarSizingTests {
    private struct Measured {
        let minimum: CGSize
        let ideal: CGSize
    }

    private func measure(_ devices: [VirtualDevice], running: [String] = []) -> Measured {
        var minimum = CGSize.zero
        var ideal = CGSize.zero
        let model = SampleData.model(devices: devices, running: running)
        let host = NSHostingView(
            rootView: SizeProbe(content: MenuBarContent(model: model)) {
                minimum = $0; ideal = $1
            })
        _ = host.fittingSize
        return Measured(minimum: minimum, ideal: ideal)
    }

    private func phones(_ count: Int) -> [VirtualDevice] {
        (0..<count).map { VirtualDevice(id: "Phone_\($0)", kind: .phone) }
    }

    @Test func theMinimumSizeIsTheIdealSizeSoTheListCannotCollapse() {
        for devices in [phones(1), phones(3), SampleData.devices] {
            let measured = measure(devices)
            #expect(measured.minimum == measured.ideal, "\(devices.count) device(s): min \(measured.minimum) vs ideal \(measured.ideal)")
        }
    }

    @Test func theListShowsDevicesInsteadOfJustAHeaderAndAFooter() {
        let height = measure(SampleData.devices).minimum.height

        #expect(height > 350, "popover is \(height) pt tall; a collapsed list is 95")
    }

    @Test func everyDeviceAddsExactlyOneRowUntilTheListScrolls() {
        let one = measure(phones(1)).minimum.height
        let two = measure(phones(2)).minimum.height
        let three = measure(phones(3)).minimum.height

        #expect(two - one == PopoverLayout.rowHeight)
        #expect(three - two == PopoverLayout.rowHeight)
    }

    @Test func aRunningDeviceAddsItsOwnSectionHeader() {
        let idle = measure(phones(2)).minimum.height
        let oneRunning = measure(phones(2), running: ["Phone_0"]).minimum.height

        #expect(oneRunning - idle == PopoverLayout.sectionHeaderHeight)
    }

    @Test func pastTheCapTheListScrollsAndThePopoverStopsGrowing() {
        let capped = measure(phones(40))
        let evenMore = measure(phones(80))

        #expect(capped.minimum.height == evenMore.minimum.height)
        #expect(capped.minimum.height < 700, "the popover must fit a laptop screen")
        #expect(capped.minimum.height - measure(phones(1)).minimum.height > 200)
    }

    @Test func theEmptyAndSetupStatesKeepTheirOwnHeight() {
        let empty = measure([]).minimum.height
        let setup = SampleData.model(devices: [], toolchain: SampleData.missingToolchain)
        var setupHeight = CGFloat.zero
        _ =
            NSHostingView(rootView: SizeProbe(content: MenuBarContent(model: setup)) { minimum, _ in setupHeight = minimum.height })
            .fittingSize

        #expect(empty > 150)
        #expect(setupHeight > 150)
    }
}
