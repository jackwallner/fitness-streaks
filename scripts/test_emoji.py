import sys
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

OUT = 1024
img = Image.new("RGB", (OUT, OUT), (20, 15, 60))
draw = ImageDraw.Draw(img)

try:
    font = ImageFont.truetype("/System/Library/Fonts/Apple Color Emoji.ttc", 700)
    draw.text((OUT/2, OUT/2), "🏆", font=font, embedded_color=True, anchor="mm")
    img.save("emoji_test.png")
    print("Success")
except Exception as e:
    print("Error:", e)
