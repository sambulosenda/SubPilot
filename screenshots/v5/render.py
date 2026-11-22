#!/usr/bin/env python3
"""SubHelm App Store screenshots v5 — 1290x2796 (6.9" well)."""
import os, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1290, 2796
SRC = "/Users/sambulosenda/Documents/indie/Rubradar/sim-shots/v4"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "v5")
os.makedirs(OUT, exist_ok=True)

F_HEAD = "/Library/Fonts/SF-Pro-Display-Bold.otf"
F_HEAVY = "/Library/Fonts/SF-Pro-Display-Heavy.otf"
F_SUB = "/Library/Fonts/SF-Pro-Display-Medium.otf"
F_SEMI = "/Library/Fonts/SF-Pro-Display-Semibold.otf"

INK = (14, 20, 28)
TEAL = (13, 148, 136)
TEAL_LT = (45, 212, 191)
MUTED = (96, 108, 122)

def font(path, size):
    return ImageFont.truetype(path, size)

def vgrad(size, top, bottom):
    w, h = size
    g = Image.new("RGB", (1, h))
    d = ImageDraw.Draw(g)
    for y in range(h):
        t = y / max(1, h - 1)
        d.point((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return g.resize((w, h), Image.BICUBIC)

def track_width(d, text, f, tracking):
    return sum(d.textlength(c, font=f) for c in text) + tracking * (len(text) - 1)

def draw_tracked(d, xy, text, f, fill, tracking=0.0):
    x, y = xy
    for c in text:
        d.text((x, y), c, font=f, fill=fill)
        x += d.textlength(c, font=f) + tracking

def draw_headline(img, lines, y, size, color, accent=None, tracking=-2.0, leading=1.02):
    """lines: list of str; words wrapped in *stars* get accent colour."""
    d = ImageDraw.Draw(img)
    f = font(F_HEAD, size)
    lh = int(size * leading)
    for i, line in enumerate(lines):
        plain = line.replace("*", "")
        tw = track_width(d, plain, f, tracking)
        x = (W - tw) / 2
        cy = y + i * lh
        # split on accent markers, preserving order
        parts, buf, acc = [], "", False
        for ch in line:
            if ch == "*":
                if buf:
                    parts.append((buf, acc)); buf = ""
                acc = not acc
            else:
                buf += ch
        if buf:
            parts.append((buf, acc))
        for txt, is_acc in parts:
            col = (accent or TEAL) if is_acc else color
            draw_tracked(d, (x, cy), txt, f, col, tracking)
            x += track_width(d, txt, f, tracking) + tracking
    return y + len(lines) * lh

def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return m

def device(shot_path, width, crop=None, bezel=14):
    """Return RGBA phone image (screen + bezel + rounded corners)."""
    im = Image.open(shot_path).convert("RGB")
    if crop:
        im = im.crop(crop)
    h = int(im.height * width / im.width)
    im = im.resize((width, h), Image.LANCZOS)
    r = int(width * 0.093)
    im.putalpha(rounded_mask(im.size, r))

    bw, bh = width + bezel * 2, h + bezel * 2
    frame = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    fd = ImageDraw.Draw(frame)
    fd.rounded_rectangle([0, 0, bw - 1, bh - 1], radius=r + bezel, fill=(26, 28, 32, 255))
    fd.rounded_rectangle([0, 0, bw - 1, bh - 1], radius=r + bezel, outline=(88, 94, 104, 255), width=3)
    frame.paste(im, (bezel, bezel), im)
    return frame

def paste_shadow(bg, ph, x, y, blur=44, alpha=110, dy=26):
    sh = Image.new("RGBA", bg.size, (0, 0, 0, 0))
    solid = Image.new("RGBA", ph.size, (0, 0, 0, alpha))
    sh.paste(solid, (x, y + dy), ph.split()[3])
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    bg.alpha_composite(sh)
    bg.alpha_composite(ph, (x, y))

def pill(d, cx, y, text, f, fg, bg_col, padx=52, pady=26, radius=None):
    tw = d.textlength(text, font=f)
    a = d.textbbox((0, 0), text, font=f)
    th = a[3] - a[1]
    w = tw + padx * 2
    h = th + pady * 2
    x0, y0 = cx - w / 2, y
    r = radius if radius is not None else h / 2
    d.rounded_rectangle([x0, y0, x0 + w, y0 + h], radius=r, fill=bg_col)
    d.text((cx - tw / 2, y0 + pady - a[1]), text, font=f, fill=fg)
    return y0 + h

# ---------------------------------------------------------------- slots

LIGHT_TOP, LIGHT_BOT = (244, 246, 251), (223, 229, 241)
TEAL_TOP, TEAL_BOT = (18, 160, 146), (7, 78, 72)


def light_bg():
    return vgrad((W, H), LIGHT_TOP, LIGHT_BOT).convert("RGBA")

def teal_bg():
    return vgrad((W, H), TEAL_TOP, TEAL_BOT).convert("RGBA")


def slot(name, bg, head_lines, sub, shot, *, dark_text=True, crop=None,
         phone_w=950, phone_y=760, chips=None, pills=None, pills_y=None,
         head_y=170, head_size=116):
    img = bg
    color = INK if dark_text else (255, 255, 255)
    acc = TEAL if dark_text else (167, 243, 208)
    y = draw_headline(img, head_lines, head_y, head_size, color, accent=acc)
    d = ImageDraw.Draw(img)
    if sub:
        f = font(F_SEMI, 50)
        tw = d.textlength(sub, font=f)
        d.text(((W - tw) / 2, y + 34), sub, font=f,
               fill=MUTED if dark_text else (200, 240, 232))
    if chips:
        f = font(F_SEMI, 44)
        gap = 22
        widths = [d.textlength(c, font=f) + 76 for c in chips]
        total = sum(widths) + gap * (len(chips) - 1)
        x = (W - total) / 2
        cy = y + 130
        for c, cw in zip(chips, widths):
            d.rounded_rectangle([x, cy, x + cw, cy + 84], radius=42,
                                fill=(255, 255, 255, 235) if dark_text else (255, 255, 255, 46))
            tw = d.textlength(c, font=f)
            d.text((x + (cw - tw) / 2, cy + 18), c, font=f,
                   fill=TEAL if dark_text else (255, 255, 255))
            x += cw + gap
    if pills:
        f = font(F_SEMI, 60)
        py = pills_y if pills_y is not None else y + 190
        ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
        od = ImageDraw.Draw(ov)
        rows = []
        for p in pills:
            tw = d.textlength(p, font=f)
            pw = max(tw + 160, 760)
            x0 = (W - pw) / 2
            od.rounded_rectangle([x0, py, x0 + pw, py + 132], radius=66,
                                 fill=(255, 255, 255, 38) if not dark_text else (255, 255, 255, 240),
                                 outline=(255, 255, 255, 120) if not dark_text else (13, 148, 136, 70),
                                 width=3)
            rows.append((tw, py))
            py += 158
        img.alpha_composite(ov)
        d = ImageDraw.Draw(img)
        for p, (tw, ry) in zip(pills, rows):
            d.text(((W - tw) / 2, ry + 30), p, font=f,
                   fill=(255, 255, 255) if not dark_text else TEAL)
    if shot:
        ph = device(shot, phone_w, crop=crop)
        paste_shadow(img, ph, (W - ph.width) // 2, phone_y)
    img.convert("RGB").save(os.path.join(OUT, name), quality=95)
    print("wrote", name, img.size)


if __name__ == "__main__":
    NEW = "/Users/sambulosenda/Documents/indie/Rubradar/sim-shots/v5"
    home = f"{NEW}/home.png"
    lock = f"{NEW}/lock.png"
    cal = f"{NEW}/calendar.png"
    add = f"{NEW}/add.png"

    slot("01-hook.png", light_bg(),
         ["Stop paying for", "subs you *forgot*"],
         "Every subscription, one running total",
         home, chips=["Free", "No account", "No bank login"],
         phone_y=830)

    # Phone runs larger here and bleeds off the bottom: iOS 26 anchors banners to
    # the bottom of the Lock Screen, so the notification only reads at thumbnail
    # size if the device is scaled up.
    slot("02-warning.png", light_bg(),
         ["A warning before", "*every* charge"],
         "Cancel free trials before they bill you",
         lock, phone_w=1160, phone_y=600)

    slot("03-private.png", teal_bg(),
         ["No bank login.", "*Ever.*"],
         "Your data never leaves your iPhone and iCloud",
         home, dark_text=False,
         pills=["On-device only", "No account", "Private iCloud sync"],
         pills_y=760, phone_y=1480)

    slot("04-calendar.png", light_bg(),
         ["See the *month*", "ahead"],
         "Renewals on a calendar, with totals",
         cal)

    slot("05-add.png", light_bg(),
         ["Add a sub in", "*seconds*"],
         "200+ services, or scan a receipt",
         add)
