"""원본 보존·호환 메시 유지·의도한 재생성의 백업을 검증한다."""
from pathlib import Path
import hashlib
import tempfile
import unittest
from unittest.mock import patch

import bake_tuning_models as baker
from glb_geometry import read, write, fingerprint, indices


class TuningSourceTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        root_patch = patch.object(baker, "ROOT", self.root)
        root_patch.start()
        self.addCleanup(root_patch.stop)
        replace_patch = patch.object(baker, "REPLACE_PARTS", False)
        replace_patch.start()
        self.addCleanup(replace_patch.stop)

    def source(self):
        doc = {"asset": {"version": "2.0"}, "buffers": [{}], "accessors": [], "bufferViews": [],
               "meshes": [], "nodes": [{"name": "BodyShell", "mesh": 0}], "scenes": [{"nodes": [0]}]}
        binary = bytearray()
        positions = [0, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 1, 1, 1, 0]
        attributes = {
            "POSITION": baker.append(doc, binary, positions, "VEC3"),
            "NORMAL": baker.append(doc, binary, [0, 1, 0]*6, "VEC3"),
            "COLOR_0": baker.append(doc, binary, [.3, .4, .5, .5]*3 + [.1, .1, .1, 1]*3, "VEC4"),
        }
        doc["meshes"] = [{"primitives": [{"attributes": attributes}]}]
        doc["buffers"][0]["byteLength"] = len(binary)
        path = self.root / "model_sources/vehicles/hatch/model.glb"
        path.parent.mkdir(parents=True)
        path.write_bytes(write(doc, binary))
        (self.root / "models/vehicles/hatch").mkdir(parents=True)
        return path

    def test_split_preserves_legacy_geometry_and_backups(self):
        path = self.source()
        before = path.read_bytes()
        doc, binary = read(before)
        expected = fingerprint(doc, binary, doc["meshes"][0])
        baker.paint_shell("hatch")
        doc, binary = read(path.read_bytes())
        nodes = {node["name"]: node for node in doc["nodes"]}
        legacy = doc["meshes"][nodes["BodyShell"]["mesh"]]
        self.assertEqual(fingerprint(doc, binary, legacy), expected)
        count = lambda name: len(indices(doc, binary, doc["meshes"][nodes[name]["mesh"]]["primitives"][0]))
        self.assertEqual(count("PaintShell") + count("TrimShell"), count("BodyShell"))
        backup = self.root / "build/reports/model-backups" / ("hatch-" + hashlib.sha256(before).hexdigest()[:12] + ".glb")
        self.assertEqual(backup.read_bytes(), before)

    def test_existing_split_is_not_rewritten(self):
        path = self.source()
        baker.paint_shell("hatch")
        before = path.read_bytes()
        baker.paint_shell("hatch")
        self.assertEqual(path.read_bytes(), before)

    def part(self):
        mesh = baker.Mesh()
        mesh.tri((0, 0, 0), (1, 0, 0), (0, 1, 0), (1, 1, 1, 1))
        path = self.root / "model_sources/vehicle_parts/artist_part/model.glb"
        path.parent.mkdir(parents=True)
        path.write_bytes(b"artist-authored-source")
        return mesh, path

    def test_normal_bake_does_not_replace_authored_parts(self):
        mesh, path = self.part()
        mesh.save("artist_part")
        self.assertEqual(path.read_bytes(), b"artist-authored-source")

    def test_explicit_replace_keeps_the_exact_previous_bytes(self):
        mesh, path = self.part()
        with patch.object(baker, "REPLACE_PARTS", True):
            mesh.save("artist_part")
        backups = list((self.root / "build/reports/model-backups").glob("*.glb"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_bytes(), b"artist-authored-source")
        self.assertNotEqual(path.read_bytes(), b"artist-authored-source")
