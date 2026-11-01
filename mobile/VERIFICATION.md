# Current installed artifact - 2026-11-01, version 0.5.0 / code 14

- ADB upgrade installation succeeded on Xiaomi 22021211RG (8586d536).
  Package version 0.5.0 / code 14 verified; normal launcher activity opened.
  No active service at update time; no uninstall/data deletion performed.
- APK: C:/Users/Mayang_/Downloads/ClipForge-0.5.0-arm64.apk, 74,322,900 bytes.
  SHA-256: aefb769ed31a958efdf9cc9fc214f88edc8fb63b5833e74aad59a0532fb66a9d.
  Normal entrypoint and bundled engine packaging checks pass.
- Includes responsive landscape editor, visible start/end timeline boundaries,
  and optional Auto Cut analysis window entered in minutes. FFmpeg extracts only
  that audio window; scoring timestamps map back to source time. Transcript cache
  reuse requires matching analysis bounds and language.
- Latest feature checks: analyzer clean, 30 Flutter tests passed before the new
  range contract test; all 5 studio contract tests then passed including range
  payloads. Android compileDebugKotlin succeeded. These are host checks, not
  proof of on-device window transcription or battery savings.
- User manual testing is pending. Earlier device proofs below apply to their
  explicitly named versions and do not establish 0.5.0 end-to-end correctness.

---

# Guided editor UX - 2026-10-31, version 0.4.6 / code 10

- Replaced one long mixed-purpose editor with three visible steps: Pilih klip,
  Atur video, Hasil. Manual and Auto Cut are distinct choices; advanced analysis
  options and source preview are collapsed in Auto Cut. Native engine unchanged.
- Marker selection opens settings first and explicitly replaces older selections
  when requested. Settings render only the visible picked list, never a hidden
  fallback after all selections are removed. Navigation/render action stays fixed.
- Auto Cut extraction keeps analysis controls separate from editor orchestration.
  EditorScreen stays below 750 lines; new focused widgets avoid growing a giant build method.
- Flutter analyzer clean; all 29 Flutter tests pass. Widget tests cover both manual
  marker bounds (with/without older selection), exact selected recommendation
  payloads, default ten recommendations, no rendering before settings, and widths
  320/360 px, including enlarged text at 320 px. Preview pauses on entry to
  settings; resolution dropdown expands within narrow fields. Screenshots use mocked source playback and recommendation data;
  they do not establish native download/render correctness for this version.
- Visual review images: build/review/editor-{manual,auto,settings,output,results}.png.
- ADB found no device on 2026-10-31. This UX version is not installed/device-tested.
  Earlier 0.4.5 device evidence below refers to the previous installed version.

- Release APK built with explicit lib/main.dart entrypoint; packaging and checksum
  checks pass. Downloads copy: C:/Users/Mayang_/Downloads/ClipForge-0.4.6-arm64.apk.
  Size: 74,278,816 bytes. SHA-256:
  f3922755ef3aeabf006aff927fcb75a15ec0347b18b403d627bb3c9be6a2c41d.
- First build overlapped Flutter tests and failed generated plugin registration.
  After tests finished, a standalone release build regenerated the normal plugin
  registrant and completed. No generated registrant was hand-edited.

---

# Device verification completed - 2026-10-30, version 0.4.5

User completed the manual installer update after USB verifier rejection.
ADB confirms version 0.4.5 / code 9 on Xiaomi 22021211RG, Android 14.

- Normal installed release UI used; no Flutter driver/integration-test APK.
- Opened existing 14:14 source; **Set awal** captured 0.00 s. Seeked paused source
  via its visible timeline, then **Set akhir** captured 8.80 s.
- Pressed **Render penanda ini** while an older selected range/output existed.
  New **Penanda manual / NEW** clip is 3.3 MB, displayed duration 0:08.
  Older 34.5 MB / 1:49 output remains visible; clip count now 2.
- Opened the newest clip's Preview and played to **0:08 / 0:08**. A UIAutomator
  dump during active playback timed out and reused stale XML; a fresh idle dump
  after completion confirmed playback reached the end. No app-code change needed.
- Evidence: `build/review/marker-device-bounds.json`,
  `marker-device-before-render.xml`, `marker-device-render-result.xml/.png`,
  and `marker-device-playback.xml`.
- Existing videos were not deleted. Only the just-created verified temporary APK
  at `/sdcard/Download/ClipForge-0.4.5-arm64.apk` was removed after installed-version
  and SHA checks, reclaiming 74,259,712 bytes. PC Downloads APK remains available.

Earlier pending/blocked status below records the attempt history and is resolved
by this successful manual update and device test.

---

# Mobile verification - 2026-10-29, version 0.4.5

## Current artifact and marker fix

## Device update attempt - 2026-10-30

Phone reconnected, package still 0.4.4 / code 8. Both streamed `adb install -r`
and normal push/no-streaming update were rejected by device verification:
`INSTALL_FAILED_VERIFICATION_FAILURE: Install not allowed for file:///data/app/vmdl...tmp`.
No uninstall or verifier/security-setting bypass attempted. User data retained.

Verified APK copied to `/sdcard/Download/ClipForge-0.4.5-arm64.apk`; phone SHA-256
matches the PC artifact. Manual Package Installer update requested from the user.
0.4.5 marker fix is not yet device-verified; wait for successful installation.


- Normal release APK 0.4.5 / code 9, ARM64, development-key signed.
- `C:/Users/Mayang_/Downloads/ClipForge-0.4.5-arm64.apk`, 74,259,712 bytes.
- SHA-256 `1651eeb183b15f99e809359deb8d86b40a2002eb839efb5988febed44aaeb785`.
- Signature, normal-entrypoint packaging and Downloads-copy checks passed.
- Root cause: Set awal/Set akhir changed only draft bounds; render sent the picked
  list. Empty list disabled render, while an older picked list could render stale
  bounds instead of the new markers.
- New preview-adjacent **Render penanda ini** sends exactly one marker range.
  **Tambahkan ke daftar** retains the explicit multi-range flow. The Output render
  button falls back to markers when no picked list exists; otherwise its label
  explicitly identifies the selected-list operation. Invalid bounds explain the
  one-second minimum, 600-second maximum, ordering and source bounds.
- Requests freeze their chosen list before asynchronous work; marker capture
  clamps to source duration. Render does not require preview initialization.
- New full-editor regression tests use a fake video platform but real editor
  callbacks/controller channel: seek to 3 s, Set awal, seek to 8 s, Set akhir,
  render markers and inspect exact 3..8 payload. Verified with empty and saved
  15..20 lists. Bottom button also checked for both cases. Tests failed before
  the fix, passed after. Bounds/disabled states covered separately.
- All 27 Flutter tests passed; analyzer clean after final test lint adjustment.
  Existing video_player_platform_interface 6.9.0 promoted to a direct dev-only
  dependency for the regression harness; no runtime version change.
- USB disconnected during build, so this APK was not yet installed/device-tested
  at this point. Waiting for the device to reconnect. No test APK was installed.

Older sections below are historical and superseded for current artifact details.

---

# Mobile verification - 2026-10-29, version 0.4.4

## Current artifact

- Normal standalone release APK 0.4.4 / code 8, ARM64, development-key signed.
- `C:/Users/Mayang_/Downloads/ClipForge-0.4.4-arm64.apk`, 74,257,760 bytes.
- SHA-256 `45df77e62265c3db23c3eb34e7e3f7882c31003666245b4514940b756489d834`.
- Signature, packaging and Downloads copy checks pass. Analyzer clean; 24 Flutter
  tests and 15 Kotlin tests passed. Three new Flutter tests cover the upload
  button, exact clip identity handoff and unavailable receiver error handling.

## YouTube handoff

Completed render cards now expose **Upload ke YouTube**. Native code resolves
only recorded clip IDs/paths and tries compatible, exported ACTION_SEND video/mp4
handlers in YouTube Studio, then YouTube. No arbitrary file path from Dart,
OAuth credential storage, YouTube Data API request, or automatic publishing.
The receiving app owns channel/account selection, title, privacy and confirmation.

- Content URI from a non-exported FileProvider, with temporary read permission
  in flags/ClipData. Packaged provider and resource XML checked with aapt: only
  the app-private studio folder is configured, no external/root filesystem path;
  YouTube/Studio package visibility queries are present. Evidence:
  `build/review/youtube-provider-proof.txt`. Obfuscated release XML resolved via
  resource table, rather than assumed source filenames.
- No extra video copy in ClipForge; keep the original clip until upload finishes.
- If no compatible app exists, shows install/enable or save-to-phone alternative.
- Phone was not connected during this update. APK not installed on the phone;
  external YouTube/Studio handoff and actual upload remain device acceptance
  checks. No video was uploaded or published during these tests.

Older versions below are historical; artifact hashes/paths below are superseded.

---

# Mobile verification - 2026-10-29, version 0.4.3

## Delivered

Normal release APK 0.4.3 / code 7 installed successfully on Xiaomi 22021211RG
(Android 14, ARM64) with `adb install -r`. Cold launch: 1,232 ms. No active
foreground processing service was present before updating.

- PC copy: `C:/Users/Mayang_/Downloads/ClipForge-0.4.3-arm64.apk`.
- 74,253,748 bytes; SHA-256
  `1516894b25f4a076beac84197b8c3e19d6e2c923badd0f85f9e8f40a1fd60e27`.
- Signature and packaging guard passed; Downloads copy hash matches source APK.
- Analyzer clean; 21 Flutter tests passed. Three deletion tests passed again after
  the final feedback/lint changes. All 15 Kotlin tests passed, zero skips.

## Delete behavior

- Current download and download history have **Hapus download**. Confirmation
  explicitly includes the source, transcript/analysis and all related render clips.
- Each render card has **Hapus klip**. It removes only that clip; when a batch has
  no outputs left, its subtitle/face-command/concat files are cleaned up too.
- Real app-private files are removed on the IO worker, deleted byte count returned,
  and current/history or clip JSON updated. Strict persistence errors propagate;
  metadata is retained for retry on a failed commit.
- Native gate and disabled UI prevent deletion during download/analysis/render.
  Source IDs must be recorded; filesystem policy restricts source UUID folders
  and recorded MP4 paths under their own render batch, rejects outside/root paths,
  supports Android filesDir aliases and never follows directory symlinks.
- Four new host filesystem tests delete real temporary bytes, verify sibling and
  unrelated files survive, check repeat/missing-file behavior, reject invalid
  paths and verify a symlink target sentinel remains intact. Symlink test ran
  successfully on this host, not skipped.
- Normal release phone UI: source-delete cascade dialog and per-clip dialog both
  inspected. **Cancel** selected in each; existing user videos were not deleted.
  Device screenshots/XML: `build/review/delete-source-dialog.*` and
  `build/review/delete-clip-dialog.*`. Actual byte deletion was tested in host
  temporary folders, not against existing user media on the phone.
- Previously exported gallery/Downloads copies are not tracked/deleted. Models
  and engine caches remain available. No database changes.

Older evidence below is historical; its APK hashes and version numbers are
superseded by this 0.4.3 section.

---

# Mobile verification - 2026-10-29, version 0.4.2

## Current delivered artifact

- Normal release APK, explicit `lib/main.dart`, version 0.4.2 / code 6, ARM64.
- PC Downloads: `C:/Users/Mayang_/Downloads/ClipForge-0.4.2-arm64.apk`.
- 74,247,092 bytes; SHA-256
  `4c9093d3d14d077548568352b2d5a120fdf2dbf91f84c8d4df8391614b2f9186`.
- Packaging guard passed; source APK and Downloads copy hashes match.
  Build script resolves the Windows Downloads known folder from the user registry
  and copies each verified build to a versioned filename there.

## Render UX changes

- Centered render progress modal covers the editor independent of list position.
  Native status/progress drives it, including face scanning and cancellation;
  accidental outside taps/back cannot dismiss it. Explicit cancel remains available.
- Modal closes when render is no longer active; no imperative dialog route push/pop.
- Latest successful render batch receives green NEW badges. Native run UUID in
  the existing clip name groups multi-output runs without new database/state files.
  Badge remains after reopening until a newer successful batch exists.
- Clip card extracted from the editor to keep progress and result UI separate.
- Analyzer clean. All 18 Flutter tests pass; four new checks cover live progress,
  dismissal/back/cancel/completion, small screens with enlarged text, render-batch
  grouping, NEW badges and preview interaction. Focused four tests passed again
  after the final modal layout adjustment.
- No native engine/database changes. No integration-test APK installed in this
  update. Physical device was not connected: new modal/badge behavior is verified
  by widget tests and release packaging, not a fresh phone test.

Older release/device evidence below remains historical; hashes and artifact
paths below are superseded by this 0.4.2 section.

---

# Mobile verification - 2026-10-29 (Asia/Jakarta), version 0.4.1

## Current delivered APK

Normal standalone **release** build, version 0.4.1 / code 5, installed with
`adb install -r` on Xiaomi 22021211RG, Android 14 ARM64.

- APK: `build/app/outputs/flutter-apk/app-release.apk`, 74,245,596 bytes (70.8 MiB).
- SHA-256: `482efa7c67a29efdbf8cc3663df3df87070a9f26658d5d6a9d7e78a34bdefc99`.
- Explicit target `lib/main.dart`, AOT release, development signing key;
  signature and packaging verifier pass. Phone Download copy has version/hash in its name.
- Blank launch reproduced before the fix: installed debug APK contained
  `integration_test/framing_test.dart` / `IntegrationTestWidgetsFlutterBinding`;
  launcher displayed an empty Android content view without the test driver.
- Delivery script `tool/build_apk.ps1` explicitly builds the normal main entrypoint.
  Packaging verifier rejects the integration binding signature in debug kernels
  and AOT payloads; this guard rejected the old test APK.
- Normal release cold-start via `am force-stop` then `am start -W`: **907 ms**,
  visible ClipForge form, local engine ready, original completed download shown.
  All host ADB connections terminated with `adb kill-server`, then reconnected:
  UI remained visible. No Flutter run/test driver used for these checks. Physical
  unplugging was not performed by the agent.
- Screenshot: `build/review/standalone-04.png`; UI XML before/after ADB disconnect
  retained under `build/review/standalone-04-*.xml`.

## Focus feature and proof

`Editor / Auto Cut > Output klip > Fokus gambar` now offers center crop (default),
follow person via face, and full frame over blurred background. Face detection
uses bundled ML Kit 16.1.7. It samples only selected ranges at 2 fps; initial
largest face, then nearest face position. Interpolated crop stays in frame;
face loss holds position for two seconds then returns to center. Entirely
undetected ranges report center fallback. It does not identify people or detect
active speakers/full bodies. Multiple faces and occlusion need visual review.

- Analyzer clean; **14 Flutter tests**, **11 Kotlin tests** pass. Includes
  Material ink regression, framing bridge contract, crop bounds, interpolation,
  explicit modes and final square-pixel aspect ratio.
- Physical `integration_test/framing_test.dart --no-uninstall`: **passed** (~26 s
  test body). Real dropdown selection verified; center, follow and blur each
  render 720x1280 MP4 and play. Follow detects faces in **9/9 sampled frames**.
  Blur render also uses burned subtitles. Log: `build/review/framing-04-integration.log`.
- Square pixel ratio normalized after scaling/compositing: fixes 720-pixel output
  appearing as ~715 pixels in the player due to rounded crop/sample-aspect ratio.
- Host FFmpeg gradient probe verifies actual crop movement/interpolation, not
  just successful process exit. Phone frame comparison visually inspected:
  `build/review/framing-comparison.png` (center / follow / blur).
- White Surface now gives ListTile its own Material ink surface. Reproduced
  failing widget regression before fix; full suite and physical dropdown pass after.
- Original download JSON unchanged and **14 pre-existing MP4 checksums match**
  before the final normal APK update. Backup: `build/review/pre-framing-04.tar`;
  result: `build/review/framing-04-data-proof.json`. Normal update preserved the
  original completed source visible in the release UI. No database changes.

Older version evidence follows for history; APK hashes/entrypoint instructions
below are superseded by this release section.

---

# Mobile verification - 2026-10-29 (Asia/Jakarta)

## Delivered 0.3.0 (code 3)

Normal UI APK installed successfully with `adb install -r` on the same Xiaomi
Android 14 ARM64 phone. APK: `build/app/outputs/flutter-apk/app-debug.apk`.

- 109,318,666 bytes; SHA-256 `bf4e8277205323548e85b93a85e417ed8521eebed26e9fa55e4d70eab86f016c`.
- Signature and static packaging checks passed. Copy also in the phone's Download folder.
- Generated ClipForge icon replaces the Flutter launcher icon at all five Android densities.
  Source image and generation prompt: `assets/branding/` (built-in image_gen).
- Subtitle ASS canvas explicitly matches output resolution. Font 27 px at 720p,
  bottom margin 6.5%, up to six words per cue. Segment subdivisions estimate
  word timing; no claim of forced word alignment. Phone-rendered frame inspected:
  `build/review/improvement-03-subtitle.png`.
- Transcript pencil dialog validates nonempty text; corrected words persist in
  app-private JSON and are used for subsequent renders. Existing MP4s need rendering again.
- Model upgraded from Base Q5_1 to multilingual Small Q5_1, with beam search width 5.
  Pinned model is 190,085,487 bytes; SHA-256
  `ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb`.
  Model download/checksum succeeded on the physical phone.

### Current proof

- Analyzer: no issues. 13 Flutter tests pass, including correction dialog validation
  and disposal. All 8 Kotlin tests pass on the final source; policy tests cover canvas sizing, short cues, clipping,
  sanitization, range validation, dimensions and locale-independent numbers.
- Physical `studio_test.dart --no-uninstall`: passed with the Small model. Existing
  short fixture reused; real local inference, recommendations without autorender,
  saved manual correction, two portrait subtitle renders, playback/seek and one
  combined landscape render all passed. Test log: `build/review/improvement-03-small-integration.log`.
- Short English fixture (19.064 s): model download/check 49,742 ms; audio extraction
  840 ms; inference 18,779 ms; scoring 251 ms; combined render 1,750 ms.
- Same fixture with Base + beam search took 4,374 ms inference and retained the
  incorrect word "hunts". Small recognizes "trunks" correctly. Both still mishear
  "in front of" as "one of"; manual correction is necessary. This single English
  fixture is not a general accuracy benchmark; Indonesian and long-video behavior
  remain manual acceptance items.
- Pre-update backup: `build/review/pre-improvement-03.tar` (private, ignored).
  Original download JSON unchanged, all seven pre-existing MP4 checksums match.
  Normal update succeeded without uninstall/recovery. Existing Base cache retained.
- USB stay-awake setting remains 2 (USB only).

Prior 0.2 evidence follows for historical context; its APK hash and Base timing
are superseded by the 0.3 details above.

---

# Mobile verification ? 2026-10-28 (Asia/Jakarta)

## Delivered

ClipForge Mobile **0.2.0 (code 2)**, Android ARM64, minimum API 26 / target API 36. Normal UI APK installed on Xiaomi 22021211RG (munch), Android 14.

APK: `build/app/outputs/flutter-apk/app-debug.apk`

- 109,266,486 bytes (~104.2 MiB), debug signed; APK signature verified.
- SHA-256: `eef7ff1589170e89f3378b8b85fb4f16ca59d4d72dd646b02ed456396dc60223`.
- Static packaging passed: ARM64 only, Python 3.12, yt-dlp 2026.10.26 + EJS, QuickJS, FFmpeg, Whisper JNI/C++ runtime, license texts and mobile recommendation script.
- Packaged `scoring.py` matches the canonical backend scorer byte for byte.

## Checks passed

- Flutter 3.47.8 stable / Dart 3.13.7; analyzer: no issues.
- 12 Flutter tests: platform state, blocked concurrent work, default 10 recommendations and explicit overrides, selected-range render contract, invalid ranges and narrow-screen downloader form.
- 7 Kotlin tests: URL/host policy, limited fallback, log redaction, finite bounded render ranges, subtitle clipping/rebasing, aspect/resolution and locale-independent FFmpeg numbers.
- 5 Python tests: default 10 and explicit top, non-overlap, short spoken video, silent/unscored fallback, option validation and maximum-duration padding.
- `integration_test/studio_test.dart --no-uninstall`: **All tests passed** on the physical phone (about 67 seconds in the test body). Includes real download of the short public fixture, local model load/inference, nonempty timestamped transcript, recommendations without automatic rendering, two selected portrait clips with burned subtitles, local playback/seek and one combined landscape output.
- Physical editor screens inspected: source preview/seek controls, analysis settings, recommendation, transcript panel, selected ranges and output settings rendered. Flutter logs reported zero UI exceptions/RenderFlex overflows during that inspection.
- Frame extracted from a phone-rendered portrait clip visually checked: correct 720x1280 crop and readable burned captions.

## Measured device scenario

Fixture: `jNQXAC9IVRw` (19.064 seconds, downloaded MP4 744,412 bytes). One recommendation is appropriate for this short source; the app does not fabricate 10 duplicate ranges.

| Phase | Milliseconds |
| --- | ---: |
| First model download/verification | 9,376 |
| Audio extraction | 384 |
| Whisper CPU transcription | 4,515 |
| Scoring | 363 |
| Analysis total | 14,701 |
| Final combined landscape render operation | 1,435 |

Whisper Base Q5_1 produced four transcript segments. Two selected 2-second ranges produced two portrait 720x1280 clips with audio and subtitles; another render produced one landscape 1280x720 combination, approximately four seconds. Three successful outputs remained in history. Automatic transcription is imperfect; the sample contains recognition errors, so review the transcript before exporting.

Earlier downloader-only device proof also passed: extraction 17.484 seconds, download phase 17.959 seconds, merge 0.373 seconds, total 35.932 seconds. Download-phase timing includes yt-dlp metadata/challenge extraction and is not pure CDN transfer time.

## Data and device handling

- Original app files backed up before integration testing (57,086,976-byte archive).
- Flutter's installer encountered `INSTALL_FAILED_VERIFICATION_FAILURE` while updating, then automatically uninstalled/reinstalled the old app. `--no-uninstall` prevents teardown removal but does not suppress this installer retry behavior.
- Normal UI APK subsequently built and installed successfully with direct `adb install -r`, without an automatic uninstall fallback.
- Original source video and current/history records restored from backup; SHA-256 of the restored video matched. Existing original records retained; the independent test fixture was added to history. Total two source-history entries after recovery.
- Cached Whisper model remained on the phone and its SHA-256 matched the pinned model hash.
- User requested USB stay-awake: `stay_on_while_plugged_in=2`, `mWakefulness=Awake`, `mStayOn=true` verified. Screen timeout/lock security settings were not changed.
- Backend/frontend source and SQL/database behavior unchanged; root README and the new mobile subtree carry this work. No npm build or PHP tests run.

## Practical limits / remaining manual checks

Real-device proof covers a short English source and 720p outputs. Still to validate manually: Indonesian transcript accuracy, long-video performance/thermal behavior, document-picker export for newly rendered clips, 1080p/1440p device encoding, real cancellation/timeout/process-death recovery and storage-full paths. Unit tests cover some validation boundaries; they do not replace these device scenarios. Face/person tracking and editable transcript correction are not implemented in this mobile version.

Build fixes: Kotlin incremental compilation disabled for cross-drive project/Pub Cache; explicit ARM64 filter retained; `.zip.so` engine archives preserved; Whisper FetchContent stays under the CMake build tree to avoid unquoted absolute object-output paths with spaces on Windows. Current Flutter-generated legacy Kotlin/DSL compatibility flags emit future-major-version deprecation notices but do not block the pinned toolchain.
