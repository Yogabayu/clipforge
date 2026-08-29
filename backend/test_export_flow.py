from pathlib import Path
from unittest import TestCase

from api import ClipJobRequest, ClipRange, build_clipper_command, build_selection_command
from clipper import ClipCandidate, output_video_filter


class ExportFlowTests(TestCase):
    def test_initial_command_can_be_made_review_only_without_render_flags(self) -> None:
        command = [*build_clipper_command(ClipJobRequest(url='https://youtu.be/example')), '--review-only']

        self.assertIn('--review-only', command)
        self.assertNotIn('--manual-ranges-json', command)

    def test_manual_command_carries_aspect_resolution_and_combine_flags(self) -> None:
        request = ClipJobRequest(url='https://youtu.be/example', analyze_seconds=120)
        ranges = [ClipRange(index=1, start=10, end=20, title='Bagian 1')]

        command = build_selection_command(request, ranges, True, 'landscape', '1440p')

        self.assertNotIn('--analyze-seconds', command)
        self.assertIn('--manual-ranges-json', command)
        self.assertIn('--combine-manual-ranges', command)
        self.assertEqual(command[command.index('--output-aspect') + 1], 'landscape')
        self.assertEqual(command[command.index('--output-resolution') + 1], '1440p')

    def test_landscape_filter_outputs_full_hd_canvas(self) -> None:
        clip = ClipCandidate(1, 0, 10, 10, 0, 'Test', '', '', {})

        video_filter = output_video_filter(Path('source.mp4'), clip, 'person', 'landscape', '1080p')

        self.assertIn('1920:1080', video_filter)
        self.assertNotIn('crop=', video_filter)

    def test_resolution_changes_dimensions_for_both_aspects(self) -> None:
        clip = ClipCandidate(1, 0, 10, 10, 0, 'Test', '', '', {})

        landscape = output_video_filter(Path('source.mp4'), clip, 'center', 'landscape', '720p')
        portrait = output_video_filter(Path('source.mp4'), clip, 'center', 'portrait', '1440p')

        self.assertIn('1280:720', landscape)
        self.assertTrue(portrait.endswith('scale=1440:2560'))
