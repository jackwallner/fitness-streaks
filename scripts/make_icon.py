#!/usr/bin/env python3
"""Generate the retro pixel flame app icon for iOS + watchOS.

Style: single white silhouette on a cyan→purple gradient — Apple Health
symptom-icon look — but the silhouette is a recognizable 8-bit flame
(two tongues + curl) so it reads as fire, not a blob.
"""
from pathlib import Path

from PIL import Image, ImageDraw

GRID = 64          # 32×32 sprite, 2× upscale for chunky pixels
OUT = 1024
ROOT = Path(__file__).resolve().parent.parent
TARGETS = [
    ROOT / "FitnessStreaks/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png",
    ROOT / "FitnessStreaksWatch/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png",
]

BG_TOP = (80, 210, 255)   # bright cyan
BG_BOT = (160, 70, 255)   # vivid purple

# 32×32 retro flame sprite. Centered, symmetric body.
# Two tongues at the top (taller on the right, shorter on the left) with a
# clear notch between them — the unmistakable fire-emoji silhouette.
FLAME_SPRITE = [
    "                                ",  # 0
    "                                ",  # 1
    "                  1             ",  # 2   main tongue tip
    "                 11             ",  # 3
    "                 11             ",  # 4
    "                111             ",  # 5
    "           11   111             ",  # 6   side tongue appears + notch
    "          111   1111            ",  # 7
    "         1111   1111            ",  # 8
    "         1111  11111            ",  # 9
    "         11111111111            ",  # 10  tongues merge
    "        1111111111111           ",  # 11
    "       11111111111111           ",  # 12
    "      111111111111111           ",  # 13
    "      1111111111111111          ",  # 14
    "     11111111111111111          ",  # 15
    "     111111111111111111         ",  # 16
    "    1111111111111111111         ",  # 17
    "    11111111111111111111        ",  # 18
    "    11111111111111111111        ",  # 19
    "    11111111111111111111        ",  # 20
    "    11111111111111111111        ",  # 21
    "    11111111111111111111        ",  # 22
    "    11111111111111111111        ",  # 23
    "     111111111111111111         ",  # 24
    "      1111111111111111          ",  # 25
    "       11111111111111           ",  # 26
    "         1111111111             ",  # 27
    "                                ",  # 28
    "                                ",  # 29
    "                                ",  # 30
    "                                ",  # 31
]

WHITE = (255, 255, 255)


def build() -> Image.Image:
    img = Image.new("RGB", (GRID, GRID))
    for y in range(GRID):
        t = y / (GRID - 1)
        r = round(BG_TOP[0] + (BG_BOT[0] - BG_TOP[0]) * t)
        g = round(BG_TOP[1] + (BG_BOT[1] - BG_TOP[1]) * t)
        b = round(BG_TOP[2] + (BG_BOT[2] - BG_TOP[2]) * t)
        for x in range(GRID):
            img.putpixel((x, y), (r, g, b))

    draw = ImageDraw.Draw(img)
    scale = 2  # 32×32 sprite → 64×64 canvas
    for r, row in enumerate(FLAME_SPRITE):
        padded = row.ljust(32, " ")[:32]
        for c, ch in enumerate(padded):
            if ch == "1":
                x0 = c * scale
                y0 = r * scale
                draw.rectangle([x0, y0, x0 + scale - 1, y0 + scale - 1], fill=WHITE)

    return img.resize((OUT, OUT), Image.NEAREST)


def main() -> None:
    icon = build()
    for path in TARGETS:
        path.parent.mkdir(parents=True, exist_ok=True)
        icon.save(path, format="PNG")
        print(f"wrote {path}")


if __name__ == "__main__":
    main()
