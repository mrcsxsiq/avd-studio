package dev.marcos.avdstudio.core.catalog

import dev.marcos.avdstudio.core.avd.FormFactor
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class DeviceProfileCatalogTest {
    /** Trimmed from a real `avdmanager list device` (cmdline-tools 19). */
    private val fixture =
        """
        Available devices definitions:
        id: 0 or "ai_glasses_displayless"
            Name: Audio Glasses
            OEM : Google
            Tag : ai-glasses
        ---------
        id: 2 or "automotive_1080p_landscape"
            Name: Automotive (1080p landscape)
            OEM : Google
            Tag : android-automotive
        ---------
        id: 14 or "desktop_medium"
            Name: Medium Desktop
            OEM : Google
            Tag : android-desktop
        ---------
        id: 23 or "Nexus 7 2013"
            Name: Nexus 7
            OEM : Google
        ---------
        id: 54 or "pixel_9"
            Name: Pixel 9
            OEM : Google
        ---------
        id: 56 or "pixel_9_pro_fold"
            Name: Pixel 9 Pro Fold
            OEM : Google
        ---------
        id: 60 or "pixel_tablet"
            Name: Pixel Tablet
            OEM : Google
        ---------
        id: 61 or "Pixel Tablet (Edited)"
            Name: Pixel Tablet (Edited)
            OEM : User
        ---------
        id: 63 or "resizable"
            Name: Resizable (Experimental)
            OEM : Generic
        ---------
        id: 69 or "tv_4k"
            Name: Television (4K)
            OEM : Google
            Tag : android-tv
        ---------
        id: 72 or "wearos_rect"
            Name: Wear OS Rectangular
            OEM : Google
            Tag : android-wear
        ---------
        id: 77 or "xr_headset_device"
            Name: XR Headset
            OEM : Google
            Tag : android-xr
        ---------
        id: 91 or "7.4in Rollable"
            Name: 7.4" Rollable
            OEM : Generic
        ---------
        id: 94 or "7in WSVGA (Tablet)"
            Name: 7" WSVGA (Tablet)
            OEM : Generic
        ---------
        id: 96 or "13.5in Freeform"
            Name: 13.5" Freeform
            OEM : Generic
        """.trimIndent()

    private val profiles = DeviceProfileCatalog.parse(fixture)

    @Test
    fun parsesEveryDefinitionWithIdNameOemAndTag() {
        assertEquals(15, profiles.size)
        val pixel = profiles.first { it.id == "pixel_9" }
        assertEquals("Pixel 9", pixel.name)
        assertEquals("Google", pixel.manufacturer)
        assertNull(pixel.tag)
        assertEquals("android-tv", profiles.first { it.id == "tv_4k" }.tag)
        assertEquals("User", profiles.first { it.id == "Pixel Tablet (Edited)" }.manufacturer)
        assertEquals("7\" WSVGA (Tablet)", profiles.first { it.id == "7in WSVGA (Tablet)" }.name)
    }

    @Test
    fun classifiesByTagIdAndFinallyByName() {
        val byId = profiles.associate { it.id to it.formFactor }
        assertEquals(FormFactor.XR, byId["ai_glasses_displayless"])
        assertEquals(FormFactor.AUTOMOTIVE, byId["automotive_1080p_landscape"])
        assertEquals(FormFactor.DESKTOP, byId["desktop_medium"])
        assertEquals(FormFactor.TABLET, byId["Nexus 7 2013"])
        assertEquals(FormFactor.PHONE, byId["pixel_9"])
        assertEquals(FormFactor.FOLDABLE, byId["pixel_9_pro_fold"])
        assertEquals(FormFactor.TABLET, byId["pixel_tablet"])
        assertEquals(FormFactor.TABLET, byId["Pixel Tablet (Edited)"])
        assertEquals(FormFactor.PHONE, byId["resizable"])
        assertEquals(FormFactor.TV, byId["tv_4k"])
        assertEquals(FormFactor.WEAR_OS, byId["wearos_rect"])
        assertEquals(FormFactor.XR, byId["xr_headset_device"])
        assertEquals(FormFactor.FOLDABLE, byId["7.4in Rollable"])
        assertEquals(FormFactor.TABLET, byId["7in WSVGA (Tablet)"])
        assertEquals(FormFactor.TABLET, byId["13.5in Freeform"])
    }

    @Test
    fun recommendsAModernPixelWhenAvailableOtherwiseTheFirstOfItsKind() {
        assertEquals("pixel_9", DeviceProfileCatalog.recommended(profiles, FormFactor.PHONE)?.id)
        assertEquals("pixel_9_pro_fold", DeviceProfileCatalog.recommended(profiles, FormFactor.FOLDABLE)?.id)
        assertEquals("pixel_tablet", DeviceProfileCatalog.recommended(profiles, FormFactor.TABLET)?.id)
        assertEquals("tv_4k", DeviceProfileCatalog.recommended(profiles, FormFactor.TV)?.id, "tv_1080p is absent, so the first TV wins")
        assertNull(DeviceProfileCatalog.recommended(profiles, FormFactor.UNKNOWN))
    }

    @Test
    fun toleratesEmptyOrGarbageOutput() {
        assertEquals(emptyList(), DeviceProfileCatalog.parse(""))
        assertEquals(emptyList(), DeviceProfileCatalog.parse("Error: something\nnull"))
    }
}
