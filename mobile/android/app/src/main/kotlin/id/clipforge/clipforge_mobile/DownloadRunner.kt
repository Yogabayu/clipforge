package id.clipforge.clipforge_mobile

import android.content.Context
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.StatFs
import android.os.SystemClock
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLException
import com.yausername.youtubedl_android.YoutubeDLRequest
import org.json.JSONObject
import java.io.File
import java.util.concurrent.CancellationException
import java.util.concurrent.atomic.AtomicBoolean

/** Blocking pipeline runs on the service's worker, never on the platform channel. */
class DownloadRunner(
    private val context: Context,
    private val id: String,
    private val url: String,
    private val notify: (String, Int) -> Unit
) : MobileTask {
    private val cancelled = AtomicBoolean(false)
    private val root = File(context.filesDir, "downloads/$id")
    private var lastEvent = 0L
    private var lastLog = 0L
    private var mergeStarted = 0L

    override fun cancel() {
        cancelled.set(true)
        DownloadStore.update("cancelling", "Membatalkan download…")
        YoutubeDL.destroyProcessById(id)
    }

    private fun checkCancelled() {
        if (cancelled.get() || Thread.currentThread().isInterrupted) throw CancellationException()
    }

    override fun run() {
        val started = SystemClock.elapsedRealtime()
        try {
            checkCancelled()
            LocalEngine.initialize(context)
            check(root.mkdirs() || root.isDirectory) { "Folder download tidak dapat dibuat." }
            check(StatFs(root.absolutePath).availableBytes > 128L * 1024 * 1024) { "Ruang penyimpanan kurang dari 128 MB." }
            DownloadStore.log("engine=${LocalEngine.version}; QuickJS/EJS; max=720p; abi=${android.os.Build.SUPPORTED_ABIS.joinToString()}")
            stage("extracting", "Membaca informasi YouTube…")
            val metadataStarted = SystemClock.elapsedRealtime()
            val metadataRequest = request().addOption("--dump-single-json").addOption("--skip-download")
                .addOption("-f", DownloadPolicy.formats.joinToString("/"))
            val metadataResponse = YoutubeDL.execute(metadataRequest, id, true) { _, _, line -> record(line) }
            checkCancelled()
            val jsonLine = metadataResponse.out.lineSequence().lastOrNull { it.trimStart().startsWith("{") }
                ?: error("Metadata video tidak tersedia.")
            val metadata = JSONObject(jsonLine)
            require(!metadata.optBoolean("is_live") && metadata.optString("live_status") !in setOf("is_upcoming", "post_live")) {
                "Live atau video yang belum selesai belum didukung."
            }
            val duration = metadata.optDouble("duration", 0.0)
            val selectedSize = metadata.optLong("filesize", metadata.optLong("filesize_approx", 0L))
            // Reserve room for separate streams plus the merged output when size is known.
            if (selectedSize > 0) check(StatFs(root.absolutePath).availableBytes > selectedSize * 2 + 64L * 1024 * 1024) {
                "Ruang penyimpanan tidak cukup untuk download dan merge."
            }
            DownloadStore.metric("extractMs", SystemClock.elapsedRealtime() - metadataStarted)
            DownloadStore.update(fields = mapOf("title" to metadata.optString("title", "Video YouTube"),
                "sourceDurationMs" to (duration * 1000).toLong()))
            val transferStarted = SystemClock.elapsedRealtime()
            for ((attempt, format) in DownloadPolicy.formats.withIndex()) {
                checkCancelled()
                stage("downloading", if (attempt == 0) "Mengunduh video dan audio…" else "Mencoba format HLS kompatibel…")
                val download = request().addOption("-f", format)
                    .addOption("-o", File(root, "source.%(ext)s").absolutePath)
                    .addOption("--merge-output-format", "mp4")
                    .addOption("--remux-video", "mp4")
                    .addOption("--newline").addOption("--no-color")
                    .addOption("--no-mtime").addOption("--continue")
                    .addOption("--concurrent-fragments", 4)
                try {
                    val response = YoutubeDL.execute(download, id, true) { progress, eta, line ->
                        if (cancelled.get()) return@execute
                        record(line)
                        val now = SystemClock.elapsedRealtime()
                        val merging = line.startsWith("[Merger]") || line.startsWith("[VideoRemuxer]")
                        if (merging && mergeStarted == 0L) {
                            mergeStarted = now
                            stage("merging", "Menggabungkan video dan audio…")
                        }
                        if (now - lastEvent > 350) {
                            lastEvent = now
                            DownloadStore.update(fields = mapOf("progress" to progress.coerceIn(0f, 100f).toDouble(),
                                "etaSeconds" to eta, "transfer" to DownloadPolicy.safeLog(line)), save = false)
                            notify(if (mergeStarted > 0) "Menggabungkan audio/video" else "Mengunduh 720p", progress.toInt())
                        }
                    }
                    checkCancelled()
                    record(response.err)
                    break
                } catch (error: YoutubeDLException) {
                    checkCancelled()
                    if (attempt == DownloadPolicy.formats.lastIndex || !DownloadPolicy.canFallback(error.message.orEmpty())) throw error
                    DownloadStore.log("Fallback: ${error.message}")
                    // A different format must never reuse fragments from the failed format.
                    root.listFiles()?.forEach { file -> check(file.delete()) { "File sementara terkunci: ${file.name}" } }
                }
            }
            val transferFinished = SystemClock.elapsedRealtime()
            DownloadStore.metric("downloadMs", (if (mergeStarted > 0) mergeStarted else transferFinished) - transferStarted)
            DownloadStore.metric("mergeMs", if (mergeStarted > 0) transferFinished - mergeStarted else 0)
            checkCancelled()
            stage("validating", "Memeriksa video, audio, dan durasi…")
            val file = File(root, "source.mp4")
            check(file.isFile && file.length() > 0) { "MP4 hasil download tidak ditemukan." }
            val validationStarted = SystemClock.elapsedRealtime()
            val durationMs = validate(file)
            checkCancelled()
            DownloadStore.metric("validateMs", SystemClock.elapsedRealtime() - validationStarted)
            DownloadStore.metric("totalMs", SystemClock.elapsedRealtime() - started)
            DownloadStore.metric("averageBytesPerSecond", file.length() * 1000 / (transferFinished - transferStarted).coerceAtLeast(1))
            DownloadStore.log("Validated MP4: video + audio, ${file.length()} bytes, ${durationMs}ms")
            // Keep only the validated MP4; fragments cannot appear as completed downloads.
            root.listFiles()?.filter { it != file }?.forEach { it.delete() }
            DownloadStore.complete(file.absolutePath, file.length(), durationMs)
        } catch (error: Exception) {
            val wasCancelled = cancelled.get() || error is CancellationException || error is InterruptedException || error is YoutubeDL.CanceledException
            DownloadStore.metric("totalMs", SystemClock.elapsedRealtime() - started)
            DownloadStore.log("${error.javaClass.simpleName}: ${error.message}")
            DownloadStore.update(if (wasCancelled) "cancelled" else "failed",
                if (wasCancelled) "Download dibatalkan. Tekan coba ulang untuk mulai lagi." else friendlyError(error))
            root.listFiles()?.forEach { it.delete() }
            root.delete()
        }
    }

    private fun request(): YoutubeDLRequest = YoutubeDLRequest(url)
        .addOption("--ignore-config").addOption("--no-playlist")
        .addOption("--socket-timeout", 20).addOption("--retries", 3)
        .addOption("--fragment-retries", 3).addOption("--extractor-retries", 2)

    private fun stage(status: String, message: String) {
        checkCancelled()
        DownloadStore.log("stage=$status")
        DownloadStore.update(status, message)
        notify(message, -1)
    }

    private fun record(line: String) {
        if (line.isBlank() || line.trimStart().startsWith("{")) return
        val now = SystemClock.elapsedRealtime()
        if (!line.startsWith("[download]") || now - lastLog > 1500) {
            lastLog = now
            DownloadStore.log(line)
        }
    }

    private fun validate(file: File): Long {
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(file.absolutePath)
            var video = false
            var audio = false
            var durationUs = 0L
            for (index in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(index)
                val mime = format.getString(MediaFormat.KEY_MIME).orEmpty()
                if (mime.startsWith("video/")) video = true
                if (mime.startsWith("audio/")) audio = true
                if (format.containsKey(MediaFormat.KEY_DURATION)) durationUs = maxOf(durationUs, format.getLong(MediaFormat.KEY_DURATION))
            }
            check(video && audio && durationUs > 0) { "MP4 gagal validasi: video/audio/durasi tidak lengkap." }
            return durationUs / 1000
        } finally { extractor.release() }
    }

    private fun friendlyError(error: Exception): String {
        val detail = DownloadPolicy.safeLog(error.message ?: error.javaClass.simpleName)
        return when {
            detail.contains("403") -> "YouTube menolak akses (403). Coba jaringan/video lain. Detail tersedia di log."
            detail.contains("Sign in", true) || detail.contains("private", true) -> "Video meminta login atau dibatasi. Pilih video publik."
            detail.contains("No space left", true) -> "Penyimpanan penuh. Kosongkan ruang lalu coba ulang."
            detail.contains("timed out", true) || detail.contains("network", true) -> "Jaringan terputus atau timeout. Periksa koneksi lalu coba ulang."
            else -> detail.takeLast(600)
        }
    }
}
