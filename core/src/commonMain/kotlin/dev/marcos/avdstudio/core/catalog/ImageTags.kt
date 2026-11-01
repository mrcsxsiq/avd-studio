package dev.marcos.avdstudio.core.catalog

import dev.marcos.avdstudio.core.avd.ApiLevel

/**
 * What the tag directory of a system image (`google_apis_playstore`, `android-wear`, ...) means.
 * Installed images and downloadable ones go through the same rules, so they always agree.
 */
internal object ImageTags {
    private val NAMES =
        mapOf(
            "google_apis_playstore" to "Google Play",
            "google_apis" to "Google APIs",
            "default" to "Default Android",
            "android-tv" to "Android TV",
            "google-tv" to "Google TV",
            "android-wear" to "Wear OS",
            "android-wear-signed" to "Wear OS (signed)",
            "android-wear-cn" to "Wear OS (China)",
            "android-automotive" to "Automotive",
            "android-automotive-playstore" to "Automotive with Google Play",
            "android-automotive-distant-display-playstore" to "Automotive distant display with Google Play",
            "android-desktop" to "Desktop",
            "google_atd" to "Automated test device (Google APIs)",
            "aosp_atd" to "Automated test device (AOSP)",
            "google-xr" to "Android XR",
            "android-xr-v3-playstore" to "Android XR v3",
            "android-xr-preview-playstore" to "Android XR preview",
            "ai-glasses" to "AI glasses",
        )

    private val SIXTEEN_KB_SUFFIX = Regex("[_-]ps16k$")
    private const val TABLET_SUFFIX = "_tablet"

    /** The label for a tag this app knows (also with a 16 KB or tablet suffix), or null for one it has never seen. */
    fun knownLabel(tag: String): String? {
        NAMES[tag]?.let { return it }
        SIXTEEN_KB_SUFFIX.find(tag)?.let { match ->
            knownLabel(tag.removeRange(match.range))?.let { return "$it (16 KB pages)" }
        }
        if (tag.endsWith(TABLET_SUFFIX) && tag.length > TABLET_SUFFIX.length) {
            knownLabel(tag.removeSuffix(TABLET_SUFFIX))?.let { return "$it (tablet)" }
        }
        return null
    }

    /** A readable label for a tag directory: `google_apis_playstore_ps16k` becomes `Google Play (16 KB pages)`. */
    fun humanize(tag: String): String {
        NAMES[tag]?.let { return it }
        SIXTEEN_KB_SUFFIX.find(tag)?.let { return "${humanize(tag.removeRange(it.range))} (16 KB pages)" }
        if (tag.endsWith(TABLET_SUFFIX) && tag.length > TABLET_SUFFIX.length) {
            return "${humanize(tag.removeSuffix(TABLET_SUFFIX))} (tablet)"
        }
        return tag.replace('_', ' ').replace('-', ' ').replaceFirstChar { it.uppercase() }
    }

    /** Which kind of device the tags describe (an image can carry several, e.g. `google-tv` + `google_apis`). */
    fun family(tags: List<String>): ImageFamily =
        when {
            tags.any { it.startsWith("android-tv") || it.startsWith("google-tv") } -> ImageFamily.TV
            tags.any { it.startsWith("android-wear") } -> ImageFamily.WEAR_OS
            tags.any { it.startsWith("android-automotive") } -> ImageFamily.AUTOMOTIVE
            tags.any { it.startsWith("android-desktop") } -> ImageFamily.DESKTOP
            tags.any { it.contains("xr") || it.contains("glasses") } -> ImageFamily.XR
            else -> ImageFamily.GENERAL
        }

    /** `Android 16 (API 36)`, `Android Baklava (preview)`, or a fallback when nothing is known. */
    fun versionLabel(
        apiLevel: ApiLevel?,
        codeName: String?,
    ): String = apiLevel?.displayName ?: codeName?.let { "Android $it (preview)" } ?: "Unknown version"
}
