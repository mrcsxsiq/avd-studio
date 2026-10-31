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
