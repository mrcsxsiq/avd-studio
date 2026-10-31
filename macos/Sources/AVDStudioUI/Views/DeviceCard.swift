import SwiftUI

/// One virtual device: a gradient tile in its kind's colour family with the essentials and a power button.
struct DeviceCard: View {
    let device: VirtualDevice
    let runState: RunState
    var isSelected = false
    var onTogglePower: () -> Void = {}

    private var palette: DevicePalette { DevicePalette(kind: device.kind, seed: device.id) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(palette.gradient)

            Image(systemName: device.kind.symbolName)
                .font(.system(size: 110, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.2))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 14)
                .padding(.trailing, 6)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    KindBadge(kind: device.kind)
                    Spacer(minLength: 8)
                    StatusPill(status: device.status, runState: runState)
                }
                Spacer(minLength: 12)
                Text(device.displayName)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(device.releaseLabel)
                    .font(.subheadline)
                    .opacity(0.88)
                    .padding(.top, 1)
                HStack(alignment: .bottom, spacing: 6) {
                    ChipRow(device: device)
                    Spacer(minLength: 8)
                    PowerButton(device: device, runState: runState, action: onTogglePower)
                }
                .padding(.top, 10)
            }
            .padding(16)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
        }
        .frame(height: 176)
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .padding(-2)
            }
        }
        .shadow(color: palette.bottom.opacity(0.35), radius: 10, y: 5)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(device.displayName), \(device.kind.title), \(device.releaseLabel), \(accessibilityState)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var accessibilityState: String {
        switch runState {
        case .running: "running"
        case .starting: "starting"
        case .idle: device.status.title.lowercased()
        }
    }
}

struct KindBadge: View {
    let kind: DeviceKind

    var body: some View {
        Label(kind.title, systemImage: kind.symbolName)
            .font(.caption.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(.black.opacity(0.22), in: Capsule())
    }
}

struct StatusPill: View {
    let status: VirtualDevice.Status
    let runState: RunState

    var body: some View {
        switch (runState, status) {
        case (.running, _):
            pill("Running", color: .green)
        case (.starting, _):
            pill("Starting…", color: .yellow)
        case (.idle, .ready):
            EmptyView()
        case (.idle, _):
            Label("Needs image", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(.orange.opacity(0.9), in: Capsule())
        }
    }

    private func pill(_ title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(.black.opacity(0.28), in: Capsule())
    }
}

private struct ChipRow: View {
    let device: VirtualDevice

    var body: some View {
        HStack(spacing: 5) {
            if let apiLevel = device.apiLevel { chip("API \(apiLevel)") }
            if device.hasPlayStore { chip("Play", symbol: "play.square.fill") }
            if let ram = device.ramLabel { chip(ram) }
        }
        .lineLimit(1)
    }

    private func chip(_ text: String, symbol: String? = nil) -> some View {
        HStack(spacing: 3) {
            if let symbol { Image(systemName: symbol) }
            Text(text)
        }
        .font(.caption2.weight(.medium))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(.white.opacity(0.2), in: Capsule())
    }
}

struct PowerButton: View {
    let device: VirtualDevice
    let runState: RunState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(.white.opacity(0.9))
                switch runState {
                case .starting:
                    ProgressView().controlSize(.small).tint(.black)
                case .running:
                    Image(systemName: "stop.fill").foregroundStyle(.red)
                case .idle:
                    Image(systemName: "play.fill").foregroundStyle(.black.opacity(0.85)).offset(x: 1)
                }
            }
            .font(.system(size: 14, weight: .bold))
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
        .opacity(device.isLaunchable || runState == .running ? 1 : 0.45)
        .disabled(runState == .starting || (!device.isLaunchable && runState == .idle))
        .help(helpText)
        .accessibilityLabel(runState == .running ? "Stop \(device.displayName)" : "Start \(device.displayName)")
    }

    private var helpText: String {
        switch runState {
        case .running: "Stop \(device.displayName)"
        case .starting: "Starting…"
        case .idle: device.isLaunchable ? "Start \(device.displayName)" : device.status.title
        }
    }
}
