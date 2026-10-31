package com.mrcsxsiq.avdstudio.core.sdk

import com.mrcsxsiq.avdstudio.core.environment.Environment
import com.mrcsxsiq.avdstudio.core.environment.value
import com.mrcsxsiq.avdstudio.core.internal.naturalOrder
import okio.FileSystem
import okio.Path
import okio.Path.Companion.toPath

internal data class SdkCandidate(
    val path: String,
    val source: SdkSource,
)

/** Finds the Android SDK and checks which of the required tools it provides. */
internal class SdkLocator(
    private val fileSystem: FileSystem,
    private val environment: Environment,
) {
    /** Places an SDK may live, in priority order (without the explicit override). */
    fun candidates(): List<SdkCandidate> {
        val homebrewPrefix = environment.value("HOMEBREW_PREFIX") ?: "/opt/homebrew"
        return listOfNotNull(
            environment.value("ANDROID_SDK_ROOT")?.let { SdkCandidate(it, SdkSource.ANDROID_SDK_ROOT) },
            environment.value("ANDROID_HOME")?.let { SdkCandidate(it, SdkSource.ANDROID_HOME) },
            SdkCandidate("${environment.homeDirectory}/Library/Android/sdk", SdkSource.ANDROID_STUDIO_DEFAULT),
            SdkCandidate("$homebrewPrefix/share/android-commandlinetools", SdkSource.HOMEBREW),
        ).distinctBy { it.path }
    }

    /**
     * An explicit path is authoritative: we report on exactly that folder instead of silently
     * falling back to another SDK. Otherwise the first fully configured candidate wins, then
     * the first one that exists at all.
     */
    fun resolve(explicitPath: String?): ToolchainStatus {
        val explicit = explicitPath?.trim()?.takeIf { it.isNotEmpty() }
        if (explicit != null) return inspect(SdkCandidate(explicit, SdkSource.EXPLICIT))

        val inspected = candidates().map { inspect(it) }
        return inspected.firstOrNull { it.isConfigured }
            ?: inspected.firstOrNull { it.sdkDirectoryExists }
            ?: inspected.firstOrNull { it.source == SdkSource.ANDROID_STUDIO_DEFAULT }
            ?: inspect(SdkCandidate("${environment.homeDirectory}/Library/Android/sdk", SdkSource.DEFAULT_LOCATION))
    }

    private fun inspect(candidate: SdkCandidate): ToolchainStatus {
        val root = candidate.path.toPath()
        return ToolchainStatus(
            sdkPath = candidate.path,
            source = candidate.source,
            sdkDirectoryExists = fileSystem.metadataOrNull(root)?.isDirectory == true,
            tools = AndroidTool.entries.map { inspectTool(root, it) },
        )
    }

    private fun inspectTool(
        root: Path,
        tool: AndroidTool,
    ): ToolState {
        val supported = supportedPaths(root, tool)
        supported.firstOrNull { fileSystem.exists(it) }?.let {
            return ToolState(tool, it.toString(), ToolAvailability.AVAILABLE)
        }
        tool.deprecatedLocations.map { root / it }.firstOrNull { fileSystem.exists(it) }?.let {
            return ToolState(tool, it.toString(), ToolAvailability.DEPRECATED)
        }
        return ToolState(tool, supported.first().toString(), ToolAvailability.MISSING)
    }

    /** `latest` first, then any versioned `cmdline-tools/<n>` folder (newest first). */
    private fun supportedPaths(
        root: Path,
        tool: AndroidTool,
    ): List<Path> {
        val fixed = tool.supportedLocations.map { root / it }
        if (tool != AndroidTool.SDK_MANAGER && tool != AndroidTool.AVD_MANAGER) return fixed

        val versioned =
            runCatching { fileSystem.list(root / "cmdline-tools") }
                .getOrDefault(emptyList())
                .filter { it.name != "latest" && fileSystem.metadataOrNull(it)?.isDirectory == true }
                .sortedWith { a, b -> naturalOrder.compare(b.name, a.name) }
                .map { it / "bin" / tool.executableName }
        return fixed + versioned
    }
}
