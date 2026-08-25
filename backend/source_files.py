from pathlib import Path


SOURCE_MEDIA_SUFFIXES = {".mkv", ".mov", ".mp4", ".webm"}


def is_complete_source_name(name: str) -> bool:
    filename = Path(name).name
    return (
        Path(filename).suffix.lower() in SOURCE_MEDIA_SUFFIXES
        and ".part" not in filename
        and ".temp." not in filename
    )


def complete_source_files(work_dir: Path) -> list[Path]:
    candidates = [
        path
        for path in work_dir.glob("source.*")
        if path.is_file()
        and is_complete_source_name(path.name)
    ]
    return sorted(candidates, key=lambda path: (path.name != "source.mp4", path.name))
