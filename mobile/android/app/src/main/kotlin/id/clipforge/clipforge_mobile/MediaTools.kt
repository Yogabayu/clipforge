package id.clipforge.clipforge_mobile

import android.content.Context
import android.media.MediaExtractor
import android.media.MediaFormat
import java.io.File
import java.util.concurrent.CancellationException
import java.util.concurrent.atomic.AtomicBoolean

class MediaTools(private val context: Context, private val cancelled: AtomicBoolean) {
    @Volatile private var process: Process? = null
    fun cancel() { cancelled.set(true); process?.destroyForcibly() }
    fun checkCancelled() { if (cancelled.get() || Thread.currentThread().isInterrupted) throw CancellationException("Proses dibatalkan.") }

    fun ffmpeg(args: List<String>, onLine: (String) -> Unit = {}): String = execute("libffmpeg.so", args, onLine)

    fun recommend(input: File, output: File, top: Int, min: Double, max: Double) {
        val scripts = File(context.filesDir, "studio-scripts").apply { mkdirs() }
        for (name in listOf("scoring.py", "recommend.py")) {
            context.assets.open(name).use { from -> File(scripts, name).outputStream().use { from.copyTo(it) } }
        }
        execute("libpython.so", listOf(File(scripts, "recommend.py").absolutePath,
            input.absolutePath, output.absolutePath, top.toString(), min.toString(), max.toString()))
    }

    private fun execute(binary: String, args: List<String>, onLine: (String) -> Unit = {}): String {
        checkCancelled()
        val native = File(context.applicationInfo.nativeLibraryDir)
        val packages = File(context.noBackupFilesDir, "youtubedl-android/packages")
        val python = File(packages, "python/usr")
        val builder = ProcessBuilder(listOf(File(native, binary).absolutePath) + args).redirectErrorStream(true)
        builder.environment().apply {
            put("LD_LIBRARY_PATH", "${python.absolutePath}/lib:${File(packages, "ffmpeg/usr/lib").absolutePath}")
            put("PYTHONHOME", python.absolutePath)
            put("SSL_CERT_FILE", File(python, "etc/tls/cert.pem").absolutePath)
            put("TMPDIR", context.cacheDir.absolutePath)
        }
        val started = builder.start()
        process = started
        val tail = ArrayDeque<String>()
        try {
            checkCancelled()
            started.inputStream.bufferedReader().useLines { lines -> lines.forEach { line ->
                checkCancelled()
                if (tail.size >= 40) tail.removeFirst()
                tail.addLast(DownloadPolicy.safeLog(line))
                onLine(line)
            } }
            check(started.waitFor() == 0) { "$binary gagal:\n${tail.joinToString("\n").takeLast(1600)}" }
            checkCancelled()
            return tail.joinToString("\n")
        } finally {
            if (started.isAlive) started.destroyForcibly()
            process = null
        }
    }

    companion object {
        fun durationMs(file: File): Long {
            val extractor = MediaExtractor()
            try {
                extractor.setDataSource(file.absolutePath)
                var video = false; var audio = false; var duration = 0L
                for (index in 0 until extractor.trackCount) {
                    val format = extractor.getTrackFormat(index)
                    val mime = format.getString(MediaFormat.KEY_MIME).orEmpty()
                    video = video || mime.startsWith("video/"); audio = audio || mime.startsWith("audio/")
                    if (format.containsKey(MediaFormat.KEY_DURATION)) duration = maxOf(duration, format.getLong(MediaFormat.KEY_DURATION) / 1000)
                }
                check(video && audio && duration > 0) { "MP4 tidak memiliki video/audio/durasi lengkap." }
                return duration
            } finally { extractor.release() }
        }
    }
}
