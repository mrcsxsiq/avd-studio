package dev.marcos.avdstudio.core.sdk

import dev.marcos.avdstudio.core.HOME
import dev.marcos.avdstudio.core.environment.StaticEnvironment
import dev.marcos.avdstudio.core.fakeEnvironment
import dev.marcos.avdstudio.core.touch
import okio.fakefilesystem.FakeFileSystem
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class JavaLocatorTest {
    private val fs = FakeFileSystem()

    private fun locate(vararg env: Pair<String, String>) = JavaLocator(fs, fakeEnvironment(*env)).locate()

    @Test
    fun javaHomeWinsWhenItContainsAJava() {
        fs.touch("/jdk/bin/java")
        fs.touch("$HOME/.sdkman/candidates/java/current/bin/java")

        assertEquals(JavaInstallation("/jdk", JavaSource.JAVA_HOME), locate("JAVA_HOME" to "/jdk"))
    }

    @Test
    fun ignoresAStaleJavaHome() {
        fs.touch("$HOME/.sdkman/candidates/java/current/bin/java")

        assertEquals(JavaSource.SDKMAN, locate("JAVA_HOME" to "/gone")?.source)
    }

    @Test
    fun picksTheNewestSystemJvm() {
        fs.touch("/Library/Java/JavaVirtualMachines/jdk-17.jdk/Contents/Home/bin/java")
        fs.touch("/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home/bin/java")

        val java = locate()

        assertEquals("/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home", java?.home)
        assertEquals(JavaSource.SYSTEM_JVM, java?.source)
    }

    @Test
    fun fallsBackToTheJdkBundledWithAndroidStudio() {
        fs.touch("/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/java")

        assertEquals(JavaSource.ANDROID_STUDIO, locate()?.source)
    }

    @Test
    fun returnsNullWhenThereIsNoJava() {
        assertNull(locate())
    }

    @Test
    fun findsHomebrewsKegOnlyOpenJdkWhichNeedsNoAdminPassword() {
        fs.touch("/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home/bin/java")

        val java = locate()

        assertEquals(JavaSource.HOMEBREW, java?.source)
        assertEquals("/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home", java?.home)
    }

    @Test
    fun aSystemRootRedirectsTheSystemWideLocations() {
        fs.touch("/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home/bin/java")
        fs.touch("/sandbox/Library/Java/JavaVirtualMachines/jdk-17.jdk/Contents/Home/bin/java")
        val sandboxed = StaticEnvironment(emptyMap(), HOME, "/sandbox")

        val java = JavaLocator(fs, sandboxed).locate()

        assertEquals("/sandbox/Library/Java/JavaVirtualMachines/jdk-17.jdk/Contents/Home", java?.home)
    }
}
