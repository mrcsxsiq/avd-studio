package com.mrcsxsiq.avdstudio.core.internal

import kotlin.test.Test
import kotlin.test.assertEquals

class NaturalOrderTest {
    @Test
    fun ordersNumbersByValueNotLexically() {
        val sorted = listOf("Pixel_10", "Pixel_2", "Pixel_1").sortedWith(naturalOrder)

        assertEquals(listOf("Pixel_1", "Pixel_2", "Pixel_10"), sorted)
    }

    @Test
    fun ignoresCase() {
        val sorted = listOf("beta", "Alpha", "alpha2", "Alpha10").sortedWith(naturalOrder)

        assertEquals(listOf("Alpha", "alpha2", "Alpha10", "beta"), sorted)
    }
}
