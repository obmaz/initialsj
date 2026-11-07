#!/usr/bin/env python3
"""Procedural INITIAL SJ / COAST RUSH logo (no photographs, no third-party marks).

Writes assets/ui/initialsj-logo.png for the in-game screens and refreshes the inline
web copy in web/coast-rush-shell.html. Lettering is Roboto Black Italic (Apache-2.0,
already bundled); everything else is drawn here, so the result is reproducible.
Run: python3 tools/bake_logo.py [--preview PATH]
"""
import base64, io, re, sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONT = ROOT / "assets/fonts/Roboto-BlackItalic.ttf"
OUT = ROOT / "assets/ui/initialsj-logo.png"
SHELL = ROOT / "web/coast-rush-shell.html"
W, H = 1500, 540
NAVY = (6, 20, 44)
CYAN = (38, 222, 255)

def font(size):
    return ImageFont.truetype(str(FONT), size)

def text_mask(text, size, tracking=0):
    f = font(size)
    widths = [f.getlength(c) for c in text]
    width = int(sum(widths) + tracking * (len(text) - 1)) + 80
    mask = Image.new("L", (width, int(size * 1.5)), 0)
    d = ImageDraw.Draw(mask)
    x = 40.0
    for c, w in zip(text, widths):
        d.text((x, 20), c, font=f, fill=255)
        x += w + tracking
    box = mask.getbbox()
    return mask.crop(box)

def gradient(size, stops):
    w, h = size
    ys = np.linspace(0, 1, h)
    xs = [s[0] for s in stops]
    cols = np.array([s[1] for s in stops], dtype=float)
    out = np.stack([np.interp(ys, xs, cols[:, i]) for i in range(3)], axis=1)
    return Image.fromarray(np.repeat(out[:, None, :], w, axis=1).astype(np.uint8), "RGB")

def dilate(mask, radius):
    return mask.filter(ImageFilter.MaxFilter(radius * 2 + 1))

def place(canvas, layer, xy):
    canvas.alpha_composite(layer, xy)

def solid(mask, color):
    layer = Image.new("RGBA", mask.size, color + (255,))
    layer.putalpha(mask)
    return layer

def lettering(mask, stops, outline=12, depth=14, pad=60):
    """Chrome-filled letters with a navy outline and a stepped extrusion."""
    w, h = mask.size
    out = Image.new("RGBA", (w + pad * 2 + depth, h + pad * 2 + depth), (0, 0, 0, 0))
    big = Image.new("L", out.size, 0)
    big.paste(mask, (pad, pad))
    edge = dilate(big, outline)
    for step in range(depth, 0, -1):
        shade = int(10 + 40 * (1 - step / depth))
        shifted = Image.new("L", out.size, 0)
        shifted.paste(edge, (step, step))
        out.alpha_composite(solid(shifted, (shade // 2, shade, shade * 2)))
    out.alpha_composite(solid(edge, NAVY))
    fill = gradient(out.size, stops).convert("RGBA")
    fill.putalpha(big)
    out.alpha_composite(fill)
    # thin highlight along the top edge of each letter
    shifted = Image.new("L", out.size, 0)
    shifted.paste(big, (0, 5))
    top = Image.fromarray(np.clip(np.asarray(big, dtype=int) - np.asarray(shifted, dtype=int), 0, 255).astype(np.uint8))
    hi = Image.new("RGBA", out.size, (255, 255, 255, 0))
    hi.putalpha(top.point(lambda v: int(v * 0.8)))
    out.alpha_composite(hi)
    return out

def build():
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    initial = lettering(text_mask("INITIAL", 190, tracking=6), [(0, (255, 255, 255)), (0.46, (214, 232, 246)), (0.5, (96, 128, 158)), (0.58, (178, 208, 230)), (1, (236, 247, 255))])
    sj = lettering(text_mask("SJ", 330, tracking=4), [(0, (255, 246, 170)), (0.44, (255, 196, 0)), (0.5, (255, 120, 0)), (0.62, (255, 82, 40)), (1, (230, 34, 52))], outline=14, depth=18)
    base = 330
    ix, iy = 40, base - initial.size[1] + 30
    sx = ix + initial.size[0] - 78
    sy = 40
    # speed streaks behind the lettering
    streaks = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(streaks)
    for i, (y, length, alpha) in enumerate([(120, 330, 200), (168, 440, 150), (216, 260, 190), (262, 380, 120), (306, 300, 170)]):
        x0 = 0
        d.polygon([(x0, y), (x0 + length, y - 3), (x0 + length + 40, y + 5), (x0 + 12, y + 9)], fill=CYAN + (alpha,))
    streaks = streaks.filter(ImageFilter.GaussianBlur(1.2))
    place(canvas, streaks, (0, 0))
    glow_src = Image.new("L", (W, H), 0)
    glow_src.paste(initial.getchannel("A"), (ix, iy))
    glow_src.paste(sj.getchannel("A"), (sx, sy), sj.getchannel("A"))
    glow = solid(glow_src.filter(ImageFilter.GaussianBlur(18)).point(lambda v: int(v * 0.55)), CYAN)
    glow_canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    glow_canvas.alpha_composite(glow)
    glow_canvas.alpha_composite(canvas)
    canvas = glow_canvas
    place(canvas, initial, (ix, iy))
    place(canvas, sj, (sx, sy))
    # COAST RUSH plate under INITIAL
    plate_y = iy + initial.size[1] - 40
    plate = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(plate)
    x0, x1, y0, y1 = ix + 60, sx + 6, plate_y, plate_y + 84
    skew = 26
    pts = [(x0 + skew, y0), (x1, y0), (x1 - skew, y1), (x0, y1)]
    d.polygon(pts, fill=NAVY + (240,), outline=CYAN + (255,), width=4)
    # checkered end cap
    for r in range(3):
        for c in range(4):
            if (r + c) % 2 == 0:
                cx = x1 - 128 + c * 22 - r * 8
                cy = y0 + 14 + r * 20
                d.polygon([(cx + 8, cy), (cx + 30, cy), (cx + 22, cy + 20), (cx, cy + 20)], fill=(246, 247, 250, 255))
    place(canvas, plate, (0, 0))
    label = text_mask("C O A S T   R U S H", 44, tracking=1)
    layer = solid(label.point(lambda v: v), CYAN)
    place(canvas, layer, (x0 + 70, y0 + (84 - label.size[1]) // 2 + 1))
    box = canvas.getbbox()
    return canvas.crop((max(0, box[0] - 24), max(0, box[1] - 24), min(W, box[2] + 24), min(H, box[3] + 24)))

def web_copy(logo):
    small = logo.resize((720, round(720 * logo.size[1] / logo.size[0])), Image.LANCZOS)
    buf = io.BytesIO()
    small.save(buf, "WEBP", quality=88, method=6)
    return "data:image/webp;base64," + base64.b64encode(buf.getvalue()).decode()

def main():
    logo = build()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    logo.save(OUT, optimize=True)
    html = SHELL.read_text()
    uri = web_copy(logo)
    pattern = re.compile(r"(<!--logo:start-->).*?(<!--logo:end-->)", re.S)
    if pattern.search(html):
        html = pattern.sub(lambda m: m.group(1) + '<img class="loading-logo" alt="Initial SJ Coast Rush" src="%s">' % uri + m.group(2), html)
        SHELL.write_text(html)
    if "--preview" in sys.argv:
        path = Path(sys.argv[sys.argv.index("--preview") + 1])
        bg = Image.new("RGBA", logo.size, (8, 22, 42, 255))
        bg.alpha_composite(logo)
        bg.save(path)
    print("logo", logo.size, OUT.stat().st_size, "bytes")

if __name__ == "__main__":
    main()
