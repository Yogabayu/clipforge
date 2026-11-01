package id.clipforge.clipforge_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import java.util.concurrent.Executors

class DownloadService : Service() {
    private val worker = Executors.newSingleThreadExecutor()
    private var runner: MobileTask? = null
    @Volatile private var workerThread: Thread? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        DownloadStore.init(this)
        getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(CHANNEL, "Download ClipForge", NotificationManager.IMPORTANCE_LOW)
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == CANCEL) { cancel(); return START_NOT_STICKY }
        if (runner != null) return START_NOT_STICKY
        val operation = intent?.action.orEmpty()
        val id = intent?.getStringExtra("id")
        val url = intent?.getStringExtra("url")
        if (id == null || url == null) { stopSelf(); return START_NOT_STICKY }
        running = true
        try {
            val notification = notification("Menyiapkan download…", -1)
            if (Build.VERSION.SDK_INT >= 29) startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
            else startForeground(NOTIFICATION_ID, notification)
            wakeLock = (getSystemService(POWER_SERVICE) as PowerManager).newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK, "ClipForge:download"
            ).apply { acquire(6 * 60 * 60 * 1000L) }
            val notify: (String, Int) -> Unit = { message, progress ->
                getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification(message, progress))
            }
            runner = if (operation in setOf("analyze", "render")) {
                StudioRunner(this, id, operation, org.json.JSONObject(intent.getStringExtra("options") ?: "{}"), notify)
            } else DownloadRunner(this, id, url, notify)
            worker.execute {
                workerThread = Thread.currentThread()
                try { runner?.run() } finally {
                    workerThread = null
                    android.os.Handler(mainLooper).post {
                        runner = null
                        running = false
                        wakeLock?.takeIf { it.isHeld }?.release()
                        stopForeground(STOP_FOREGROUND_REMOVE)
                        stopSelf(startId)
                    }
                }
            }
        } catch (error: Exception) {
            running = false
            if (operation in setOf("analyze", "render")) StudioStore.update("failed", error.message ?: "Service gagal dimulai.")
            else DownloadStore.update("failed", error.message ?: "Foreground service gagal dimulai.")
            wakeLock?.takeIf { it.isHeld }?.release()
            stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun cancel() {
        runner?.cancel()
        workerThread?.interrupt()
    }

    // Android 15+ limits background dataSync services. Persist a terminal state on timeout.
    override fun onTimeout(startId: Int, fgsType: Int) {
        cancel()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        if (runner != null) cancel()
        worker.shutdownNow()
        wakeLock?.takeIf { it.isHeld }?.release()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun notification(message: String, progress: Int): Notification {
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        val cancel = PendingIntent.getService(this, 1, Intent(this, DownloadService::class.java).setAction(CANCEL), PendingIntent.FLAG_IMMUTABLE)
        return Notification.Builder(this, CHANNEL).setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("ClipForge").setContentText(message).setContentIntent(open)
            .setOngoing(true).setOnlyAlertOnce(true)
            .setProgress(100, progress.coerceIn(0, 100), progress < 0)
            .addAction(Notification.Action.Builder(null, "Batal", cancel).build()).build()
    }

    companion object {
        @Volatile var running = false
            private set
        const val CANCEL = "id.clipforge.CANCEL"
        private const val CHANNEL = "clipforge_downloads"
        private const val NOTIFICATION_ID = 41
    }
}
