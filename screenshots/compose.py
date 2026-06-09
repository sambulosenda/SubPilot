#!/usr/bin/env python3
"""Compose App Store screenshots for SubPilot.

Frames raw 1320x2868 (iPhone 16 Pro Max) simulator captures on a premium teal
gradient with a two-tier caption, and RE-RENDERS the layout natively at every
App Store Connect size (no stretching -> crisp text, undistorted device).
Deterministic — no network, no AI. Run with the system Python (ships Pillow):

    /usr/bin/python3 screenshots/compose.py

Regenerate the raws first via the DEBUG -DemoSeed / -StartTab launch args
(see aso-screenshots memory).

Output wells:
    final-69/  1320x2868  -> App Store Connect "6.9-inch" iPhone slot
    final-65/  1284x2778  -> App Store Connect "6.5-inch" iPhone slot
ASC auto-scales the largest set down, but each slot validates its exact dims,
so we emit a native set per slot.
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "v2-raw")
FONT_TTC = "/System/Library/Fonts/HelveticaNeue.ttc"
COND_BLACK = 9                          # Helvetica Neue Condensed Black face index
BASE_W = 1320                           # design reference width; everything scales off this

# Target wells: (width, height, output-subdir).
TARGETS = [
    (1320, 2868, "final-69"),           # 6.9" iPhone (16 Pro Max)
    (1284, 2778, "final-65"),           # 6.5" iPhone (12-14 Pro Max) — ASC 6.5" slot
]

# Brand teal gradient stops (top -> base -> deep) and the upper-centre glow.
TOP  = (20, 184, 166)    # #14B8A6
BASE = (13, 148, 136)    # #0D9488  (brand)
DEEP = (7,  78,  72)     # deep teal at the bottom
GLOW = (45, 212, 191)    # #2DD4BF  soft key-light bloom

SHOTS = [
    ("01-home.png",     "01-see-spend.png",             "SEE",  "WHAT YOU\nREALLY SPEND"),
    ("02-calendar.png", "02-stop-surprise-charges.png", "STOP", "SURPRISE\nCHARGES"),
    ("03-assistant.png","03-ask-assistant.png",         "ASK",  "ABOUT YOUR\nSPENDING"),
]


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def background(W, H):
    """Smooth teal gradient + radial glow + vignette, built small then upscaled."""
    w0, h0 = 132, max(1, round(132 * H / W))
    g = Image.new("RGB", (w0, h0))
    px = g.load()
    cx, cy, cr = 0.5 * w0, 0.30 * h0, 0.85 * h0
    for y in range(h0):
        t = y / (h0 - 1)
        col = lerp(TOP, BASE, t / 0.5) if t < 0.5 else lerp(BASE, DEEP, (t - 0.5) / 0.5)
        for x in range(w0):
            d = (((x - cx) ** 2 + (y - cy) ** 2) ** 0.5) / cr
            glow = max(0.0, 1.0 - d) ** 2 * 0.45
            vig = 1.0 - 0.10 * (((x / w0 - 0.5) ** 2 + (y / h0 - 0.6) ** 2) * 2.2)
            r = min(255, int((col[0] + (GLOW[0] - col[0]) * glow) * vig))
            gg = min(255, int((col[1] + (GLOW[1] - col[1]) * glow) * vig))
            b = min(255, int((col[2] + (GLOW[2] - col[2]) * glow) * vig))
            px[x, y] = (r, gg, b)
    return g.resize((W, H), Image.LANCZOS)


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0], img.size[1]], radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def draw_caption(canvas, hero, sub, W, k):
    d = ImageDraw.Draw(canvas)
    f_hero = ImageFont.truetype(FONT_TTC, round(250 * k), index=COND_BLACK)
    f_sub  = ImageFont.truetype(FONT_TTC, round(150 * k), index=COND_BLACK)
    y = round(150 * k)

    hb = d.textbbox((0, 0), hero, font=f_hero)
    hw, hh = hb[2] - hb[0], hb[3] - hb[1]
    d.text(((W - hw) / 2 - hb[0], y - hb[1]), hero, font=f_hero, fill=(255, 255, 255))
    y += hh + round(34 * k)

    for line in sub.split("\n"):
        lb = d.textbbox((0, 0), line, font=f_sub)
        lw, lh = lb[2] - lb[0], lb[3] - lb[1]
        d.text(((W - lw) / 2 - lb[0], y - lb[1]), line, font=f_sub, fill=(236, 253, 250))
        y += lh + round(16 * k)
    return y


def compose(raw_path, hero, sub, W, H):
    k = W / BASE_W
    canvas = background(W, H).convert("RGBA")
    caption_bottom = draw_caption(canvas, hero, sub, W, k)

    raw = Image.open(raw_path).convert("RGBA")
    dw = int(W * 0.745)
    dh = int(raw.size[1] * (dw / raw.size[0]))   # keep the capture's own aspect — no distortion
    device = rounded(raw.resize((dw, dh), Image.LANCZOS), round(78 * k))

    dx = (W - dw) // 2
    dy = max(int(caption_bottom + 70 * k), round(700 * k))

    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [dx, dy + round(26 * k), dx + dw, dy + dh + round(26 * k)], round(78 * k), fill=(0, 0, 0, 130))
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(round(38 * k))))

    edge = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle(
        [dx - 2, dy - 2, dx + dw + 2, dy + dh + 2], round(80 * k),
        outline=(255, 255, 255, 38), width=max(2, round(3 * k)))
    canvas = Image.alpha_composite(canvas, edge)

    canvas.alpha_composite(device, (dx, dy))
    return canvas.convert("RGB")


def main():
    for W, H, sub in TARGETS:
        out = os.path.join(HERE, sub)
        os.makedirs(out, exist_ok=True)
        for raw_name, out_name, hero, cap in SHOTS:
            img = compose(os.path.join(RAW, raw_name), hero, cap, W, H)
            img.save(os.path.join(out, out_name))
            print("wrote", os.path.join(sub, out_name), f"{W}x{H}")


if __name__ == "__main__":
    main()
