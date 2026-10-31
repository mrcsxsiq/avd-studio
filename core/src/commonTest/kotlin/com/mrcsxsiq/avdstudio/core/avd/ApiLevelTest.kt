package com.mrcsxsiq.avdstudio.core.avd

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class ApiLevelTest {
    @Test
    fun parsesTargetStrings() {
        assertEquals(ApiLevel(34), ApiLevel.parse("android-34"))
        assertEquals(ApiLevel(37, 0), ApiLevel.parse("android-37.0"))
        assertEquals(ApiLevel(36, 1), ApiLevel.parse("android-36.1"))
        assertEquals(ApiLevel(33), ApiLevel.parse("33"))
    }

    @Test
    fun rejectsPreviewCodenamesAndGarbage() {
        assertNull(ApiLevel.parse("android-Baklava"))
        assertNull(ApiLevel.parse(""))
        assertNull(ApiLevel.parse("latest"))
    }

    @Test
    fun displayNameUsesTheMarketingVersion() {
        assertEquals("Android 14 (API 34)", ApiLevel(34).displayName)
        assertEquals("Android 16 (API 36.1)", ApiLevel(36, 1).displayName)
        assertEquals("API 99", ApiLevel(99).displayName)
    }

    @Test
    fun comparesByMajorThenMinor() {
        assertTrue(ApiLevel(36, 1) > ApiLevel(36))
        assertTrue(ApiLevel(37) > ApiLevel(36, 1))
    }
}
