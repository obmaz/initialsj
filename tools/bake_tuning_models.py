"""차량 도장면을 원본에서 분리하고 교체 부품을 오프라인 GLB로 만든다."""
from pathlib import Path
import copy
import math
import struct
import json
import argparse
import hashlib
from glb_geometry import read, write, accessor, indices

ROOT = Path(__file__).resolve().parents[1]
REPLACE_PARTS = False


def backup(path):
    data=path.read_bytes()
    target=ROOT/"build/reports/model-backups"/(path.parent.name+"-"+hashlib.sha256(data).hexdigest()[:12]+".glb")
    target.parent.mkdir(parents=True,exist_ok=True)
    if not target.exists(): target.write_bytes(data)


def append(doc, binary, values, kind, component=5126):
    width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[kind]
    binary.extend(b"\0" * (-len(binary) % 4))
    raw = struct.pack("<" + ("I" if component == 5125 else "f") * len(values), *values)
    view = len(doc["bufferViews"])
    doc["bufferViews"].append({"buffer": 0, "byteOffset": len(binary), "byteLength": len(raw)})
    binary.extend(raw)
    item = {"bufferView": view, "componentType": component, "count": len(values)//width, "type": kind}
    if kind == "VEC3":
        item["min"] = [min(values[i::3]) for i in range(3)]
        item["max"] = [max(values[i::3]) for i in range(3)]
    doc["accessors"].append(item)
    return len(doc["accessors"])-1


def paint_shell(model):
    path = ROOT / f"model_sources/vehicles/{model}/model.glb"
    doc, raw = read(path.read_bytes())
    if any(n.get("name") == "PaintShell" for n in doc["nodes"]):
        return
    body = next(n for n in doc["nodes"] if n.get("name") == "BodyShell")
    primitive = doc["meshes"][body["mesh"]]["primitives"][0]
    colors = list(struct.iter_unpack("<4f", accessor(doc, raw, primitive["attributes"]["COLOR_0"])[0]))
    positions = list(struct.iter_unpack("<3f", accessor(doc, raw, primitive["attributes"]["POSITION"])[0]))
    triangles = indices(doc, raw, primitive)
    paint, trim = [], []
    for i in range(0, len(triangles), 3):
        face = triangles[i:i+3]
        (paint if all(colors[j][3] < .75 for j in face) else trim).extend(face)
    assert paint and trim
    lo = [min(p[i] for p in positions) for i in range(3)]
    hi = [max(p[i] for p in positions) for i in range(3)]
    uv = []
    for x,y,z in positions:
        uv.extend(((z-lo[2])/max(.001,hi[2]-lo[2]),
                   (math.atan2(x-(lo[0]+hi[0])*.5,y-(lo[1]+hi[1])*.5)+math.pi)/math.tau))
    binary = bytearray(raw)
    skin = copy.deepcopy(primitive)
    skin["indices"] = append(doc,binary,paint,"SCALAR",5125)
    skin["attributes"]["TEXCOORD_0"] = append(doc,binary,uv,"VEC2")
    trim_primitive = copy.deepcopy(primitive)
    trim_primitive["indices"] = append(doc,binary,trim,"SCALAR",5125)
    trim_node = copy.deepcopy(body)
    trim_node.update(name="TrimShell",mesh=len(doc["meshes"]))
    doc["meshes"].append({"name":"TrimShell","primitives":[trim_primitive]})
    trim_index=len(doc["nodes"])
    doc["nodes"].append(trim_node)
    node = copy.deepcopy(body)
    node.update(name="PaintShell",mesh=len(doc["meshes"]))
    doc["meshes"].append({"name":"PaintShell","primitives":[skin]})
    new_index=len(doc["nodes"])
    doc["nodes"].append(node)
    parent=next((n for n in doc["nodes"][:-1] if doc["nodes"].index(body) in n.get("children",[])),None)
    if parent is not None: parent["children"].extend([trim_index,new_index])
    else: doc["scenes"][doc.get("scene",0)]["nodes"].extend([trim_index,new_index])
    doc["buffers"][0]["byteLength"]=len(binary)
    backup(path)
    path.write_bytes(write(doc,binary))
    folder=ROOT/f"models/vehicles/{model}"
    (folder/"livery-uv.json").write_text(json.dumps({"schema":1,"node":"PaintShell","boundsMin":lo,"boundsMax":hi,"paintTriangles":len(paint)//3,"originalTriangles":len(triangles)//3,"mapping":"longitudinal U, cylindrical cross-section V; underside seam; trim preserves original UV"},indent=2)+"\n")
    with (folder/"SOURCE.md").open("a") as f:
        f.write("\n도장면은 원본 BodyShell의 기존 면만 PaintShell로 분리했습니다. 형상·법선·비도장 UV를 보존하며 전용 UV0는 livery-uv.json의 종방향·단면 원통 전개을 사용합니다. 리버리 이미지는 models/shared/vehicle_liveries/SOURCE.md를 따릅니다.\n")


class Mesh:
    def __init__(self): self.vertices=[]; self.normals=[]; self.colors=[]
    def tri(self,a,b,c,color):
        ab=[b[i]-a[i] for i in range(3)];ac=[c[i]-a[i] for i in range(3)]
        n=[ab[1]*ac[2]-ab[2]*ac[1],ab[2]*ac[0]-ab[0]*ac[2],ab[0]*ac[1]-ab[1]*ac[0]]
        length=math.sqrt(sum(x*x for x in n)) or 1
        for p in [a,b,c]: self.vertices.extend(p);self.normals.extend(x/length for x in n);self.colors.extend(color)
    def slab(self,points,color):
        front=[(p[0],p[1]+.035,p[2]) for p in points]
        back=[(p[0],p[1]-.035,p[2]) for p in points]
        self.tri(front[0],front[2],front[1],color);self.tri(front[0],front[3],front[2],color)
        self.tri(back[0],back[1],back[2],color);self.tri(back[0],back[2],back[3],color)
        for i in range(4):
            j=(i+1)%4
            self.tri(front[i],back[i],back[j],color);self.tri(front[i],back[j],front[j],color)
    def box(self,center,size,color):
        points=[tuple(center[j]+size[j]*(.5 if i&(1<<j) else -.5) for j in range(3)) for i in range(8)]
        for a,b,c,d in [(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3),(0,2,3,1),(4,5,7,6)]:
            self.tri(points[a],points[b],points[c],color);self.tri(points[a],points[c],points[d],color)
    def save(self,name):
        doc={"asset":{"version":"2.0","generator":"Initial SJ offline tuning parts"},"buffers":[{}],"bufferViews":[],"accessors":[],"materials":[{"name":"TuningPart","pbrMetallicRoughness":{"baseColorFactor":[1,1,1,1],"metallicFactor":.65,"roughnessFactor":.28}}],"meshes":[],"nodes":[{"name":"Visual","mesh":0}],"scenes":[{"nodes":[0]}],"scene":0}
        data=bytearray()
        attrs={key:append(doc,data,values,kind) for key,values,kind in [("POSITION",self.vertices,"VEC3"),("NORMAL",self.normals,"VEC3"),("COLOR_0",self.colors,"VEC4")]}
        doc["meshes"].append({"name":"Visual","primitives":[{"attributes":attrs,"material":0}]})
        doc["buffers"][0]["byteLength"]=len(data)
        source=ROOT/f"model_sources/vehicle_parts/{name}/model.glb";source.parent.mkdir(parents=True,exist_ok=True)
        if source.exists():
            if not REPLACE_PARTS: return
            backup(source)
        source.write_bytes(write(doc,data))
        folder=ROOT/f"models/vehicle_parts/{name}";folder.mkdir(parents=True,exist_ok=True)
        (folder/"model.tscn").write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="PackedScene" path="res://models/vehicle_parts/'+name+'/model.glb" id="1"]\n[node name="Part" type="Node3D"]\n[node name="Model" parent="." instance=ExtResource("1")]\n')
        (folder/"definition.tres").write_text('[gd_resource type="Resource" format=3]\n[ext_resource type="Script" path="res://models/model_definition.gd" id="1"]\n[resource]\nscript = ExtResource("1")\nid = "'+name+'"\ncategory = "vehicle_parts"\nscene_path = "res://models/vehicle_parts/'+name+'/model.tscn"\nsource_path = "res://models/vehicle_parts/'+name+'/SOURCE.md"\n')
        (folder/"SOURCE.md").write_text("# 튜닝 부품\n\nInitial SJ 자체 제작. tools/bake_tuning_models.py로 오프라인 제작한 GLB입니다. 형상 원본은 model_sources/vehicle_parts/에 보존합니다. 휠은 로컬+Y 회전축·반경1, 윙은 폭1이며 어댑터가 차량 실척에 맞춥니다.\n")


def parts():
    for name,count in [("five_spoke",5),("split_spoke",10)]:
        mesh=Mesh()
        for i in range(count):
            a=math.tau*i/count
            # 평면 XZ, 바깥쪽 면은+Y. 원본 타이어·피벗은 그대로 둔다.
            direction=(math.cos(a),math.sin(a));side=(-direction[1],direction[0])
            pts=[(direction[0]*r+side[0]*w,.03,direction[1]*r+side[1]*w) for r,w in [(.15,-.07),(.82,-.045),(.82,.045),(.15,.07)]]
            mesh.slab(pts,(1,1,1,1))
        for i in range(48):
            a,b=math.tau*i/48,math.tau*(i+1)/48
            p=[(math.cos(t)*r,.03,math.sin(t)*r) for t,r in [(a,.82),(b,.82),(b,.9),(a,.9)]]
            mesh.slab(p,(1,1,1,1))
        mesh.box((0,0,0),(.22,.09,.22),(1,1,1,1));mesh.save(name)
    for name,height,depth in [("ducktail",.10,.20),("gt_wing",.32,.32)]:
        mesh=Mesh();mesh.box((0,height,0),(1,.06,depth),(.15,.19,.22,1))
        for x in [-.32,.32]:mesh.box((x,height*.5,0),(.045,height,.13),(.35,.39,.42,1))
        if name=="gt_wing":
            for x in [-.49,.49]:mesh.box((x,height+.05,0),(.035,.17,.36),(.15,.19,.22,1))
        mesh.save(name)


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--replace-generated-parts",action="store_true",help="기존 부품 원본을 해시별 백업한 뒤 의도적으로 재생성")
    REPLACE_PARTS=parser.parse_args().replace_generated_parts
    for model in ["hatch","wedge","muscle","gt"]: paint_shell(model)
    parts()
