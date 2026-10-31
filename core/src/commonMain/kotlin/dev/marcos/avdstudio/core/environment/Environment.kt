package dev.marcos.avdstudio.core.environment

/** The slice of the host environment the core depends on. */
public interface Environment {
    public val variables: Map<String, String>
    public val homeDirectory: String
}

public class StaticEnvironment(
    override val variables: Map<String, String>,
    override val homeDirectory: String,
) : Environment

/** Returns the trimmed value of [name], or null when it is unset or blank. */
internal fun Environment.value(name: String): String? = variables[name]?.trim()?.takeIf { it.isNotEmpty() }
