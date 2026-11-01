"""Static packaging proof only. Does not claim successful YouTube/device execution."""
from __future__ import annotations

import hashlib
import io
import json
import sys
import zipfile
from pathlib import Path

ENGINE_VERSION = "2026.10.26"
ENGINE_SHA256 = "e51e69e89489f199530f13d32a4342da3ddb2cf34842f364603a066db05afbf3"


def verify(path: Path) -> dict:
    with zipfile.ZipFile(path) as apk:
        names = set(apk.namelist())
        for entry in ("assets/flutter_assets/kernel_blob.bin", "lib/arm64-v8a/libapp.so"):
            if entry in names and b"IntegrationTestWidgetsFlutterBinding" in apk.read(entry):
                raise ValueError("Integration-test APK must not be delivered; rebuild with --target lib/main.dart")
        required = {
            "lib/arm64-v8a/libflutter.so", "lib/arm64-v8a/libpython.so",
            "lib/arm64-v8a/libpython.zip.so", "lib/arm64-v8a/libqjs.so",
            "lib/arm64-v8a/libffmpeg.so", "lib/arm64-v8a/libffmpeg.zip.so",
            "lib/arm64-v8a/libclipforge_whisper.so", "lib/arm64-v8a/libc++_shared.so",
            "assets/scoring.py", "assets/recommend.py",
            "assets/flutter_assets/assets/licenses/whisper.cpp.txt",
            f"assets/yt-dlp-{ENGINE_VERSION}",
            "assets/flutter_assets/assets/licenses/youtubedl-android.txt",
        }
        missing = required - names
        if missing:
            raise ValueError(f"Missing APK entries: {sorted(missing)}")
        scoring = Path(__file__).resolve().parents[2] / 'backend/scoring.py'
        if apk.read('assets/scoring.py') != scoring.read_bytes():
            raise ValueError('Bundled scoring.py differs from the canonical backend scorer')
        other_abis = {name.split('/')[1] for name in names if name.startswith('lib/') and name.count('/') == 2} - {'arm64-v8a'}
        if other_abis:
            raise ValueError(f"Unexpected ABI payload: {sorted(other_abis)}")
        engine = apk.read(f"assets/yt-dlp-{ENGINE_VERSION}")
        if hashlib.sha256(engine).hexdigest() != ENGINE_SHA256:
            raise ValueError("Bundled yt-dlp checksum mismatch")
        with zipfile.ZipFile(io.BytesIO(engine)) as executable:
            if f"__version__ = '{ENGINE_VERSION}'" not in executable.read('yt_dlp/version.py').decode():
                raise ValueError("yt-dlp version mismatch")
            for solver in ['core.min.js', 'lib.min.js']:
                if not executable.read(f'yt_dlp_ejs/yt/solver/{solver}'):
                    raise ValueError(f'Missing EJS solver {solver}')
        with zipfile.ZipFile(io.BytesIO(apk.read('lib/arm64-v8a/libpython.zip.so'))) as python:
            if not any(name.startswith('usr/lib/libpython3.12') for name in python.namelist()):
                raise ValueError('Expected bundled Python 3.12 runtime')
    return {"apk": str(path.resolve()), "bytes": path.stat().st_size,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "engine": ENGINE_VERSION, "abi": "arm64-v8a",
            "packaging": "passed", "physical_device_download": "not established by this check"}


if __name__ == '__main__':
    apk_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1] / 'build/app/outputs/flutter-apk/app-release.apk'
    print(json.dumps(verify(apk_path), indent=2))
