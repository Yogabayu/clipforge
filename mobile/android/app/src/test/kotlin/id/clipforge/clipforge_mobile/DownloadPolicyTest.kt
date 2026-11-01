package id.clipforge.clipforge_mobile

import org.junit.Assert.*
import org.junit.Test

class DownloadPolicyTest {
    @Test fun canonicalizesSingleVideosAndRemovesUntrustedQueryOptions() {
        val expected = "https://www.youtube.com/watch?v=BaW_jenozKc"
        listOf("https://youtu.be/BaW_jenozKc?si=secret", "https://m.youtube.com/watch?v=BaW_jenozKc&list=PL123",
            "https://www.youtube.com/shorts/BaW_jenozKc", "https://youtube.com/embed/BaW_jenozKc").forEach {
            assertEquals(expected, DownloadPolicy.canonicalUrl(it))
        }
    }

    @Test fun rejectsForeignHostsPlaylistsAndMalformedInput() {
        listOf("--exec touch", "file:///etc/passwd", "https://youtube.com.evil.test/watch?v=BaW_jenozKc",
            "https://youtube.com/playlist?list=abc", "https://youtu.be/short", "https://user@youtube.com/watch?v=BaW_jenozKc",
            "https://youtube.com:443/watch?v=BaW_jenozKc").forEach {
            assertThrows(IllegalArgumentException::class.java) { DownloadPolicy.canonicalUrl(it) }
        }
    }

    @Test fun fallbackDoesNotRetryAuthenticationOrUnavailableVideo() {
        assertTrue(DownloadPolicy.canFallback("HTTP Error 403: Forbidden"))
        assertTrue(DownloadPolicy.canFallback("Requested format is not available"))
        assertFalse(DownloadPolicy.canFallback("Sign in to confirm your age"))
        assertFalse(DownloadPolicy.canFallback("Video unavailable"))
    }

    @Test fun diagnosticsRedactSignedUrls() {
        assertEquals("Download failed [URL] retry", DownloadPolicy.safeLog("Download failed https://cdn.test/file?token=secret retry"))
    }
}
