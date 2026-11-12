#!/usr/bin/env python3
"""속도 계측 구조물·노면 안내·호수 범선을 오프라인 GLB 팩으로 제작한다."""
import argparse
import hashlib
import math
from pathlib import Path

from glb_shapes import ColoredMesh, append
from glb_geometry import write

ROOT = Path(__file__).resolve().parents[1]
STEEL = (.22, .28, .32, 1)
DARK = (.025, .045, .06, 1)
GOLD = (.78, .55, .18, 1)
WHITE = (.92, .88, .73, 1)


class Shape(ColoredMesh):
    def quad(self, a, b, c, d, color):
        self.tri(a, b, c, color)
        self.tri(a, c, d, color)

    def beam(self, a, b, radius, color, sides=6):
        axis = [b[i] - a[i] for i in range(3)]
        length = math.sqrt(sum(v * v for v in axis))
        axis = [v / length for v in axis]
        reference = (1, 0, 0) if abs(axis[1]) > .9 else (0, 1, 0)
        u = (axis[1]*reference[2]-axis[2]*reference[1], axis[2]*reference[0]-axis[0]*reference[2], axis[0]*reference[1]-axis[1]*reference[0])
        span = math.sqrt(sum(v * v for v in u))
        u = [v / span for v in u]
        v = (axis[1]*u[2]-axis[2]*u[1], axis[2]*u[0]-axis[0]*u[2], axis[0]*u[1]-axis[1]*u[0])
        rings = [[tuple(p[j]+radius*(u[j]*math.cos(t)+v[j]*math.sin(t)) for j in range(3)) for t in [math.tau*i/sides for i in range(sides)]] for p in [a, b]]
        for i in range(sides):
            nxt = (i + 1) % sides
            self.quad(rings[0][i], rings[0][nxt], rings[1][nxt], rings[1][i], color)
            self.tri(a, rings[0][nxt], rings[0][i], color)
            self.tri(b, rings[1][i], rings[1][nxt], color)

    def pack(self, name, description, parameters="{}", markers="", replace=False):
        source = ROOT / f"model_sources/props/{name}/model.glb"
        if source.exists() and not replace:
            print(f"원본 보존: {name}")
            return
        if source.exists():
            data = source.read_bytes()
            backup = ROOT / f"build/reports/model-backups/{name}-{hashlib.sha256(data).hexdigest()[:12]}.glb"
            backup.parent.mkdir(parents=True, exist_ok=True)
            if not backup.exists():
                backup.write_bytes(data)
        doc = {"asset": {"version": "2.0", "generator": "Initial SJ roadside models"}, "buffers": [{}], "bufferViews": [], "accessors": [], "materials": [{"name": name, "doubleSided": True, "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": .15, "roughnessFactor": .66}}], "meshes": [], "nodes": [{"name": "Visual", "mesh": 0}], "scenes": [{"nodes": [0]}], "scene": 0}
        binary = bytearray()
        # 앞면은 +Z, 갑판·노면은 +Y. 전용 LED 셰이더도 같은 UV0를 사용한다.
        uv = []
        for i in range(0, len(self.vertices), 3):
            x, y, z = self.vertices[i:i+3]
            uv.extend((x / 3 + .5, .5 - y / 1.5))
        attributes = {key: append(doc, binary, values, kind) for key, values, kind in [("POSITION", self.vertices, "VEC3"), ("NORMAL", self.normals, "VEC3"), ("COLOR_0", self.colors, "VEC4"), ("TEXCOORD_0", uv, "VEC2")]}
        doc["meshes"].append({"name": "Visual", "primitives": [{"attributes": attributes, "material": 0}]})
        doc["buffers"][0]["byteLength"] = len(binary)
        assert len(self.vertices) // 9 < 3200, name
        source.parent.mkdir(parents=True, exist_ok=True)
        source.write_bytes(write(doc, binary))
        folder = ROOT / f"models/props/{name}"
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "model.tscn").write_text(f'[gd_scene load_steps=3 format=3]\n\n[ext_resource type="PackedScene" path="res://models/props/{name}/model.glb" id="1"]\n[ext_resource type="Material" path="res://models/props/{name}/material.tres" id="2"]\n\n[node name="{name}" type="Node3D"]\n\n[node name="Model" parent="." instance=ExtResource("1")]\n{markers}\n[node name="Visual" parent="Model" index="0"]\nmaterial_override = ExtResource("2")\n')
        # GLB 임포터가 정점색 사용을 자동 설정한다고 가정하지 않는다.
        (folder / "material.tres").write_text('[gd_resource type="StandardMaterial3D" format=3]\n\n[resource]\nvertex_color_use_as_albedo = true\nroughness = 0.66\nmetallic = 0.15\ncull_mode = 2\n')
        (folder / "definition.tres").write_text(f'[gd_resource type="Resource" format=3]\n\n[ext_resource type="Script" path="res://models/model_definition.gd" id="1"]\n\n[resource]\nscript = ExtResource("1")\nid = "{name}"\nscene_path = "res://models/props/{name}/model.tscn"\nmaterial_path = "res://models/props/{name}/material.tres"\nsource_path = "res://models/props/{name}/SOURCE.md"\nparameters = {parameters}\n')
        (folder / "SOURCE.md").write_text(f'# {name}\n\n{description}\n\nInitial SJ 자체 제작. `tools/bake_roadside_models.py`로 오프라인 제작한 GLB이며 실행 중 정점을 생성하지 않습니다. 편집 원본은 `model_sources/props/{name}/model.glb`에 보존합니다. 기본 실행은 기존 원본을 덮어쓰지 않습니다. 의도한 재생성은 `--replace`로 요청하며 이전 바이트를 해시별로 먼저 백업합니다.\n')
        print(f"{name}: {len(self.vertices)//9}삼각형")


def equipment(replace):
    camera = Shape()
    camera.box((0, .25, 0), (1.1, .5, 1.1), (.48, .49, .45, 1))
    camera.box((0, 3.1, 0), (.3, 5.7, .3), STEEL)
    camera.box((-2.1, 6.0, 0), (4.5, .28, .36), STEEL)
    camera.beam((0, 4.5, 0), (-2.8, 5.85, 0), .09, STEEL)
    for x in [-3.2, -4.1]:
        camera.box((x, 5.75, .1), (.65, .65, .95), (.83, .83, .75, 1))
        camera.beam((x, 5.75, .52), (x, 5.75, .66), .22, DARK, 12)
        camera.beam((x, 5.75, .66), (x, 5.75, .69), .14, (.08, .22, .3, 1), 12)
        camera.box((x, 6.13, .1), (.76, .10, 1.16), STEEL)
    camera.box((0, 2.1, .18), (.7, 1, .46), (.55, .59, .57, 1))
    camera.pack("speed_camera", "높이6.3m의 실척 속도 카메라. 두 렌즈·차광 후드·제어함·콘크리트 기초·강재 사재를 갖습니다. +Z가 촬영 방향이고 가드레일 바깥의 지주에서 도로 쪽 −X로 뻗습니다.", markers='\n[node name="Lens" type="Marker3D" parent="."]\nposition = Vector3(-3.65, 5.75, 0.72)\n', replace=replace)
    board = Shape()
    for x in [-10.0, 10.0]:
        board.box((x, .4, 0), (1.9, .8, 2.1), (.43, .46, .45, 1))
        board.box((x, 6.8, 0), (.75, 12.8, .85), STEEL)
    board.box((0, 9.1, 0), (20.6, .8, .95), STEEL)
    board.box((0, 12.1, 0), (19.4, 5.8, 1.1), (.09, .13, .17, 1))
    board.box((0, 12.1, .57), (18.2, 4.9, .09), DARK)
    for y in [9.45, 14.75]:
        board.box((0, y, .6), (19.1, .14, .16), GOLD)
    board.box((0, 9.0, -1.0), (19.5, .25, 1.4), STEEL)
    for i in range(12):
        x = -9.3 + i * 1.69
        board.beam((x, 9.5, -.4), (x + 1.5, 10.4, -.4), .08, STEEL)
    board.pack("speed_display", "높이15m·폭21.9m의 대형 LED 전광판 구조물. 도로 위 통과 높이8.7m 이상을 확보하고 두꺼운 강재 지주·트러스·점검 발판을 갖습니다. Screen은 +Z를 향하는 표시 원점입니다. 폭은 배치 어댑터가 실제 도로·갓길 폭에 맞추며 기록 표시는 Label3D가 소유합니다.", parameters='{"screen_width": 18.2}', markers='\n[node name="Screen" type="Marker3D" parent="."]\nposition = Vector3(0, 12.1, 0.64)\n', replace=replace)
    face = Shape()
    face.box((0, 0, .01), (3, 1.5, .02), WHITE)
    face.pack("digital_chevrons", "3m×1.5m LED 안내판 표시면. UV0는 화면 전체0~1이며 기존 안내판 케이스와 방향 변환을 유지합니다. 시간 기반 점등은 공통 야간 안내 셰이더에서 수행합니다.", replace=replace)


def arrows(replace):
    for angle in [45, 60, 75]:
        mesh = Shape()
        a = math.radians(angle)
        start, bend = (0, .012, 3), (0, .012, 0)
        end = (math.sin(a) * 2.3, .012, -math.cos(a) * 2.3)
        for first, last in [(start, bend), (bend, end)]:
            dx, dz = last[0] - first[0], last[2] - first[2]
            span = math.hypot(dx, dz)
            nx, nz = -dz / span * .28, dx / span * .28
            mesh.quad((first[0]-nx,.012,first[2]-nz),(last[0]-nx,.012,last[2]-nz),(last[0]+nx,.012,last[2]+nz),(first[0]+nx,.012,first[2]+nz), WHITE)
        direction = (math.sin(a), -math.cos(a))
        tip = (end[0] + direction[0] * 1.2, .012, end[2] + direction[1] * 1.2)
        mesh.tri((end[0]-direction[1]*.9,.012,end[2]+direction[0]*.9),tip,(end[0]+direction[1]*.9,.012,end[2]-direction[0]*.9), WHITE)
        # 아주 얇은 표식도 바닥 경계에서 유효한 부피를 갖는다.
        mesh.box((0, .006, 2.7), (.56, .012, .5), WHITE)
        mesh.pack(f"bend_arrow_{angle}", f"진행 방향−Z에서 오른쪽으로{angle}도 꺾이는 반사 도료 노면 화살표. X를 반사하면 왼쪽 안내가 됩니다. 높이12mm, 길이 약7m이며 실제 코너 각도에 따라 사전 구간에 배치합니다.", replace=replace)


def ship(replace):
    mesh = Shape()
    sections = [(-25, .1), (-21, 2.0), (-15, 4.0), (-7, 5.1), (3, 5.4), (12, 5), (20, 4), (23, 2.5)]
    rings = [(-2.4, .12), (-.4, .65), (2.1, 1), (4.1, 1)]
    colors = [(.09,.15,.17,1), (.08,.25,.3,1), (.13,.31,.34,1)]
    for side in [-1, 1]:
        for i in range(len(sections)-1):
            z, width = sections[i]
            zn, wn = sections[i+1]
            for j in range(3):
                y, factor = rings[j]
                yn, fn = rings[j+1]
                mesh.quad((side*width*factor,y,z),(side*wn*factor,y,zn),(side*wn*fn,yn,zn),(side*width*fn,yn,z),colors[j])
            mesh.beam((side*width, 4.25, z), (side*wn,4.25,zn), .10, GOLD, 4)
            mesh.beam((side*width, 5.25, z), (side*wn,5.25,zn), .075, WHITE, 4)
            for f in [0, .5]:
                zz, ww = z + (zn-z)*f, width+(wn-width)*f
                mesh.beam((side*ww,4.2,zz),(side*ww,5.25,zz),.045,STEEL,4)
                if i in range(1,7):
                    mesh.box((side*(ww+.01),2.85,zz),(.15,.52,.85),GOLD)
                    mesh.box((side*(ww+.10),2.85,zz),(.05,.35,.64),DARK)
    for i in range(len(sections)-1):
        z,w = sections[i]
        zn,wn = sections[i+1]
        for j in range(8):
            a, b = -1 + j / 4, -1 + (j + 1) / 4
            mesh.quad((w*a,4.1,z),(w*b,4.1,z),(wn*b,4.1,zn),(wn*a,4.1,zn),(.42+j%2*.04,.27+j%2*.02,.13,1))
    for z, width in [sections[0], sections[-1]]:
        for j in range(3):
            y, factor = rings[j]
            yn, fn = rings[j+1]
            mesh.quad((-width*factor,y,z),(width*factor,y,z),(width*fn,yn,z),(-width*fn,yn,z),colors[j])
    mesh.box((0,4.8,16), (6.8,1.4,7), (.65,.48,.24,1))
    mesh.box((0,5.56,16), (7.3,.22,7.5), WHITE)
    for x in [-2.6,-1.3,0,1.3,2.6]:
        mesh.box((x,5.0,19.55),(1,.6,.10),(.09,.24,.31,1))
    for z,height,width in [(-15,28,5.7),(-1,35,7.2),(13,26,5.8)]:
        mesh.beam((0,4,z),(0,height,z),.20, (.36,.22,.09,1),10)
        for level in [.49,.70,.88]:
            top = 5 + (height-5)*level
            low = top - (5.6 if level < .8 else 3.7)
            half = width * (1.0 if level < .8 else .72)
            mesh.beam((-half-.4,top,z),(half+.4,top,z),.12,(.38,.24,.1,1),8)
            for i in range(6):
                u, un = i/6, (i+1)/6
                x, xn = -half+2*half*u, -half+2*half*un
                # 돛의 곡률·봉제 띠는 형상으로 남기며 단순 종이 평면을 피한다.
                for j in range(2):
                    v,vn=j/2,(j+1)/2
                    def cloth(px, f):
                        return (px*(.88+.12*f),top-(top-low)*f,z-1.3*math.sin(math.pi*f)*(1-(px/half)**2))
                    color=(.83+i%2*.045,.8+i%2*.035,.64+i%2*.03,1)
                    mesh.quad(cloth(x,v),cloth(xn,v),cloth(xn,vn),cloth(x,vn),color)
            for side in [-1,1]:
                mesh.beam((0,height,z),(side*4.2,4.3,z+5),.035,STEEL,4)
                mesh.beam((side*half,top,z),(0,low-1,z),.025,STEEL,4)
    mesh.beam((0,3.5,-22),(0,8,-33),.16,(.42,.28,.12,1),8)
    mesh.tri((0,27,-15),(0,8,-32),(.9,10,-16),WHITE)
    mesh.tri((0,24,-15),(0,9,-28),(.8,10,-16),(.75,.74,.6,1))
    mesh.beam((0,35,-1),(0,31,-15),.035,STEEL,4)
    mesh.beam((0,35,-1),(0,26,13),.035,STEEL,4)
    mesh.pack("lake_cruiser", "수선 피벗Y=0의 약56m급3마스트 호수 유람 범선입니다. 곡면 선체·청록 도장·목재 갑판·난간·선실 창·9장의 부푼 돛·지브·브라스 장식·삭구를 하나의 공유 메시로 제공합니다. 선체 바닥은 수면 아래−2.4m, 주 돛대는35m이며 선수는−Z입니다. 실제4.5m 차량에 비례한 실척으로 배치하며 도로·주행 충돌에 사용하지 않습니다.", parameters='{"waterline_y": 0.0}', replace=replace)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--replace", action="store_true", help="원본을 해시별 백업한 뒤 의도적으로 재생성")
    args = parser.parse_args()
    equipment(args.replace)
    arrows(args.replace)
    ship(args.replace)
