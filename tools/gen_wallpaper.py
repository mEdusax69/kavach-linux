#!/usr/bin/env python3
"""Generates the Kavach Linux wallpaper (1920x1080). Requires: pip install pillow"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import glob
W, H = 1920, 1080
img = Image.new("RGB", (W, H)); px = img.load()
for y in range(H):
    for x in range(W):
        t = x / W * 0.5 + y / H * 0.5
        px[x, y] = (int(10 + 18 * t), int(14 + 10 * t), int(28 + 34 * t))
glow = Image.new("RGB", (W, H), (0, 0, 0)); d = ImageDraw.Draw(glow)
cx, cy = W // 2, H // 2 - 40
d.ellipse((cx - 380, cy - 380, cx + 380, cy + 380), fill=(20, 90, 160))
glow = glow.filter(ImageFilter.GaussianBlur(190))
img = Image.blend(img, Image.composite(glow, img, glow.convert("L")), 0.55)
d = ImageDraw.Draw(img)
def shield(cx, cy, s, w, col):
    pts = [(cx-s, cy-s*.8), (cx, cy-s*1.05), (cx+s, cy-s*.8), (cx+s, cy+s*.1), (cx, cy+s*1.1), (cx-s, cy+s*.1)]
    d.line(pts + [pts[0]], fill=col, width=w, joint="curve")
shield(cx, cy, 170, 8, (60, 170, 255)); shield(cx, cy, 135, 3, (40, 120, 200))
for a, b in [((cx-45, cy-70), (cx-45, cy+70)), ((cx-45, cy+2), (cx+55, cy-70)), ((cx-20, cy-16), (cx+58, cy+70))]:
    d.line([a, b], fill=(235, 245, 255), width=14)
fb = next((p for p in glob.glob("/usr/share/fonts/**/*.ttf", recursive=True)
           if "Bold" in p and ("DejaVuSans" in p or "Liberation" in p) and "Mono" not in p), None)
f1 = ImageFont.truetype(fb, 64) if fb else ImageFont.load_default()
f2 = ImageFont.truetype(fb, 26) if fb else ImageFont.load_default()
for text, font, dy, col in [("KAVACH LINUX", f1, 215, (225, 238, 255)), ("Rakshak  \u2022  1.0", f2, 295, (110, 160, 210))]:
    w = d.textlength(text, font=font); d.text(((W - w) / 2, cy + dy), text, font=font, fill=col)
img.save("wallpaper.png")
