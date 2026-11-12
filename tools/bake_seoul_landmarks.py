"""서울 랜드마크·유리 회랑·교대 GLB를 오프라인 제작한다. 기존 원본은 덮어쓰지 않는다."""
from pathlib import Path
import math
import argparse
import hashlib
REPLACE = False
ONLY = None
from glb_shapes import ColoredMesh, append
from glb_geometry import write
ROOT = Path(__file__).resolve().parents[1]
def ring(m,y,r,h,color,n=20,upper=None):
    upper=r if upper is None else upper
    for i in range(n):
        a,b=math.tau*i/n,math.tau*(i+1)/n
        p=[(math.cos(a)*r,y,math.sin(a)*r),(math.cos(b)*r,y,math.sin(b)*r),(math.cos(b)*upper,y+h,math.sin(b)*upper),(math.cos(a)*upper,y+h,math.sin(a)*upper)]
        m.tri(p[0],p[2],p[1],color);m.tri(p[0],p[3],p[2],color)
        m.tri((0,y+h,0),p[2],p[3],color)
        m.tri((0,y,0),p[0],p[1],color)


def save(name,m,size,transparent=False):
    if ONLY and name != ONLY: return
    source=ROOT/f'model_sources/props/{name}/model.glb'
    if source.exists():
        if not REPLACE:
            raise SystemExit(f'원본 보존: 이미 존재합니다 {source}')
        data=source.read_bytes()
        backup=ROOT/'build/reports/model-backups'/(name+'-'+hashlib.sha256(data).hexdigest()+'.glb')
        backup.parent.mkdir(parents=True,exist_ok=True)
        if not backup.exists(): backup.write_bytes(data)
    mat={'name':name,'pbrMetallicRoughness':{'baseColorFactor':[1,1,1,1],'metallicFactor':.28,'roughnessFactor':.4}}
    if transparent: mat.update(alphaMode='BLEND',doubleSided=True)
    doc={'asset':{'version':'2.0','generator':'Initial SJ Seoul scenery'},'buffers':[{}],'bufferViews':[],'accessors':[],'materials':[mat],'meshes':[],'nodes':[{'name':'Model','children':[1]},{'name':'Visual','mesh':0}],'scenes':[{'nodes':[0]}],'scene':0}
    data=bytearray();attrs={k:append(doc,data,v,t) for k,v,t in [('POSITION',m.vertices,'VEC3'),('NORMAL',m.normals,'VEC3'),('COLOR_0',m.colors,'VEC4')]}
    doc['meshes'].append({'name':'Visual','primitives':[{'attributes':attrs,'material':0}]});doc['buffers'][0]['byteLength']=len(data)
    assert len(m.vertices)//9<3200
    source.parent.mkdir(parents=True,exist_ok=True);source.write_bytes(write(doc,data))
    folder=ROOT/f'models/props/{name}';folder.mkdir(parents=True,exist_ok=True)
    (folder/'model.tscn').write_text(f'[gd_scene format=3]\n[ext_resource type="PackedScene" path="res://models/props/{name}/model.glb" id="1"]\n[node name="Landmark" type="Node3D"]\n[node name="Model" parent="." instance=ExtResource("1")]\n')
    (folder/'definition.tres').write_text(f'[gd_resource type="Resource" format=3]\n[ext_resource type="Script" path="res://models/model_definition.gd" id="1"]\n[resource]\nscript = ExtResource("1")\ncontract_version = 2\nid = "{name}"\ncategory = "props"\nscene_path = "res://models/props/{name}/model.tscn"\nsource_path = "res://models/props/{name}/SOURCE.md"\nbase_size = Vector3{size}\nvisibility_range = 2200.0\n')
    if not (name == 'sungnyemun_gate' and (folder/'heritage_atlas.png').exists()):
        (folder/'material.tres').write_text('[gd_resource type="StandardMaterial3D" format=3]\n[resource]\nvertex_color_use_as_albedo = true\nroughness = 0.65\n'+('transparency = 1\ncull_mode = 2\n' if transparent else ''))
    with (folder/'definition.tres').open('a') as output:
        output.write(f'material_path = "res://models/props/{name}/material.tres"\n')
    if not (name == 'sungnyemun_gate' and (folder/'heritage_atlas.png').exists()):
        (folder/'SOURCE.md').write_text(f'# {name}\n\nInitial SJ 자체 제작 GLB. tools/bake_seoul_landmarks.py의 오프라인 형상 제작. 원본은 model_sources/props/{name}/model.glb에 보존합니다. 실척(m): {size}. 서울 실루엣을 참고한 게임용 해석이며 외부 모델·상표·사진을 사용하지 않습니다. 숭례문 통과 폭은 게임 도로에 맞추고 탑은 도로 밖 원경에 배치합니다.\n')

def main():
    from sungnyemun_geometry import make_gate
    m=make_gate()
    save('sungnyemun_gate',m,(64,49,24))
    m=ColoredMesh();ring(m,0,8,145,(.73,.75,.74,1),upper=4);ring(m,145,15,16,(.34,.4,.42,1));ring(m,161,10,12,(.16,.28,.35,1));ring(m,173,4,63,(.78,.79,.76,1),upper=.3);save('namsan_tower',m,(30,236,30))
    m=ColoredMesh();m.box((0,124.5,0),(42,249,28),(.7,.49,.18,1))
    for y in range(5,248,4):m.box((0,y,14.1),(42,.6,.2),(.23,.27,.27,1))
    for x in range(-18,20,4):m.box((x,124.5,14.3),(.35,249,.25),(.88,.71,.37,1))
    save('golden_63_tower',m,(42,249,29))
    m=ColoredMesh()
    for i in range(16):
        a,b=math.pi*i/16,math.pi*(i+1)/16
        p=[(math.cos(t)*18,3+math.sin(t)*12,z) for z in [-4,4] for t in [a,b]]
        m.tri(p[0],p[2],p[3],(.2,.75,.85,.20));m.tri(p[0],p[3],p[1],(.2,.75,.85,.20))
        m.box((math.cos(a)*18,3+math.sin(a)*12,0),(.25,.25,8),(.22,.8,.9,1))
    for x in [-18,18]:m.box((x,1.5,0),(.4,3,8),(.2,.65,.73,.45))
    save('carnival_glass_gallery',m,(37,16,8),True)
    m=ColoredMesh();m.box((0,.5,0),(1,1,1),(.44,.46,.45,1));save('skyway_abutment',m,(1,1,1))
def configure_imports():
    for name in ['sungnyemun_gate','namsan_tower','golden_63_tower','carnival_glass_gallery','skyway_abutment']:
        if ONLY and name != ONLY: continue
        path=ROOT/f'models/props/{name}/model.glb.import'
        if not path.exists():raise SystemExit('먼저 Godot --editor --import --quit을 실행하세요')
        text=path.read_text()
        if 'use_external/enabled' in text:continue
        assert '_subresources={}' in text,path
        text=text.replace('_subresources={}', '_subresources={\n"materials": {\n"'+name+'": {\n"use_external/enabled": true,\n"use_external/path": "res://models/props/'+name+'/material.tres"\n}\n}\n}')
        path.write_text(text)

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--only', choices=['sungnyemun_gate','namsan_tower','golden_63_tower','carnival_glass_gallery','skyway_abutment'], help='지정 팩만 편집하고 다른 원본·조립 자료는 보존')
    parser.add_argument('--replace-generated',action='store_true',help='기존 자체 제작 원본을 SHA-256별 백업하고 재생성')
    parser.add_argument('--configure-imports',action='store_true',help='최초 Godot 임포트 뒤 정점색·유리 전용 재질 연결. UID 보존')
    args=parser.parse_args()
    REPLACE=args.replace_generated
    ONLY=args.only
    if args.configure_imports:configure_imports()
    else:main()
