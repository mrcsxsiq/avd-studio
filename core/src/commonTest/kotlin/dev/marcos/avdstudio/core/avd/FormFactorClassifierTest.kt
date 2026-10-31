package dev.marcos.avdstudio.core.avd

import kotlin.test.Test
import kotlin.test.assertEquals

class FormFactorClassifierTest {
    private fun classify(
        device: String? = null,
        tag: String? = null,
        screen: ScreenSpec? = null,
    ) = FormFactorClassifier.classify(device, tag, screen)

    @Test
    fun usesTheSystemImageTagForNonPhoneFamilies() {
        assertEquals(FormFactor.TV, classify(device = "tv_4k", tag = "android-tv"))
        assertEquals(FormFactor.WEAR_OS, classify(tag = "android-wear"))
        assertEquals(FormFactor.AUTOMOTIVE, classify(tag = "android-automotive-playstore"))
        assertEquals(FormFactor.DESKTOP, classify(tag = "android-desktop"))
        assertEquals(FormFactor.XR, classify(tag = "android-xr"))
    }

    @Test
    fun fallsBackToTheDeviceProfileName() {
        assertEquals(FormFactor.WEAR_OS, classify(device = "wearos_large_round", tag = "google_apis"))
        assertEquals(FormFactor.AUTOMOTIVE, classify(device = "automotive_1080p_landscape"))
        assertEquals(FormFactor.FOLDABLE, classify(device = "pixel_9_pro_fold"))
        assertEquals(FormFactor.TABLET, classify(device = "pixel_tablet"))
        assertEquals(FormFactor.TABLET, classify(device = "Pixel Tablet (Edited)"))
        assertEquals(FormFactor.TABLET, classify(device = "nexus_9"))
    }

    @Test
    fun usesScreenSizeForCustomDevices() {
        // 1920x1200 @ 240dpi -> 600dp smallest width: a tablet.
        assertEquals(FormFactor.TABLET, classify(device = "Custom", screen = ScreenSpec(1920, 1200, 240)))
        // 2400x1080 @ 420dpi -> ~411dp: a phone.
        assertEquals(FormFactor.PHONE, classify(device = "medium_phone", screen = ScreenSpec(1080, 2400, 420)))
    }

    @Test
    fun treatsUnknownInputAsUnknownAndKnownPhonesAsPhones() {
        assertEquals(FormFactor.UNKNOWN, classify())
        assertEquals(FormFactor.PHONE, classify(device = "pixel_2", tag = "google_apis_playstore"))
    }
}
