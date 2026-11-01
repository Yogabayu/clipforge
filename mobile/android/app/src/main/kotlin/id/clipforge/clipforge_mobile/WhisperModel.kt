package id.clipforge.clipforge_mobile

import android.content.Context
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

object WhisperModel {
    const val name = "ggml-small-q5_1.bin"
    const val hash = "ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb"
    private const val url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/f281eb45af861ab5e5297d23694b7d46e090c02c/ggml-small-q5_1.bin"

    fun ensure(context: Context, tools: MediaTools, progress: (Int) -> Unit): File {
        val root = File(context.noBackupFilesDir, "whisper-models").apply { check(mkdirs() || isDirectory) }
        val file = File(root, name)
        if (file.isFile && checksum(file, tools) == hash) return file
        check(android.os.StatFs(root.absolutePath).availableBytes > 400L * 1024 * 1024) { "Butuh minimal 400 MB ruang kosong untuk model dan audio." }
        val temporary = File(root, "$name.part")
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = 20000; connection.readTimeout = 20000
        connection.setRequestProperty("User-Agent", "ClipForge-Mobile/0.3")
        try {
            check(connection.responseCode == 200) { "Unduh model gagal: HTTP ${connection.responseCode}" }
            var received = 0L; var last = -1
            connection.inputStream.use { input -> temporary.outputStream().use { output ->
                val buffer = ByteArray(65536)
                while (true) {
                    tools.checkCancelled()
                    val count = input.read(buffer); if (count < 0) break
                    output.write(buffer, 0, count); received += count
                    val percent = (received * 100 / 190085487).toInt().coerceAtMost(99)
                    if (percent != last) { last = percent; progress(percent) }
                }
            } }
            check(checksum(temporary, tools) == hash) { "Checksum model Whisper gagal. Unduh ulang." }
            java.nio.file.Files.move(temporary.toPath(), file.toPath(), java.nio.file.StandardCopyOption.REPLACE_EXISTING)
            progress(100)
            return file
        } finally { connection.disconnect(); temporary.delete() }
    }

    private fun checksum(file: File, tools: MediaTools): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(65536)
            while (true) {
                tools.checkCancelled()
                val count = input.read(buffer); if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }
}
