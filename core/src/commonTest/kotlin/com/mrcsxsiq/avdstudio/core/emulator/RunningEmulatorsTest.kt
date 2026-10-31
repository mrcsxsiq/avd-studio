package com.mrcsxsiq.avdstudio.core.emulator

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class RunningEmulatorsTest {
    private val sdk = "/Users/x/Library/Android/sdk/emulator"

    @Test
    fun picksTheQemuProcessOfEachEmulator() {
        val output =
            """
            101 /sbin/launchd
            202 $sdk/emulator -avd Medium_Phone -no-snapshot-load
            203 $sdk/qemu/darwin-aarch64/qemu-system-aarch64 -avd Medium_Phone -netdelay none
            310 $sdk/qemu/darwin-aarch64/qemu-system-aarch64 -avd Pixel_Tablet_API_34 -netspeed full
            """.trimIndent()

        assertEquals(
            listOf(RunningEmulator("Medium_Phone", 203), RunningEmulator("Pixel_Tablet_API_34", 310)),
            RunningEmulators.parse(output),
        )
    }

    @Test
    fun ignoresLaunchersUnrelatedProcessesAndGarbage() {
        val output = "202 $sdk/emulator -avd Only_Launcher\nnot a line\n  \n 55 /usr/bin/grep qemu-system -avd X"

        assertTrue(RunningEmulators.parse(output).isEmpty())
    }

    @Test
    fun ignoresQemuWithoutAnAvdArgument() {
        assertTrue(RunningEmulators.parse("9 /x/qemu-system-aarch64 -machine virt").isEmpty())
    }
}
