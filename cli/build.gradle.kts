plugins {
    alias(libs.plugins.kotlin.multiplatform)
    alias(libs.plugins.kotlin.serialization)
}

kotlin {
    compilerOptions {
        allWarningsAsErrors.set(true)
    }

    listOf(macosArm64()).forEach { target ->
        target.binaries.executable {
            baseName = "avdstudio"
            entryPoint = "com.mrcsxsiq.avdstudio.cli.main"
        }
    }

    sourceSets {
        commonMain.dependencies {
            implementation(project(":core"))
            implementation(libs.clikt)
            implementation(libs.kotlinx.serialization.json)
            implementation(libs.okio)
        }
        commonTest.dependencies {
            implementation(kotlin("test"))
        }
    }
}
