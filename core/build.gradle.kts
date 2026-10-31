import org.jetbrains.kotlin.gradle.plugin.mpp.apple.XCFramework

plugins {
    alias(libs.plugins.kotlin.multiplatform)
}

val xcframeworkName = "AVDStudioCore"

kotlin {
    explicitApi()
    compilerOptions {
        allWarningsAsErrors.set(true)
    }

    val xcFramework = XCFramework(xcframeworkName)
    listOf(macosArm64()).forEach { target ->
        target.binaries.framework {
            baseName = xcframeworkName
            isStatic = true
            xcFramework.add(this)
        }
    }

    sourceSets {
        commonMain.dependencies {
            implementation(libs.okio)
        }
        commonTest.dependencies {
            implementation(kotlin("test"))
            implementation(libs.okio.fakefilesystem)
        }
    }
}

// Copies the XCFramework next to the Swift package (macos/Frameworks, git-ignored) so SwiftPM and
// Xcode can consume it from a stable path. `-Pavdstudio.xcframework=debug` builds the debug flavour.
// `ditto` (not Gradle's Sync) because frameworks rely on symlinks (Versions/Current) that Sync would flatten.
val xcframeworkFlavour = providers.gradleProperty("avdstudio.xcframework").orElse("release")
tasks.register<Exec>("installXCFramework") {
    group = "build"
    description = "Builds the $xcframeworkName XCFramework and installs it into macos/Frameworks."
    val flavour = xcframeworkFlavour.get()
    val source = layout.buildDirectory.dir("XCFrameworks/$flavour/$xcframeworkName.xcframework")
    val destination = rootProject.layout.projectDirectory.dir("macos/Frameworks/$xcframeworkName.xcframework")
    dependsOn("assemble${xcframeworkName}${flavour.replaceFirstChar { it.uppercase() }}XCFramework")
    inputs.dir(source)
    outputs.dir(destination)
    doFirst { destination.asFile.deleteRecursively() }
    commandLine("/usr/bin/ditto", source.get().asFile.path, destination.asFile.path)
}
