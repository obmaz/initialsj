"""야간 도로등·광고 투광등 GLB와 기존 광고판의 조명 형상을 오프라인 제작한다."""
from pathlib import Path
import copy
import hashlib
import struct

from glb_geometry import accessor, indices, read, write
from glb_shapes import ColoredMesh, append

ROOT = Path(__file__).resolve().parents[1]
BODY = (.18, .21, .23, 0)
LENS = (.96, .87, .62, 1)


def backup(path):
    if not path.exists():
        return
    data = path.read_bytes()
    target = ROOT / 'build/reports/model-backups' / (path.parent.name + '-' + hashlib.sha256(data).hexdigest() + '.glb')
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists():
        target.write_bytes(data)


def save_fixture(name, mesh, size):
    source = ROOT / f'model_sources/props/{name}/model.glb'
    if source.exists():
        print('기존 원본 보존:', name)
        return
    doc = {'asset': {'version': '2.0', 'generator': 'Initial SJ lighting fixtures'}, 'buffers': [{}],
           'bufferViews': [], 'accessors': [], 'materials': [{'name': name}],
           'nodes': [{'name': 'Model', 'children': [1]}, {'name': 'Visual', 'mesh': 0}],
           'meshes': [], 'scenes': [{'nodes': [0]}], 'scene': 0}
    binary = bytearray()
    attrs = {key: append(doc, binary, values, kind) for key, values, kind in
             [('POSITION', mesh.vertices, 'VEC3'), ('NORMAL', mesh.normals, 'VEC3'), ('COLOR_0', mesh.colors, 'VEC4')]}
    doc['meshes'] = [{'primitives': [{'attributes': attrs, 'material': 0}]}]
    doc['buffers'][0]['byteLength'] = len(binary)
    source.parent.mkdir(parents=True, exist_ok=True)
    source.write_bytes(write(doc, binary))
    folder = ROOT / f'models/props/{name}'
    folder.mkdir(parents=True, exist_ok=True)
    (folder / 'model.tscn').write_text(f'[gd_scene format=3]\n[ext_resource type="PackedScene" path="res://models/props/{name}/model.glb" id="1"]\n[node name="Fixture" type="Node3D"]\n[node name="Model" parent="." instance=ExtResource("1")]\n')
    (folder / 'material.tres').write_text('[gd_resource type="ShaderMaterial" format=3]\n[ext_resource type="Shader" path="res://shaders/fixture_lamp.gdshader" id="1"]\n[resource]\nshader = ExtResource("1")\n')
    (folder / 'definition.tres').write_text(f'[gd_resource type="Resource" format=3]\n[ext_resource type="Script" path="res://models/model_definition.gd" id="1"]\n[resource]\nscript = ExtResource("1")\ncontract_version = 2\nid = "{name}"\ncategory = "props"\nscene_path = "res://models/props/{name}/model.tscn"\nsource_path = "res://models/props/{name}/SOURCE.md"\nmaterial_path = "res://models/props/{name}/material.tres"\nbase_size = Vector3({', '.join(map(str,size))})\n')
    (folder / 'SOURCE.md').write_text(f'# {name}\n\nInitial SJ 자체 제작. [오프라인 도구](../../../tools/author_night_fixtures.py)에서 금속 지주·브래킷·두꺼운 LED 하우징과 렌즈를 제작합니다. 원본은 [편집 GLB](../../../model_sources/props/{name}/model.glb)에 보존합니다. 실척은{size}m이며 COLOR.a는0=몸체·1=렌즈입니다. 조립 씬은 정적 형상만 소유하고 발광·실제 광원 예산은 공용 코스 제어기가 관리합니다.\n')


def enhance_billboard():
    path = ROOT / 'model_sources/props/billboard/model.glb'
    original = path.read_bytes()
    doc, binary = read(original)
    if doc['asset'].get('extras', {}).get('fixture_schema') == 2:
        return
    backup(path)
    primitive = doc['meshes'][0]['primitives'][0]
    arrays = {}
    for key, index in primitive['attributes'].items():
        raw, width = accessor(doc, binary, index)
        arrays[key] = list(struct.unpack('<' + 'f' * (len(raw) // 4), raw))
    original_indices = indices(doc, binary, primitive)
    if doc['asset'].get('extras', {}).get('fixture_schema') == 1:
        # 첫 등기구 버전의 추가 정점만 제거하고 기존 인쇄면·속성·인덱스는 보존한다.
        marker = arrays['TEXCOORD_1'][::2]
        count = next(i for i, value in enumerate(marker) if value in [-2, -3])
        widths = {'POSITION': 3, 'NORMAL': 3, 'COLOR_0': 4, 'TEXCOORD_1': 2, 'TEXCOORD_0': 2, 'TANGENT': 4}
        arrays = {key: values[:count * widths[key]] for key, values in arrays.items()}
        original_indices = [i for i in original_indices if i < count]
    old_count = len(arrays['POSITION']) // 3
    fixture = ColoredMesh()
    for side in [-1, 1]:
        for x in [-4.3, 4.3]:
            fixture.box((x, 15.65, side * .4), (.13, .24, 1.0), BODY)
            fixture.box((x, 15.82, side * .70), (.95, .4, .38), BODY)
            fixture.box((x, 15.59, side * .70), (.74, .06, .30), LENS)
    additions = len(fixture.vertices) // 3
    for key in arrays:
        if key == 'POSITION':
            extra = fixture.vertices
        elif key == 'NORMAL':
            extra = fixture.normals
        elif key == 'COLOR_0':
            extra = fixture.colors
        elif key == 'TEXCOORD_1':
            extra = [value for i in range(additions) for value in (-3 if fixture.colors[i*4+3] > .5 else -2, 0)]
        elif key == 'TEXCOORD_0':
            extra = [0.0] * (additions * 2)
        elif key == 'TANGENT':
            extra = [1, 0, 0, 1] * additions
        else:
            raise ValueError('추가 속성의 보존 규칙이 필요합니다: ' + key)
        arrays[key].extend(extra)
    result = copy.deepcopy(doc)
    result['buffers'], result['bufferViews'], result['accessors'] = [{}], [], []
    output = bytearray()
    kinds = {'POSITION': 'VEC3', 'NORMAL': 'VEC3', 'COLOR_0': 'VEC4', 'TANGENT': 'VEC4', 'TEXCOORD_0': 'VEC2', 'TEXCOORD_1': 'VEC2'}
    target = result['meshes'][0]['primitives'][0]
    target['attributes'] = {k: append(result, output, v, kinds[k]) for k, v in arrays.items()}
    target['indices'] = append(result, output, original_indices + list(range(old_count, old_count + additions)), 'SCALAR', 5125)
    result['buffers'][0]['byteLength'] = len(output)
    result['asset']['extras'] = {'fixture_schema': 2}
    path.write_bytes(write(result, output))


def main():
    road = ColoredMesh()
    road.box((0, .23, 0), (.85, .46, .85), (.42, .43, .42, 0))
    road.box((0, 4.55, 0), (.27, 8.5, .27), BODY)
    road.box((-1.3, 8.8, 0), (2.8, .2, .24), BODY)
    road.box((-2.6, 8.7, 0), (1.3, .36, .65), BODY)
    road.box((-2.6, 8.49, 0), (1.08, .06, .5), LENS)
    save_fixture('road_lamp', road, (3.7, 8.98, .85))
    ad = ColoredMesh()
    ad.box((0, 0, 0), (.3, .5, .22), BODY)
    ad.box((0, .25, .7), (.12, .12, 1.4), BODY)
    ad.box((0, .2, 1.3), (.95, .36, .66), BODY)
    ad.box((0, -.01, 1.27), (.76, .06, .46), LENS)
    save_fixture('billboard_floodlight', ad, (.95, .63, 1.74))
    enhance_billboard()


if __name__ == '__main__':
    main()
