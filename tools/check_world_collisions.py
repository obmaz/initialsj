"""주행 GLB·프로필과 생성된 정적 충돌 자료의 신선도를 검사한다."""
from pathlib import Path
import hashlib
import json
import re


ROOT = Path(__file__).resolve().parents[1]


def check(root=ROOT):
    failures = []
    count = 0
    digests = {}
    generator = root / "tools/bake_world_collisions.gd"
    match = re.search(r"const INPUTS := \[(.*?)\]", generator.read_text(), re.S)
    if match is None:
        raise ValueError("충돌 자료 생성기의 필수 입력 목록이 없습니다")
    shared_inputs = set(re.findall(r'"(res://[^\"]+)"', match.group(1)))
    if not shared_inputs:
        raise ValueError("충돌 자료 생성기의 필수 입력 목록이 비어 있습니다")

    def digest(path):
        if path not in digests:
            digests[path] = hashlib.sha256(path.read_bytes()).hexdigest()
        return digests[path]

    for profile in sorted((root / "models/world").glob("*/profile.tres")):
        folder = profile.parent
        output = folder / "collision.res"
        metadata_path = folder / "collision.sources.json"
        try:
            metadata = json.loads(metadata_path.read_text())
            if metadata["schema"] != 1 or not metadata["inputs"]:
                raise ValueError("invalid schema")
            required = shared_inputs | {
                "res://" + profile.relative_to(root).as_posix(),
                "res://" + (folder / "model.tscn").relative_to(root).as_posix(),
            }
            required.update("res://" + path.relative_to(root).as_posix()
                            for path in (folder / "assembly").glob("*")
                            if path.suffix in (".tres", ".tscn"))
            if not required.issubset(metadata["inputs"]):
                raise ValueError("해당 코스·공통 생성 코드의 필수 입력 누락")
            for uri, expected in metadata["inputs"].items():
                path = root / uri.removeprefix("res://")
                if not path.is_file() or digest(path) != expected:
                    failures.append(f"충돌 자료 입력 변경: {uri} ({folder.name})")
            if digest(output) != metadata["sha256"]:
                failures.append(f"충돌 자료 불일치: {output.relative_to(root)}")
            if metadata["groundTriangles"] <= 0 or metadata["barrierTriangles"] <= 0:
                raise ValueError("empty collision")
            count += 1
        except (OSError, ValueError, KeyError) as error:
            failures.append(f"충돌 자료 누락/손상: {folder.name}: {error}")
    if count == 0:
        failures.append("정적 충돌 자료가 없습니다")
    if failures:
        raise ValueError("\n".join(failures) + "\n./tools/godot --headless --path . --script res://tools/bake_world_collisions.gd 로 다시 생성하세요.")
    return count


if __name__ == "__main__":
    print(f"정적 충돌 자료·입력 해시: PASS ({check()}개 코스)")
