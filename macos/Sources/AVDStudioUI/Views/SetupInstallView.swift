import SwiftUI

/// The sheet behind "Install automatically": the steps, the license checkbox, progress and the fallback
/// routes (Terminal script, Homebrew, manual download) when the app cannot do it by itself.
public struct SetupInstallView: View {
    @Bindable var model: SetupModel
    let onFinished: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    public init(model: SetupModel, onFinished: @escaping () -> Void) {
        self.model = model
        self.onFinished = onFinished
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(24)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !model.plan.canRunAutomatically { needsTerminal }
                    stepList
                    if model.plan.needsLicenseAcceptance && model.plan.canRunAutomatically && !model.isFinished { license }
                    if model.isFinished { done }
                }
                .padding(24)
            }
            Divider()
            footer.padding(.horizontal, 20).padding(.vertical, 14)
        }
        .frame(width: 560, height: 560)
        .animation(.default, value: model.states)
        .animation(.default, value: model.isFinished)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(
                    LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Set up Android on this Mac").font(.title2.weight(.bold))
                Text(subtitle).foregroundStyle(.secondary)
            }
        }
    }

    private var subtitle: String {
        if model.plan.canRunAutomatically {
            return "AVD Studio installs everything below for you. It takes a few minutes and about 1 GB of downloads."
        }
        return "Homebrew isn't installed, so AVD Studio can't do this by itself yet."
    }

    private var needsTerminal: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Run the script in Terminal", systemImage: "terminal.fill").font(.headline)
            Text(
                "It installs Homebrew first (that step asks for your password), then everything below. Or install Homebrew yourself and come back to let AVD Studio finish."
            )
            .foregroundStyle(.secondary)
            HStack {
                Button("Open in Terminal", systemImage: "terminal") { model.openInTerminal() }.buttonStyle(.borderedProminent)
                Button("Copy Script", systemImage: "doc.on.doc") { model.copyScript() }
                Button("About Homebrew") { openURL(SetupPlan.homebrewURL) }.buttonStyle(.link)
            }
            Text("Prefer not to use Homebrew? Download the command-line tools from Google and choose that folder in Settings.")
                .font(.callout).foregroundStyle(.secondary)
            Button("Download command-line tools…") { openURL(SetupPlan.commandLineToolsURL) }.buttonStyle(.link)
        }
        .padding(14)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var stepList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(model.plan.steps.enumerated()), id: \.element.id) { index, step in
                SetupStepRow(index: index + 1, step: step, state: model.state(of: step))
                if step.id != model.plan.steps.last?.id { Divider().padding(.leading, 44) }
            }
        }
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var license: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $model.acceptedLicense) {
                Text("I have read and accept the Android SDK License Agreement")
            }
            .toggleStyle(.checkbox)
            Button("Read the agreement") { openURL(SetupPlan.licenseURL) }.buttonStyle(.link).padding(.leading, 20)
        }
    }

    private var done: some View {
        Label("All set. Your Android SDK is ready.", systemImage: "checkmark.seal.fill")
            .font(.headline)
            .foregroundStyle(.green)
    }

    @ViewBuilder
    private var footer: some View {
        HStack {
            if model.plan.canRunAutomatically, let failed = model.failedStep {
                Text("“\(failed.title)” failed. Fix the problem shown above and try again.").font(.callout).foregroundStyle(.red)
            }
            Spacer()
            if model.isFinished {
                Button("Done") {
                    onFinished()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            } else {
                Button(model.isRunning ? "Installing…" : "Cancel") { dismiss() }.disabled(model.isRunning)
                if model.plan.canRunAutomatically {
                    Button(model.failedStep == nil ? "Install" : "Try Again") { Task { await model.run() } }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .disabled(!(model.canStart || (model.failedStep != nil && !model.isRunning)))
                }
            }
        }
    }
}

struct SetupStepRow: View {
    let index: Int
    let step: SetupStep
    let state: SetupModel.StepState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                status.frame(width: 20)
                VStack(alignment: .leading, spacing: 3) {
                    Text(step.title).font(.body.weight(.medium))
                    Text(step.displayCommand)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
            }
            if case .failed(let output) = state {
                Text(output)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    .padding(.leading, 32)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(index), \(step.title), \(accessibilityState)")
    }

    @ViewBuilder
    private var status: some View {
        switch state {
        case .pending:
            Text("\(index)").font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(width: 20, height: 20).background(
                .quaternary, in: Circle())
        case .running: ProgressView().controlSize(.small)
        case .succeeded: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }

    private var accessibilityState: String {
        switch state {
        case .pending: "not started"
        case .running: "in progress"
        case .succeeded: "done"
        case .failed: "failed"
        }
    }
}
