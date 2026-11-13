"""생성형 원화의 프레임을 재단하고 실제 메뉴 좌표로 글자 없는 화면 정본을 만든다."""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art_sources/ui/coastal"
OUTPUT = ROOT / "assets/ui/pre_race"
SIZE = (1280, 720)
CROPS = {
    "button": ((43, 24, 312, 115), (256, 96), 17),
    "panel": ((40, 165, 460, 585), (192, 192), 40),
    "primary": ((1010, 786, 1632, 902), (512, 96), 25),
    "header": ((462, 16, 1385, 124), (768, 96), 25),
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def nine_slice(image, size, margin=20):
    from PIL import Image
    out = Image.new("RGBA", size)
    width, height = image.size
    dx, dy = [0, margin, size[0] - margin, size[0]], [0, margin, size[1] - margin, size[1]]
    sx, sy = [0, margin, width - margin, width], [0, margin, height - margin, height]
    for row in range(3):
        for column in range(3):
            part = image.crop((sx[column], sy[row], sx[column + 1], sy[row + 1]))
            part = part.resize((dx[column + 1] - dx[column], dy[row + 1] - dy[row]), Image.Resampling.BICUBIC)
            out.alpha_composite(part, (dx[column], dy[row]))
    return out


def source_rects():
    # 입력·표시의 정본인 GDScript 상수를 읽는다. 같은 좌표를 별도 수기로 복사하지 않는다.
    text = (ROOT / "scripts/ui/hud.gd").read_text()
    layout = (ROOT / "scripts/ui/menu_layout.gd").read_text()
    result = {}
    for name, values in re.findall(r"const (\w+) := Rect2\(([^\n]+)\)", text + "\n" + layout):
        try:
            numbers = [int(value.strip()) for value in values.split(",")]
        except ValueError:
            continue
        if len(numbers) == 4:
            result[name] = numbers
    result["GARAGE_BACK"] = result["BACK"]
    return result


def plans(rects):
    def item(name, role="panel"):
        return {"id": name, "rect": rects[name], "role": role}
    back = item("GARAGE_BACK", "button")
    title = {"id": "title", "rect": [310, 16, 615, 80], "role": "header"}
    return {
        "start": [
            {"id": "brand", "rect": [680, 64, 540, 170], "role": "panel"},
            {"id": "loading", "rect": [180, 548, 920, 154], "role": "panel"},
        ],
        "home": [title, item("HOME_PASSPORT", "button"), item("HOME_SETTINGS", "button"),
                 item("HOME_TOUR"), item("HOME_TRACK")],
        "courses": [back, title] + [item("COURSE_" + name) for name in ["FUJI", "SPEEDWAY", "NIGHT", "RIVIERA", "GORGE"]]
                   + [item("COURSE_WEATHER", "button"), item("COURSE_PERIOD", "button"),
                      {"id": "summary", "rect": [24, 594, 284, 102], "role": "button"}],
        "garage": [back, title, item("GARAGE_GHOST", "button"),
                   {"id": "vehicle_name", "rect": [60, 122, 720, 88], "role": "header"},
                   {"id": "performance", "rect": [800, 122, 400, 346], "role": "panel"}]
                  + [{"id": f"car_{index}", "rect": [144 + index * 252, 480, 236, 106], "role": "panel"}
                     for index in range(4)]
                  + [item("GARAGE_PREVIOUS", "button"), item("GARAGE_NEXT", "button")]
                  + [item("GARAGE_" + name, "primary" if name == "START" else "button")
                     for name in ["PAINT", "PLATE", "TUNING", "START"]],
        # 푸터는 Android·Web의 버튼 수가 다르므로 실제 9slice 부품으로 그린다.
        "settings": [item("SETTINGS_PANEL")] + [item("SETTINGS_" + name)
                    for name in ["SOUND", "MUSIC", "MOTION", "FPS", "GRAPHICS", "AUTO"]]
                    + [{"id": "controls", "rect": [650, 460, 402, 80], "role": "button"}],
    }


def bake():
    from PIL import Image, ImageDraw, ImageOps
    OUTPUT.mkdir(parents=True, exist_ok=True)
    master = Image.open(SOURCE / "master.png").convert("RGBA")
    parts = {}
    for name, (bounds, target, corner) in CROPS.items():
        part = master.crop(bounds)
        width, height = part.size
        alpha = Image.new("L", part.size)
        ImageDraw.Draw(alpha).polygon(
            [(corner, 0), (width - corner, 0), (width - 1, corner), (width - 1, height - corner),
             (width - corner, height - 1), (corner, height - 1), (0, height - corner), (0, corner)], fill=255)
        part.putalpha(alpha)
        part = part.resize(target, Image.Resampling.LANCZOS)
        part.save(OUTPUT / (name + ".png"), optimize=True)
        parts[name] = part
    backdrop = Image.open(SOURCE / "backdrop.png").convert("RGBA").resize(SIZE, Image.Resampling.LANCZOS)
    screens = plans(source_rects())
    for name, frames in screens.items():
        image = ImageOps.mirror(backdrop) if name == "garage" else backdrop.copy()
        # 헤더·설정은 밝은 원화의 프레임을 실제 문구 아래에 둔다.
        if name in ["home", "courses", "garage"]:
            strip = Image.new("RGBA", (1280, 110), (255, 250, 237, 238))
            image.alpha_composite(strip)
        for entry in frames:
            x, y, width, height = entry["rect"]
            # 버전 배지는32px 높이. 작은 원화 조각은 종횡 보존 가장자리를 사용한다.
            frame = nine_slice(parts[entry["role"]], (width, height), min(20, width // 3, height // 3))
            image.alpha_composite(frame, (x, y))
        image.convert("RGB").save(OUTPUT / (name + ".png"), optimize=True)
    manifest = {"schema": 1, "designSize": list(SIZE), "nineSliceMargin": 20,
                "sources": {name: digest(SOURCE / name) for name in ["master.png", "backdrop.png"]},
                "crops": {name: {"bounds": list(bounds), "size": list(target), "cornerMask": corner}
                          for name, (bounds, target, corner) in CROPS.items()}, "screens": screens,
                "outputs": {path.name: digest(path) for path in sorted(OUTPUT.glob("*.png"))}}
    (SOURCE / "layout.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("생성형 시작 전 원화와 실제 좌표 베이크:", len(screens), "화면")


if __name__ == "__main__":
    bake()
