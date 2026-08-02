from __future__ import annotations

import argparse
import json
import math
import re
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable, Literal

import imageio_ffmpeg
from rich.console import Console
from rich.table import Table
from slugify import slugify
from yt_dlp import YoutubeDL

from scoring import score_window


console = Console()


@dataclass
class TranscriptSegment:
    start: float
    end: float
    text: str


@dataclass
class ClipCandidate:
    index: int
    start: float
    end: float
    duration: float
    score: int
    title: str
    reason: str
    text: str
    score_breakdown: dict[str, int]

CropMode = Literal["center", "person"]
YUNET_MODEL_PATH = Path(__file__).resolve().parent / "models" / "face_detection_yunet_2023mar.onnx"

TRANSCRIPT_REPLACEMENTS = {
    r"\binkam\b": "income",
    r"\bin kam\b": "income",
    r"\bcoin mass\b": "coin emas",
    r"\bkoin mass\b": "koin emas",
    r"\bfiat namis\b": "Vietnamese",
    r"\bfilipin\b": "Filipina",
    r"\bsilvernya\b": "silver-nya",
    r"\bdolarnya\b": "dolar-nya",
    r"\bsoftware- and wealth\b": "sovereign wealth",
    r"\bsoftware and wealth\b": "sovereign wealth",
    r"\bterperakap\b": "terperangkap",
    r"\bhana kan\b": "menggunakan",
    r"\bpengatahuan\b": "pengetahuan",
    r"\bbarang-barang\b": "bareng-bareng",
    r"\bdimasa\b": "di masa",
    r"\bribuk\b": "ribu",
    r"\bseraksud\b": "seratus",
    r"\bseris\b": "series",
    r"\bmelawangkan\b": "meluangkan",
    r"\bmenyerahanakan\b": "menyederhanakan",
}


def run(command: list[str], cwd: Path | None = None) -> None:
    process = subprocess.run(command, cwd=cwd, text=True)
    if process.returncode != 0:
        raise RuntimeError(f"Command failed with exit code {process.returncode}: {' '.join(command)}")


def ffmpeg_path() -> str:
    return imageio_ffmpeg.get_ffmpeg_exe()


def make_even(value: float, minimum: int) -> int:
    rounded = max(minimum, int(round(value)))
    return rounded if rounded % 2 == 0 else rounded + 1


def clamp_even(value: float, minimum: int, maximum: int) -> int:
    bounded = max(minimum, min(maximum, int(round(value))))
    if bounded % 2:
        bounded -= 1
    return max(minimum, min(maximum, bounded))


def detect_person_focus_x(video_path: Path, clip: ClipCandidate) -> tuple[float, tuple[int, int]] | None:
    try:
        import cv2
    except Exception as exc:
        console.print(f"[yellow]Person crop unavailable:[/yellow] {exc}")
        return None

    capture = cv2.VideoCapture(str(video_path.resolve()))
    if not capture.isOpened():
        return None

    width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT))
    if width <= 0 or height <= 0:
        capture.release()
        return None

    duration = max(0.1, clip.end - clip.start)
    sample_count = min(12, max(4, int(duration // 8)))
    if sample_count == 1:
        offsets = [duration / 2]
    else:
        step = duration / (sample_count + 1)
        offsets = [step * (index + 1) for index in range(sample_count)]

    hog = cv2.HOGDescriptor()
    hog.setSVMDetector(cv2.HOGDescriptor_getDefaultPeopleDetector())
    face_cascade = cv2.CascadeClassifier(str(Path(cv2.data.haarcascades) / "haarcascade_frontalface_default.xml"))
    profile_cascade = cv2.CascadeClassifier(str(Path(cv2.data.haarcascades) / "haarcascade_profileface.xml"))
    yunet = None
    if YUNET_MODEL_PATH.exists() and hasattr(cv2, "FaceDetectorYN_create"):
        yunet = cv2.FaceDetectorYN_create(
            str(YUNET_MODEL_PATH),
            "",
            (320, 320),
            0.35,
            0.3,
            5000,
        )

    face_weighted_sum = 0.0
    face_total_weight = 0.0
    person_weighted_sum = 0.0
    person_total_weight = 0.0

    for offset in offsets:
        capture.set(cv2.CAP_PROP_POS_MSEC, (clip.start + offset) * 1000)
        ok, frame = capture.read()
        if not ok:
            continue

        resize_scale = min(1.0, 720 / max(frame.shape[:2]))
        if resize_scale < 1:
            resized = cv2.resize(frame, None, fx=resize_scale, fy=resize_scale, interpolation=cv2.INTER_AREA)
        else:
            resized = frame

        gray = cv2.cvtColor(resized, cv2.COLOR_BGR2GRAY)
        face_detections: list[tuple[float, float, float]] = []
        person_detections: list[tuple[float, float, float]] = []

        if yunet is not None:
            resized_height, resized_width = resized.shape[:2]
            yunet.setInputSize((resized_width, resized_height))
            _, faces = yunet.detect(resized)
            if faces is not None:
                for face in faces:
                    x, _, w, h = face[:4]
                    confidence = float(face[-1])
                    center_x = (x + w / 2) / resize_scale
                    face_detections.append((center_x, max(w, h) / resize_scale, confidence * 3.0))

        faces = face_cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5, minSize=(36, 36))
        for x, y, w, h in faces:
            center_x = (x + w / 2) / resize_scale
            face_detections.append((center_x, max(w, h) / resize_scale, 2.0))

        profiles = profile_cascade.detectMultiScale(gray, scaleFactor=1.08, minNeighbors=4, minSize=(34, 34))
        for x, y, w, h in profiles:
            center_x = (x + w / 2) / resize_scale
            face_detections.append((center_x, max(w, h) / resize_scale, 1.8))

        flipped_gray = cv2.flip(gray, 1)
        flipped_profiles = profile_cascade.detectMultiScale(
            flipped_gray,
            scaleFactor=1.08,
            minNeighbors=4,
            minSize=(34, 34),
        )
        resized_width = resized.shape[1]
        for x, y, w, h in flipped_profiles:
            original_x = resized_width - x - w
            center_x = (original_x + w / 2) / resize_scale
            face_detections.append((center_x, max(w, h) / resize_scale, 1.8))

        people, weights = hog.detectMultiScale(
            resized,
            winStride=(8, 8),
            padding=(16, 16),
            scale=1.05,
        )
        for index, (x, _, w, _) in enumerate(people):
            confidence = float(weights[index]) if len(weights) > index else 1.0
            center_x = (x + w / 2) / resize_scale
            person_detections.append((center_x, w / resize_scale, max(0.25, confidence)))

        if face_detections:
            center_x, box_width, confidence = max(face_detections, key=lambda item: item[1] * item[2])
            weight = box_width * confidence
            face_weighted_sum += (center_x / width) * weight
            face_total_weight += weight
        elif person_detections:
            center_x, box_width, confidence = max(person_detections, key=lambda item: item[1] * item[2])
            weight = box_width * confidence
            person_weighted_sum += (center_x / width) * weight
            person_total_weight += weight

    capture.release()
    if face_total_weight > 0:
        return face_weighted_sum / face_total_weight, (width, height)
    if person_total_weight > 0:
        return person_weighted_sum / person_total_weight, (width, height)
    if face_total_weight <= 0 and person_total_weight <= 0:
        return None


def vertical_crop_filter(video_path: Path, clip: ClipCandidate, crop_mode: CropMode) -> str:
    center_filter = "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1"
    if crop_mode == "center":
        return center_filter

    focus = detect_person_focus_x(video_path, clip)
    if focus is None:
        console.print(f"[yellow]No person detected for clip {clip.index}; using center crop.[/yellow]")
        return center_filter

    focus_x, (source_width, source_height) = focus
    scale = max(1080 / source_width, 1920 / source_height)
    scaled_width = make_even(source_width * scale, 1080)
    scaled_height = make_even(source_height * scale, 1920)
    crop_x = clamp_even((focus_x * scaled_width) - 540, 0, scaled_width - 1080)
    crop_y = clamp_even((scaled_height - 1920) / 2, 0, scaled_height - 1920)
    console.print(f"[green]Person crop[/green] clip {clip.index}: focus x={focus_x:.2f}, crop x={crop_x}")
    return f"scale={scaled_width}:{scaled_height},crop=1080:1920:{crop_x}:{crop_y},setsar=1"


def seconds_to_stamp(seconds: float, srt: bool = False) -> str:
    seconds = max(0, seconds)
    millis = int(round((seconds - math.floor(seconds)) * 1000))
    whole = int(math.floor(seconds))
    h = whole // 3600
    m = (whole % 3600) // 60
    s = whole % 60
    sep = "," if srt else "."
    return f"{h:02}:{m:02}:{s:02}{sep}{millis:03}"


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def save_json(path: Path, payload) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")


def clean_transcript_text(text: str) -> str:
    cleaned = re.sub(r"\s+", " ", text).strip()
    cleaned = cleaned.replace(" ,", ",").replace(" .", ".").replace(" ?", "?").replace(" !", "!")
    for pattern, replacement in TRANSCRIPT_REPLACEMENTS.items():
        cleaned = re.sub(pattern, replacement, cleaned, flags=re.IGNORECASE)
    return cleaned.strip()


def fetch_metadata(url: str) -> dict:
    ydl_opts = {
        "quiet": True,
        "no_warnings": True,
        "noplaylist": True,
    }
    with YoutubeDL(ydl_opts) as ydl:
        return sanitize_metadata(ydl.extract_info(url, download=False))


def download_video(url: str, work_dir: Path, force: bool = False) -> tuple[Path, dict]:
    info_path = work_dir / "metadata.json"
    existing = sorted(work_dir.glob("source.*"))
    if existing and info_path.exists() and not force:
        return existing[0], load_json(info_path)

    ydl_opts = {
        "format": (
            "bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/"
            "bestvideo[height<=1080]+bestaudio/"
            "best[height<=1080]/best"
        ),
        "outtmpl": str(work_dir / "source.%(ext)s"),
        "merge_output_format": "mp4",
        "noplaylist": True,
        "quiet": True,
        "noprogress": True,
        "no_warnings": True,
        "ffmpeg_location": ffmpeg_path(),
    }

    work_dir.mkdir(parents=True, exist_ok=True)
    with YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=True)
        file_path = Path(ydl.prepare_filename(info))

    if not file_path.exists():
        downloaded = sorted(work_dir.glob("source.*"))
        if not downloaded:
            raise FileNotFoundError("Downloaded video was not found.")
        file_path = downloaded[0]

    save_json(info_path, sanitize_metadata(info))
    return file_path, sanitize_metadata(info)


def sanitize_metadata(info: dict) -> dict:
    keys = ["id", "title", "uploader", "duration", "webpage_url", "ext"]
    return {key: info.get(key) for key in keys}


def extract_audio(video_path: Path, audio_path: Path, force: bool = False, limit_seconds: float | None = None) -> Path:
    if audio_path.exists() and not force:
        return audio_path

    audio_path.parent.mkdir(parents=True, exist_ok=True)
    command = [
        ffmpeg_path(),
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-i",
        str(video_path),
        "-vn",
        "-ac",
        "1",
        "-ar",
        "16000",
        "-c:a",
        "pcm_s16le",
    ]
    if limit_seconds:
        command.extend(["-t", f"{limit_seconds:.3f}"])
    command.append(str(audio_path))
    run(command)
    return audio_path


def transcribe(audio_path: Path, transcript_path: Path, model_name: str, language: str, force: bool = False) -> list[TranscriptSegment]:
    if transcript_path.exists() and not force:
        return [
            TranscriptSegment(
                start=float(item["start"]),
                end=float(item["end"]),
                text=clean_transcript_text(item["text"]),
            )
            for item in load_json(transcript_path)
        ]

    from faster_whisper import WhisperModel

    console.print(f"[bold]Loading model:[/bold] {model_name}")
    model = WhisperModel(model_name, device="cpu", compute_type="int8")
    segments, info = model.transcribe(
        str(audio_path),
        language=language,
        vad_filter=True,
        beam_size=1,
        best_of=1,
    )

    rows: list[TranscriptSegment] = []
    for segment in segments:
        text = clean_transcript_text(segment.text)
        if text:
            rows.append(TranscriptSegment(float(segment.start), float(segment.end), text))

    save_json(transcript_path, [asdict(item) for item in rows])
    console.print(f"[green]Transcribed[/green] {len(rows)} segments. Detected language: {getattr(info, 'language', language)}")
    return rows


def first_sentence(text: str, max_words: int = 8) -> str:
    cleaned = re.sub(r"\s+", " ", text).strip(" .,!?:;-")
    words = cleaned.split()
    return " ".join(words[:max_words]).capitalize() or "Auto clip"


def build_candidates(
    segments: list[TranscriptSegment],
    min_duration: float,
    max_duration: float,
    limit: int,
) -> list[ClipCandidate]:
    candidates: list[ClipCandidate] = []
    if not segments:
        return candidates

    for start_idx, first in enumerate(segments):
        window: list[TranscriptSegment] = []
        for item in segments[start_idx:]:
            window.append(item)
            duration = window[-1].end - first.start
            if duration < min_duration:
                continue
            if duration > max_duration:
                break

            text = " ".join(part.text for part in window)
            score_result = score_window(window, duration)
            candidates.append(
                ClipCandidate(
                    index=0,
                    start=max(0, first.start - 0.35),
                    end=window[-1].end + 0.25,
                    duration=duration,
                    score=score_result.score,
                    title=first_sentence(text),
                    reason=", ".join(score_result.reasons) or "segmen stabil",
                    text=text,
                    score_breakdown=score_result.breakdown,
                )
            )

    candidates.sort(key=lambda item: (item.score - abs(item.duration - 85) * 0.04), reverse=True)
    picked: list[ClipCandidate] = []
    remaining = candidates[:]
    while remaining and len(picked) < limit:
        best: ClipCandidate | None = None
        best_adjusted = -1_000.0
        for candidate in remaining:
            overlaps = any(not (candidate.end < item.start or candidate.start > item.end) for item in picked)
            if overlaps:
                continue
            duration_similarity = min((abs(candidate.duration - item.duration) for item in picked), default=999)
            diversity_bonus = 8 if duration_similarity > 18 else 0
            adjusted = candidate.score - abs(candidate.duration - 85) * 0.04 + diversity_bonus
            if adjusted > best_adjusted:
                best = candidate
                best_adjusted = adjusted

        if best is None:
            break
        best.index = len(picked) + 1
        picked.append(best)
        remaining.remove(best)

    picked.sort(key=lambda item: item.start)
    for idx, candidate in enumerate(picked, start=1):
        candidate.index = idx
    return picked


def segments_for_clip(segments: Iterable[TranscriptSegment], clip: ClipCandidate) -> list[TranscriptSegment]:
    return [item for item in segments if item.end > clip.start and item.start < clip.end]


def wrap_subtitle(text: str, max_chars: int = 32, max_lines: int = 2) -> str:
    chunks = split_subtitle_text(text, max_chars=max_chars, max_lines=max_lines)
    return chunks[0] if chunks else ""


def split_subtitle_text(text: str, max_chars: int = 32, max_lines: int = 2) -> list[str]:
    words = text.split()
    chunks: list[str] = []
    lines: list[str] = []
    current: list[str] = []

    for word in words:
        candidate = " ".join([*current, word]).strip()
        if current and len(candidate) > max_chars:
            lines.append(" ".join(current))
            current = [word]
            if len(lines) == max_lines:
                chunks.append("\n".join(lines))
                lines = []
        else:
            current.append(word)

    if current and len(lines) < max_lines:
        lines.append(" ".join(current))
    if lines:
        chunks.append("\n".join(lines))

    return chunks


def write_srt(path: Path, segments: list[TranscriptSegment], offset: float, clip_duration: float) -> None:
    lines: list[str] = []
    cue_index = 1
    for item in segments:
        start = max(0, item.start - offset)
        end = min(clip_duration, max(start + 0.2, item.end - offset))
        if start >= clip_duration or end - start < 0.45:
            continue

        chunks = split_subtitle_text(item.text)
        chunk_duration = (end - start) / max(1, len(chunks))
        for chunk_idx, chunk in enumerate(chunks):
            chunk_start = start + chunk_duration * chunk_idx
            chunk_end = end if chunk_idx == len(chunks) - 1 else start + chunk_duration * (chunk_idx + 1)
            lines.extend(
                [
                    str(cue_index),
                    f"{seconds_to_stamp(chunk_start, srt=True)} --> {seconds_to_stamp(chunk_end, srt=True)}",
                    chunk,
                    "",
                ]
            )
            cue_index += 1
    path.write_text("\n".join(lines), encoding="utf-8")


def export_clip(
    video_path: Path,
    clip: ClipCandidate,
    clip_segments: list[TranscriptSegment],
    clips_dir: Path,
    burn_subtitles: bool,
    crop_mode: CropMode,
) -> Path:
    clips_dir.mkdir(parents=True, exist_ok=True)
    base_name = f"clip_{clip.index:02}_{slugify(clip.title)[:42] or 'auto'}"
    srt_path = clips_dir / f"{base_name}.srt"
    json_path = clips_dir / f"{base_name}.json"
    out_path = clips_dir / f"{base_name}.mp4"
    temp_video_path = clips_dir / f"{base_name}.video_tmp.mp4"
    temp_audio_path = clips_dir / f"{base_name}.audio_tmp.wav"

    duration = clip.end - clip.start
    write_srt(srt_path, clip_segments, clip.start, duration)
    save_json(json_path, asdict(clip))

    vf = vertical_crop_filter(video_path, clip, crop_mode)
    if burn_subtitles and clip_segments:
        style = (
            "FontName=Arial,FontSize=5,PrimaryColour=&H00FFFFFF,"
            "OutlineColour=&H00000000,BorderStyle=1,Outline=0.6,Shadow=0,"
            "Alignment=2,MarginV=42"
        )
        vf = f"{vf},subtitles='{srt_path.name}':force_style='{style}'"

    common_input = [
        ffmpeg_path(),
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-ss",
        f"{clip.start:.3f}",
        "-t",
        f"{duration:.3f}",
        "-i",
        str(video_path.resolve()),
    ]

    run(
        [
            *common_input,
            "-map",
            "0:v:0",
            "-an",
            "-vf",
            vf,
            "-c:v",
            "libx264",
            "-profile:v",
            "baseline",
            "-level",
            "4.0",
            "-preset",
            "veryfast",
            "-crf",
            "18",
            "-pix_fmt",
            "yuv420p",
            str(temp_video_path.name),
        ],
        cwd=clips_dir,
    )
    run(
        [
            *common_input,
            "-map",
            "0:a:0?",
            "-vn",
            "-af",
            "loudnorm=I=-16:TP=-1.5:LRA=11,aresample=48000",
            "-ac",
            "2",
            "-ar",
            "48000",
            "-c:a",
            "pcm_s16le",
            str(temp_audio_path.name),
        ],
        cwd=clips_dir,
    )
    run(
        [
            ffmpeg_path(),
            "-hide_banner",
            "-loglevel",
            "error",
            "-fflags",
            "+genpts",
            "-y",
            "-i",
            str(temp_video_path.name),
            "-i",
            str(temp_audio_path.name),
            "-map",
            "0:v:0",
            "-map",
            "1:a:0",
            "-c:v",
            "copy",
            "-c:a",
            "aac",
            "-profile:a",
            "aac_low",
            "-b:a",
            "160k",
            "-ar",
            "48000",
            "-ac",
            "2",
            "-disposition:a:0",
            "default",
            "-shortest",
            "-brand",
            "mp42",
            "-tag:v",
            "avc1",
            "-tag:a",
            "mp4a",
            "-movflags",
            "+faststart",
            str(out_path.name),
        ],
        cwd=clips_dir,
    )
    temp_video_path.unlink(missing_ok=True)
    return out_path


def print_candidates(candidates: list[ClipCandidate]) -> None:
    table = Table(title="Clip candidates")
    table.add_column("#", justify="right")
    table.add_column("Start")
    table.add_column("End")
    table.add_column("Score", justify="right")
    table.add_column("Title")
    table.add_column("Reason")

    for item in candidates:
        table.add_row(
            str(item.index),
            seconds_to_stamp(item.start),
            seconds_to_stamp(item.end),
            str(item.score),
            item.title,
            item.reason,
        )
    console.print(table)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Local YouTube auto clipper for short vertical videos.")
    parser.add_argument("url", help="YouTube URL")
    parser.add_argument("--top", type=int, default=5, help="Number of clips to export")
    parser.add_argument("--min", type=float, default=35, help="Minimum clip duration in seconds")
    parser.add_argument("--max", type=float, default=180, help="Maximum clip duration in seconds")
    parser.add_argument("--model", default="Systran/faster-whisper-small", help="faster-whisper model name")
    parser.add_argument("--language", default="id", help="Transcription language code")
    parser.add_argument("--output", default="outputs", help="Output directory")
    parser.add_argument("--analyze-seconds", type=float, help="Only transcribe the first N seconds; useful for quick tests")
    parser.add_argument("--review-only", action="store_true", help="Stop after generating clip candidates")
    parser.add_argument("--export-indexes", help="Comma-separated candidate indexes to export, e.g. 1,3,5")
    parser.add_argument("--no-burn-subtitles", action="store_true", help="Create SRT files but do not burn subtitles into MP4")
    parser.add_argument(
        "--crop-mode",
        choices=["center", "person"],
        default="center",
        help="Use center crop or shift the vertical crop toward a detected person",
    )
    parser.add_argument("--force", action="store_true", help="Redo download, audio extraction, and transcription")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if args.min <= 0 or args.max <= args.min:
        console.print("[red]Invalid duration range.[/red]")
        return 2

    root = Path(args.output)
    root.mkdir(parents=True, exist_ok=True)

    console.print("[bold]Fetching metadata...[/bold]")
    metadata = fetch_metadata(args.url)
    title = metadata.get("title") or metadata.get("id") or "youtube-video"
    work_dir = root / slugify(title)[:80]
    work_dir.mkdir(parents=True, exist_ok=True)

    console.print("[bold]Fetching video...[/bold]")
    final_video_path, metadata = download_video(args.url, work_dir, force=args.force)
    save_json(work_dir / "metadata.json", metadata)

    cache_suffix = f"_{int(args.analyze_seconds)}s" if args.analyze_seconds else ""
    audio_path = extract_audio(
        final_video_path,
        work_dir / f"audio{cache_suffix}.wav",
        force=args.force,
        limit_seconds=args.analyze_seconds,
    )
    transcript = transcribe(
        audio_path,
        work_dir / f"transcript{cache_suffix}.json",
        args.model,
        args.language,
        force=args.force,
    )

    console.print("[bold]Scoring candidate clips...[/bold]")
    candidates = build_candidates(transcript, args.min, args.max, args.top)
    if not candidates:
        console.print("[red]No clip candidates found. Try lowering --min or increasing --max.[/red]")
        return 1

    save_json(work_dir / f"candidates{cache_suffix}.json", [asdict(item) for item in candidates])
    print_candidates(candidates)

    if args.review_only:
        console.print("[green]Review candidates ready.[/green]")
        return 0

    if args.export_indexes:
        selected_indexes = {
            int(part.strip())
            for part in args.export_indexes.split(",")
            if part.strip().isdigit()
        }
        candidates = [item for item in candidates if item.index in selected_indexes]
        if not candidates:
            console.print("[red]No matching candidate indexes to export.[/red]")
            return 1

    console.print("[bold]Exporting vertical clips...[/bold]")
    clips_dir = work_dir / "clips"
    exported: list[Path] = []
    for candidate in candidates:
        clip_segments = segments_for_clip(transcript, candidate)
        exported.append(
            export_clip(
                final_video_path,
                candidate,
                clip_segments,
                clips_dir,
                not args.no_burn_subtitles,
                args.crop_mode,
            )
        )

    console.print("[green]Done.[/green] Exported:")
    for path in exported:
        console.print(f"  {path}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        console.print("\n[yellow]Cancelled.[/yellow]")
        raise SystemExit(130)
    except Exception as exc:
        console.print(f"[red]Error:[/red] {exc}")
        raise SystemExit(1)
