# XII Stills icons from Mauro's painted references (4 Oct 2026: "more like
# this but that matches our game"). Sources, kept in the repo and ignored by
# Godot: art/ui/stills/refs/mauro_still_bottles.png (12 potion bottles, 4x3)
# and mauro_still_fragments.png (12 framed glass shards, 4x3).
# Each cell is cut out, its black backdrop turned into alpha (the glow stays
# as a soft halo), fitted to 128x128 and matched to a Still by colour; two
# are recoloured to the Still's Vault of Aeons colour. The Still's emblem coin
# from still_icons.py is added so the 12 read apart at phone size.
# Writes art/ui/stills/still_<id>.png and still_<id>_fragment.png.
# Run: python3 build_tools/art/still_icons_from_refs.py
import colorsys
import os
import sys

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

sys.path.insert(0, os.path.dirname(__file__))
import still_icons as base  # noqa: E402  (medallion + colours)

ROOT = base.ROOT
REFS = os.path.join(ROOT, "art", "ui", "stills", "refs")
OUT = base.OUT
SIZE = 128
COLS, ROWS = 4, 3

# Reference cell (row-major) → Still. The brown stone bottle / shard becomes
# Stride (pale blue-white); the cream sun becomes Opening (amber).
CELL_FOR = {
    "silence": 0, "stride": 1, "cut": 2, "mercy": 3,
    "guard": 4, "quiet": 5, "root": 6, "ember": 7,
    "tide": 8, "opening": 9, "crown": 10, "end": 11,
}
RECOLOR = {"stride": "stride", "opening": "opening"}


def cell(img, index):
    w, h = img.size
    cw, ch = w / COLS, h / ROWS
    c, r = index % COLS, index // COLS
    return img.crop((int(c * cw), int(r * ch), int((c + 1) * cw), int((r + 1) * ch)))


def matte(im):
    """Black backdrop → alpha. Solid art inside stays opaque; glow fades."""
    a = np.asarray(im.convert("RGB"), dtype=np.float32)
    border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(border, axis=0)
    dist = np.sqrt(((a - bg) ** 2).sum(-1))
    # Near-black noise around the art is backdrop, not glow.
    soft = np.clip((dist - 16.0) / 60.0, 0.0, 1.0) ** 1.4
    # Solid body: everything not reachable from the border through near-black.
    near = dist < 18.0
    labels, _ = ndimage.label(near)
    edge_labels = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))) - {0}
    outside = np.isin(labels, list(edge_labels))
    body = ndimage.binary_fill_holes(~outside)
    body = ndimage.binary_erosion(body, iterations=2)
    body_a = np.asarray(Image.fromarray((body * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5)), dtype=np.float32) / 255.0
    alpha = np.maximum(soft, body_a)
    # Keep only the main piece (and its glow): drop slivers of the next cell.
    solid = alpha > 0.35
    lab, n = ndimage.label(solid)
    if n > 1:
        sizes = ndimage.sum(solid, lab, range(1, n + 1))
        keep = lab == (int(np.argmax(sizes)) + 1)
        near = ndimage.binary_dilation(keep, iterations=14)
        alpha = alpha * ndimage.gaussian_filter(near.astype(np.float32), 3.0)
    # Un-mix the black backdrop from the glow so it does not go grey.
    safe = np.maximum(alpha, 1e-3)[..., None]
    rgb = np.clip((a - bg * (1.0 - safe)) / safe, 0, 255)
    out = np.dstack([rgb, alpha * 255.0]).astype(np.uint8)
    return Image.fromarray(out, "RGBA"), body


def recolor(im, body, still):
    """Shift the liquid / glass (not the gold) toward the Still's colour."""
    a = np.asarray(im, dtype=np.float32) / 255.0
    rgb = a[..., :3]
    hsv = np.zeros_like(rgb)
    flat = rgb.reshape(-1, 3)
    hsv_flat = np.array([colorsys.rgb_to_hsv(*p) for p in flat])
    hsv = hsv_flat.reshape(rgb.shape)
    target_h, target_s, _ = colorsys.rgb_to_hsv(*base.COLORS[still])
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    # Gold trim: saturated yellow-orange and bright. Leave it alone.
    gold = (h > 0.08) & (h < 0.17) & (s > 0.45) & (v > 0.45)
    inside = ndimage.binary_erosion(body, iterations=6)
    mask = inside & ~gold
    soft = ndimage.gaussian_filter(mask.astype(np.float32), 2.0)
    if still == "stride":
        nh = np.full_like(h, target_h)
        ns = np.clip(s * 0.3 + 0.16, 0, 1)
        nv = np.clip(v * 1.5 + 0.12, 0, 1)
    else:  # opening: cream → warm amber
        nh = np.full_like(h, target_h)
        ns = np.clip(s * 1.6 + 0.35, 0, 1)
        nv = v
    new = np.array([colorsys.hsv_to_rgb(*p) for p in np.dstack([nh, ns, nv]).reshape(-1, 3)]).reshape(rgb.shape)
    k = soft[..., None]
    out = rgb * (1.0 - k) + new * k
    a[..., :3] = out
    return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "RGBA")


def fit(im, margin=4):
    """Crop to the art (alpha) and centre it in a SIZE square."""
    alpha = np.asarray(im)[..., 3]
    ys, xs = np.where(alpha > 40)
    box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    art = im.crop(box)
    side = SIZE - margin * 2
    scale = side / max(art.size)
    art = art.resize((max(1, int(art.size[0] * scale)), max(1, int(art.size[1] * scale))), Image.LANCZOS)
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.alpha_composite(art, ((SIZE - art.size[0]) // 2, (SIZE - art.size[1]) // 2))
    return out


def with_coin(icon, still):
    """The Still's emblem coin, bottom right (painted at 4x, like still_icons)."""
    big = Image.new("RGBA", (base.W, base.W), (0, 0, 0, 0))
    base.medallion(big, still, base.W - base.s(17), base.W - base.s(17), base.s(14), sum(map(ord, still)) + 99)
    coin = big.resize((SIZE, SIZE), Image.LANCZOS)
    out = icon.copy()
    out.alpha_composite(coin)
    return out


def build(sheet_name, suffix):
    sheet = Image.open(os.path.join(REFS, sheet_name)).convert("RGB")
    for still, index in CELL_FOR.items():
        im, body = matte(cell(sheet, index))
        if still in RECOLOR:
            im = recolor(im, body, still)
        icon = with_coin(fit(im), still)
        icon.save(os.path.join(OUT, "still_%s%s.png" % (still, suffix)))


def main():
    os.makedirs(OUT, exist_ok=True)
    build("mauro_still_bottles.png", "")
    build("mauro_still_fragments.png", "_fragment")
    print("wrote 24 icons from Mauro's references to %s" % OUT)


if __name__ == "__main__":
    main()
