"""리소스 검사기가 정상 include·문서 링크를 허용하고 실제 누락을 잡는지 검사합니다."""
import tempfile
import unittest
from pathlib import Path, PureWindowsPath
from unittest.mock import MagicMock, patch

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
        for name in ("README.md", "AGENTS.md", "CLAUDE.md", "GEMINI.md", "addons/app_version/version_export.gd"):
            self.write(name, "")

    def write(self, name, source):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(source, encoding="utf-8")
        return path

    def test_shared_subresource_file_and_missing_id(self):
        self.write("models/world/urban/assembly/resources.tres",
                   '[gd_resource type="Resource" format=3]\n[sub_resource type="StandardMaterial3D" id="wall"]\n')
        source = '\n'.join(['"res://models/world/urban/assembly/resources.tres::wall"',
                            '"res://models/world/urban/assembly/resources.tres::absent"'])
        self.assertEqual(verify.resource_refs(source),
                         ["models/world/urban/assembly/resources.tres"] * 2)
        self.assertEqual(verify.errors,
                         ["Missing subresource: models/world/urban/assembly/resources.tres::absent"])

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

    def test_shader_directory_does_not_hide_unused_sources(self):
        self.write("project.godot", 'warm="res://shaders/"\nshader="res://shaders/used.gdshader"\n')
        self.write("export_presets.cfg", "")
        self.write("web/retire-flutter-worker.js", "")
        for name in ("used", "unused"):
            self.write(f"shaders/{name}.gdshader", "shader_type spatial;\n")
            self.write(f"shaders/{name}.gdshader.uid", "uid://test\n")
        reached = verify.live_resources()
        self.assertEqual(verify.errors, [])
        self.assertNotIn("shaders/unused.gdshader", reached)
        verify.check_sources(reached)
        self.assertIn("Unreferenced runtime source: shaders/unused.gdshader", verify.errors)

    def test_unused_sampler_is_not_kept_alive_by_comments(self):
        self.write("shaders/ground.gdshader", '''shader_type spatial;
uniform sampler2D retired;
// retired used to be sampled here.
/* retired */
void fragment() { ALBEDO = vec3(1.0); }
''')
        verify.check_shader_samplers()
        self.assertEqual(verify.errors, ["Unused shader sampler in shaders/ground.gdshader: retired"])

    def test_windows_shader_error_uses_portable_relative_path(self):
        root = MagicMock()
        path = MagicMock()
        path.relative_to.return_value = PureWindowsPath("shaders/ground.gdshader")
        (root / "shaders").rglob.return_value = [path]
        with patch.object(verify, "ROOT", root), patch.object(
            verify, "expanded_shader", return_value="uniform sampler2D retired;"
        ):
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
