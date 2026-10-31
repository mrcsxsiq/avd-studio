package dev.marcos.avdstudio.core.avd

/** An Android API level such as `34` or `36.1` (minor SDK releases exist since Android 16). */
public data class ApiLevel(
    val major: Int,
    val minor: Int = 0,
) : Comparable<ApiLevel> {
    override fun compareTo(other: ApiLevel): Int = compareValuesBy(this, other, { it.major }, { it.minor })

    /** `34`, or `36.1` when there is a minor revision. */
    public val label: String
        get() = if (minor == 0) "$major" else "$major.$minor"

    /** Marketing version, e.g. `14` for API 34, when known. */
    public val androidVersion: String?
        get() = ANDROID_VERSIONS[major]

    /** `Android 14 (API 34)`, or just `API 34` for unknown releases. */
    public val displayName: String
        get() = androidVersion?.let { "Android $it (API $label)" } ?: "API $label"

    override fun toString(): String = label

    public companion object {
        /**
         * Parses `android-34`, `android-37.0`, `34` or `36.1`. Returns null for preview codenames
         * (`android-Baklava`) and anything else that is not numeric.
         */
        public fun parse(value: String): ApiLevel? {
            val match = Regex("^(?:android-)?(\\d+)(?:\\.(\\d+))?").find(value.trim()) ?: return null
            val (major, minor) = match.destructured
            return ApiLevel(major.toInt(), minor.ifEmpty { "0" }.toInt())
        }
    }
}

private val ANDROID_VERSIONS: Map<Int, String> =
    mapOf(
        16 to "4.1",
        17 to "4.2",
        18 to "4.3",
        19 to "4.4",
        20 to "4.4W",
        21 to "5.0",
        22 to "5.1",
        23 to "6.0",
        24 to "7.0",
        25 to "7.1",
        26 to "8.0",
        27 to "8.1",
        28 to "9",
        29 to "10",
        30 to "11",
        31 to "12",
        32 to "12L",
        33 to "13",
        34 to "14",
        35 to "15",
        36 to "16",
        37 to "17",
    )
