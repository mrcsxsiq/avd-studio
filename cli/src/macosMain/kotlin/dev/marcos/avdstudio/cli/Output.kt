package dev.marcos.avdstudio.cli

import com.github.ajalt.mordant.rendering.TextColors
import com.github.ajalt.mordant.rendering.TextStyles
import dev.marcos.avdstudio.core.avd.Avd
import dev.marcos.avdstudio.core.avd.AvdHealth
import dev.marcos.avdstudio.core.catalog.AvailableSystemImage
import dev.marcos.avdstudio.core.catalog.DeviceProfile
import dev.marcos.avdstudio.core.catalog.SystemImage
import dev.marcos.avdstudio.core.doctor.CheckStatus
import dev.marcos.avdstudio.core.doctor.DoctorCheck
import dev.marcos.avdstudio.core.doctor.DoctorReport
import dev.marcos.avdstudio.core.process.CommandResult
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

internal fun AvdHealth.explanation(): String =
    when (this) {
        AvdHealth.READY -> "ready"
        AvdHealth.MISSING_SYSTEM_IMAGE -> "its system image is not installed"
        AvdHealth.INVALID_CONFIGURATION -> "its configuration is missing or unreadable"
    }

private fun AvdHealth.slug(): String =
    when (this) {
        AvdHealth.READY -> "ready"
        AvdHealth.MISSING_SYSTEM_IMAGE -> "missing-system-image"
        AvdHealth.INVALID_CONFIGURATION -> "invalid-configuration"
    }

@Serializable
internal data class AvdDto(
    val name: String,
    val displayName: String,
    val path: String,
    val type: String,
    val api: String?,
    val androidVersion: String?,
    val device: String?,
    val abi: String?,
    val playStore: Boolean,
    val ramMegabytes: Int?,
    val storage: String?,
    val status: String,
    val diskUsageBytes: Long,
)

@Serializable
internal data class CheckDto(
    val id: String,
    val status: String,
    val title: String,
    val detail: String,
    val hint: String?,
)

@Serializable
internal data class DoctorDto(
    val healthy: Boolean,
    val checks: List<CheckDto>,
    val nextSteps: List<String>,
)

@Serializable
internal data class ImageDto(
    @SerialName("package") val packagePath: String,
    val api: String?,
    val androidVersion: String?,
    val version: String,
    val tag: String,
    val abi: String,
    val playStore: Boolean,
    val native: Boolean,
    val family: String,
    /** Disk space the image takes, in bytes; null when it could not be measured. */
    val sizeBytes: Long?,
)

@Serializable
internal data class AvailableImageDto(
    @SerialName("package") val packagePath: String,
    val api: String?,
    val androidVersion: String?,
    /** Preview name (`canary-20261007`, `Baklava`) when there is no API level. */
    val codeName: String?,
    val extensionLevel: Int?,
    /** `beta 1` for pre-release platforms such as `android-37.2-beta1`. */
    val prerelease: String?,
    val version: String,
    /** The tag as it appears in the package path (`google_apis_playstore_ps16k`). */
    val tagId: String,
    /** The same tag, as a label (`Google Play (16 KB pages)`). */
    val tag: String,
    val abi: String,
    val revision: String,
    val description: String,
    val installed: Boolean,
    val playStore: Boolean,
    val native: Boolean,
    val family: String,
    val preview: Boolean,
    val sixteenKbPages: Boolean,
    val automatedTest: Boolean,
)

@Serializable
internal data class ProfileDto(
    val id: String,
    val name: String,
    val type: String,
    val manufacturer: String,
)

internal fun SystemImage.toDto() =
    ImageDto(
        packagePath = packagePath,
        api = apiLevel?.label,
        androidVersion = apiLevel?.androidVersion,
        version = versionLabel,
        tag = tagDisplay,
        abi = abi,
        playStore = hasPlayStore,
        native = isNativeOnAppleSilicon,
        family = family.name.lowercase(),
        sizeBytes = sizeBytes,
    )

internal fun AvailableSystemImage.toDto() =
    AvailableImageDto(
        packagePath = packagePath,
        api = apiLevel?.label,
        androidVersion = apiLevel?.androidVersion,
        codeName = codeName,
        extensionLevel = extensionLevel,
        prerelease = prerelease,
        version = versionLabel,
        tagId = tag,
        tag = tagDisplay,
        abi = abi,
        revision = revision,
        description = description,
        installed = isInstalled,
        playStore = hasPlayStore,
        native = isNativeOnAppleSilicon,
        family = family.name.lowercase(),
        preview = isPreview,
        sixteenKbPages = usesSixteenKbPages,
        automatedTest = isAutomatedTestImage,
    )

internal fun DeviceProfile.toDto() = ProfileDto(id = id, name = name, type = formFactor.displayName, manufacturer = manufacturer)

internal fun Avd.toDto() =
    AvdDto(
        name = name,
        displayName = displayName,
        path = path,
        type = formFactor.displayName,
        api = apiLevel?.label,
        androidVersion = apiLevel?.androidVersion,
        device = deviceProfile,
        abi = abi,
        playStore = hasPlayStore,
        ramMegabytes = ramMegabytes,
        storage = storage,
        status = health.slug(),
        diskUsageBytes = diskUsageBytes,
    )

internal fun DoctorReport.toDto() =
    DoctorDto(
        healthy = isHealthy,
        checks = checks.map { CheckDto(it.id, it.status.name.lowercase(), it.title, it.detail, it.hint) },
        nextSteps = nextSteps,
    )

internal object Output {
    fun heading(text: String): String = TextStyles.bold(text)

    fun dim(text: String): String = TextColors.gray(text)

    fun success(text: String): String = TextColors.green(text)

    fun failure(text: String): String = TextColors.red(text)

    val json =
        Json {
            prettyPrint = true
            encodeDefaults = true
        }

    fun imageTable(images: List<SystemImage>): String =
        table(
            listOf("ANDROID", "TAG", "ABI", "SIZE", "PACKAGE"),
            images.map {
                listOf(
                    it.versionLabel,
                    it.tagDisplay,
                    it.abi + if (it.isNativeOnAppleSilicon) "" else " (slow)",
                    it.sizeBytes?.let(::formatBytes) ?: "-",
                    it.packagePath,
                )
            },
        )

    /** Previews say "(preview)" in the first column and test devices say so in the second, so neither passes for a release. */
    fun availableImageTable(images: List<AvailableSystemImage>): String =
        table(
            listOf("ANDROID", "FLAVOR", "ABI", "REVISION", "STATUS", "PACKAGE"),
            images.map {
                listOf(
                    it.qualifiedVersionLabel,
                    it.tagDisplay,
                    it.abi + if (it.isNativeOnAppleSilicon) "" else " (slow)",
                    it.revision,
                    if (it.isInstalled) "installed" else "",
                    it.packagePath,
                )
            },
        )

    /** The last lines of what sdkmanager printed, minus its deprecation banner and progress bars. */
    fun sdkManagerTail(result: CommandResult): List<String> =
        (result.standardError + "\n" + result.standardOutput)
            .split('\n', '\r')
            .map { it.trim() }
            .filter { it.isNotEmpty() && !it.startsWith("[") && !SDKMANAGER_BANNER.containsMatchIn(it) }
            .takeLast(15)

    fun profileTable(profiles: List<DeviceProfile>): String =
        table(listOf("ID", "NAME", "TYPE", "OEM"), profiles.map { listOf(it.id, it.name, it.formFactor.displayName, it.manufacturer) })

    private fun table(
        header: List<String>,
        rows: List<List<String>>,
    ): String {
        val widths = header.indices.map { column -> (rows + listOf(header)).maxOf { it[column].length } }

        fun line(cells: List<String>) = cells.indices.joinToString("  ") { cells[it].padEnd(widths[it]) }.trimEnd()
        return (listOf(TextStyles.bold(line(header))) + rows.map(::line)).joinToString("\n")
    }

    fun avdTable(avds: List<Avd>): String {
        val header = listOf("NAME", "TYPE", "ANDROID", "DEVICE", "SIZE", "STATUS")
        val rows =
            avds.map {
                listOf(
                    it.name,
                    it.formFactor.displayName,
                    it.apiLevel?.androidVersion?.let { v -> "Android $v" } ?: it.apiLevel?.let { a -> "API ${a.label}" } ?: "-",
                    it.deviceProfile ?: "-",
                    formatBytes(it.diskUsageBytes),
                    it.health.statusLabel(),
                )
            }
        val widths = header.indices.map { column -> (rows + listOf(header)).maxOf { it[column].length } }

        fun line(
            cells: List<String>,
            styleStatus: (String) -> String = { it },
        ) = cells.indices.joinToString("  ") { i ->
            val text = cells[i].padEnd(widths[i])
            if (i == cells.lastIndex) styleStatus(cells[i]) else text
        }

        return buildString {
            appendLine(TextStyles.bold(line(header)))
            avds.indices.forEach { i ->
                appendLine(line(rows[i]) { styleHealth(avds[i].health, it) })
            }
        }.trimEnd()
    }

    fun doctor(report: DoctorReport): String =
        buildString {
            report.checks.forEach { check ->
                appendLine("${symbol(check)} ${TextStyles.bold(check.title)}  ${check.detail}")
            }
            appendLine()
            if (report.nextSteps.isNotEmpty()) {
                appendLine(TextStyles.bold("Next steps"))
                report.nextSteps.forEachIndexed { index, step -> appendLine("  ${index + 1}. $step") }
                appendLine()
                appendLine(TextColors.gray("Then run `avdstudio doctor` again to check."))
                appendLine()
            }
            append(
                when {
                    !report.isHealthy -> TextColors.red("Not ready: fix the items marked ✗ above.")
                    report.hasWarnings -> TextColors.yellow("Ready, with warnings.")
                    else -> TextColors.green("Everything looks good.")
                },
            )
        }

    private fun symbol(check: DoctorCheck): String =
        when (check.status) {
            CheckStatus.PASS -> TextColors.green("✓")
            CheckStatus.WARNING -> TextColors.yellow("!")
            CheckStatus.FAIL -> TextColors.red("✗")
        }

    private fun AvdHealth.statusLabel(): String =
        when (this) {
            AvdHealth.READY -> "ready"
            AvdHealth.MISSING_SYSTEM_IMAGE -> "needs system image"
            AvdHealth.INVALID_CONFIGURATION -> "invalid config"
        }

    private fun styleHealth(
        health: AvdHealth,
        text: String,
    ): String =
        when (health) {
            AvdHealth.READY -> TextColors.green(text)
            AvdHealth.MISSING_SYSTEM_IMAGE -> TextColors.yellow(text)
            AvdHealth.INVALID_CONFIGURATION -> TextColors.red(text)
        }

    private val SDKMANAGER_BANNER = Regex("sdkmanager\\) is deprecated|The 'android' binary|documentation \\(https://d.android.com")

    /** Decimal units, matching what Finder shows. */
    fun formatBytes(bytes: Long): String {
        if (bytes < 1_000) return "$bytes B"
        val units = listOf("KB", "MB", "GB", "TB")
        var value = bytes.toDouble()
        var unit = -1
        while (value >= 1_000 && unit < units.lastIndex) {
            value /= 1_000
            unit++
        }
        val rounded = (value * 10).toLong() / 10.0
        return "$rounded ${units[unit]}"
    }
}
