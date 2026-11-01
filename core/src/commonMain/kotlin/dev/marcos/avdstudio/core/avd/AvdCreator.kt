package dev.marcos.avdstudio.core.avd

import dev.marcos.avdstudio.core.catalog.DeviceProfile
import dev.marcos.avdstudio.core.catalog.SystemImage
import dev.marcos.avdstudio.core.internal.IniParser
import dev.marcos.avdstudio.core.process.Command
import dev.marcos.avdstudio.core.process.CommandException
import dev.marcos.avdstudio.core.process.CommandRunner
import okio.FileSystem
import okio.Path
import okio.Path.Companion.toPath

public data class CreateAvdRequest(
    /** Identifier (`Pixel_9_API_36`); letters, digits, `.`, `_` and `-` only. */
    val name: String,
    /** Shown in the app (`Pixel 9`); defaults to the name with spaces. */
    val displayName: String? = null,
    val systemImage: SystemImage,
    val device: DeviceProfile,
    /** `null` keeps the hardware definition's default. */
    val ramMegabytes: Int? = null,
    /** Internal storage as `sdkmanager` writes it (`16G`); `null` keeps the default (10G). */
    val storage: String? = null,
    /** SD card size (`512M`); `null` for no card. */
    val sdCard: String? = null,
)

public object AvdNames {
    private val VALID = Regex("^[A-Za-z0-9._-]+$")

    /** Returns a message when [name] cannot be used, or null when it can. */
    public fun validate(
        name: String,
        existing: Collection<String>,
    ): String? =
        when {
            name.isBlank() -> "Give the device a name."
            !VALID.matches(name) -> "Use only letters, digits, dots, dashes and underscores (no spaces)."
            existing.any { it.equals(name, ignoreCase = true) } -> "A device called $name already exists."
            else -> null
        }

    /** `Pixel 9` + API 36 → `Pixel_9_API_36`, with `_2`, `_3`… when taken. */
    public fun suggest(
        deviceName: String,
        apiLabel: String?,
        existing: Collection<String>,
    ): String {
        val base =
            listOfNotNull(deviceName, apiLabel?.let { "API_$it" })
                .joinToString("_")
                .replace(Regex("[^A-Za-z0-9._-]+"), "_")
                .replace(Regex("_+"), "_")
                .trim('_')
                .ifEmpty { "Device" }
        if (existing.none { it.equals(base, ignoreCase = true) }) return base
        return generateSequence(2) { it + 1 }.map { "${base}_$it" }.first { candidate ->
            existing.none { it.equals(candidate, ignoreCase = true) }
        }
    }
}

/** Creates and deletes devices through `avdmanager`, then fixes up `config.ini` the way Android Studio does. */
internal class AvdCreator(
    private val fileSystem: FileSystem,
    private val runner: CommandRunner,
) {
    fun create(
        request: CreateAvdRequest,
        avdManager: String,
        sdkPath: String,
        avdHome: String,
        environment: Map<String, String>,
    ): String {
        val arguments =
            buildList {
                addAll(
                    listOf(
                        "create",
                        "avd",
                        "--name",
                        request.name,
                        "--package",
                        request.systemImage.packagePath,
                        "--device",
                        request.device.id,
                    ),
                )
                request.sdCard?.let { addAll(listOf("--sdcard", it)) }
            }
        val result = runner.run(Command(avdManager, arguments, environment))
        failIfErrored(result.exitCode, result.standardOutput + "\n" + result.standardError, "create ${request.name}")

        val avdDirectory = resolveDirectory(avdHome.toPath(), request.name)
        patchConfig(avdDirectory / "config.ini", request, sdkPath)
        return avdDirectory.toString()
    }

    /**
     * Deletes the device. With [avdManager] it asks `avdmanager` first; without it (no Java, no command-line tools)
     * the files are removed directly, which is all `avdmanager delete avd` does anyway.
     */
    fun delete(
        name: String,
        avdManager: String?,
        avdHome: String,
        environment: Map<String, String>,
    ) {
        if (name.isBlank() || name == ".." || name.contains('/') || name.contains('\\')) {
            throw CommandException("\"$name\" is not a device name.")
        }
        val home = avdHome.toPath()
        val ini = home / "$name.ini"
        // Check before anything runs: `avdmanager delete avd` removes whatever `path=` in the .ini points at, so a
        // stale or hand-edited file could make it delete an arbitrary folder.
        if (fileSystem.exists(ini)) requireAvdFolder(resolveDirectory(home, name), ini)
        if (avdManager != null) {
            val result = runner.run(Command(avdManager, listOf("delete", "avd", "--name", name), environment))
            if ((result.exitCode != 0 || hasError(result.standardOutput + result.standardError)) && !fileSystem.exists(ini)) {
                failIfErrored(result.exitCode, result.standardOutput + "\n" + result.standardError, "delete $name")
            }
        } else if (!fileSystem.exists(ini) && !fileSystem.exists(home / "$name.avd")) {
            throw CommandException("No device called $name was found in $avdHome.")
        }
        // avdmanager refuses devices it cannot load (missing system image); remove the files ourselves then.
        if (fileSystem.exists(ini)) {
            val directory = resolveDirectory(home, name)
            requireAvdFolder(directory, ini)
            fileSystem.delete(ini)
            if (fileSystem.exists(directory)) fileSystem.deleteRecursively(directory)
        }
    }

    /** The `path=` in a .ini can point anywhere. Only ever remove what is an AVD folder (`<name>.avd`). */
    private fun requireAvdFolder(
        directory: Path,
        ini: Path,
    ) {
        if (!directory.name.endsWith(".avd")) {
            throw CommandException("Not deleting $directory: it is not an .avd folder. Remove $ini by hand if it is stale.")
        }
    }

    /** `avdmanager` reports many failures as `Error: …` text with exit code 0. */
    private fun failIfErrored(
        exitCode: Int,
        output: String,
        action: String,
    ) {
        if (exitCode == 0 && !hasError(output)) return
        val message =
            output
                .lines()
                .map { it.trim() }
                .filter { it.isNotEmpty() && it != "null" && !it.startsWith("Loading ") }
                .let { lines -> lines.filter { it.contains("Error", ignoreCase = true) }.ifEmpty { lines } }
                .joinToString(" ")
                .removePrefix("Error: ")
        throw CommandException("Could not $action: ${message.ifEmpty { "avdmanager exited with code $exitCode" }}")
    }

    private fun hasError(output: String): Boolean = output.lineSequence().any { it.trimStart().startsWith("Error:") }

    private fun resolveDirectory(
        home: Path,
        name: String,
    ): Path {
        val pointer = runCatching { IniParser.parse(fileSystem.read(home / "$name.ini") { readUtf8() }) }.getOrDefault(emptyMap())
        return pointer["path"]?.toPath()?.takeIf { fileSystem.exists(it) } ?: (home / "$name.avd")
    }

    private fun patchConfig(
        file: Path,
        request: CreateAvdRequest,
        sdkPath: String,
    ) {
        val overrides = linkedMapOf<String, String>()
        overrides["avd.ini.displayname"] = request.displayName?.takeIf { it.isNotBlank() } ?: request.name.replace('_', ' ')
        overrides["PlayStore.enabled"] = if (request.systemImage.hasPlayStore) "true" else "false"
        overrides["hw.gpu.enabled"] = "yes"
        overrides["hw.gpu.mode"] = "auto"
        overrides["hw.keyboard"] = "yes"
        request.ramMegabytes?.let { overrides["hw.ramSize"] = it.toString() }
        request.storage?.let { overrides["disk.dataPartition.size"] = it }
        val skin = sdkPath.toPath() / "skins" / request.device.id
        if (fileSystem.exists(skin / "layout")) {
            overrides["skin.name"] = request.device.id
            overrides["skin.path"] = skin.toString()
            overrides["showDeviceFrame"] = "yes"
        }

        val existing = runCatching { fileSystem.read(file) { readUtf8() } }.getOrDefault("")
        val remaining = overrides.toMutableMap()
        val lines =
            existing.lines().filter { it.isNotEmpty() }.map { line ->
                val key = line.substringBefore('=').trim()
                remaining.remove(key)?.let { "$key=$it" } ?: line
            }
        val output = (lines + remaining.map { (key, value) -> "$key=$value" }).joinToString("\n") + "\n"
        file.parent?.let(fileSystem::createDirectories)
        fileSystem.write(file) { writeUtf8(output) }
    }
}
