package dev.marcos.avdstudio.cli

import com.github.ajalt.mordant.rendering.TextColors
import com.github.ajalt.mordant.rendering.TextStyles
import dev.marcos.avdstudio.core.avd.Avd
import dev.marcos.avdstudio.core.avd.AvdHealth
import dev.marcos.avdstudio.core.doctor.CheckStatus
import dev.marcos.avdstudio.core.doctor.DoctorCheck
import dev.marcos.avdstudio.core.doctor.DoctorReport
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
)

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
    )

internal object Output {
    val json =
        Json {
            prettyPrint = true
            encodeDefaults = true
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
                check.hint?.let { appendLine("    ${TextColors.gray(it)}") }
            }
            appendLine()
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
