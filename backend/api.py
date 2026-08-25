from __future__ import annotations

import json
import shutil
import subprocess
import sys
import threading
import time
import uuid
from math import ceil
from datetime import datetime, timezone
from pathlib import Path
from typing import Literal
from urllib.parse import quote

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field
from yt_dlp import YoutubeDL

from source_files import complete_source_files, is_complete_source_name


BASE_DIR = Path(__file__).resolve().parent
OUTPUTS_DIR = BASE_DIR / "outputs"
JOBS_PATH = BASE_DIR / "jobs.json"
SECONDS_PER_TARGET_CLIP = 360
MIN_AUTO_CLIPS = 2
MAX_AUTO_CLIPS = 8
FULL_ANALYSIS_LIMIT_SECONDS = 30 * 60
LONG_VIDEO_ANALYSIS_RATIO = 0.55
MAX_AUTO_ANALYSIS_SECONDS = 60 * 60


class ClipJobRequest(BaseModel):
    url: str = Field(min_length=8)
    top: int | None = Field(default=None, ge=1, le=12)
    min_duration: float = Field(default=35, ge=5, le=600)
    max_duration: float = Field(default=180, ge=10, le=600)
    model: str = "Systran/faster-whisper-small"
    language: str = "id"
    analyze_seconds: float | None = Field(default=None, ge=10, le=7200)
    burn_subtitles: bool = True
    crop_mode: Literal["center", "person", "clip"] = "center"


class ClipCandidate(BaseModel):
    index: int
    start: float
    end: float
    duration: float
    score: int
    title: str
    reason: str
    text: str
    score_breakdown: dict[str, int] = Field(default_factory=dict)


class ClipRange(BaseModel):
    index: int = Field(ge=1)
    start: float = Field(ge=0)
    end: float = Field(gt=0)
    title: str = Field(min_length=1, max_length=120)


class RenderSelectionRequest(BaseModel):
    ranges: list[ClipRange] = Field(min_length=1, max_length=12)
    combine: bool = False
    output_aspect: Literal['portrait', 'landscape'] = 'portrait'
    output_resolution: Literal['720p', '1080p', '1440p'] = '1080p'


class ClipFile(BaseModel):
    name: str
    url: str
    size_bytes: int


class ClipJob(BaseModel):
    id: str
    status: Literal["queued", "running", "completed", "failed"]
    request: ClipJobRequest
    created_at: str
    updated_at: str
    logs: list[str] = []
    clips: list[ClipFile] = []
    candidates: list[ClipCandidate] = []
    source_url: str | None = None
    video_duration: float | None = None
    error: str | None = None


app = FastAPI(title="ClipForge API", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://127.0.0.1:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

OUTPUTS_DIR.mkdir(parents=True, exist_ok=True)
app.mount("/outputs", StaticFiles(directory=OUTPUTS_DIR), name="outputs")

def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_jobs() -> dict[str, ClipJob]:
    if not JOBS_PATH.exists():
        return {}

    payload = json.loads(JOBS_PATH.read_text(encoding="utf-8"))
    loaded: dict[str, ClipJob] = {}
    for item in payload:
        job = ClipJob(**item)
        if job.status in {"queued", "running"}:
            data = job.model_dump()
            data["status"] = "failed"
            data["updated_at"] = now_iso()
            data["error"] = "Backend restarted before this job finished"
            job = ClipJob(**data)
        loaded[job.id] = job
    return loaded


def save_jobs_unlocked() -> None:
    jobs_list = sorted(jobs.values(), key=lambda job: job.created_at, reverse=True)
    payload = [job.model_dump() for job in jobs_list]
    temp_path = JOBS_PATH.with_suffix(".json.tmp")
    temp_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
    temp_path.replace(JOBS_PATH)


def clear_outputs_dir() -> tuple[int, list[str]]:
    OUTPUTS_DIR.mkdir(parents=True, exist_ok=True)
    root = OUTPUTS_DIR.resolve()
    removed = 0
    skipped: list[str] = []
    for item in OUTPUTS_DIR.iterdir():
        resolved = item.resolve()
        if root not in resolved.parents:
            raise RuntimeError(f"Refusing to delete path outside outputs: {resolved}")

        try:
            if item.is_dir():
                shutil.rmtree(item)
            else:
                item.unlink()
            removed += 1
        except OSError:
            skipped.append(item.name)
    return removed, skipped


jobs: dict[str, ClipJob] = load_jobs()
jobs_lock = threading.Lock()


def clip_url(path: Path) -> str:
    relative = path.resolve().relative_to(OUTPUTS_DIR.resolve()).as_posix()
    return "/outputs/" + quote(relative)


def discover_clips(started_at: float) -> list[ClipFile]:
    clips: list[ClipFile] = []
    for path in OUTPUTS_DIR.rglob("clips/*.mp4"):
        if path.stat().st_mtime + 1 < started_at:
            continue
        clips.append(
            ClipFile(
                name=path.name,
                url=clip_url(path),
                size_bytes=path.stat().st_size,
            )
        )
    clips.sort(key=lambda item: item.name)
    return clips


def discover_candidates(started_at: float) -> list[ClipCandidate]:
    candidate_files = [
        path
        for path in OUTPUTS_DIR.rglob("candidates*.json")
        if path.stat().st_mtime + 1 >= started_at
    ]
    if not candidate_files:
        return []

    latest = max(candidate_files, key=lambda path: path.stat().st_mtime)
    payload = json.loads(latest.read_text(encoding="utf-8"))
    return [ClipCandidate(**item) for item in payload]


def discover_source(started_at: float) -> tuple[str | None, float | None]:
    candidate_files = [
        path
        for path in OUTPUTS_DIR.rglob('candidates*.json')
        if path.stat().st_mtime + 1 >= started_at
    ]
    if not candidate_files:
        return None, None

    work_dir = max(candidate_files, key=lambda path: path.stat().st_mtime).parent
    source_files = complete_source_files(work_dir)
    metadata_path = work_dir / 'metadata.json'
    duration = None
    if metadata_path.exists():
        metadata = json.loads(metadata_path.read_text(encoding='utf-8'))
        if metadata.get('duration'):
            duration = float(metadata['duration'])
    return (clip_url(source_files[0]) if source_files else None, duration)


def hydrate_job_source(job: ClipJob) -> ClipJob:
    if job.source_url and job.video_duration and is_complete_source_name(job.source_url):
        return job
    for metadata_path in OUTPUTS_DIR.rglob('metadata.json'):
        metadata = json.loads(metadata_path.read_text(encoding='utf-8'))
        known_urls = {metadata.get('webpage_url'), metadata.get('original_url')}
        if job.request.url not in known_urls:
            continue
        source_files = complete_source_files(metadata_path.parent)
        if not source_files or not metadata.get('duration'):
            continue
        data = job.model_dump()
        data.update(source_url=clip_url(source_files[0]), video_duration=float(metadata['duration']))
        return ClipJob(**data)
    return job


def set_job(job_id: str, **updates) -> None:
    with jobs_lock:
        job = jobs[job_id]
        data = job.model_dump()
        data.update(updates)
        data["updated_at"] = now_iso()
        jobs[job_id] = ClipJob(**data)
        save_jobs_unlocked()


def clamp(value: int, minimum: int, maximum: int) -> int:
    return max(minimum, min(maximum, value))


def fetch_video_duration(url: str) -> float | None:
    ydl_opts = {
        "quiet": True,
        "no_warnings": True,
        "noplaylist": True,
        "skip_download": True,
    }
    try:
        with YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
    except Exception:
        return None

    duration = info.get("duration") if isinstance(info, dict) else None
    return float(duration) if duration else None


def choose_auto_top(duration: float | None) -> int:
    if not duration:
        return MIN_AUTO_CLIPS + 3
    return clamp(ceil(duration / SECONDS_PER_TARGET_CLIP), MIN_AUTO_CLIPS, MAX_AUTO_CLIPS)


def choose_auto_analyze_seconds(duration: float | None) -> float | None:
    if not duration or duration <= FULL_ANALYSIS_LIMIT_SECONDS:
        return None
    return min(MAX_AUTO_ANALYSIS_SECONDS, max(FULL_ANALYSIS_LIMIT_SECONDS, duration * LONG_VIDEO_ANALYSIS_RATIO))


def normalize_job_request(request: ClipJobRequest) -> ClipJobRequest:
    duration = fetch_video_duration(request.url)
    data = request.model_dump()

    if request.top is None:
        data["top"] = choose_auto_top(duration)
    if request.analyze_seconds is None:
        data["analyze_seconds"] = choose_auto_analyze_seconds(duration)

    return ClipJobRequest(**data)


def build_clipper_command(request: ClipJobRequest) -> list[str]:
    command = [
        sys.executable,
        "clipper.py",
        request.url,
        "--top",
        str(request.top or choose_auto_top(None)),
        "--min",
        str(request.min_duration),
        "--max",
        str(request.max_duration),
        "--model",
        request.model,
        "--language",
        request.language,
    ]

    if request.analyze_seconds:
        command.extend(["--analyze-seconds", str(request.analyze_seconds)])
    if not request.burn_subtitles:
        command.append("--no-burn-subtitles")
    command.extend(["--crop-mode", request.crop_mode])
    return command


def build_selection_command(
    request: ClipJobRequest,
    ranges: list[ClipRange],
    combine: bool,
    output_aspect: Literal['portrait', 'landscape'],
    output_resolution: Literal['720p', '1080p', '1440p'],
) -> list[str]:
    command = build_clipper_command(request)
    command.extend(['--manual-ranges-json', json.dumps([item.model_dump() for item in ranges])])
    if combine:
        command.append('--combine-manual-ranges')
    command.extend(['--output-aspect', output_aspect])
    command.extend(['--output-resolution', output_resolution])
    return command


def run_job(
    job_id: str,
    ranges: list[ClipRange] | None = None,
    combine: bool = False,
    output_aspect: Literal['portrait', 'landscape'] = 'portrait',
    output_resolution: Literal['720p', '1080p', '1440p'] = '1080p',
) -> None:
    with jobs_lock:
        request = jobs[job_id].request

    started_at = time.time()
    set_job(job_id, status="running", error=None)
    if ranges:
        command = build_selection_command(request, ranges, combine, output_aspect, output_resolution)
    else:
        command = [*build_clipper_command(request), '--review-only']

    process = subprocess.Popen(
        command,
        cwd=BASE_DIR,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
        bufsize=1,
    )

    logs: list[str] = []
    assert process.stdout is not None
    for line in process.stdout:
        cleaned = line.rstrip()
        if cleaned:
            logs.append(cleaned)
            set_job(job_id, logs=logs[-120:])

    code = process.wait()
    clips = discover_clips(started_at)
    candidates = discover_candidates(started_at)
    source_url, video_duration = discover_source(started_at)
    if code == 0:
        updates = {"status": "completed", "logs": logs[-120:]}
        updates.update(source_url=source_url, video_duration=video_duration)
        if clips:
            updates["clips"] = clips
        if candidates:
            updates["candidates"] = candidates
        set_job(job_id, **updates)
    else:
        set_job(
            job_id,
            status="failed",
            clips=clips,
            candidates=candidates,
            logs=logs[-120:],
            error=f"clipper.py exited with code {code}",
        )


@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


def queue_selection_job(
    source_job: ClipJob,
    ranges: list[ClipRange],
    combine: bool,
    output_aspect: Literal['portrait', 'landscape'],
    output_resolution: Literal['720p', '1080p', '1440p'],
) -> ClipJob:
    duration = source_job.video_duration
    if not source_job.source_url or not duration:
        raise HTTPException(status_code=409, detail='Full video source is not ready')
    for selected in ranges:
        if selected.end > duration or selected.end <= selected.start:
            raise HTTPException(status_code=400, detail=f'Range {selected.index} is invalid')

    render_job = ClipJob(
        id=uuid.uuid4().hex,
        status='queued',
        request=source_job.request,
        created_at=now_iso(),
        updated_at=now_iso(),
    )
    with jobs_lock:
        jobs[render_job.id] = render_job
        save_jobs_unlocked()

    thread = threading.Thread(
        target=run_job,
        args=(render_job.id, ranges, combine, output_aspect, output_resolution),
        daemon=True,
    )
    thread.start()
    return render_job


@app.post('/api/jobs', response_model=ClipJob)
def create_job(request: ClipJobRequest) -> ClipJob:
    if request.max_duration <= request.min_duration:
        raise HTTPException(status_code=400, detail="max_duration must be greater than min_duration")

    request = normalize_job_request(request)
    job_id = uuid.uuid4().hex
    job = ClipJob(
        id=job_id,
        status="queued",
        request=request,
        created_at=now_iso(),
        updated_at=now_iso(),
    )
    with jobs_lock:
        jobs[job_id] = job
        save_jobs_unlocked()

    thread = threading.Thread(target=run_job, args=(job_id,), daemon=True)
    thread.start()
    return job


@app.post('/api/jobs/{job_id}/render', response_model=ClipJob)
def render_selection(job_id: str, selection: RenderSelectionRequest) -> ClipJob:
    with jobs_lock:
        source_job = jobs.get(job_id)
    if not source_job:
        raise HTTPException(status_code=404, detail='Job not found')
    if source_job.status != 'completed':
        raise HTTPException(status_code=409, detail='Full video source is not ready')
    source_job = hydrate_job_source(source_job)
    return queue_selection_job(
        source_job,
        selection.ranges,
        selection.combine,
        selection.output_aspect,
        selection.output_resolution,
    )





@app.get("/api/jobs", response_model=list[ClipJob])
def list_jobs() -> list[ClipJob]:
    with jobs_lock:
        ordered = sorted(jobs.values(), key=lambda job: job.created_at, reverse=True)
    return [hydrate_job_source(job) for job in ordered]


@app.delete("/api/jobs")
def delete_all_jobs() -> dict[str, str | int | list[str]]:
    with jobs_lock:
        if any(job.status in {"queued", "running"} for job in jobs.values()):
            raise HTTPException(status_code=409, detail="Stop active jobs before deleting history")
        jobs.clear()
        save_jobs_unlocked()
    removed_outputs, skipped_outputs = clear_outputs_dir()
    return {
        "status": "ok",
        "removed_outputs": removed_outputs,
        "skipped_outputs": skipped_outputs,
    }


@app.get("/api/jobs/{job_id}", response_model=ClipJob)
def get_job(job_id: str) -> ClipJob:
    with jobs_lock:
        job = jobs.get(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    return hydrate_job_source(job)
