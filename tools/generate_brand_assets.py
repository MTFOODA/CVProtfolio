"""Generate the square brand assets from the supplied logo artwork.

`CV & Portfolio Builder logo.jpg` is a 1407x768 banner: an illustration emblem
above the "CV & PORTFOLIO BUILDER" wordmark on a soft teal backdrop. A launcher
icon cannot use that banner as-is (not square, and the wordmark is unreadable at
48 px), so this script:

1. locates the emblem inside the banner and deliberately ignores the wordmark,
2. crops a square around the emblem (no stretching, no cropping of artwork),
3. extends that crop's edges from its own pixels so the square icon has no
   hard seams, no different-tone plate and no added borders,
4. writes the PNG masters consumed by `flutter_launcher_icons` (see the
   `flutter_launcher_icons:` block in `pubspec.yaml`) and by the in-app logo.

The supplied banner is never modified; only new files are written.

Usage:
    python tools/generate_brand_assets.py
    python tools/generate_brand_assets.py --source "CV & Portfolio Builder logo.jpg"
"""
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageFilter, ImageDraw, ImageStat

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = REPO_ROOT / 'CV & Portfolio Builder logo.jpg'
DEFAULT_OUTPUT = REPO_ROOT / 'assets' / 'branding'
PREVIEW_DIR = REPO_ROOT / 'build' / 'brand_assets_preview'

# Everything darker than this is considered artwork rather than backdrop.
INK_THRESHOLD = 130
# Rows below this belong to the wordmark rather than the emblem.
WORDMARK_TOP = 560
# Square crop margin around the emblem's ink (1.0 = touching the artwork).
CROP_MARGIN = 1.22
# Share of the icon canvas covered by the square artwork crop. The emblem's ink
# occupies about 82% of that crop.
# - legacy mipmaps are masked to a rounded square: 0.86 keeps the emblem large;
# - adaptive layers only guarantee the central 66%, so 0.58 keeps the whole
#   emblem (including its bottom-left dot) inside the circular safe zone;
# - maskable PWA icons may be cropped to a circle of 80%: 0.68 fits inside it.
LEGACY_ART_RATIO = 0.86
ADAPTIVE_ART_RATIO = 0.58
WEB_ART_RATIO = 0.68
CANVAS = 1024


def emblem_box(source: Image.Image) -> tuple[int, int, int, int]:
    """Return the square, wordmark-free crop that frames the emblem."""
    mask = source.convert('L').point(lambda v: 255 if v < INK_THRESHOLD else 0)
    bbox = mask.crop((0, 0, source.width, WORDMARK_TOP)).getbbox()
    if bbox is None:  # pragma: no cover - defensive
        raise SystemExit('could not find the logo emblem in the source image')

    left, top, right, bottom = bbox
    center_x = (left + right) / 2
    center_y = (top + bottom) / 2
    side = round(max(right - left, bottom - top) * CROP_MARGIN)

    x0 = round(center_x - side / 2)
    y0 = round(center_y - side / 2)
    x0 = max(0, min(x0, source.width - side))
    y0 = max(0, min(y0, source.height - side))
    return x0, y0, x0 + side, y0 + side


def edge_color(canvas: Image.Image) -> tuple[int, int, int]:
    """Average of the canvas corners: the tone revealed outside the drawable."""
    patch = max(4, canvas.width // 128)
    spots = [
        canvas.crop((0, 0, patch, patch)),
        canvas.crop((canvas.width - patch, 0, canvas.width, patch)),
        canvas.crop((0, canvas.height - patch, patch, canvas.height)),
        canvas.crop(
            (canvas.width - patch, canvas.height - patch, canvas.width, canvas.height)
        ),
    ]
    strip = Image.new('RGB', (patch * len(spots), patch))
    for index, spot in enumerate(spots):
        strip.paste(spot, (index * patch, 0))
    mean = ImageStat.Stat(strip).mean
    return tuple(int(round(channel)) for channel in mean)


def feathered_mask(size: int, radius_ratio: float = 0.16) -> Image.Image:
    """Square mask whose edges fade out so the crop melts into the backdrop."""
    feather = max(8, round(size * 0.035))
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle(
        (feather, feather, size - feather, size - feather),
        radius=round(size * radius_ratio),
        fill=255,
    )
    return mask.filter(ImageFilter.GaussianBlur(feather / 1.4))


def extend_edges(art: Image.Image, canvas_size: int) -> Image.Image:
    """Pad `art` to `canvas_size` by stretching its own border pixels.

    Stretching the outermost row/column keeps the artwork's own gradient and
    colour, so the padding continues the logo instead of introducing a plate
    with a different tone.
    """
    width, height = art.size
    pad = (canvas_size - width) // 2
    canvas = Image.new('RGB', (canvas_size, canvas_size))
    canvas.paste(art, (pad, pad))

    top = art.crop((0, 0, width, 1)).resize((width, pad), Image.BILINEAR)
    bottom = art.crop((0, height - 1, width, height)).resize(
        (width, pad), Image.BILINEAR
    )
    left = art.crop((0, 0, 1, height)).resize((pad, height), Image.BILINEAR)
    right = art.crop((width - 1, 0, width, height)).resize(
        (pad, height), Image.BILINEAR
    )
    corners = {
        'tl': art.crop((0, 0, 1, 1)),
        'tr': art.crop((width - 1, 0, width, 1)),
        'bl': art.crop((0, height - 1, 1, height)),
        'br': art.crop((width - 1, height - 1, width, height)),
    }

    canvas.paste(top, (pad, 0))
    canvas.paste(bottom, (pad, pad + height))
    canvas.paste(left, (0, pad))
    canvas.paste(right, (pad + width, pad))
    for key, offset in {
        'tl': (0, 0),
        'tr': (pad + width, 0),
        'bl': (0, pad + height),
        'br': (pad + width, pad + height),
    }.items():
        canvas.paste(corners[key].resize((pad, pad), Image.BILINEAR), offset)
    return canvas


def build_icon(
    source: Image.Image, crop: tuple[int, int, int, int], ratio: float
) -> Image.Image:
    """Compose one square icon: edge-extended artwork + sharp emblem crop."""
    art = source.crop(crop).convert('RGB')

    art_size = round(CANVAS * ratio)
    art_layer = art.resize((art_size, art_size), Image.LANCZOS)
    offset = (CANVAS - art_size) // 2
    canvas = extend_edges(art_layer, CANVAS)
    canvas.paste(art_layer, (offset, offset), feathered_mask(art_size))
    return canvas


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=DEFAULT_SOURCE)
    parser.add_argument('--output', type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    source = Image.open(args.source).convert('RGB')
    crop = emblem_box(source)
    args.output.mkdir(parents=True, exist_ok=True)

    icon = build_icon(source, crop, LEGACY_ART_RATIO)
    adaptive = build_icon(source, crop, ADAPTIVE_ART_RATIO)
    web = build_icon(source, crop, WEB_ART_RATIO)

    icon.save(args.output / 'app_icon.png', optimize=True)
    # Adaptive layers are cropped by the launcher mask, so this master is a
    # full-bleed layer (opaque edges) with the emblem inside the safe zone.
    adaptive.save(args.output / 'app_icon_foreground.png', optimize=True)
    web.save(args.output / 'app_icon_web.png', optimize=True)
    icon.resize((512, 512), Image.LANCZOS).save(
        args.output / 'app_logo.png', optimize=True
    )

    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    sheet = Image.new('RGB', (CANVAS * 3 + 40, CANVAS + 20), (246, 247, 251))
    for index, image in enumerate((icon, adaptive, web)):
        sheet.paste(image, (10 + index * (CANVAS + 10), 10))
    sheet.resize((sheet.width // 2, sheet.height // 2), Image.LANCZOS).save(
        PREVIEW_DIR / 'icons.png'
    )
    icon.resize((192, 192), Image.LANCZOS).save(PREVIEW_DIR / 'icon-192.png')

    red, green, blue = edge_color(adaptive)
    print(f'source      : {args.source.name} ({source.width}x{source.height})')
    print(f'emblem crop : {crop} -> {crop[2] - crop[0]} px square')
    print(f'adaptive bg : #{red:02X}{green:02X}{blue:02X}')
    print(f'written to  : {args.output}')


if __name__ == '__main__':
    main()
