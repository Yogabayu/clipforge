# ClipForge Mobile

Standalone Android ARM64 clip editor. Flutter UI, Kotlin foreground service, bundled Python/yt-dlp + QuickJS/EJS + FFmpeg, and whisper.cpp CPU transcription. No backend server, Termux, API key, or database required.

## Mobile workflow (0.4.6)

- Paste a single public YouTube video/Shorts URL.
- Download up to 720p MP4 with video and audio; one active job.
- Background notification, progress, cancellation, bounded retries and compatible HLS fallback.
- Validate tracks/duration before marking complete; preview/play/pause/seek locally.
- Export MP4 or diagnostic JSON through Android's document picker.
- Restore completed history from app-private JSON; mark interrupted work for manual retry.

After downloading, open **Editor / Auto Cut**:

1. **Pilih klip**: choose **Manual** to mark Set awal / Set akhir on the source timeline. **Gunakan penanda ini** opens settings with that exact range; when an old selection exists, **Gunakan hanya penanda ini** explicitly replaces it. Add more manual ranges through **Tambahkan ke daftar**, or choose **Auto Cut**, run local transcription/recommendations, and check the clips you want. Default: 10 recommendations; count and duration limits live under **Atur rekomendasi**. Auto Cut's source preview is collapsible.
2. **Atur video**: review/edit/remove the chosen ranges, correct an available transcript, select aspect, resolution, face following / center crop / blur, subtitles, and optional concatenation. Each range must be 1-600 seconds, maximum 12. The sticky **Render N klip** button renders only this explicit list; an empty list cannot render. No render occurs while selecting markers.
3. **Hasil**: view completed clips, preview, save, upload through YouTube/Studio, or delete. After a render request is accepted, this step opens under the existing render-progress modal. **Buat klip lain** returns to selection. Existing completed clips can be reached directly through the Hasil step header.

Local multilingual Whisper Small Q5_1 (~190 MB) is downloaded once and verified by SHA-256. Choose the spoken language when known; no audio is uploaded. Short videos may return fewer recommendations. Analysis results still require manual selection and render confirmation.

Analysis does not auto-render MP4s. Transcript/model caches are reused; analysis and rendering run in the foreground service with cancellation. Audio inference reads 60-second chunks to bound RAM; the temporary PCM file still needs disk space proportional to source duration and is removed afterward. Source videos and previous successful clips remain available after a failed/cancelled operation.

Playlists, livestreams, authenticated/restricted videos, full-body tracking are outside this mobile version. Desktop/backend code and database behavior are unchanged.

## Toolchain

Tested host SDK: Flutter 3.47.8 / Dart 3.13.7, stable. Android minimum API 26, compile/target API 36, NDK 28.2.13676358, build-tools 37.0.0. Use Android Studio's JDK 21. Exact Dart package versions are in `pubspec.lock`; native wrapper/FFmpeg version is 0.18.1. Native Whisper uses CMake 3.22.1 and checksum-pinned whisper.cpp v1.9.5, fetched at build time from its official repository.

```powershell
cd mobile
flutter pub get
flutter analyze
flutter test
.\tool\build_apk.ps1
python tool/verify_apk.py
python tool/test_recommend.py
```

APK: `build/app/outputs/flutter-apk/app-release.apk`. Development-key signed release build for local installation; no production release signing configured. The engine APK contains native binaries and is larger than an ordinary Flutter UI APK.

## USB installation

Connect an ARM64 phone, enable USB debugging, accept the computer's RSA prompt, then:

```powershell
adb devices -l
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell am start -n id.clipforge.clipforge_mobile/.MainActivity
```

Use the full SDK `platform-tools/adb.exe` path if `adb` is absent from PATH. On first launch, allow notifications so progress remains visible. Android may still restrict background work under battery-saving policies; forcibly stopping the app interrupts the job.

## Device proof

```powershell
.\tool\device_smoke.ps1 -VideoUrl 'https://www.youtube.com/watch?v=jNQXAC9IVRw'
# Multiple devices: add -DeviceId '<adb serial>'
```

The downloader test waits for native engine self-tests, downloads the supplied public video, checks validated audio/video, then plays and seeks the local MP4. The SDK default uninstalls integration-test apps; always pass `--no-uninstall` to preserve app data.

Full pipeline test (uses a short public fixture, keeps existing downloads):

```powershell
flutter test integration_test/studio_test.dart --no-uninstall -d '<adb serial>'
```

This checks real local transcription, candidates without automatic rendering, two selected portrait clips with subtitles, playback/seek and a combined landscape output. Listen to the phone to confirm audible output. A desktop build, unit test or packaging check does not prove YouTube download on Android.

Manual acceptance: short video, Shorts, long video, Wi-Fi/mobile data, disconnected network, cancel during extraction/transfer/merge, retry, locked screen, app process killed/reopened, denied notifications, storage full and cancelled document picker. Verify an exported MP4 plays outside ClipForge. Test only content you may download.

## Bottleneck diagnostics

Expand **Detail & diagnostik**, or tap **Log** to save JSON. Metrics: `extractMs`, `downloadMs`, `mergeMs`, `validateMs`, `totalMs`, `averageBytesPerSecond`. Download time includes retries; merge is measured from the first merger/remux log. Progress follows the active stream, so it can reset between video and audio. Logs omit signed HTTP URLs.

`downloadMs` includes yt-dlp's second metadata/challenge extraction inside the download command; it is not pure network transfer time. `averageBytesPerSecond` is effective throughput for that entire phase. Separate metadata and download commands currently extract twice.

`403` or bot/login restrictions can depend on YouTube, video and network/IP. The APK reports the actual failure and preserves a bounded diagnostic log; it does not claim every YouTube video will always download. User cookies and login are not collected.

## Engine provenance / updates

Bundled yt-dlp **2026.10.26**, SHA-256 `e51e69e89489f199530f13d32a4342da3ddb2cf34842f364603a066db05afbf3`. Official executable includes EJS; wrapper AAR includes Python 3.12 and QuickJS. Initialization verifies the hash, executes a QuickJS self-test and checks yt-dlp's reported version. FFmpeg initializes before jobs start.

To restore the pinned engine asset, run `tool/fetch_engine.ps1`. Updating engine versions requires changing the pin/hash in that script, `LocalEngine.kt`, `tool/verify_apk.py`, notices and this README together, followed by rebuilding and rerunning the device test. No silent engine update or runtime remote-script download is enabled.

Source/license: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), [LICENSE](LICENSE). The GPL mobile subtree does not change the existing desktop/backend license. Native sources/build instructions are linked in the notices.

## Offline transcription provenance

whisper.cpp v1.9.5 source archive SHA-256: `ff1a9053feb509ff9d7729703355541ae9690073a6b1c40eb692c962e0dc1720`.

Model: [ggml-small-q5_1.bin, pinned revision](https://huggingface.co/ggerganov/whisper.cpp/blob/f281eb45af861ab5e5297d23694b7d46e090c02c/ggml-small-q5_1.bin), 59,707,625 bytes; SHA-256 `422f1ae452ade6f30a004d7e5c6a43195e4433bc370bf23fac9cc591f01a8898`. The model is stored in app-private no-backup storage; it is not bundled in the APK. Subsequent transcription works without the model server once that model is cached. Downloading a new YouTube source still requires internet.

Studio data is per-source `files/studio/<source-id>/analysis.json`; successful clip files live in generated render directories. No SQL database is introduced. The canonical `backend/scoring.py` is copied into Android assets by Gradle without modifying the backend file. Mobile window selection is in `recommend.py`.

Studio timing metrics are per operation: `modelMs`, `audioMs`, `transcribeMs`, `scoreMs`, `renderMs`, `totalMs`. A cached transcript can skip model/audio/transcription phases. Accuracy depends on speech/language/audio quality; transcript review is available before exporting.

## Subtitle and icon update (0.3.0)

Subtitle ASS canvas matches the output resolution; font size is 3.8% of the
short side (27 px at 720p), with a 6.5% bottom margin and up to six words per cue.
Cue subdivisions estimate timing within each Whisper segment; they are not
word-level alignment. Render again to update existing burned captions.

Whisper now uses beam search (width 5) instead of greedy decoding. This can take
longer; it does not guarantee correct words. Existing automatic transcripts from
0.2 are regenerated on the next analysis. Manual corrections are saved locally
and reused until the language changes or transcription is explicitly forced.
Recommendation text is refreshed on the next analysis.

Launcher icon source and generation prompt: `assets/branding/`.

## Focus modes (0.4.0)

In **Editor / Auto Cut > Atur video > Tampilan video > Fokus gambar**, choose:

- **Ikuti orang (wajah)**: bundled ML Kit face detector samples selected ranges at
  2 frames/second. Starts with the largest face, then follows the nearest face
  position. Crop coordinates interpolate between samples and stay inside the
  source. On face loss, holds position for two seconds, then returns toward center.
  If no face is found in a range, reports the center-crop fallback after rendering.
- **Crop tengah**: fixed center crop (default, preserving previous behavior).
- **Video utuh + blur**: keeps the entire source visible, centered over a blurred
  fill background, for either aspect ratio.

Focus follows visible faces, not full-body identity or active-speaker detection.
Profiles, occlusion, small faces and multiple people can cause target changes.
Review the rendered preview. Focus scanning adds work only in follow mode and
uses the same foreground notification/cancel mechanism. No camera permission or
media upload is needed. Existing MP4s must be rendered again.

## Standalone delivery and blank test builds

After any `flutter test integration_test/...` run, the installed APK is a test
harness and may open blank without the test driver. `--no-uninstall` preserves
app data but leaves that test APK installed. Always restore the normal app:

```powershell
.\tool\build_apk.ps1
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

The script explicitly builds `lib/main.dart` in release mode; the packaging
verifier rejects debug integration-test kernels. This prototype release still
uses the configured development signing key. Force-stop and launch the installed
app without `flutter run` or `flutter test` before calling it delivered. Do not
leave a test APK installed or share it with users.

## Render feedback (0.4.2)

Render progress appears in a centered modal above the editor, independent of
scroll position. It updates through native events, blocks accidental dismissal,
and offers cancellation. It closes when the native operation finishes, fails or
is cancelled. Face scanning uses an indeterminate indicator with its stage text.

The latest successful render batch has a green **NEW** badge on every output.
This includes separate clips from the same run and a combined output. The badge
remains after reopening the editor until a newer successful render replaces it;
failed/cancelled renders do not replace the latest batch.

`tool/build_apk.ps1` now also copies the verified APK to the current Windows
user's Downloads folder as `ClipForge-<version>-arm64.apk`, checking the copy's
SHA-256. This is the PC Downloads folder, separate from phone export actions.

## Delete videos (0.4.3)

- **Hapus klip** deletes that rendered MP4 and updates the list. When the last
  output in a batch is removed, its subtitle, face-command and concat files are
  cleaned up too. Source and other clips remain available.
- **Hapus download** deletes that source folder, its transcript/analysis and
  **all related rendered clips**. Permanent confirmation explicitly states this
  cascade before any deletion is sent to Android.
- Disabled/rejected while download, analysis or render is active. Disk work runs
  off the Android main thread under a single-operation gate.
- Real app-private files are removed, JSON history updated, and deleted bytes
  reported. Paths must belong to the recorded source/render directories;
  symlink directories are never followed. Model/engine caches remain available.
- Exported gallery/Downloads copies are separate: remove those in the gallery or
  file manager. Previously exported copies are not tracked by this app.

## YouTube upload handoff (0.4.4)

Each completed render card has **Upload ke YouTube**. Android hands the selected
MP4 to an installed, enabled app that accepts `ACTION_SEND` with `video/mp4`:
YouTube Studio is preferred when compatible, otherwise YouTube. If neither
accepts it, the UI explains installing/enabling an app or saving to the phone
and selecting the video manually.

This opens the receiving app; it does not use the YouTube Data API, log into
Google inside ClipForge, report upload completion or automatically publish.
Finish account/channel, title, privacy and confirmation in YouTube/Studio.
Do not delete the original clip until uploading has finished.

Recorded clip IDs are resolved by the native store; arbitrary paths from Dart
are not accepted. A non-exported FileProvider exposes only explicitly granted
content URIs under the studio folder, with temporary read permission. ClipForge makes no extra
MP4 copy and no new broad storage permission is requested.

## Marker selection (0.4.6)

After **Set awal** and **Set akhir**, press **Gunakan penanda ini** below the
preview to open **Atur video** with exactly those bounds. With an older selection,
**Gunakan hanya penanda ini** explicitly replaces that list. This action does not
start rendering. **Tambahkan ke daftar** opens the manual-range form for a batch.
The fixed **Lanjut: atur video** button keeps an existing selected list, or selects
the current markers when Manual mode has no list. Auto Cut requires a selection.

**Render N klip** renders only the list shown in Atur video. Removing all entries
disables render; return to Pilih klip to choose new bounds. Validation requires
end after start, at least one second, at most 600 seconds and bounds within the
source. Capture positions clamp to source duration. Render requests freeze the
chosen ranges before asynchronous work. Moving away from selection pauses the
source, and transcript correction includes its own expandable source preview.

## Auto Cut analysis window

Enable **Analisis rentang tertentu** in Auto Cut and enter **Mulai (menit)** /
**Selesai (menit)**; decimal minutes are accepted. With the switch off, analysis
covers the entire source. Bounds must stay inside the source and span at least
one second. FFmpeg seeks and extracts only this audio window before Whisper.
Scoring runs on that window, including silent-video fallbacks; subtitle and
candidate times are shifted back into the original video timeline. The current
transcript cache is reused only for the same language, revision and bounds;
changing bounds replaces the current analysis results after success. Previously
rendered MP4s remain. Reduced battery usage has not been measured on-device.
