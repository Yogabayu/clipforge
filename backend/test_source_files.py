import tempfile
from pathlib import Path
from unittest import TestCase

from source_files import complete_source_files, is_complete_source_name


class CompleteSourceFilesTests(TestCase):
    def test_prefers_merged_source_and_ignores_download_artifacts(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            work_dir = Path(temp_dir)
            merged = work_dir / "source.mp4"
            alternate = work_dir / "source.webm"
            for path in (
                work_dir / "source.f399.mp4.part",
                work_dir / "source.f612.mp4.part-Frag28.part",
                work_dir / "source.f612.mp4.ytdl",
                work_dir / "source.temp.mp4",
                alternate,
                merged,
            ):
                path.touch()

            self.assertEqual(complete_source_files(work_dir), [merged, alternate])

    def test_rejects_partial_source_url(self) -> None:
        self.assertFalse(is_complete_source_name("/outputs/video/source.f399.mp4.part"))
        self.assertTrue(is_complete_source_name("/outputs/video/source.mp4"))
