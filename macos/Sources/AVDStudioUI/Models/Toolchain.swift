import Foundation

public struct ToolchainSummary: Equatable, Sendable {
    public struct Tool: Equatable, Identifiable, Sendable {
        public enum State: Equatable, Sendable { case available, missing, deprecated }

        public let name: String
        public let path: String
        public let state: State
        public var id: String { name }

        public init(name: String, path: String, state: State) {
            self.name = name
            self.path = path
            self.state = state
        }
    }

    public let sdkPath: String
    /// Why this folder was chosen, e.g. "from ANDROID_HOME".
    public let sourceDescription: String
    public let directoryExists: Bool
    public let isConfigured: Bool
    public let summary: String
    public let tools: [Tool]

    public init(
        sdkPath: String,
        sourceDescription: String,
        directoryExists: Bool,
        isConfigured: Bool,
        summary: String,
        tools: [Tool]
    ) {
        self.sdkPath = sdkPath
        self.sourceDescription = sourceDescription
        self.directoryExists = directoryExists
        self.isConfigured = isConfigured
        self.summary = summary
        self.tools = tools
    }
}

public struct DoctorItem: Identifiable, Equatable, Sendable {
    public enum Status: Equatable, Sendable { case pass, warning, fail }

    public let id: String
    public let title: String
    public let status: Status
    public let detail: String
    public let hint: String?

    public init(id: String, title: String, status: Status, detail: String, hint: String? = nil) {
        self.id = id
        self.title = title
        self.status = status
        self.detail = detail
        self.hint = hint
    }
}
