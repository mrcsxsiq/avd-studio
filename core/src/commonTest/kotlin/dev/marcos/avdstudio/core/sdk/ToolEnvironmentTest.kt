package dev.marcos.avdstudio.core.sdk

import dev.marcos.avdstudio.core.fakeEnvironment
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse

class ToolEnvironmentTest {
    @Test
    fun exportsSdkAvdHomeAndJavaAndExtendsPath() {
        val env =
            ToolEnvironment(fakeEnvironment("PATH" to "/usr/bin:/bin"))
                .build("/sdk", "/avd", JavaInstallation("/jdk", JavaSource.JAVA_HOME))

        assertEquals("/sdk", env["ANDROID_HOME"])
        assertEquals("/sdk", env["ANDROID_SDK_ROOT"])
        assertEquals("/avd", env["ANDROID_AVD_HOME"])
        assertEquals("/jdk", env["JAVA_HOME"])
        assertEquals("/jdk/bin:/sdk/platform-tools:/usr/bin:/bin", env["PATH"])
    }

    @Test
    fun usesASensiblePathWhenLaunchedFromFinderWithoutOne() {
        val env = ToolEnvironment(fakeEnvironment()).build("/sdk", "/avd", null)

        assertFalse("JAVA_HOME" in env)
        assertEquals(
            "/sdk/platform-tools:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
            env["PATH"],
        )
    }
}
