import SwiftUI

struct DeviceGridView: View {
    @Bindable var model: AppModel

    private let columns = [GridItem(.adaptive(minimum: 250, maximum: 340), spacing: 18)]

    var body: some View {
        let devices = model.visibleDevices
        Group {
            if devices.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(devices) { device in
                            DeviceCard(
                                device: device,
                                runState: model.runState(of: device),
                                isSelected: model.selection == device.id,
                                onTogglePower: { Task { await model.togglePower(device) } }
                            )
                            .onTapGesture(count: 2) { Task { await model.togglePower(device) } }
                            .onTapGesture { model.selection = device.id }
                            .contextMenu { DeviceActions(model: model, device: device) }
                        }
                    }
                    .padding(24)
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !model.searchText.isEmpty {
            ContentUnavailableView.search(text: model.searchText)
        } else if model.devices.isEmpty {
            ContentUnavailableView(
                "No Virtual Devices",
                systemImage: "iphone.slash",
                description: Text(
                    "No devices were found in \(model.avdHome).\nChoose another folder in Settings, or create a device in Android Studio.")
            )
        } else {
            ContentUnavailableView(
                "No \(model.currentTitle)",
                systemImage: "tray",
                description: Text("None of your devices is in this category.")
            )
        }
    }
}
