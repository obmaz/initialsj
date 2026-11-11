"""GLB 정적 형상의 바이트 보존 읽기·쓰기와 동일 정점 병합. 외부 패키지를 사용하지 않습니다."""
import copy
import hashlib
import json
import struct

COMPONENTS = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
WIDTHS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def read(data):
    magic, version, length = struct.unpack_from("<III", data)
    if magic != 0x46546C67 or version != 2 or length != len(data):
        raise ValueError("유효한 GLB 2 파일이 아닙니다")
    size, kind = struct.unpack_from("<II", data, 12)
    if kind != 0x4E4F534A:
        raise ValueError("GLB JSON 청크 누락")
    doc = json.loads(data[20:20 + size])
    offset = 20 + size
    binary = data[offset + 8:] if offset < len(data) else b""
    return doc, binary


def static_document(doc):
    if any(doc.get(key) for key in ("images", "animations", "skins")):
        raise ValueError("코스 최적화 입력은 이미지·스킨·애니메이션 없는 정적 GLB여야 합니다")
    if len(doc.get("buffers", [])) != 1:
        raise ValueError("단일 내장 버퍼가 필요합니다")
    for mesh in doc.get("meshes", []):
        for primitive in mesh["primitives"]:
            if primitive.get("targets") or primitive.get("extensions"):
                raise ValueError("모프·압축 확장 형상은 명시적인 어댑터가 필요합니다")


def accessor(doc, binary, index):
    item = doc["accessors"][index]
    if "sparse" in item:
        raise ValueError("희소 접근자는 지원하지 않습니다")
    view = doc["bufferViews"][item["bufferView"]]
    width = COMPONENTS[item["componentType"]] * WIDTHS[item["type"]]
    stride = view.get("byteStride", width)
    start = view.get("byteOffset", 0) + item.get("byteOffset", 0)
    count = item["count"]
    if count and start + (count - 1) * stride + width > len(binary):
        raise ValueError("접근자가 GLB 버퍼 경계를 벗어납니다")
    if stride == width:
        return binary[start:start + count * width], width
    return b"".join(binary[start + i * stride:start + i * stride + width] for i in range(count)), width


def indices(doc, binary, primitive):
    if "indices" not in primitive:
        return list(range(doc["accessors"][primitive["attributes"]["POSITION"]]["count"]))
    item = doc["accessors"][primitive["indices"]]
    code = {5121: "B", 5123: "H", 5125: "I"}[item["componentType"]]
    data, _ = accessor(doc, binary, primitive["indices"])
    return [v[0] for v in struct.iter_unpack("<" + code, data)]


def fingerprint(doc, binary, mesh):
    """재질을 제외한 모든 표면 속성·삼각형 순서를 비교합니다. 재질은 코스 씬이 소유합니다."""
    digest = hashlib.sha256()
    for primitive in mesh["primitives"]:
        for semantic, index in sorted(primitive["attributes"].items()):
            item = doc["accessors"][index]
            digest.update(json.dumps([semantic, item["componentType"], item["type"], item["count"], item.get("normalized", False)]).encode())
            digest.update(accessor(doc, binary, index)[0])
        digest.update(str(primitive.get("mode", 4)).encode())
        values = indices(doc, binary, primitive)
        digest.update(struct.pack("<%dI" % len(values), *values))
    return digest.hexdigest()


def write(doc, binary):
    payload = json.dumps(doc, ensure_ascii=False, separators=(",", ":")).encode()
    payload += b" " * (-len(payload) % 4)
    binary = bytes(binary) + b"\0" * (-len(binary) % 4)
    size = 12 + 8 + len(payload) + 8 + len(binary)
    return (struct.pack("<III", 0x46546C67, 2, size)
            + struct.pack("<II", len(payload), 0x4E4F534A) + payload
            + struct.pack("<II", len(binary), 0x004E4942) + binary)


def optimize(doc, binary, remove=()):
    """전체 속성이 같은 정점만 병합합니다. 노드 이름·변환·면 순서·재질 슬롯을 보존합니다."""
    static_document(doc)
    result = copy.deepcopy(doc)
    result["accessors"], result["bufferViews"], result["meshes"] = [], [], []
    data = bytearray()
    mapping = {}

    def append(raw, template, count):
        data.extend(b"\0" * (-len(data) % 4))
        view = {"buffer": 0, "byteOffset": len(data), "byteLength": len(raw)}
        data.extend(raw)
        item = {k: v for k, v in template.items() if k not in ("bufferView", "byteOffset", "sparse")}
        item.update(bufferView=len(result["bufferViews"]), count=count)
        result["bufferViews"].append(view)
        result["accessors"].append(item)
        return len(result["accessors"]) - 1

    for mesh_index, mesh in enumerate(doc["meshes"]):
        if mesh_index in remove:
            continue
        mapping[mesh_index] = len(result["meshes"])
        target = copy.deepcopy(mesh)
        for primitive in target["primitives"]:
            arrays = []
            for key, index in sorted(primitive["attributes"].items()):
                raw, width = accessor(doc, binary, index)
                arrays.append((key, index, raw, width))
            count = doc["accessors"][arrays[0][1]]["count"]
            if any(doc["accessors"][a[1]]["count"] != count for a in arrays):
                raise ValueError("표면 속성의 정점 수가 다릅니다")
            seen, representatives, inverse = {}, [], []
            for vertex in range(count):
                key = b"".join(raw[vertex * width:(vertex + 1) * width] for _, _, raw, width in arrays)
                if key not in seen:
                    seen[key] = len(representatives)
                    representatives.append(vertex)
                inverse.append(seen[key])
            old_indices = indices(doc, binary, primitive)
            for key, index, raw, width in arrays:
                packed = b"".join(raw[v * width:(v + 1) * width] for v in representatives)
                primitive["attributes"][key] = append(packed, doc["accessors"][index], len(representatives))
            values = [inverse[index] for index in old_indices]
            component, code = (5123, "H") if len(representatives) <= 65535 else (5125, "I")
            packed = struct.pack("<%d%s" % (len(values), code), *values)
            primitive["indices"] = append(packed, {"componentType": component, "type": "SCALAR"}, len(values))
        result["meshes"].append(target)
    for node in result.get("nodes", []):
        if "mesh" in node:
            old = node.pop("mesh")
            if old in mapping:
                node["mesh"] = mapping[old]
    result["buffers"] = [{"byteLength": len(data)}]
    return write(result, data)


def single_mesh(doc, binary, mesh_index, name="Visual"):
    target = copy.deepcopy(doc)
    target["nodes"] = [{"name": name, "mesh": mesh_index}]
    target["scenes"] = [{"nodes": [0]}]
    target["scene"] = 0
    return optimize(target, binary, set(range(len(doc["meshes"]))) - {mesh_index})
