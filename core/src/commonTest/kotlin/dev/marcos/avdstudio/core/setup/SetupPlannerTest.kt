package dev.marcos.avdstudio.core.setup

import dev.marcos.avdstudio.core.HOME
import dev.marcos.avdstudio.core.avd.Avd
import dev.marcos.avdstudio.core.avd.AvdHealth
import dev.marcos.avdstudio.core.avd.FormFactor
import dev.marcos.avdstudio.core.fakeEnvironment
import dev.marcos.avdstudio.core.installSdk
import dev.marcos.avdstudio.core.sdk.JavaInstallation
import dev.marcos.avdstudio.core.sdk.JavaLocator
import dev.marcos.avdstudio.core.sdk.JavaSource
import dev.marcos.avdstudio.core.sdk.SdkLocator
import dev.marcos.avdstudio.core.touch
import okio.fakefilesystem.FakeFileSystem
import kotlin.test.Test
import kotlin.test.assertContains
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class SetupPlannerTest {
    private val fs = FakeFileSystem()
    private val env = fakeEnvironment("HOMEBREW_PREFIX" to "/opt/homebrew")
    private val sdk = "$HOME/Library/Android/sdk"
    private val brewSdk = "/opt/homebrew/share/android-commandlinetools"

    private fun plan(
        sdkPath: String? = null,
        java: JavaInstallation? = JavaLocator(fs, env).locate(),
        avds: List<Avd> = emptyList(),
    ) = SetupPlanner(fs, env).plan(SdkLocator(fs, env).resolve(sdkPath), java, avds)

    private fun brokenAvd(image: String) =
        Avd(
            name = "X",
            displayName = "X",
            path = "/x",
            apiLevel = null,
            formFactor = FormFactor.PHONE,
            deviceProfile = null,
            manufacturer = null,
            systemImageTag = null,
            abi = null,
            hasPlayStore = false,
            ramMegabytes = null,
            storage = null,
            screen = null,
            health = AvdHealth.MISSING_SYSTEM_IMAGE,
            diskUsageBytes = 0,
            systemImage = image,
        )

    @Test
    fun anEmptyMacWithHomebrewGetsTheFullPlanInOrder() {
        fs.touch("/opt/homebrew/bin/brew")

        val plan = plan()

        assertEquals(
            listOf(SetupStepKind.COMMAND_LINE_TOOLS, SetupStepKind.JAVA, SetupStepKind.LICENSES, SetupStepKind.SDK_PACKAGES),
            plan.steps.map { it.kind },
        )
        assertEquals("/opt/homebrew/bin/brew", plan.homebrewPath)
        assertEquals(brewSdk, plan.sdkPath)
        assertTrue(plan.canRunAutomatically)
        assertTrue(plan.needsLicenseAcceptance)

        val tools = plan.steps[0]
        assertEquals("brew install --cask android-commandlinetools", tools.displayCommand)
        assertEquals("/opt/homebrew/bin/brew", tools.command.executable)
        assertEquals(listOf("install", "--cask", "android-commandlinetools"), tools.command.arguments)
        assertEquals("1", tools.command.environment["NONINTERACTIVE"])

        assertEquals("brew install openjdk@17", plan.steps[1].displayCommand)

        val licenses = plan.steps[2]
        assertEquals("/bin/sh", licenses.command.executable)
        assertEquals("$brewSdk/cmdline-tools/latest/bin/sdkmanager", licenses.command.arguments[2])
        assertEquals(brewSdk, licenses.command.arguments[3])
        assertTrue(licenses.requiresLicenseAcceptance)

        val packages = plan.steps[3]
        assertEquals(listOf("--sdk_root=$brewSdk", "emulator", "platform-tools"), packages.command.arguments)
    }

    @Test
    fun withoutHomebrewThePlanCannotRunItselfButTheScriptInstallsHomebrewFirst() {
        val plan = plan()

        assertNull(plan.homebrewPath)
        assertTrue(plan.needsHomebrew)
        assertFalse(plan.canRunAutomatically)
        assertContains(plan.shellScript, SetupPlan.INSTALL_HOMEBREW)
        assertContains(plan.shellScript, "# 2. Install the Android command-line tools")
        assertContains(plan.shellScript, "brew install --cask android-commandlinetools")
        assertTrue(plan.shellScript.indexOf("install.sh") < plan.shellScript.indexOf("android-commandlinetools"))
    }

    @Test
    fun aConfiguredMacNeedsNothing() {
        fs.installSdk(sdk)

        val plan = plan(java = JavaInstallation("/jdk", JavaSource.JAVA_HOME))

        assertTrue(plan.isEmpty)
        assertFalse(plan.canRunAutomatically)
        assertEquals(sdk, plan.sdkPath)
    }

    @Test
    fun onlyTheMissingPartsAreInstalledIntoTheExistingSdk() {
        fs.touch("$sdk/cmdline-tools/latest/bin/sdkmanager")
        fs.touch("$sdk/cmdline-tools/latest/bin/avdmanager")
        fs.touch("$sdk/platform-tools/adb")

        val plan =
            plan(
                java = JavaInstallation("/jdk", JavaSource.JAVA_HOME),
                avds = listOf(brokenAvd("system-images/android-34/google_apis/arm64-v8a")),
            )

        assertEquals(listOf(SetupStepKind.LICENSES, SetupStepKind.SDK_PACKAGES, SetupStepKind.SYSTEM_IMAGES), plan.steps.map { it.kind })
        assertFalse(plan.needsHomebrew)
        assertTrue(plan.canRunAutomatically, "sdkmanager steps need no Homebrew")
        assertEquals(sdk, plan.sdkPath)
        assertEquals(listOf("--sdk_root=$sdk", "emulator"), plan.steps[1].command.arguments)
        assertEquals(listOf("--sdk_root=$sdk", "system-images;android-34;google_apis;arm64-v8a"), plan.steps[2].command.arguments)
        assertEquals("$sdk/cmdline-tools/latest/bin/sdkmanager", plan.steps[2].command.executable)
        assertContains(plan.steps[2].displayCommand, "\"system-images;android-34;google_apis;arm64-v8a\"")
    }

    @Test
    fun aMissingJdkAloneIsOneBrewStepAndIntelHomebrewIsFoundWithoutAPrefix() {
        fs.installSdk(sdk)
        fs.touch("/usr/local/bin/brew")
        val noPrefix = fakeEnvironment()

        val plan = SetupPlanner(fs, noPrefix).plan(SdkLocator(fs, noPrefix).resolve(null), null, emptyList())

        assertEquals(listOf(SetupStepKind.JAVA), plan.steps.map { it.kind })
        assertEquals("/usr/local/bin/brew", plan.homebrewPath)
        assertFalse(plan.needsLicenseAcceptance)
    }

    @Test
    fun quotesPathsWithSpacesInTheDisplayedCommands() {
        val env = fakeEnvironment("HOMEBREW_PREFIX" to "/opt/homebrew")
        val sdkWithSpace = "/Volumes/My SSD/sdk"
        fs.touch("$sdkWithSpace/cmdline-tools/latest/bin/sdkmanager")
        fs.touch("$sdkWithSpace/cmdline-tools/latest/bin/avdmanager")

        val plan =
            SetupPlanner(
                fs,
                env,
            ).plan(SdkLocator(fs, env).resolve(sdkWithSpace), JavaInstallation("/jdk", JavaSource.JAVA_HOME), emptyList())

        assertContains(plan.steps.last().displayCommand, "--sdk_root='/Volumes/My SSD/sdk'")
        assertEquals(
            "--sdk_root=/Volumes/My SSD/sdk",
            plan.steps
                .last()
                .command.arguments
                .first(),
        )
    }

    @Test
    fun anExplicitHomebrewPrefixIsTrustedEvenWhenTheDefaultLocationHasBrew() {
        fs.touch("/opt/homebrew/bin/brew")
        val custom = fakeEnvironment("HOMEBREW_PREFIX" to "/opt/brew")

        assertNull(SetupPlanner(fs, custom).homebrewPath())
        fs.touch("/opt/brew/bin/brew")
        assertEquals("/opt/brew/bin/brew", SetupPlanner(fs, custom).homebrewPath())
    }
}
