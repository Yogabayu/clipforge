import tempfile
from pathlib import Path
from unittest import TestCase
from unittest.mock import MagicMock, patch

from yt_dlp.utils import DownloadError

from clipper import ClipCandidate, build_montage_segments, download_video, sequence_badge_filter, video_download_options


class VideoDownloadOptionsTests(TestCase):
    def test_recovers_missing_metadata_without_redownloading_video(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            work_dir = Path(temp_dir)
            source_path = work_dir / "source.mp4"
            source_path.write_bytes(b"complete video")
            metadata = {"id": "video-id", "title": "Recovered"}

            with (
                patch("clipper.fetch_metadata", return_value=metadata) as fetch_metadata,
                patch("clipper.YoutubeDL") as youtube_dl,
            ):
                file_path, info = download_video("https://example.com/video", work_dir)

            self.assertEqual(file_path, source_path)
            self.assertEqual(info, metadata)
            self.assertTrue((work_dir / "metadata.json").exists())
            fetch_metadata.assert_called_once_with("https://example.com/video")
            youtube_dl.assert_not_called()

    def test_retries_slow_transfers_and_resumes_partial_downloads(self) -> None:
        options = video_download_options(Path("output"))

        self.assertEqual(options["socket_timeout"], 60)
        self.assertEqual(options["retries"], 20)
        self.assertEqual(options["fragment_retries"], 20)
        self.assertTrue(options["continuedl"])
        self.assertEqual(options["js_runtimes"], {"node": {}})
        self.assertEqual(options["concurrent_fragment_downloads"], 4)
        self.assertIn("protocol^=m3u8", options["format"])

    def test_reextracts_with_hls_fallback_after_http_403(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            work_dir = Path(temp_dir)
            downloaded_path = work_dir / "source.mp4"
            failed_ydl = MagicMock()
            failed_ydl.__enter__.return_value = failed_ydl
            failed_ydl.extract_info.side_effect = DownloadError(
                "ERROR: unable to download video data: HTTP Error 403: Forbidden"
            )
            successful_ydl = MagicMock()
            successful_ydl.__enter__.return_value = successful_ydl

            def complete_download(*_args, **_kwargs):
                downloaded_path.touch()
                return {"id": "video-id", "ext": "mp4"}

            successful_ydl.extract_info.side_effect = complete_download
            successful_ydl.prepare_filename.return_value = str(downloaded_path)

            with patch("clipper.YoutubeDL", side_effect=[failed_ydl, successful_ydl]) as youtube_dl:
                file_path, info = download_video("https://example.com/video", work_dir)

            self.assertEqual(file_path, downloaded_path)
            self.assertEqual(info["id"], "video-id")
            self.assertEqual(youtube_dl.call_count, 2)
            primary_options, fallback_options = [call.args[0] for call in youtube_dl.call_args_list]
            self.assertNotEqual(primary_options["format"], fallback_options["format"])
            self.assertIn("protocol^=m3u8", primary_options["format"])
            self.assertNotIn("protocol^=m3u8", fallback_options["format"])
            failed_ydl.extract_info.assert_called_once_with("https://example.com/video", download=True)
            successful_ydl.extract_info.assert_called_once_with("https://example.com/video", download=True)

    def test_does_not_retry_other_download_errors(self) -> None:
        failed_ydl = MagicMock()
        failed_ydl.__enter__.return_value = failed_ydl
        failed_ydl.extract_info.side_effect = DownloadError("ERROR: video unavailable")

        with tempfile.TemporaryDirectory() as temp_dir:
            with patch("clipper.YoutubeDL", return_value=failed_ydl) as youtube_dl:
                with self.assertRaisesRegex(DownloadError, "video unavailable"):
                    download_video("https://example.com/video", Path(temp_dir))

        youtube_dl.assert_called_once()


def candidate(index: int, start: float, score: int, duration: float = 35) -> ClipCandidate:
    return ClipCandidate(index, start, start + duration, duration, score, f"Hook {index}", "", "", {})


class MontageSegmentTests(TestCase):
    def test_selects_up_to_five_best_hooks_in_timeline_order(self) -> None:
        candidates = [candidate(index, index * 100, score) for index, score in enumerate([60, 95, 80, 100, 70, 90], 1)]

        segments = build_montage_segments(candidates, 60)

        self.assertEqual(len(segments), 5)
        self.assertEqual([item.title for item in segments], ["Hook 2", "Hook 3", "Hook 4", "Hook 5", "Hook 6"])
        self.assertEqual([item.index for item in segments], [1, 2, 3, 4, 5])
        self.assertLessEqual(sum(item.duration for item in segments), 60)

    def test_limits_segment_count_when_duration_budget_is_short(self) -> None:
        segments = build_montage_segments([candidate(index, index * 10, 100 - index) for index in range(1, 6)], 12)

        self.assertEqual(len(segments), 2)
        self.assertLessEqual(sum(item.duration for item in segments), 12)

    def test_draws_sequence_badge_without_system_font_dependency(self) -> None:
        video_filter = sequence_badge_filter(5)

        self.assertIn("color=black@0.72", video_filter)
        self.assertEqual(video_filter.count("color=white"), 5)
        self.assertNotIn("drawtext", video_filter)
