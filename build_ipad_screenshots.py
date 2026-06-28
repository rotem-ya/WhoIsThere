#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Derive iPad screenshots from the 1080x1920 phone marketing shots.

App Store Connect requires 13" iPad screenshots when the build supports iPad
(Flutter apps are universal). iPad is much wider (3:4), so we place the phone
shot centered on a navy canvas. The canvas uses the SAME vertical gradient as
the phone shots, scaled to the same height, so the side fill blends seamlessly
(no visible seam) — and no content is cropped.

Sizes: 13" iPad = 2064x2752, 12.9" iPad = 2048x2732 (both accepted by ASC).
"""
import os
from PIL import Image

ROOT = "/home/user/WhoIsThere"
SRC = os.path.join(ROOT, "google-play-assets", "graphics", "screenshots")
OUT = os.path.join(ROOT, "google-play-assets", "graphics", "screenshots-apple")

# Same gradient the phone shots use (build_play_assets.vgradient top->bottom).
TOP = (10, 18, 52)
BOTTOM = (26, 48, 110)

TARGETS = [
    ("ipad_13_2064x2752", 2064, 2752),
    ("ipad_12_9_2048x2732", 2048, 2732),
]


def vgradient(w, h, top, bottom):
    base = Image.new("RGB", (w, h), top)
    grad = Image.new("L", (1, h))
    for y in range(h):
        grad.putpixel((0, y), int(255 * y / max(1, h - 1)))
    grad = grad.resize((w, h))
    base.paste(Image.new("RGB", (w, h), bottom), (0, 0), grad)
    return base


srcs = sorted(f for f in os.listdir(SRC)
              if f.startswith("phone_screenshot_") and f.endswith(".png"))
for folder, tw, th in TARGETS:
    d = os.path.join(OUT, folder)
    os.makedirs(d, exist_ok=True)
    for f in srcs:
        im = Image.open(os.path.join(SRC, f)).convert("RGB")
        # Scale to the FULL canvas height; width ends up < canvas width.
        scale = th / im.height
        nw, nh = int(im.width * scale + 0.5), th
        im = im.resize((nw, nh), Image.LANCZOS)
        canvas = vgradient(tw, th, TOP, BOTTOM)
        canvas.paste(im, ((tw - nw) // 2, 0))  # centered; gradient blends sides
        canvas.save(os.path.join(d, f), "PNG")
    print(f"{folder}: {len(srcs)} screenshots @ {tw}x{th}")
print("done")
