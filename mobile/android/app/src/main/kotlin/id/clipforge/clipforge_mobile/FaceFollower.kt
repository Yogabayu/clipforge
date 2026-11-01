package id.clipforge.clipforge_mobile

import android.media.MediaMetadataRetriever
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import java.io.File
import java.util.concurrent.TimeUnit
import kotlin.math.abs
import kotlin.math.min

data class FollowPlan(val commands: File, val detectedFrames: Int, val sampledFrames: Int)

/** Samples only selected ranges. Bundled ML Kit model; no video upload. */
class FaceFollower(private val tools: MediaTools) {
    fun plan(source: File, range: StudioRange, width: Int, height: Int, output: File,
             progress: (Int) -> Unit): FollowPlan {
        val retriever = MediaMetadataRetriever()
        val detector = FaceDetection.getClient(FaceDetectorOptions.Builder()
            .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
            .setMinFaceSize(0.08f).build())
        var detected = 0; var sampled = 0
        val points = mutableListOf<FocusPoint>()
        var cx = 0.5; var cy = 0.5; var lastSeen = -10.0
        try {
            retriever.setDataSource(source.absolutePath)
            val length = range.end - range.start
            val steps = kotlin.math.ceil(length * 2).toInt()
            for (step in 0..steps) {
                tools.checkCancelled()
                val time = min(step * 0.5, length)
                val bitmap = retriever.getScaledFrameAtTime(((range.start + min(time, length - 0.001)) * 1000000).toLong(),
                    MediaMetadataRetriever.OPTION_CLOSEST, 640, 640)
                    ?: error("Frame video tidak dapat dibaca untuk mengikuti wajah.")
                try {
                    val faces = Tasks.await(detector.process(InputImage.fromBitmap(bitmap, 0)), 20, TimeUnit.SECONDS)
                    tools.checkCancelled(); sampled++
                    val face = if (lastSeen < 0 || time - lastSeen > 2) faces.maxByOrNull { it.boundingBox.width() * it.boundingBox.height() }
                        else faces.minByOrNull { abs(it.boundingBox.exactCenterX() / bitmap.width - cx) + abs(it.boundingBox.exactCenterY() / bitmap.height - cy) }
                    val targetX = face?.let { it.boundingBox.exactCenterX().toDouble() / bitmap.width } ?: if (time - lastSeen > 2) 0.5 else cx
                    val targetY = face?.let { it.boundingBox.exactCenterY().toDouble() / bitmap.height } ?: if (time - lastSeen > 2) 0.5 else cy
                    if (face != null) { detected++; lastSeen = time }
                    // Limit camera speed and interpolate between samples during encoding.
                    cx += (targetX - cx).coerceIn(-0.12, 0.12)
                    cy += (targetY - cy).coerceIn(-0.12, 0.12)
                    val aspect = bitmap.width.toDouble() / bitmap.height
                    val outputAspect = width.toDouble() / height
                    points.add(FocusPoint(time,
                        FramingPolicy.cropOffset(cx, min(1.0, outputAspect / aspect)),
                        FramingPolicy.cropOffset(cy, min(1.0, aspect / outputAspect))))
                    progress(step * 100 / steps)
                } finally { bitmap.recycle() }
            }
            output.writeText(FramingPolicy.commands(points))
            return FollowPlan(output, detected, sampled)
        } finally { detector.close(); retriever.release() }
    }
}
