"""고정된 투어 진입 연결부의 GLB를 만든다. 기존 코스 원본은 수정하지 않는다."""
from pathlib import Path
import hashlib
import json
import math

from glb_geometry import write
from glb_shapes import ColoredMesh, append

ROOT = Path(__file__).resolve().parents[1]


def frame(points, index):
    a = points[max(0, index - 1)]
    b = points[min(len(points) - 1, index + 1)]
    x, z = b[0] - a[0], b[2] - a[2]
    length = math.hypot(x, z)
    return (x / length, 0, z / length), (-z / length, 0, x / length)


def point(base, right, lane, height=0):
    return (base[0] + right[0] * lane, base[1] + height, base[2] + right[2] * lane)


def surface(points):
    m = ColoredMesh()
    uv = []
    def tri(a, b, c, alpha, coords):
        m.tri(a,b,c,(.35,.35,.35,alpha))
        for q in coords: uv.extend(q)
    for i in range(0, len(points)-1, 4):
        end = min(i+4,len(points)-1)
        _, ra = frame(points,i)
        _, rb = frame(points,end)
        for left,right,alpha,y in [(-8.1,8.1,0,0),(-9.6,-8.1,1,-.025),(8.1,9.6,1,-.025)]:
            a,b = point(points[i],ra,left,y),point(points[end],rb,left,y)
            c,d = point(points[i],ra,right,y),point(points[end],rb,right,y)
            va,vb = i*.5/6,end*.5/6
            tri(a,c,b,alpha,[(left/5.4,va),(right/5.4,va),(left/5.4,vb)])
            tri(b,c,d,alpha,[(left/5.4,vb),(right/5.4,va),(right/5.4,vb)])
    return m,uv


def rails(points,side):
    m=ColoredMesh()
    for index in range(0,len(points)-1,8):
        end=min(index+8,len(points)-1)
        forward,right=frame(points,index)
        middle=tuple((points[index][j]+points[end][j])*.5 for j in range(3))
        length=math.dist(points[index],points[end])
        for edge in ([-1,1] if side==0 else [side]):
            for at,size in [(point(middle,right,edge*9.6,.75),(.22,.42,length+.08)),
                            (point(points[index],right,edge*9.6,.52),(.21,1.04,.25))]:
                box=ColoredMesh();box.box((0,0,0),size,(.48,.5,.49,1))
                for k in range(0,len(box.vertices),3):
                    x,y,z=box.vertices[k:k+3]
                    m.vertices.extend((at[0]+right[0]*x-forward[0]*z,at[1]+y,at[2]+right[2]*x-forward[2]*z))
                    x,y,z=box.normals[k:k+3]
                    m.normals.extend((right[0]*x-forward[0]*z,y,right[2]*x-forward[2]*z))
                m.colors.extend(box.colors)
    return m


def main():
    data=json.loads((ROOT/'build/reports/circuit-weather/entry_curves.json').read_text())
    doc={'asset':{'version':'2.0','generator':'Initial SJ tour entry'},'buffers':[{}],'bufferViews':[],
         'accessors':[],'materials':[{'name':'entry'}],'meshes':[],'nodes':[{'name':'Model','children':[]}],
         'scenes':[{'nodes':[0]}],'scene':0}
    binary=bytearray()
    for side in [-1,0,1]:
        points=data[str(side)]['points']
        ground,uv=surface(points)
        for role,m,coords in [('Surface',ground,uv),('Rails',rails(points,side),None)]:
            name=f'Entry{side+1}{role}'
            attrs={k:append(doc,binary,v,t) for k,v,t in [('POSITION',m.vertices,'VEC3'),('NORMAL',m.normals,'VEC3'),('COLOR_0',m.colors,'VEC4')]}
            if coords:attrs['TEXCOORD_0']=append(doc,binary,coords,'VEC2')
            doc['meshes'].append({'name':name,'primitives':[{'attributes':attrs,'material':0}]})
            doc['nodes'][0]['children'].append(len(doc['nodes']))
            doc['nodes'].append({'name':name,'mesh':len(doc['meshes'])-1})
    doc['buffers'][0]['byteLength']=len(binary)
    source=ROOT/'model_sources/shared/tour_entry/model.glb'
    if source.exists():
        original=source.read_bytes()
        backup=ROOT/'build/reports/model-backups'/('tour_entry-'+hashlib.sha256(original).hexdigest()+'.glb')
        backup.parent.mkdir(parents=True,exist_ok=True)
        if not backup.exists():backup.write_bytes(original)
    source.parent.mkdir(parents=True,exist_ok=True)
    source.write_bytes(write(doc,binary))
    folder=ROOT/'models/shared/tour_entry';folder.mkdir(exist_ok=True,parents=True)
    (folder/'surface.tres').write_text('[gd_resource type="ShaderMaterial" format=3]\n[ext_resource type="Shader" path="res://shaders/asphalt.gdshader" id="1"]\n[ext_resource type="Texture2D" path="res://assets/environment/asphalt.png" id="2"]\n[ext_resource type="Texture2D" path="res://assets/environment/asphalt-variants.png" id="3"]\n[resource]\nshader = ExtResource("1")\nshader_parameter/asphalt_texture = ExtResource("2")\nshader_parameter/asphalt_variants = ExtResource("3")\nshader_parameter/entry_surface = true\n')
    for side in [-1,0,1]:
        kind=side+1
        (folder/f'entry_{kind}.tscn').write_text(f'[gd_scene format=3]\n[ext_resource type="Material" path="res://models/shared/tour_entry/surface.tres" id="1"]\n[sub_resource type="StandardMaterial3D" id="rail"]\nvertex_color_use_as_albedo = true\nroughness = 0.7\nmetallic = 0.25\n[node name="TourEntry" type="Node3D"]\nmetadata/entry_connector = true\n[node name="Surface" type="MeshInstance3D" parent="."]\nmaterial_override = ExtResource("1")\nmetadata/world_ground = true\nmetadata/mesh_ref = "res://models/shared/tour_entry/model.glb#Model/Entry{kind}Surface"\n[node name="Rails" type="MeshInstance3D" parent="."]\nmaterial_override = SubResource("rail")\nmetadata/mesh_ref = "res://models/shared/tour_entry/model.glb#Model/Entry{kind}Rails"\n')
    (folder/'SOURCE.md').write_text('# 투어 진입 연결부\n\n[진입 프로필 도구](../../../tools/author_tour_entry.gd)의120m 곡선을 [GLB 도구](../../../tools/bake_tour_entry.py)로 시각 형상에 저장합니다. 도로 반폭8.1m·갓길1.5m와 바깥쪽 가드레일을 보존합니다. 이전 코스 GLB는 수정하지 않고 새 원본은 [공용 원본](../../../model_sources/shared/tour_entry/model.glb)에 보존합니다. 픽셀 이미지는 기존 노면을 공유하며 동적 메시 생성은 하지 않습니다.\n')


if __name__=='__main__':main()
