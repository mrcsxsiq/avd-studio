package dev.marcos.avdstudio.core.catalog

import dev.marcos.avdstudio.core.avd.FormFactor
import dev.marcos.avdstudio.core.avd.FormFactorClassifier

/** A hardware definition known to `avdmanager` (`pixel_9`, `tv_4k`, `wearos_large_round`, …). */
public data class DeviceProfile(
    /** What `avdmanager create avd --device` expects. May contain spaces (`Nexus 7 2013`). */
    val id: String,
    val name: String,
    val manufacturer: String,
    /** Tag from the definition (`android-tv`), when it has one. */
    val tag: String?,
    val formFactor: FormFactor,
)

/** Parses `avdmanager list device` and picks sensible defaults. */
public object DeviceProfileCatalog {
    private val ID = Regex("""^id:\s*\d+\s+or\s+"([^"]+)"""")
    private val FIELD = Regex("""^\s*(Name|OEM|Tag)\s*:\s*(.*)$""")

    /** Preferred definition per device type, when it exists on this SDK. */
    private val RECOMMENDED =
        mapOf(
            FormFactor.PHONE to listOf("pixel_9", "pixel_8", "medium_phone"),
            FormFactor.FOLDABLE to listOf("pixel_9_pro_fold", "pixel_fold"),
            FormFactor.TABLET to listOf("pixel_tablet", "medium_tablet"),
            FormFactor.WEAR_OS to listOf("wearos_large_round", "wearos_square"),
            FormFactor.TV to listOf("tv_1080p", "tv_4k"),
            FormFactor.AUTOMOTIVE to listOf("automotive_1080p_landscape", "automotive_1024p_landscape"),
            FormFactor.DESKTOP to listOf("desktop_medium", "desktop_large"),
            FormFactor.XR to listOf("xr_headset_device", "xr_glasses_device"),
        )

    public fun parse(output: String): List<DeviceProfile> {
        val profiles = mutableListOf<DeviceProfile>()
        var id: String? = null
        var name: String? = null
        var oem: String? = null
        var tag: String? = null

        fun flush() {
            val currentId = id ?: return
            profiles += profile(currentId, name ?: currentId, oem ?: "Unknown", tag)
            id = null
            name = null
            oem = null
            tag = null
        }

        for (line in output.lineSequence()) {
            ID.find(line.trim())?.let {
                flush()
                id = it.groupValues[1]
                return@let
            }
            if (line.trim().startsWith("---")) {
                flush()
                continue
            }
            FIELD.find(line)?.let { match ->
                val value = match.groupValues[2].trim()
                when (match.groupValues[1]) {
                    "Name" -> name = value
                    "OEM" -> oem = value
                    "Tag" -> tag = value.takeIf { it.isNotEmpty() }
                }
            }
        }
        flush()
        return profiles
    }

    public fun recommended(
        profiles: List<DeviceProfile>,
        formFactor: FormFactor,
    ): DeviceProfile? {
        val candidates = profiles.filter { it.formFactor == formFactor }
        return RECOMMENDED[formFactor].orEmpty().firstNotNullOfOrNull { wanted -> candidates.firstOrNull { it.id == wanted } }
            ?: candidates.firstOrNull()
    }

    private fun profile(
        id: String,
        name: String,
        oem: String,
        tag: String?,
    ): DeviceProfile {
        val byId = FormFactorClassifier.classify(id, tag, null)
        // Generic definitions ("7in WSVGA (Tablet)", "Nexus 7 2013") only say what they are in their name.
        val formFactor = if (byId == FormFactor.PHONE) FormFactorClassifier.classify(name, tag, null) else byId
        return DeviceProfile(id = id, name = name, manufacturer = oem, tag = tag, formFactor = formFactor)
    }
}
