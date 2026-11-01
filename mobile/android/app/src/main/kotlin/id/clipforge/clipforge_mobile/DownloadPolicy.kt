package id.clipforge.clipforge_mobile

import java.net.URI

/** Never pass arbitrary URLs or user-provided command options to the engine. */
object DownloadPolicy {
    private val videoId = Regex("[A-Za-z0-9_-]{11}")
    private val hosts = setOf("youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com")

    fun canonicalUrl(input: String): String {
        val uri = try { URI(input.trim()) } catch (_: Exception) {
            throw IllegalArgumentException("URL YouTube tidak valid.")
        }
        require(uri.scheme in setOf("https", "http") && uri.userInfo == null && uri.port == -1) {
            "Gunakan URL video YouTube publik."
        }
        val host = uri.host?.lowercase()
        val parts = uri.path.orEmpty().trim('/').split('/')
        val id = when {
            host == "youtu.be" && parts.size == 1 -> parts[0]
            host in hosts && uri.path == "/watch" -> uri.rawQuery.orEmpty().split('&')
                .firstOrNull { it.startsWith("v=") }?.substringAfter("v=")
            host in hosts && parts.size == 2 && parts[0] in setOf("shorts", "embed") -> parts[1]
            else -> null
        }
        require(id != null && videoId.matches(id)) { "Masukkan tautan video tunggal atau Shorts YouTube." }
        return "https://www.youtube.com/watch?v=$id"
    }

    val formats = listOf(
        "bv[height<=720][ext=mp4][vcodec^=avc1]+ba[ext=m4a]/b[height<=720][ext=mp4][vcodec^=avc1]",
        "bv[height<=720][protocol^=m3u8][vcodec^=avc1]+ba[protocol^=m3u8][acodec^=mp4a]/b[height<=720][ext=mp4][vcodec^=avc1]"
    )

    fun canFallback(message: String): Boolean =
        listOf("HTTP Error 403", "Requested format is not available").any { message.contains(it, true) }

    fun safeLog(message: String): String = message
        .replace(Regex("https?://[^\\s]+"), "[URL]")
        .take(1200)
}
