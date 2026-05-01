import os
from pathlib import Path
from PIL import Image, ImageDraw

GRID = 64
OUT = 1024
DESKTOP = Path(os.path.expanduser("~/Desktop"))

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

VARIATIONS = [
    {
        "name": "01_original_chunky",
        "bg_top": (18, 14, 36),
        "bg_bot": (40, 18, 58),
        "colors": {"1": (120, 22, 44), "2": (190, 38, 40), "3": (235, 82, 32), "4": (252, 148, 34), "5": (255, 210, 68), "6": (255, 246, 188)},
        "scale": 3
    },
    {
        "name": "02_blue_flame",
        "bg_top": (10, 20, 40),
        "bg_bot": (20, 40, 80),
        "colors": {"1": (22, 44, 120), "2": (38, 80, 190), "3": (32, 140, 235), "4": (34, 180, 252), "5": (68, 220, 255), "6": (188, 246, 255)},
        "scale": 3
    },
    {
        "name": "03_neon_green",
        "bg_top": (14, 25, 14),
        "bg_bot": (20, 50, 20),
        "colors": {"1": (22, 120, 44), "2": (38, 190, 40), "3": (82, 235, 32), "4": (148, 252, 34), "5": (210, 255, 68), "6": (246, 255, 188)},
        "scale": 3
    },
    {
        "name": "04_cyberpunk_pink",
        "bg_top": (30, 10, 40),
        "bg_bot": (60, 20, 80),
        "colors": {"1": (120, 22, 100), "2": (190, 38, 150), "3": (235, 32, 200), "4": (252, 34, 220), "5": (255, 68, 240), "6": (255, 188, 250)},
        "scale": 3
    },
    {
        "name": "05_dark_monochrome",
        "bg_top": (10, 10, 10),
        "bg_bot": (40, 40, 40),
        "colors": {"1": (60, 60, 60), "2": (100, 100, 100), "3": (140, 140, 140), "4": (180, 180, 180), "5": (220, 220, 220), "6": (255, 255, 255)},
        "scale": 3
    },
    {
        "name": "06_light_theme",
        "bg_top": (240, 240, 245),
        "bg_bot": (200, 200, 210),
        "colors": {"1": (180, 50, 50), "2": (220, 80, 80), "3": (250, 120, 80), "4": (255, 160, 100), "5": (255, 200, 120), "6": (255, 255, 255)},
        "scale": 3
    },
    {
        "name": "07_golden_flame",
        "bg_top": (30, 25, 10),
        "bg_bot": (70, 50, 20),
        "colors": {"1": (150, 100, 20), "2": (200, 140, 30), "3": (230, 180, 40), "4": (250, 210, 50), "5": (255, 230, 100), "6": (255, 255, 200)},
        "scale": 3
    },
    {
        "name": "08_purple_magic",
        "bg_top": (15, 10, 25),
        "bg_bot": (40, 20, 60),
        "colors": {"1": (80, 20, 120), "2": (130, 40, 180), "3": (180, 60, 220), "4": (210, 100, 240), "5": (240, 150, 255), "6": (255, 220, 255)},
        "scale": 3
    },
    {
        "name": "09_larger_sprite",
        "bg_top": (18, 14, 36),
        "bg_bot": (40, 18, 58),
        "colors": {"1": (120, 22, 44), "2": (190, 38, 40), "3": (235, 82, 32), "4": (252, 148, 34), "5": (255, 210, 68), "6": (255, 246, 188)},
        "scale": 4
    },
    {
        "name": "10_smaller_sprite",
        "bg_top": (18, 14, 36),
        "bg_bot": (40, 18, 58),
        "colors": {"1": (120, 22, 44), "2": (190, 38, 40), "3": (235, 82, 32), "4": (252, 148, 34), "5": (255, 210, 68), "6": (255, 246, 188)},
        "scale": 2
    }
]

def build(var) -> Image.Image:
    img = Image.new("RGB", (GRID, GRID))
    bg_top = var["bg_top"]
    bg_bot = var["bg_bot"]
    colors = var["colors"]
    scale = var["scale"]
    
    for y in range(GRID):
        t = y / (GRID - 1)
        r = round(bg_top[0] + (bg_bot[0] - bg_top[0]) * t)
        g = round(bg_top[1] + (bg_bot[1] - bg_top[1]) * t)
        b = round(bg_top[2] + (bg_bot[2] - bg_top[2]) * t)
        for x in range(GRID):
            img.putpixel((x, y), (r, g, b))
            
    draw = ImageDraw.Draw(img)
    
    off_x = (GRID - 16 * scale) // 2
    off_y = (GRID - 16 * scale) // 2 + 2
    
    for r, row in enumerate(FIRE_SPRITE):
        for c, char in enumerate(row):
            if char in colors:
                color = colors[char]
                x0 = off_x + c * scale
                y0 = off_y + r * scale
                x1 = x0 + scale - 1
                y1 = y0 + scale - 1
                draw.rectangle([x0, y0, x1, y1], fill=color)

    if "dark_monochrome" not in var["name"]:
        sparks = [(14, 14), (46, 12), (10, 28), (52, 34), (16, 46), (48, 48)]
        spark_color = colors.get("5", (255, 200, 90))
        for x, y in sparks:
            draw.rectangle([x, y, x+1, y+1], fill=spark_color)

    return img.resize((OUT, OUT), Image.NEAREST)

def main():
    desktop_dir = DESKTOP / "FitnessStreaks_Icon_Options"
    desktop_dir.mkdir(parents=True, exist_ok=True)
    
    for var in VARIATIONS:
        icon = build(var)
        path = desktop_dir / f"{var['name']}.png"
        icon.save(path, format="PNG")
        print(f"Generated {path}")

if __name__ == "__main__":
    main()
