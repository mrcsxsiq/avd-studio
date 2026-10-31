package com.mrcsxsiq.avdstudio.core.process

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class NativeCommandRunnerTest {
    private val runner = NativeCommandRunner()

    private fun sh(
        script: String,
        environment: Map<String, String> = emptyMap(),
        workingDirectory: String? = null,
    ) = runner.run(Command("/bin/sh", listOf("-c", script), environment, workingDirectory))

    @Test
    fun capturesStandardOutputAndExitCode() {
        val result = sh("printf hello")

        assertTrue(result.isSuccess)
        assertEquals("hello", result.standardOutput)
        assertEquals("", result.standardError)
    }

    @Test
    fun keepsStandardErrorSeparateAndReportsFailures() {
        val result = sh("echo out; echo oops >&2; exit 3")

        assertFalse(result.isSuccess)
        assertEquals(3, result.exitCode)
        assertEquals("out\n", result.standardOutput)
        assertEquals("oops\n", result.standardError)
    }

    @Test
    fun passesArgumentsWithoutInvolvingAShell() {
        val result = runner.run(Command("/bin/echo", listOf("a b", "\$HOME", "'q'")))

        assertEquals("a b \$HOME 'q'\n", result.standardOutput)
    }

    @Test
    fun appliesEnvironmentOverridesAndWorkingDirectory() {
        val result = sh("printf '%s|%s' \"\$AVDSTUDIO_TEST\" \"\$(pwd -P)\"", mapOf("AVDSTUDIO_TEST" to "yes"), "/private/tmp")

        assertEquals("yes|/private/tmp", result.standardOutput)
    }

    @Test
    fun doesNotDeadlockOnLargeOutput() {
        val result = sh("yes 0123456789 | head -c 2000000")

        assertEquals(2_000_000, result.standardOutput.length)
    }

    @Test
    fun throwsWhenTheExecutableDoesNotExist() {
        val error = assertFailsWith<CommandException> { runner.run(Command("/definitely/not/here")) }

        assertTrue(error.message.orEmpty().contains("/definitely/not/here"))
    }

    @Test
    fun launchDetachedReturnsAPidWithoutWaiting() {
        val pid = runner.launchDetached(Command("/bin/sleep", listOf("0.1")))

        assertTrue(pid > 0)
    }
}
