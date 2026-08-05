from pathlib import Path
from types import SimpleNamespace
from unittest import TestCase

from clipper import ClipCandidate, build_timeline_candidates, vertical_crop_filter
from scoring import score_window


def segment(start: float, end: float, text: str) -> SimpleNamespace:
    return SimpleNamespace(start=start, end=end, text=text)


class ScoreWindowTests(TestCase):
    def test_rewards_early_hook_and_complete_payoff(self) -> None:
        items = [
            segment(0, 4, "Bagaimana cara membuat video yang menarik?"),
            segment(4, 22, "Kita mulai dengan masalah yang jelas lalu memberikan contoh praktis untuk penonton. Setiap bagian harus membawa informasi baru agar perhatian mereka tetap terjaga."),
            segment(22, 42, "Tunjukkan penyebab masalah, berikan langkah yang bisa langsung dicoba, kemudian bandingkan keadaan sebelum dan sesudah langkah tersebut dilakukan."),
            segment(42, 58, "Penjelasan yang runtut menjaga konteks tetap padat dan mudah dipahami. Buang pengulangan yang tidak menambah makna atau membantu alur cerita."),
            segment(58, 70, "Akhirnya, hasilnya lebih fokus, pesannya lengkap, dan penonton memahami solusinya dengan jelas."),
        ]

        result = score_window(items, 70)

        self.assertGreaterEqual(result.score, 70)
        self.assertGreater(result.breakdown["opening"], 0)
        self.assertGreater(result.breakdown["ending"], 0)

    def test_penalizes_weak_incomplete_sparse_window(self) -> None:
        items = [
            segment(0, 3, "Dan eh ya"),
            segment(8, 11, "terus gitu"),
            segment(15, 18, "mungkin anu"),
        ]

        result = score_window(items, 40)

        self.assertLess(result.score, 30)
        self.assertLess(result.breakdown["opening"], 0)
        self.assertLess(result.breakdown["content"], 0)

    def test_hook_after_first_five_seconds_does_not_raise_opening_score(self) -> None:
        early = [segment(0, 4, "Pembukaan biasa tanpa pemicu."), segment(6, 12, "Rahasia penting ada di sini.")]
        plain = [segment(0, 4, "Pembukaan biasa tanpa pemicu."), segment(6, 12, "Penjelasan biasa ada di sini.")]

        self.assertEqual(score_window(early, 40).breakdown["opening"], score_window(plain, 40).breakdown["opening"])


class TimelineCandidateTests(TestCase):
    def test_builds_unscored_candidates_when_dialogue_is_absent(self) -> None:
        candidates = build_timeline_candidates(300, 35, 180, 3)

        self.assertEqual(len(candidates), 3)
        self.assertEqual([item.index for item in candidates], [1, 2, 3])
        self.assertTrue(all(item.duration == 85 for item in candidates))
        self.assertTrue(all(item.score == 0 for item in candidates))
        self.assertTrue(all(item.text == "" for item in candidates))
        self.assertGreater(candidates[1].start, candidates[0].end)

    def test_returns_empty_when_video_is_shorter_than_minimum(self) -> None:
        self.assertEqual(build_timeline_candidates(20, 35, 180, 3), [])


class VideoLayoutTests(TestCase):
    def test_center_mode_fits_video_on_gray_vertical_canvas(self) -> None:
        clip = ClipCandidate(1, 0, 60, 60, 0, "Test", "Test", "", {})

        video_filter = vertical_crop_filter(Path("unused.mp4"), clip, "center")

        self.assertIn("force_original_aspect_ratio=decrease", video_filter)
        self.assertIn("pad=1080:1920", video_filter)
        self.assertIn("color=gray", video_filter)
        self.assertNotIn("crop=", video_filter)
