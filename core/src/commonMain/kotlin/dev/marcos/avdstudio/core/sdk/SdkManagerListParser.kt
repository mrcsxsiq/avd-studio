package dev.marcos.avdstudio.core.sdk

/** One row of `sdkmanager --list`. */
internal data class SdkListEntry(
    /** Always the `;` form (`system-images;android-36;google_apis;arm64-v8a`), whichever way sdkmanager printed it. */
    val path: String,
    /** `7.0.0`; the " (+1)" sdkmanager appends when more revisions exist is dropped. */
    val revision: String,
    val description: String,
)

/** The two sections of `sdkmanager --list` that matter here. */
internal data class SdkListing(
    val installed: List<SdkListEntry>,
    val available: List<SdkListEntry>,
)

/**
 * Reads the output of `sdkmanager --list`. Two layouts exist and both are understood:
 *
 * - sdkmanager 23 and later: no separators, columns divided by runs of spaces, paths with `/`,
 *   sections called `Installed packages:` and `Available packages:`.
 * - older versions: `|` between columns, a `Path | Version | Description | Location` header with a rule
 *   under it, paths with `;`, sections `Installed packages:`, `Available Packages:` and `Available Updates:`.
 *
 * Everything outside a row is ignored: the deprecation banner, progress bars (which contain carriage returns
 * and can even be glued to a section title), warnings, blank lines and the updates section.
 */
internal object SdkManagerListParser {
    private enum class Section { INSTALLED, AVAILABLE, OTHER }

    private val SECTION_TITLE = Regex("(installed packages|available packages|available updates):", RegexOption.IGNORE_CASE)
    private val PACKAGE_PATH = Regex("^[A-Za-z0-9][A-Za-z0-9_.-]*(?:[;/][A-Za-z0-9][A-Za-z0-9_.-]*)*$")
    private val COLUMN_GAP = Regex("\\s{2,}")
    private val EXTRA_REVISIONS = Regex("\\s*\\(\\+\\d+\\)\\s*$")
    private val HEADER_WORDS = setOf("version", "installed", "available")

    fun parse(output: String): SdkListing {
        val installed = mutableListOf<SdkListEntry>()
        val available = mutableListOf<SdkListEntry>()
        var section: Section? = null
        for (line in output.split('\n', '\r')) {
            val title = SECTION_TITLE.find(line)
            if (title != null) {
                section =
                    when (title.groupValues[1].lowercase()) {
                        "installed packages" -> Section.INSTALLED
                        "available packages" -> Section.AVAILABLE
                        else -> Section.OTHER
                    }
                continue
            }
            when (section) {
                Section.INSTALLED -> entry(line)?.let(installed::add)
                Section.AVAILABLE -> entry(line)?.let(available::add)
                Section.OTHER, null -> Unit
            }
        }
        return SdkListing(installed, available)
    }

    private fun entry(line: String): SdkListEntry? {
        // Rows are indented; progress bars, warnings and section titles are not.
        if (line.isEmpty() || !line[0].isWhitespace()) return null
        val columns = columns(line)
        if (columns.size < 2) return null
        val path = columns[0]
        val revision = columns[1].replace(EXTRA_REVISIONS, "").trim()
        val isHeader = columns[1].lowercase() in HEADER_WORDS
        if (!PACKAGE_PATH.matches(path) || revision.isEmpty() || isHeader) return null
        return SdkListEntry(path.replace('/', ';'), revision, columns.getOrElse(2) { "" })
    }

    private fun columns(line: String): List<String> {
        val pipe = line.indexOf('|')
        // A '|' only separates columns when what precedes it is a package path; a description may contain one.
        if (pipe > 0 && PACKAGE_PATH.matches(line.substring(0, pipe).trim())) return line.split('|').map { it.trim() }
        return line.trim().split(COLUMN_GAP)
    }
}
