"""Blender로 플레이어 차체 반경·패널 곡면·휠 법선을 다듬는다. 원본은 해시별 백업한다.

blender -b --factory-startup --python tools/refine_player_models.py -- --models hatch wedge muscle gt redcar
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import shutil
import struct
import sys

import bpy
import bmesh

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from glb_geometry import read, write, accessor, indices
from glb_shapes import append
import bake_tuning_models
import author_effect_models


def backup(path):
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    target = ROOT / "build/reports/model-backups" / digest / path.relative_to(ROOT / "model_sources")
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists():
        shutil.copy2(path, target)
    return target


def refine_mesh(obj, model):
    mesh = obj.data
    wheel = obj.name.startswith("wheel_")
    if obj.name.startswith("BrakeLights"):
        return
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    # 수직 모서리의 면을 연결하고 같은 평면의 불필요한 대각선을 정리한다.
    if model != "redcar":
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=.000002)
        bmesh.ops.dissolve_limit(bm, angle_limit=.001, verts=list(bm.verts), edges=list(bm.edges),
                                  use_dissolve_boundaries=False, delimit={"MATERIAL", "UV"})
        # 앞부분은 약하게 좁아지고 후드 중심은 약2cm 솟도록 형상을 바꾼다.
        if obj.name == "BodyShell":
            low = [min(v.co[i] for v in bm.verts) for i in range(3)]
            high = [max(v.co[i] for v in bm.verts) for i in range(3)]
            half_width = max(abs(low[0]), abs(high[0]))
            half_length = max(abs(low[1]), abs(high[1]))
            height = high[2] - low[2]
            if half_length > height:
                for v in bm.verts:
                    front = max(0, (v.co.y / max(.01, half_length) - .35) / .65)
                    v.co.x *= 1 - .022 * front * front
                    if low[2] + height * .36 < v.co.z < low[2] + height * .63 and front > 0:
                        v.co.z += .018 * (1 - min(1, abs(v.co.x) / half_width) ** 2) * front
        bm.to_mesh(mesh)
        bm.free()
        # 이미 촘촘한 GT와 휠은 작은 반경만 적용해 모바일 메시 예산을 유지한다.
        bevel = obj.modifiers.new("Manufactured edge radius", "BEVEL")
        bevel.width = .007 if wheel else (.012 if model == "gt" else .027)
        bevel.segments = 1 if model == "gt" else 2
        bevel.limit_method = "ANGLE"
        bevel.angle_limit = math.radians(55 if wheel or model == "gt" else 35)
        bevel.use_clamp_overlap = True
        bevel.harden_normals = True
        bpy.ops.object.modifier_apply(modifier=bevel.name)
    # 휠 곡면과 차체의 큰 판면을 구분하는 가중 법선. 사진 UV·정점색은 바꾸지 않는다.
    mesh = obj.data
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    mesh.set_sharp_from_angle(angle=math.radians(42))
    modifier = obj.modifiers.new("Panel weighted normals", "WEIGHTED_NORMAL")
    modifier.keep_sharp = True
    modifier.weight = 50
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def float_colors(doc, binary):
    data = bytearray(binary)
    for mesh in doc["meshes"]:
        for primitive in mesh["primitives"]:
            attributes = primitive["attributes"]
            if "COLOR_0" not in attributes:
                continue
            info = doc["accessors"][attributes["COLOR_0"]]
            if info["componentType"] == 5126:
                continue
            code, maximum = {5121: ("B", 255), 5123: ("H", 65535)}[info["componentType"]]
            raw, _ = accessor(doc, data, attributes["COLOR_0"])
            colors = [x[0] / maximum for x in struct.iter_unpack("<" + code, raw)]
            attributes["COLOR_0"] = append(doc, data, colors, "VEC4")
    doc["buffers"][0]["byteLength"] = len(data)
    return write(doc, data)


def run(model):
    source = ROOT / "model_sources/vehicles" / model / "model.glb"
    existing, _ = read(source.read_bytes())
    if existing.get("asset", {}).get("extras", {}).get("initialsj_player_refinement") == 1:
        print("이미 개선한 편집본 보존:", model, flush=True)
        return
    root_index = existing["scenes"][existing.get("scene", 0)]["nodes"][0]
    child_order = [existing["nodes"][i].get("name") for i in existing["nodes"][root_index].get("children", [])]
    saved = backup(source)
    original_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    if model != "redcar":
        for name in ["PaintShell", "TrimShell", "OpenPaintShell", "OpenTrimShell", "OpenCabin"]:
            obj = bpy.data.objects.get(name)
            if obj:
                bpy.data.objects.remove(obj, do_unlink=True)
    if model != "redcar":
        # COLOR.a는 도장 마스크다. 내보낼 때 RGBA가 생략되지 않게 연결한 뒤 GLB 재질은 불투명으로 복구한다.
        for material in bpy.data.materials:
            if material.use_nodes:
                shader = next((n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
                if shader:
                    color = material.node_tree.nodes.new("ShaderNodeVertexColor")
                    material.node_tree.links.new(color.outputs["Alpha"], shader.inputs["Alpha"])
    objects = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    transforms = {o.name: list(sum((tuple(row) for row in o.matrix_world), ())) for o in objects}
    for obj in objects:
        refine_mesh(obj, model)
    output = ROOT / "build/reports/model-refinement" / (model + ".glb")
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(output), export_format="GLB", use_selection=True,
                              export_yup=True, export_animations=False, export_cameras=False,
                              export_lights=False, export_texcoords=True, export_normals=True,
                              export_all_vertex_colors=True, export_active_vertex_color_when_no_material=True)
    doc, raw = read(output.read_bytes())
    if "GODOT_single_root" in existing.get("extensionsUsed", []):
        doc.setdefault("extensionsUsed", []).append("GODOT_single_root")
    first = doc["scenes"][doc.get("scene", 0)]["nodes"][0]
    order = [first] + [i for i in range(len(doc["nodes"])) if i != first]
    lookup = {old: new for new, old in enumerate(order)}
    doc["nodes"] = [doc["nodes"][i] for i in order]
    for node in doc["nodes"]:
        if "children" in node:
            node["children"] = [lookup[i] for i in node["children"]]
    for scene in doc["scenes"]:
        if "name" not in existing["scenes"][0]:
            scene.pop("name", None)
        scene["nodes"] = [lookup[i] for i in scene["nodes"]]
    if model != "redcar":
        for material in doc.get("materials", []):
            material["alphaMode"] = "OPAQUE"
        body = next(n for n in doc["nodes"] if n.get("name") == "BodyShell")
        primitives = doc["meshes"][body["mesh"]]["primitives"]
        assert len(primitives) == 1
        assert doc["accessors"][primitives[0]["attributes"]["COLOR_0"]]["type"] == "VEC4"
    try:
        source.write_bytes(float_colors(doc, raw))
        if model != "redcar":
            bake_tuning_models.paint_shell(model)
            if model == "gt":
                author_effect_models.roadster()
        result, data = read(source.read_bytes())
        counts = {n.get("name"): sum(len(indices(result, data, p)) // 3 for p in result["meshes"][n["mesh"]]["primitives"])
                  for n in result["nodes"] if "mesh" in n}
        root = result["scenes"][result.get("scene", 0)]["nodes"][0]
        result["nodes"][root]["children"].sort(
            key=lambda i: child_order.index(result["nodes"][i].get("name"))
            if result["nodes"][i].get("name") in child_order else len(child_order))
        result["asset"].setdefault("extras", {})["initialsj_player_refinement"] = 1
        source.write_bytes(write(result, data))
        active = sum(v for k, v in counts.items() if k != "BodyShell" and not k.startswith("Open"))
        assert active < 20000, (model, active)
        record = {"model": model, "beforeSha256": original_hash, "afterSha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                  "backup": str(saved), "activeTriangles": active, "parts": counts, "originalTransforms": transforms}
        (output.parent / (model + ".json")).write_text(json.dumps(record, indent=2) + "\n")
        print(json.dumps({"model": model, "activeTriangles": active}), flush=True)
    except Exception:
        shutil.copy2(saved, source)
        raise


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--models", nargs="+", choices=["hatch", "wedge", "muscle", "gt", "redcar"], required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    for model_id in args.models:
        run(model_id)
