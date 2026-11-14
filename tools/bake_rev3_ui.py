"""승인된 rev3 원화를 게임용 PNG 부품과 공통 좌표 목록으로 분리합니다."""
from pathlib import Path
import argparse
import hashlib
import json

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage


ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / "art_sources/ui/kit/rev3"
REFERENCES = ROOT / "art_sources/ui/reference/rev3"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_text(path, value):
    path.write_text(value, encoding="utf-8", newline="\n")


def shape_mask(size, item):
    """마스크·표시·터치는 동일한 원화 좌표를 사용합니다."""
    mask = Image.new("L", size)
    draw = ImageDraw.Draw(mask)
    x, y, width, height = item["rect"]
    bounds = (x, y, x + width - 1, y + height - 1)
    if item.get("polygon"):
        draw.polygon(item["polygon"], fill=255)
    elif item.get("shape") == "ellipse":
        draw.ellipse(bounds, fill=255)
    else:
        draw.rounded_rectangle(bounds, radius=item.get("radius", 0), fill=255)
    return mask


def visual_mask(source, item):
    mask = shape_mask(source.size, item)
    if item.get("plate_alpha"):
        bounds = mask.getbbox()
        rgb = np.asarray(source.crop(bounds))[:, :, :3].astype(np.int16)
        red, green, blue = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
        selected = ((red < blue * .81) & (green > red * 1.1))
        selected |= (rgb.min(axis=2) > 155) & ((rgb.max(axis=2) - rgb.min(axis=2)) < 75)
        selected |= (red > 168) & (green > 115) & (red > blue * 1.3)
        selected &= np.asarray(mask.crop(bounds)) > 0
        labels, count = ndimage.label(selected)
        if count:
            sizes = np.bincount(labels.ravel())
            sizes[0] = 0
            selected = ndimage.binary_fill_holes(labels == sizes.argmax())
        local = Image.fromarray((selected * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))
        result = Image.new("L", source.size)
        result.paste(local, bounds[:2])
        return Image.fromarray(np.minimum(np.asarray(mask), np.asarray(result)))
    if not item.get("transparent"):
        return mask
    bounds = mask.getbbox()
    if not bounds:
        return mask
    rgb = np.asarray(source.crop(bounds))[:, :, :3].astype(np.int16)
    white = (rgb.min(axis=2) > 176) & ((rgb.max(axis=2) - rgb.min(axis=2)) < 85)
    gold = (rgb[:, :, 0] > 168) & (rgb[:, :, 1] > 120) & (rgb[:, :, 0] > rgb[:, :, 2] * 1.3)
    selected = (white | gold) & (np.asarray(mask.crop(bounds)) > 0)
    labels, count = ndimage.label(selected)
    sizes = np.bincount(labels.ravel())
    if count:
        keep = sizes >= max(5, rgb.shape[0] * rgb.shape[1] * .0004)
        keep[0] = False
        selected = keep[labels]
    local = Image.fromarray((selected * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))
    result = Image.new("L", source.size)
    result.paste(local, bounds[:2])
    return Image.fromarray(np.minimum(np.asarray(mask), np.asarray(result)))


def fill_plate(source, parent_mask, removed_mask):
    """부품 뒤의 단순 UI 재질을 복원합니다. 풍경 복원은 image_gen 원본을 사용합니다."""
    bounds = parent_mask.getbbox()
    if not bounds:
        return source.copy()
    original = source
    source = source.crop(bounds)
    parent_mask = parent_mask.crop(bounds)
    removed_mask = removed_mask.crop(bounds)
    pixels = np.asarray(source).copy()
    parent = np.asarray(parent_mask) > 0
    removed = np.asarray(removed_mask) > 0
    candidates = parent & ~removed
    if not candidates.any():
        return original.copy()
    rgb = pixels[:, :, :3].astype(np.float32)
    samples = rgb[candidates]
    median = np.median(samples[::max(1, len(samples) // 20000)], axis=0)
    # 사진·아이콘 대신 패널의 우세 색상에서 완만한 2차원 재질을 추정합니다.
    usable = candidates & (np.linalg.norm(rgb - median, axis=2) < 75)
    yy, xx = np.nonzero(usable)
    if len(xx) < 12:
        pixels[removed, :3] = median.astype(np.uint8)
        result = original.copy()
        result.paste(Image.fromarray(pixels), bounds[:2])
        return result
    step = max(1, len(xx) // 12000)
    xx, yy = xx[::step], yy[::step]
    x_scale, y_scale = max(1, source.width), max(1, source.height)
    matrix = np.column_stack((np.ones(len(xx)), xx / x_scale, yy / y_scale))
    weights, *_ = np.linalg.lstsq(matrix, rgb[yy, xx], rcond=None)
    target_y, target_x = np.nonzero(removed)
    target = np.column_stack((np.ones(len(target_x)), target_x / x_scale, target_y / y_scale))
    pixels[target_y, target_x, :3] = np.clip(target @ weights, 0, 255).round().astype(np.uint8)
    result = original.copy()
    result.paste(Image.fromarray(pixels), bounds[:2])
    return result


def glyph_mask(source, parent_mask):
    bounds = parent_mask.getbbox()
    if not bounds:
        return Image.new("L", source.size)
    original_size = source.size
    source = source.crop(bounds)
    parent_mask = parent_mask.crop(bounds)
    pixels = np.asarray(source)
    rgb = pixels[:, :, :3].astype(np.int16)
    white = (rgb.min(axis=2) > 188) & ((rgb.max(axis=2) - rgb.min(axis=2)) < 70)
    white &= np.asarray(parent_mask) > 0
    result = Image.fromarray((white * 255).astype(np.uint8))
    # 원화의 안티앨리어싱 가장자리까지 보존하되 주변 풍경을 가져오지 않습니다.
    result = result.filter(ImageFilter.MaxFilter(3))
    icon = Image.fromarray(np.minimum(np.asarray(result), np.asarray(parent_mask)))
    result = Image.new("L", original_size)
    result.paste(icon, bounds[:2])
    return result


class Exporter:
    def __init__(self, output):
        self.output = output
        self.assets = {}
        self.output.mkdir(parents=True, exist_ok=True)
        (self.output / "sprites").mkdir(exist_ok=True)
        (self.output / "backgrounds").mkdir(exist_ok=True)

    def save_asset(self, image, role):
        data = image.tobytes()
        fingerprint = hashlib.sha256(str(image.size).encode() + data).hexdigest()[:24]
        asset_id = "part_" + fingerprint
        if asset_id not in self.assets:
            relative = f"sprites/{asset_id}.png"
            path = self.output / relative
            image.save(path, optimize=True)
            alpha = np.asarray(image.getchannel("A"))
            self.assets[asset_id] = {
                "file": relative, "size": list(image.size), "sha256": digest(path),
                "role": role, "has_transparency": bool((alpha < 255).any()),
            }
        return asset_id

    def pack_glyphs(self):
        """작은 알파 아이콘을 여백이 있는 아틀라스로 묶습니다. 원 PNG도 보존합니다."""
        atlas_folder = self.output / "atlases"
        atlas_folder.mkdir(exist_ok=True)
        candidates = [(name, asset) for name, asset in self.assets.items()
                      if asset["role"] == "glyph" and max(asset["size"]) <= 320]
        candidates.sort(key=lambda pair: (-pair[1]["size"][1], -pair[1]["size"][0], pair[0]))
        pages = []
        image = Image.new("RGBA", (1024, 1024))
        x = y = row_height = 0
        page_index = 0
        def save_page():
            path = atlas_folder / f"icons_{page_index:02d}.png"
            image.save(path, optimize=True)
            pages.append({"file": path.relative_to(self.output).as_posix(), "sha256": digest(path),
                          "size": [1024, 1024], "padding": 2})
        for _name, asset in candidates:
            width, height = asset["size"]
            if x + width + 4 > 1024:
                x, y = 0, y + row_height
                row_height = 0
            if y + height + 4 > 1024:
                save_page()
                page_index += 1
                image = Image.new("RGBA", (1024, 1024))
                x = y = row_height = 0
            sprite = Image.open(self.output / asset["file"]).convert("RGBA")
            image.paste(sprite, (x + 2, y + 2))
            image.paste(sprite.crop((0, 0, 1, height)).resize((2, height)), (x, y + 2))
            image.paste(sprite.crop((width - 1, 0, width, height)).resize((2, height)), (x + width + 2, y + 2))
            image.paste(sprite.crop((0, 0, width, 1)).resize((width, 2)), (x + 2, y))
            image.paste(sprite.crop((0, height - 1, width, height)).resize((width, 2)), (x + 2, y + height + 2))
            for corner_x, corner_y, target_x, target_y in (
                (0, 0, x, y), (width - 1, 0, x + width + 2, y),
                (0, height - 1, x, y + height + 2),
                (width - 1, height - 1, x + width + 2, y + height + 2),
            ):
                corner = sprite.crop((corner_x, corner_y, corner_x + 1, corner_y + 1)).resize((2, 2))
                image.paste(corner, (target_x, target_y))
            asset["atlas"] = {"file": f"atlases/icons_{page_index:02d}.png", "rect": [x + 2, y + 2, width, height]}
            x += width + 4
            row_height = max(row_height, height + 4)
        if candidates:
            save_page()
        return pages

    def split_part(self, source, item, parent_mask, parent_id=None):
        if item.get("kind") == "reference_board":
            return {"id": item["id"], "kind": "screen_instance", "screen": item["screen"],
                    "rect": item["rect"], "children": []}
        mask = Image.fromarray(np.minimum(np.asarray(visual_mask(source, item)), np.asarray(parent_mask)))
        bounds = mask.getbbox()
        if not bounds:
            return None
        x, y, right, bottom = bounds
        children = list(item.get("children", []))
        child_masks = Image.new("L", source.size)
        for child in children:
            child_mask = Image.fromarray(np.minimum(np.asarray(visual_mask(source, child)), np.asarray(mask)))
            child_masks = Image.fromarray(np.maximum(np.asarray(child_masks), np.asarray(child_mask)))
        if item.get("glyph"):
            # 사진·차량에는 자동 글리프 추출을 적용하지 않습니다.
            inset = Image.new("L", source.size)
            inset.paste(mask.crop(bounds).filter(ImageFilter.MinFilter(9)), bounds[:2])
            icon_mask = glyph_mask(source, inset)
            if icon_mask.getbbox():
                children.append({"id": item["id"] + "_icon", "rect": list(icon_mask.getbbox()),
                                 "kind": "glyph", "_mask": icon_mask})
                child_masks = Image.fromarray(np.maximum(np.asarray(child_masks), np.asarray(icon_mask)))
        base = fill_plate(source, mask, child_masks) if child_masks.getbbox() else source.copy()
        part = base.crop(bounds)
        part.putalpha(mask.crop(bounds))
        result = {
            "id": item["id"], "asset": self.save_asset(part, item.get("kind", "panel")),
            "rect": [x, y, right - x, bottom - y], "kind": item.get("kind", "panel"),
            "children": [], "anchor": item.get("anchor", "design"),
        }
        for field in ("action", "label", "label_rect", "value", "radius", "shape", "nine_slice", "placeholder"):
            if field in item:
                result[field] = item[field]
        if item.get("kind") in ("button", "panel", "modal", "card") and not item.get("polygon"):
            if item.get("shape") != "ellipse":
                margin = min(item.get("radius", 24) + 3, part.width // 3, part.height // 3)
                result.setdefault("nine_slice", [margin, margin, margin, margin])
        if parent_id:
            result["parent"] = parent_id
        for child in children:
            if child.get("_mask") is not None:
                icon_bounds = child["_mask"].getbbox()
                icon = source.crop(icon_bounds)
                icon.putalpha(child["_mask"].crop(icon_bounds))
                left, top, end_x, end_y = icon_bounds
                result["children"].append({
                    "id": child["id"], "asset": self.save_asset(icon, "glyph"),
                    "rect": [left, top, end_x - left, end_y - top], "kind": "glyph", "children": [],
                    "parent": item["id"],
                })
            else:
                exported = self.split_part(source, child, mask, item["id"])
                if exported:
                    result["children"].append(exported)
        return result

    def screen(self, spec):
        source = Image.open(REFERENCES / spec["reference"]).convert("RGBA")
        if spec.get("source_crop"):
            left, top, width, height = spec["source_crop"]
            source = source.crop((left, top, left + width, top + height))
        cover = Image.new("L", source.size)
        for item in spec["parts"]:
            cover = Image.fromarray(np.maximum(np.asarray(cover), np.asarray(visual_mask(source, item))))
        clean = Image.open(KIT / "inputs" / spec["background"]).convert("RGBA")
        if clean.size != source.size:
            clean = clean.resize(source.size, Image.Resampling.LANCZOS)
        background = source.copy()
        background.paste(clean, (0, 0), cover)
        relative = f"../preview/backdrops/{spec['id']}.png"
        path = self.output / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        background.save(path, optimize=True)
        production_plate = self.output / "backgrounds" / spec["background"]
        if not production_plate.exists():
            production_plate.write_bytes((KIT / "inputs" / spec["background"]).read_bytes())
        full_mask = Image.new("L", source.size, 255)
        layers = [self.split_part(source, item, full_mask) for item in spec["parts"]]
        return {
            "id": spec["id"], "title": spec["title"], "reference": spec["reference"],
            "reference_sha256": digest(REFERENCES / spec["reference"]),
            "source_crop": spec.get("source_crop"), "size": list(source.size),
            "background": {"file": relative, "sha256": digest(path), "role": spec.get("background_role", "menu"),
                           "clean_plate": "backgrounds/" + spec["background"]},
            "layers": [layer for layer in layers if layer], "group": spec.get("group", "menu"),
            "reference_only": spec.get("reference_only", False),
            "text_slots": spec.get("text_slots", []),
        }


def compose(screen, manifest, output):
    image = Image.open(output / screen["background"]["file"]).convert("RGBA")
    def draw(layer):
        if layer["kind"] == "screen_instance":
            child = next(item for item in manifest["screens"] if item["id"] == layer["screen"])
            image.alpha_composite(compose(child, manifest, output), tuple(layer["rect"][:2]))
            return
        asset = manifest["assets"][layer["asset"]]
        part = Image.open(output / asset["file"]).convert("RGBA")
        image.alpha_composite(part, tuple(layer["rect"][:2]))
        for child in layer["children"]:
            draw(child)
    for layer in screen["layers"]:
        draw(layer)
    return image


def godot_resources(manifest, output):
    """이미지의 원래 알파·모서리를 유지하는 Godot 4 리소스 템플릿을 만듭니다."""
    folder = output / "godot"
    folder.mkdir(exist_ok=True)
    prefix = "res://assets/ui/rev3/"
    previous_hashes = manifest.get("godot", {}).get("hashes", {})
    margins = {}
    def inspect(layer):
        if layer.get("nine_slice") and layer.get("asset"):
            margins.setdefault(layer["asset"], layer["nine_slice"])
        for child in layer["children"]:
            inspect(child)
    for screen in manifest["screens"]:
        for layer in screen["layers"]:
            inspect(layer)
    resources = []
    for name, asset in manifest["assets"].items():
        asset.pop("godot_resource", None)
        if asset.get("atlas"):
            atlas = asset["atlas"]
            rect = ", ".join(map(str, atlas["rect"]))
            content = (
                '[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n'
                f'[ext_resource type="Texture2D" path="{prefix + atlas["file"]}" id="1"]\n\n'
                '[resource]\natlas = ExtResource("1")\n'
                f'region = Rect2({rect})\nfilter_clip = true\n'
            )
        elif name in margins:
            left, top, right, bottom = margins[name]
            content = (
                '[gd_resource type="StyleBoxTexture" load_steps=2 format=3]\n\n'
                f'[ext_resource type="Texture2D" path="{prefix + asset["file"]}" id="1"]\n\n'
                '[resource]\ntexture = ExtResource("1")\n'
                f'texture_margin_left = {left}.0\ntexture_margin_top = {top}.0\n'
                f'texture_margin_right = {right}.0\ntexture_margin_bottom = {bottom}.0\n'
            )
        else:
            continue
        path = folder / (name + ".tres")
        write_text(path, content)
        resources.append(path.relative_to(output).as_posix())
        asset["godot_resource"] = path.relative_to(output).as_posix()
    for relative, old_hash in previous_hashes.items():
        path = output / relative
        if relative not in resources and path.exists() and digest(path) == old_hash:
            path.unlink()
    manifest["godot"] = {"resource_prefix": prefix, "resources": resources,
                         "hashes": {relative: digest(output / relative) for relative in resources},
                         "runtime_installed": False, "engine_render_verified": False}
    return resources


def bake(output, selected=None):
    output = output.resolve()
    if output == ROOT or output.is_relative_to(REFERENCES) or output.is_relative_to(KIT / "inputs"):
        raise SystemExit("원화·복원 원본 폴더를 출력 위치로 사용할 수 없습니다.")
    definitions = json.loads((KIT / "layouts.json").read_text(encoding="utf-8"))
    known = {screen["id"] for screen in definitions["screens"]}
    if selected and not selected <= known:
        raise SystemExit(f"알 수 없는 화면: {sorted(selected - known)}")
    sources = json.loads((REFERENCES / "source.json").read_text(encoding="utf-8"))
    for source in sources["images"]:
        if digest(REFERENCES / source["file"]) != source["sha256"]:
            raise SystemExit(f"원화 변경: 먼저 원본 출처를 확인하세요: {source['file']}")
    inputs = json.loads((KIT / "inputs/source.json").read_text(encoding="utf-8"))
    for source in inputs["images"]:
        if digest(KIT / "inputs" / source["file"]) != source["sha256"]:
            raise SystemExit(f"복원 원본 변경: 먼저 출처를 확인하세요: {source['file']}")
    exporter = Exporter(output)
    old_path = output / "manifest.json"
    previous = json.loads(old_path.read_text(encoding="utf-8")) if old_path.exists() else {"assets": {}, "screens": []}
    old_screens = {screen["id"]: screen for screen in previous["screens"]}
    if selected:
        exporter.assets.update(previous["assets"])
    screens = []
    for spec in definitions["screens"]:
        if selected and spec["id"] not in selected and spec["id"] in old_screens:
            screen = old_screens[spec["id"]]
            screen["text_slots"] = spec.get("text_slots", [])
        else:
            screen = exporter.screen(spec)
        screens.append(screen)
    manifest = {
        "schema": 1, "revision": 3, "text_baked": False,
        "coordinate_contract": "all_rects_are_global_source_pixels; uniform_contain_in_safe_area",
        "source_layout_sha256": digest(KIT / "layouts.json"), "assets": exporter.assets,
        "screens": screens,
    }
    used = set()
    def collect(layer):
        if layer.get("asset"):
            used.add(layer["asset"])
        for child in layer["children"]:
            collect(child)
    for screen in screens:
        for layer in screen["layers"]:
            collect(layer)
    exporter.assets = {name: asset for name, asset in exporter.assets.items() if name in used}
    manifest["assets"] = exporter.assets
    manifest["atlases"] = exporter.pack_glyphs()
    godot_resources(manifest, output)
    font = output / "fonts/noto_sans_kr.ttf"
    if font.exists():
        manifest["fonts"] = [{"file": "fonts/noto_sans_kr.ttf", "license": "fonts/OFL.txt",
                              "source": "https://github.com/google/fonts/tree/main/ofl/notosanskr",
                              "sha256": digest(font)}]
    manifest["scope"] = {
        "runtime_installed": False,
        "reference_backgrounds": "preview/backdrops는 원화 좌표 비교용입니다. 게임 배경은 clean_plate로 구분합니다.",
        "world_previews": "주행·결과 배경과 차량 그림은 비교용이며 실제 3D 월드를 대신하지 않습니다.",
    }
    checks = []
    for screen in manifest["screens"]:
        reference = Image.open(REFERENCES / screen["reference"]).convert("RGBA")
        if screen["source_crop"]:
            x, y, width, height = screen["source_crop"]
            reference = reference.crop((x, y, x + width, y + height))
        rebuilt = compose(screen, manifest, output)
        delta = np.abs(np.asarray(rebuilt).astype(np.int16) - np.asarray(reference).astype(np.int16))
        checks.append({"screen": screen["id"], "max_channel_delta": int(delta.max()),
                       "changed_pixels": int((delta[:, :, :3].max(axis=2) > 0).sum())})
    manifest["reconstruction"] = checks
    write_text(output / "manifest.json", json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    write_text(output.parent / "manifest.js", "window.REV3_UI_KIT = " + json.dumps(manifest, ensure_ascii=False) + ";\n")
    current_files = {asset["file"] for asset in exporter.assets.values()}
    for asset in previous["assets"].values():
        path = output / asset["file"]
        if asset["file"] not in current_files and path.exists() and digest(path) == asset["sha256"]:
            path.unlink()
    current_atlases = {atlas["file"] for atlas in manifest["atlases"]}
    for atlas in previous.get("atlases", []):
        path = output / atlas["file"]
        if atlas["file"] not in current_atlases and path.exists() and digest(path) == atlas["sha256"]:
            path.unlink()
    print(f"분리: {len(manifest['screens'])}개 화면, {len(exporter.assets)}개 중복 제거 PNG")
    failures = [check for check in checks if check["max_channel_delta"]]
    if failures:
        raise SystemExit(f"재조립 불일치: {failures}")
    print("원화 픽셀 재조립: 모든 화면 PASS")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=KIT / "portable")
    parser.add_argument("--screens", help="편집한 화면만 다시 분리합니다. 쉼표로 구분하고 이후 전체 검증을 실행합니다.")
    arguments = parser.parse_args()
    bake(arguments.output, set(arguments.screens.split(",")) if arguments.screens else None)
