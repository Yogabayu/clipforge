package id.clipforge.clipforge_mobile

import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.nio.file.Files

class MediaFileDeletionTest {
    @get:Rule val temporary = TemporaryFolder()
    private val id = "bc7a1200-0000-4000-8000-000000000001"
    private val run = "ac7a1200-0000-4000-8000-000000000001"

    @Test fun deletingSourceTreesFreesRealBytesAndKeepsOtherMedia() {
        val files = temporary.newFolder("files")
        val source = MediaFileDeletion.sourceDirectory(files, "downloads", id).apply { mkdirs() }
        val studio = MediaFileDeletion.sourceDirectory(files, "studio", id).apply { mkdirs() }
        File(source, "video.mp4").writeBytes(ByteArray(17))
        File(studio, "render-$run").mkdirs()
        File(studio, "render-$run/clip-1.mp4").writeBytes(ByteArray(23))
        val keep = File(files, "downloads/other/video.mp4").apply { requireNotNull(parentFile).mkdirs(); writeText("keep") }
        assertEquals(40L, MediaFileDeletion.remove(files, source) + MediaFileDeletion.remove(files, studio))
        assertFalse(source.exists()); assertFalse(studio.exists()); assertEquals("keep", keep.readText())
        assertEquals(0L, MediaFileDeletion.remove(files, source))
    }

    @Test fun clipDeletionKeepsSiblingsAndLastBatchCleanupRemovesSidecars() {
        val files = temporary.newFolder("files")
        val root = MediaFileDeletion.sourceDirectory(files, "studio", id)
        val batch = File(root, "render-$run").apply { mkdirs() }
        val first = File(batch, "clip-1.mp4").apply { writeBytes(ByteArray(11)) }
        val second = File(batch, "clip-2.mp4").apply { writeBytes(ByteArray(13)) }
        File(batch, "clip-1.ass").writeBytes(ByteArray(5))
        assertEquals(11L, MediaFileDeletion.remove(files, MediaFileDeletion.clip(files, id, first.path)))
        assertTrue(second.exists()); assertTrue(batch.exists())
        assertEquals(18L, MediaFileDeletion.remove(files, batch))
        assertFalse(batch.exists())
    }

    @Test fun malformedIdsRootDeletionAndOutsideFilesAreRejected() {
        val files = temporary.newFolder("files")
        val outside = temporary.newFile("outside.mp4").apply { writeText("safe") }
        assertThrows(IllegalArgumentException::class.java) { MediaFileDeletion.sourceDirectory(files, "downloads", "../other") }
        assertThrows(IllegalArgumentException::class.java) { MediaFileDeletion.remove(files, files) }
        assertThrows(IllegalArgumentException::class.java) { MediaFileDeletion.remove(files, outside) }
        assertThrows(IllegalArgumentException::class.java) { MediaFileDeletion.clip(files, id, outside.path) }
        assertEquals("safe", outside.readText())
    }

    @Test fun directorySymlinksNeverDeleteTheirTargets() {
        val files = temporary.newFolder("files")
        val outside = temporary.newFolder("outside")
        val sentinel = File(outside, "keep.mp4").apply { writeText("safe") }
        val source = MediaFileDeletion.sourceDirectory(files, "downloads", id).apply { mkdirs() }
        try { Files.createSymbolicLink(File(source, "linked").toPath(), outside.toPath()) }
        catch (error: Exception) { org.junit.Assume.assumeNoException("Host cannot create symlinks", error) }
        MediaFileDeletion.remove(files, source)
        assertEquals("safe", sentinel.readText())
    }
}
