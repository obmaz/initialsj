"""원본을 백업한 뒤 GT 오픈카 변형과 원거리 번개를 오프라인 GLB로 제작한다."""
from pathlib import Path
import copy
import hashlib
import math
import struct
from glb_geometry import read, write, accessor, indices
from glb_shapes import ColoredMesh, append
ROOT = Path(__file__).resolve().parents[1]

def add_mesh(doc, data, name, mesh):
    attributes = {key: append(doc, data, values, kind) for key, values, kind in [('POSITION', mesh.vertices, 'VEC3'), ('NORMAL', mesh.normals, 'VEC3'), ('COLOR_0', mesh.colors, 'VEC4'), ('TEXCOORD_0', [0.1, 0.8] * (len(mesh.vertices) // 3), 'VEC2')]}
    doc['meshes'].append({'name': name, 'primitives': [{'attributes': attributes, 'material': 0}]})
    doc['nodes'].append({'name': name, 'mesh': len(doc['meshes']) - 1})
    doc['scenes'][doc.get('scene', 0)]['nodes'].append(len(doc['nodes']) - 1)

def make_cabin():
    mesh = ColoredMesh()

    def seat_box(c, size, color, radius=0.04):
        w, h, d = size
        pts = []
        for cx, cy, start in [(w / 2 - radius, h / 2 - radius, 0), (-w / 2 + radius, h / 2 - radius, 90), (-w / 2 + radius, -h / 2 + radius, 180), (w / 2 - radius, -h / 2 + radius, 270)]:
            for a in range(start, start + 91, 30):
                angle = math.radians(a)
                pts.append((c[0] + cx + math.cos(angle) * radius, c[1] + cy + math.sin(angle) * radius))
        front = [(x, y, c[2] - d / 2) for x, y in pts]
        back = [(x, y, c[2] + d / 2) for x, y in pts]
        for i in range(len(pts)):
            q = (i + 1) % len(pts)
            mesh.tri((c[0], c[1], c[2] - d / 2), front[q], front[i], color)
            mesh.tri((c[0], c[1], c[2] + d / 2), back[i], back[q], color)
            mesh.tri(front[i], front[q], back[q], color)
            mesh.tri(front[i], back[q], back[i], color)
    leather = (0.095, 0.085, 0.075, 1)
    panel = (0.32, 0.115, 0.055, 1)
    mesh.box((0, 0.72, 0.13), (1.4, 0.08, 1.1), leather)
    for x in [-0.36, 0.36]:
        seat_box((x, 0.79, 0.12), (0.5, 0.14, 0.53), leather)
        seat_box((x, 0.96, 0.43), (0.5, 0.34, 0.13), leather, 0.065)
        seat_box((x, 1.17, 0.45), (0.25, 0.16, 0.12), leather, 0.035)
        seat_box((x, 0.96, 0.355), (0.32, 0.25, 0.025), panel, 0.03)
        for e in [-1, 1]:
            mesh.box((x + e * 0.21, 0.85, 0.1), (0.045, 0.1, 0.47), panel)
            mesh.box((x + e * 0.18, 1.13, 0.67), (0.026, 0.28, 0.026), (0.32, 0.34, 0.36, 1))
        mesh.box((x, 1.27, 0.67), (0.385, 0.026, 0.026), (0.32, 0.34, 0.36, 1))
    mesh.box((0, 0.82, 0.01), (0.13, 0.18, 0.62), (0.07, 0.08, 0.1, 1))
    mesh.box((0, 0.93, -0.5), (1.34, 0.13, 0.18), leather)
    for i in range(20):
        a = math.tau * i / 20
        mesh.box((-0.36 + math.cos(a) * 0.13, 0.99 + math.sin(a) * 0.13, -0.34), (0.035, 0.035, 0.035), leather)
    return mesh

def roadster():
    path = ROOT / 'model_sources/vehicles/gt/model.glb'
    original = path.read_bytes()
    doc, raw = read(original)
    cabin_index = next((i for i, n in enumerate(doc['nodes']) if n.get('name') == 'OpenCabin'), None)
    if cabin_index is not None:
        roots = doc['scenes'][doc.get('scene', 0)]['nodes']
        if cabin_index in roots and len(roots) > 1:
            roots.remove(cabin_index)
            doc['nodes'][roots[0]].setdefault('children', []).append(cabin_index)
            path.write_bytes(write(doc, raw))
        return
    data = bytearray(raw)
    for name in ['PaintShell', 'TrimShell']:
        node = next((n for n in doc['nodes'] if n.get('name') == name))
        primitive = doc['meshes'][node['mesh']]['primitives'][0]
        positions = list(struct.iter_unpack('<3f', accessor(doc, raw, primitive['attributes']['POSITION'])[0]))
        old = indices(doc, raw, primitive)
        kept = []
        for start in range(0, len(old), 3):
            face = old[start:start + 3]
            points = [positions[i] for i in face]
            middle = [sum((v[i] for v in points)) / 3 for i in range(3)]
            roof = max((v[1] for v in points)) > 1.02 and -0.52 < middle[2] < 1.05 and (abs(middle[0]) < 0.95)
            if not roof:
                kept.extend(face)
        assert 0 < len(kept) < len(old)
        part = copy.deepcopy(primitive)
        part['indices'] = append(doc, data, kept, 'SCALAR', 5125)
        doc['meshes'].append({'name': 'Open' + name, 'primitives': [part]})
        variant = copy.deepcopy(node)
        variant.update(name='Open' + name, mesh=len(doc['meshes']) - 1)
        doc['nodes'].append(variant)
        parent = next((n for n in doc['nodes'] if doc['nodes'].index(node) in n.get('children', [])), None)
        if parent is not None:
            parent['children'].append(len(doc['nodes']) - 1)
        else:
            doc['scenes'][doc.get('scene', 0)]['nodes'].append(len(doc['nodes']) - 1)
    cabin = make_cabin()
    add_mesh(doc, data, 'OpenCabin', cabin)
    cabin_index = len(doc['nodes']) - 1
    doc['scenes'][doc.get('scene', 0)]['nodes'].remove(cabin_index)
    doc['nodes'][0]['children'].append(cabin_index)
    doc['buffers'][0]['byteLength'] = len(data)
    backup = ROOT / 'build/reports/model-backups' / ('gt-' + hashlib.sha256(original).hexdigest()[:12] + '.glb')
    backup.parent.mkdir(parents=True, exist_ok=True)
    if not backup.exists():
        backup.write_bytes(original)
    path.write_bytes(write(doc, data))

def lightning():
    source = ROOT / 'model_sources/props/distant_lightning/model.glb'
    if source.exists():
        return
    doc = {'asset': {'version': '2.0', 'generator': 'Initial SJ offline effects'}, 'buffers': [{}], 'bufferViews': [], 'accessors': [], 'materials': [{'pbrMetallicRoughness': {'baseColorFactor': [1, 1, 1, 1]}}], 'meshes': [], 'nodes': [], 'scenes': [{'nodes': []}], 'scene': 0}
    mesh = ColoredMesh()
    for points in [[(0, 2.4), (0.13, 1.9), (-0.05, 1.45), (0.2, 1.2), (0.02, 0.65), (0.08, 0)], [(0.06, 1.5), (-0.28, 1.2), (-0.36, 0.82)], [(0.1, 1.9), (0.42, 1.6), (0.35, 1.28)]]:
        for a, b in zip(points, points[1:]):
            width = 0.015
            mesh.tri((a[0] - width, a[1], 0), (a[0] + width, a[1], 0), (b[0] + width, b[1], 0), (1, 1, 1, 1))
            mesh.tri((a[0] - width, a[1], 0), (b[0] + width, b[1], 0), (b[0] - width, b[1], 0), (1, 1, 1, 1))
    data = bytearray()
    add_mesh(doc, data, 'Visual', mesh)
    doc['buffers'][0]['byteLength'] = len(data)
    source.parent.mkdir(parents=True, exist_ok=True)
    source.write_bytes(write(doc, data))
    folder = ROOT / 'models/props/distant_lightning'
    folder.mkdir(parents=True, exist_ok=True)
    (folder / 'model.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="PackedScene" path="res://models/props/distant_lightning/model.glb" id="1"]\n[node name="Lightning" type="Node3D"]\n[node name="Model" parent="." instance=ExtResource("1")]\n')
    (folder / 'definition.tres').write_text('[gd_resource type="Resource" format=3]\n[ext_resource type="Script" path="res://models/model_definition.gd" id="1"]\n[resource]\nscript = ExtResource("1")\nid = "distant_lightning"\ncategory = "props"\nscene_path = "res://models/props/distant_lightning/model.tscn"\nsource_path = "res://models/props/distant_lightning/SOURCE.md"\n')
    (folder / 'SOURCE.md').write_text('# 원거리 번개\n\nInitial SJ 자체 제작. tools/author_effect_models.py로 오프라인 생성한 분기형 번개 GLB. 원본은 model_sources/props/distant_lightning/model.glb에 보존하며 그림자·충돌 없는 먼 배경 연출로만 사용합니다.\n')
if __name__ == '__main__':
    roadster()
    lightning()
