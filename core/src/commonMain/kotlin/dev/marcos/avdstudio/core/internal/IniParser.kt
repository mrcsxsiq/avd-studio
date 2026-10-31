package dev.marcos.avdstudio.core.internal

/** Reads the flat `key=value` files Android uses for AVD metadata (`*.ini`, `config.ini`). */
internal object IniParser {
    fun parse(text: String): Map<String, String> {
        val result = LinkedHashMap<String, String>()
        for (rawLine in text.removePrefix("﻿").lineSequence()) {
            val line = rawLine.trim()
            if (line.isEmpty() || line.startsWith("#") || line.startsWith(";")) continue
            val separator = line.indexOf('=')
            if (separator <= 0) continue
            val key = line.substring(0, separator).trim()
            if (key.isEmpty()) continue
            // Some tools write `key = value`; later duplicates win, like the emulator itself.
            result[key] = line.substring(separator + 1).trim()
        }
        return result
    }
}
