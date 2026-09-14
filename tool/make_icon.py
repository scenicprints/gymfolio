"""Draw the GymFolio launcher icon.

    python tool/make_icon.py
    dart run flutter_launcher_icons      (after tool/prepare_android.sh)

The mark is a barbell with one blue plate and one orange plate — the same two
colours the app uses for left and right everywhere else, so the icon says
"two sides, loaded separately" before you have opened it.

Adaptive icons are 108dp with only the middle 72dp guaranteed visible, and
flutter_launcher_icons scales the foreground into that canvas. So the mark is
drawn at ~62% of the artboard and the script renders _launcher_preview.png
through the real circle and squircle masks — check that file, not icon.png,
because a mark that looks right full-bleed can lose its plates to the crop.
"""

from PIL import Image, ImageDraw
import os

S = 1024
BG = (14, 17, 19, 255)
BAR = (236, 241, 244, 255)
LEFT = (96, 165, 250, 255)
RIGHT = (240, 168, 104, 255)
COLLAR = (140, 154, 164, 255)

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(HERE, "assets", "icon")
os.makedirs(OUT, exist_ok=True)


def rr(d, box, r, fill):
    d.rounded_rectangle(box, radius=r, fill=fill)


def draw_mark(size, scale=1.0):
    """The barbell, centred, on a transparent ground."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = size / 2
    u = size / 100.0 * scale  # one unit

    # Bar through the middle.
    rr(d, (c - 40 * u, c - 3.2 * u, c + 40 * u, c + 3.2 * u), 3.2 * u, BAR)

    # Inner collars.
    for sx in (-1, 1):
        x = c + sx * 20 * u
        rr(d, (x - 2.6 * u, c - 8 * u, x + 2.6 * u, c + 8 * u), 1.6 * u, COLLAR)

    # Plates: a tall inner plate and a shorter outer one on each side.
    for sx, colour in ((-1, LEFT), (1, RIGHT)):
        x1 = c + sx * 26 * u
        rr(d, (min(x1, x1 + sx * 8 * u), c - 26 * u,
               max(x1, x1 + sx * 8 * u), c + 26 * u), 3.4 * u, colour)
        x2 = c + sx * 36 * u
        rr(d, (min(x2, x2 + sx * 6 * u), c - 17 * u,
               max(x2, x2 + sx * 6 * u), c + 17 * u), 2.6 * u, colour)

    return img


def masked(img, mask_kind):
    """Simulate what the launcher actually shows."""
    base = Image.new("RGBA", (S, S), BG)
    base.alpha_composite(img)
    mask = Image.new("L", (S, S), 0)
    m = ImageDraw.Draw(mask)
    if mask_kind == "circle":
        m.ellipse((0, 0, S, S), fill=255)
    else:
        m.rounded_rectangle((0, 0, S, S), radius=int(S * 0.22), fill=255)
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.paste(base, (0, 0), mask)
    return out


# Full-bleed icon (legacy launchers, the web favicon, the Releases page).
full = Image.new("RGBA", (S, S), BG)
full.alpha_composite(draw_mark(S, scale=1.0))
full.save(os.path.join(OUT, "icon.png"))

# Adaptive foreground. flutter_launcher_icons wraps this in a further 16%
# inset (see the generated mipmap-anydpi-v26/ic_launcher.xml), so the mark is
# drawn large here and INSET is applied below when previewing. Draw it small
# as well and the barbell ends up a sliver in the middle of the circle.
FG_SCALE = 0.95
INSET = 0.16

fg = draw_mark(S, scale=FG_SCALE)
fg.save(os.path.join(OUT, "icon_fg.png"))


def as_launcher_sees_it():
    """Foreground shrunk by the 16% inset the generated XML applies."""
    inner = int(S * (1 - 2 * INSET))
    small = draw_mark(S, scale=FG_SCALE).resize((inner, inner))
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    layer.alpha_composite(small, (int(S * INSET), int(S * INSET)))
    return layer


prev = Image.new("RGBA", (S * 2 + 60, S), (30, 30, 30, 255))
prev.alpha_composite(masked(as_launcher_sees_it(), "circle"), (0, 0))
prev.alpha_composite(masked(as_launcher_sees_it(), "squircle"), (S + 60, 0))
prev.resize((512, 256)).save(os.path.join(OUT, "_launcher_preview.png"))

print("wrote", OUT)
