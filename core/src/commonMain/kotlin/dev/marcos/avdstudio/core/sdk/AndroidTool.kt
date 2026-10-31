package dev.marcos.avdstudio.core.sdk

public enum class AndroidTool(
    public val executableName: String,
) {
    SDK_MANAGER("sdkmanager"),
    AVD_MANAGER("avdmanager"),
    EMULATOR("emulator"),
    ADB("adb"),
    ;

    /** Where the tool lives inside an SDK root, most preferred first. */
    internal val supportedLocations: List<String>
        get() =
            when (this) {
                SDK_MANAGER, AVD_MANAGER -> listOf("cmdline-tools/latest/bin/$executableName")
                EMULATOR -> listOf("emulator/$executableName")
                ADB -> listOf("platform-tools/$executableName")
            }

    /** Locations kept only so we can tell users they are outdated. */
    internal val deprecatedLocations: List<String>
        get() =
            when (this) {
                SDK_MANAGER, AVD_MANAGER -> listOf("tools/bin/$executableName")
                EMULATOR, ADB -> emptyList()
            }

    /** The SDK package that provides the tool (for `sdkmanager` install hints). */
    public val sdkPackage: String
        get() =
            when (this) {
                SDK_MANAGER, AVD_MANAGER -> "cmdline-tools;latest"
                EMULATOR -> "emulator"
                ADB -> "platform-tools"
            }
}

public enum class ToolAvailability {
    AVAILABLE,
    MISSING,

    /** Found only in the legacy `tools/bin` location, which current SDKs no longer support. */
    DEPRECATED,
}

public data class ToolState(
    val tool: AndroidTool,
    /** The resolved executable, or where it was expected when it is missing. */
    val path: String,
    val availability: ToolAvailability,
) {
    public val isAvailable: Boolean
        get() = availability == ToolAvailability.AVAILABLE
}
