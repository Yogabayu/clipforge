from pathlib import Path
from unittest import TestCase

from clipper import ClipCandidate, build_montage_segments, sequence_badge_filter, video_download_options


class VideoDownloadOptionsTests(TestCase):
    def test_retries_slow_transfers_and_resumes_partial_downloads(self) -> None:
        options = video_download_options(Path("output"))

        self.assertEqual(options["socket_timeout"], 60)
        self.assertEqual(options["retries"], 20)
        self.assertEqual(options["fragment_retries"], 20)
        self.assertTrue(options["continuedl"])


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
