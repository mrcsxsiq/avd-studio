package dev.marcos.avdstudio.core.sdk

import dev.marcos.avdstudio.core.environment.Environment
import dev.marcos.avdstudio.core.environment.value
import okio.FileSystem
import okio.Path
import okio.Path.Companion.toPath

public enum class JavaSource {
    JAVA_HOME,
    SDKMAN,
    HOMEBREW,
    SYSTEM_JVM,
    ANDROID_STUDIO,
}

public data class JavaInstallation(
    val home: String,
    val source: JavaSource,
)

/**
 * `sdkmanager` and `avdmanager` are Java programs. Apps launched from Finder do not inherit the
 * shell's `JAVA_HOME`/`PATH`, so we look for a JDK ourselves and hand it to the tools explicitly.
 */
internal class JavaLocator(
    private val fileSystem: FileSystem,
    private val environment: Environment,
) {
    fun locate(): JavaInstallation? {
        val home = environment.homeDirectory
        val homebrewPrefix = environment.value("HOMEBREW_PREFIX") ?: "/opt/homebrew"

        val candidates =
            buildList {
                environment.value("JAVA_HOME")?.let { add(JavaInstallation(it, JavaSource.JAVA_HOME)) }
                add(JavaInstallation("$home/.sdkman/candidates/java/current", JavaSource.SDKMAN))
                add(JavaInstallation("$homebrewPrefix/opt/openjdk/libexec/openjdk.jdk/Contents/Home", JavaSource.HOMEBREW))
                installedJvms().forEach { add(JavaInstallation(it.toString(), JavaSource.SYSTEM_JVM)) }
                add(JavaInstallation("/Applications/Android Studio.app/Contents/jbr/Contents/Home", JavaSource.ANDROID_STUDIO))
            }
        return candidates.firstOrNull { fileSystem.exists(it.home.toPath() / "bin" / "java") }
    }

    private fun installedJvms(): List<Path> {
        val root = "/Library/Java/JavaVirtualMachines".toPath()
        return runCatching { fileSystem.list(root) }
            .getOrDefault(emptyList())
            .sortedByDescending { it.name }
            .map { it / "Contents" / "Home" }
    }
}
