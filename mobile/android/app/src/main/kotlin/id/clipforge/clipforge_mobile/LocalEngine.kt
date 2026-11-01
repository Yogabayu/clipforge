package id.clipforge.clipforge_mobile

import android.content.Context
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.TimeUnit

object LocalEngine {
    const val version = "2026.10.26"
    private const val sha256 = "e51e69e89489f199530f13d32a4342da3ddb2cf34842f364603a066db05afbf3"
    private var ready = false

    @Synchronized fun initialize(context: Context) {
        if (ready) return
        try {
            YoutubeDL.init(context)
            FFmpeg.getInstance().init(context)
            val nativeDir = File(context.applicationInfo.nativeLibraryDir)
            for (name in listOf("libpython.so", "libqjs.so", "libffmpeg.so")) {
                check(File(nativeDir, name).canExecute()) { "$name tidak tersedia untuk ABI perangkat ini." }
            }
            val target = File(context.noBackupFilesDir, "youtubedl-android/yt-dlp/yt-dlp")
            if (!target.isFile || hash(target) != sha256) {
                val temporary = File(target.parentFile, "yt-dlp.pending")
                context.assets.open("yt-dlp-$version").use { input -> temporary.outputStream().use { input.copyTo(it) } }
                check(hash(temporary) == sha256) { "Checksum yt-dlp gagal." }
                java.nio.file.Files.move(temporary.toPath(), target.toPath(), java.nio.file.StandardCopyOption.REPLACE_EXISTING)
            }
            checkProcess(context, File(nativeDir, "libqjs.so"), listOf("-e", "console.log('clipforge-quickjs-ok')"), "clipforge-quickjs-ok")
            checkProcess(context, File(nativeDir, "libffmpeg.so"), listOf("-version"), "ffmpeg version")
            val response = YoutubeDL.execute(YoutubeDLRequest(emptyList()).addOption("--version"))
            check(response.out.trim() == version) { "Versi yt-dlp tidak cocok: ${response.out.trim()}" }
            ready = true
            DownloadStore.engineReady(version)
        } catch (error: Exception) {
            DownloadStore.engineFailed(error.message ?: error.javaClass.simpleName)
            throw error
        }
    }

    private fun checkProcess(context: Context, executable: File, arguments: List<String>, expected: String) {
        val builder = ProcessBuilder(listOf(executable.absolutePath) + arguments).redirectErrorStream(true)
        val packages = File(context.noBackupFilesDir, "youtubedl-android/packages")
        builder.environment()["LD_LIBRARY_PATH"] = listOf("python", "ffmpeg")
            .joinToString(":") { File(packages, "$it/usr/lib").absolutePath }
        // Drain output concurrently: FFmpeg's build configuration may exceed the pipe buffer.
        val process = builder.start()
        val output = StringBuffer()
        val reader = Thread {
            try {
                process.inputStream.bufferedReader().useLines { lines -> lines.forEach { if (output.length < 32000) output.append(it).append('\n') } }
            } catch (_: java.io.IOException) {
                // A timed-out/cancelled process can close its output while the reader drains it.
            }
        }.apply { isDaemon = true; start() }
        try {
            check(process.waitFor(15, TimeUnit.SECONDS)) { "${executable.name} self-test timeout." }
            reader.join(2000)
            check(!reader.isAlive && process.exitValue() == 0 && output.contains(expected)) {
                "${executable.name} self-test gagal: ${output.take(600)}"
            }
        } finally {
            if (process.isAlive) process.destroyForcibly()
        }
    }

    private fun hash(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(8192)
            while (true) { val count = input.read(buffer); if (count < 0) break; digest.update(buffer, 0, count) }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }
}
