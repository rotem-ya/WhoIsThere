#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Build Google Play Console asset package for "מה בתמונה" (WhoIsThere)."""
import os, re, shutil, zipfile
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

ROOT = "/home/user/WhoIsThere"
OUT = os.path.join(ROOT, "google-play-assets")
LISTING = os.path.join(ROOT, "docs", "GOOGLE_PLAY_LISTING.md")
ICON_SRC = os.path.join(ROOT, "docs", "store", "play-icon-512.png")
IMG_DIR = os.path.join(ROOT, "assets", "game_places", "images")

FONT_BOLD = "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf"
FONT_REG = "/usr/share/fonts/truetype/freefont/FreeSans.ttf"
PRIVACY_URL = "https://rotem-ya.github.io/WhoIsThere/privacy.html"

# ───────────────────────── helpers ─────────────────────────
def F(size, bold=True):
    return ImageFont.truetype(FONT_BOLD if bold else FONT_REG, size)

def he(draw, xy, text, font, fill, anchor="mm"):
    draw.text(xy, text, font=font, fill=fill, anchor=anchor, direction="rtl")

def he_size(draw, text, font, anchor="mm"):
    b = draw.textbbox((0, 0), text, font=font, anchor=anchor, direction="rtl")
    return b[2] - b[0], b[3] - b[1]

def vgradient(w, h, top, bottom):
    base = Image.new("RGB", (w, h), top)
    top_r, top_g, top_b = top
    bot_r, bot_g, bot_b = bottom
    grad = Image.new("L", (1, h))
    for y in range(h):
        grad.putpixel((0, y), int(255 * y / max(1, h - 1)))
    grad = grad.resize((w, h))
    overlay = Image.new("RGB", (w, h), bottom)
    base.paste(overlay, (0, 0), grad)
    return base

def rounded(size, radius, fill):
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=fill)
    return img

def cover_crop(img, tw, th):
    w, h = img.size
    scale = max(tw / w, th / h)
    nw, nh = int(w * scale + 0.5), int(h * scale + 0.5)
    img = img.resize((nw, nh), Image.LANCZOS)
    left = (nw - tw) // 2
    top = (nh - th) // 2
    return img.crop((left, top, left + tw, top + th))

# ───────────────────────── 1. structure ─────────────────────────
if os.path.exists(OUT):
    shutil.rmtree(OUT)
TEXTS = os.path.join(OUT, "texts")
GFX = os.path.join(OUT, "graphics")
SHOTS = os.path.join(GFX, "screenshots")
for d in (TEXTS, GFX, SHOTS):
    os.makedirs(d, exist_ok=True)

# ───────────────────────── 2. extract texts ─────────────────────────
md = open(LISTING, encoding="utf-8").read()
fences = re.findall(r"```\n(.*?)\n```", md, re.DOTALL)
title = fences[0].strip()
short = fences[1].strip()
full = fences[2].strip()

assert len(title) <= 30, f"title too long: {len(title)}"
assert len(short) <= 80, f"short too long: {len(short)}"
assert len(full) <= 4000, f"full too long: {len(full)}"

def w(name, content):
    with open(os.path.join(TEXTS, name), "w", encoding="utf-8") as f:
        f.write(content)

w("app_title.txt", title + "\n")
w("short_description.txt", short + "\n")
w("full_description.txt", full + "\n")
w("privacy_policy_url.txt", PRIVACY_URL + "\n")
print(f"texts: title={len(title)} short={len(short)} full={len(full)} chars")

# ───────────────────────── 3. icon ─────────────────────────
icon = Image.open(ICON_SRC).convert("RGBA")
if icon.size != (512, 512):
    icon = icon.resize((512, 512), Image.LANCZOS)
icon_path = os.path.join(GFX, "icon_512x512.png")
icon.save(icon_path, "PNG")
assert Image.open(icon_path).size == (512, 512)
print("icon:", Image.open(icon_path).size, "bytes", os.path.getsize(icon_path))

# ───────────────────────── 4. feature graphic 1024x500 ─────────────────────────
FW, FH = 1024, 500
fg = vgradient(FW, FH, (12, 22, 64), (30, 60, 140)).convert("RGBA")
d = ImageDraw.Draw(fg)

# subtle tile motif on the right
import random
random.seed(7)
tile = 56
motif = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
md_ = ImageDraw.Draw(motif)
for ty in range(0, FH, tile + 8):
    for tx in range(FW - 360, FW, tile + 8):
        a = random.choice([0, 18, 28, 40])
        md_.rounded_rectangle([tx, ty, tx + tile, ty + tile], radius=10,
                              fill=(120, 170, 255, a))
fg = Image.alpha_composite(fg, motif)
d = ImageDraw.Draw(fg)

# app icon badge on the right
badge = icon.resize((300, 300), Image.LANCZOS)
shadow = Image.new("RGBA", fg.size, (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow)
sd.rounded_rectangle([FW - 360, FH // 2 - 158, FW - 60, FH // 2 + 142],
                     radius=60, fill=(0, 0, 0, 120))
shadow = shadow.filter(ImageFilter.GaussianBlur(14))
fg = Image.alpha_composite(fg, shadow)
mask = rounded((300, 300), 60, (255, 255, 255, 255)).split()[3]
fg.paste(badge, (FW - 360, FH // 2 - 150), mask)
d = ImageDraw.Draw(fg)

# texts on the left (own region, clear of the icon badge on the right)
cx = 400
he(d, (cx, 165), title, F(82), (255, 255, 255), anchor="mm")
he(d, (cx, 275), "חשפו את התמונה,", F(38, False), (200, 220, 255), anchor="mm")
he(d, (cx, 328), "נחשו את המקום!", F(38, False), (200, 220, 255), anchor="mm")
# gold accent line
d.rounded_rectangle([cx - 130, 378, cx + 130, 386], radius=4, fill=(255, 200, 70))

fg_path = os.path.join(GFX, "feature_graphic_1024x500.png")
fg.convert("RGB").save(fg_path, "PNG")
assert Image.open(fg_path).size == (1024, 500)
print("feature graphic:", Image.open(fg_path).size)

# ───────────────────────── 5. phone screenshots 1080x1920 ─────────────────────────
SW, SH = 1080, 1920
specs = [
    ("western_wall.jpg", "נחשו את המקום!", "המשבצות נחשפות אחת-אחת", 0.45),
    ("dead_sea.jpg", "מי שמזהה ראשון — מנצח!", "ככל שתנחשו מוקדם, תרוויחו יותר", 0.20),
    ("masada.jpg", "הרוויחו מטבעות וטפסו בדרגות", "7 דרגות: מ\"עיוור\" ועד \"אגדה\"", 0.0),
    ("ramon_crater.jpg", "עשרות מקומות מרהיבים", "מהארץ ומכל העולם", 0.0),
]

def find_img(name):
    p = os.path.join(IMG_DIR, name)
    if os.path.exists(p):
        return p
    stem = os.path.splitext(name)[0]
    for ext in (".jpg", ".png", ".jpeg"):
        q = os.path.join(IMG_DIR, stem + ext)
        if os.path.exists(q):
            return q
    return None

for i, (img_name, cap, sub, hide_frac) in enumerate(specs, 1):
    canvas = vgradient(SW, SH, (10, 18, 52), (26, 48, 110)).convert("RGBA")
    d = ImageDraw.Draw(canvas)

    # top caption
    he(d, (SW // 2, 175), cap, F(66), (255, 255, 255), anchor="mm")
    he(d, (SW // 2, 255), sub, F(38, False), (190, 210, 255), anchor="mm")

    # phone frame geometry
    pw, ph = 760, 1340
    px = (SW - pw) // 2
    py = 360
    # frame shadow
    sh = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([px - 6, py - 6, px + pw + 6, py + ph + 6],
                                         radius=80, fill=(0, 0, 0, 150))
    sh = sh.filter(ImageFilter.GaussianBlur(22))
    canvas = Image.alpha_composite(canvas, sh)
    d = ImageDraw.Draw(canvas)
    # phone body (bezel)
    d.rounded_rectangle([px, py, px + pw, py + ph], radius=76, fill=(18, 18, 22, 255))
    # screen area
    bez = 22
    sx, sy = px + bez, py + bez
    sxw, syh = pw - 2 * bez, ph - 2 * bez

    # game image inside screen (cover-cropped)
    src = find_img(img_name)
    photo = Image.open(src).convert("RGB")
    photo = cover_crop(photo, sxw, syh)
    screen_mask = rounded((sxw, syh), 58, (255, 255, 255, 255)).split()[3]
    canvas.paste(photo, (sx, sy), screen_mask)
    d = ImageDraw.Draw(canvas)

    # reveal-grid overlay: hide a fraction of tiles to show the mechanic
    if hide_frac > 0:
        cols, rows = 6, 10
        cw, ch = sxw / cols, syh / rows
        random.seed(100 + i)
        cells = [(r, c) for r in range(rows) for c in range(cols)]
        random.shuffle(cells)
        nhide = int(len(cells) * hide_frac)
        grid = Image.new("RGBA", (sxw, syh), (0, 0, 0, 0))
        gd = ImageDraw.Draw(grid)
        for (r, c) in cells[:nhide]:
            x0, y0 = c * cw, r * ch
            gd.rounded_rectangle([x0 + 4, y0 + 4, x0 + cw - 4, y0 + ch - 4],
                                 radius=10, fill=(13, 20, 45, 235))
        # thin grid lines for the rest
        for r in range(rows + 1):
            gd.line([(0, r * ch), (sxw, r * ch)], fill=(255, 255, 255, 30), width=2)
        for c in range(cols + 1):
            gd.line([(c * cw, 0), (c * cw, syh)], fill=(255, 255, 255, 30), width=2)
        # Use the grid's OWN alpha (clipped to the rounded screen) as the paste
        # mask — pasting with the opaque screen_mask would stamp the grid's
        # transparent areas as solid black over the photo.
        grid.putalpha(ImageChops.multiply(grid.split()[3], screen_mask))
        canvas.paste(grid, (sx, sy), grid)
        d = ImageDraw.Draw(canvas)

    # notch
    d.rounded_rectangle([SW // 2 - 70, py + 14, SW // 2 + 70, py + 38],
                        radius=12, fill=(8, 8, 10, 255))

    # in-screen coin HUD chip (drawn gold coin — emoji glyphs aren't in FreeSans)
    def coin_chip(cx0, cy0, value, bg):
        cf = F(34)
        tw, th = he_size(d, value, cf)
        coin_d = 38
        pad = 20
        gap = 12
        chip_w = pad + coin_d + gap + tw + pad
        chip_h = max(coin_d, th) + 22
        d.rounded_rectangle([cx0, cy0, cx0 + chip_w, cy0 + chip_h], radius=26, fill=bg)
        cym = cy0 + chip_h // 2
        # gold coin
        cx_coin = cx0 + pad
        d.ellipse([cx_coin, cym - coin_d // 2, cx_coin + coin_d, cym + coin_d // 2],
                  fill=(255, 196, 60), outline=(208, 150, 20), width=3)
        d.ellipse([cx_coin + 9, cym - coin_d // 2 + 9,
                   cx_coin + coin_d - 9, cym + coin_d // 2 - 9],
                  outline=(208, 150, 20), width=2)
        d.text((cx0 + pad + coin_d + gap, cym), value, font=cf,
               fill=(255, 255, 255), anchor="lm")
    coin_chip(sx + 20, sy + 24, "320", (20, 30, 70, 235))
    # guess button near bottom of screen
    bw2, bh2 = 360, 90
    bx2 = sx + (sxw - bw2) // 2
    by2 = sy + syh - bh2 - 30
    d.rounded_rectangle([bx2, by2, bx2 + bw2, by2 + bh2], radius=45, fill=(255, 184, 28, 255))
    he(d, (bx2 + bw2 // 2, by2 + bh2 // 2), "נחש עכשיו!", F(42), (40, 25, 0), anchor="mm")

    # bottom tagline
    he(d, (SW // 2, SH - 110), "מה בתמונה?", F(52), (255, 255, 255), anchor="mm")

    out = os.path.join(SHOTS, f"phone_screenshot_{i}.png")
    canvas.convert("RGB").save(out, "PNG")
    assert Image.open(out).size == (1080, 1920)
    print(f"screenshot {i}: {Image.open(out).size}  ({img_name})")

# ───────────────────────── 6. README ─────────────────────────
readme = f"""מדריך העלאה ל-Google Play Console — "מה בתמונה?" (WhoIsThere)
==============================================================

תוכן החבילה
-----------
google-play-assets/
├── texts/
│   ├── app_title.txt            ← שם האפליקציה ({len(title)}/30 תווים)
│   ├── short_description.txt    ← תיאור קצר ({len(short)}/80 תווים)
│   ├── full_description.txt     ← תיאור מלא ({len(full)}/4000 תווים)
│   └── privacy_policy_url.txt   ← קישור מדיניות פרטיות
├── graphics/
│   ├── icon_512x512.png         ← אייקון 512×512 PNG (32-bit)
│   ├── feature_graphic_1024x500.png ← Feature graphic 1024×500 PNG
│   └── screenshots/
│       ├── phone_screenshot_1.png   (1080×1920)
│       ├── phone_screenshot_2.png   (1080×1920)
│       ├── phone_screenshot_3.png   (1080×1920)
│       └── phone_screenshot_4.png   (1080×1920)
└── README.txt                   ← הקובץ הזה

איפה להדביק כל פריט ב-Play Console
----------------------------------
Play Console → בחר את האפליקציה → Grow → Store presence → **Main store listing**

1) App name (שם האפליקציה)
   • הדבק את התוכן מ-texts/app_title.txt
   • מגבלה: 30 תווים.

2) Short description (תיאור קצר)
   • הדבק את התוכן מ-texts/short_description.txt
   • מגבלה: 80 תווים.

3) Full description (תיאור מלא)
   • הדבק את התוכן מ-texts/full_description.txt
   • מגבלה: 4000 תווים.

4) App icon (אייקון)
   • העלה graphics/icon_512x512.png
   • דרישה מדויקת: 512×512 פיקסל, PNG, עד 1MB.

5) Feature graphic (גרפיקת נושא)
   • העלה graphics/feature_graphic_1024x500.png
   • דרישה מדויקת: 1024×500 פיקסל, PNG/JPG.

6) Phone screenshots (צילומי מסך לטלפון)
   • העלה את 4 הקבצים מ-graphics/screenshots/
   • דרישה: לפחות 2 צילומים, 1080×1920 פיקסל (פורטרט). כאן יש 4.
   • הערה: אלה צילומי מוקאפ שיווקיים. מומלץ בהמשך להחליף/להוסיף
     צילומי מסך אמיתיים מהמכשיר (מסך בית, משחק, ניצחון, חנות, מפה).

7) Privacy policy URL (מדיניות פרטיות)
   • App content → Privacy policy → הדבק את הקישור מ-
     texts/privacy_policy_url.txt :
     {PRIVACY_URL}
   • דרוש פעם אחת: הפעל GitHub Pages (Settings → Pages → Branch: main, Folder: /docs).

תזכורת מידות מדויקות
--------------------
• אייקון:           512 × 512 px  (PNG, < 1MB)
• Feature graphic:  1024 × 500 px (PNG)
• צילומי מסך טלפון:  1080 × 1920 px (PNG, פורטרט) — לפחות 2

מידע משלים להגשה (מתוך GOOGLE_PLAY_LISTING.md)
----------------------------------------------
• קטגוריה: משחקים → חידון/טריוויה (Trivia)
• מחיר: חינם (עם פרסומות — AdMob)
• Content rating: מלא שאלון IARC (ללא אלימות/מין/שפה/סמים; יש פרסומות).
• Data safety: נאספים שם, אימייל, User IDs, App interactions, Advertising ID.
• Target audience: 13+ (לא מיועד לילדים).
• אימייל תמיכה: askthekids.app@gmail.com
"""
with open(os.path.join(OUT, "README.txt"), "w", encoding="utf-8") as f:
    f.write(readme)
print("README.txt written")

# ───────────────────────── 7. zip ─────────────────────────
zip_path = os.path.join(ROOT, "google-play-assets.zip")
if os.path.exists(zip_path):
    os.remove(zip_path)
with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
    for base, _, files in os.walk(OUT):
        for fn in files:
            fp = os.path.join(base, fn)
            arc = os.path.relpath(fp, ROOT)
            z.write(fp, arc)
print("ZIP:", zip_path, os.path.getsize(zip_path), "bytes")
