package id.clipforge.clipforge_mobile

import java.util.Locale

data class StudioRange(val start: Double, val end: Double, val title: String = "Klip") {
    fun validate(duration: Double) {
        require(start.isFinite() && end.isFinite() && start >= 0 && end <= duration + 0.001 && end - start >= 1 && end - start <= 600) {
            "Rentang harus berada dalam video, berdurasi 1–600 detik."
        }
    }
}

data class TimedSubtitle(val start: Double, val end: Double, val text: String)

object RenderPolicy {
    /** Explicit canvas avoids SRT/libass's 384x288 default enlarging portrait text. */
    fun subtitleAss(segments: List<TimedSubtitle>, range: StudioRange, width: Int, height: Int): String = buildString {
        val font = (minOf(width, height) * 0.038).toInt().coerceAtLeast(16)
        val margin = (height * 0.065).toInt()
        append("[Script Info]\nScriptType: v4.00+\nPlayResX: $width\nPlayResY: $height\nWrapStyle: 0\nScaledBorderAndShadow: yes\n")
        append("[V4+ Styles]\nFormat: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding\n")
        append("Style: Default,Roboto,$font,&H00FFFFFF,&H00FFFFFF,&H00101010,&H80000000,0,0,0,0,100,100,0,0,1,1.5,0,2,${width / 12},${width / 12},$margin,1\n")
        append("[Events]\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n")
        for (segment in segments) {
            val words = segment.text.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }
            val groups = words.chunked(6)
            for ((i, group) in groups.withIndex()) {
                val span = segment.end - segment.start
                val start = maxOf(segment.start + span * (i * 6) / words.size, range.start) - range.start
                val end = minOf(segment.start + span * minOf((i + 1) * 6, words.size) / words.size, range.end) - range.start
                if (end <= start) continue
                val text = group.joinToString(" ").replace('{', '(').replace('}', ')').replace('\\', '/').replace('\n', ' ').replace('\r', ' ')
                append("Dialogue: 0,${assStamp(start)},${assStamp(end)},Default,,0,0,0,,$text\n")
            }
        }
    }

    private fun assStamp(seconds: Double): String {
        val ticks = (seconds.coerceAtLeast(0.0) * 100).toLong()
        return String.format(Locale.US, "%d:%02d:%02d.%02d", ticks / 360000, ticks / 6000 % 60, ticks / 100 % 60, ticks % 100)
    }

    fun dimensions(aspect: String, resolution: String): Pair<Int, Int> {
        require(aspect in setOf("portrait", "landscape")) { "Aspek tidak valid." }
        val short = mapOf("720p" to 720, "1080p" to 1080, "1440p" to 1440)[resolution] ?: error("Resolusi tidak valid.")
        val long = short * 16 / 9
        return if (aspect == "portrait") short to long else long to short
    }

    fun number(value: Double): String = String.format(Locale.US, "%.3f", value)
}
