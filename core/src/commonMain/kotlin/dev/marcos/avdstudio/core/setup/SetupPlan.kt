package dev.marcos.avdstudio.core.setup

import dev.marcos.avdstudio.core.process.Command

public enum class SetupStepKind {
    COMMAND_LINE_TOOLS,
    JAVA,
    LICENSES,
    SDK_PACKAGES,
    SYSTEM_IMAGES,
}

public data class SetupStep(
    val kind: SetupStepKind,
    val title: String,
    /** The command as the user would type it. */
    val displayCommand: String,
    val command: Command,
    val requiresHomebrew: Boolean,
    /** The step accepts the Android SDK License Agreement on the user's behalf; they must agree first. */
    val requiresLicenseAcceptance: Boolean,
)

/** Everything needed to turn this Mac into one that can run emulators, in the order it must happen. */
public data class SetupPlan(
    val steps: List<SetupStep>,
    /** Path of the `brew` executable, or null when Homebrew is not installed. */
    val homebrewPath: String?,
    /** The SDK folder the steps install into (may differ from the current one when the tools come from Homebrew). */
    val sdkPath: String,
) {
    public val isEmpty: Boolean
        get() = steps.isEmpty()

    public val needsHomebrew: Boolean
        get() = steps.any { it.requiresHomebrew }

    public val needsLicenseAcceptance: Boolean
        get() = steps.any { it.requiresLicenseAcceptance }

    /** True when the app or CLI can run every step itself, without the user opening a terminal. */
    public val canRunAutomatically: Boolean
        get() = steps.isNotEmpty() && (!needsHomebrew || homebrewPath != null)

    /**
     * The same steps as a shell script, for "open in Terminal" or copy-and-paste. When Homebrew is missing
     * the script starts by installing it (that is interactive, which is exactly what a terminal is for).
     */
    public val shellScript: String
        get() =
            buildString {
                appendLine("#!/bin/bash")
                appendLine("set -euo pipefail")
                if (needsHomebrew && homebrewPath == null) {
                    appendLine()
                    appendLine("# 1. Homebrew (asks for your password)")
                    appendLine(INSTALL_HOMEBREW)
                    appendLine("eval \"$(/opt/homebrew/bin/brew shellenv)\"")
                }
                steps.forEachIndexed { index, step ->
                    appendLine()
                    appendLine("# ${index + if (needsHomebrew && homebrewPath == null) 2 else 1}. ${step.title}")
                    appendLine(step.displayCommand)
                }
                appendLine()
                appendLine("echo; echo 'Done. Open AVD Studio again, or run: avdstudio doctor'")
            }

    public companion object {
        public const val LICENSE_URL: String = "https://developer.android.com/studio/terms"
        public const val HOMEBREW_URL: String = "https://brew.sh"
        public const val COMMAND_LINE_TOOLS_URL: String = "https://developer.android.com/studio#command-line-tools-only"
        public const val INSTALL_HOMEBREW: String =
            "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    }
}
