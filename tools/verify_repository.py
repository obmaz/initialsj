#!/usr/bin/env python3
"""Check live resource reachability, sidecars and maintained Markdown links."""
from pathlib import Path
import re
import sys
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
RESOURCE = re.compile(r'''["']res://([^"'\n]+)["']''')
LINK = re.compile(r'!?\[[^\]]*\]\(([^\s)]+)(?:\s+"[^"]*")?\)')
# The retirement worker is served at a compatibility URL by the deploy workflow.
ROOTS = ("project.godot", "export_presets.cfg", "web/retire-flutter-worker.js")
MODEL_DIRECTORIES = {"models/props", "models/vehicles", "models/buildings"}
errors = []


def text(path):
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeError:
        return ""


def live_resources():
    pending = list(ROOTS)
    reached = set()
    while pending:
        name = pending.pop()
        if name in reached:
            continue
        reached.add(name)
        path = ROOT / name
        if name in MODEL_DIRECTORIES and path.is_dir():
            pending.extend(p.relative_to(ROOT).as_posix() for p in path.glob("*/definition.tres"))
            continue
        if not path.is_file():
            errors.append(f"Missing runtime resource: {name}")
            continue
        pending.extend(RESOURCE.findall(text(path)))
    return reached


def check_sources(reached):
    for folder in ("scripts", "shaders", "scenes", "assets", "web", "models", "tests"):
        for path in (ROOT / folder).rglob("*"):
            if not path.is_file():
                continue
            name = path.relative_to(ROOT).as_posix()
            if path.name == "AGENTS.md":
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
            if folder in ("scripts", "shaders", "scenes", "web") and name not in reached:
                errors.append(f"Unreferenced runtime source: {name}")
            if folder == "assets" and path.suffix not in (".txt", ".md") and name not in reached:
                errors.append(f"Unreferenced runtime asset: {name}")
            if folder == "models" and path.suffix not in (".txt", ".md") and name not in reached:
                errors.append(f"Unreferenced model resource: {name}")
            if path.suffix in (".gd", ".tscn", ".tres", ".gdshader"):
                for ref in RESOURCE.findall(text(path)):
                    if ref == "build/reports" or ref.startswith("build/reports/"):
                        continue
                    if not (ROOT / ref).exists():
                        errors.append(f"Broken resource in {name}: {ref}")


def check_docs():
    documents = [ROOT / "README.md", ROOT / "AGENTS.md"]
    documents.extend((ROOT / "docs").rglob("*.md"))
    documents.extend((ROOT / "assets").rglob("*.md"))
    documents.extend((ROOT / "models").rglob("*.md"))
    documents.extend((ROOT / ".agents").rglob("*.md"))
    documents.extend((ROOT / ".claude").rglob("*.md"))
    for path in documents:
        for target in LINK.findall(text(path)):
            if target.startswith(("https://", "http://", "mailto:", "#")):
                continue
            target = unquote(target.strip("<>").split("#", 1)[0])
            if target and not (path.parent / target).exists():
                errors.append(f"Broken link in {path.relative_to(ROOT)}: {target}")
    for path in (ROOT / "docs").rglob("*"):
        # APK 기록 스키마는 임시 보고서가 아니라 문서가 참조하는 검증 기준입니다.
        if path.is_file() and path.suffix != ".md" and path != ROOT / "docs/apk-build-record.schema.json":
            errors.append(f"Generated review artifact belongs in build/reports/: {path.relative_to(ROOT)}")


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


reached = live_resources()
check_audio_licences()
check_sources(reached)
check_docs()
if errors:
    print("\n".join(sorted(set(errors))), file=sys.stderr)
    sys.exit(1)
print(f"Repository resources, sidecars and documentation links: PASS ({len(reached)} live resources)")
