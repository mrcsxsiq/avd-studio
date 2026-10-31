plugins {
    alias(libs.plugins.kotlin.multiplatform) apply false
    alias(libs.plugins.kotlin.serialization) apply false
    alias(libs.plugins.ktlint) apply false
}

// Single source of truth for the product version (also read by scripts/ and the release workflow).
val appVersion = providers.fileContents(layout.projectDirectory.file("VERSION")).asText.map { it.trim() }

allprojects {
    group = "com.mrcsxsiq.avdstudio"
    version = appVersion.get()

    apply(plugin = "org.jlleitschuh.gradle.ktlint")
    extensions.configure<org.jlleitschuh.gradle.ktlint.KtlintExtension> {
        version.set(rootProject.libs.versions.ktlintEngine)
    }
}
