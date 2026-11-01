package dev.marcos.avdstudio.core.update

import dev.marcos.avdstudio.core.fakeEnvironment
import dev.marcos.avdstudio.core.process.Command
import dev.marcos.avdstudio.core.process.CommandException
import dev.marcos.avdstudio.core.process.CommandResult
import dev.marcos.avdstudio.core.process.CommandRunner
import dev.marcos.avdstudio.core.setup.SetupPlanner
import dev.marcos.avdstudio.core.touch
import okio.Path.Companion.toPath
import okio.fakefilesystem.FakeFileSystem
import kotlin.test.Test
import kotlin.test.assertContains
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class AppUpdaterTest {
    private class Recorder(
        var result: CommandResult = CommandResult(0, "", ""),
    ) : CommandRunner {
        val commands = mutableListOf<Command>()

        override fun run(command: Command): CommandResult {
            commands += command
            return result
        }

        override fun launchDetached(command: Command): Int = error("an update never starts a detached process")
    }

    private val fs = FakeFileSystem()
    private val runner = Recorder()

    private fun updater(vararg env: Pair<String, String>): AppUpdater {
        val environment = fakeEnvironment(*env)
        return AppUpdater(runner, fs, SetupPlanner(fs, environment))
    }

    private fun brewWithCask(prefix: String = "/opt/homebrew") {
        fs.touch("$prefix/bin/brew")
        fs.createDirectories("$prefix/Caskroom/avd-studio/0.2.0".toPath())
    }

    // MARK: Does Homebrew manage the app?

    @Test
    fun homebrewUpdatesTheAppWhenBrewExistsAndTheCaskIsInstalled() {
        brewWithCask()

        assertTrue(updater().canUpdateWithHomebrew())
    }

    @Test
    fun homebrewIsNotUsedWithoutBrew() {
        fs.createDirectories("/opt/homebrew/Caskroom/avd-studio/0.2.0".toPath())

        assertFalse(updater().canUpdateWithHomebrew())
    }

    @Test
    fun homebrewIsNotUsedWhenTheAppWasNotInstalledByIt() {
        fs.touch("/opt/homebrew/bin/brew")

        assertFalse(updater().canUpdateWithHomebrew(), "brew exists but never installed this app")
    }

    @Test
    fun anotherCaskInTheCaskroomDoesNotCount() {
        fs.touch("/opt/homebrew/bin/brew")
        fs.createDirectories("/opt/homebrew/Caskroom/android-commandlinetools/13".toPath())

        assertFalse(updater().canUpdateWithHomebrew())
    }

    @Test
    fun anExplicitHomebrewPrefixIsRespected() {
        brewWithCask("/custom/brew")

        assertTrue(updater("HOMEBREW_PREFIX" to "/custom/brew").canUpdateWithHomebrew())
        assertFalse(updater("HOMEBREW_PREFIX" to "/elsewhere").canUpdateWithHomebrew())
    }

    // MARK: Upgrading with Homebrew

    @Test
    fun upgradesTheFullyQualifiedCaskWithoutAShell() {
        brewWithCask()

        updater().upgradeWithHomebrew()

        val command = runner.commands.single()
        assertEquals("/opt/homebrew/bin/brew", command.executable)
        assertEquals(listOf("upgrade", "--cask", "mrcsxsiq/avd-studio/avd-studio"), command.arguments)
        assertEquals("1", command.environment["NONINTERACTIVE"])
        assertContains(command.environment.getValue("PATH"), "/opt/homebrew/bin")
        assertContains(command.environment.getValue("PATH"), "/usr/bin")
    }

    @Test
    fun theUpgradeUsesTheBrewOfTheExplicitPrefix() {
        brewWithCask("/custom/brew")

        updater("HOMEBREW_PREFIX" to "/custom/brew").upgradeWithHomebrew()

        val command = runner.commands.single()
        assertEquals("/custom/brew/bin/brew", command.executable)
        assertContains(command.environment.getValue("PATH"), "/custom/brew/bin")
    }

    @Test
    fun theUpgradeReturnsWhateverBrewSaid() {
        brewWithCask()
        runner.result = CommandResult(1, "", "Error: nope")

        val result = updater().upgradeWithHomebrew()

        assertFalse(result.isSuccess)
        assertEquals("Error: nope", result.standardError)
    }

    @Test
    fun upgradingWithoutBrewSaysSo() {
        val error = assertFailsWith<CommandException> { updater().upgradeWithHomebrew() }

        assertContains(error.message.orEmpty(), "Homebrew is not installed")
        assertTrue(runner.commands.isEmpty())
    }

    // MARK: Disk image and copy

    @Test
    fun mountsTheImageReadOnlyHiddenAtTheGivenFolder() {
        updater().mountDiskImage("/Users/me/Downloads/AVD Studio 0.3.0.dmg", "/tmp/avd update/mount")

        val command = runner.commands.single()
        assertEquals("/usr/bin/hdiutil", command.executable)
        assertEquals(
            listOf(
                "attach",
                "-nobrowse",
                "-readonly",
                "-noautoopen",
                "-mountpoint",
                "/tmp/avd update/mount",
                "/Users/me/Downloads/AVD Studio 0.3.0.dmg",
            ),
            command.arguments,
            "paths with spaces travel as single arguments",
        )
    }

    @Test
    fun unmountsByFolder() {
        updater().unmountDiskImage("/tmp/mount")

        assertEquals(Command("/usr/bin/hdiutil", listOf("detach", "/tmp/mount")), runner.commands.single())
    }

    @Test
    fun copiesTheAppWithDitto() {
        updater().copyApplication("/tmp/mount/AVD Studio.app", "/Applications/.AVD Studio.new.app")

        assertEquals(
            Command("/usr/bin/ditto", listOf("/tmp/mount/AVD Studio.app", "/Applications/.AVD Studio.new.app")),
            runner.commands.single(),
        )
    }

    @Test
    fun verifiesTheSignatureStrictly() {
        updater().verifyApplication("/tmp/mount/AVD Studio.app")

        assertEquals(
            Command("/usr/bin/codesign", listOf("--verify", "--deep", "--strict", "/tmp/mount/AVD Studio.app")),
            runner.commands.single(),
        )
    }

    @Test
    fun relativeOrOptionLikePathsAreRefusedBeforeAnythingRuns() {
        val updater = updater()

        for (bad in listOf("relative.dmg", "-foo", "", "../x")) {
            assertFailsWith<CommandException>(bad) { updater.mountDiskImage(bad, "/tmp/mount") }
            assertFailsWith<CommandException>(bad) { updater.mountDiskImage("/tmp/a.dmg", bad) }
            assertFailsWith<CommandException>(bad) { updater.unmountDiskImage(bad) }
            assertFailsWith<CommandException>(bad) { updater.copyApplication(bad, "/tmp/x") }
            assertFailsWith<CommandException>(bad) { updater.copyApplication("/tmp/x", bad) }
            assertFailsWith<CommandException>(bad) { updater.verifyApplication(bad) }
        }

        assertTrue(runner.commands.isEmpty())
    }
}
