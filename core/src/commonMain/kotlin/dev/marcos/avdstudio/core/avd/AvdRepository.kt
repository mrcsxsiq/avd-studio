package dev.marcos.avdstudio.core.avd

import dev.marcos.avdstudio.core.internal.IniParser
import dev.marcos.avdstudio.core.internal.naturalOrder
import okio.FileSystem
import okio.Path
import okio.Path.Companion.toPath

/**
 * Reads virtual devices straight from the AVD folder instead of shelling out to `avdmanager`:
 * it is instant, works without Java, and also surfaces devices `avdmanager` refuses to list.
 */
internal class AvdRepository(
    private val fileSystem: FileSystem,
) {
    fun list(
        avdHome: String,
        sdkPath: String?,
    ): List<Avd> {
        val home = avdHome.toPath()
        val entries = runCatching { fileSystem.list(home) }.getOrDefault(emptyList())
        return entries
            .filter { it.name.endsWith(".ini") }
            .map { read(it, home, sdkPath) }
            .sortedWith(compareBy(naturalOrder) { it.name })
    }

    private fun read(
        iniFile: Path,
        home: Path,
        sdkPath: String?,
    ): Avd {
        val name = iniFile.name.removeSuffix(".ini")
        val pointer = readIni(iniFile).orEmpty()
        val avdDirectory = resolveDirectory(pointer, home, name)
        val config = avdDirectory?.let { readIni(it / "config.ini") }

        val tagId = config?.get("tag.id") ?: config?.get("tag.ids")
        val screen = screenOf(config)
        val deviceProfile = config?.get("hw.device.name")
        val systemImageDir = config?.get("image.sysdir.1")

        return Avd(
            name = name,
            displayName = config?.get("avd.ini.displayname")?.takeIf { it.isNotEmpty() } ?: name.replace('_', ' '),
            path = avdDirectory?.toString() ?: pointer["path"] ?: (home / "$name.avd").toString(),
            apiLevel = apiLevelOf(pointer, config, systemImageDir),
            formFactor = FormFactorClassifier.classify(deviceProfile, tagId, screen),
            deviceProfile = deviceProfile,
            manufacturer = config?.get("hw.device.manufacturer"),
            systemImageTag = tagId,
            abi = config?.get("abi.type"),
            hasPlayStore = config?.get("PlayStore.enabled") == "true" || tagId?.contains("playstore") == true,
            ramMegabytes = config?.get("hw.ramSize")?.filter { it.isDigit() }?.toIntOrNull(),
            storage = config?.get("disk.dataPartition.size"),
            screen = screen,
            health = healthOf(config, systemImageDir, sdkPath),
            diskUsageBytes = avdDirectory?.let { diskUsage(it) } ?: 0L,
            systemImage = systemImageDir?.trim('/')?.takeIf { it.isNotEmpty() },
        )
    }

    /** `path` is absolute; `path.rel` is relative to the parent of the AVD home (it survives moved home folders). */
    private fun resolveDirectory(
        pointer: Map<String, String>,
        home: Path,
        name: String,
    ): Path? {
        val candidates =
            listOfNotNull(
                pointer["path"]?.toPath(),
                pointer["path.rel"]?.let { (home.parent ?: home) / it },
                home / "$name.avd",
            )
        return candidates.firstOrNull { fileSystem.metadataOrNull(it)?.isDirectory == true }
    }

    private fun apiLevelOf(
        pointer: Map<String, String>,
        config: Map<String, String>?,
        systemImageDir: String?,
    ): ApiLevel? =
        (config?.get("target") ?: pointer["target"])?.let(ApiLevel::parse)
            ?: systemImageDir?.split('/')?.getOrNull(1)?.let(ApiLevel::parse)

    private fun screenOf(config: Map<String, String>?): ScreenSpec? {
        val width = config?.get("hw.lcd.width")?.toIntOrNull() ?: return null
        val height = config["hw.lcd.height"]?.toIntOrNull() ?: return null
        return ScreenSpec(width, height, config["hw.lcd.density"]?.toIntOrNull() ?: 0)
    }

    private fun healthOf(
        config: Map<String, String>?,
        systemImageDir: String?,
        sdkPath: String?,
    ): AvdHealth =
        when {
            config == null -> AvdHealth.INVALID_CONFIGURATION

            sdkPath != null && systemImageDir != null &&
                !fileSystem.exists(sdkPath.toPath() / systemImageDir) -> AvdHealth.MISSING_SYSTEM_IMAGE

            else -> AvdHealth.READY
        }

    private fun readIni(file: Path): Map<String, String>? =
        runCatching { IniParser.parse(fileSystem.read(file) { readUtf8() }) }.getOrNull()

    private fun diskUsage(directory: Path): Long =
        runCatching {
            fileSystem.listRecursively(directory).sumOf { fileSystem.metadataOrNull(it)?.size ?: 0L }
        }.getOrDefault(0L)
}
