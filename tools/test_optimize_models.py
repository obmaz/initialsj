"""형상·UV 경계 보존, 원본 누락·변조·경로 이탈 및 재생성 계약을 검사합니다."""
import copy
import json
from pathlib import Path
import struct
import tempfile
import unittest

import glb_geometry as glb
import optimize_models as pipeline


def fixture():
    positions = [(0., 0., 0.), (1., 0., 0.), (0., 1., 0.)] * 2 + [(0., 0., 0.)]
    uv = [(0., 0.), (1., 0.), (0., 1.)] * 2 + [(0.5, 0.5)]
    data = bytearray()
    accessors, views = [], []
    for values, kind in [(positions, "VEC3"), ([(0., 0., 1.)] * 7, "VEC3"), (uv, "VEC2")]:
        raw = b"".join(struct.pack("<" + "f" * len(v), *v) for v in values)
        views.append({"buffer": 0, "byteOffset": len(data), "byteLength": len(raw)})
        data.extend(raw)
        accessors.append({"bufferView": len(views) - 1, "componentType": 5126, "count": 7, "type": kind})
    raw = struct.pack("<9H", 0, 1, 2, 3, 4, 5, 6, 1, 2)
    views.append({"buffer": 0, "byteOffset": len(data), "byteLength": len(raw)})
    data.extend(raw)
    accessors.append({"bufferView": 3, "componentType": 5123, "count": 9, "type": "SCALAR"})
    primitive = {"attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2}, "indices": 3, "mode": 4}
    doc = {"asset": {"version": "2.0"}, "buffers": [{"byteLength": len(data)}], "bufferViews": views,
           "accessors": accessors, "meshes": [{"primitives": [primitive]}],
           "nodes": [{"name": "Visual", "mesh": 0, "translation": [1, 2, 3]}], "scenes": [{"nodes": [0]}], "scene": 0}
    return glb.write(doc, data)


class ModelPipelineChecks(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.source = self.root / "model_sources"
        self.path = self.source / "world/test/geometry.glb"
        self.path.parent.mkdir(parents=True)
        self.path.write_bytes(fixture())
        self.recipe = {"schema": 1, "trees": {}, "bindings": {}}
        self.registry()

    def registry(self):
        records = {p.relative_to(self.source).as_posix(): pipeline.digest(p.read_bytes()) for p in self.source.rglob("*.glb")}
        (self.source / "inventory.json").write_bytes(pipeline.encoded({"schema": 1, "files": records}))
        (self.source / "world-vegetation.json").write_bytes(pipeline.encoded(self.recipe))

    def expanded(self, doc, binary, primitive):
        values = glb.indices(doc, binary, primitive)
        result = {}
        for key, index in primitive["attributes"].items():
            raw, width = glb.accessor(doc, binary, index)
            result[key] = b"".join(raw[v * width:(v + 1) * width] for v in values)
        return result

    def test_weld_preserves_triangles_uv_seams_and_transforms(self):
        doc, binary = glb.read(fixture())
        new, packed = glb.read(glb.optimize(doc, binary))
        a, b = doc["meshes"][0]["primitives"][0], new["meshes"][0]["primitives"][0]
        self.assertEqual(self.expanded(doc, binary, a), self.expanded(new, packed, b))
        self.assertEqual(new["accessors"][b["attributes"]["POSITION"]]["count"], 4)
        self.assertEqual(new["nodes"], doc["nodes"])

    def test_rebuild_is_deterministic_and_never_writes_source(self):
        before = self.path.read_bytes(), self.path.stat().st_mtime_ns
        pipeline.run(self.root)
        target = self.root / "models/world/test/geometry.glb"
        generated = target.read_bytes(), target.stat().st_mtime_ns
        pipeline.run(self.root)
        pipeline.run(self.root, check=True)
        self.assertEqual(before, (self.path.read_bytes(), self.path.stat().st_mtime_ns))
        self.assertEqual(generated, (target.read_bytes(), target.stat().st_mtime_ns))

    def test_missing_original_is_rejected_even_when_accepting_changes(self):
        self.path.unlink()
        for accept in (False, True):
            with self.assertRaisesRegex(ValueError, "보호된 원본"):
                pipeline.run(self.root, accept=accept)
        self.assertFalse((self.root / "models").exists())

    def test_source_edit_needs_explicit_acceptance_and_is_preserved(self):
        doc, binary = glb.read(self.path.read_bytes())
        doc["nodes"][0]["translation"] = [8, 0, 0]
        changed = glb.write(doc, binary)
        self.path.write_bytes(changed)
        with self.assertRaisesRegex(ValueError, "의도한 편집"):
            pipeline.run(self.root)
        pipeline.run(self.root, accept=True)
        self.assertEqual(self.path.read_bytes(), changed)

    def test_modified_output_is_detected_and_can_be_regenerated(self):
        pipeline.run(self.root)
        target = self.root / "models/world/test/geometry.glb"
        target.write_bytes(b"edited generated output")
        with self.assertRaisesRegex(ValueError, "생성물을 직접 편집"):
            pipeline.run(self.root, check=True)
        pipeline.run(self.root)
        pipeline.run(self.root, check=True)

    def test_output_cannot_follow_symlink_into_source(self):
        (self.root / "models").mkdir()
        (self.root / "models/world").symlink_to(self.source / "world", target_is_directory=True)
        before = self.path.read_bytes()
        with self.assertRaisesRegex(ValueError, "models/"):
            pipeline.run(self.root)
        self.assertEqual(before, self.path.read_bytes())

    def test_runtime_glb_without_original_is_rejected(self):
        pipeline.run(self.root)
        extra = self.root / "models/temporary.glb"
        extra.write_bytes(fixture())
        with self.assertRaisesRegex(ValueError, "등록되지 않은 배포 GLB"):
            pipeline.run(self.root, check=True)

    def test_source_only_keeps_original_protected_without_shipped_output(self):
        registry = self.source / "inventory.json"
        inventory = json.loads(registry.read_text())
        inventory["source_only"] = ["world/test/geometry.glb"]
        registry.write_bytes(pipeline.encoded(inventory))
        before = self.path.read_bytes(), self.path.stat().st_mtime_ns
        pipeline.run(self.root)
        pipeline.run(self.root, check=True)
        self.assertEqual(before, (self.path.read_bytes(), self.path.stat().st_mtime_ns))
        self.assertFalse((self.root / "models/world/test/geometry.glb").exists())
        self.path.unlink()
        for accept in (False, True):
            with self.assertRaisesRegex(ValueError, "보호된 원본"):
                pipeline.run(self.root, accept=accept)

    def test_source_only_does_not_delete_existing_output(self):
        pipeline.run(self.root)
        registry = self.source / "inventory.json"
        inventory = json.loads(registry.read_text())
        inventory["source_only"] = ["world/test/geometry.glb"]
        registry.write_bytes(pipeline.encoded(inventory))
        target = self.root / "models/world/test/geometry.glb"
        before = target.read_bytes()
        pipeline.run(self.root)
        self.assertEqual(target.read_bytes(), before)
        with self.assertRaisesRegex(ValueError, "등록되지 않은 배포 GLB"):
            pipeline.run(self.root, check=True)

    def test_common_tree_edit_keeps_course_binding_and_original_snapshot(self):
        doc, binary = glb.read(self.path.read_bytes())
        doc["meshes"][0]["primitives"].append(copy.deepcopy(doc["meshes"][0]["primitives"][0]))
        original = glb.write(doc, binary)
        self.path.write_bytes(original)
        tree = self.source / "shared/world_vegetation/tree/model.glb"
        tree.parent.mkdir(parents=True)
        tree.write_bytes(glb.single_mesh(doc, binary, 0))
        self.recipe["trees"] = {"tree": {"source": tree.relative_to(self.source).as_posix()}}
        self.recipe["bindings"] = {"world/test/geometry.glb": {"Visual": {"tree": "tree", "geometry_sha256": glb.fingerprint(doc, binary, doc["meshes"][0])}}}
        self.registry()
        pipeline.run(self.root)
        manifest = self.root / "models/shared/world_vegetation/references.json"
        before = manifest.read_bytes()
        edited, data = glb.read(tree.read_bytes())
        edited["asset"]["generator"] = "intentional artist edit"
        tree.write_bytes(glb.write(edited, data))
        pipeline.run(self.root, accept=True)
        self.assertEqual(manifest.read_bytes(), before)
        self.assertEqual(self.path.read_bytes(), original)
        runtime, _ = glb.read((self.root / "models/world/test/geometry.glb").read_bytes())
        self.assertEqual(runtime["meshes"], [])


if __name__ == "__main__":
    unittest.main()
