#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Mark up the YouTube Studio screenshots used in guide section 6.

    python3 docs/guide/annotate.py [--images DIR]

Reads yt-key-row.png and yt-key-dropdown.png from docs/guide/images/ and
writes the -annotated.png beside them, so a fresh screenshot can be dropped
in and the markings redrawn instead of hand-edited.

The coordinates below are in the source images' own pixels and were read off
a grid overlay. YouTube moves this UI about once a year: when it moves, take
the new screenshots at the same window size, re-measure, and change only the
constants at the top.

Needs Pillow:  python3 -m pip install pillow
"""
from __future__ import annotations

import argparse
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
IMAGES = os.path.join(HERE, "images")

RED = (255, 69, 58)      # the don't-touch marks
GREEN = (48, 209, 88)    # the do-this marks
SHADOW = (0, 0, 0)       # text outline, for contrast on the dark UI

BOLD_SANS = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

# --- yt-key-row.png: the control room's top row ------------------------------
# Cropped to the key row with a little of the panel around it, then doubled so
# the strokes and labels stay crisp once reportlab scales the page down.
ROW_CROP = (710, 148, 1105, 275)
ROW_SCALE = 2
ROW_REFRESH = (628, 84)   # circular arrow, in the doubled crop
ROW_COPY = (706, 84)      # the two overlapping squares
ROW_X_ARM = 26            # half-width of the red X
ROW_CIRCLE_R = 34         # radius of the green circle
ROW_LABEL_PX = 40         # >= 28px, and 40 keeps it legible at page width

# --- yt-key-dropdown.png: the open Key menu ---------------------------------
DROP_CROP = (89, 50, 404, 252)      # the Key box and its open menu, nothing else
DROP_KEEP = (92, 202, 400, 250)     # box around "Default stream key (RTMP, Variable)"
DROP_STRIKE = [                     # struck through the middle of each label
    ((100, 130), (267, 130)),       # "Create new stream key"
    ((100, 178), (253, 178)),       # "Manage stream keys"
]

# Anything private that has to be blurred before these ship: (x0, y0, x1, y1)
# per file, in that file's own pixels. Both current screenshots were checked
# and show no key, no address and no account name inside the regions used, so
# there is nothing to blur; a future screenshot that does gets its box here.
BLUR_REGIONS: dict[str, list[tuple[int, int, int, int]]] = {
    "yt-key-row.png": [],
    "yt-key-dropdown.png": [],
}


def load(images: str, name: str) -> Image.Image:
    im = Image.open(os.path.join(images, name)).convert("RGB")
    for box in BLUR_REGIONS.get(name, []):
        patch = im.crop(box).resize((8, 8)).resize(
            (box[2] - box[0], box[3] - box[1]), Image.NEAREST)
        im.paste(patch, box)
    return im


def font(size_px: int) -> ImageFont.FreeTypeFont:
    try:
        return ImageFont.truetype(BOLD_SANS, size_px)
    except OSError:
        return ImageFont.load_default(size_px)


def label(draw: ImageDraw.ImageDraw, text: str, centre, colour, size_px):
    """Centred, outlined so it reads against whatever is behind it."""
    draw.text(centre, text, font=font(size_px), fill=colour, anchor="mm",
              stroke_width=3, stroke_fill=SHADOW)


def annotate_row(images: str) -> str:
    im = load(images, "yt-key-row.png").crop(ROW_CROP)
    im = im.resize((im.width * ROW_SCALE, im.height * ROW_SCALE), Image.LANCZOS)
    d = ImageDraw.Draw(im)

    x, y = ROW_REFRESH
    a = ROW_X_ARM
    d.line([(x - a, y - a), (x + a, y + a)], fill=RED, width=7)
    d.line([(x - a, y + a), (x + a, y - a)], fill=RED, width=7)

    cx, cy = ROW_COPY
    r = ROW_CIRCLE_R
    d.ellipse([(cx - r, cy - r), (cx + r, cy + r)], outline=GREEN, width=6)

    # Leaders, so each label is unmistakably about one icon.
    d.line([(558, 186), (x - 4, y + a + 6)], fill=RED, width=4)
    d.line([(cx, 168), (cx, cy + r + 4)], fill=GREEN, width=4)

    label(d, "Never click", (450, 196), RED, ROW_LABEL_PX)
    label(d, "Copy", (cx, 196), GREEN, ROW_LABEL_PX)

    out = os.path.join(images, "yt-key-row-annotated.png")
    im.save(out)
    return out


def annotate_dropdown(images: str) -> str:
    im = load(images, "yt-key-dropdown.png")
    d = ImageDraw.Draw(im)

    d.rectangle(DROP_KEEP, outline=GREEN, width=4)
    for start, end in DROP_STRIKE:
        d.line([start, end], fill=RED, width=5)

    # Cropped last, so every coordinate above is read off the source image.
    im = im.crop(DROP_CROP)

    out = os.path.join(images, "yt-key-dropdown-annotated.png")
    im.save(out)
    return out


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--images", default=IMAGES,
                    help="folder holding the screenshots (default: %s)" % IMAGES)
    args = ap.parse_args(argv)

    for path in (annotate_row(args.images), annotate_dropdown(args.images)):
        print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
