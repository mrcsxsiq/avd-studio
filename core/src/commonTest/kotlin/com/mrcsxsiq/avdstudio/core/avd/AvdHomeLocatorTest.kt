package com.mrcsxsiq.avdstudio.core.avd

import com.mrcsxsiq.avdstudio.core.HOME
import com.mrcsxsiq.avdstudio.core.fakeEnvironment
import kotlin.test.Test
import kotlin.test.assertEquals

class AvdHomeLocatorTest {
    private fun resolve(
        explicit: String? = null,
        vararg env: Pair<String, String>,
    ) = AvdHomeLocator(fakeEnvironment(*env)).resolve(explicit)

    @Test
    fun defaultsToDotAndroidAvd() {
        assertEquals("$HOME/.android/avd", resolve())
    }

    @Test
    fun explicitPathWinsOverEverything() {
        assertEquals("/Volumes/ssd/avd", resolve("/Volumes/ssd/avd", "ANDROID_AVD_HOME" to "/other"))
    }

    @Test
    fun honoursAndroidAvdHomeThenUserHome() {
        assertEquals("/other", resolve(null, "ANDROID_AVD_HOME" to "/other", "ANDROID_USER_HOME" to "/u"))
        assertEquals("/u/avd", resolve(null, "ANDROID_USER_HOME" to "/u/"))
        assertEquals("/e/avd", resolve(null, "ANDROID_EMULATOR_HOME" to "/e", "ANDROID_USER_HOME" to "/u"))
    }
}
