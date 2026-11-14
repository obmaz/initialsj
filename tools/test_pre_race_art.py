"""배포 UI 제작 원본·생성물의 동일성과 실제 입력 좌표를 검사한다. 새 시안은 별도 자료다."""
from pathlib import Path
import hashlib
import json
import unittest

import struct
import bake_pre_race_art

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art_sources/ui/runtime_sources/pre_race"
OUTPUT = ROOT / "assets/ui/pre_race"


class PreRaceArtTests(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads((SOURCE / "layout.json").read_text())

    def test_sources_and_shipped_images_match_manifest(self):
        self.assertEqual(self.manifest["schema"], 1)
        self.assertEqual(self.manifest["designSize"], [1280, 720])
        for name, expected in self.manifest["sources"].items():
            self.assertEqual(hashlib.sha256((SOURCE / name).read_bytes()).hexdigest(), expected, name)
        for name, expected in self.manifest["outputs"].items():
            self.assertEqual(hashlib.sha256((OUTPUT / name).read_bytes()).hexdigest(), expected, name)
        for screen in ["start", "home", "courses", "garage", "settings"]:
            data = (OUTPUT / (screen + ".png")).read_bytes()
            self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
            self.assertEqual(struct.unpack(">II", data[16:24]), (1280, 720), screen)

    def test_generated_frames_use_current_hit_rectangles(self):
        current = bake_pre_race_art.source_rects()
        compared = 0
        for screen, frames in self.manifest["screens"].items():
            for entry in frames:
                x, y, width, height = entry["rect"]
                self.assertGreater(width, 0, (screen, entry["id"]))
                self.assertGreater(height, 0, (screen, entry["id"]))
                self.assertGreaterEqual(x, 0)
                self.assertGreaterEqual(y, 0)
                self.assertLessEqual(x + width, 1280)
                self.assertLessEqual(y + height, 720)
                if entry["id"] in current:
                    self.assertEqual(entry["rect"], current[entry["id"]], (screen, entry["id"]))
                    compared += 1
        self.assertGreaterEqual(compared, 20)

    def test_native_and_web_settings_footer_is_not_baked(self):
        # 웹은 세 버튼, Android는 넓은 완료 버튼 하나를 같은 조각으로 그린다.
        ids = {entry["id"] for entry in self.manifest["screens"]["settings"]}
        self.assertTrue(ids.isdisjoint({"SETTINGS_FULLSCREEN", "SETTINGS_INSTALL", "SETTINGS_CLOSE"}))
        self.assertEqual(self.manifest["nineSliceMargin"], 20)


if __name__ == "__main__":
    unittest.main()
