package id.clipforge.clipforge_mobile

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val io = Executors.newSingleThreadExecutor()
    private var exportResult: MethodChannel.Result? = null
    private var exportFile: File? = null
    private var exportText: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        DownloadStore.init(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "clipforge/downloads")
            .setMethodCallHandler(::handle)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "clipforge/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) { DownloadStore.listen(events) }
                override fun onCancel(arguments: Any?) { DownloadStore.listen(null) }
            })
        initialize()
    }

    private fun initialize() {
        io.execute {
            try { LocalEngine.initialize(applicationContext) } catch (_: Exception) {
                // Engine failure is delivered through the state stream; UI offers retry.
            }
        }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "snapshot" -> result.success(DownloadStore.snapshot())
                "initialize" -> { initialize(); result.success(null) }
                "start" -> {
                    checkIdle()
                    val url = DownloadPolicy.canonicalUrl(call.argument<String>("url").orEmpty())
                    val id = UUID.randomUUID().toString()
                    DownloadStore.begin(id, url)
                    if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 12)
                    }
                    try {
                        startForegroundService(Intent(this, DownloadService::class.java).putExtra("id", id).putExtra("url", url))
                    } catch (error: Exception) {
                        DownloadStore.update("failed", error.message ?: "Service gagal dimulai.")
                        throw error
                    }
                    result.success(id)
                }
                "cancel" -> {
                    if (DownloadStore.busy() || StudioStore.busy()) startService(Intent(this, DownloadService::class.java).setAction(DownloadService.CANCEL))
                    result.success(null)
                }
                "saveVideo" -> {
                    val id = requireNotNull(call.argument<String>("id"))
                    val file = DownloadStore.completedFile(this, id)
                    export(file, null, "ClipForge-${id.take(8)}.mp4", "video/mp4", result)
                }
                "saveDiagnostics" -> export(null, DownloadStore.diagnosticText(),
                    "ClipForge-diagnostics.json", "application/json", result)
                "studio" -> {
                    check(!MediaDeletion.busy()) { "Tunggu penghapusan selesai." }
                    StudioStore.open(requireNotNull(call.argument<String>("id")))
                    result.success(DownloadStore.studioSnapshot())
                }
                "editTranscript" -> {
                    checkIdle()
                    val id = requireNotNull(call.argument<String>("id"))
                    StudioStore.open(id)
                    val index = requireNotNull(call.argument<Int>("index"))
                    val text = requireNotNull(call.argument<String>("text")).trim()
                    require(text.isNotEmpty() && text.length <= 2000) { "Teks harus 1–2000 karakter." }
                    val segments = StudioStore.data().getJSONArray("segments")
                    require(index in 0 until segments.length()) { "Segmen tidak tersedia." }
                    segments.getJSONObject(index).put("text", text)
                    StudioStore.update(message = "Koreksi tersimpan. Render ulang untuk menerapkan subtitle.", fields = mapOf("segments" to segments, "transcriptRevision" to 3))
                    result.success(null)
                }
                "analyze", "render" -> {
                    checkIdle()
                    val id = requireNotNull(call.argument<String>("id"))
                    DownloadStore.completedFile(this, id)
                    val options = org.json.JSONObject(call.arguments as Map<*, *>)
                    StudioStore.begin(id, if (call.method == "analyze") "model" else "rendering", "Menyiapkan proses lokal…")
                    try {
                        startForegroundService(Intent(this, DownloadService::class.java).setAction(call.method)
                            .putExtra("id", id).putExtra("url", "local").putExtra("options", options.toString()))
                    } catch (error: Exception) {
                        StudioStore.update("failed", error.message ?: "Service gagal dimulai."); throw error
                    }
                    result.success(null)
                }
                "saveClip" -> {
                    val id = requireNotNull(call.argument<String>("id"))
                    val name = requireNotNull(call.argument<String>("name"))
                    export(StudioStore.clipFile(id, name), null, "ClipForge-$name", "video/mp4", result)
                }
                "openYouTubeUpload" -> {
                    checkIdle()
                    check(exportResult == null) { "Selesaikan dialog simpan dahulu." }
                    val id = requireNotNull(call.argument<String>("id"))
                    val name = requireNotNull(call.argument<String>("name"))
                    val file = StudioStore.clipFile(id, name)
                    YouTubeUpload.open(this, file, call.argument<String>("title") ?: "ClipForge")
                    result.success(null)
                }
                "deleteDownload", "deleteClip" -> {
                    checkIdle()
                    check(exportResult == null) { "Selesaikan dialog simpan dahulu." }
                    val id = requireNotNull(call.argument<String>("id"))
                    val name = if (call.method == "deleteClip") requireNotNull(call.argument<String>("name")) else null
                    MediaDeletion.acquire()
                    try { io.execute {
                        val outcome = try {
                            Result.success(if (name == null) MediaDeletion.download(applicationContext, id)
                                else MediaDeletion.clip(applicationContext, id, name))
                        } catch (error: Exception) {
                            Result.failure<Long>(error)
                        } finally { MediaDeletion.release() }
                        runOnUiThread { outcome.fold(
                            onSuccess = { result.success(it) },
                            onFailure = { result.error("CLIPFORGE", it.message ?: "Penghapusan gagal.", null) }) }
                    } } catch (error: Exception) {
                        MediaDeletion.release(); throw error
                    }
                }
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error("CLIPFORGE", error.message ?: error.javaClass.simpleName, null)
        }
    }

    private fun checkIdle() {
        check(!MediaDeletion.busy() && !DownloadService.running && !DownloadStore.busy() && !StudioStore.busy()) { "Tunggu proses aktif selesai dahulu." }
    }

    private fun export(file: File?, text: String?, name: String, mime: String, result: MethodChannel.Result) {
        check(!MediaDeletion.busy()) { "Tunggu penghapusan selesai." }
        check(exportResult == null) { "Selesaikan dialog simpan sebelumnya." }
        exportResult = result
        exportFile = file
        exportText = text
        try {
            startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = mime
                putExtra(Intent.EXTRA_TITLE, name)
            }, 42)
        } catch (error: Exception) {
            exportResult = null; exportFile = null; exportText = null
            throw error
        }
    }

    @Deprecated("Android activity result bridge used by FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 42) return
        val result = exportResult ?: return
        val file = exportFile
        val text = exportText
        exportResult = null; exportFile = null; exportText = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { result.success(false); return }
        io.execute {
            try {
                contentResolver.openOutputStream(uri, "wt").use { output ->
                    checkNotNull(output) { "Lokasi simpan tidak dapat dibuka." }
                    if (file != null) file.inputStream().use { it.copyTo(output) }
                    else output.write(requireNotNull(text).toByteArray(Charsets.UTF_8))
                }
                runOnUiThread { result.success(true) }
            } catch (error: Exception) {
                runOnUiThread { result.error("EXPORT", error.message, null) }
            }
        }
    }

    override fun onDestroy() {
        exportResult?.error("CLOSED", "Dialog simpan terputus. Coba ulang.", null)
        exportResult = null
        io.shutdown()
        super.onDestroy()
    }
}
