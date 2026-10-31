package com.mrcsxsiq.avdstudio.core.internal

import kotlin.test.Test
import kotlin.test.assertEquals

class IniParserTest {
    @Test
    fun parsesPlainKeyValuePairs() {
        val result = IniParser.parse("avd.ini.encoding=UTF-8\npath=/Users/x/.android/avd/Pixel.avd\ntarget=android-37.0\n")

        assertEquals("UTF-8", result["avd.ini.encoding"])
        assertEquals("/Users/x/.android/avd/Pixel.avd", result["path"])
        assertEquals("android-37.0", result["target"])
    }

    @Test
    fun toleratesSpacesAroundTheSeparator() {
        // Seen in AVDs created by third-party tools.
        val result = IniParser.parse("hw.device.name = pixel_2\ntag.id = google_apis_playstore")

        assertEquals("pixel_2", result["hw.device.name"])
        assertEquals("google_apis_playstore", result["tag.id"])
    }

    @Test
    fun skipsCommentsBlankLinesAndMalformedLines() {
        val result = IniParser.parse("# comment\n; another\n\nnot a pair\n=orphan\nkey=value")

        assertEquals(mapOf("key" to "value"), result)
    }

    @Test
    fun keepsEqualsSignsInsideValuesAndLastDuplicateWins() {
        val result = IniParser.parse("a=1\nb=x=y\na=2")

        assertEquals("2", result["a"])
        assertEquals("x=y", result["b"])
    }

    @Test
    fun keepsEmptyValuesAndStripsByteOrderMark() {
        val result = IniParser.parse("﻿fastboot.chosenSnapshotFile=\nkey=v")

        assertEquals("", result["fastboot.chosenSnapshotFile"])
        assertEquals("v", result["key"])
    }
}
