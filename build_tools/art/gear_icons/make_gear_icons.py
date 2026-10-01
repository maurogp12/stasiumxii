# Gear icons from the set art in the GDD Blueprint (Mauro, 29 Sep 2026:
# "build item based on the sets images"). Sources in src/ are the Blueprint's
# armor sheets (s_*) and weapon sheets (w_*). Each piece is cut from its sheet
# background, cleaned, outlined and fitted to a 128 px transparent icon:
#   art/items/gear/<family>_<head|chest|legs|boots>.png
#   art/items/gear/<family>_weapon_<class>.png   (the family weapon per class)
# Undertow and Stillcut only have full-figure art: helm / chest / legs are cut
# from the figure; their legs and boots (hidden on the figure) are the Ironveil
# boots and greaves recoloured to the family palette.
# Boxes are in the coordinates of the sheet shown 680 px wide.
# Run: python3 build_tools/art/gear_icons/make_gear_icons.py
import os
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "src")
MASKS = os.path.join(HERE, "masks")  # make_masks.py (rembg) for hard pieces
OUT = os.path.abspath(os.path.join(HERE, "..", "..", "..", "art", "items", "gear"))
SIZE = 128
CLASSES = ["kestrel", "ironjaw", "mender", "gloam", "bastion"]

PIECES = {
    "sheaf": ("s_sheaf", {"head": (440, 8, 596, 184), "chest": (235, 85, 440, 430), "legs": (75, 200, 225, 410), "boots": (430, 215, 610, 425)}),
    "ironveil": ("s_iron", {"head": (195, 15, 330, 225), "chest": (330, 35, 530, 350), "legs": (170, 245, 345, 425), "boots": (440, 235, 640, 432)}),
    "brightedge": ("s_bright", {"head": (215, 22, 375, 210), "chest": (395, 12, 612, 250), "legs": (145, 195, 348, 432), "boots": (350, 245, 562, 442)}),
    "duskbrand": ("s_dusk", {"head": (270, 75, 378, 232), "chest": (420, 58, 628, 252), "legs": (108, 250, 272, 416), "boots": (368, 268, 560, 414)}),
    "undertow": ("s_under", {"head": (145, 25, 420, 360), "chest": (0, 240, 470, 860)}),
    "stillcut": ("s_still", {"head": (210, 0, 520, 370), "chest": (60, 290, 475, 880)}),
}
WEAPONS = {
    "sheaf": ("w_sheaf", [(40, 85, 160, 362), (148, 150, 305, 358), (300, 85, 378, 365), (375, 172, 515, 345), (517, 100, 658, 348)]),
    "undertow": ("w_under", [(40, 68, 325, 195), (345, 85, 645, 195), (60, 180, 200, 425), (375, 190, 600, 300), (150, 315, 505, 430)]),
    "ironveil": ("w_iron", [(20, 65, 230, 262), (245, 70, 465, 235), (505, 22, 640, 256), (60, 280, 260, 415), (305, 255, 575, 420)]),
    "stillcut": ("w_still", [(30, 55, 140, 350), (150, 110, 282, 345), (295, 70, 385, 352), (385, 125, 525, 332), (525, 75, 668, 320)]),
    "brightedge": ("w_bright", [(125, 60, 350, 235), (440, 45, 660, 255), (45, 180, 180, 440), (205, 255, 385, 425), (470, 255, 660, 445)]),
    "duskbrand": ("w_dusk", [(35, 75, 125, 345), (135, 140, 285, 310), (310, 90, 385, 340), (400, 150, 520, 300), (525, 100, 665, 325)]),
}
# Boots recolour for the families whose figure hides the feet: (dark, light) tints.
BOOT_TINT = {"undertow": ((18, 52, 56), (196, 164, 92)), "stillcut": ((14, 14, 18), (214, 176, 96))}


def load(name):
    return Image.open(os.path.join(SRC, name + ".jpg")).convert("RGB")


def cut(img, box, tol=None, keep_frac=0.12, mask_path=None):
    s = img.width / 680.0
    x0, y0, x1, y1 = [int(round(v * s)) for v in box]
    raw = img.crop((x0, y0, x1, y1))
    crop = np.asarray(raw).astype(np.float32)
    if mask_path and os.path.exists(mask_path):
        m = np.asarray(Image.open(mask_path).convert("L").resize(raw.size))
        im = Image.fromarray(np.dstack([crop.astype(np.uint8), m]), "RGBA")
        bb = Image.fromarray(np.where(m > 96, 255, 0).astype(np.uint8)).getbbox()
        return im.crop(bb) if bb else None
    soft = np.asarray(raw.filter(ImageFilter.MedianFilter(3))).astype(np.float32)
    # Paper colour = the most common colour along the crop edge. The paper is
    # one flat colour there while the item's colours vary, so the mode stays on
    # the paper even when the item covers much of a narrow crop's edge.
    border = np.concatenate([soft[0], soft[-1], soft[:, 0], soft[:, -1]])
    bins = (border // 12).astype(np.int32)
    keys = bins[:, 0] * 10000 + bins[:, 1] * 100 + bins[:, 2]
    vals, counts = np.unique(keys, return_counts=True)
    top = vals[np.argmax(counts)]
    bg = np.median(border[keys == top], axis=0)
    dist = np.sqrt(((soft - bg) ** 2).sum(axis=2))
    light = bg.mean() > 110
    figure = img.height > img.width * 2  # full-figure cards are noisier
    near = dist < (tol if tol is not None else (26 if light else (34 if figure else 22)))
    # Cast shadows on pale paper (Sheaf): same hue as the paper, a bit darker.
    if bg.mean() > 170:
        ratio = soft / np.maximum(bg, 1)
        near |= (np.std(ratio, axis=2) < 0.04) & (ratio.mean(axis=2) > 0.6) & (ratio.mean(axis=2) < 0.93)
    # Background = paper connected to the crop border (the ink outline of each
    # piece stops the fill, so pale or dark parts inside a piece survive).
    lab, n = ndi.label(near)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    # Big enclosed patches of paper (inside a bow and its string) are background too.
    if n:
        sizes = ndi.sum(near, lab, range(1, n + 1))
        edge |= {i + 1 for i, v in enumerate(sizes) if v > 0.03 * near.size}
    fg = ~np.isin(lab, list(edge))
    fg = ndi.binary_opening(fg, iterations=1)
    lab, n = ndi.label(fg)
    if n == 0:
        return None
    sizes = ndi.sum(fg, lab, range(1, n + 1))
    keep = [i + 1 for i, v in enumerate(sizes) if v >= keep_frac * sizes.max()]
    mask = np.isin(lab, keep)
    # Fill only small holes: a bow's string frames open background.
    holes = ndi.binary_fill_holes(mask) & ~mask
    hl, hn = ndi.label(holes)
    if hn:
        hs = ndi.sum(holes, hl, range(1, hn + 1))
        small = [i + 1 for i, v in enumerate(hs) if v < 0.02 * mask.sum()]
        mask |= np.isin(hl, small)
    alpha = (mask * 255).astype(np.uint8)
    im = Image.fromarray(np.dstack([crop.astype(np.uint8), alpha]), "RGBA")
    bb = im.getbbox()
    return im.crop(bb) if bb else None


def finish(piece):
    # Fit to the icon with padding, soft edge, 1 px dark outline, gentle lift.
    pad = 10
    w, h = piece.size
    s = min((SIZE - 2 * pad) / w, (SIZE - 2 * pad) / h)
    piece = piece.resize((max(1, int(w * s)), max(1, int(h * s))), Image.LANCZOS)
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(piece, ((SIZE - piece.width) // 2, (SIZE - piece.height) // 2))
    a = np.asarray(canvas.getchannel("A")) > 96
    ring = ndi.binary_dilation(a, iterations=2) & ~a
    arr = np.asarray(canvas).copy()
    arr[..., 3] = np.where(a, 255, 0)
    arr[ring] = [16, 12, 10, 235]
    out = Image.fromarray(arr, "RGBA")
    return out.filter(ImageFilter.UnsharpMask(radius=1.2, percent=50, threshold=2))


def recolour(piece, dark, light):
    arr = np.asarray(piece).astype(np.float32)
    lum = arr[..., :3].mean(axis=2, keepdims=True) / 255.0
    d = np.array(dark, np.float32)
    l = np.array(light, np.float32)
    rgb = d + (l - d) * np.clip(lum * 1.6 - 0.15, 0, 1)
    arr[..., :3] = rgb
    return Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA")


def main():
    os.makedirs(OUT, exist_ok=True)
    made = 0
    for fam, (sheet, boxes) in PIECES.items():
        img = load(sheet)
        for slot, box in boxes.items():
            mask = os.path.join(MASKS, f"{fam}_{slot}.png")
            piece = cut(img, box, tol=14 if fam == "sheaf" else None, mask_path=mask)
            finish(piece).save(os.path.join(OUT, f"{fam}_{slot}.png"), optimize=True)
            made += 1
    iron = load("s_iron")
    for slot in ["legs", "boots"]:
        base = cut(iron, PIECES["ironveil"][1][slot])
        for fam, (dark, light) in BOOT_TINT.items():
            finish(recolour(base, dark, light)).save(os.path.join(OUT, f"{fam}_{slot}.png"), optimize=True)
            made += 1
    for fam, (sheet, boxes) in WEAPONS.items():
        img = load(sheet)
        for cls, box in zip(CLASSES, boxes):
            # The Ironveil weapon sheet's paper shades from centre to edge.
            piece = cut(img, box, tol=50 if fam == "ironveil" else None, keep_frac=0.25)
            finish(piece).save(os.path.join(OUT, f"{fam}_weapon_{cls}.png"), optimize=True)
            made += 1
    print("icons:", made)


if __name__ == "__main__":
    main()
