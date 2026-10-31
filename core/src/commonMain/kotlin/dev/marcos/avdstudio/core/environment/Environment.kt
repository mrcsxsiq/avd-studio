package dev.marcos.avdstudio.core.environment

/** The slice of the host environment the core depends on. */
public interface Environment {
    public val variables: Map<String, String>
    public val homeDirectory: String

    /**
     * Prefix of the system locations the core looks at (`/Library/Java/JavaVirtualMachines`,
     * `/Applications/Android Studio.app`). Empty on a real Mac; tests point it at a temporary folder so
     * the machine they run on can never leak into the result.
     */
    public val systemRoot: String
}

public class StaticEnvironment(
    override val variables: Map<String, String>,
    override val homeDirectory: String,
    override val systemRoot: String,
) : Environment {
    public constructor(variables: Map<String, String>, homeDirectory: String) : this(variables, homeDirectory, "")
}

/** Returns the trimmed value of [name], or null when it is unset or blank. */
internal fun Environment.value(name: String): String? = variables[name]?.trim()?.takeIf { it.isNotEmpty() }
