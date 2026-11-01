package dev.marcos.avdstudio.core.sdk

import dev.marcos.avdstudio.core.SDKMANAGER_LIST
import dev.marcos.avdstudio.core.SDKMANAGER_LIST_OLD_FORMAT
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class SdkManagerListParserTest {
    @Test
    fun readsBothSectionsOfTheCurrentFormat() {
        val listing = SdkManagerListParser.parse(SDKMANAGER_LIST)

        assertEquals(
            listOf(
                "emulator",
                "platforms;android-36",
                "system-images;android-23;default;armeabi-v7a",
                "system-images;android-36;google_apis_playstore;arm64-v8a",
            ),
            listing.installed.map { it.path },
        )
        assertEquals(22, listing.available.size)
        val play = listing.available.first { it.path == "system-images;android-36;google_apis_playstore;arm64-v8a" }
        assertEquals("7.0.0", play.revision)
        assertEquals("Google Play ARM 64 v8a System Image", play.description)
    }

    @Test
    fun turnsSlashPathsIntoTheSemicolonFormSdkmanagerAccepts() {
        val paths = SdkManagerListParser.parse(SDKMANAGER_LIST).available.map { it.path }

        assertTrue("add-ons;addon-google_apis-google-10" in paths)
        assertTrue("system-images;android-canary-20261007;google_apis_playstore_ps16k;arm64-v8a" in paths)
        assertTrue(paths.none { '/' in it })
    }

    @Test
    fun dropsTheExtraRevisionsMarker() {
        val available = SdkManagerListParser.parse(SDKMANAGER_LIST).available.associate { it.path to it.revision }

        assertEquals("29.0.0", available["system-images;android-24;google_apis;arm64-v8a"])
        assertEquals("3.0.0", available["platforms;android-34"])
        assertEquals(
            "Android SDK Platform 34",
            SdkManagerListParser
                .parse(SDKMANAGER_LIST)
                .available
                .first {
                    it.path ==
                        "platforms;android-34"
                }.description,
        )
    }

    @Test
    fun ignoresTheBannerProgressBarsAndWarningsAroundTheRows() {
        val noisy =
            "WARNING: banner\r\n" +
                "[=====           ] 30% Fetch remote repository...        \r[=======================] 100% Fetch remote repository...\r\n" +
                "Warning: Could not read the repository channel\r\n" +
                "Installed packages:\r\n" +
                "  emulator      37.2.13    Android Emulator   \r\n" +
                "[=====] 100% Computing updates...\r\n" +
                "Available packages:\r\n" +
                "  platform-tools     37.0.1    Android SDK Platform-Tools   \r\n" +
                "Warning: something went wrong\r\n"

        val listing = SdkManagerListParser.parse(noisy)

        assertEquals(listOf("emulator"), listing.installed.map { it.path })
        assertEquals(listOf("platform-tools"), listing.available.map { it.path })
        assertEquals("Android SDK Platform-Tools", listing.available.single().description)
    }

    @Test
    fun readsTheOldPipeSeparatedFormatSkippingHeadersRulesAndUpdates() {
        val listing = SdkManagerListParser.parse(SDKMANAGER_LIST_OLD_FORMAT)

        assertEquals(
            listOf("build-tools;28.0.3", "emulator", "system-images;android-28;google_apis;x86"),
            listing.installed.map { it.path },
        )
        assertEquals(
            listOf(
                "add-ons;addon-google_apis-google-15",
                "system-images;android-28;google_apis;x86",
                "system-images;android-29;google_apis_playstore;arm64-v8a",
            ),
            listing.available.map { it.path },
        )
        val first = listing.available.first()
        assertEquals("3", first.revision)
        assertEquals("Google APIs", first.description)
        assertEquals("29.4.6", listing.installed[1].revision)
    }

    @Test
    fun sectionTitlesMatchRegardlessOfCase() {
        val listing =
            SdkManagerListParser.parse(
                "INSTALLED PACKAGES:\n  emulator  1.0.0  Android Emulator\navailable PACKAGES:\n  adb  2.0.0  Debug Bridge\n",
            )

        assertEquals(listOf("emulator"), listing.installed.map { it.path })
        assertEquals(listOf("adb"), listing.available.map { it.path })
    }

    @Test
    fun aPipeInsideADescriptionDoesNotBreakTheCurrentFormat() {
        val listing = SdkManagerListParser.parse("Available packages:\n  extras/odd  1.0.0  Good | Bad Tools\n")

        assertEquals("Good | Bad Tools", listing.available.single().description)
    }

    @Test
    fun rowsOutsideAnyRecognisedSectionAreIgnored() {
        val listing =
            SdkManagerListParser.parse(
                "  stray  1.0.0  Not in a section\nAvailable Updates:\n  platforms/android-34  3.0.0  4.0.0\n",
            )

        assertTrue(listing.installed.isEmpty())
        assertTrue(listing.available.isEmpty())
    }

    @Test
    fun emptyAndGarbageInputGiveNothing() {
        for (text in listOf(
            "",
            "\n\n",
            "Error: Could not determine SDK root.",
            "{\"json\": true}\n  not a row\n",
            "Installed packages:\nAvailable packages:\n",
        )) {
            val listing = SdkManagerListParser.parse(text)

            assertTrue(listing.installed.isEmpty(), "installed for: $text")
            assertTrue(listing.available.isEmpty(), "available for: $text")
        }
    }
}
