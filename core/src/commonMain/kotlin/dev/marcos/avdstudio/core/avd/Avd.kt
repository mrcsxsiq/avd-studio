package dev.marcos.avdstudio.core.avd

public enum class AvdHealth {
    READY,

    /** The AVD points at a system image that is not installed in the SDK. */
    MISSING_SYSTEM_IMAGE,

    /** The AVD folder or its `config.ini` could not be found or read. */
    INVALID_CONFIGURATION,
}

public data class ScreenSpec(
    val widthPixels: Int,
    val heightPixels: Int,
    val density: Int,
) {
    /** Smallest screen width in dp, the number Android uses to tell phones from tablets. */
    public val smallestWidthDp: Int
        get() = if (density > 0) minOf(widthPixels, heightPixels) * 160 / density else 0
}

public data class Avd(
    /** Identifier used with `emulator -avd` and `avdmanager` (the `.ini` file name). */
    val name: String,
    /** Human-friendly name (`Medium Phone`). */
    val displayName: String,
    /** The `.avd` folder holding the device data. */
    val path: String,
    val apiLevel: ApiLevel?,
    val formFactor: FormFactor,
    /** Device profile id (`pixel_9`, `tv_4k`, ...) or a custom name. */
    val deviceProfile: String?,
    val manufacturer: String?,
    /** System image flavour: `google_apis`, `google_apis_playstore`, `android-tv`, `default`, ... */
    val systemImageTag: String?,
    val abi: String?,
    val hasPlayStore: Boolean,
    val ramMegabytes: Int?,
    val storage: String?,
    val screen: ScreenSpec?,
    val health: AvdHealth,
    val diskUsageBytes: Long,
    /** SDK-relative folder of the system image (`system-images/android-34/google_apis/arm64-v8a`), if known. */
    val systemImage: String? = null,
) {
    /** The `sdkmanager` package that provides [systemImage] (`system-images;android-34;google_apis;arm64-v8a`). */
    public val systemImagePackage: String?
        get() = systemImage?.trim('/')?.takeIf { it.isNotEmpty() }?.replace('/', ';')

    public val isLaunchable: Boolean
        get() = health == AvdHealth.READY
}
