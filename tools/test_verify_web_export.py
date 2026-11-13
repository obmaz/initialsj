"""기본 엔진 워커·누락 산출물·엇갈린 셸을 게시 전에 차단하는지 검사한다."""
import json
from pathlib import Path
import tempfile
import unittest

from verify_web_export import verify


class WebExportChecks(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.folder = Path(temporary.name)
        self.index = self.folder / "index.html"
        self.worker = self.folder / "index.service.worker.js"
        version = "a" * 64
        config = {"version": version, "index": "index.html", "offline": "index.offline.html",
                  "coreFiles": ["index.html", "index.offline.html"], "engineFiles": ["index.wasm", "index.pck"]}
        self.index.write_text(f'window.INITIALSJ_OFFLINE_VERSION = "{version}"; window.initialsjOffline = (function () {{}}());')
        self.worker.write_text("const CONFIG = " + json.dumps(config) + ";\n")
        for name in ["index.offline.html", "index.wasm", "index.pck"]:
            (self.folder / name).write_bytes(b"fixture")

    def test_valid_generated_export(self):
        verify(self.index)

    def test_default_worker_is_rejected(self):
        self.worker.write_text("const CACHE_NAME = 'Godot default';")
        with self.assertRaisesRegex(ValueError, "관리 워커"):
            verify(self.index)

    def test_missing_pack_and_mismatched_shell_are_rejected(self):
        (self.folder / "index.pck").unlink()
        with self.assertRaisesRegex(ValueError, "파일 누락"):
            verify(self.index)
        self.index.write_text(self.index.read_text().replace("a" * 64, "b" * 64))
        with self.assertRaisesRegex(ValueError, "버전"):
            verify(self.index)
