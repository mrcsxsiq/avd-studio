package dev.marcos.avdstudio.core.avd

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class AvdNamesTest {
    private val existing = listOf("Pixel_9_API_36", "Medium_Phone")

    @Test
    fun acceptsSafeNamesAndRejectsTheRest() {
        assertNull(AvdNames.validate("Pixel_10.pro-test", existing))
        assertEquals("Give the device a name.", AvdNames.validate("   ", existing))
        assertEquals("Use only letters, digits, dots, dashes and underscores (no spaces).", AvdNames.validate("Pixel 9", existing))
        assertEquals("A device called pixel_9_api_36 already exists.", AvdNames.validate("pixel_9_api_36", existing))
    }

    @Test
    fun suggestsAUniqueNameFromTheDeviceAndApiLevel() {
        assertEquals("Pixel_9_API_36_2", AvdNames.suggest("Pixel 9", "36", existing))
        assertEquals("Pixel_9_Pro_Fold_API_35", AvdNames.suggest("Pixel 9 Pro Fold", "35", existing))
        assertEquals("Television_4K_API_34", AvdNames.suggest("Television (4K)", "34", existing))
        assertEquals("7_WSVGA_Tablet", AvdNames.suggest("7\" WSVGA (Tablet)", null, existing))
        assertEquals("Device", AvdNames.suggest("((", null, existing))
    }
}
