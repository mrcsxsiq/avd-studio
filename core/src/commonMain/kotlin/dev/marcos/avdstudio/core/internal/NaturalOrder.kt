package dev.marcos.avdstudio.core.internal

/** Case-insensitive "natural" ordering: `Pixel_2` < `Pixel_10`. */
internal val naturalOrder: Comparator<String> =
    Comparator { a, b ->
        val left = tokenize(a)
        val right = tokenize(b)
        for (i in 0 until minOf(left.size, right.size)) {
            val l = left[i]
            val r = right[i]
            val result =
                if (l.all { it.isDigit() } && r.all { it.isDigit() }) {
                    val byNumber =
                        l.trimStart('0').padStart(1, '0').let { ln ->
                            val rn = r.trimStart('0').padStart(1, '0')
                            if (ln.length != rn.length) ln.length.compareTo(rn.length) else ln.compareTo(rn)
                        }
                    byNumber
                } else {
                    l.lowercase().compareTo(r.lowercase())
                }
            if (result != 0) return@Comparator result
        }
        left.size.compareTo(right.size)
    }

private fun tokenize(value: String): List<String> {
    val tokens = mutableListOf<String>()
    val current = StringBuilder()
    var digits = false
    for (c in value) {
        if (current.isNotEmpty() && c.isDigit() != digits) {
            tokens += current.toString()
            current.clear()
        }
        digits = c.isDigit()
        current.append(c)
    }
    if (current.isNotEmpty()) tokens += current.toString()
    return tokens
}
