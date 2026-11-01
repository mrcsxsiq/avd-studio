package dev.marcos.avdstudio.core.catalog

import dev.marcos.avdstudio.core.SDKMANAGER_LIST
import dev.marcos.avdstudio.core.avd.ApiLevel
import dev.marcos.avdstudio.core.sdk.SdkListEntry
import dev.marcos.avdstudio.core.sdk.SdkListing
import dev.marcos.avdstudio.core.sdk.SdkManagerListParser
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class AvailableSystemImagesTest {
    private val images = AvailableSystemImages.from(SdkManagerListParser.parse(SDKMANAGER_LIST))

    private fun image(packagePath: String) = images.single { it.packagePath == packagePath }

    @Test
    fun keepsOnlySystemImagesAndSortsThemNewestFirst() {
        assertEquals(
            listOf(
                "system-images;android-canary-20261007;google_apis_playstore_ps16k;arm64-v8a",
                "system-images;android-37.0;google_apis_playstore;arm64-v8a",
                "system-images;android-37.0;google_apis_playstore;x86_64",
                "system-images;android-36.1;google_apis_playstore;arm64-v8a",
                "system-images;android-36;google_apis_playstore;arm64-v8a",
                "system-images;android-36;google_apis_playstore_ps16k;arm64-v8a",
                "system-images;android-36;google_apis;arm64-v8a",
                "system-images;android-36;google_apis;x86_64",
                "system-images;android-36;default;arm64-v8a",
                "system-images;android-36;google-tv;arm64-v8a",
                "system-images;android-36;ai-glasses;arm64-v8a",
                "system-images;android-36-ext18;google_apis_playstore;arm64-v8a",
                "system-images;android-35;google_apis_playstore_tablet;arm64-v8a",
                "system-images;android-34;android-tv;arm64-v8a",
                "system-images;android-34;google-xr;arm64-v8a",
                "system-images;android-30;google_atd;arm64-v8a",
                "system-images;android-30;android-wear;arm64-v8a",
                "system-images;android-24;google_apis;arm64-v8a",
                "system-images;android-23;default;armeabi-v7a",
            ),
            images.map { it.packagePath },
        )
    }

    @Test
    fun marksTheImagesTheInstalledSectionListsEvenThoughAvailableListsThemToo() {
        assertEquals(
            setOf(
                "system-images;android-36;google_apis_playstore;arm64-v8a",
                "system-images;android-23;default;armeabi-v7a",
            ),
            images.filter { it.isInstalled }.map { it.packagePath }.toSet(),
        )
        assertFalse(image("system-images;android-36;google_apis;arm64-v8a").isInstalled)
    }

    @Test
    fun anInstalledImageSdkmanagerNoLongerOffersStillShowsUpAsInstalled() {
        val withdrawn = SdkListEntry("system-images;android-21;default;x86", "2.0.0", "Intel x86 Atom System Image")
        val listing = SdkListing(installed = listOf(withdrawn), available = emptyList())

        val only = AvailableSystemImages.from(listing).single()

        assertTrue(only.isInstalled)
        assertEquals(ApiLevel(21), only.apiLevel)
    }

    @Test
    fun theAvailableRowSuppliesTheRevisionThatWouldBeDownloaded() {
        val installed = SdkListEntry("system-images;android-36;default;arm64-v8a", "1.0.0", "old")
        val available = SdkListEntry("system-images;android-36;default;arm64-v8a", "2.0.0", "ARM 64 v8a System Image")

        val only = AvailableSystemImages.from(SdkListing(listOf(installed), listOf(available))).single()

        assertEquals("2.0.0", only.revision)
        assertEquals("ARM 64 v8a System Image", only.description)
        assertTrue(only.isInstalled)
    }

    @Test
    fun readsTheFieldsOfAPlayImage() {
        val play = image("system-images;android-36;google_apis_playstore;arm64-v8a")

        assertEquals(ApiLevel(36), play.apiLevel)
        assertNull(play.codeName)
        assertEquals("google_apis_playstore", play.tag)
        assertEquals("Google Play", play.tagDisplay)
        assertEquals("arm64-v8a", play.abi)
        assertEquals("7.0.0", play.revision)
        assertEquals("Google Play ARM 64 v8a System Image", play.description)
        assertTrue(play.hasPlayStore)
        assertTrue(play.isNativeOnAppleSilicon)
        assertEquals(ImageFamily.GENERAL, play.family)
        assertFalse(play.isPreview)
        assertFalse(play.usesSixteenKbPages)
        assertFalse(play.isAutomatedTestImage)
        assertNull(play.extensionLevel)
        assertEquals("Android 16 (API 36)", play.versionLabel)
        assertEquals("Android 16 (API 36) · Google Play · arm64-v8a", play.displayName)
    }

    @Test
    fun minorApiLevelsAndExtensionLevelsAreTold() {
        val minor = image("system-images;android-36.1;google_apis_playstore;arm64-v8a")
        val extension = image("system-images;android-36-ext18;google_apis_playstore;arm64-v8a")

        assertEquals(ApiLevel(36, 1), minor.apiLevel)
        assertEquals(18, extension.extensionLevel)
        assertEquals(ApiLevel(36), extension.apiLevel)
        assertEquals("Android 16 (API 36)", extension.versionLabel)
        assertEquals("Android 16 (API 36), extension 18", extension.qualifiedVersionLabel)
        assertEquals("Android 16 (API 36), extension 18 · Google Play · arm64-v8a", extension.displayName)
    }

    @Test
    fun previewsCarryTheirCodeNameInsteadOfAnApiLevel() {
        val canary = image("system-images;android-canary-20261007;google_apis_playstore_ps16k;arm64-v8a")

        assertNull(canary.apiLevel)
        assertEquals("canary-20261007", canary.codeName)
        assertTrue(canary.isPreview)
        assertEquals("Android canary-20261007 (preview)", canary.versionLabel)

        val baklava = "system-images;android-Baklava;google_apis;arm64-v8a"
        val named =
            AvailableSystemImages
                .from(
                    SdkListing(
                        emptyList(),
                        listOf(SdkListEntry(baklava, "1", "Google APIs")),
                    ),
                ).single()
        assertEquals("Baklava", named.codeName)
        assertNull(named.apiLevel)
    }

    @Test
    fun describesSixteenKilobytePageAndAutomatedTestImages() {
        val sixteen = image("system-images;android-36;google_apis_playstore_ps16k;arm64-v8a")
        val atd = image("system-images;android-30;google_atd;arm64-v8a")

        assertTrue(sixteen.usesSixteenKbPages)
        assertTrue(sixteen.hasPlayStore)
        assertEquals("Google Play (16 KB pages)", sixteen.tagDisplay)
        assertTrue(atd.isAutomatedTestImage)
        assertFalse(atd.hasPlayStore)
        assertEquals("Automated test device (Google APIs)", atd.tagDisplay)
    }

    @Test
    fun classifiesTheFamilyOfEveryKindOfImage() {
        assertEquals(ImageFamily.TV, image("system-images;android-34;android-tv;arm64-v8a").family)
        assertEquals(ImageFamily.TV, image("system-images;android-36;google-tv;arm64-v8a").family)
        assertEquals(ImageFamily.WEAR_OS, image("system-images;android-30;android-wear;arm64-v8a").family)
        assertEquals(ImageFamily.XR, image("system-images;android-34;google-xr;arm64-v8a").family)
        assertEquals(ImageFamily.XR, image("system-images;android-36;ai-glasses;arm64-v8a").family)
        assertEquals(ImageFamily.GENERAL, image("system-images;android-35;google_apis_playstore_tablet;arm64-v8a").family)
        assertEquals("Google Play (tablet)", image("system-images;android-35;google_apis_playstore_tablet;arm64-v8a").tagDisplay)
    }

    @Test
    fun flagsTheImagesThatAreSlowOnAppleSilicon() {
        assertFalse(image("system-images;android-36;google_apis;x86_64").isNativeOnAppleSilicon)
        assertFalse(image("system-images;android-23;default;armeabi-v7a").isNativeOnAppleSilicon)
        assertEquals(images.size - 3, images.count { it.isNativeOnAppleSilicon })
    }

    @Test
    fun ignoresPackagesThatAreNotWellFormedSystemImages() {
        val listing =
            SdkListing(
                installed = emptyList(),
                available =
                    listOf(
                        SdkListEntry("system-images;android-36", "1", "partial"),
                        SdkListEntry("system-images;android-36;a;b;c", "1", "too long"),
                        SdkListEntry("platforms;android-36", "1", "platform"),
                    ),
            )

        assertTrue(AvailableSystemImages.from(listing).isEmpty())
    }

    @Test
    fun betaPlatformsArePreviewsAndSortAfterTheFinalRelease() {
        fun entry(platform: String) =
            SdkListEntry("system-images;$platform;google_apis;arm64-v8a", "1.0.0", "Google APIs ARM 64 v8a System Image")
        val listing =
            SdkListing(
                installed = emptyList(),
                available =
                    listOf(
                        "android-37.2-beta1",
                        "android-37.2",
                        "android-37.2-beta10",
                        "android-37.2-beta2",
                        "android-37.2-rc1",
                    ).map(::entry),
            )

        val sorted = AvailableSystemImages.from(listing)

        assertEquals(
            listOf("android-37.2", "android-37.2-rc1", "android-37.2-beta10", "android-37.2-beta2", "android-37.2-beta1"),
            sorted.map { it.packagePath.split(';')[1] },
        )
        assertFalse(sorted[0].isPreview)
        assertNull(sorted[0].prerelease)
        assertTrue(sorted[1].isPreview)
        assertEquals("rc 1", sorted[1].prerelease)
        assertEquals("beta 10", sorted[2].prerelease)
        assertEquals(ApiLevel(37, 2), sorted[2].apiLevel)
        assertNull(sorted[2].codeName)
        assertEquals("Android 17 (API 37.2), beta 10 · Google APIs · arm64-v8a", sorted[2].displayName)
    }
}
