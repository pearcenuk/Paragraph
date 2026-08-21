#!/usr/bin/env python3
"""Generate Paragraph's application icon.

The icon is a pilcrow — the mark that ends a paragraph — set in IBM Plex Sans,
the same typeface the editor uses. It is rendered here rather than drawn by
hand so that it can be reproduced exactly, and so each size is laid out at its
own scale instead of being downscaled from one large image: a 16-pixel icon
made by shrinking a 1024-pixel one is mush.

    python3 Tools/make-icon.py

Writes Paragraph/Resources/AppIcon.icns. Requires Pillow and macOS iconutil.
"""

import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(ROOT, "Paragraph/Resources/Fonts/IBMPlexSans.ttf")
OUTPUT = os.path.join(ROOT, "Paragraph/Resources/AppIcon.icns")
WORK = os.path.join(ROOT, "build/AppIcon.iconset")

CANVAS = 1024
SHAPE_FRACTION = 824 / 1024      # Apple's macOS icon grid
CORNER_FRACTION = 0.2225         # squircle corner radius, of the shape's width
GLYPH_FRACTION = 0.55            # of the shape's height
OPTICAL_LIFT = 0.02              # the mark is bottom-heavy, so raise it slightly
WEIGHT = 700                     # heavy enough to survive 16 pixels

FACE = (16, 22, 16)              # near-black with a faint green undertone
GREEN = (153, 222, 153)          # the Green Screen theme's body text


def render(size: int) -> Image.Image:
    scale = size / CANVAS
    shape = CANVAS * SHAPE_FRACTION * scale
    inset = (size - shape) / 2

    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle(
        [inset, inset, size - inset, size - inset],
        radius=shape * CORNER_FRACTION,
        fill=FACE + (255,),
    )

    target = max(6, int(shape * GLYPH_FRACTION))
    point = target * 2
    for _ in range(50):
        font = ImageFont.truetype(FONT, point)
        font.set_variation_by_axes([WEIGHT, 100])
        box = draw.textbbox((0, 0), "¶", font=font)
        height = box[3] - box[1]
        if height == 0 or abs(height - target) <= 1:
            break
        point = max(6, int(round(point * target / max(1, height))))

    font = ImageFont.truetype(FONT, point)
    font.set_variation_by_axes([WEIGHT, 100])
    box = draw.textbbox((0, 0), "¶", font=font)
    width, height = box[2] - box[0], box[3] - box[1]
    draw.text(
        ((size - width) / 2 - box[0], (size - height) / 2 - box[1] - shape * OPTICAL_LIFT),
        "¶",
        font=font,
        fill=GREEN + (255,),
    )
    return image


def main() -> int:
    if not os.path.exists(FONT):
        print(f"missing font: {FONT}", file=sys.stderr)
        return 1

    os.makedirs(WORK, exist_ok=True)
    for pixels, name in [
        (16, "16x16"), (32, "16x16@2x"),
        (32, "32x32"), (64, "32x32@2x"),
        (128, "128x128"), (256, "128x128@2x"),
        (256, "256x256"), (512, "256x256@2x"),
        (512, "512x512"), (1024, "512x512@2x"),
    ]:
        render(pixels).save(os.path.join(WORK, f"icon_{name}.png"))

    subprocess.run(["iconutil", "-c", "icns", WORK, "-o", OUTPUT], check=True)
    print(f"wrote {os.path.relpath(OUTPUT, ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
