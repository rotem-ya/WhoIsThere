#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Derive App Store screenshot sizes from the 1080x1920 Play screenshots.

iPhone 6.7" (1290x2796) and 6.5" (1242x2688) are taller (≈19.5:9) than the
source (9:16), so we scale each source to the target HEIGHT and center-crop the
width. This preserves all vertical content (top caption + bottom tagline) and
only trims the navy side margins — no distortion, no letterbox bars.
"""
import os
from PIL import Image

ROOT = "/home/user/WhoIsThere"
SRC = os.path.join(ROOT, "google-play-assets", "graphics", "screenshots")
OUT = os.path.join(ROOT, "google-play-assets", "graphics", "screenshots-apple")

TARGETS = [
    ("iphone_6_9_1320x2868", 1320, 2868),
    ("iphone_6_7_1290x2796", 1290, 2796),
    ("iphone_6_5_1242x2688", 1242, 2688),
]


def cover_to(img, tw, th):
    w, h = img.size
    scale = max(tw / w, th / h)
    nw, nh = int(w * scale + 0.5), int(h * scale + 0.5)
    img = img.resize((nw, nh), Image.LANCZOS)
    left = (nw - tw) // 2
    top = (nh - th) // 2
    return img.crop((left, top, left + tw, top + th))


srcs = sorted(f for f in os.listdir(SRC) if f.startswith("phone_screenshot_") and f.endswith(".png"))
for folder, tw, th in TARGETS:
    d = os.path.join(OUT, folder)
    os.makedirs(d, exist_ok=True)
    for f in srcs:
        im = Image.open(os.path.join(SRC, f)).convert("RGB")
        out = cover_to(im, tw, th)
        assert out.size == (tw, th)
        out.save(os.path.join(d, f), "PNG")
    print(f"{folder}: {len(srcs)} screenshots @ {tw}x{th}")
print("done")
