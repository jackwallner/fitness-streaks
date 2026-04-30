#!/usr/bin/env python3
"""Generate the chunky pixel-fire app icon for iOS + watchOS."""
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

# 16x16 pixel art flame
FIRE_SPRITE = [
    "                ",
    "       1        ",
    "      121       ",
    "      232       ",
    "     13431  1   ",
    "    1245421 21  ",
    "    2356532 32  ",
    "   134666431431 ",
    "   245666542542 ",
    "  13566666536531",
    "  24666666646542",
    "  13566666545431",
    "   245666554321 ",
    "    1345543221  ",
    "     1233211    ",
    "       111      "
]

COLORS = {
    "1": (120,  22,  44),  # dark red rim
    "2": (190,  38,  40),  # red
    "3": (235,  82,  32),  # red-orange
    "4": (252, 148,  34),  # orange
    "5": (255, 210,  68),  # yellow
    "6": (255, 246, 188),  # white-hot core
}

def build() -> Image.Image:
    # We want a 64x64 canvas. We will draw the 16x16 sprite centered.
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
    
    # Flame sprite is 16x16, map it to the 64x64 grid.
    # Each sprite pixel = 3x3 grid pixels -> 48x48 total.
    scale = 3
    off_x = (GRID - 16 * scale) // 2  # 8
    off_y = (GRID - 16 * scale) // 2 + 2 # 10 (slightly lower to visually center)
    
    for r, row in enumerate(FIRE_SPRITE):
        for c, char in enumerate(row):
            if char in COLORS:
                color = COLORS[char]
                x0 = off_x + c * scale
                y0 = off_y + r * scale
                x1 = x0 + scale - 1
                y1 = y0 + scale - 1
                draw.rectangle([x0, y0, x1, y1], fill=color)

    # tiny ember sparks for character
    sparks = [(14, 14), (46, 12), (10, 28), (52, 34), (16, 46), (48, 48)]
    for x, y in sparks:
        # draw a 2x2 spark
        draw.rectangle([x, y, x+1, y+1], fill=(255, 200, 90))

    return img.resize((OUT, OUT), Image.NEAREST)

def main() -> None:
    icon = build()
    for path in TARGETS:
        # Ensure parent directories exist
        path.parent.mkdir(parents=True, exist_ok=True)
        icon.save(path, format="PNG")
        print(f"wrote {path}")

if __name__ == "__main__":
    main()
