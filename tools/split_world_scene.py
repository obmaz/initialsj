"""큰 코스 조립 씬을 공유 자원과 작은 연결 단위로 나눈다. GLB·배치는 변경하지 않는다."""
from pathlib import Path
import argparse
import hashlib
import re

ROOT = Path(__file__).resolve().parents[1]
NODE = re.compile(r'^\[node [^\n]+\]', re.M)
EXTERNAL = re.compile(r'^\[ext_resource [^\n]+\]\n', re.M)
SUB = re.compile(r'^\[sub_resource type="([^"]+)" id="([^"]+)"\]', re.M)


def split(folder, budget=24):
    path = folder / 'model.tscn'
    text = path.read_text()
    if 'metadata/assembly_parts' in text:
        print('이미 분할된 조립 씬:', path.relative_to(ROOT))
        return
    backup = ROOT / 'build/reports/model-backups' / (folder.name + '-' + hashlib.sha256(text.encode()).hexdigest() + '.tscn')
    backup.parent.mkdir(parents=True, exist_ok=True)
    if not backup.exists():
        backup.write_text(text)
    if re.search(r'^\[(?:connection|editable)\b', text, re.M):
        raise ValueError('연결 신호·편집 인스턴스가 있는 씬은 별도 연결 계약이 필요합니다')
    matches = list(NODE.finditer(text))
    if len(matches) < 2:
        raise ValueError('분할할 코스 노드가 없습니다')
    declarations = {re.search(r'id="([^"]+)"', m[0])[1]: m[0] for m in EXTERNAL.finditer(text)}
    shared = list(SUB.finditer(text[:matches[0].start()]))
    assembly = folder / 'assembly'
    assembly.mkdir(exist_ok=True)
    resource_path = 'res://' + (assembly / 'resources.tres').relative_to(ROOT).as_posix()
    resources = '[gd_resource type="Resource" format=3]\n\n' + ''.join(declarations.values())
    if shared:
        resources += '\n' + text[shared[0].start():matches[0].start()]
    resources += '\n[resource]\nmetadata/shared = [' + ', '.join('SubResource("' + m[2] + '")' for m in shared) + ']\n'
    (assembly / 'resources.tres').write_text(resources)
    for m in shared:
        declarations['shared_' + m[2]] = f'[ext_resource type="{m[1]}" path="{resource_path}::{m[2]}" id="shared_{m[2]}"]\n'

    def convert(body):
        return re.sub(r'SubResource\("([^"]+)"\)', r'ExtResource("shared_\1")', body)

    def headers(body):
        used = set(re.findall(r'ExtResource\("([^"]+)"\)', body))
        return ''.join(declarations[key] for key in declarations if key in used)

    blocks, children = {}, {}
    for i, match in enumerate(matches):
        block = text[match.start():matches[i + 1].start() if i + 1 < len(matches) else len(text)]
        name = re.search(r'name="([^"]+)"', match[0])[1]
        parent_match = re.search(r'parent="([^"]+)"', match[0])
        if parent_match is None:
            root_block = block
            continue
        parent = parent_match[1]
        node_path = name if parent == '.' else parent + '/' + name
        blocks[node_path] = block
        children.setdefault(parent, []).append(node_path)

    def subtree(node):
        result = [node]
        for child in children.get(node, []):
            result.extend(subtree(child))
        return result

    parts = []

    def emit(nodes, parent):
        body = '[node name="AssemblyPart" type="Node3D"]\nmetadata/assembly_resources = ExtResource("assembly")\n\n'
        for node in nodes:
            block = blocks[node]
            if parent != '.':
                first, rest = block.split('\n', 1)
                original_parent = re.search(r'parent="([^"]+)"', first)[1]
                local_parent = '.' if original_parent == parent else original_parent.removeprefix(parent + '/')
                first = first.replace('parent="' + original_parent + '"', 'parent="' + local_parent + '"')
                block = first + '\n' + rest
            body += block
        body = convert(body)
        filename = f'part_{len(parts):03d}.tscn'
        (assembly / filename).write_text('[gd_scene format=3]\n\n' + f'[ext_resource type="Resource" path="{resource_path}" id="assembly"]\n' + headers(body) + '\n' + body)
        parts.append({'path': 'res://' + (assembly / filename).relative_to(ROOT).as_posix(), 'parent': parent})

    def group(parent):
        pending = []
        for child in children.get(parent, []):
            branch = subtree(child)
            if len(branch) > budget:
                if pending:
                    emit(pending, parent)
                    pending = []
                emit([child], parent)
                group(child)
            else:
                if len(pending) + len(branch) > budget:
                    emit(pending, parent)
                    pending = []
                pending.extend(branch)
        if pending:
            emit(pending, parent)

    group('.')
    root_block = convert(root_block)
    manifest = '[ ' + ', '.join('{"path": "' + p['path'] + '", "parent": "' + p['parent'] + '"}' for p in parts) + ' ]'
    root_block += '\nmetadata/assembly_parts = ' + manifest + '\nmetadata/assembly_resources = ExtResource("assembly")\n'
    path.write_text('; vegetation-size-schema=1\n[gd_scene format=3]\n\n' + f'[ext_resource type="Resource" path="{resource_path}" id="assembly"]\n' + headers(root_block) + '\n' + root_block)
    profile = folder / 'profile.tres'
    original = profile.read_text()
    dependencies = [resource_path] + [p['path'] for p in parts]
    original = re.sub(r'(metadata/dependencies = Array\[String\]\(\[)(.*?)(\]\))',
                      lambda m: m[1] + m[2] + ', ' + ', '.join('"' + p + '"' for p in dependencies) + m[3], original)
    profile.write_text(original)
    print(folder.name, '조립 단위', len(parts), '노드', len(blocks), '단위 최대', budget)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--world', required=True, help='models/world 안의 코스 ID')
    args = parser.parse_args()
    folder = (ROOT / 'models/world' / args.world).resolve()
    if folder.parent != (ROOT / 'models/world').resolve():
        raise ValueError('코스 팩 ID만 지정하세요')
    split(folder)


if __name__ == '__main__':
    main()
