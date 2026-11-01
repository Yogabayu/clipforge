package id.clipforge.clipforge_mobile

import java.io.File
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.SimpleFileVisitor
import java.nio.file.FileVisitResult
import java.nio.file.attribute.BasicFileAttributes

/** Delete only verified app-owned paths; never traverse directory symlinks. */
object MediaFileDeletion {
    private val uuid = Regex("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")

    fun sourceDirectory(files: File, area: String, id: String): File {
        require(area in setOf("downloads", "studio") && uuid.matches(id)) { "Lokasi video tidak valid." }
        return owned(files, File(files.canonicalFile, "$area/$id"))
    }

    fun clip(files: File, id: String, path: String): File {
        val root = sourceDirectory(files, "studio", id)
        // Android may expose filesDir through /data/user/0 while canonical paths use /data/data.
        val logicalRoot = File(files.absoluteFile, "studio/$id").toPath().normalize()
        val requested = File(path).absoluteFile.toPath().normalize()
        val candidate = if (requested.startsWith(logicalRoot)) root.toPath().resolve(logicalRoot.relativize(requested)).toFile() else File(path)
        val file = owned(root, candidate)
        val batch = requireNotNull(file.parentFile) { "Folder klip tidak valid." }
        require(file.extension == "mp4" && batch.parentFile == root &&
            batch.name.startsWith("render-") && uuid.matches(batch.name.removePrefix("render-"))) { "Lokasi klip tidak valid." }
        require(!file.exists() || file.isFile) { "Klip bukan file video." }
        return file
    }

    private fun owned(root: File, candidate: File): File {
        val base = root.canonicalFile.toPath()
        val logical = candidate.absoluteFile.toPath().normalize()
        val actual = candidate.canonicalFile.toPath()
        require(actual.startsWith(base) && actual != base && actual == logical) { "Penghapusan di luar folder video ditolak." }
        return actual.toFile()
    }

    fun remove(files: File, target: File): Long {
        val checked = owned(files, target).toPath()
        if (!Files.exists(checked, java.nio.file.LinkOption.NOFOLLOW_LINKS)) return 0
        var bytes = 0L
        Files.walkFileTree(checked, object : SimpleFileVisitor<Path>() {
            override fun visitFile(file: Path, attrs: BasicFileAttributes): FileVisitResult {
                val size = if (attrs.isSymbolicLink) 0 else attrs.size()
                Files.delete(file); bytes += size
                return FileVisitResult.CONTINUE
            }
            override fun postVisitDirectory(dir: Path, error: java.io.IOException?): FileVisitResult {
                if (error != null) throw error
                Files.delete(dir)
                return FileVisitResult.CONTINUE
            }
        })
        return bytes
    }
}
