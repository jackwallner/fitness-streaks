import os
from pathlib import Path
from PIL import Image, ImageDraw

OUT = 1024
GRID = 64
DESKTOP = Path(os.path.expanduser("~/Desktop"))

# Simple, bold retro pixel trophy
TROPHY_32 = [
    "                                ",
    "                                ",
    "                                ",
    "                                ",
    "           1111111111           ",
    "         11111111111111         ",
    "        1111111111111111        ",
    "  111   1111111111111111   111  ",
    " 11111  1111111111111111  11111 ",
    " 11  11 1111111111111111 11  11 ",
    " 11   11111111111111111111   11 ",
    " 11   11111111111111111111   11 ",
    " 11   11111111111111111111   11 ",
    " 11   11111111111111111111   11 ",
    " 11  111  111111111111  111  11 ",
    " 111111    1111111111    111111 ",
    "  1111       111111       1111  ",
    "   11         1111         11   ",
    "               11               ",
    "               11               ",
    "              1111              ",
    "              1111              ",
    "             111111             ",
    "            11111111            ",
    "           1111111111           ",
    "          111111111111          ",
    "         11111111111111         ",
    "                                ",
    "                                ",
    "                                ",
    "                                ",
    "                                "
]

COLORS = {
    "1": (255, 255, 255),  # Pure white
}

# Vitals to Headache gradient: Cyan -> Blue -> Purple
BG_TOP = (80, 200, 255) # light cyan
BG_BOT = (150, 80, 255) # light purple

img = Image.new("RGB", (GRID, GRID))
for y in range(GRID):
    t = y / (GRID - 1)
    r = round(BG_TOP[0] + (BG_BOT[0] - BG_TOP[0]) * t)
    g = round(BG_TOP[1] + (BG_BOT[1] - BG_TOP[1]) * t)
    b = round(BG_TOP[2] + (BG_BOT[2] - BG_TOP[2]) * t)
    for x in range(GRID):
        img.putpixel((x, y), (r, g, b))
        
draw = ImageDraw.Draw(img)

scale = 2
for r, row in enumerate(TROPHY_32):
    for c, char in enumerate(row.ljust(32, ' ')[:32]):
        if char in COLORS:
            color = COLORS[char]
            x0 = c * scale
            y0 = r * scale
            x1 = x0 + scale - 1
            y1 = y0 + scale - 1
            draw.rectangle([x0, y0, x1, y1], fill=color)

img = img.resize((OUT, OUT), Image.NEAREST)
img.save(DESKTOP / "Vitals_Style_Trophy.png")
print("Saved to desktop")
