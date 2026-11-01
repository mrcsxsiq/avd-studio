package dev.marcos.avdstudio.core.update

import dev.marcos.avdstudio.core.process.Command
import dev.marcos.avdstudio.core.process.CommandException
import dev.marcos.avdstudio.core.process.CommandResult
import dev.marcos.avdstudio.core.process.CommandRunner
import dev.marcos.avdstudio.core.setup.SetupPlanner
import okio.FileSystem
import okio.Path.Companion.toPath

/**
 * The commands behind "Install" in the update window. Updating the app means either asking Homebrew to do it
 * (when Homebrew manages the app) or mounting the downloaded disk image and copying the app out of it.
 *
 * Every command goes through [CommandRunner] with its arguments passed as they are, never through a shell, and
 * paths must be absolute so none of them can be read as an option.
 */
internal class AppUpdater(
    private val runner: CommandRunner,
    private val fileSystem: FileSystem,
    private val setupPlanner: SetupPlanner,
) {
    /** True when Homebrew is installed and the AVD Studio cask is installed through it. */
    fun canUpdateWithHomebrew(): Boolean {
        val brew = setupPlanner.homebrewPath() ?: return false
        return fileSystem.exists("${prefix(brew)}/Caskroom/$CASK_TOKEN".toPath())
    }

    /** `brew upgrade --cask mrcsxsiq/avd-studio/avd-studio`: brew refreshes its taps first, so this can take a minute. */
    @Throws(CommandException::class)
    fun upgradeWithHomebrew(): CommandResult {
        val brew = setupPlanner.homebrewPath() ?: throw CommandException("Homebrew is not installed.")
        val prefix = prefix(brew)
        return runner.run(
            Command(
                executable = brew,
                arguments = listOf("upgrade", "--cask", HOMEBREW_CASK),
                environment =
                    mapOf(
                        "HOMEBREW_NO_ENV_HINTS" to "1",
                        "NONINTERACTIVE" to "1",
                        // Apps started from Finder get a bare PATH; brew needs git and curl from the system.
                        "PATH" to "$prefix/bin:$prefix/sbin:/usr/bin:/bin:/usr/sbin:/sbin",
                    ),
            ),
        )
    }

    /** Mounts [dmgPath] read-only at [mountPoint] without showing it in the Finder. */
    @Throws(CommandException::class)
    fun mountDiskImage(
        dmgPath: String,
        mountPoint: String,
    ): CommandResult {
        requireAbsolute(dmgPath, mountPoint)
        return runner.run(
            Command(
                "/usr/bin/hdiutil",
                listOf("attach", "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mountPoint, dmgPath),
            ),
        )
    }

    @Throws(CommandException::class)
    fun unmountDiskImage(mountPoint: String): CommandResult {
        requireAbsolute(mountPoint)
        return runner.run(Command("/usr/bin/hdiutil", listOf("detach", mountPoint)))
    }

    /** `ditto` keeps what a signed app bundle needs (symlinks, extended attributes, permissions). */
    @Throws(CommandException::class)
    fun copyApplication(
        source: String,
        destination: String,
    ): CommandResult {
        requireAbsolute(source, destination)
        return runner.run(Command("/usr/bin/ditto", listOf(source, destination)))
    }

    /** `codesign --verify --deep --strict`: succeeds when the bundle is complete and its signature is intact. */
    @Throws(CommandException::class)
    fun verifyApplication(path: String): CommandResult {
        requireAbsolute(path)
        return runner.run(Command("/usr/bin/codesign", listOf("--verify", "--deep", "--strict", path)))
    }

    private fun prefix(brew: String): String = brew.substringBeforeLast("/bin/brew")

    private fun requireAbsolute(vararg paths: String) {
        paths.firstOrNull { !it.startsWith("/") || it.contains('\u0000') }?.let {
            throw CommandException("\"$it\" is not an absolute path.")
        }
    }

    companion object {
        const val CASK_TOKEN = "avd-studio"

        /** Fully qualified, so it works without trusting the tap and cannot clash with another tap's cask. */
        const val HOMEBREW_CASK = "mrcsxsiq/avd-studio/avd-studio"
    }
}
