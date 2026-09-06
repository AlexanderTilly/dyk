"""One-off preparation of the light-mode assets.

Kept in the repo rather than run ad hoc so the crops are reproducible: the
wordmark files are derived, and if the logo is ever redrawn they have to be
regenerated the same way.
"""
from PIL import Image

SRC_DARK = "assets/images/passim_logo.png"
SRC_LIGHT = "design/Passim_logo_bluetext.png"
SRC_BG = "design/Passim_light_back.png"


def split_row(path):
    """The empty band between the pin and the wordmark, as a y coordinate."""
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    px = im.load()
    rows = [any(px[x, y][3] > 10 for x in range(0, w, 2)) for y in range(h)]
    gaps, start = [], None
    for y, filled in enumerate(rows):
        if not filled and start is None:
            start = y
        if filled and start is not None:
            if y - start > 3:
                gaps.append((start, y))
            start = None
    # The gap that separates the pin from the wordmark is the last one that
    # still has content below it.
    top, bottom = gaps[-1]
    return (top + bottom) // 2


def crop_wordmark(src, dest):
    im = Image.open(src).convert("RGBA")
    y = split_row(src)
    im.crop((0, y, im.width, im.height)).save(dest)
    print("%s -> %s (klipp vid y=%d)" % (src, dest, y))


# Full logo, blue text, for light backgrounds.
Image.open(SRC_LIGHT).convert("RGBA").save("assets/images/passim_logo_light.png")
print("%s -> assets/images/passim_logo_light.png" % SRC_LIGHT)

crop_wordmark(SRC_DARK, "assets/images/passim_wordmark.png")
crop_wordmark(SRC_LIGHT, "assets/images/passim_wordmark_light.png")

# The artwork. JPEG to match landing_background.jpg and keep the APK down;
# it is a photographic backdrop with no transparency.
bg = Image.open(SRC_BG).convert("RGB")
bg.save("assets/images/landing_background_light.jpg", quality=88, optimize=True)
print("%s -> assets/images/landing_background_light.jpg %s" % (SRC_BG, bg.size))
