import os
from pathlib import Path
from PIL import Image, ImageDraw

OUT = 1024
GRID = 64
DESKTOP = Path(os.path.expanduser("~/Desktop"))

TROPHY_32 = [
    "                                ",
    "                                ",
    "                                ",
    "                                ",
    "           1111111111           ",
    "         11222222222211         ",
    "        1223333333333221        ",
    "  111   1233444444443321   111  ",
    " 12221  1234444444444321  12221 ",
    " 121221 1234455444444321 122121 ",
    " 121 1211234455444444321121 121 ",
    " 121  12123444544444432121  121 ",
    " 121  12123444444444432121  121 ",
    " 121  12123344444444332121  121 ",
    " 121 1221223344444433221221 121 ",
    " 122122112233344443332211221221 ",
    "  12221 1222333333332221 12221  ",
    "   111   11222222222211   111   ",
    "            11233211            ",
    "             123421             ",
    "              1341              ",
    "              1341              ",
    "             123421             ",
    "            12334421            ",
    "           1233444421           ",
    "          123344444421          ",
    "         11111111111111         ",
    "                                ",
    "                                ",
    "                                ",
    "                                ",
    "                                "
]

COLORS = {
    "1": (90,  50,  10),   # Outline: Very dark gold / brown
    "2": (180, 110, 20),   # Dark gold (shadows)
    "3": (230, 160, 30),   # Medium gold (midtones)
    "4": (255, 210, 50),   # Light gold (base cup color)
    "5": (255, 255, 180),  # Highlight (bright shine)
    "6": (255, 255, 255),  # Sparkle
}

img = Image.new("RGB", (GRID, GRID), (20, 15, 60))
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

# Add some nice star sparkles (drawn directly with PIL for cleaner look)
sparks = [(12, 10), (50, 8), (18, 50), (46, 46), (10, 32), (54, 30)]
for x, y in sparks:
    draw.rectangle([x, y, x+1, y+1], fill=COLORS["5"])
    draw.rectangle([x, y, x, y], fill=COLORS["6"])

img = img.resize((OUT, OUT), Image.NEAREST)
img.save(DESKTOP / "Trophy_32_Test.png")
print("Saved to desktop")
