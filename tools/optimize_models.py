#!/usr/bin/env python3
"""편집 원본을 보존하며 코스 GLB를 생성합니다. 삭제·원본 덮어쓰기 옵션은 없습니다."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import tempfile

from glb_geometry import fingerprint, optimize, read

ROOT = Path(__file__).resolve().parents[1]
VERSION = 1


def digest(data):
    return hashlib.sha256(data).hexdigest()


def encoded(value):
    return (json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode()


def source_path(root, name):
    base = (root / "model_sources").resolve()
    path = base / name
    if not path.resolve().is_relative_to(base) or path.is_symlink():
        raise ValueError("원본 경로 이탈·심볼릭 링크 금지: " + name)
    if not path.is_file():
        raise ValueError("보호된 원본이 없습니다. 삭제하지 말고 Git에서 복원하세요: " + name)
    return path


def output_path(root, name):
    base = (root / "models").resolve()
    path = root / name
    if not path.resolve().is_relative_to(base) or path.is_symlink():
        raise ValueError("생성물은 models/ 안에만 기록할 수 있습니다: " + name)
    return path


def atomic_write(path, data):
    if path.is_file() and path.read_bytes() == data:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".model-", delete=False) as file:
            temporary = Path(file.name)
            file.write(data)
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def inputs(root, accept=False):
    source = root / "model_sources"
    registry_path = source / "inventory.json"
    inventory = json.loads(registry_path.read_text(encoding="utf-8"))
    if inventory.get("schema") != 1:
        raise ValueError("원본 목록의 계약 버전을 확인하세요")
    records = inventory["files"]
    source_only = inventory.get("source_only", [])
    if not isinstance(source_only, list) or any(not isinstance(name, str) or name not in records for name in source_only):
        raise ValueError("원본 전용 항목은 보호 목록에 등록된 경로여야 합니다")
    # 입력을 모두 검사한 후에만 생성물을 기록한다. 수동으로 목록을 줄여 원본을 지우지 않는다.
    for name in records:
        source_path(root, name)
    found = {p.relative_to(source).as_posix(): digest(p.read_bytes()) for p in source.rglob("*.glb")}
    for name in found:
        source_path(root, name)
    changed = [name for name in sorted(set(records) | set(found)) if records.get(name) != found.get(name)]
    if changed and not accept:
        raise ValueError("원본이 수정·추가됐습니다. 의도한 편집이면 --accept-source-changes로 해시를 갱신하세요: " + ", ".join(changed))
    if changed:
        inventory["files"] = found
        atomic_write(registry_path, encoded(inventory))
    recipe = json.loads((source / "world-vegetation.json").read_text(encoding="utf-8"))
    if set(source_only) & {tree["source"] for tree in recipe["trees"].values()}:
        raise ValueError("연결된 공통 식생은 원본 전용으로 바꿀 수 없습니다")
    return found, recipe, sorted(set(source_only))


def generate(root, records, recipe, source_only=()):
    outputs = {}
    references, dependencies, scenes = {}, {}, {}
    for name, tree in recipe["trees"].items():
        path = tree["source"]
        if path not in records:
            raise ValueError("공통 식생 원본이 목록에 없습니다: " + path)
        data = source_path(root, path).read_bytes()
        doc, binary = read(data)
        nodes = [n for n in doc["nodes"] if "mesh" in n]
        if len(nodes) != 1 or nodes[0].get("name") != "Visual" or len(doc["meshes"][nodes[0]["mesh"]]["primitives"]) != 2:
            raise ValueError("공통 식생은 Visual 노드와 줄기·잎 두 표면이 필요합니다: " + name)
        for node in doc["nodes"]:
            if (node.get("translation", [0, 0, 0]) != [0, 0, 0]
                    or node.get("rotation", [0, 0, 0, 1]) != [0, 0, 0, 1]
                    or node.get("scale", [1, 1, 1]) != [1, 1, 1]
                    or node.get("matrix", [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]) != [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]):
                raise ValueError("공통 식생은 내보내기 전에 노드 변환을 형상에 적용하세요: " + name)
        # 단일 메시 GLB를 Godot이 루트 MeshInstance로 임포트하더라도 연결점은 항상 Visual이다.
        doc["nodes"] = [{"name": "Model", "children": [1]}, nodes[0]]
        doc["scenes"] = [{"nodes": [0]}]
        doc["scene"] = 0
        outputs["models/" + path] = optimize(doc, binary)
        scene_path = "models/" + path.removesuffix(".glb") + ".tscn"
        outputs[scene_path] = ('[gd_scene load_steps=2 format=3]\n\n'
                               '[ext_resource type="PackedScene" path="res://models/' + path + '" id="1"]\n\n'
                               '[node name="' + name + '" instance=ExtResource("1")]\n').encode()
        scenes["res://models/" + path] = "res://" + scene_path
    for name in records:
        if name in source_only or name in {tree["source"] for tree in recipe["trees"].values()}:
            continue
        data = source_path(root, name).read_bytes()
        if name.startswith("world/"):
            doc, binary = read(data)
            nodes = {n["name"]: n for n in doc["nodes"] if "mesh" in n}
            remove = set()
            deps = {"res://models/" + name}
            for node_name, binding in recipe["bindings"].get(name, {}).items():
                node = nodes.get(node_name)
                if node is None:
                    raise ValueError("원본의 연결 노드 이름이 바뀌었습니다: " + name + "#" + node_name)
                if fingerprint(doc, binary, doc["meshes"][node["mesh"]]) != binding["geometry_sha256"]:
                    raise ValueError("공유 식생은 해당 전용 원본에서 편집하세요. 코스의 식생 스냅샷이 달라졌습니다: " + name + "#" + node_name)
                target = "res://models/" + recipe["trees"][binding["tree"]]["source"]
                references["res://models/" + name + "#" + node_name] = target + "#Visual"
                deps.add(scenes[target])
                remove.add(node["mesh"])
            dependencies["res://models/" + name] = sorted(deps)
            outputs["models/" + name] = optimize(doc, binary, remove)
        else:
            # 독립 모델은 제작자의 GLB 바이트를 그대로 전달한다. 코스만 동일 정점 병합 대상이다.
            outputs["models/" + name] = data
    outputs["models/shared/world_vegetation/references.json"] = encoded({"schema": 1, "references": references, "dependencies": dependencies, "scenes": scenes})
    return outputs


def state(root, records, recipe, outputs, source_only=()):
    tool_hash = digest(Path(__file__).read_bytes() + Path(__file__).with_name("glb_geometry.py").read_bytes())
    return {"schema": VERSION, "tool_sha256": tool_hash, "sources": records, "source_only": list(source_only), "recipe_sha256": digest(encoded(recipe)),
            "outputs": {name: digest(data) for name, data in sorted(outputs.items())}}


def run(root=ROOT, check=False, accept=False):
    records, recipe, source_only = inputs(root, accept)
    stamp_path = root / "models/shared/world_vegetation/generated.json"
    if check:
        stamp = json.loads(stamp_path.read_text(encoding="utf-8"))
        actual = state(root, records, recipe, {}, source_only)
        for key in ("schema", "tool_sha256", "sources", "source_only", "recipe_sha256"):
            if stamp.get(key) != actual[key]:
                raise ValueError("최적화 결과가 오래됐습니다. tools/optimize_models.py를 실행하세요: " + key)
        for name, checksum in stamp["outputs"].items():
            path = output_path(root, name)
            if not path.is_file() or digest(path.read_bytes()) != checksum:
                raise ValueError("생성물을 직접 편집했거나 파일이 없습니다. 원본에서 재생성하세요: " + name)
        registered = {name for name in stamp["outputs"] if name.endswith(".glb")}
        actual_glbs = {path.relative_to(root).as_posix() for path in (root / "models").rglob("*.glb")}
        if actual_glbs != registered:
            raise ValueError("원본·생성 목록에 등록되지 않은 배포 GLB가 있습니다: " + ", ".join(sorted(actual_glbs ^ registered)))
        print("GLB 원본 보존·입력 해시·생성물 일치: PASS (%d개 원본)" % len(records))
        return
    outputs = generate(root, records, recipe, source_only)
    # 출력 경로를 전부 검증하고 원본 해시를 재확인한다. 중간에 편집한 입력으로 기록하지 않는다.
    for name in outputs:
        output_path(root, name)
    for name, checksum in records.items():
        if digest(source_path(root, name).read_bytes()) != checksum:
            raise ValueError("생성 도중 원본이 변경됐습니다: " + name)
    for name, data in outputs.items():
        atomic_write(output_path(root, name), data)
    atomic_write(stamp_path, encoded(state(root, records, recipe, outputs, source_only)))
    print("GLB 생성 완료: 원본 %d개 보존, 배포 파일 %d개" % (len(records), len(outputs)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="파일을 쓰지 않고 원본·생성물 해시를 검사")
    parser.add_argument("--accept-source-changes", action="store_true", help="의도한 원본 편집·추가의 해시 갱신. 누락된 원본은 허용하지 않음")
    args = parser.parse_args()
    if args.check and args.accept_source_changes:
        parser.error("--check와 원본 목록 갱신은 함께 사용할 수 없습니다")
    try:
        run(check=args.check, accept=args.accept_source_changes)
    except (ValueError, OSError, KeyError) as error:
        parser.exit(1, str(error) + "\n")


if __name__ == "__main__":
    main()
