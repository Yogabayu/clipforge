package id.clipforge.clipforge_mobile

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.content.FileProvider
import java.io.File

/** Handoff only: the receiving YouTube app owns account, details and upload confirmation. */
object YouTubeUpload {
    fun open(activity: Activity, file: File, title: String) {
        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.media", file)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "video/mp4"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_TITLE, title.take(100))
            putExtra(Intent.EXTRA_SUBJECT, title.take(100))
            clipData = ClipData.newRawUri("ClipForge video", uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val target = listOf("com.google.android.apps.youtube.creator", "com.google.android.youtube")
            .firstOrNull { activity.packageManager.resolveActivity(Intent(intent).setPackage(it), PackageManager.MATCH_DEFAULT_ONLY)?.activityInfo?.exported == true }
            ?: error("Pasang atau aktifkan YouTube/YouTube Studio yang mendukung berbagi video. Alternatif: Simpan ke HP lalu pilih video di aplikasi YouTube.")
        activity.startActivity(intent.setPackage(target))
    }
}
