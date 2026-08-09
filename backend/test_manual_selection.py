from unittest import TestCase

from clipper import build_manual_candidates


class ManualCandidateTests(TestCase):
    def test_builds_selected_ranges_in_submitted_order(self) -> None:
        ranges = [
            {'index': 4, 'start': 12.5, 'end': 25.0, 'title': 'Bagian empat'},
            {'index': 2, 'start': 40.0, 'end': 51.5, 'title': 'Bagian dua'},
        ]

        candidates = build_manual_candidates(ranges, 60)

        self.assertEqual([item.index for item in candidates], [1, 2])
        self.assertEqual([item.start for item in candidates], [12.5, 40.0])
        self.assertEqual([item.duration for item in candidates], [12.5, 11.5])
        self.assertTrue(all(item.reason == 'Dipilih manual' for item in candidates))

    def test_rejects_empty_or_out_of_bounds_ranges(self) -> None:
        with self.assertRaises(ValueError):
            build_manual_candidates([{'start': 10, 'end': 10}], 60)
        with self.assertRaises(ValueError):
            build_manual_candidates([{'start': 0, 'end': 61}], 60)

    def test_allows_long_range_inside_full_video(self) -> None:
        candidates = build_manual_candidates([{'start': 100, 'end': 800, 'title': 'Long cut'}], 1000)

        self.assertEqual(candidates[0].duration, 700)
