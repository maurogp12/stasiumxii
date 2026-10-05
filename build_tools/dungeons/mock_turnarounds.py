"""Turnaround review images (S and E source paintings, keyed) in _mock/."""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402

SETS = {
    "granary_rat": [("rat_S", "S: front, facing down-right"), ("rat_E", "E: back, facing up-right")],
    "sling_rat": [("sling_rat_S", "S: front, facing down-right"), ("sling_rat_E", "E: back, facing up-right")],
    "scarecrow_drudge": [("scarecrow_S", "S: front, facing down-right"), ("scarecrow_E", "E: back, facing up-right")],
    "the_ratking": [("ratking_S", "S: front, facing down-right"), ("ratking_E", "E: back, facing up-right")],
    "radioactive_ratking": [("ratking_S", "base S (the Ratking)"), ("rad_ratking_S", "star 5 S: front, down-right"), ("rad_ratking_E", "star 5 E: back, up-right")],
    "radioactive_rat": [("rad_rat_S", "star 5 S: front, down-right"), ("rad_rat_E", "star 5 E: back, up-right")],
    "radioactive_sling_rat": [("rad_sling_rat_S", "star 5 S: front, down-right"), ("rad_sling_rat_E", "star 5 E: back, up-right")],
}


def cut(name, h):
    b = gkit.binarize(gkit.clean_alpha(gkit.key_auto(gkit.load_rgb(name + ".jpg"))))
    im = Image.fromarray(b)
    ys, xs = np.nonzero(b[..., 3])
    im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    sc = h / max(im.height, im.width * 0.9)
    return im.resize((int(im.width * sc), int(im.height * sc)), Image.LANCZOS)


def main(ids):
    for mid in ids:
        star = mid.startswith("radioactive")
        ims = [(cut(n, 720), lbl) for n, lbl in SETS[mid]]
        W = sum(i.width for i, _ in ims) + 30 * (len(ims) + 1)
        H = max(i.height for i, _ in ims) + 70
        bg = (48, 44, 40) if star else (172, 172, 172)
        fg = (230, 230, 220) if star else (0, 0, 0)
        c = Image.new("RGB", (W, H), bg)
        d = ImageDraw.Draw(c)
        x = 30
        for i, lbl in ims:
            c.paste(i, (x, 50 + H - 70 - i.height), i)
            d.text((x, 20), lbl, fill=fg)
            x += i.width + 30
        out = os.path.join(gkit.OUT, "_mock", "%s_turnaround.png" % mid)
        c.save(out)
        print(out)


if __name__ == "__main__":
    main(sys.argv[1:] or list(SETS))
