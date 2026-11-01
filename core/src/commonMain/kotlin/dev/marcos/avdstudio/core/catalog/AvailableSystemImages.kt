package dev.marcos.avdstudio.core.catalog

import dev.marcos.avdstudio.core.avd.ApiLevel
import dev.marcos.avdstudio.core.sdk.SdkListEntry
import dev.marcos.avdstudio.core.sdk.SdkListing

/** Turns the parsed `sdkmanager --list` into the system images a person can choose from. */
internal object AvailableSystemImages {
    fun from(listing: SdkListing): List<AvailableSystemImage> {
        val installedPaths = listing.installed.map { it.path.lowercase() }.toSet()
        // The available row wins because it carries the revision that would be downloaded; an installed image
        // that is no longer offered (withdrawn upstream) still shows up, marked as installed.
        val entries = LinkedHashMap<String, SdkListEntry>()
        listing.installed.forEach { entries[it.path] = it }
        listing.available.forEach { entries[it.path] = it }
        return entries.values
            .mapNotNull { image(it, isInstalled = it.path.lowercase() in installedPaths) }
            .sortedWith(ORDER)
    }

    private fun image(
        entry: SdkListEntry,
        isInstalled: Boolean,
    ): AvailableSystemImage? {
        val path = SystemImagePackage.normalize(entry.path) ?: return null
        val (_, platform, tag, abi) = path.split(';')
        val apiLevel = ApiLevel.parse(platform)
        return AvailableSystemImage(
            packagePath = path,
            apiLevel = apiLevel,
            codeName = if (apiLevel == null) platform.removePrefix("android-") else null,
            tag = tag,
            tagDisplay = ImageTags.humanize(tag),
            abi = abi,
            revision = entry.revision,
            description = entry.description,
            isInstalled = isInstalled,
        )
    }

    private val PRERELEASE_RANK = mapOf("rc" to 3, "beta" to 2, "alpha" to 1)

    /** Final releases first, then release candidates, betas and alphas, the highest number of each first. */
    private fun prereleaseWeight(image: AvailableSystemImage): Int {
        val label = image.prerelease ?: return Int.MAX_VALUE
        val number = label.substringAfter(' ', "").toIntOrNull() ?: 0
        return (PRERELEASE_RANK[label.substringBefore(' ').lowercase()] ?: 0) * 1000 + number
    }

    private fun flavorRank(image: AvailableSystemImage): Int =
        when {
            image.hasPlayStore -> 0
            image.tag.startsWith("google_apis") -> 1
            image.tag == "default" -> 2
            else -> 3
        }

    /**
     * Newest Android first (previews on top); within a version the images for phones and tablets before
     * TV, Wear OS and the rest, then Play > Google APIs > default, 16 KB variants after the regular one,
     * native ABI first. The tail of the comparator only exists to make the order deterministic.
     */
    private val ORDER: Comparator<AvailableSystemImage> =
        compareByDescending<AvailableSystemImage> { it.apiLevel ?: ApiLevel(Int.MAX_VALUE) }
            .thenByDescending { it.codeName.orEmpty() }
            .thenByDescending { it.extensionLevel ?: Int.MAX_VALUE }
            .thenByDescending { prereleaseWeight(it) }
            .thenBy { it.family.ordinal }
            .thenBy { flavorRank(it) }
            .thenBy { it.usesSixteenKbPages }
            .thenBy { if (it.isNativeOnAppleSilicon) 0 else 1 }
            .thenBy { it.abi }
            .thenBy { it.tag }
            .thenBy { it.packagePath }
}
