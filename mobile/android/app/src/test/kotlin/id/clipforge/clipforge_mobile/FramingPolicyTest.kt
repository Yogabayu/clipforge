package id.clipforge.clipforge_mobile

import org.junit.Assert.*
import org.junit.Test
import java.io.File

class FramingPolicyTest {
    @Test fun cropOffsetsKeepFaceInsideAvailableFrame() {
        assertEquals(0.0, FramingPolicy.cropOffset(0.0, 0.3), 0.001)
        assertEquals(1.0, FramingPolicy.cropOffset(1.0, 0.3), 0.001)
        assertEquals(0.5, FramingPolicy.cropOffset(0.5, 0.3), 0.001)
        assertEquals(0.5, FramingPolicy.cropOffset(0.9, 1.0), 0.001)
    }
    @Test fun followCommandsInterpolateAndFinishWithStationaryPosition() {
        val commands = FramingPolicy.commands(listOf(FocusPoint(0.0, 0.2, 0.5), FocusPoint(0.5, 0.8, 0.5)))
        assertTrue(commands.contains("(t-0.000)/0.500"))
        assertTrue(commands.contains("0.500 crop@follow x '(iw-ow)*0.800'"))
    }
    @Test fun eachModeHasExplicitFilterAndInvalidModesFail() {
        for (mode in listOf("center", "follow", "blur")) {
            assertTrue(FramingPolicy.filter(mode, 720, 1280, File("/tmp/focus.txt")).endsWith("setsar=1"))
        }
        assertTrue(FramingPolicy.filter("blur", 720, 1280).contains("force_original_aspect_ratio=decrease"))
        assertTrue(FramingPolicy.filter("center", 720, 1280).contains("crop@follow"))
        assertTrue(FramingPolicy.filter("follow", 720, 1280, File("/tmp/focus.txt")).contains("sendcmd="))
        assertThrows(IllegalArgumentException::class.java) { FramingPolicy.validate("unknown") }
    }
}
