"""원본과 다른 정적 충돌 자료가 빌드 검사를 통과하지 못하게 한다."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from check_world_collisions import check


class CollisionFreshnessTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.folder = self.root / "models/world/track_0"
        self.folder.mkdir(parents=True)
        self.profile = self.folder / "profile.tres"
        self.profile.write_text("road-v1")
        self.scene = self.folder / "model.tscn"
        self.scene.write_text("road-scene-v1")
        self.generator = self.root / "tools/bake_world_collisions.gd"
        self.generator.parent.mkdir()
        self.generator.write_text('const INPUTS := ["res://tools/bake_world_collisions.gd"]')
        self.output = self.folder / "collision.res"
        self.output.write_bytes(b"generated-shape-v1")
        metadata = {
            "schema": 1,
            "inputs": {
                "res://" + path.relative_to(self.root).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
                for path in [self.profile, self.scene, self.generator]
            },
            "sha256": hashlib.sha256(self.output.read_bytes()).hexdigest(),
            "groundTriangles": 10,
            "barrierTriangles": 12,
        }
        (self.folder / "collision.sources.json").write_text(json.dumps(metadata))

    def test_matching_input_and_output(self):
        self.assertEqual(check(self.root), 1)

    def test_geometry_input_change_requires_rebake(self):
        self.profile.write_text("road-v2")
        with self.assertRaisesRegex(ValueError, "입력 변경"):
            check(self.root)

    def test_generated_data_tampering_is_detected(self):
        self.output.write_bytes(b"unrelated-shape")
        with self.assertRaisesRegex(ValueError, "불일치"):
            check(self.root)

    def test_missing_data_is_detected(self):
        self.output.unlink()
        with self.assertRaisesRegex(ValueError, "누락/손상"):
            check(self.root)

    def test_cache_copied_from_another_course_is_rejected(self):
        other = self.folder.with_name("track_1")
        other.mkdir()
        for path in self.folder.iterdir():
            (other / path.name).write_bytes(path.read_bytes())
        with self.assertRaisesRegex(ValueError, "필수 입력 누락"):
            check(self.root)

    def test_missing_shared_dependency_is_rejected(self):
        path = self.folder / "collision.sources.json"
        data = json.loads(path.read_text())
        del data["inputs"]["res://tools/bake_world_collisions.gd"]
        path.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, "필수 입력 누락"):
            check(self.root)


if __name__ == "__main__":
    unittest.main()
