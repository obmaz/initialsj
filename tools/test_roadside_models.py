"""모델 제작 도구가 편집 원본을 조용히 덮어쓰지 않는지 검사한다."""
import hashlib
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import bake_roadside_models as models


class RoadsideOriginals(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        self.setting = patch.object(models, "ROOT", self.root)
        self.setting.start()
        self.shape = models.Shape()
        self.shape.box((0, 0, 0), (1, 1, 1), (.2, .3, .4, 1))

    def tearDown(self):
        self.setting.stop()
        self.directory.cleanup()

    def test_existing_artist_original_and_assembly_stay_untouched(self):
        self.shape.pack("sample", "검사용 모델")
        source = self.root / "model_sources/props/sample/model.glb"
        scene = self.root / "models/props/sample/model.tscn"
        source.write_bytes(b"artist-owned-original")
        scene.write_text("artist-owned-assembly")
        self.shape.pack("sample", "재실행")
        self.assertEqual(source.read_bytes(), b"artist-owned-original")
        self.assertEqual(scene.read_text(), "artist-owned-assembly")

    def test_explicit_replace_preserves_previous_bytes_and_color_binding(self):
        self.shape.pack("sample", "검사용 모델")
        source = self.root / "model_sources/props/sample/model.glb"
        old = b"artist-owned-original"
        source.write_bytes(old)
        self.shape.pack("sample", "명시적 교체", replace=True)
        backup = self.root / f"build/reports/model-backups/sample-{hashlib.sha256(old).hexdigest()[:12]}.glb"
        self.assertEqual(backup.read_bytes(), old)
        self.assertNotEqual(source.read_bytes(), old)
        material = self.root / "models/props/sample/material.tres"
        scene = self.root / "models/props/sample/model.tscn"
        self.assertIn("vertex_color_use_as_albedo = true", material.read_text())
        self.assertIn('material_override = ExtResource("2")', scene.read_text())


if __name__ == "__main__":
    unittest.main()
