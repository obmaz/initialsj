"""숭례문 원본 형상은 유지하고 석재·기와·단청 전용 UV를 연결한다."""
from pathlib import Path
import hashlib
import struct

from glb_geometry import accessor, read, write
from glb_shapes import append

ROOT = Path(__file__).resolve().parents[1]


def main():
    source = ROOT / 'model_sources/props/sungnyemun_gate/model.glb'
    original = source.read_bytes()
    doc, raw = read(original)
    binary = bytearray(raw[:doc['buffers'][0]['byteLength']])
    changed = False
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            attrs = primitive['attributes']
            if 'TEXCOORD_0' in attrs and 'TEXCOORD_1' in attrs:
                continue
            positions = list(struct.iter_unpack('<3f', accessor(doc, raw, attrs['POSITION'])[0]))
            normals = list(struct.iter_unpack('<3f', accessor(doc, raw, attrs['NORMAL'])[0]))
            colors = list(struct.iter_unpack('<4f', accessor(doc, raw, attrs['COLOR_0'])[0]))
            uv, regions = [], []
            for (x, y, z), normal, color in zip(positions, normals, colors):
                # UV0는 미터 단위 반복 좌표, UV1.x는0=석재·1=기와·2=단청이다.
                stone = abs(color[0] - color[1]) < .09 and color[0] > .3
                tile = color[0] < .15
                kind = 0 if stone else (1 if tile else 2)
                if tile or abs(normal[1]) > .7:
                    pair = (x / 4, z / 4)
                elif abs(normal[0]) > abs(normal[2]):
                    pair = (z / 6, -y / 6)
                else:
                    pair = (x / 6, -y / 6)
                uv.extend(pair)
                regions.extend((kind, 0))
            attrs['TEXCOORD_0'] = append(doc, binary, uv, 'VEC2')
            attrs['TEXCOORD_1'] = append(doc, binary, regions, 'VEC2')
            changed = True
    if not changed:
        print('숭례문 전용 UV는 이미 연결되어 있습니다')
        return
    backup = ROOT / 'build/reports/model-backups' / ('sungnyemun_gate-' + hashlib.sha256(original).hexdigest() + '.glb')
    backup.parent.mkdir(parents=True, exist_ok=True)
    if not backup.exists():
        backup.write_bytes(original)
    doc['buffers'][0]['byteLength'] = len(binary)
    source.write_bytes(write(doc, binary))
    print('원본 형상·정점색 보존, 전용 UV 추가:', source)


if __name__ == '__main__':
    main()
