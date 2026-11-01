package id.clipforge.clipforge_mobile

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.AtomicFile
import io.flutter.plugin.common.EventChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/** One owner for persisted state; Flutter only renders snapshots. No database. */
object DownloadStore {
    val activeStates = setOf("preparing", "extracting", "downloading", "merging", "validating", "cancelling")
    private val main = Handler(Looper.getMainLooper())
    private lateinit var disk: AtomicFile
    private var initialized = false
    private var sink: EventChannel.EventSink? = null
    private var current: JSONObject? = null
    private var history = JSONArray()
    private var engine = JSONObject().put("ready", false).put("message", "Menyiapkan engine lokal…")

    @Synchronized fun init(context: Context) {
        if (initialized) return
        disk = AtomicFile(File(context.filesDir, "downloads.json"))
        try {
            val saved = JSONObject(disk.openRead().bufferedReader().use { it.readText() })
            current = saved.optJSONObject("current")
            history = saved.optJSONArray("history") ?: JSONArray()
            if (busy()) current?.put("status", "interrupted")
                ?.put("message", "Proses terputus. Tekan coba ulang.")
        } catch (_: java.io.FileNotFoundException) {
            // Fresh installation.
        } catch (_: Exception) {
            engine.put("message", "Riwayat lokal tidak terbaca; engine akan diperiksa.")
        }
        initialized = true
        StudioStore.init(context)
    }

    @Synchronized fun listen(eventSink: EventChannel.EventSink?) {
        sink = eventSink
        publish()
    }

    @Synchronized fun snapshot(): Map<String, Any?> = mapOf(
        "engine" to toValue(engine), "current" to current?.let { toValue(it) },
        "history" to toValue(history), "studio" to toValue(JSONObject(StudioStore.snapshot()))
    )

    fun studioChanged() { synchronized(this) { publish() } }
    fun studioSnapshot(): Any? = synchronized(this) { toValue(JSONObject(StudioStore.snapshot())) }

    @Synchronized fun engineReady(version: String) {
        engine = JSONObject().put("ready", true).put("version", version)
            .put("message", "yt-dlp $version · QuickJS + EJS · FFmpeg")
        publish()
    }

    @Synchronized fun engineFailed(error: String) {
        engine = JSONObject().put("ready", false).put("message", DownloadPolicy.safeLog(error))
        publish()
    }

    @Synchronized fun busy(): Boolean = current?.optString("status") in activeStates

    @Synchronized fun begin(id: String, url: String) {
        check(!busy()) { "Masih ada download aktif." }
        check(engine.optBoolean("ready")) { "Engine belum siap." }
        current = JSONObject().put("id", id).put("url", url).put("title", "Video YouTube")
            .put("status", "preparing").put("progress", 0).put("message", "Menyiapkan download…")
            .put("createdAt", System.currentTimeMillis()).put("logs", JSONArray())
            .put("metrics", JSONObject()).put("engineVersion", engine.optString("version"))
        persist()
        publish()
    }

    @Synchronized fun update(status: String? = null, message: String? = null,
                             fields: Map<String, Any?> = emptyMap(), save: Boolean = true) {
        val job = current ?: return
        if (status != null) job.put("status", status)
        if (message != null) job.put("message", message)
        fields.forEach { (key, value) -> job.put(key, value) }
        if (save) persist()
        publish()
    }

    @Synchronized fun log(message: String) {
        val job = current ?: return
        val logs = job.optJSONArray("logs") ?: JSONArray()
        logs.put("${java.time.Instant.now()} ${DownloadPolicy.safeLog(message)}")
        while (logs.length() > 120) logs.remove(0)
        job.put("logs", logs)
    }

    @Synchronized fun metric(name: String, value: Long) {
        current?.getJSONObject("metrics")?.put(name, value)
    }

    @Synchronized fun complete(path: String, bytes: Long, durationMs: Long) {
        update("completed", "Video siap. Preview atau simpan ke HP.", mapOf(
            "path" to path, "bytes" to bytes, "durationMs" to durationMs, "progress" to 100
        ), save = false)
        val recent = JSONArray().put(JSONObject(current.toString()))
        for (index in 0 until history.length()) {
            val item = history.optJSONObject(index) ?: continue
            if (item.optString("id") != current?.optString("id")) recent.put(item)
        }
        history = recent
        persist()
        publish()
    }

    @Synchronized fun completedFile(context: Context, id: String): File {
        val candidates = (0 until history.length()).mapNotNull { history.optJSONObject(it) } + listOfNotNull(current)
        val job = candidates.firstOrNull { it.optString("id") == id && it.optString("status") == "completed" }
            ?: error("Hasil download tidak ditemukan.")
        val file = File(job.getString("path")).canonicalFile
        val root = File(context.filesDir, "downloads").canonicalFile
        check(file.toPath().startsWith(root.toPath()) && file.isFile) { "File video tidak tersedia." }
        return file
    }

    @Synchronized fun requireRecord(id: String) {
        check(current?.optString("id") == id || (0 until history.length()).any { history.optJSONObject(it)?.optString("id") == id }) {
            "Video tidak ditemukan dalam riwayat."
        }
    }

    @Synchronized fun removeRecord(id: String) {
        requireRecord(id)
        val previous = current; val previousHistory = history
        val kept = JSONArray()
        for (index in 0 until history.length()) {
            val item = history.getJSONObject(index)
            if (item.optString("id") != id) kept.put(item)
        }
        if (current?.optString("id") == id) current = null
        history = kept
        try { persist(strict = true) } catch (error: Exception) {
            current = previous; history = previousHistory; throw error
        }
        publish()
    }

    @Synchronized fun diagnosticText(): String = JSONObject().put("engine", engine)
        .put("device", "${android.os.Build.MANUFACTURER} ${android.os.Build.MODEL}; Android ${android.os.Build.VERSION.RELEASE}")
        .put("current", current).put("history", history).toString(2)

    private fun persist(strict: Boolean = false) {
        var output: java.io.FileOutputStream? = null
        try {
            output = disk.startWrite()
            output.write(JSONObject().put("current", current).put("history", history).toString().toByteArray())
            disk.finishWrite(output)
        } catch (error: Exception) {
            output?.let { disk.failWrite(it) }
            android.util.Log.e("ClipForge", "Cannot persist download state", error)
            if (strict) throw error
        }
    }

    private fun publish() {
        val event = snapshot()
        main.post { sink?.success(event) }
    }

    private fun toValue(value: Any?): Any? = when (value) {
        is JSONObject -> value.keys().asSequence().associateWith { toValue(value.opt(it)) }
        is JSONArray -> (0 until value.length()).map { toValue(value.opt(it)) }
        JSONObject.NULL -> null
        else -> value
    }
}
