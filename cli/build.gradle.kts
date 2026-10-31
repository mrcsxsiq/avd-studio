plugins {
    alias(libs.plugins.kotlin.multiplatform)
    alias(libs.plugins.kotlin.serialization)
}

// The version lives in the root VERSION file; generate a constant so `avdstudio --version` can never drift.
val productVersion = providers.fileContents(rootProject.layout.projectDirectory.file("VERSION")).asText.map { it.trim() }
val generatedVersionDir = layout.buildDirectory.dir("generated/version")
val generateBuildInfo =
    tasks.register("generateBuildInfo") {
        val outputDir = generatedVersionDir
        val version = productVersion
        inputs.property("version", version)
        outputs.dir(outputDir)
        doLast {
            val file = outputDir.get().file("com/mrcsxsiq/avdstudio/cli/BuildInfo.kt").asFile
            file.parentFile.mkdirs()
            file.writeText(
                "package com.mrcsxsiq.avdstudio.cli\n\n" +
                    "internal const val VERSION = \"${version.get()}\"\n",
            )
        }
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
        macosMain {
            kotlin.srcDir(generateBuildInfo)
        }
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

ktlint {
    filter { exclude { it.file.path.contains("/generated/") } }
}
