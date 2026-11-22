#!/usr/bin/env python3
"""Replace the simulator's default lock-screen date with one consistent with the
seeded data (Netflix renews Tue 4 Aug, so 'renews soon' reads true on Sun 2 Aug)."""
from PIL import Image, ImageDraw, ImageFont

P = "/Users/sambulosenda/Documents/indie/Rubradar/sim-shots/v5/lock.png"
im = Image.open(P).convert("RGB")
W, H = im.size

X0, X1 = 430, 780          # band covering "Sat 1 Jan"
Y0, Y1 = 288, 350
TOP, BOT = Y0 - 3, Y1 + 3  # clean rows to interpolate between

px = im.load()
for x in range(X0, X1):
    top = px[x, TOP]
    bot = px[x, BOT]
    span = BOT - TOP
    for y in range(TOP + 1, BOT):
        t = (y - TOP) / span
        px[x, y] = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))

d = ImageDraw.Draw(im)
text = "Sun 2 Aug"
target_w = 262            # measured width of the original string
size = 40
while True:
    f = ImageFont.truetype("/Library/Fonts/SF-Pro-Display-Semibold.otf", size)
    if d.textlength(text, font=f) >= target_w or size > 120:
        break
    size += 1
f = ImageFont.truetype("/Library/Fonts/SF-Pro-Display-Semibold.otf", size)
tw = d.textlength(text, font=f)
bbox = d.textbbox((0, 0), text, font=f)
d.text(((W - tw) / 2, 296 - bbox[1]), text, font=f, fill=(132, 165, 231))
im.save(P)
print("patched, font size", size)
