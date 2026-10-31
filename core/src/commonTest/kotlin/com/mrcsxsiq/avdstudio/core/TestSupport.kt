package com.mrcsxsiq.avdstudio.core

import com.mrcsxsiq.avdstudio.core.environment.StaticEnvironment
import okio.Path.Companion.toPath
import okio.fakefilesystem.FakeFileSystem

internal const val HOME = "/Users/tester"

internal fun fakeEnvironment(
    vararg variables: Pair<String, String>,
    home: String = HOME,
) = StaticEnvironment(mapOf(*variables), home)

/** Creates an empty file (and its parents), standing in for an installed executable. */
internal fun FakeFileSystem.touch(
    path: String,
    content: String = "",
) {
    val target = path.toPath()
    target.parent?.let(::createDirectories)
    write(target) { writeUtf8(content) }
}

/** Lays out a complete, modern Android SDK under [root]. */
internal fun FakeFileSystem.installSdk(root: String) {
    touch("$root/cmdline-tools/latest/bin/sdkmanager")
    touch("$root/cmdline-tools/latest/bin/avdmanager")
    touch("$root/emulator/emulator")
    touch("$root/platform-tools/adb")
}
