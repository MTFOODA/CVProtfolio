"""Render approved CV ligature proposal 4 from shared vector geometry.

The SVG and supersampled raster masters use the same path commands. Pillow is
the only dependency. Run dart run flutter_launcher_icons afterwards.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'branding'
INK, SKY, PAPER = '#2D333B', '#6CABDD', '#F1F4F6'

# One continuous CV ligature: C bowl, shared diagonal and rounded V arm.
# The SVG and rasterizer consume these same absolute vector commands.
MARK = [
    ('M', 280, 193),
    ('C', 256, 158, 231, 150, 190, 150),
    ('C', 114, 150, 62, 202, 62, 262),
    ('C', 62, 324, 110, 362, 179, 362),
    ('C', 216, 362, 245, 348, 265, 324),
    ('L', 233, 269),
    ('C', 220, 288, 204, 298, 181, 298),
    ('C', 145, 298, 124, 279, 124, 253),
    ('C', 124, 225, 148, 208, 181, 208),
    ('C', 205, 208, 215, 218, 228, 239),
    ('L', 284, 338),
    ('C', 293, 354, 305, 362, 322, 362),
    ('C', 338, 362, 351, 354, 360, 338),
    ('L', 454, 169),
    ('C', 461, 156, 457, 150, 443, 150),
    ('L', 420, 150),
    ('C', 404, 150, 392, 158, 386, 170),
    ('L', 321, 282),
    ('Z',),
]


def svg_path():
    return ' '.join(str(value) for command in MARK for value in command)


def outline():
    points = []
    cursor = (0, 0)
    for command in MARK:
        kind, *values = command
        if kind in ('M', 'L'):
            cursor = tuple(values)
            points.append(cursor)
        elif kind == 'C':
            start = cursor
            first, second, end = values[:2], values[2:4], values[4:]
            for step in range(1, 65):
                t = step / 64
                u = 1 - t
                points.append(tuple(
                    u**3 * start[axis] + 3 * u**2 * t * first[axis]
                    + 3 * u * t**2 * second[axis] + t**3 * end[axis]
                    for axis in (0, 1)
                ))
            cursor = tuple(end)
    return points


def render(ratio=1, size=1024, rounded=False, background=INK, foreground=SKY):
    # Launchers apply their own masks to full-bleed masters. In-app artwork
    # instead has transparent rounded corners, matching the approved tile.
    canvas = size * 4
    image = Image.new('RGBA', (canvas, canvas), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    if rounded:
        draw.rounded_rectangle((0, 0, canvas, canvas), radius=canvas * .21875, fill=background)
    else:
        draw.rectangle((0, 0, canvas, canvas), fill=background)
    factor = canvas / 512
    points = [((256 + (x - 256) * ratio) * factor,
               (256 + (y - 256) * ratio) * factor) for x, y in outline()]
    draw.polygon(points, fill=foreground)
    return image.resize((size, size), Image.Resampling.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" role="img" aria-labelledby="title desc">
<title id="title">CV &amp; Portfolio Builder</title>
<desc id="desc">A continuous sky blue CV monogram on a rounded graphite tile.</desc>
<rect width="512" height="512" rx="112" fill="{INK}"/>
<path d="{svg_path()}" fill="{SKY}"/>
</svg>
'''
    (OUT / 'brand_mark.svg').write_text(svg, encoding='utf-8')
    for name, ratio in [('app_icon', 1), ('app_icon_foreground', .70), ('app_icon_web', .82)]:
        render(ratio).convert('RGB').save(OUT / f'{name}.png', optimize=True)
    render(size=512, rounded=True).save(OUT / 'app_logo.png', optimize=True)
    render(size=256, rounded=True, background='#FFFFFF', foreground=(0, 0, 0, 0)).save(OUT / 'portfolio_link_logo.png', optimize=True)

    card = Image.new('RGB', (1200, 630), PAPER)
    tile = render(size=260, rounded=True)
    card.paste(tile, (80, 185), tile)
    fonts = ROOT / 'assets' / 'google_fonts'
    draw = ImageDraw.Draw(card)
    title = ImageFont.truetype(str(fonts / 'Inter-Bold.ttf'), 64)
    caption = ImageFont.truetype(str(fonts / 'Inter-Regular.ttf'), 28)
    draw.text((395, 205), 'CV & Portfolio', font=title, fill=INK)
    draw.text((395, 290), 'Builder', font=title, fill=INK)
    draw.rounded_rectangle((398, 393, 525, 401), radius=4, fill=SKY)
    draw.text((395, 435), 'Your story. Moving forward.', font=caption, fill='#616870')
    card.save(ROOT / 'web' / 'social-preview.png', optimize=True)

    # Local visual QA: real small sizes and enlarged unsmoothed silhouettes.
    preview = ROOT / 'build' / 'brand_assets_preview'
    preview.mkdir(parents=True, exist_ok=True)
    sheet = Image.new('RGB', (1000, 410), PAPER)
    draw = ImageDraw.Draw(sheet)
    for index, size in enumerate((16, 24, 32, 48, 192)):
        icon = render(size=size, rounded=True)
        x = 20 + index * 195
        sheet.paste(icon, (x, 45), icon)
        draw.text((x, 20), f'{size}px', fill=INK)
        zoom = icon.resize((156, 156), Image.Resampling.NEAREST)
        sheet.paste(zoom, (x, 240), zoom)
    sheet.save(preview / 'cv-monogram-sizes.png')
    print('Created CV monogram SVG, raster masters, size preview and share card.')


if __name__ == '__main__':
    main()
