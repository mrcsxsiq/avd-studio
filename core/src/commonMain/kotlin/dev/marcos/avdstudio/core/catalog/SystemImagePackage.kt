package dev.marcos.avdstudio.core.catalog

/**
 * The only package names this app hands to `sdkmanager` for installing or removing: system images,
 * `system-images;<platform>;<tag>;<abi>`. Anything else is refused up front, so a typo (or a hostile
 * string) can never uninstall the emulator or the platform tools.
 */
internal object SystemImagePackage {
    private val ALLOWED_CHARACTERS = Regex("^[A-Za-z0-9_.;/-]+$")

    /**
     * Accepts the `;` form sdkmanager documents and the `/` form it prints, with or without a trailing
     * separator, and returns the `;` form. Returns null for anything that is not a system image package.
     */
    fun normalize(value: String): String? {
        if (!ALLOWED_CHARACTERS.matches(value) || value.contains("..")) return null
        val canonical = value.replace('/', ';').trimEnd(';')
        val parts = canonical.split(';')
        val isSystemImage = parts.size == 4 && parts[0] == "system-images" && parts.none { it.isEmpty() || it == "." }
        return canonical.takeIf { isSystemImage }
    }

    /** True when both names point at the same image, whichever way they are written. */
    fun same(
        first: String,
        second: String,
    ): Boolean {
        val a = first.trim().replace('/', ';').trim(';')
        val b = second.trim().replace('/', ';').trim(';')
        return a.equals(b, ignoreCase = true)
    }
}
