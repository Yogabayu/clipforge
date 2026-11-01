package id.clipforge.clipforge_mobile

import android.content.Context
import android.os.SystemClock
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID
import java.util.concurrent.CancellationException
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

class StudioRunner(private val context: Context, private val sourceId: String, private val action: String,
                   private val options: JSONObject, private val notify: (String, Int) -> Unit) : MobileTask {
    private val cancelled = AtomicBoolean(false)
    private val tools = MediaTools(context, cancelled)
    @Volatile private var nativeRunning = false
    private var temporaryRender: File? = null

    override fun cancel() {
        tools.cancel()
        if (nativeRunning) NativeWhisper.cancel()
        StudioStore.update("cancelling", "Membatalkan proses…")
    }

    override fun run() {
        val started = SystemClock.elapsedRealtime()
        try {
            tools.checkCancelled()
            LocalEngine.initialize(context)
            val source = DownloadStore.completedFile(context, sourceId)
            if (action == "analyze") analyze(source) else render(source)
            StudioStore.metric("totalMs", SystemClock.elapsedRealtime() - started)
            StudioStore.update()
        } catch (error: LinkageError) {
            StudioStore.update("failed", "Library transkripsi native tidak dapat dimuat. Pasang ulang APK ARM64. ${error.message}")
        } catch (error: Exception) {
            StudioStore.metric("totalMs", SystemClock.elapsedRealtime() - started)
            StudioStore.update(if (cancelled.get() || error is CancellationException || error is InterruptedException) "cancelled" else "failed",
                if (cancelled.get()) "Proses dibatalkan. Video sumber tetap tersedia." else error.message ?: error.javaClass.simpleName)
            temporaryRender?.listFiles()?.forEach { it.delete() }; temporaryRender?.delete()
        }
    }

    private fun stage(status: String, message: String, progress: Int = 0) {
        tools.checkCancelled()
        StudioStore.update(status, message, mapOf("progress" to progress))
        notify(message, progress)
    }

    private fun analyze(source: File) {
        val language = options.optString("language", "auto")
        require(language in setOf("auto", "id", "en")) { "Bahasa tidak didukung." }
        val top = options.optInt("top", 10)
        val minimum = options.optDouble("minDuration", 35.0)
        val maximum = options.optDouble("maxDuration", 180.0)
        require(top in 1..12 && minimum.isFinite() && maximum.isFinite() && minimum >= 1 && maximum > minimum && maximum <= 600) { "Pengaturan rekomendasi tidak valid." }
        val root = StudioStore.directory(sourceId)
        val duration = MediaTools.durationMs(source) / 1000.0
        val analysisStart = options.optDouble("analysisStart", 0.0)
        val analysisEnd = options.optDouble("analysisEnd", duration)
        require(analysisStart.isFinite() && analysisEnd.isFinite() && analysisStart >= 0 &&
            analysisEnd <= duration && analysisEnd - analysisStart >= 1) { "Rentang analisis tidak valid." }
        val analysisDuration = analysisEnd - analysisStart
        val previous = StudioStore.data()
        var segments = previous.optJSONArray("segments") ?: JSONArray()
        if (segments.length() == 0 || previous.optString("language") != language || previous.optInt("transcriptRevision") < 3 || previous.optDouble("analysisStart", 0.0) != analysisStart || previous.optDouble("analysisEnd", duration) != analysisEnd || options.optBoolean("force")) {
            stage("model", "Menyiapkan model offline Small (~190 MB)…")
            val modelStarted = SystemClock.elapsedRealtime()
            val model = WhisperModel.ensure(context, tools) { percent ->
                StudioStore.update(fields = mapOf("progress" to percent), save = false)
                notify("Mengunduh model Whisper: $percent%", percent)
            }
            StudioStore.metric("modelMs", SystemClock.elapsedRealtime() - modelStarted)
            stage("audio", "Mengekstrak audio 16 kHz…")
            val pcm = File(root, "audio.pcm")
            val audioStarted = SystemClock.elapsedRealtime()
            try {
                tools.ffmpeg(listOf("-y", "-v", "error", "-ss", analysisStart.toString(), "-i", source.absolutePath, "-t", analysisDuration.toString(), "-vn", "-ac", "1", "-ar", "16000", "-f", "f32le", pcm.absolutePath))
                StudioStore.metric("audioMs", SystemClock.elapsedRealtime() - audioStarted)
                stage("transcribing", "Transkripsi lokal berjalan. Video panjang membutuhkan waktu.")
                val transcriptionStarted = SystemClock.elapsedRealtime()
                val polling = Executors.newSingleThreadScheduledExecutor()
                nativeRunning = true
                val lines = try {
                    polling.scheduleAtFixedRate({
                        if (cancelled.get()) NativeWhisper.cancel()
                        StudioStore.update(fields = mapOf("progress" to NativeWhisper.progress()), save = false)
                        notify("Transkripsi lokal", NativeWhisper.progress())
                    }, 500, 500, TimeUnit.MILLISECONDS)
                    tools.checkCancelled()
                    NativeWhisper.transcribe(model.absolutePath, pcm.absolutePath, language)
                } finally { nativeRunning = false; polling.shutdownNow() }
                tools.checkCancelled()
                StudioStore.metric("transcribeMs", SystemClock.elapsedRealtime() - transcriptionStarted)
                segments = JSONArray()
                for (line in lines) {
                    val parts = line.split('\t', limit = 3)
                    if (parts.size != 3) continue
                    val start = (analysisStart + parts[0].toDouble() / 1000).coerceIn(analysisStart, analysisEnd)
                    val end = (analysisStart + parts[1].toDouble() / 1000).coerceIn(analysisStart, analysisEnd)
                    if (start < end && parts[2].isNotBlank()) segments.put(JSONObject().put("start", start).put("end", end).put("text", parts[2].trim()))
                }
            } finally { pcm.delete() }
        }
        stage("scoring", "Menyusun hingga $top rekomendasi; belum merender file.")
        val input = File(root, "score-input.json")
        val output = File(root, "score-output.json")
        val relativeSegments = JSONArray()
        for (index in 0 until segments.length()) {
            val segment = segments.getJSONObject(index)
            relativeSegments.put(JSONObject(segment.toString())
                .put("start", segment.getDouble("start") - analysisStart)
                .put("end", segment.getDouble("end") - analysisStart))
        }
        input.writeText(JSONObject().put("duration", analysisDuration).put("segments", relativeSegments).toString(), Charsets.UTF_8)
        val scoreStarted = SystemClock.elapsedRealtime()
        tools.recommend(input, output, top, minimum, maximum)
        val candidates = JSONArray(output.readText(Charsets.UTF_8))
        for (index in 0 until candidates.length()) {
            val candidate = candidates.getJSONObject(index)
            candidate.put("start", (candidate.getDouble("start") + analysisStart).coerceIn(analysisStart, analysisEnd))
            candidate.put("end", (candidate.getDouble("end") + analysisStart).coerceIn(analysisStart, analysisEnd))
        }
        StudioStore.metric("scoreMs", SystemClock.elapsedRealtime() - scoreStarted)
        StudioStore.update("ready", "${candidates.length()} rekomendasi siap. Pilih atau edit rentang sebelum render.", mapOf(
            "segments" to segments, "candidates" to candidates, "language" to language, "transcriptRevision" to 3,
            "sourceDurationMs" to (duration * 1000).toLong(), "analysisStart" to analysisStart, "analysisEnd" to analysisEnd, "progress" to 100))
    }

    private fun render(source: File) {
        val duration = MediaTools.durationMs(source) / 1000.0
        val rangesJson = options.getJSONArray("ranges")
        require(rangesJson.length() in 1..12) { "Pilih 1–12 rentang." }
        val ranges = (0 until rangesJson.length()).map { index -> rangesJson.getJSONObject(index).let {
            StudioRange(it.getDouble("start"), it.getDouble("end"), it.optString("title", "Klip ${index+1}")).apply { validate(duration) }
        } }
        val (width, height) = RenderPolicy.dimensions(options.optString("aspect", "portrait"), options.optString("resolution", "720p"))
        val framing = options.optString("framing", "center")
        FramingPolicy.validate(framing)
        val burn = options.optBoolean("burnSubtitles", true)
        val document = StudioStore.data()
        val segmentsJson = document.optJSONArray("segments") ?: JSONArray()
        val segments = (0 until segmentsJson.length()).map { index -> segmentsJson.getJSONObject(index).let {
            TimedSubtitle(it.getDouble("start"), it.getDouble("end"), it.getString("text"))
        } }
        require(!burn || segments.isNotEmpty()) { "Transkripsikan video dahulu atau matikan subtitle." }
        val runId = UUID.randomUUID().toString()
        val root = File(StudioStore.directory(sourceId), "render-$runId").apply { check(mkdirs()) }
        temporaryRender = root
        val outputs = mutableListOf<Pair<File, String>>()
        val renderStarted = SystemClock.elapsedRealtime()
        var detectedFrames = 0; var sampledFrames = 0; var fallbackRanges = 0
        for ((index, range) in ranges.withIndex()) {
            stage("rendering", "Render rentang ${index+1}/${ranges.size}…", index * 100 / ranges.size)
            val file = File(root, "clip-${index+1}.mp4")
            val plan = if (framing == "follow") {
                FaceFollower(tools).plan(source, range, width, height, File(root, "focus-${index+1}.txt")) { progress ->
                    val message = "Mendeteksi wajah rentang ${index+1}/${ranges.size}: $progress%"
                    StudioStore.update(message = message, save = false)
                    notify(message, index * 100 / ranges.size)
                }.also {
                    detectedFrames += it.detectedFrames; sampledFrames += it.sampledFrames
                    if (it.detectedFrames == 0) fallbackRanges++
                }
            } else null
            var filter = FramingPolicy.filter(framing, width, height, plan?.commands)
            if (burn) {
                val subtitle = File(root, "clip-${index+1}.ass")
                subtitle.writeText(RenderPolicy.subtitleAss(segments, range, width, height), Charsets.UTF_8)
                filter += ",subtitles='${subtitle.absolutePath}':fontsdir=/system/fonts"
            }
            tools.ffmpeg(listOf("-y", "-v", "error", "-nostats", "-progress", "pipe:1",
                "-ss", RenderPolicy.number(range.start), "-i", source.absolutePath, "-t", RenderPolicy.number(range.end-range.start),
                "-map", "0:v:0", "-map", "0:a:0", "-vf", filter, "-af", "asetpts=PTS-STARTPTS",
                "-c:v", "libx264", "-preset", "ultrafast", "-crf", "23", "-threads", "4",
                "-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart", file.absolutePath)) { line ->
                if (line.startsWith("out_time_us=")) {
                    val seconds = line.substringAfter('=').toDoubleOrNull()?.div(1000000) ?: 0.0
                    val progress = ((index + (seconds / (range.end-range.start)).coerceIn(0.0, 1.0)) * 100 / ranges.size).toInt().coerceAtMost(99)
                    StudioStore.update(fields = mapOf("progress" to progress), save = false); notify("Merender klip", progress)
                }
            }
            MediaTools.durationMs(file)
            outputs.add(file to range.title)
        }
        if (options.optBoolean("combine") && outputs.size > 1) {
            stage("rendering", "Menggabungkan rentang terpilih…", 99)
            val list = File(root, "concat.txt").apply { writeText(outputs.joinToString("\n") { "file '${it.first.absolutePath}'" }) }
            val combined = File(root, "combined.mp4")
            tools.ffmpeg(listOf("-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", list.absolutePath, "-c", "copy", "-movflags", "+faststart", combined.absolutePath))
            MediaTools.durationMs(combined)
            outputs.forEach { it.first.delete() }; outputs.clear(); outputs.add(combined to "Gabungan ${ranges.size} rentang")
        }
        tools.checkCancelled()
        val clips = document.optJSONArray("clips") ?: JSONArray()
        for ((file, title) in outputs) clips.put(JSONObject().put("name", "$runId-${file.name}").put("title", title)
            .put("path", file.absolutePath).put("bytes", file.length()).put("durationMs", MediaTools.durationMs(file)).put("framing", framing))
        StudioStore.metric("renderMs", SystemClock.elapsedRealtime() - renderStarted)
        val warning = if (fallbackRanges > 0) " $fallbackRanges rentang tanpa wajah terdeteksi: memakai crop tengah." else ""
        StudioStore.update("ready", "${outputs.size} file klip selesai. Preview atau simpan ke HP.$warning", mapOf(
            "clips" to clips, "progress" to 100, "lastRanges" to rangesJson,
            "framingReport" to JSONObject().put("mode", framing).put("detectedFrames", detectedFrames).put("sampledFrames", sampledFrames)))
        temporaryRender = null
    }
}
