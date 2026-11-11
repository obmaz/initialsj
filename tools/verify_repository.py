#!/usr/bin/env python3
"""실행 리소스·사이드카·셰이더 바인딩·문서 링크를 검증합니다."""
from pathlib import Path
import re
import sys
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
RESOURCE = re.compile(r'''["']res://([^"'\n]+)["']''')
LINK = re.compile(r'!?\[[^\]]*\]\(\s*(<[^>\n]+>|[^\s)]+)(?:\s+"[^"]*")?\s*\)')
# 이전 워커 주소로도 제공해야 하는 호환 리소스입니다.
ROOTS = ("project.godot", "export_presets.cfg", "web/retire-flutter-worker.js")
MODEL_DIRECTORIES = {"models/props", "models/vehicles", "models/buildings", "models/vegetation"}
UID_SOURCES = {".gd", ".gdshader", ".gdshaderinc"}
IMPORTED_SOURCES = {".png", ".webp", ".svg", ".wav", ".ogg", ".ttf", ".obj", ".glb"}
BUILD_METADATA = {"models/shared/world_vegetation/generated.json"}
errors = []


def text(path):
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeError:
        return ""


def resource_refs(source):
    """GLB의 메시 노드 연결점은 # 뒤에 있고 파일 검사는 원본 경로에 적용합니다."""
    return [ref.partition("#")[0] if ".glb#" in ref else ref for ref in RESOURCE.findall(source)]


def live_resources():
    pending = list(ROOTS)
    reached = set()
    while pending:
        name = pending.pop()
        if name in reached:
            continue
        reached.add(name)
        path = ROOT / name
        if name.rstrip("/") == "models/world" and path.is_dir():
            pending.extend(p.relative_to(ROOT).as_posix() for pattern in ("*/model.tscn", "*/profile.tres") for p in path.glob(pattern))
            continue
        if name in MODEL_DIRECTORIES and path.is_dir():
            pending.extend(p.relative_to(ROOT).as_posix() for p in path.glob("*/definition.tres"))
            continue
        if not path.is_file():
            errors.append(f"Missing runtime resource: {name}")
            continue
        pending.extend(resource_refs(text(path)))
    return reached


def check_sources(reached):
    for folder in ("scripts", "shaders", "scenes", "assets", "web", "models", "tests", "addons", "tools"):
        for path in (ROOT / folder).rglob("*"):
            if not path.is_file():
                continue
            name = path.relative_to(ROOT).as_posix()
            if path.name == "AGENTS.md":
                continue
            if name in BUILD_METADATA:
                continue
            if path.suffix == ".mtl":
                # An OBJ model's material file is read by the importer, not by res:// references.
                if not path.with_suffix(".obj").is_file():
                    errors.append(f"Orphan material file: {name}")
                continue
            if path.suffix in (".uid", ".import"):
                if not Path(str(path).rsplit(".", 1)[0]).is_file():
                    errors.append(f"Orphan sidecar: {name}")
                continue
            sidecar = ".uid" if path.suffix in UID_SOURCES else (
                ".import" if path.suffix in IMPORTED_SOURCES else None
            )
            if sidecar and not Path(str(path) + sidecar).is_file():
                errors.append(f"Missing sidecar: {name}{sidecar}")
            if folder in ("scripts", "shaders", "scenes", "web") and name not in reached:
                errors.append(f"Unreferenced runtime source: {name}")
            if folder == "assets" and path.suffix not in (".txt", ".md") and name not in reached:
                errors.append(f"Unreferenced runtime asset: {name}")
            if folder == "models" and path.suffix not in (".txt", ".md") and name not in reached:
                errors.append(f"Unreferenced model resource: {name}")
            if folder in ("scripts", "models") and path.suffix == ".gd":
                if re.search(r"\b(?:SurfaceTool|ArrayMesh|BoxMesh|PlaneMesh|QuadMesh|CylinderMesh|SphereMesh|TorusMesh|PrismMesh|CapsuleMesh|TextMesh)\.new\s*\(", text(path)):
                    errors.append(f"Runtime geometry generator must use GLB assets: {name}")
            if path.suffix in (".gd", ".tscn", ".tres", ".gdshader"):
                for ref in resource_refs(text(path)):
                    if ref == "build/reports" or ref.startswith("build/reports/"):
                        continue
                    if not (ROOT / ref).exists():
                        errors.append(f"Broken resource in {name}: {ref}")


def markdown_anchors(source):
    """검사 대상 문서의 GitHub 형식 제목 앵커. 코드 블록의 #은 제목으로 세지 않습니다."""
    anchors = set()
    fenced = None
    for line in source.splitlines():
        fence = re.match(r"^\s*(`{3,}|~{3,})", line)
        if fence:
            marker = fence[1][0]
            fenced = None if fenced == marker else (marker if fenced is None else fenced)
        if fenced or fence:
            continue
        heading = re.match(r"^#{1,6}\s+(.+?)\s*#*\s*$", line)
        if not heading:
            continue
        label = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", heading[1])
        slug = re.sub(r"[^\w -]", "", label.lower()).replace(" ", "-")
        candidate = slug
        duplicate = 0
        while candidate in anchors:
            duplicate += 1
            candidate = f"{slug}-{duplicate}"
        anchors.add(candidate)
    return anchors


def check_docs():
    documents = [ROOT / name for name in ("README.md", "AGENTS.md", "CLAUDE.md", "GEMINI.md")]
    documents.extend((ROOT / "docs").rglob("*.md"))
    documents.extend((ROOT / "assets").rglob("*.md"))
    documents.extend((ROOT / "models").rglob("*.md"))
    documents.extend((ROOT / "model_sources").rglob("*.md"))
    documents.extend((ROOT / ".agents").rglob("*.md"))
    documents.extend((ROOT / ".claude").rglob("*.md"))
    for path in documents:
        for target in LINK.findall(text(path)):
            if target.startswith(("https://", "http://", "mailto:")):
                continue
            target, _, anchor = unquote(target.strip("<>")).partition("#")
            linked = path.parent / target if target else path
            if not linked.exists():
                errors.append(f"Broken link in {path.relative_to(ROOT)}: {target}")
            elif anchor and linked.suffix == ".md" and anchor not in markdown_anchors(text(linked)):
                errors.append(f"Broken anchor in {path.relative_to(ROOT)}: {target}#{anchor}")
    for path in (ROOT / "docs").rglob("*"):
        # APK 기록 스키마는 임시 보고서가 아니라 문서가 참조하는 검증 기준입니다.
        if path.is_file() and path.suffix != ".md" and path != ROOT / "docs/apk-build-record.schema.json":
            errors.append(f"Generated review artifact belongs in build/reports/: {path.relative_to(ROOT)}")


def expanded_shader(path, visited=None):
    """공통 include 안에서만 참조하는 sampler도 실제 사용으로 처리합니다."""
    visited = set() if visited is None else visited
    if path in visited or not path.is_file():
        return ""
    visited.add(path)
    source = text(path)
    return re.sub(
        r'#include\s+"res://([^"\n]+)"',
        lambda match: expanded_shader(ROOT / match[1], visited),
        source,
    )


def check_shader_samplers():
    for path in (ROOT / "shaders").rglob("*.gdshader"):
        source = re.sub(r"/\*.*?\*/|//[^\n]*", "", expanded_shader(path), flags=re.S)
        for sampler in re.findall(r"\buniform\s+sampler\w+\s+(\w+)", source):
            if len(re.findall(rf"\b{re.escape(sampler)}\b", source)) == 1:
                errors.append(f"Unused shader sampler in {path.relative_to(ROOT)}: {sampler}")


def check_audio_licences():
    """Every shipped sound must be covered by assets/audio/LICENSE.txt (and its vehicle pattern)."""
    licence = text(ROOT / "assets/audio/LICENSE.txt")
    for path in (ROOT / "assets/audio").rglob("*"):
        if path.suffix not in (".wav", ".ogg", ".json"):
            continue
        name = path.relative_to(ROOT / "assets/audio").as_posix()
        if name.startswith("vehicles/"):
            if "vehicles/<id>-engine.ogg" not in licence:
                errors.append("Vehicle audio is not covered by assets/audio/LICENSE.txt")
        elif path.name not in licence:
            errors.append(f"Audio file without a licence entry: assets/audio/{name}")


def main():
    errors.clear()
    if (ROOT / "model_sources").exists() or (ROOT / "models/shared/world_vegetation/generated.json").exists():
        from optimize_models import run
        try:
            run(ROOT, check=True)
        except (ValueError, OSError, KeyError) as error:
            errors.append(str(error))
    reached = live_resources()
    check_audio_licences()
    check_sources(reached)
    check_docs()
    check_shader_samplers()
    if errors:
        print("\n".join(sorted(set(errors))), file=sys.stderr)
        return 1
    print(f"Repository resources, sidecars, shader samplers and documentation links: PASS ({len(reached)} live resources)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
