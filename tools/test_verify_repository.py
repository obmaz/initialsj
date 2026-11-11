"""리소스 검사기가 정상 include·문서 링크를 허용하고 실제 누락을 잡는지 검사합니다."""
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import verify_repository as verify


class RepositoryChecks(unittest.TestCase):
    def setUp(self):
        self.workspace = tempfile.TemporaryDirectory()
        self.addCleanup(self.workspace.cleanup)
        self.root = Path(self.workspace.name)
        self.patch = patch.object(verify, "ROOT", self.root)
        self.patch.start()
        self.addCleanup(self.patch.stop)
        verify.errors.clear()
        for name in ("README.md", "AGENTS.md", "CLAUDE.md", "GEMINI.md"):
            self.write(name, "")

    def write(self, name, source):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(source, encoding="utf-8")
        return path

    def test_missing_and_orphan_sidecars(self):
        self.write("scripts/physics/car.gd", "extends RefCounted\n")
        self.write("assets/unused.png.import", "")
        verify.check_sources({"scripts/physics/car.gd"})
        self.assertIn("Missing sidecar: scripts/physics/car.gd.uid", verify.errors)
        self.assertIn("Orphan sidecar: assets/unused.png.import", verify.errors)

    def test_model_catalog_keeps_dynamic_resources_reachable(self):
        self.write("project.godot", 'catalog="res://models/props"\n')
        self.write("export_presets.cfg", "")
        self.write("web/retire-flutter-worker.js", "")
        self.write("models/props/tree/definition.tres", 'mesh="res://models/props/tree/tree.obj"')
        self.write("models/props/tree/tree.obj", "v 0 0 0\n")
        reached = verify.live_resources()
        self.assertIn("models/props/tree/definition.tres", reached)
        self.assertIn("models/props/tree/tree.obj", reached)
        self.assertEqual(verify.errors, [])

    def test_shader_include_usage_is_not_reported_as_unused(self):
        self.write("shaders/ground.gdshader", '''shader_type spatial;
uniform sampler2D terrain;
#include "res://shaders/sample.gdshaderinc"
void fragment() { ALBEDO = surface(); }
''')
        self.write("shaders/sample.gdshaderinc", "vec3 surface() { return texture(terrain, UV).rgb; }")
        verify.check_shader_samplers()
        self.assertEqual(verify.errors, [])

    def test_unused_sampler_is_not_kept_alive_by_comments(self):
        self.write("shaders/ground.gdshader", '''shader_type spatial;
uniform sampler2D retired;
// retired used to be sampled here.
/* retired */
void fragment() { ALBEDO = vec3(1.0); }
''')
        verify.check_shader_samplers()
        self.assertEqual(verify.errors, ["Unused shader sampler in shaders/ground.gdshader: retired"])

    def test_korean_anchors_spaces_and_duplicate_headings(self):
        self.write("docs/개발 안내.md", "# 실행과 검사\n# 실행과 검사\n```gdscript\n# 가짜 제목\n```\n")
        readme = self.write("README.md", "[실행](<docs/개발 안내.md#실행과-검사-1>)\n")
        verify.check_docs()
        self.assertEqual(verify.errors, [])
        readme.write_text("[없음](<docs/개발 안내.md#가짜-제목>)\n", encoding="utf-8")
        verify.check_docs()
        self.assertEqual(verify.errors, ["Broken anchor in README.md: docs/개발 안내.md#가짜-제목"])


if __name__ == "__main__":
    unittest.main()
