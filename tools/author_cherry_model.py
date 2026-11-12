"""기존 원본을 보존하고 벚꽃 전용 실척 GLB를 새 팩으로 파생합니다."""
from pathlib import Path
import copy
import math
import struct
from glb_geometry import read, write

ROOT = Path(__file__).resolve().parents[1]


def main():
    source = ROOT / "model_sources/shared/world_vegetation/town_oak_0/model.glb"
    destination = ROOT / "model_sources/props/cherry_blossom_tree/model.glb"
    if destination.exists():
        raise SystemExit("이미 만든 벚꽃 원본은 덮어쓰지 않습니다: " + str(destination))
    doc, binary = read(source.read_bytes())
    data = bytearray(binary)
    scale = (1.22, .78, 1.22)
    seen = set()
    primitives = doc["meshes"][0]["primitives"]
    for primitive in primitives:
        for semantic in ("POSITION", "NORMAL", "TANGENT"):
            index = primitive["attributes"][semantic]
            if index in seen:
                continue
            seen.add(index)
            item = doc["accessors"][index]
            assert item["componentType"] == 5126
            view = doc["bufferViews"][item["bufferView"]]
            width = 4 if semantic == "TANGENT" else 3
            stride = view.get("byteStride", width * 4)
            offset = view.get("byteOffset", 0) + item.get("byteOffset", 0)
            positions = []
            for i in range(item["count"]):
                values = list(struct.unpack_from("<" + "f" * width, data, offset + i * stride))
                for axis in range(3):
                    values[axis] *= (1 / scale[axis]) if semantic == "NORMAL" else scale[axis]
                if semantic != "POSITION":
                    length = math.sqrt(sum(x * x for x in values[:3]))
                    values[:3] = [x / max(length, 1e-9) for x in values[:3]]
                else:
                    positions.append(values[:3])
                struct.pack_into("<" + "f" * width, data, offset + i * stride, *values)
            if positions:
                item["min"] = [min(p[a] for p in positions) for a in range(3)]
                item["max"] = [max(p[a] for p in positions) for a in range(3)]
    doc["nodes"] = [{"name": "Model", "children": [1, 2]}, {"name": "Bark", "mesh": 0}, {"name": "Blossoms", "mesh": 1}]
    doc["scenes"] = [{"nodes": [0]}]
    doc["scene"] = 0
    doc["materials"] = [{"name": "Bark"}, {"name": "Blossoms", "doubleSided": True}]
    doc["meshes"] = []
    for index, name in enumerate(["Bark", "Blossoms"]):
        primitive = copy.deepcopy(primitives[index])
        primitive["material"] = index
        doc["meshes"].append({"name": name, "primitives": [primitive]})
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(write(doc, data))
    print("새 벚꽃 원본:", destination)


if __name__ == "__main__":
    main()
