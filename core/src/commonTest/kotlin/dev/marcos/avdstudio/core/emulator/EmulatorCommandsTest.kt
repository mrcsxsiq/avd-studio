package dev.marcos.avdstudio.core.emulator

import kotlin.test.Test
import kotlin.test.assertEquals

class EmulatorCommandsTest {
    private fun launch(options: EmulatorLaunchOptions = EmulatorLaunchOptions()) =
        EmulatorCommands.launch("/sdk/emulator/emulator", "Pixel_9", options, mapOf("ANDROID_HOME" to "/sdk"))

    @Test
    fun plainLaunchOnlyNamesTheDevice() {
        val command = launch()

        assertEquals("/sdk/emulator/emulator", command.executable)
        assertEquals(listOf("-avd", "Pixel_9"), command.arguments)
        assertEquals(mapOf("ANDROID_HOME" to "/sdk"), command.environment)
    }

    @Test
    fun coldBootAndWipeAddTheMatchingFlags() {
        val command = launch(EmulatorLaunchOptions(coldBoot = true, wipeData = true, extraArguments = listOf("-no-audio")))

        assertEquals(listOf("-avd", "Pixel_9", "-no-snapshot-load", "-wipe-data", "-no-audio"), command.arguments)
    }
}
