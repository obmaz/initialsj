"""오프라인 GLB 제작용 정점색 형상과 버퍼 직렬화. 런타임에서는 사용하지 않는다."""
import math
import struct

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


class ColoredMesh:
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
