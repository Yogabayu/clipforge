package id.clipforge.clipforge_mobile

import android.content.Context
import org.json.JSONArray
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

/** One deletion at a time, sharing the native operation gate with download/render. */
object MediaDeletion {
    private val running = AtomicBoolean(false)
    fun busy() = running.get()
    fun acquire() { check(running.compareAndSet(false, true)) { "Penghapusan masih berjalan." } }
    fun release() { running.set(false) }

    fun download(context: Context, id: String): Long {
        DownloadStore.requireRecord(id)
        val source = MediaFileDeletion.sourceDirectory(context.filesDir, "downloads", id)
        val studio = MediaFileDeletion.sourceDirectory(context.filesDir, "studio", id)
        val bytes = MediaFileDeletion.remove(context.filesDir, source) + MediaFileDeletion.remove(context.filesDir, studio)
        DownloadStore.removeRecord(id)
        StudioStore.forget(id)
        return bytes
    }

    fun clip(context: Context, id: String, name: String): Long {
        val document = StudioStore.open(id)
        val clips = document.optJSONArray("clips") ?: JSONArray()
        val selected = (0 until clips.length()).map { clips.getJSONObject(it) }
            .firstOrNull { it.optString("name") == name } ?: error("Klip tidak ditemukan.")
        val file = MediaFileDeletion.clip(context.filesDir, id, selected.getString("path"))
        val batch = requireNotNull(file.parentFile)
        val remaining = JSONArray()
        for (index in 0 until clips.length()) {
            val item = clips.getJSONObject(index)
            if (item.optString("name") != name) remaining.put(item)
        }
        val batchStillUsed = (0 until remaining.length()).any {
            File(remaining.getJSONObject(it).getString("path")).canonicalFile.parentFile == batch
        }
        // Remove subtitle/face-command/concat leftovers when the last batch output goes.
        val bytes = MediaFileDeletion.remove(context.filesDir, if (batchStillUsed) file else batch)
        StudioStore.commitDeletedClips(remaining)
        return bytes
    }
}
