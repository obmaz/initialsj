#!/usr/bin/env python3
"""Bake the rear 240 degrees of the Fuji Lakeside sky from the front panorama.

The generated front panorama (assets/environment/fuji-lake-panorama.png) covers
the 120 degrees around Mount Fuji. This tool paints the remaining 240 degrees at
the same pixel scale (two 1774 x 887 panels), so no part of the horizon is
stretched:

- lake water and the shoreline band are the original pixels, mirror-tiled so
  every join matches exactly; Fuji's reflection is covered with other ripples;
- the sky is the original sky, mirror-tiled, with the sun removed (no second
  sun) and Fuji's silhouette replaced by the surrounding haze;
- two new ridge lines are drawn: a pale far range and a near forested range
  filled 1:1 with the original forest texture, never scaled;
- next to the front panorama the original hills are used and the new ridges are
  aligned to them, so both seams continue the picture.

The result is deterministic. Run: python3 tools/bake_fuji_backdrop.py
Outputs: assets/environment/fuji-lake-back-a.png (+60..180 degrees from Fuji)
         assets/environment/fuji-lake-back-b.png (-180..-60 degrees)
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ENV = ROOT / "assets" / "environment"
FRONT = ENV / "fuji-lake-panorama.png"
SHORE_TOP = 430      # first row of the town/tree band along the shore
WATER_TOP = 463      # first row of open water
SKY_LIMIT = 380      # new ridges always cover the sky below this row
SEAM = 230           # columns beside each seam that keep the original hills
SUN = (88, 167)      # sun centre (x, y) in the front panorama


def mirror_index(i, n):
    """Mirror-tile index into 0..n-1 (0,1,..,n-1,n-1,..,0,0,1,..): no scaling."""
    m = np.mod(i, 2 * n)
    return np.where(m < n, m, 2 * n - 1 - m)


def translated(source: np.ndarray, total: int, start: int, lo: int, hi: int, overlap: int = 160) -> np.ndarray:
    """Columns lo..hi of the source repeated by translation (never mirrored, never
    scaled). Each repeat's join is a crossfade over `overlap` neighbouring
    columns, so no seam shows and no symmetric pattern appears."""
    period = hi - lo - overlap
    p = np.mod(start + np.arange(total), period)
    weight = smooth(0, overlap, p)
    near = source[:, lo + p]
    far = source[:, lo + np.minimum(p + period, hi - lo - 1)]
    fade = np.where(p < overlap, weight, 1.0)[None, :, None]
    return near * fade + far * (1 - fade)


def smooth(edge0, edge1, x):
    t = np.clip((x - edge0) / (edge1 - edge0), 0, 1)
    return t * t * (3 - 2 * t)


def mirror_map(width: int, total: int) -> np.ndarray:
    """Source columns for the back panel, mirror-walking so every join matches.

    The panel starts beside the front's right edge (source column W-1) and ends
    beside its left edge (source column 0, approached in descending order).
    Walk: W-1 -> W/2, W/2 -> W-1, W-1 -> 0.
    """
    half = width // 2
    first = np.arange(width - 1, half - 1, -1)
    second = np.arange(half, width)
    third = np.arange(width - 1, -1, -1)
    columns = np.concatenate([first, second, third])
    assert len(columns) == total, (len(columns), total)
    return columns


def ridge_profile(rng: np.random.Generator, n: int, base: float, amplitude: float, scales) -> np.ndarray:
    """Smooth, natural ridge heights (rows) from summed random cosine octaves."""
    x = np.arange(n, dtype=np.float64)
    out = np.zeros(n)
    for period, weight in scales:
        phase = rng.uniform(0, 2 * np.pi)
        jitter = rng.uniform(0.85, 1.15)
        out += weight * np.cos(2 * np.pi * x / (period * jitter) + phase)
        # Sharper crests: add a rectified harmonic.
        out -= 0.35 * weight * np.abs(np.sin(np.pi * x / (period * jitter * 0.5) + phase))
    out = out / max(np.abs(out).max(), 1e-6)
    return base + amplitude * out


def clean_sky(front: np.ndarray) -> np.ndarray:
    """Front sky without the sun or Mount Fuji.

    Only rows above the new far ridge can show, and there the one thing that is
    not sky is Fuji: its region is replaced with sky from the open right side,
    feathered so no edge shows. Rows the ridges cover are not touched.
    """
    sky = front.copy()
    height, width, _ = sky.shape
    columns = np.arange(width)
    rows = np.arange(height)
    donor_columns = 1330 + mirror_index(columns - 500, 440)
    donor = front[:, donor_columns]
    horizontal = smooth(500, 560, columns) * (1 - smooth(1240, 1300, columns))
    vertical = smooth(270, 290, rows) * (1 - smooth(395, 405, rows))
    weight = (vertical[:, None] * horizontal[None, :])[..., None]
    sky = sky * (1 - weight) + donor * weight
    # Remove the sun. The panel's columns next to the seam must still match the
    # panorama's edge, so the sun's soft glow starts at the edge brightness and
    # fades away from the seam into borrowed sky: no second sun, no light streak.
    yy, xx = np.mgrid[0:height, 0:width]
    distance = np.hypot(xx - SUN[0], yy - SUN[1])
    sun_area = smooth(220, 110, distance)[..., None]
    sun_donor = np.roll(front, -340, axis=1)
    fade = smooth(0, 150, xx)[..., None]
    glow = front[:, :1] * (1 - fade) + sun_donor * fade
    return sky * (1 - sun_area) + glow * sun_area


def blur(field: np.ndarray, radius: int) -> np.ndarray:
    """Separable box blur, repeated for a soft, low-frequency field."""
    out = field
    kernel = np.ones(2 * radius + 1) / (2 * radius + 1)
    for _ in range(3):
        out = np.apply_along_axis(lambda v: np.convolve(np.pad(v, radius, mode="wrap"), kernel, mode="valid"), 1, out)
        out = np.apply_along_axis(lambda v: np.convolve(np.pad(v, radius, mode="edge"), kernel, mode="valid"), 0, out)
    return out


def original_tops(front: np.ndarray) -> np.ndarray:
    """Near-hill canopy line of the original, used only beside the seams."""
    r, g, b = front[..., 0], front[..., 1], front[..., 2]
    land = (g >= b - 18) | ((r + g + b) < 300)
    tops = np.full(front.shape[1], SHORE_TOP - 4, dtype=np.int64)
    for x in range(front.shape[1]):
        hits = np.nonzero(land[340:SHORE_TOP, x])[0]
        if hits.size: tops[x] = 340 + hits[0]
    # Single bright or dark pixels (clouds, poles) must not become spikes: take
    # a running median and keep the line within the hills' real range.
    padded = np.pad(tops, 12, mode="edge")
    tops = np.array([np.median(padded[i:i + 25]) for i in range(len(tops))])
    return np.clip(tops, 372, SHORE_TOP - 4)


def clean_water(front: np.ndarray) -> np.ndarray:
    """Front water and shore without Fuji's reflection."""
    water = front.copy()
    columns = np.arange(front.shape[1])
    # Fuji's bright reflection runs down the middle; cover it with ripples
    # from the right side of the same rows.
    weight = smooth(700, 780, columns) * (1 - smooth(1000, 1080, columns))
    donor = np.roll(front, -420, axis=1)
    rows = slice(WATER_TOP, front.shape[0])
    water[rows] = water[rows] * (1 - weight[None, :, None]) + donor[rows] * weight[None, :, None]
    return water


def forest_detail(front: np.ndarray) -> np.ndarray:
    """Leaf-scale detail of the original forest: luminance minus its local mean.

    Only this fine detail is reused (mirror-tiled, never scaled); the hill shapes
    and colours are painted, so no copied silhouette or sky patch repeats.
    """
    region = front[400:430, 20:220]
    r, g, b = region[..., 0], region[..., 1], region[..., 2]
    sky = (b > g + 10) & (b > r + 30) & (b > 140)
    luminance = region.mean(axis=2)
    luminance[sky] = luminance[~sky].mean()
    return luminance - blur(luminance, 4)


def paint_back(front: np.ndarray) -> np.ndarray:
    height, width, _ = front.shape
    total = width * 2
    columns = mirror_map(width, total)
    # Beside each seam: mirror-walked originals (they meet the panorama exactly).
    # Elsewhere: the same pictures repeated by translation, about every 100 deg,
    # so a view never shows a symmetric (kaleidoscope) pattern.
    x_all = np.arange(total)
    mirror_zone = np.maximum(1 - smooth(90, 260, x_all), smooth(total - 260, total - 90, x_all))[None, :, None]
    clean = clean_sky(front)
    sky = clean[:, columns] * mirror_zone + translated(clean, total, 300, 300, width) * (1 - mirror_zone)
    lake = clean_water(front)
    water = lake[:, columns] * mirror_zone + translated(lake, total, 700, 260, width) * (1 - mirror_zone)
    original = clean[:, columns]
    rng = np.random.default_rng(31415)
    out = sky.copy()
    rows = np.arange(height)[:, None]
    x = np.arange(total)
    # Far range: hazy blue mountains in the original's distant colours, with
    # soft mottling and slopes lit from the sun's side (left), no texture repeat.
    # Next to the seams the new ranges sink behind the original hills, so they
    # rise into view gradually instead of starting at an edge.
    emerge = smooth(SEAM * 0.55, SEAM + 320, x) * (1 - smooth(total - SEAM - 320, total - SEAM * 0.55, x))
    sink = (1 - emerge) * 70
    farthest = ridge_profile(rng, total, 352, 16, [(1300, 1.0), (520, 0.5), (200, 0.2)]) + sink
    pale = np.array([146, 170, 188], dtype=np.float32)
    pale_alpha = np.clip(rows - farthest[None, :] + 0.5, 0, 1)[..., None] * 0.85
    out = out * (1 - pale_alpha) + pale * pale_alpha
    far = ridge_profile(rng, total, 366, 24, [(900, 1.0), (420, 0.55), (170, 0.25), (70, 0.08)]) + sink
    top_colour = np.array([114, 140, 150], dtype=np.float32)
    low_colour = np.array([80, 106, 116], dtype=np.float32)
    depth = np.clip((rows - far[None, :]) / 55.0, 0, 1)[..., None]
    far_fill = top_colour * (1 - depth) + low_colour * depth
    slope = np.gradient(far)
    light = np.clip(-slope * 1.4, -1, 1)
    far_fill = far_fill * (1 + 0.14 * light[None, :, None] * (1 - 0.5 * depth))
    mottle = blur(rng.normal(0, 1, (-(-height // 4), -(-total // 4))), 3)
    mottle = np.kron(mottle / max(np.abs(mottle).max(), 1e-6), np.ones((4, 4)))[:height, :total]
    far_fill = far_fill + 10 * mottle[..., None]
    far_alpha = np.clip(rows - far[None, :] + 0.5, 0, 1)[..., None]
    out = out * (1 - far_alpha) + far_fill * far_alpha
    # Near range: forest texture laid 1:1 below a ridge that meets the original
    # hills next to each seam.
    near = ridge_profile(rng, total, 398, 26, [(800, 1.0), (330, 0.6), (130, 0.25), (50, 0.08)])
    source_tops = original_tops(front)[columns].astype(np.float64)
    seam_weight = np.maximum(1 - smooth(SEAM * 0.55, SEAM, x), smooth(total - SEAM, total - SEAM * 0.55, x))
    near = near * (1 - seam_weight) + np.minimum(source_tops, SHORE_TOP - 4) * seam_weight
    near = np.minimum(near, SHORE_TOP - 6)
    # Painted forest: sunlit yellow-green at the canopy, deeper green below,
    # soft mottling, and the original's leaf detail on top.
    canopy = rng.normal(0, 1, total)
    canopy = np.convolve(np.pad(canopy, 2, mode="wrap"), np.ones(5) / 5, mode="valid")
    near = near + 2.2 * canopy * (1 - seam_weight)
    light_colour = np.array([128, 146, 78], dtype=np.float32)
    mid_colour = np.array([66, 104, 66], dtype=np.float32)
    deep_colour = np.array([40, 72, 58], dtype=np.float32)
    below = np.clip((rows - near[None, :]) / 45.0, 0, 1)[..., None]
    forest = np.where(below < 0.35, light_colour + (mid_colour - light_colour) * (below / 0.35),
                      mid_colour + (deep_colour - mid_colour) * ((below - 0.35) / 0.65))
    patches = blur(rng.normal(0, 1, (-(-height // 3), -(-total // 3))), 2)
    patches = np.kron(patches / max(np.abs(patches).max(), 1e-6), np.ones((3, 3)))[:height, :total]
    forest = forest * (1 + 0.16 * patches[..., None])
    detail = forest_detail(front)
    dh, dw = detail.shape
    leaves = detail[mirror_index(rows - np.floor(near[None, :]).astype(np.int64), dh), mirror_index(x, dw)[None, :]]
    forest = forest + 0.9 * leaves[..., None]
    near_alpha = np.clip(rows - near[None, :] + 0.5, 0, 1)[..., None]
    out = out * (1 - near_alpha) + forest * near_alpha
    # Beside the seams the original hills themselves are used.
    seam_mix = seam_weight[None, :, None] * (rows < SHORE_TOP)[..., None]
    out = out * (1 - seam_mix) + original * seam_mix
    # Shore band and water: original pixels, mirror-tiled.
    out[SHORE_TOP - 2:] = water[SHORE_TOP - 2:]
    blend = smooth(SHORE_TOP - 6, SHORE_TOP - 1, rows)[..., None]
    out[SHORE_TOP - 8:SHORE_TOP] = (out[SHORE_TOP - 8:SHORE_TOP] * (1 - blend[SHORE_TOP - 8:SHORE_TOP])
                                    + water[SHORE_TOP - 8:SHORE_TOP] * blend[SHORE_TOP - 8:SHORE_TOP])
    return np.clip(out, 0, 255).astype(np.uint8)


def main() -> None:
    front = np.asarray(Image.open(FRONT).convert("RGB")).astype(np.float32)
    back = paint_back(front)
    width = front.shape[1]
    Image.fromarray(back[:, :width]).save(ENV / "fuji-lake-back-a.png", optimize=True)
    Image.fromarray(back[:, width:]).save(ENV / "fuji-lake-back-b.png", optimize=True)
    print("wrote", ENV / "fuji-lake-back-a.png", "and", ENV / "fuji-lake-back-b.png")


if __name__ == "__main__":
    main()
