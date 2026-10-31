package com.mrcsxsiq.avdstudio.core.process

/** A process invocation. Arguments are passed verbatim (never through a shell). */
public data class Command(
    val executable: String,
    val arguments: List<String> = emptyList(),
    val environment: Map<String, String> = emptyMap(),
    val workingDirectory: String? = null,
) {
    /** Shell-quoted rendition, suitable for logs and "copy command" actions. */
    public val displayString: String
        get() = (listOf(executable) + arguments).joinToString(" ") { shellQuote(it) }
}

public data class CommandResult(
    val exitCode: Int,
    val standardOutput: String,
    val standardError: String,
) {
    public val isSuccess: Boolean
        get() = exitCode == 0
}

/** Thrown when a process cannot be started at all (a non-zero exit code is reported via [CommandResult]). */
public class CommandException(
    message: String,
    cause: Throwable? = null,
) : Exception(message, cause)

/**
 * Abstraction over process execution so that the core stays platform-agnostic and every
 * workflow can be unit tested with a fake runner.
 */
public interface CommandRunner {
    /** Runs [command] to completion and captures its output. */
    @Throws(CommandException::class)
    public fun run(command: Command): CommandResult

    /** Starts [command] without waiting for it (e.g. an emulator) and returns the process id. */
    @Throws(CommandException::class)
    public fun launchDetached(command: Command): Int
}

private val SAFE_SHELL_WORD = Regex("^[A-Za-z0-9_@%+=:,./-]+$")

internal fun shellQuote(word: String): String = if (SAFE_SHELL_WORD.matches(word)) word else "'" + word.replace("'", "'\\''") + "'"
