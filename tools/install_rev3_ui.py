"""rev3 제작 자료에서 게임이 사용하는 UI 부품·좌표만 설치합니다. 원화는 변경하지 않습니다."""
from pathlib import Path
import hashlib
import json
import shutil

import numpy as np
from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / "art_sources/ui/kit/rev3/portable"
OUTPUT = ROOT / "assets/ui/rev3"
PREFIX = "res://assets/ui/rev3/"

# 좌표는 전 화면을 보존하되, 실제 그리는 그림만 패키징한다. 네이티브 패널·예시 차량은 제외한다.
HEADER = {"header", "back_icon", "settings_icon", "header_icon"}
PARTS = {
    "start_passport": {"brand_header", "settings_icon", "passport_icon", "track_icon"},
    "track_select": HEADER | {"selected_course", "previous_icon", "next_icon", "weather_icon", "time_icon", "continue_icon"}
                    | {f"course_photo_{i}" for i in range(3)},
    "track_select_more": HEADER | {"previous_icon", "next_icon", "weather_icon", "time_icon", "continue_icon"}
                         | {f"course_photo_{i}" for i in range(3)},
    "track_conditions": {"weather_icon", "time_icon"},
    "car_select": HEADER | {"previous_vehicle_icon", "next_vehicle_icon", "tuning_icon", "start_race_icon"}
                  | {f"performance_{i}_icon" for i in range(4)},
    "settings": HEADER | {"sound_icon", "music_icon", "graphics_icon", "motion_icon", "fps_icon",
                           "auto_acceleration_icon", "controls_icon", "done_icon"}
                | {f"graphics_{i}_icon" for i in range(3)},
    "controls_settings": HEADER | {"controls_icon", "steering_left_icon", "steering_right_icon", "reset_icon", "done_icon"}
                         | {f"size_{i}_icon" for i in range(3)},
    "tour_passport": HEADER | {"passport_icon"} | {f"goal_photo_{i}" for i in range(5)}
                     | {f"route_{i}" for i in range(16)} | {f"reward_{i}" for i in range(5)},
    "tuning_shop": {"header", "wrench"} | {f"tab_{id}_icon" for id in ("paint", "livery", "wheels", "wing", "shading")},
    "tuning_wheels": {f"wheel_thumb_{i}" for i in range(3)},
    "tuning_rear_wing": {f"wing_{i}_icon" for i in range(4)},
    "tuning_shading": {f"material_{i}" for i in range(2)},
    "tuning_effects": {f"effect_{i}_icon" for i in range(3)},
    "race_hud": {"pause_icon", "drift_icon", "nitro_icon", "brake_icon", "nitro_gauge"},
    "pause": {"pause_title_icon", "resume_icon", "settings_icon", "retry_icon", "home_icon"},
    "loading_long": {"brand_header"},
    "start_countdown": {"start_signal", "countdown_value"},
    "rolling_start": {"start_signal", "rolling_status"},
}
for screen in ("race_results", "result_time_over", "result_tour", "result_new_record"):
    PARTS[screen] = {"result_header", "retry_icon", "continue_icon"}


def install():
    source = json.loads((KIT / "manifest.json").read_text(encoding="utf-8"))
    assets = {}
    copied = set()

    def copy(relative):
        destination = OUTPUT / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        if not destination.exists() or destination.read_bytes() != (KIT / relative).read_bytes():
            shutil.copyfile(KIT / relative, destination)
        copied.add(relative)
        return PREFIX + relative

    def layer(item, reference):
        if item["kind"] in ("vehicle_placeholder", "screen_instance"):
            return None
        result = {key: value for key, value in item.items() if key not in ("parent", "children", "placeholder")}
        if item["id"] in PARTS.get(screen_id, set()):
            asset_id = item["asset"]
            if asset_id not in assets:
                original = source["assets"][asset_id]
                atlas = original.get("atlas")
                assets[asset_id] = {
                    "path": copy(atlas["file"] if atlas else original["file"]),
                    "region": atlas["rect"] if atlas else [0, 0, *original["size"]],
                    "size": original["size"],
                }
            if item["kind"] == "glyph_region" or item["id"] in ("drift_icon", "brake_icon", "nitro_icon", "joystick_icon"):
                # 분리된 부모·자식 글리프를 한 번 더 지우지 않고 원화에서 흰 그림 전체를 추출한다.
                x, y, width, height = item["rect"]
                image = reference.crop((x, y, x + width, y + height)).convert("RGBA")
                rgb = np.asarray(image)[:, :, :3].astype(np.int16)
                white = (rgb.min(axis=2) > 176) & (rgb.max(axis=2) - rgb.min(axis=2) < 80)
                if item["id"] in ("drift_icon", "brake_icon", "nitro_icon", "joystick_icon"):
                    parent = current_index.get(item.get("parent", ""))
                    if parent:
                        px, py, pw, ph = parent["rect"]
                        yy, xx = np.mgrid[:height, :width]
                        white &= ((xx + x - px - pw / 2) / (pw * .39)) ** 2 + (
                            (yy + y - py - ph / 2) / (ph * .39)) ** 2 < 1
                mask = Image.fromarray((white * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))
                image.putalpha(mask)
                relative = "sprites/glyph_" + hashlib.sha256(image.tobytes()).hexdigest()[:24] + ".png"
                (OUTPUT / relative).parent.mkdir(parents=True, exist_ok=True)
                image.save(OUTPUT / relative, optimize=True)
                copied.add(relative)
                assets[asset_id] = {"path": PREFIX + relative, "region": [0, 0, width, height], "size": [width, height]}
        else:
            result.pop("asset", None)
            result["render"] = "native"
        result["children"] = [child for entry in item["children"] if (child := layer(entry, reference))]
        return result

    screens = {}
    for entry in source["screens"]:
        if entry["reference_only"]:
            continue
        screen_id = entry["id"]
        current_index = {}
        def index_layer(item):
            current_index[item["id"]] = item
            for child in item["children"]:
                index_layer(child)
        for item in entry["layers"]:
            index_layer(item)
        reference = Image.open(ROOT / "art_sources/ui/reference/rev3" / entry["reference"]).convert("RGBA")
        if entry.get("source_crop"):
            x, y, width, height = entry["source_crop"]
            reference = reference.crop((x, y, x + width, y + height))
        layers = [child for item in entry["layers"] if (child := layer(item, reference))]
        background = ""
        if entry["background"]["role"] == "menu":
            background = copy(entry["background"]["clean_plate"])
        screens[entry["id"]] = {"size": entry["size"], "layers": layers, "background": background}
    result = {
        "schema": 1, "design_size": [1280, 720], "assets": assets, "screens": screens,
        "font": PREFIX + "fonts/interface_font.tres",
        "source_layout_sha256": source["source_layout_sha256"],
    }
    copy("fonts/noto_sans_kr.ttf")
    copy("fonts/OFL.txt")
    font = (
        '[gd_resource type="FontVariation" load_steps=2 format=3]\n\n'
        '[ext_resource type="FontFile" path="res://assets/ui/rev3/fonts/noto_sans_kr.ttf" id="1"]\n\n'
        '[resource]\nbase_font = ExtResource("1")\nvariation_opentype = {\n2003265652: 650.0\n}\n'
    )
    (OUTPUT / "fonts/interface_font.tres").write_text(font, encoding="utf-8", newline="\n")
    retained = {entry["path"].removeprefix(PREFIX) for entry in assets.values()}
    retained.update(entry["background"].removeprefix(PREFIX) for entry in screens.values() if entry["background"])
    for folder in ["sprites", "atlases", "backgrounds"]:
        for path in (OUTPUT / folder).glob("*.png"):
            if path.relative_to(OUTPUT).as_posix() not in retained:
                path.unlink()
                path.with_suffix(path.suffix + ".import").unlink(missing_ok=True)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / "catalog.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n",
                                         encoding="utf-8", newline="\n")
    credit = (
        "# rev3 UI 출처\n\n"
        "디자인·분리 원본은 [UI 이미지 가이드](../../../art_sources/ui/README.md), "
        "[에셋 제작 계약](../../../art_sources/ui/kit/rev3/README.md)을 따릅니다.\n\n"
        "OpenAI image_gen으로 제작한 원화에서 UI 부품을 분리했습니다. "
        "주행·결과의 월드 스냅샷과 원화 비교용 배경은 설치하지 않습니다. "
        "좌표·아틀라스·PNG는 tools/install_rev3_ui.py로 생성합니다.\n\n"
        "Noto Sans KR는 Google Fonts 배포본이며 [OFL 라이선스](fonts/OFL.txt)를 함께 제공합니다.\n"
    )
    (OUTPUT / "SOURCE.md").write_text(credit, encoding="utf-8", newline="\n")
    print(f"rev3 런타임 UI: {len(screens)}화면, {len(assets)}부품, {len(retained) + 3}파일. 비교용 배경 제외.")


if __name__ == "__main__":
    install()
