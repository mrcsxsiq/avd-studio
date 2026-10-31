package com.mrcsxsiq.avdstudio.core.sdk

import com.mrcsxsiq.avdstudio.core.HOME
import com.mrcsxsiq.avdstudio.core.fakeEnvironment
import com.mrcsxsiq.avdstudio.core.installSdk
import com.mrcsxsiq.avdstudio.core.touch
import okio.Path.Companion.toPath
import okio.fakefilesystem.FakeFileSystem
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class SdkLocatorTest {
    private val fs = FakeFileSystem()

    private fun locator(vararg env: Pair<String, String>) = SdkLocator(fs, fakeEnvironment(*env))

    @Test
    fun explicitPathIsAuthoritativeEvenWhenAnotherSdkIsConfigured() {
        fs.installSdk("$HOME/Library/Android/sdk")

        val status = locator().resolve("/custom/sdk")

        assertEquals("/custom/sdk", status.sdkPath)
        assertEquals(SdkSource.EXPLICIT, status.source)
        assertFalse(status.sdkDirectoryExists)
        assertFalse(status.isConfigured)
    }

    @Test
    fun blankExplicitPathIsIgnored() {
        fs.installSdk("$HOME/Library/Android/sdk")

        val status = locator().resolve("   ")

        assertEquals(SdkSource.ANDROID_STUDIO_DEFAULT, status.source)
        assertTrue(status.isConfigured)
    }

    @Test
    fun environmentVariablesTakePrecedenceOverTheStudioDefault() {
        fs.installSdk("/env/sdk")
        fs.installSdk("$HOME/Library/Android/sdk")

        val status = locator("ANDROID_SDK_ROOT" to "/env/sdk").resolve(null)

        assertEquals("/env/sdk", status.sdkPath)
        assertEquals(SdkSource.ANDROID_SDK_ROOT, status.source)
    }

    @Test
    fun skipsAnIncompleteCandidateInFavourOfAConfiguredOne() {
        fs.createDirectories("/env/empty".toPath())
        fs.installSdk("$HOME/Library/Android/sdk")

        val status = locator("ANDROID_HOME" to "/env/empty").resolve(null)

        assertEquals("$HOME/Library/Android/sdk", status.sdkPath)
    }

    @Test
    fun findsTheHomebrewCommandLineToolsSdk() {
        fs.touch("/opt/homebrew/share/android-commandlinetools/cmdline-tools/latest/bin/sdkmanager")

        val status = locator().resolve(null)

        assertEquals(SdkSource.HOMEBREW, status.source)
        assertTrue(status.sdkDirectoryExists)
        assertFalse(status.isConfigured)
        assertEquals(listOf(AndroidTool.AVD_MANAGER, AndroidTool.EMULATOR, AndroidTool.ADB), status.missingTools.map { it.tool })
    }

    @Test
    fun reportsTheDefaultLocationWhenNothingExists() {
        val status = locator().resolve(null)

        assertEquals("$HOME/Library/Android/sdk", status.sdkPath)
        assertFalse(status.sdkDirectoryExists)
        assertEquals("No Android SDK found at $HOME/Library/Android/sdk.", status.summary)
    }

    @Test
    fun acceptsVersionedCommandLineToolsFolders() {
        val root = "/sdk"
        fs.touch("$root/cmdline-tools/9.0/bin/sdkmanager")
        fs.touch("$root/cmdline-tools/10.0/bin/avdmanager")
        fs.touch("$root/emulator/emulator")
        fs.touch("$root/platform-tools/adb")

        val status = locator().resolve(root)

        assertEquals("$root/cmdline-tools/9.0/bin/sdkmanager", status.executable(AndroidTool.SDK_MANAGER))
        assertEquals("$root/cmdline-tools/10.0/bin/avdmanager", status.executable(AndroidTool.AVD_MANAGER))
        assertTrue(status.isConfigured)
    }

    @Test
    fun prefersLatestOverVersionedFolders() {
        fs.touch("/sdk/cmdline-tools/latest/bin/avdmanager")
        fs.touch("/sdk/cmdline-tools/99.0/bin/avdmanager")

        val status = locator().resolve("/sdk")

        assertEquals("/sdk/cmdline-tools/latest/bin/avdmanager", status.executable(AndroidTool.AVD_MANAGER))
    }

    @Test
    fun flagsLegacyToolsBinAsDeprecated() {
        fs.touch("/sdk/tools/bin/sdkmanager")
        fs.touch("/sdk/tools/bin/avdmanager")

        val status = locator().resolve("/sdk")

        assertEquals(ToolAvailability.DEPRECATED, status.state(AndroidTool.SDK_MANAGER).availability)
        assertNull(status.executable(AndroidTool.SDK_MANAGER))
        assertTrue(status.summary.startsWith("Deprecated sdkmanager, avdmanager found under tools/bin"))
    }
}
