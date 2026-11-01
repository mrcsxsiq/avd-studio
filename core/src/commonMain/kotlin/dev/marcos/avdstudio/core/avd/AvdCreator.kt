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
     * Deletes the device: its `.ini` and its folder. That is all `avdmanager delete avd` does, but avdmanager removes
     * whatever `path=` or `path.rel=` in the `.ini` points at, with no check: a stale or edited `.ini` made it delete an
     * unrelated folder (reproduced with the real tool). Doing it here lets us look first, and needs neither Java nor
     * the command-line tools.
     */
    fun delete(
        name: String,
        avdHome: String,
    ) {
        if (name.isBlank() || name == ".." || name.contains('/') || name.contains('\\')) {
            throw CommandException("\"$name\" is not a device name.")
        }
        val home = avdHome.toPath()
        val ini = home / "$name.ini"
        val directory = resolveDirectory(home, name)
        if (!fileSystem.exists(ini) && !fileSystem.exists(directory)) {
            throw CommandException("No device called $name was found in $avdHome.")
        }
        if (fileSystem.exists(directory)) requireAvdFolder(directory, home, name, ini)
        if (fileSystem.exists(ini)) fileSystem.delete(ini)
        if (fileSystem.exists(directory)) fileSystem.deleteRecursively(directory)
    }

    /**
     * Only ever remove an AVD's own folder. The `.ini` can point anywhere, so a folder is accepted when it is the
     * default location (`<home>/<name>.avd`, even if its `config.ini` is gone) or when it holds a `config.ini` (an AVD
     * kept elsewhere with `avdmanager create avd -p`). The AVD home itself, or a folder above it, never is.
     */
    private fun requireAvdFolder(
        directory: Path,
        home: Path,
        name: String,
        ini: Path,
    ) {
        val containsHome = home == directory || home.toString().startsWith(directory.toString().trimEnd('/') + "/")
        val isDefaultLocation = directory == home / "$name.avd"
        val looksLikeAnAvd = fileSystem.exists(directory / "config.ini")
        if (containsHome || !(isDefaultLocation || looksLikeAnAvd)) {
            throw CommandException(
                "Not deleting $directory: it does not look like an AVD folder (no config.ini). " +
                    "Remove $ini by hand if it is stale.",
            )
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

    /**
     * The folder of device [name], resolved like the device list does: `path` (absolute), then `path.rel` (relative to
     * the parent of the AVD home), then `<home>/<name>.avd`. The first that exists wins; when none does, the default.
     */
    private fun resolveDirectory(
        home: Path,
        name: String,
    ): Path {
        val pointer = runCatching { IniParser.parse(fileSystem.read(home / "$name.ini") { readUtf8() }) }.getOrDefault(emptyMap())
        val default = home / "$name.avd"
        val candidates =
            listOfNotNull(
                pointer["path"]?.takeIf { it.isNotBlank() }?.toPath(normalize = true),
                pointer["path.rel"]?.takeIf { it.isNotBlank() }?.let { ((home.parent ?: home) / it).normalized() },
                default,
            )
        return candidates.firstOrNull { fileSystem.metadataOrNull(it)?.isDirectory == true } ?: default
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
