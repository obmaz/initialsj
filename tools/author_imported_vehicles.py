"""Blender에서 제공 차량을 실척 GLB로 제작합니다. 업로드 원본은 source_only로 영구 보존합니다.

blender -b --python tools/author_imported_vehicles.py -- --source redcar=/path/redcar.glb
원본을 처음 등록할 때만 --source ID=PATH를 줍니다. 재생성은 저장된 uploaded.glb를 읽습니다.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import shutil
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
SPECS = {
    'redcar': ('vehicles', 4.65, 1.92, 1.42, math.pi, 17500, 2048),
    'icecream_car': ('props', 6.4, 2.55, 3.25, math.pi / 2, 3600, 1024),
    'bike': ('props', 2.05, .85, 1.44, math.pi, 3200, 1024),
    'dumptruck': ('props', 7.2, 2.55, 3.1, -math.pi / 2, 3600, 1024),
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def create_model(model_id, spec):
    category, length, width, height, angle, target, texture_size = spec
    source = ROOT / 'model_sources' / category / model_id
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(source / 'uploaded.glb'))
    mesh = next(obj for obj in bpy.context.selected_objects if obj.type == 'MESH')
    mesh.data.transform(Matrix.Rotation(angle, 4, 'Z') @ mesh.matrix_world)
    mesh.matrix_world = Matrix.Identity(4)
    vertices = mesh.data.vertices
    low = Vector(tuple(min(v.co[i] for v in vertices) for i in range(3)))
    high = Vector(tuple(max(v.co[i] for v in vertices) for i in range(3)))
    center = (low + high) / 2
    scale = Vector((width / (high.x - low.x), length / (high.y - low.y), height / (high.z - low.z)))
    for vertex in vertices:
        vertex.co = Vector(((vertex.co.x - center.x) * scale.x, (vertex.co.y - center.y) * scale.y, (vertex.co.z - low.z) * scale.z))
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.select_all(action='DESELECT')
    mesh.select_set(True)
    original_triangles = len(mesh.data.polygons)
    modifier = mesh.modifiers.new('Traffic silhouette budget' if category == 'props' else 'Player silhouette budget', 'DECIMATE')
    modifier.ratio = min(1.0, target / original_triangles)
    modifier.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    mesh.name = 'PaintShell' if category == 'vehicles' else 'Visual'
    if category == 'vehicles':
        split_wheels(mesh)
        split_trim(mesh)
        # 제동등은 사진과 분리된 발광 부품으로 공통 차량 제어기에 연결한다.
        brake_material = bpy.data.materials.new('Brake lamp')
        brake_material.use_nodes = True
        shader = brake_material.node_tree.nodes.get('Principled BSDF')
        shader.inputs['Base Color'].default_value = (.65, .015, .01, 1)
        shader.inputs['Emission Color'].default_value = (.8, .025, .015, 1)
        shader.inputs['Emission Strength'].default_value = 1.7
        for side in [-1, 1]:
            bpy.ops.mesh.primitive_cube_add(size=1, location=(side * .67, -2.31, .57))
            lamp = bpy.context.object
            lamp.name = 'BrakeLightsLeft' if side < 0 else 'BrakeLightsRight'
            lamp.scale = (.43, .025, .14)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            lamp.data.materials.append(brake_material)
        # UV0는 사진 원본, UV1은 차체 길이·높이에 맞춘 리버리 좌표다.
        layer = mesh.data.uv_layers.new(name='Livery')
        for loop in mesh.data.loops:
            co = mesh.data.vertices[loop.vertex_index].co
            layer.data[loop.index].uv = (co.y / length + .5, co.z / height)
    for material in mesh.data.materials:
        if material and material.use_nodes:
            for node in material.node_tree.nodes:
                if node.type == 'TEX_IMAGE' and node.image:
                    if max(node.image.size) > texture_size:
                        node.image.scale(texture_size, texture_size)
    bpy.ops.object.select_all(action='DESELECT')
    objects = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
    container = bpy.data.objects.new('Model', None)
    bpy.context.collection.objects.link(container)
    container.select_set(True)
    for obj in objects:
        obj.parent = container
        obj.select_set(True)
    output = source / 'model.glb'
    # 기존 편집본은 덮어쓰기 전에 해시별로 보존한다. 업로드 원본은 절대 출력 경로로 쓰지 않는다.
    if output.exists():
        backup = ROOT / 'build/reports/model-backups' / digest(output) / category / model_id
        backup.mkdir(parents=True, exist_ok=True)
        shutil.copy2(output, backup / 'model.glb')
    bpy.ops.export_scene.gltf(filepath=str(output), export_format='GLB', use_selection=True,
                              export_image_format='JPEG', export_jpeg_quality=87, export_yup=True,
                              export_animations=False, export_cameras=False, export_lights=False,
                              export_extras=False, export_texcoords=True, export_normals=True)
    return {'inputBytes': (source / 'uploaded.glb').stat().st_size, 'outputBytes': output.stat().st_size,
            'inputTriangles': original_triangles, 'outputTriangles': sum(len(obj.data.polygons) for obj in objects),
            'sizeMeters': [width, height, length], 'textureSize': texture_size}


def split_wheels(mesh):
    centers = {'wheel_fl': Vector((-.79, 1.39, .34)), 'wheel_fr': Vector((.79, 1.39, .34)),
               'wheel_rl': Vector((-.79, -1.39, .34)), 'wheel_rr': Vector((.79, -1.39, .34))}
    original = mesh.data.copy()
    assigned = {}
    for polygon in original.polygons:
        point = sum((original.vertices[index].co for index in polygon.vertices), Vector()) / len(polygon.vertices)
        for name, center in centers.items():
            if point.x * center.x > 0 and abs(point.x) > .66 and (Vector((point.y, point.z)) - Vector((center.y, center.z))).length < .355:
                assigned[polygon.index] = name
                break
    for name, center in centers.items():
        data = original.copy()
        bm = bmesh.new(); bm.from_mesh(data); bm.faces.ensure_lookup_table(); bm.faces.index_update()
        remove = [face for face in bm.faces if assigned.get(face.index) != name]
        bmesh.ops.delete(bm, geom=remove, context='FACES')
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
        if not bm.faces:
            raise ValueError('휠 분리 실패: ' + name)
        bm.to_mesh(data); bm.free()
        wheel = bpy.data.objects.new(name, data)
        bpy.context.collection.objects.link(wheel)
        transform = Matrix.Translation(center) @ Matrix.Rotation(math.pi / 2, 4, 'Y')
        data.transform(transform.inverted())
        wheel.matrix_world = transform
    bm = bmesh.new(); bm.from_mesh(mesh.data); bm.faces.ensure_lookup_table(); bm.faces.index_update()
    bmesh.ops.delete(bm, geom=[face for face in bm.faces if face.index in assigned], context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bm.to_mesh(mesh.data); bm.free()


def split_trim(mesh):
    import numpy as np
    image = next(node.image for material in mesh.data.materials for node in material.node_tree.nodes if node.type == 'TEX_IMAGE')
    pixels = np.empty(len(image.pixels), dtype=np.float32)
    image.pixels.foreach_get(pixels)
    pixels = pixels.reshape((image.size[1], image.size[0], 4))
    uv = mesh.data.uv_layers[0].data
    selected = set()
    for polygon in mesh.data.polygons:
        samples = []
        for loop in polygon.loop_indices:
            point = uv[loop].uv
            samples.append(pixels[min(image.size[1]-1, max(0, int(point.y*image.size[1]))), min(image.size[0]-1, max(0, int(point.x*image.size[0]))), :3])
        color = np.mean(samples, axis=0)
        if color[0] - max(color[1], color[2]) < .065:
            selected.add(polygon.index)
    data = mesh.data.copy()
    bm = bmesh.new(); bm.from_mesh(data); bm.faces.index_update()
    bmesh.ops.delete(bm, geom=[face for face in bm.faces if face.index not in selected], context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bm.to_mesh(data); bm.free()
    trim = bpy.data.objects.new('TrimShell', data)
    bpy.context.collection.objects.link(trim)
    bm = bmesh.new(); bm.from_mesh(mesh.data); bm.faces.index_update()
    bmesh.ops.delete(bm, geom=[face for face in bm.faces if face.index in selected], context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bm.to_mesh(mesh.data); bm.free()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', action='append', default=[], metavar='ID=PATH')
    parser.add_argument('--only', choices=list(SPECS))
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    supplied = dict(item.split('=', 1) for item in args.source)
    inventory_path = ROOT / 'model_sources/inventory.json'
    inventory = json.loads(inventory_path.read_text())
    report = {}
    for model_id, spec in SPECS.items():
        if args.only and args.only != model_id:
            continue
        category = spec[0]
        folder = ROOT / 'model_sources' / category / model_id
        folder.mkdir(parents=True, exist_ok=True)
        uploaded = folder / 'uploaded.glb'
        if model_id in supplied:
            incoming = Path(supplied[model_id])
            if uploaded.exists() and digest(uploaded) != digest(incoming):
                raise ValueError('보존된 업로드 원본과 다릅니다. 별도 모델 ID로 등록하세요: ' + model_id)
            if not uploaded.exists():
                shutil.copy2(incoming, uploaded)
        if not uploaded.exists():
            raise ValueError('최초 등록에는 --source ID=PATH가 필요합니다: ' + model_id)
        key = f'{category}/{model_id}/uploaded.glb'
        inventory['files'][key] = digest(uploaded)
        if key not in inventory.setdefault('source_only', []):
            inventory['source_only'].append(key)
        report[model_id] = create_model(model_id, spec)
    inventory_path.write_text(json.dumps(inventory, ensure_ascii=False, indent=2, sort_keys=True) + '\n')
    target = ROOT / 'build/reports/imported-vehicles'
    target.mkdir(parents=True, exist_ok=True)
    (target / 'optimization.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
