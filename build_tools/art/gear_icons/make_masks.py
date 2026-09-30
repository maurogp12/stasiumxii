# Cut masks for gear pieces the paper-colour cut in make_gear_icons.py cannot
# separate (Sheaf: pale plate on pale paper; Mauro 29 Sep 2026 saw the Sheaf
# pieces half erased). rembg BiRefNet on the 3x crop, one piece per process
# (the model runs out of memory when several share a process). Writes
# masks/<family>_<slot>.png at the crop size; make_gear_icons.py uses a mask
# when one exists. Needs rembg + ~/.u2net or ~/.rembg birefnet-general.
# Run: python3 build_tools/art/gear_icons/make_masks.py
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_gear_icons as g  # noqa: E402

TARGETS = [("sheaf", "head"), ("sheaf", "chest"), ("sheaf", "legs")]

ONE = r"""
import sys
from PIL import Image
from rembg import remove, new_session
src, box, out = sys.argv[1], [float(v) for v in sys.argv[2].split(",")], sys.argv[3]
img = Image.open(src).convert("RGB")
s = img.width / 680.0
crop = img.crop(tuple(int(round(v * s)) for v in box))
big = crop.resize((crop.width * 3, crop.height * 3), Image.LANCZOS)
m = remove(big, session=new_session("birefnet-general"), only_mask=True)
m.resize(crop.size, Image.LANCZOS).save(out)
"""

if __name__ == "__main__":
    os.makedirs(os.path.join(HERE, "masks"), exist_ok=True)
    for fam, slot in TARGETS:
        sheet, boxes = g.PIECES[fam]
        box = ",".join(str(v) for v in boxes[slot])
        out = os.path.join(HERE, "masks", f"{fam}_{slot}.png")
        subprocess.run([sys.executable, "-c", ONE, os.path.join(g.SRC, sheet + ".jpg"), box, out], check=True)
        print("mask", fam, slot)
