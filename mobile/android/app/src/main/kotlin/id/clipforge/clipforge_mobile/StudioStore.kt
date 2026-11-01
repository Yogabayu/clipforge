package id.clipforge.clipforge_mobile

import android.content.Context
import android.util.AtomicFile
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/** Per-source JSON analysis, with one active native operation across the application. */
object StudioStore {
    private lateinit var context: Context
    private var current = JSONObject()
    private val active = setOf("model", "audio", "transcribing", "scoring", "rendering", "cancelling")

    fun init(app: Context) { context = app.applicationContext }
    @Synchronized fun busy() = current.optString("status") in active
    @Synchronized fun snapshot(): String = current.toString()
    @Synchronized fun currentId(): String = current.optString("id")
    @Synchronized fun data(): JSONObject = JSONObject(current.toString())

    fun forget(id: String) {
        synchronized(this) { if (currentId() == id) current = JSONObject() }
        DownloadStore.studioChanged()
    }

    fun commitDeletedClips(clips: JSONArray) {
        synchronized(this) {
            val previous = JSONObject(current.toString())
            current.put("clips", clips).put("message", "Klip dihapus dari penyimpanan ClipForge.")
            try { persist() } catch (error: Exception) { current = previous; throw error }
        }
        DownloadStore.studioChanged()
    }

    fun open(id: String): JSONObject {
        DownloadStore.completedFile(context, id)
        val result = synchronized(this) {
            check(!busy() || currentId() == id) { "Tunggu proses video lain selesai." }
            if (currentId() != id) {
                val file = AtomicFile(File(directory(id), "analysis.json"))
                current = try { JSONObject(file.openRead().bufferedReader().use { it.readText() }) }
                catch (_: java.io.FileNotFoundException) {
                    JSONObject().put("id", id).put("status", "idle").put("segments", JSONArray())
                        .put("candidates", JSONArray()).put("clips", JSONArray()).put("metrics", JSONObject())
                }
                if (busy()) current.put("status", "interrupted").put("message", "Proses terputus; silakan ulang analisis/render.")
            }
            JSONObject(current.toString())
        }
        DownloadStore.studioChanged()
        return result
    }

    fun begin(id: String, status: String, message: String) {
        check(!busy()) { "Masih ada proses aktif." }
        open(id)
        update(status, message, mapOf("progress" to 0, "metrics" to JSONObject()))
    }

    fun update(status: String? = null, message: String? = null, fields: Map<String, Any?> = emptyMap(), save: Boolean = true) {
        synchronized(this) {
            status?.let { current.put("status", it) }
            message?.let { current.put("message", DownloadPolicy.safeLog(it)) }
            fields.forEach { (key, value) -> current.put(key, value) }
            if (save) persist()
        }
        DownloadStore.studioChanged()
    }

    @Synchronized fun metric(name: String, milliseconds: Long) {
        val metrics = current.optJSONObject("metrics") ?: JSONObject().also { current.put("metrics", it) }
        metrics.put(name, milliseconds)
    }

    fun directory(id: String = currentId()): File {
        require(id.matches(Regex("[0-9a-f-]{36}"))) { "ID video tidak valid." }
        return File(context.filesDir, "studio/$id").apply { check(mkdirs() || isDirectory) }
    }

    fun clipFile(id: String, name: String): File {
        DownloadStore.completedFile(context, id)
        val state = if (currentId() == id) data() else JSONObject(AtomicFile(File(directory(id), "analysis.json")).openRead().bufferedReader().use { it.readText() })
        val clips = state.optJSONArray("clips") ?: JSONArray()
        val item = (0 until clips.length()).map { clips.getJSONObject(it) }.firstOrNull { it.optString("name") == name }
            ?: error("Klip belum selesai atau tidak ditemukan.")
        val file = File(item.getString("path")).canonicalFile
        check(file.toPath().startsWith(directory(id).canonicalFile.toPath()) && file.isFile) { "File klip tidak tersedia." }
        return file
    }

    private fun persist() {
        val file = AtomicFile(File(directory(), "analysis.json"))
        val output = file.startWrite()
        try { output.write(current.toString().toByteArray(Charsets.UTF_8)); file.finishWrite(output) }
        catch (error: Exception) { file.failWrite(output); throw error }
    }
}
