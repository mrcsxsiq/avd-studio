package com.mrcsxsiq.avdstudio.core.avd

import com.mrcsxsiq.avdstudio.core.HOME
import com.mrcsxsiq.avdstudio.core.touch
import okio.Path.Companion.toPath
import okio.fakefilesystem.FakeFileSystem
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class AvdRepositoryTest {
    private val fs = FakeFileSystem()
    private val avdHome = "$HOME/.android/avd"
    private val sdk = "$HOME/Library/Android/sdk"
    private val repository = AvdRepository(fs)

    private fun ini(vararg lines: String) = lines.joinToString("\n")

    private fun createAvd(
        iniName: String,
        folder: String = iniName,
        target: String,
        config: String?,
        pointerPath: String? = "$avdHome/$folder.avd",
    ) {
        val pointer =
            buildString {
                appendLine("avd.ini.encoding=UTF-8")
                pointerPath?.let { appendLine("path=$it") }
                appendLine("path.rel=avd/$folder.avd")
                appendLine("target=$target")
            }
        fs.touch("$avdHome/$iniName.ini", pointer)
        if (config != null) fs.touch("$avdHome/$folder.avd/config.ini", config)
        fs.touch("$avdHome/$folder.avd/userdata-qemu.img", "x".repeat(2048))
    }

    private val mediumPhoneConfig =
        """
        AvdId=Medium_Phone
        PlayStore.enabled=true
        abi.type=arm64-v8a
        avd.ini.displayname=Medium Phone
        disk.dataPartition.size=10G
        hw.device.manufacturer=Generic
        hw.device.name=medium_phone
        hw.lcd.density=420
        hw.lcd.height=2400
        hw.lcd.width=1080
        hw.ramSize=2048
        image.sysdir.1=system-images/android-37.0/google_apis_playstore/arm64-v8a/
        tag.id=google_apis_playstore
        target=android-37.0
        """.trimIndent()

    @Test
    fun readsAllMetadataOfAHealthyDevice() {
        createAvd("Medium_Phone", target = "android-37.0", config = mediumPhoneConfig)
        fs.touch("$sdk/system-images/android-37.0/google_apis_playstore/arm64-v8a/system.img")

        val avd = repository.list(avdHome, sdk).single()

        assertEquals("Medium_Phone", avd.name)
        assertEquals("Medium Phone", avd.displayName)
        assertEquals("$avdHome/Medium_Phone.avd", avd.path)
        assertEquals(ApiLevel(37), avd.apiLevel)
        assertEquals(FormFactor.PHONE, avd.formFactor)
        assertEquals("medium_phone", avd.deviceProfile)
        assertEquals("Generic", avd.manufacturer)
        assertEquals("google_apis_playstore", avd.systemImageTag)
        assertEquals("arm64-v8a", avd.abi)
        assertTrue(avd.hasPlayStore)
        assertEquals(2048, avd.ramMegabytes)
        assertEquals("10G", avd.storage)
        assertEquals(ScreenSpec(1080, 2400, 420), avd.screen)
        assertEquals(AvdHealth.READY, avd.health)
        assertTrue(avd.diskUsageBytes >= 2048)
    }

    @Test
    fun usesThePointerFileNotTheFolderNameAsTheIdentity() {
        // Real-world case: Medium_Phone.ini points at Medium_Phone_2.avd.
        createAvd("Medium_Phone", folder = "Medium_Phone_2", target = "android-37.0", config = mediumPhoneConfig)

        val avd = repository.list(avdHome, null).single()

        assertEquals("Medium_Phone", avd.name)
        assertEquals("$avdHome/Medium_Phone_2.avd", avd.path)
    }

    @Test
    fun fallsBackToRelativePathWhenTheAbsolutePathIsStale() {
        createAvd("Moved", target = "android-34", config = mediumPhoneConfig, pointerPath = "/old/home/.android/avd/Moved.avd")

        val avd = repository.list(avdHome, null).single()

        assertEquals("$avdHome/Moved.avd", avd.path)
        assertEquals(AvdHealth.READY, avd.health)
    }

    @Test
    fun parsesSpacedKeyValuePairsAndReadsTheTelevisionFormFactor() {
        createAvd(
            "Retroid_Pocket_5",
            target = "android-33",
            config =
                ini(
                    "hw.device.name = pixel_2",
                    "tag.id = google_apis_playstore",
                    "image.sysdir.1 = system-images/android-33/google_apis_playstore/arm64-v8a/",
                ),
        )
        createAvd(
            "Television_4K_API_34",
            target = "android-34",
            config =
                ini(
                    "hw.device.name=tv_4k",
                    "tag.id=android-tv",
                    "image.sysdir.1=system-images/android-34/android-tv/arm64-v8a/",
                ),
        )

        val byName = repository.list(avdHome, null).associateBy { it.name }

        assertEquals("pixel_2", byName.getValue("Retroid_Pocket_5").deviceProfile)
        assertEquals(FormFactor.PHONE, byName.getValue("Retroid_Pocket_5").formFactor)
        assertEquals(FormFactor.TV, byName.getValue("Television_4K_API_34").formFactor)
        assertEquals("Retroid Pocket 5", byName.getValue("Retroid_Pocket_5").displayName)
    }

    @Test
    fun flagsDevicesWhoseSystemImageIsNotInstalled() {
        createAvd(
            "Pixel_Tablet_API_23",
            target = "android-23",
            config =
                ini(
                    "hw.device.name=Pixel Tablet (Edited)",
                    "tag.id=google_apis",
                    "image.sysdir.1=system-images/android-23/google_apis/arm64-v8a/",
                ),
        )
        fs.createDirectories(sdk.toPath())

        val avd = repository.list(avdHome, sdk).single()

        assertEquals(AvdHealth.MISSING_SYSTEM_IMAGE, avd.health)
        assertFalse(avd.isLaunchable)
        assertEquals(FormFactor.TABLET, avd.formFactor)
    }

    @Test
    fun doesNotJudgeSystemImagesWithoutAnSdk() {
        createAvd("Anything", target = "android-34", config = mediumPhoneConfig)

        assertEquals(AvdHealth.READY, repository.list(avdHome, null).single().health)
    }

    @Test
    fun derivesTheApiLevelFromTheSystemImageWhenTargetIsMissing() {
        fs.touch("$avdHome/NoTarget.ini", "path=$avdHome/NoTarget.avd")
        fs.touch("$avdHome/NoTarget.avd/config.ini", "image.sysdir.1=system-images/android-35/google_apis/arm64-v8a/")

        assertEquals(ApiLevel(35), repository.list(avdHome, null).single().apiLevel)
    }

    @Test
    fun reportsDevicesWithoutAConfigAsInvalid() {
        createAvd("Broken", target = "android-34", config = null)

        val avd = repository.list(avdHome, null).single()

        assertEquals(AvdHealth.INVALID_CONFIGURATION, avd.health)
        assertEquals(FormFactor.UNKNOWN, avd.formFactor)
    }

    @Test
    fun sortsNaturallyAndIgnoresNonIniFiles() {
        listOf("Pixel_10", "Pixel_2", "Pixel_1").forEach {
            createAvd(it, target = "android-34", config = mediumPhoneConfig)
        }
        fs.touch("$avdHome/.DS_Store")

        assertEquals(listOf("Pixel_1", "Pixel_2", "Pixel_10"), repository.list(avdHome, null).map { it.name })
    }

    @Test
    fun returnsNothingWhenTheFolderDoesNotExist() {
        assertTrue(repository.list("/nowhere/avd", null).isEmpty())
    }
}
