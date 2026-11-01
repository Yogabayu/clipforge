# Mobile engine notices

Mobile source and combined APK are distributed under GPL-3.0 (see `LICENSE`) because the bundled Android engine is GPL-3.0. The existing desktop/backend project retains its existing license.

| Component | Pinned version / source | License |
| --- | --- | --- |
| youtubedl-android library and FFmpeg AAR | [0.18.1](https://github.com/yausername/youtubedl-android/tree/0.18.1) | GPL-3.0; native packages retain their own notices |
| yt-dlp Python executable | [2026.10.26](https://github.com/yt-dlp/yt-dlp/releases/tag/2026.10.26) | Unlicense; bundled dependencies retain their licenses |
| QuickJS | Bundled in library 0.18.1; [upstream](https://github.com/bellard/quickjs) | MIT |
| yt-dlp EJS | Bundled in the pinned yt-dlp executable; [source](https://github.com/yt-dlp/ejs) | ISC |
| Python | 3.12 runtime bundled by library 0.18.1; [source](https://github.com/python/cpython/tree/3.12) | PSF and included notices |
| FFmpeg | Bundled in FFmpeg AAR 0.18.1; [build instructions](https://github.com/yausername/youtubedl-android/blob/0.18.1/BUILD_FFMPEG.md) | LGPL/GPL according to included codecs/configuration |
| Flutter / video_player | Exact versions in `pubspec.lock` | BSD-style; registered Flutter license page |
| whisper.cpp / ggml | [v1.9.5](https://github.com/ggml-org/whisper.cpp/tree/v1.9.5), checksum-pinned source in CMake | MIT |
| Whisper Small Q5_1 model | [Converted model](https://huggingface.co/ggerganov/whisper.cpp/blob/f281eb45af861ab5e5297d23694b7d46e090c02c/ggml-small-q5_1.bin); [Whisper source/license](https://github.com/openai/whisper) | MIT |

License texts in `assets/licenses/` are bundled and available through the app's information button. Engine wrappers and upstream code are unmodified; the original bundled yt-dlp is replaced at initialization by the checksum-verified executable in Android assets. Its zip also includes dependency license texts. See upstream build instructions for corresponding native sources. Keep these notices and supply corresponding source when redistributing the GPL APK.

yt-dlp SHA-256: `e51e69e89489f199530f13d32a4342da3ddb2cf34842f364603a066db05afbf3`.

Face following (0.4.0): `com.google.mlkit:face-detection:16.1.7`, bundled model.
[Integration documentation](https://developers.google.com/ml-kit/vision/face-detection/android),
[ML Kit terms](https://developers.google.com/ml-kit/terms). Google components
retain their own terms and notices; the mobile source license does not relicense
third-party SDK binaries or models.
