from pathlib import Path
import importlib.util
import sys
import unittest

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / 'backend'))
spec = importlib.util.spec_from_file_location('mobile_recommend', root / 'mobile/android/app/src/main/assets/recommend.py')
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
spec.loader.exec_module(module)


class RecommendationTests(unittest.TestCase):
    def test_default_ten_and_explicit_override(self):
        payload = {'duration': 2000, 'segments': [dict(start=i*100, end=i*100+60, text='Kenapa penting? Intinya solusi dan hasilnya jelas.') for i in range(15)]}
        result = module.recommend(payload, minimum=35, maximum=80)
        self.assertEqual(10, len(result))
        self.assertEqual(2, len(module.recommend(payload, top=2, minimum=35, maximum=80)))
        self.assertTrue(all(a['end'] <= b['start'] for a, b in zip(result, result[1:])))
        self.assertEqual(list(range(1, 11)), [item['index'] for item in result])

    def test_short_spoken_video_is_scored_without_fake_ten_duplicates(self):
        result = module.recommend({'duration': 19.064, 'segments': [dict(start=.3, end=18.4, text='Here is how this works. This is the result.')]})
        self.assertEqual(1, len(result))
        self.assertEqual(19.064, result[0]['end'])
        self.assertGreater(result[0]['score'], 0)

    def test_silent_timeline_is_explicitly_unscored(self):
        result = module.recommend({'duration': 19, 'segments': []})
        self.assertEqual(1, len(result))
        self.assertEqual(0, result[0]['score'])
        self.assertIn('tidak dinilai', result[0]['reason'])

    def test_rejects_invalid_options(self):
        for options in [dict(top=0), dict(top=13), dict(minimum=180, maximum=35), dict(maximum=float('nan'))]:
            with self.assertRaises(ValueError): module.recommend({'duration': 120, 'segments': []}, **options)

    def test_sentence_padding_respects_maximum_duration(self):
        result = module.recommend({'duration': 100, 'segments': [dict(start=.5, end=80.5, text='Bagaimana cara penting ini bekerja? Intinya hasilnya jelas.')]}, minimum=35, maximum=80)
        self.assertTrue(all(item['duration'] <= 80 for item in result))


if __name__ == '__main__': unittest.main()
