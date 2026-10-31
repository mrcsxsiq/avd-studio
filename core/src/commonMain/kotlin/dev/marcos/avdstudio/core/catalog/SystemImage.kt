package dev.marcos.avdstudio.core.catalog

import dev.marcos.avdstudio.core.avd.ApiLevel
import dev.marcos.avdstudio.core.avd.FormFactor

/** Which kind of device a system image is built for. */
public enum class ImageFamily {
    /** Phones, foldables and tablets. */
    GENERAL,
    TV,
    WEAR_OS,
    AUTOMOTIVE,
    DESKTOP,
    XR,
    ;

    public fun supports(formFactor: FormFactor): Boolean =
        when (this) {
            GENERAL -> formFactor in setOf(FormFactor.PHONE, FormFactor.FOLDABLE, FormFactor.TABLET, FormFactor.UNKNOWN)
            TV -> formFactor == FormFactor.TV
            WEAR_OS -> formFactor == FormFactor.WEAR_OS
            AUTOMOTIVE -> formFactor == FormFactor.AUTOMOTIVE
            DESKTOP -> formFactor == FormFactor.DESKTOP
            XR -> formFactor == FormFactor.XR
        }
}

/** A system image installed in the SDK (`system-images/<platform>/<tag>/<abi>`). */
public data class SystemImage(
    /** What `sdkmanager`/`avdmanager` call it: `system-images;android-36;google_apis_playstore;arm64-v8a`. */
    val packagePath: String,
    /** SDK-relative folder: `system-images/android-36/google_apis_playstore/arm64-v8a`. */
    val directory: String,
    val apiLevel: ApiLevel?,
    /** Preview code name (`Baklava`) when the image is not a final release. */
    val codeName: String?,
    /** `["google_apis_playstore"]`, or several for combined images (`["google-tv", "google_apis"]`). */
    val tags: List<String>,
    /** Human label from `source.properties`, e.g. `Google Play`. */
    val tagDisplay: String,
    val abi: String,
) {
    public val hasPlayStore: Boolean
        get() = tags.any { it.contains("playstore") }

    /** Apple Silicon runs arm64 images natively; everything else is slow or will not boot. */
    public val isNativeOnAppleSilicon: Boolean
        get() = abi == "arm64-v8a"

    public val family: ImageFamily
        get() =
            when {
                tags.any { it.startsWith("android-tv") || it.startsWith("google-tv") } -> ImageFamily.TV
                tags.any { it.startsWith("android-wear") } -> ImageFamily.WEAR_OS
                tags.any { it.startsWith("android-automotive") } -> ImageFamily.AUTOMOTIVE
                tags.any { it.startsWith("android-desktop") } -> ImageFamily.DESKTOP
                tags.any { it.startsWith("android-xr") || it.contains("glasses") } -> ImageFamily.XR
                else -> ImageFamily.GENERAL
            }

    public val versionLabel: String
        get() = apiLevel?.displayName ?: codeName?.let { "Android $it (preview)" } ?: "Unknown version"

    /** `Android 16 (API 36) · Google Play · arm64-v8a` */
    public val displayName: String
        get() = "$versionLabel · $tagDisplay · $abi"
}
