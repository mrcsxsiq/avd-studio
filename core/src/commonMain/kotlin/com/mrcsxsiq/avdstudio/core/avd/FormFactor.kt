package com.mrcsxsiq.avdstudio.core.avd

public enum class FormFactor(
    public val displayName: String,
) {
    PHONE("Phone"),
    FOLDABLE("Foldable"),
    TABLET("Tablet"),
    WEAR_OS("Wear OS"),
    DESKTOP("Desktop"),
    TV("TV"),
    AUTOMOTIVE("Automotive"),
    XR("XR"),
    UNKNOWN("Unknown"),
}

/** Decides which kind of device an AVD is from the hints stored in its `config.ini`. */
internal object FormFactorClassifier {
    private const val TABLET_MIN_DP = 600

    fun classify(
        deviceProfile: String?,
        tagId: String?,
        screen: ScreenSpec?,
    ): FormFactor {
        val device = deviceProfile?.lowercase().orEmpty()
        val tag = tagId?.lowercase().orEmpty()

        return when {
            tag.contains("wear") || device.startsWith("wear") -> FormFactor.WEAR_OS
            tag.contains("tv") || device.startsWith("tv") -> FormFactor.TV
            tag.contains("automotive") || device.startsWith("automotive") -> FormFactor.AUTOMOTIVE
            tag.contains("desktop") || device.startsWith("desktop") -> FormFactor.DESKTOP
            tag.contains("xr") || device.startsWith("xr") -> FormFactor.XR
            device.contains("fold") || device.contains("flip") -> FormFactor.FOLDABLE
            device.contains("tablet") || device in KNOWN_TABLETS -> FormFactor.TABLET
            screen != null && screen.smallestWidthDp >= TABLET_MIN_DP -> FormFactor.TABLET
            device.isNotEmpty() || screen != null || tag.isNotEmpty() -> FormFactor.PHONE
            else -> FormFactor.UNKNOWN
        }
    }

    private val KNOWN_TABLETS = setOf("pixel_c", "nexus_7", "nexus_7_2013", "nexus_9", "nexus_10")
}
