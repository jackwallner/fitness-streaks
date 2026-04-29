#!/usr/bin/env python3
"""Generate the chunky pixel-fire app icon for iOS + watchOS."""
import math
from pathlib import Path

from PIL import Image, ImageDraw

GRID = 64          # low-res canvas → chunky pixels when upscaled
OUT = 1024         # icon resolution
ROOT = Path(__file__).resolve().parent.parent
TARGETS = [
    ROOT / "FitnessStreaks/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png",
    ROOT / "FitnessStreaksWatch/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png",
]

BG_TOP = (18, 14, 36)
BG_BOT = (40, 18, 58)


def flame_polygon(scale: float, y_shift: float, sway: float) -> list[tuple[float, float]]:
    pts_left, pts_right = [], []
    cx = GRID * 0.5
    top = GRID * (0.10 + y_shift)
    bot = GRID * (0.94 - y_shift * 0.4)
    H = bot - top
    N = 120
    for i in range(N + 1):
        t = i / N
        y = top + t * H
        # asymmetric flame "lick" — top sways left, bottom centers
        cx_off = -math.sin(t * math.pi) * GRID * sway * (1 - t * 0.7)
        if t < 0.70:
            # upper teardrop: pointed tip widening down
            w = GRID * 0.36 * scale * math.pow(t / 0.70, 0.80)
        else:
            # round bulb at the base
            tt = (t - 0.70) / 0.30
            w = GRID * 0.36 * scale * math.sqrt(max(0.0, 1 - tt * tt))
        pts_left.append((cx + cx_off - w, y))
        pts_right.append((cx + cx_off + w, y))
    return pts_left + pts_right[::-1]


def build() -> Image.Image:
    img = Image.new("RGB", (GRID, GRID))
    # vertical gradient background (banded by pixel — looks good upscaled)
    for y in range(GRID):
        t = y / (GRID - 1)
        r = round(BG_TOP[0] + (BG_BOT[0] - BG_TOP[0]) * t)
        g = round(BG_TOP[1] + (BG_BOT[1] - BG_TOP[1]) * t)
        b = round(BG_TOP[2] + (BG_BOT[2] - BG_TOP[2]) * t)
        for x in range(GRID):
            img.putpixel((x, y), (r, g, b))

    draw = ImageDraw.Draw(img)
    # outer rim → bright core. PIL's polygon fill is non-AA, so edges stay crisp.
    layers = [
        (1.00, 0.000, 0.045, (120,  22,  44)),  # dark red rim
        (0.92, 0.012, 0.042, (190,  38,  40)),  # red
        (0.78, 0.030, 0.038, (235,  82,  32)),  # red-orange
        (0.62, 0.060, 0.032, (252, 148,  34)),  # orange
        (0.45, 0.100, 0.026, (255, 210,  68)),  # yellow
        (0.28, 0.150, 0.020, (255, 246, 188)),  # white-hot core
    ]
    for scale, y_shift, sway, color in layers:
        draw.polygon(flame_polygon(scale, y_shift, sway), fill=color)

    # tiny ember sparks for character
    sparks = [(11, 14), (52, 18), (8, 30), (55, 36), (14, 49), (50, 50)]
    for x, y in sparks:
        img.putpixel((x, y), (255, 200, 90))

    return img.resize((OUT, OUT), Image.NEAREST)


def main() -> None:
    icon = build()
    for path in TARGETS:
        icon.save(path, format="PNG")
        print(f"wrote {path}")


if __name__ == "__main__":
    main()
