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
    designs = {}
    for name, brand, slogan, bg, fg in [
        ('aerova','AEROVA','CHASE THE HORIZON','#143e72','#ffffff'),
        ('shift','SHIFT 96','FIND YOUR NEXT GEAR','#f2b830','#18232a'),
        ('fizz','CANYON FIZZ','TASTE THE ADVENTURE','#ca4532','#fff5d8'),
        ('apex','APEX OIL','KEEP THE MOMENTUM','#11786f','#fff6d7'),
        ('summit','SUMMIT TIRE','GRIP EVERY CORNER','#322d4e','#ffe28b'),
        ('route84','ROUTE 84','THE ROAD IS YOURS','#e57036','#fff7e8'),
        ('bluebay','BLUEBAY','TAKE THE COAST ROAD','#085f86','#daf6e9'),
        ('orbit','ORBIT AUTO','MADE FOR THE DRIVE','#e9e3cf','#283a4e')]:
        svg = '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="448" viewBox="0 0 1024 448">'
        svg += f'<rect width="1024" height="448" rx="10" fill="{bg}"/><rect x="13" y="13" width="998" height="422" rx="4" fill="none" stroke="{fg}" stroke-width="6"/>'
        if name == 'summit': svg += '<path d="M0 448L230 0H325L95 448Z M130 448L360 0H410L180 448Z" fill="#595272"/>'
        if name == 'route84': svg += '<path d="M0 340H1024V400H0Z" fill="#a73c24"/><path d="M0 358H1024" stroke="#f3c78f" stroke-width="6" stroke-dasharray="60 35"/>'
        if name == 'bluebay': svg += '<path d="M0 370Q170 300 340 370T680 370T1024 370V448H0Z" fill="#14a7b6"/>'
        if name == 'orbit': svg += '<ellipse cx="900" cy="100" rx="220" ry="65" transform="rotate(-25 900 100)" fill="none" stroke="#c2a66a" stroke-width="18"/>'
        svg += f'<path d="M56 105H104L62 254H14Z M113 105H161L119 254H71Z" fill="{fg}" opacity=".7"/>'
        svg += text(brand,173,231,104 if len(brand)<10 else 88,fg)
        svg += text(slogan,173,310,36,fg)
        svg += f'<path d="M173 352H951" stroke="{fg}" stroke-width="7"/><path d="M887 78L957 78L940 99L870 99Z" fill="{fg}"/>'
        designs[name] = svg+'</svg>\n'
    names=['aerova','shift','fizz','apex','summit','route84','bluebay','orbit']
    pieces=['<svg xmlns="http://www.w3.org/2000/svg" width="2048" height="448" viewBox="0 0 4096 896">']
    for i,name in enumerate(names):
        source=designs[name]
        body=source[source.index('>')+1:source.rindex('</svg>')]
        pieces.append(f'<g transform="translate({i%4*1024} {i//4*448})">{body}</g>')
    (ROOT/'assets/environment/ad-print-atlas.svg').write_text(''.join(pieces)+'</svg>\n')
if __name__ == '__main__':
    main()
