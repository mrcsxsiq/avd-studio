package dev.marcos.avdstudio.core.catalog

import kotlin.test.Test
import kotlin.test.assertEquals

class ImageTagsTest {
    @Test
    fun humanizesEveryTagTheSdkUses() {
        val expected =
            mapOf(
                "google_apis_playstore" to "Google Play",
                "google_apis" to "Google APIs",
                "default" to "Default Android",
                "google_apis_ps16k" to "Google APIs (16 KB pages)",
                "google_apis_playstore_ps16k" to "Google Play (16 KB pages)",
                "google-tv-ps16k" to "Google TV (16 KB pages)",
                "google_apis_tablet" to "Google APIs (tablet)",
                "google_apis_playstore_tablet" to "Google Play (tablet)",
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

        for ((tag, label) in expected) assertEquals(label, ImageTags.humanize(tag), tag)
    }

    @Test
    fun unknownTagsFallBackToReadableText() {
        assertEquals("Some new thing", ImageTags.humanize("some-new_thing"))
        assertEquals("Brand new (16 KB pages)", ImageTags.humanize("brand-new_ps16k"))
        assertEquals("", ImageTags.humanize(""))
    }

    @Test
    fun classifiesTheFamilyFromTheTags() {
        val expected =
            mapOf(
                listOf("google_apis_playstore") to ImageFamily.GENERAL,
                listOf("google_apis_tablet") to ImageFamily.GENERAL,
                listOf("google_atd") to ImageFamily.GENERAL,
                listOf("android-tv") to ImageFamily.TV,
                listOf("google-tv-ps16k") to ImageFamily.TV,
                listOf("google-tv", "google_apis") to ImageFamily.TV,
                listOf("android-wear") to ImageFamily.WEAR_OS,
                listOf("android-wear-signed") to ImageFamily.WEAR_OS,
                listOf("android-wear-cn") to ImageFamily.WEAR_OS,
                listOf("android-automotive-playstore") to ImageFamily.AUTOMOTIVE,
                listOf("android-automotive-distant-display-playstore") to ImageFamily.AUTOMOTIVE,
                listOf("android-desktop") to ImageFamily.DESKTOP,
                listOf("google-xr") to ImageFamily.XR,
                listOf("android-xr-v3-playstore") to ImageFamily.XR,
                listOf("android-xr-preview-playstore") to ImageFamily.XR,
                listOf("ai-glasses") to ImageFamily.XR,
            )

        for ((tags, family) in expected) assertEquals(family, ImageTags.family(tags), tags.toString())
    }
}
