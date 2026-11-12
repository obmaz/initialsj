#!/usr/bin/env python3
"""Draw the Android launcher icons from the same geometry as assets/ui/branding/coast_rush_icon.svg.

Writes assets/android/icon-192.png (legacy rounded icon) and the adaptive pair
icon-foreground-432.png / icon-background-432.png (artwork inside the safe central area).
Needs Pillow only. Run: python3 tools/bake_android_icons.py
"""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "assets/android"
BG = (7, 17, 30, 255)
CYAN = (57, 220, 255, 255)
ORANGE = (255, 128, 82, 255)
LINE = (217, 248, 255, 255)
LEFT = [(19, 36), (48, 36), (75, 64), (48, 92), (19, 92), (46, 64)]
RIGHT = [(65, 36), (85, 36), (112, 64), (85, 92), (65, 92), (92, 64)]

def artwork(size, offset=(0, 0), scale=1.0, background=False, rounded=False):
    """The icon at size x size; art coordinates are the 128 unit SVG box."""
    ss = 4
    image = Image.new("RGBA", (size*ss, size*ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(image)
    unit = size*ss/128*scale
    ox, oy = offset[0]*ss, offset[1]*ss
    def pt(p): return (ox+p[0]*unit, oy+p[1]*unit)
    if background:
        if rounded: d.rounded_rectangle([0, 0, size*ss-1, size*ss-1], radius=26*size*ss/128, fill=BG)
        else: d.rectangle([0, 0, size*ss, size*ss], fill=BG)
    d.polygon([pt(p) for p in LEFT], fill=CYAN)
    d.polygon([pt(p) for p in RIGHT], fill=ORANGE)
    a, b = pt((24, 107)), pt((92, 107))
    r = 2.5*unit
    d.line([a, b], fill=LINE, width=int(5*unit))
    for c in (a, b): d.ellipse([c[0]-r, c[1]-r, c[0]+r, c[1]+r], fill=LINE)
    return image.resize((size, size), Image.LANCZOS)

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    artwork(192, background=True, rounded=True).save(OUT/"icon-192.png", optimize=True)
    # Adaptive icons are masked to a circle or squircle: keep the art in the inner 66%.
    inner = 432*0.66
    scale = inner/432
    offset = ((432-inner)/2, (432-inner)/2)
    artwork(432, offset=offset, scale=scale).save(OUT/"icon-foreground-432.png", optimize=True)
    Image.new("RGBA", (432, 432), BG).save(OUT/"icon-background-432.png", optimize=True)
    print("wrote", sorted(p.name for p in OUT.glob("*.png")))

if __name__ == "__main__":
    main()
