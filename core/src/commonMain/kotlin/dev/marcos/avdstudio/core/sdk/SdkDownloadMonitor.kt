package dev.marcos.avdstudio.core.sdk

import okio.FileSystem
import okio.Path
import okio.Path.Companion.toPath

/**
 * How much `sdkmanager` has downloaded so far, read from the disk because it reports no percentage when it does not
 * run in a terminal (and never says how big a package is).
 *
 * sdkmanager 23 writes an archive to `<sdk>/.sdk/arch/<hash>.part`, which grows while it downloads and is renamed to
 * `<hash>` when done. Older versions use `.downloadIntermediates` and `.temp`. Files that existed before the
 * operation started (an archive downloaded earlier and reused) do not count.
 */
internal class SdkDownloadMonitor(
    private val fileSystem: FileSystem,
) {
    /** Bytes of archives written at or after [sinceEpochMillis]; 0 when nothing has been written (yet). */
    fun downloadedBytes(
        sdkPath: String,
        sinceEpochMillis: Long,
    ): Long {
        val root = sdkPath.toPath()
        return FOLDERS.sumOf { folder -> bytes(root / folder, sinceEpochMillis) }
    }

    private fun bytes(
        folder: Path,
        since: Long,
    ): Long {
        val children = runCatching { fileSystem.list(folder) }.getOrDefault(emptyList())
        var total = 0L
        for (child in children) {
            val metadata = fileSystem.metadataOrNull(child) ?: continue
            when {
                metadata.isDirectory -> total += bytes(child, since)
                metadata.isRegularFile && (metadata.lastModifiedAtMillis ?: 0L) >= since -> total += metadata.size ?: 0L
            }
        }
        return total
    }

    private companion object {
        val FOLDERS = listOf(".sdk/arch", ".downloadIntermediates", ".temp")
    }
}
