import tempfile
from pathlib import Path
from unittest import TestCase
from unittest.mock import patch

import api


class OutputCleanupTests(TestCase):
    def test_locked_output_is_reported_and_other_outputs_are_removed(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            output_dir = Path(temp_dir)
            locked_dir = output_dir / "locked-job"
            locked_dir.mkdir()
            (locked_dir / "source.mp4").touch()
            removable_file = output_dir / "old.log"
            removable_file.touch()

            with (
                patch.object(api, "OUTPUTS_DIR", output_dir),
                patch.object(api.shutil, "rmtree", side_effect=PermissionError("file is locked")),
            ):
                removed, skipped = api.clear_outputs_dir()

            self.assertEqual(removed, 1)
            self.assertEqual(skipped, ["locked-job"])
            self.assertTrue(locked_dir.exists())
            self.assertFalse(removable_file.exists())
