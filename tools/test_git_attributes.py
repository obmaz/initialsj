"""Windows 방식의 Git 체크아웃에서도 텍스트·충돌 바이너리의 해시를 보존합니다."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which("git"), "Git이 필요한 체크아웃 계약 검사입니다")
class CheckoutBytesTests(unittest.TestCase):
    def test_autocrlf_checkout_keeps_lf_text_and_binary_bytes(self):
        text = "# 한글과 LF 줄바꿈\nvalue = 1\n".encode()
        binary = b"\x00binary\r\nunchanged\n\xff"
        files = {
            "scripts/sample.gd": text,
            "models/world/sample/profile.tres": text,
            "models/world/sample/model.tscn": text,
            "models/world/sample/collision.sources.json": text,
            "scripts/sample.gd.uid": text,
            "shaders/sample.gdshader": text,
            "shaders/sample.gdshaderinc": text,
            "export_presets.cfg": text,
            "project.godot": text,
            "tools/sample.py": text,
            "tools/sample.sh": text,
            "models/world/sample/geometry.glb": binary,
            "models/world/sample/collision.res": binary,
        }
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            repository = root / "repository"
            repository.mkdir()
            # 저장소 로컬 설정만 사용한다. 사용자의 Git 설정과 작업 트리는 바꾸지 않는다.
            subprocess.run(["git", "init", "--quiet", str(repository)], check=True)
            command = ["git", "-C", str(repository), "-c", "core.autocrlf=true", "-c", "core.safecrlf=false"]
            (repository / ".gitattributes").write_bytes((ROOT / ".gitattributes").read_bytes())
            for name, data in files.items():
                path = repository / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
            subprocess.run([*command, "add", "--all"], check=True, capture_output=True)
            checkout = root / "checkout"
            checkout.mkdir()
            subprocess.run(
                [*command, "checkout-index", "--all", "--prefix=" + checkout.as_posix() + "/"],
                check=True, capture_output=True,
            )
            for name, data in files.items():
                with self.subTest(path=name):
                    self.assertEqual((checkout / name).read_bytes(), data)


if __name__ == "__main__":
    unittest.main()
