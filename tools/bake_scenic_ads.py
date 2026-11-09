#!/usr/bin/env python3
"""프로젝트 가상 브랜드의 광고판 SVG를 번들 글꼴 윤곽선으로 만듭니다."""
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
ROOT = Path(__file__).resolve().parents[1]
font = TTFont(ROOT / 'assets/fonts/Roboto-BoldItalic.ttf')
glyphs = font.getGlyphSet()
cmap = font.getBestCmap()
units = font['head'].unitsPerEm

def text(label, x, y, size, color):
    paths = []
    for char in label:
        name = cmap[ord(char)]
        pen = SVGPathPen(glyphs)
        glyphs[name].draw(pen)
        paths.append(f'<path transform="translate({x:.3f} {y}) scale({size/units:.8f} {-size/units:.8f})" d="{pen.getCommands()}"/>')
        x += font['hmtx'][name][0] * size / units
    return f'<g fill="{color}">'+''.join(paths)+'</g>'

def main():
    for name, brand, slogan, bg, fg in [
        ('aerova','AEROVA','CHASE THE HORIZON','#143e72','#ffffff'),
        ('shift','SHIFT 96','FIND YOUR NEXT GEAR','#f2b830','#18232a'),
        ('fizz','CANYON FIZZ','TASTE THE ADVENTURE','#ca4532','#fff5d8'),
        ('apex','APEX OIL','KEEP THE MOMENTUM','#11786f','#fff6d7')]:
        svg = '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="448" viewBox="0 0 1024 448">'
        svg += f'<rect width="1024" height="448" rx="10" fill="{bg}"/><rect x="13" y="13" width="998" height="422" rx="4" fill="none" stroke="{fg}" stroke-width="6"/>'
        svg += f'<path d="M56 105H104L62 254H14Z M113 105H161L119 254H71Z" fill="{fg}" opacity=".7"/>'
        svg += text(brand,173,231,104 if len(brand)<10 else 88,fg)
        svg += text(slogan,173,310,36,fg)
        svg += f'<path d="M173 352H951" stroke="{fg}" stroke-width="7"/><path d="M887 78L957 78L940 99L870 99Z" fill="{fg}"/>'
        (ROOT / f'assets/environment/ad-{name}.svg').write_text(svg+'</svg>\n')
if __name__ == '__main__':
    main()
