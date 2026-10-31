package dev.marcos.avdstudio.core.sdk

/** How the SDK path was chosen, so the UI/CLI can explain it. */
public enum class SdkSource {
    /** Chosen explicitly by the user (settings or `--sdk-path`). */
    EXPLICIT,
    ANDROID_SDK_ROOT,
    ANDROID_HOME,
    ANDROID_STUDIO_DEFAULT,
    HOMEBREW,

    /** Nothing was found; this is only where we would expect an SDK to live. */
    DEFAULT_LOCATION,
}

public data class ToolchainStatus(
    val sdkPath: String,
    val source: SdkSource,
    val sdkDirectoryExists: Boolean,
    val tools: List<ToolState>,
) {
    public val isConfigured: Boolean
        get() = sdkDirectoryExists && tools.all { it.isAvailable }

    public val missingTools: List<ToolState>
        get() = tools.filter { it.availability == ToolAvailability.MISSING }

    public val deprecatedTools: List<ToolState>
        get() = tools.filter { it.availability == ToolAvailability.DEPRECATED }

    public fun state(tool: AndroidTool): ToolState = tools.first { it.tool == tool }

    /** Resolved executable path, or null when the tool is not usable. */
    public fun executable(tool: AndroidTool): String? = state(tool).takeIf { it.isAvailable }?.path

    public val summary: String
        get() =
            when {
                isConfigured -> {
                    "Android SDK ready."
                }

                !sdkDirectoryExists -> {
                    "No Android SDK found at $sdkPath."
                }

                deprecatedTools.isNotEmpty() -> {
                    "Deprecated ${deprecatedTools.names()} found under tools/bin. Install the Android command-line tools."
                }

                else -> {
                    "Missing ${missingTools.names()}."
                }
            }

    private fun List<ToolState>.names(): String = joinToString(", ") { it.tool.executableName }
}
