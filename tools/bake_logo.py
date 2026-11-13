#!/usr/bin/env python3
"""Build the flat INITIAL SJ vector wordmark and its identical web copy.

The lettering is outlined from bundled Apache-2.0 Roboto Bold Italic, so SVG
rendering does not depend on a browser/system font. Requires fontTools.
Run: python3 tools/bake_logo.py
"""
import base64
import re
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'art_sources/ui/coastal/retired/initialsj_logo.svg'
SHELL = ROOT / 'web/coast-rush-shell.html'
FONT = TTFont(ROOT / 'assets/fonts/Roboto-BoldItalic.ttf')
GLYPHS = FONT.getGlyphSet()
CMAP = FONT.getBestCmap()
UNITS = FONT['head'].unitsPerEm


def lettering(text, x, baseline, size, color, tracking=0):
    # Advance uses pixel coordinates; each glyph gets its own scale so the
    # tracking and translation stay independent of font design units.
    pieces = []
    cursor = x
    for char in text:
        name = CMAP[ord(char)]
        pen = SVGPathPen(GLYPHS)
        GLYPHS[name].draw(pen)
        if pen.getCommands():
            pieces.append(f'<path transform="translate({cursor:.3f} {baseline}) scale({size/UNITS:.8f} {-size/UNITS:.8f})" d="{pen.getCommands()}"/>')
        cursor += FONT['hmtx'][name][0] * size / UNITS + tracking
    return f'<g fill="{color}">'+''.join(pieces)+'</g>', cursor-x-tracking


def build():
    initial, width = lettering('INITIAL', 92, 166, 188, '#f3f6f8', 3.0)
    sj, sj_width = lettering('SJ', 92 + width + 28, 166, 188, '#42dceb', 3.0)
    subtitle, _ = lettering('COAST RUSH', 98, 224, 29, '#bfced8', 8.0)
    canvas_width = round(92 + width + 28 + sj_width + 28)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{canvas_width}" height="252" '
            f'viewBox="0 0 {canvas_width} 252" role="img" aria-labelledby="brand-title">'
            '<title id="brand-title">Initial SJ — Coast Rush</title>'
            '<path d="M28 164H44L76 53H60Z" fill="#ff895b"/>'
            + initial + sj + subtitle + '</svg>\n')


def main():
    svg = build()
    OUT.write_text(svg)
    uri = 'data:image/svg+xml;base64,' + base64.b64encode(svg.encode()).decode()
    pattern = re.compile(r'(<!--logo:start-->).*?(<!--logo:end-->)', re.S)
    html = SHELL.read_text()
    if not pattern.search(html):
        raise SystemExit('Missing web logo markers')
    html = pattern.sub(lambda m: m.group(1) + '<img class="loading-logo" alt="Initial SJ Coast Rush" src="' + uri + '">' + m.group(2), html)
    SHELL.write_text(html)
    print(f'Vector wordmark: {len(svg)} bytes; matching web copy embedded')


if __name__ == '__main__':
    main()
