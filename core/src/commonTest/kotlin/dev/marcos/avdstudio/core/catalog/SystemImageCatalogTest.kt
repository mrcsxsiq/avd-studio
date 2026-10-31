package dev.marcos.avdstudio.core.catalog

import dev.marcos.avdstudio.core.avd.ApiLevel
import dev.marcos.avdstudio.core.avd.FormFactor
import dev.marcos.avdstudio.core.touch
import okio.fakefilesystem.FakeFileSystem
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class SystemImageCatalogTest {
    private val fs = FakeFileSystem()
    private val sdk = "/sdk"

    private fun image(
        platform: String,
        tag: String,
        abi: String,
        properties: String? = null,
    ) {
        fs.touch("$sdk/system-images/$platform/$tag/$abi/system.img")
        properties?.let { fs.touch("$sdk/system-images/$platform/$tag/$abi/source.properties", it) }
    }

    @Test
    fun readsSourcePropertiesIncludingCombinedTagsAndMinorApiLevels() {
        image(
            "android-37.0",
            "google_apis_playstore_ps16k",
            "arm64-v8a",
            "AndroidVersion.ApiLevel=37.0\nSystemImage.Abi=arm64-v8a\nSystemImage.TagId=google_apis_playstore,page_size_16kb\nSystemImage.TagDisplay=Google APIs PlayStore,Page Size 16KB\n",
        )
        image(
            "android-36",
            "google-tv",
            "arm64-v8a",
            "AndroidVersion.ApiLevel=36\nSystemImage.Abi=arm64-v8a\nSystemImage.TagId=google-tv,google_apis\nSystemImage.TagDisplay=Google TV,Google APIs\n",
        )

        val images = SystemImageCatalog(fs).installed(sdk)

        val playstore = images.first { it.packagePath == "system-images;android-37.0;google_apis_playstore_ps16k;arm64-v8a" }
        assertEquals(ApiLevel(37), playstore.apiLevel)
        assertEquals(listOf("google_apis_playstore", "page_size_16kb"), playstore.tags)
        assertTrue(playstore.hasPlayStore)
        assertEquals(ImageFamily.GENERAL, playstore.family)
        assertEquals("Android 17 (API 37) · Google APIs PlayStore,Page Size 16KB · arm64-v8a", playstore.displayName)

        val tv = images.first { "google-tv" in it.tags }
        assertEquals(ImageFamily.TV, tv.family)
        assertTrue(tv.family.supports(FormFactor.TV))
        assertFalse(tv.family.supports(FormFactor.PHONE))
        assertEquals("system-images/android-36/google-tv/arm64-v8a", tv.directory)
    }

    @Test
    fun fallsBackToFolderNamesWithoutSourceProperties() {
        image("android-23", "default", "armeabi-v7a")

        val only = SystemImageCatalog(fs).installed(sdk).single()

        assertEquals(ApiLevel(23), only.apiLevel)
        assertEquals(listOf("default"), only.tags)
        assertEquals("Default Android", only.tagDisplay)
        assertEquals("armeabi-v7a", only.abi)
        assertFalse(only.isNativeOnAppleSilicon)
        assertNull(only.codeName)
    }

    @Test
    fun sortsNewestFirstThenPlayThenGoogleApisThenNativeAbi() {
        image("android-34", "default", "arm64-v8a")
        image("android-34", "google_apis", "arm64-v8a")
        image("android-34", "google_apis_playstore", "arm64-v8a")
        image("android-34", "google_apis", "x86_64")
        image("android-36", "google_apis", "arm64-v8a")
        image(
            "android-Baklava",
            "google_apis",
            "arm64-v8a",
            "AndroidVersion.ApiLevel=36\nAndroidVersion.CodeName=Baklava\nSystemImage.TagId=google_apis\n",
        )

        val order = SystemImageCatalog(fs).installed(sdk).map { it.packagePath }

        assertEquals(
            listOf(
                "system-images;android-36;google_apis;arm64-v8a",
                "system-images;android-Baklava;google_apis;arm64-v8a",
                "system-images;android-34;google_apis_playstore;arm64-v8a",
                "system-images;android-34;google_apis;arm64-v8a",
                "system-images;android-34;google_apis;x86_64",
                "system-images;android-34;default;arm64-v8a",
            ),
            order,
        )
        assertEquals(
            "Android 16 (API 36) · Google APIs · arm64-v8a",
            SystemImageCatalog(fs).installed(sdk)[1].versionLabel + " · Google APIs · arm64-v8a",
        )
    }

    @Test
    fun ignoresFoldersThatAreNotImagesAndMissingSdks() {
        fs.touch("$sdk/system-images/android-34/google_apis/.DS_Store")
        fs.touch("$sdk/system-images/android-34/google_apis/arm64-v8a/.incomplete")
        fs.touch("$sdk/system-images/.knownPackages")

        assertTrue(SystemImageCatalog(fs).installed(sdk).isEmpty())
        assertTrue(SystemImageCatalog(fs).installed("/nowhere").isEmpty())
    }

    @Test
    fun previewImagesShowTheirCodeName() {
        image(
            "android-Baklava",
            "google_apis",
            "arm64-v8a",
            "AndroidVersion.CodeName=Baklava\nSystemImage.TagId=google_apis\nSystemImage.TagDisplay=Google APIs\n",
        )

        val preview = SystemImageCatalog(fs).installed(sdk).single()

        assertNull(preview.apiLevel)
        assertEquals("Android Baklava (preview)", preview.versionLabel)
    }
}
