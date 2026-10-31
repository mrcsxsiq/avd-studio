import AppKit
import Foundation
import Observation

/// Drives the one-click installation: runs the plan's steps in order and keeps their state for the UI.
@MainActor
@Observable
public final class SetupModel {
    public enum StepState: Equatable, Sendable {
        case pending
        case running
        case succeeded
        case failed(output: String)
    }

    public let plan: SetupPlan
    public private(set) var states: [SetupStep.ID: StepState] = [:]
    public private(set) var isRunning = false
    /// True once every step succeeded.
    public private(set) var isFinished = false
    public var acceptedLicense = false

    @ObservationIgnored private let service: any DeviceService
    @ObservationIgnored private let locations: Locations
    @ObservationIgnored private let opener: any FileOpening
    @ObservationIgnored private let scriptsDirectory: URL

    public init(
        plan: SetupPlan,
        service: any DeviceService,
        locations: Locations,
        opener: any FileOpening = WorkspaceFileOpener(),
        scriptsDirectory: URL = FileManager.default.temporaryDirectory
    ) {
        self.plan = plan
        self.service = service
        self.locations = locations
        self.opener = opener
        self.scriptsDirectory = scriptsDirectory
        for step in plan.steps { states[step.id] = .pending }
    }

    public func state(of step: SetupStep) -> StepState { states[step.id] ?? .pending }

    /// The license must be accepted by the user, never by the app.
    public var canStart: Bool {
        plan.canRunAutomatically && !isRunning && !isFinished && (!plan.needsLicenseAcceptance || acceptedLicense)
    }

    public var failedStep: SetupStep? {
        plan.steps.first { if case .failed = state(of: $0) { true } else { false } }
    }

    /// Runs every step in order and stops at the first failure. Safe to call again to retry.
    public func run() async {
        guard canStart || failedStep != nil, !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        for step in plan.steps where state(of: step) != .succeeded {
            states[step.id] = .running
            do {
                let result = try await service.runSetupStep(step, locations: locations)
                guard result.isSuccess else {
                    states[step.id] = .failed(output: Self.tail(of: result.output, exitCode: result.exitCode))
                    return
                }
                states[step.id] = .succeeded
            } catch {
                states[step.id] = .failed(output: error.localizedDescription)
                return
            }
        }
        isFinished = true
    }

    /// Writes the script as a `.command` file and opens it, which runs it in Terminal (where Homebrew's own
    /// installer can ask for the password). Returns the file so tests can inspect it.
    @discardableResult
    public func openInTerminal() -> URL? {
        let file = scriptsDirectory.appendingPathComponent("Set up Android for AVD Studio.command")
        do {
            try plan.shellScript.write(to: file, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        } catch {
            return nil
        }
        opener.open(file)
        return file
    }

    public func copyScript() { Clipboard.copy(plan.shellScript) }

    private static func tail(of output: String, exitCode: Int32, lines: Int = 25) -> String {
        let kept = output.split(separator: "\n", omittingEmptySubsequences: false).suffix(lines).joined(separator: "\n")
        let trimmed = kept.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "The command failed with exit code \(exitCode)." : trimmed
    }
}
