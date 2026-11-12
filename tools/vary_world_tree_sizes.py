"""코스별 식생 MultiMesh의 저장된 크기를 구역별로 변주한다. 원본 GLB·위치는 보존한다."""
from pathlib import Path
import json, math, re
ROOT=Path(__file__).resolve().parents[1]

def main():
    refs=json.loads((ROOT/'models/shared/world_vegetation/references.json').read_text())['references']
    for path in sorted((ROOT/'models/world').glob('*/model.tscn')):
        text=path.read_text()
        if '; vegetation-size-schema=1' in text:continue
        targets=set()
        for block in re.split(r'(?=\[node )',text)[1:]:
            ref=re.search(r'metadata/mesh_ref = "([^"]+)"',block)
            mm=re.search(r'multimesh = SubResource\("([^"]+)"\)',block)
            if ref and mm and ref[1] in refs:targets.add(mm[1])
        def resource(match):
            block=match[0]
            name=re.search(r'id="([^"]+)"',block)
            if not name or name[1] not in targets:return block
            def buffer(m):
                values=[float(v) for v in m[1].split(',')]
                stride=12+(4 if 'use_colors = true' in block else 0)+(4 if 'use_custom_data = true' in block else 0)
                assert len(values)%stride==0
                for start in range(0,len(values),stride):
                    x,z=values[start+3],values[start+11]
                    zone=math.floor((x+z)/180)
                    district=[.70,1.0,1.32, .88][zone%4]
                    factor=district*(.91+.18*(math.sin(x*1.73+z*.83)*.5+.5))
                    for k in [0,1,2,4,5,6,8,9,10]:values[start+k]*=factor
                return 'buffer = PackedFloat32Array('+', '.join(format(v,'.8g') for v in values)+')'
            return re.sub(r'buffer = PackedFloat32Array\(([^)]*)\)',buffer,block)
        text=re.sub(r'\[sub_resource[^\n]*\][\s\S]*?(?=\n\[|\Z)',resource,text)
        if targets:
            path.write_text('; vegetation-size-schema=1\n'+text)
            print(path.parent.name,len(targets),'식생 배치 그룹')
if __name__=='__main__':main()
