from types import SimpleNamespace
from unittest import TestCase

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
