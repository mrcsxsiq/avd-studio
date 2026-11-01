package dev.marcos.avdstudio.core.catalog

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class SystemImagePackageTest {
    private val canonical = "system-images;android-36;google_apis_playstore;arm64-v8a"

    @Test
    fun acceptsTheSemicolonAndTheSlashFormWithOrWithoutATrailingSeparator() {
        assertEquals(canonical, SystemImagePackage.normalize(canonical))
        assertEquals(canonical, SystemImagePackage.normalize("system-images/android-36/google_apis_playstore/arm64-v8a"))
        assertEquals(canonical, SystemImagePackage.normalize("system-images/android-36/google_apis_playstore/arm64-v8a/"))
        assertEquals(canonical, SystemImagePackage.normalize("$canonical;"))
        assertEquals(
            "system-images;android-canary-20261007;google_apis_ps16k;x86_64",
            SystemImagePackage.normalize("system-images/android-canary-20261007/google_apis_ps16k/x86_64"),
        )
    }

    @Test
    fun refusesAnythingThatIsNotASystemImage() {
        val refused =
            listOf(
                "",
                "emulator",
                "platform-tools",
                "platforms;android-36",
                "cmdline-tools;latest",
                "system-images",
                "system-images;android-36",
                "system-images;android-36;google_apis",
                "system-images;android-36;google_apis;arm64-v8a;extra",
                "system-images;;google_apis;arm64-v8a",
                ";system-images;android-36;google_apis;arm64-v8a",
                "system-images;android-36;.;arm64-v8a",
                "System-Images;android-36;google_apis;arm64-v8a",
            )

        for (value in refused) assertNull(SystemImagePackage.normalize(value), "\"$value\"")
    }

    @Test
    fun refusesWhitespaceQuotesTraversalAndShellSyntax() {
        val refused =
            listOf(
                " $canonical",
                "$canonical ",
                "system-images;android 36;google_apis;arm64-v8a",
                "\"$canonical\"",
                "'$canonical'",
                "system-images;android-36;google_apis;arm64-v8a\nemulator",
                "system-images;android-36;..;arm64-v8a",
                "system-images/../emulator/x/y",
                "$canonical; rm -rf ~",
                "$canonical\$(id)",
                "$canonical`id`",
                "$canonical|cat",
                "--install system-images;android-36;google_apis;arm64-v8a",
            )

        for (value in refused) assertNull(SystemImagePackage.normalize(value), value)
    }

    @Test
    fun comparesNamesWhicheverWayTheyAreWritten() {
        assertTrue(SystemImagePackage.same(canonical, "system-images/android-36/google_apis_playstore/arm64-v8a/"))
        assertTrue(SystemImagePackage.same(canonical, " $canonical "))
        assertTrue(
            SystemImagePackage.same(
                "system-images;android-Baklava;google_apis;arm64-v8a",
                "system-images;android-baklava;google_apis;arm64-v8a",
            ),
        )
        assertFalse(SystemImagePackage.same(canonical, "system-images;android-36;google_apis;arm64-v8a"))
    }
}
