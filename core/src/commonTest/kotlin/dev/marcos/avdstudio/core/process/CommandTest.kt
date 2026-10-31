package dev.marcos.avdstudio.core.process

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class CommandTest {
    @Test
    fun displayStringLeavesSafeWordsUntouched() {
        val command = Command("/sdk/emulator/emulator", listOf("-avd", "Pixel_9"))

        assertEquals("/sdk/emulator/emulator -avd Pixel_9", command.displayString)
    }

    @Test
    fun displayStringQuotesSpacesAndSingleQuotes() {
        val command = Command("/Users/a b/emulator", listOf("-avd", "it's me"))

        assertEquals("'/Users/a b/emulator' -avd 'it'\\''s me'", command.displayString)
    }

    @Test
    fun resultIsSuccessOnlyForExitCodeZero() {
        assertTrue(CommandResult(0, "", "").isSuccess)
        assertFalse(CommandResult(1, "", "boom").isSuccess)
    }
}
