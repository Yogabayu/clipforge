package id.clipforge.clipforge_mobile

import org.junit.Assert.*
import org.junit.Test
import java.util.Locale

class RenderPolicyTest {
    @Test fun subtitleCanvasAndShortCuesPreventOversizedPortraitText() {
        val text = RenderPolicy.subtitleAss(listOf(TimedSubtitle(0.0, 6.0,
            "one two three four five six seven eight nine ten eleven twelve")), StudioRange(1.0, 5.0), 720, 1280)
        assertTrue(text.contains("PlayResX: 720\nPlayResY: 1280"))
        assertTrue(text.contains("Style: Default,Roboto,27,"))
        assertTrue(text.contains("0:00:00.00,0:00:02.00"))
        assertTrue(text.contains("0:00:02.00,0:00:04.00"))
        assertEquals(2, text.lines().count { it.startsWith("Dialogue:") })
        assertFalse(text.contains("six seven"))
    }
    @Test fun validatesFiniteRangesWithinSource() {
        StudioRange(0.0, 2.0).validate(19.0)
        for (range in listOf(StudioRange(-1.0, 2.0), StudioRange(1.0, 1.5), StudioRange(0.0, 20.0), StudioRange(Double.NaN, 2.0))) {
            assertThrows(IllegalArgumentException::class.java) { range.validate(19.0) }
        }
    }
    @Test fun subtitlesAreClippedAndShiftedToOutputTimeline() {
        val text = RenderPolicy.subtitleAss(listOf(TimedSubtitle(8.0, 12.0, "{hello}"), TimedSubtitle(14.0, 20.0, "world"), TimedSubtitle(30.0, 40.0, "outside")), StudioRange(10.0, 16.0), 720, 1280)
        assertTrue(text.contains("0:00:00.00,0:00:02.00,Default,,0,0,0,,(hello)"))
        assertTrue(text.contains("0:00:04.00,0:00:06.00,Default,,0,0,0,,world"))
        assertFalse(text.contains("outside"))
    }
    @Test fun outputAspectResolutionAndNumbersAreDeterministic() {
        assertEquals(720 to 1280, RenderPolicy.dimensions("portrait", "720p"))
        assertEquals(1920 to 1080, RenderPolicy.dimensions("landscape", "1080p"))
        assertEquals(1440 to 2560, RenderPolicy.dimensions("portrait", "1440p"))
        val original = Locale.getDefault()
        try { Locale.setDefault(Locale.GERMANY); assertEquals("1.250", RenderPolicy.number(1.25)) }
        finally { Locale.setDefault(original) }
        assertThrows(IllegalArgumentException::class.java) { RenderPolicy.dimensions("square", "720p") }
    }
}
