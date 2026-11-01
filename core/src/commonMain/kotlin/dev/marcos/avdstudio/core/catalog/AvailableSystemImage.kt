package dev.marcos.avdstudio.core.catalog

import dev.marcos.avdstudio.core.avd.ApiLevel

/** A system image `sdkmanager` can download, or has already downloaded (see [isInstalled]). */
public data class AvailableSystemImage(
    /** `system-images;android-36;google_apis_playstore;arm64-v8a` (always the `;` form). */
    val packagePath: String,
    val apiLevel: ApiLevel?,
    /** Set when [apiLevel] is null: the platform segment without `android-`, e.g. `canary-20261007`, `Baklava`. */
    val codeName: String?,
    /** The tag directory as it appears in the path, e.g. `google_apis_playstore_ps16k`. */
    val tag: String,
    /** Human label, e.g. `Google Play`, `Google Play (16 KB pages)`, `Android TV`, `Wear OS`, `Automated test device (Google APIs)`. */
    val tagDisplay: String,
    val abi: String,
    /** The revision sdkmanager would download, e.g. `7.0.0`. */
    val revision: String,
    /** The description sdkmanager prints. */
    val description: String,
    val isInstalled: Boolean,
) {
    public val hasPlayStore: Boolean
        get() = tag.contains("playstore")

    /** Apple Silicon runs arm64 images natively; everything else is slow or will not boot. */
    public val isNativeOnAppleSilicon: Boolean
        get() = abi == "arm64-v8a"

    public val family: ImageFamily
        get() = ImageTags.family(listOf(tag))

    /** A preview, canary or beta build rather than a released Android version. */
    public val isPreview: Boolean
        get() = codeName != null || prerelease != null

    /** Built for devices that use 16 KB memory pages (`ps16k`). */
    public val usesSixteenKbPages: Boolean
        get() = tag.contains("ps16k")

    /** An "Automated Test Device" image: headless and meant for CI rather than for people to use. */
    public val isAutomatedTestImage: Boolean
        get() = tag.contains("_atd")

    /**
     * The Android extension level for platforms such as `android-36-ext18` (the same API level with newer
     * system APIs), or null for ordinary images.
     */
    public val extensionLevel: Int?
        get() =
            EXTENSION_LEVEL
                .find(platform)
                ?.groupValues
                ?.get(1)
                ?.toIntOrNull()

    /** `beta 1` for platforms such as `android-37.2-beta1`: a pre-release of an Android version. Null for final releases. */
    public val prerelease: String?
        get() = PRERELEASE.find(platform)?.destructured?.let { (kind, number) -> "$kind $number".trim() }

    public val versionLabel: String
        get() = ImageTags.versionLabel(apiLevel, codeName)

    /** [versionLabel] with the extension level or pre-release spelled out: `Android 16 (API 36), extension 18`. */
    public val qualifiedVersionLabel: String
        get() {
            val qualifiers = listOfNotNull(extensionLevel?.let { "extension $it" }, prerelease)
            return if (qualifiers.isEmpty()) versionLabel else "$versionLabel, ${qualifiers.joinToString(", ")}"
        }

    /** `Android 16 (API 36) · Google Play · arm64-v8a` */
    public val displayName: String
        get() = "$qualifiedVersionLabel · $tagDisplay · $abi"

    /** The platform folder name of the package: `android-36`, `android-36-ext18`, `android-canary-20261007`. */
    private val platform: String
        get() = packagePath.split(';').getOrElse(1) { "" }

    private companion object {
        val EXTENSION_LEVEL = Regex("-ext(\\d+)$")
        val PRERELEASE = Regex("-(alpha|beta|rc)(\\d*)$", RegexOption.IGNORE_CASE)
    }
}
