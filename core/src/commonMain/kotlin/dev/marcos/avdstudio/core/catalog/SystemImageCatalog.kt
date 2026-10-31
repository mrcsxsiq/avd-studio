package dev.marcos.avdstudio.core.catalog

import dev.marcos.avdstudio.core.avd.ApiLevel
import dev.marcos.avdstudio.core.internal.IniParser
import okio.FileSystem
import okio.Path
import okio.Path.Companion.toPath

/** Finds the system images installed in an SDK by reading `system-images/` from disk (no Java needed). */
internal class SystemImageCatalog(
    private val fileSystem: FileSystem,
) {
    fun installed(sdkPath: String): List<SystemImage> {
        val root = sdkPath.toPath() / "system-images"
        val images = mutableListOf<SystemImage>()
        for (platform in directories(root)) {
            for (tag in directories(platform)) {
                for (abi in directories(tag)) {
                    val hasImage = fileSystem.exists(abi / "system.img") || fileSystem.exists(abi / "source.properties")
                    if (hasImage) images += read(platform.name, tag.name, abi)
                }
            }
        }
        return images.sortedWith(ORDER)
    }

    private fun read(
        platform: String,
        tagDirectory: String,
        abiDirectory: Path,
    ): SystemImage {
        val properties =
            runCatching { IniParser.parse(fileSystem.read(abiDirectory / "source.properties") { readUtf8() }) }
                .getOrDefault(emptyMap())
        val tags = properties["SystemImage.TagId"]?.split(',')?.map { it.trim() }?.filter { it.isNotEmpty() } ?: listOf(tagDirectory)
        val abi = properties["SystemImage.Abi"] ?: abiDirectory.name
        return SystemImage(
            packagePath = "system-images;$platform;$tagDirectory;${abiDirectory.name}",
            directory = "system-images/$platform/$tagDirectory/${abiDirectory.name}",
            apiLevel = (properties["AndroidVersion.ApiLevel"] ?: platform).let(ApiLevel::parse),
            codeName = properties["AndroidVersion.CodeName"]?.takeIf { it.isNotEmpty() },
            tags = tags,
            tagDisplay = properties["SystemImage.TagDisplay"]?.takeIf { it.isNotEmpty() } ?: humanize(tags.first()),
            abi = abi,
        )
    }

    private fun directories(path: Path): List<Path> =
        runCatching { fileSystem.list(path) }
            .getOrDefault(emptyList())
            .filter { fileSystem.metadataOrNull(it)?.isDirectory == true && !it.name.startsWith(".") }
            .sortedBy { it.name }

    private fun humanize(tag: String): String =
        when (tag) {
            "google_apis_playstore" -> "Google Play"
            "google_apis" -> "Google APIs"
            "default" -> "Default Android"
            "android-tv" -> "Android TV"
            "google-tv" -> "Google TV"
            "android-wear" -> "Wear OS"
            "android-automotive" -> "Automotive"
            "android-automotive-playstore" -> "Automotive with Google Play"
            "android-desktop" -> "Desktop"
            else -> tag.replace('_', ' ').replace('-', ' ')
        }

    private companion object {
        /** Newest Android first; within a version Play > Google APIs > default; arm64 first. */
        val ORDER: Comparator<SystemImage> =
            compareByDescending<SystemImage> { it.apiLevel ?: ApiLevel(Int.MAX_VALUE) }
                .thenBy { image ->
                    when {
                        image.hasPlayStore -> 0
                        "google_apis" in image.tags -> 1
                        "default" in image.tags -> 2
                        else -> 3
                    }
                }.thenBy { if (it.isNativeOnAppleSilicon) 0 else 1 }
                .thenBy { it.packagePath }
    }
}
