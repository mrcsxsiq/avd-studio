package dev.marcos.avdstudio.core.emulator

import dev.marcos.avdstudio.core.process.Command

public data class RunningEmulator(
    /** The AVD the emulator was started with (`emulator -avd <name>`). */
    val avdName: String,
    val processId: Int,
)

/**
 * Finds running emulators from the process list. This needs neither `adb` nor Java, and it also
 * sees emulators that were started from Android Studio or a terminal.
 */
internal object RunningEmulators {
    val listProcesses = Command("/bin/ps", listOf("-axo", "pid=,command="))

    /** Parses `ps -axo pid=,command=` output, keeping only the `qemu-system-*` process of each emulator. */
    fun parse(psOutput: String): List<RunningEmulator> =
        psOutput
            .lineSequence()
            .mapNotNull(::parseLine)
            .distinctBy { it.avdName }
            .toList()

    private fun parseLine(line: String): RunningEmulator? {
        val trimmed = line.trim()
        val split = trimmed.indexOf(' ')
        if (split <= 0) return null
        val pid = trimmed.substring(0, split).toIntOrNull() ?: return null
        val arguments = trimmed.substring(split + 1).trim().split(Regex("\\s+"))
        if (arguments.firstOrNull()?.substringAfterLast('/')?.startsWith("qemu-system") != true) return null
        val name = arguments.getOrNull(arguments.indexOf("-avd") + 1)?.takeIf { "-avd" in arguments } ?: return null
        return RunningEmulator(name, pid)
    }
}
