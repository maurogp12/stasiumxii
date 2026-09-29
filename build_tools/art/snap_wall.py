"""Bake the Bastion Snap Wall sprite (Mauro 29 Sep 2026: "make it look like a
realistic wall"). An isometric block of dressed stone masonry sized to one
board tile (64x32 diamond), with lit / shaded faces, mortar, chipped edges,
moss at the foot, crenellations on top and a carved gold-rimmed shield on the
front face. Output: art/vfx/wall/snap_wall.png at 4x (drawn at 0.25 in Godot).

Run: python3 build_tools/art/snap_wall.py
"""
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

S = 4                      # supersample: 1 board px = 4 sprite px
HALF_W, HALF_H = 32 * S, 16 * S
INSET = 0.10               # walls on neighbouring tiles read as separate blocks
BODY_H = 40 * S            # wall height (board px 40)
MERLON_H = 10 * S
PAD = 8 * S
W = 2 * HALF_W + 2 * PAD
H = 2 * HALF_H + BODY_H + MERLON_H + 2 * PAD
# Base diamond centre in sprite pixels (Godot anchors here).
CX, CY = W / 2, PAD + MERLON_H + BODY_H + HALF_H
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "art", "vfx", "wall", "snap_wall.png")

rng = random.Random(7)
np_rng = np.random.default_rng(7)


def value_noise(w, h, scale, octaves=4):
    out = np.zeros((h, w), np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        cell = max(2, int(scale / (2 ** o)))
        gw, gh = w // cell + 2, h // cell + 2
        grid = np_rng.random((gh, gw)).astype(np.float32)
        img = Image.fromarray((grid * 255).astype(np.uint8)).resize((gw * cell, gh * cell), Image.BICUBIC)
        out += np.asarray(img, np.float32)[:h, :w] / 255.0 * amp
        total += amp
        amp *= 0.5
    return out / total


def stone_texture(w, h, rows, light, seed_shift=0.0, moss=True):
    """Dressed ashlar: rows of stones with random widths, mortar, chips."""
    base = np.array([112, 104, 96], np.float32)          # warm grey granite
    img = np.zeros((h, w, 3), np.float32)
    grain = value_noise(w, h, 18 * S // 4)
    fine = value_noise(w, h, 4 * S // 4, 2)
    mortar = np.ones((h, w), np.float32)
    shade = np.ones((h, w), np.float32)
    row_h = h / rows
    for r in range(rows):
        y0, y1 = int(r * row_h), int((r + 1) * row_h)
        x = -rng.uniform(0, w * 0.3) if r % 2 else -rng.uniform(w * 0.15, w * 0.45)
        while x < w:
            sw = rng.uniform(w * 0.22, w * 0.42)
            x0, x1 = int(max(x, 0)), int(min(x + sw, w))
            tint = rng.uniform(0.82, 1.12)
            hue = np.array([rng.uniform(0.96, 1.04), 1.0, rng.uniform(0.94, 1.05)], np.float32)
            if x1 > x0:
                img[y0:y1, x0:x1] = base * tint * hue
                # Bevel: top/left edge catches light, bottom/right in shadow.
                b = max(2, S)
                shade[y0:y0 + b, x0:x1] *= 1.22
                shade[y0:y1, x0:x0 + b] *= 1.12
                shade[max(y1 - b, y0):y1, x0:x1] *= 0.72
                shade[y0:y1, max(x1 - b, x0):x1] *= 0.80
                # A chipped corner now and then.
                if rng.random() < 0.35:
                    cr = rng.randint(2 * S, 4 * S)
                    cx = x0 if rng.random() < 0.5 else x1 - cr
                    mortar[y0:y0 + cr, max(cx, 0):max(cx + cr, 0)] *= 0.55
            # Mortar joint (vertical).
            j = int(x + sw)
            mortar[y0:y1, max(j - S // 2, 0):min(j + S // 2 + 1, w)] = 0.35
            x += sw
        mortar[max(y1 - S // 2 - 1, 0):min(y1 + S // 2, h), :] = 0.35
    img *= (0.72 + 0.5 * grain)[..., None] * (0.9 + 0.2 * fine)[..., None]
    img *= shade[..., None]
    img = img * mortar[..., None] + np.array([46, 42, 38], np.float32) * (1 - mortar[..., None])
    # Foot: ambient occlusion and a little moss creeping up.
    v = np.linspace(0, 1, h, dtype=np.float32)[:, None]
    ao = 0.55 + 0.45 * np.clip((1 - v) / 0.35 + 0.0, 0, 1) ** 0.5
    ao = np.where(v > 0.65, 1 - (v - 0.65) / 0.35 * 0.45, 1.0)
    img *= ao[..., None]
    if moss:
        mn = value_noise(w, h, 10 * S // 4, 3)
        m = np.clip((v - 0.72) * 4.0 + (mn - 0.55) * 2.2, 0, 1)[..., None] * 0.65
        img = img * (1 - m) + np.array([74, 96, 46], np.float32) * m
    # Top of the face slightly lighter (sky light).
    img *= (1.08 - 0.12 * v)[..., None]
    img *= light
    return np.clip(img, 0, 255).astype(np.uint8)


def paste_face(canvas, tex, p0, p1, height):
    """Map a (h, w) texture onto the parallelogram p0→p1 raised by `height`."""
    th, tw = tex.shape[:2]
    ax, ay = p1[0] - p0[0], p1[1] - p0[1]          # along the edge
    bx, by = 0.0, -height                          # straight up
    # Output (X, Y) = p0_top + a*u + b*(1-v) ... solve texture coords from output.
    top = (p0[0] + bx, p0[1] + by)
    # u = (X - top.x)/ax ; Y = top.y + ay*u + (-by)*v  -> v = (Y - top.y - ay*u)/(-by)
    a_ = tw / ax
    d_ = -ay / (-by) * th / ax
    e_ = th / (-by)
    coeffs = (a_, 0, -top[0] * a_,
              d_, e_, -(top[1]) * e_ - top[0] * d_)
    face = Image.fromarray(tex).convert("RGBA").transform(canvas.size, Image.AFFINE, coeffs, resample=Image.BICUBIC)
    mask = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(mask).polygon([p0, p1, (p1[0], p1[1] - height), (p0[0], p0[1] - height)], fill=255)
    canvas.paste(face, (0, 0), mask)


def diamond(cx, cy, hw, hh, inset=0.0):
    pts = [(cx, cy - hh), (cx + hw, cy), (cx, cy + hh), (cx - hw, cy)]
    return [(x + (cx - x) * inset, y + (cy - y) * inset) for x, y in pts]


def box(canvas, cx, cy, hw, hh, height, rows, light_l=1.0, light_r=0.62, top_light=1.18, moss=False):
    n, e, s, w_ = diamond(cx, cy, hw, hh)
    lw = int(max(8, np.hypot(s[0] - w_[0], s[1] - w_[1])))
    th = int(max(8, height))
    paste_face(canvas, stone_texture(lw, th, rows, light_l, moss=moss), w_, s, height)
    paste_face(canvas, stone_texture(lw, th, rows, light_r, moss=moss), s, e, height)
    top = [(x, y - height) for x, y in (n, e, s, w_)]
    tex = stone_texture(int(hw * 2), int(hh * 2), 2, top_light, moss=False)
    face = Image.fromarray(tex).convert("RGBA").resize((int(hw * 2), int(hh * 2)))
    mask = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(mask).polygon(top, fill=255)
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    layer.paste(face, (int(cx - hw), int(cy - hh - height)))
    canvas.paste(layer, (0, 0), mask)
    d = ImageDraw.Draw(canvas)
    # Crisp top rim highlight and dark vertical corner.
    d.line([top[3], top[2], top[1]], fill=(214, 204, 186, 255), width=max(1, S // 2))
    d.line([s, (s[0], s[1] - height)], fill=(40, 36, 32, 255), width=max(1, S // 2))


def main():
    canvas = Image.new("RGBA", (int(W), int(H)), (0, 0, 0, 0))
    hw, hh = HALF_W * (1 - INSET), HALF_H * (1 - INSET)
    # Soft contact shadow on the tile.
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).polygon(diamond(CX + 3 * S, CY + 2 * S, hw * 1.08, hh * 1.08), fill=(0, 0, 0, 120))
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(3 * S)))
    # Main body.
    box(canvas, CX, CY, hw, hh, BODY_H, rows=5, moss=True)
    # Crenellations: merlons on the parapet, back ones first.
    top_y = CY - BODY_H
    m_hw, m_hh = hw * 0.19, hh * 0.19
    spots = []
    n, e, s, w_ = diamond(CX, top_y, hw, hh)
    for (a, b) in [(n, e), (w_, n), (w_, s), (s, e)]:
        for t in (0.22, 0.78):
            spots.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    for x, y in sorted(spots, key=lambda p: p[1]):
        # Pull the merlon inward so it sits on the wall top.
        px, py = x + (CX - x) * 0.14, y + (top_y - y) * 0.14
        box(canvas, px, py + m_hh * 0.3, m_hw, m_hh, MERLON_H, rows=2, light_l=1.08, light_r=0.66)
    # Carved shield with a gold rim on the lit front face.
    # Centre of the lit W->S face; points lean with the face (slope +0.5).
    fx = CX - hw * 0.5
    fy = CY + hh * 0.5 - BODY_H * 0.52
    raw = [(-6, -7), (6, -7), (6, 1), (0, 8), (-6, 1)]
    sh = [(fx + x * S, fy + y * S + x * S * 0.5) for x, y in raw]
    d = ImageDraw.Draw(canvas)
    d.polygon([(x + S, y + S) for x, y in sh], fill=(30, 26, 22, 200))
    d.polygon(sh, fill=(86, 80, 74, 255), outline=(222, 176, 72, 255))
    d.line(sh + [sh[0]], fill=(240, 196, 92, 255), width=S)
    d.line([(fx, fy - 7 * S), (fx, fy + 8 * S)], fill=(210, 164, 64, 255), width=max(1, S // 2))
    d.line([(fx - 6 * S, fy - 6 * S), (fx + 6 * S, fy)], fill=(210, 164, 64, 255), width=max(1, S // 2))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    canvas.save(OUT)
    print("wrote", os.path.normpath(OUT), canvas.size, "anchor", (CX, CY))


if __name__ == "__main__":
    main()
