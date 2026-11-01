package id.clipforge.clipforge_mobile

import java.io.File

data class FocusPoint(val time: Double, val x: Double, val y: Double)

/** FFmpeg filter construction and bounded crop positions, independent of detection. */
object FramingPolicy {
    fun validate(mode: String) {
        require(mode in setOf("center", "follow", "blur")) { "Mode fokus tidak valid." }
    }

    fun cropOffset(center: Double, visibleFraction: Double): Double =
        if (visibleFraction >= 0.999) 0.5 else ((center - visibleFraction / 2) / (1 - visibleFraction)).coerceIn(0.0, 1.0)

    fun filter(mode: String, width: Int, height: Int, commands: File? = null): String {
        validate(mode)
        val start = "setpts=PTS-STARTPTS,setsar=1,fps=30"
        if (mode == "blur") return "$start,split[bg][fg];" +
            "[bg]scale=$width:$height:force_original_aspect_ratio=increase,crop=$width:$height,boxblur=20:2[background];" +
            "[fg]scale=$width:$height:force_original_aspect_ratio=decrease:force_divisible_by=2[foreground];" +
            "[background][foreground]overlay=(W-w)/2:(H-h)/2:shortest=1,setsar=1"
        val send = if (mode == "follow") "sendcmd=f='${requireNotNull(commands).absolutePath}'," else ""
        return "$start,$send" +
            "crop@follow=w='trunc(min(iw,ih*$width/$height)/2)*2':h='trunc(min(ih,iw*$height/$width)/2)*2':x='(iw-ow)/2':y='(ih-oh)/2',scale=$width:$height,setsar=1"
    }

    fun commands(points: List<FocusPoint>): String = buildString {
        require(points.isNotEmpty())
        points.forEachIndexed { i, point ->
            val next = points.getOrNull(i + 1)
            fun coordinate(axis: String, value: Double, after: Double?): String {
                val fraction = if (next == null || after == null) RenderPolicy.number(value) else
                    "(${RenderPolicy.number(value)}+(${RenderPolicy.number(after - value)})*(t-${RenderPolicy.number(point.time)})/${RenderPolicy.number(next.time - point.time)})"
                return if (axis == "x") "(iw-ow)*$fraction" else "(ih-oh)*$fraction"
            }
            append("${RenderPolicy.number(point.time)} crop@follow x '${coordinate("x", point.x, next?.x)}', crop@follow y '${coordinate("y", point.y, next?.y)}';\n")
        }
    }
}
