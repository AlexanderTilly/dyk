"""Normalise the Explore category icons.

The artwork arrives as transparent 500x500 PNGs, but the drawing inside each
one occupies a different share of the canvas — the column fills 263px across,
the open book 471. Rendered at the same size they look like different sizes,
which is the sort of thing that reads as sloppy without anyone being able to
say why.

So: trim each to its actual content, then place it back on a square canvas at
the same proportion. After this they can be drawn in one box and the row looks
even. Scripted rather than done by hand so a redrawn icon gets the same
treatment.
"""
import io
import os

from PIL import Image

SRC = "assets/images"
DEST = "assets/images/badges"

# filename stem -> category key used by CategoryBadge
ICONS = {
    "history": "history",
    "leisure": "otium",
    "storiesandlegends": "headline",
    "hotdeals": "hotdeal",
}

# How much of the square the drawing should fill. The badge sits inside a
# circle, so the art has to stay clear of the corners; 0.72 keeps it off the
# ring without leaving it stranded in the middle.
FILL = 0.72
SIZE = 512


def normalise(src_path, dest_path):
    im = Image.open(src_path).convert("RGBA")
    bbox = im.split()[3].getbbox()
    if bbox is None:
        raise SystemExit("%s is empty" % src_path)
    art = im.crop(bbox)

    target = int(SIZE * FILL)
    scale = min(target / art.width, target / art.height)
    art = art.resize(
        (max(1, round(art.width * scale)), max(1, round(art.height * scale))),
        Image.LANCZOS,
    )

    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    canvas.paste(art, ((SIZE - art.width) // 2, (SIZE - art.height) // 2), art)
    canvas.save(dest_path)
    return art.size


for stem, key in ICONS.items():
    src = os.path.join(SRC, "Passim_exploreicons_%s.png" % stem)
    dest = os.path.join(DEST, "explore_%s.png" % key)
    size = normalise(src, dest)
    print("%-20s -> %s  (art %dx%d in %d)" % (stem, dest, size[0], size[1], SIZE))


# ---------------------------------------------------------------------------
# Map pins
# ---------------------------------------------------------------------------
# The same art again, but with the navy ground and a thin amber ring baked in.
# Mapbox takes a finished PNG — it cannot compose a disc behind a transparent
# image the way the Flutter widget does — so the pin has to arrive complete.
#
# The ring matters more here than on Explore: a pin sits on streets, parks and
# water, and without an edge the navy disc dissolves into a dark basemap.
from PIL import ImageDraw

PIN_SIZE = 256
PIN_FILL = 0.56  # art share; smaller than the badge because of the ring
RING = 10
NAVY = (7, 26, 47, 255)
AMBER = (255, 194, 26, 255)


def make_pin(src_path, dest_path):
    im = Image.open(src_path).convert("RGBA")
    bbox = im.split()[3].getbbox()
    art = im.crop(bbox)

    target = int(PIN_SIZE * PIN_FILL)
    scale = min(target / art.width, target / art.height)
    art = art.resize(
        (max(1, round(art.width * scale)), max(1, round(art.height * scale))),
        Image.LANCZOS,
    )

    pin = Image.new("RGBA", (PIN_SIZE, PIN_SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(pin)
    d.ellipse([0, 0, PIN_SIZE - 1, PIN_SIZE - 1], fill=NAVY,
              outline=AMBER, width=RING)
    pin.paste(art, ((PIN_SIZE - art.width) // 2, (PIN_SIZE - art.height) // 2),
              art)
    pin.save(dest_path)
    return art.size


for stem, key in ICONS.items():
    src = os.path.join(SRC, "Passim_exploreicons_%s.png" % stem)
    dest = os.path.join(DEST, "pin_%s.png" % key)
    size = make_pin(src, dest)
    print("%-20s -> %s  (art %dx%d in %d)" % (stem, dest, size[0], size[1], PIN_SIZE))
