#!/usr/bin/env python3
"""Pack the locked down-right (east) march into the mobile walk sheets.

Source frames are the painted 12-frame S walks (old letter e = down-right).
Each class is scaled so the contact frame's opaque height matches the
previous east walk, then pasted so that foot sits on the same cell row the
pawn already uses (offset (0, -72), cell height 160 when the pose fits).
The contact foot is the horizontal pivot (cell center). South, north, and
west sheets are not touched: south is its own down-left walk, and north/west
are the back views.

Writes:
  art/export_2x/characters/<class>/anims/<class>_walk_e.png
  art/export_2x/walk_src/<class>_walk_e.pngbin
and retargets walk_e in the kestrel/ironjaw/gloam SpriteFrames tres.
"""

from __future__ import annotations

import math
import re
import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = Path("/tmp/walks/locked_S_walks")
CLASSES = ["ironjaw", "gloam", "kestrel", "bastion", "mender"]
FRAMES = 12
# Godot Image pixel alpha is 0..1. The foot test is `a > 0.08`.
ALPHA_FOOT = 20  # 21/255 > 0.08, 20/255 is not
# Soft fringe still draws. Dust under this stays out of the cell fit.
ALPHA_FIT = 8
OLD_CELL_H = 160
OFFSET_Y = -72
# Previous east contact, measured the same way StripLibrary._foot_point does.
OLD_FOOT_Y = {
    "ironjaw": 150,
    "gloam": 151,
    "kestrel": 150,
    "bastion": 149,
    "mender": 150,
}
OLD_FIG_H = {
    "ironjaw": 146,
    "gloam": 146,
    "kestrel": 150,
    "bastion": 146,
    "mender": 144,
}
SPRITE_SCALE = {
    "ironjaw": 0.5 * 1.18,
    "bastion": 0.5 * 1.18,
    "kestrel": 0.5 * 0.88,
    "gloam": 0.5 * 0.88,
    "mender": 0.5 * 0.88,
}


def opaque_bounds(im: Image.Image, thresh: int) -> tuple[int, int, int, int] | None:
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    minx, miny, maxx, maxy = w, h, -1, -1
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > thresh:
                if x < minx:
                    minx = x
                if y < miny:
                    miny = y
                if x > maxx:
                    maxx = x
                if y > maxy:
                    maxy = y
    if maxx < 0:
        return None
    return minx, miny, maxx, maxy


def foot_point(im: Image.Image) -> tuple[float, int] | None:
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    foot_y = -1
    for y in range(h - 1, -1, -1):
        if any(px[x, y][3] > ALPHA_FOOT for x in range(w)):
            foot_y = y
            break
    if foot_y < 0:
        return None
    top = max(foot_y - 5, 0)
    sum_x = 0
    count = 0
    for y in range(top, foot_y + 1):
        for x in range(w):
            if px[x, y][3] > ALPHA_FOOT:
                sum_x += x
                count += 1
    if count <= 0:
        return None
    return (sum_x / count, foot_y)


def fig_h(im: Image.Image) -> int:
    bb = opaque_bounds(im, ALPHA_FOOT)
    if bb is None:
        return 0
    return bb[3] - bb[1] + 1


def scale_to_height(frames: list[Image.Image], target_h: int) -> tuple[list[Image.Image], float]:
    base = fig_h(frames[0])
    if base <= 0:
        raise SystemExit("contact frame has no opaque pixels")
    lo, hi = 0.2, 3.0
    best = frames
    best_scale = 1.0
    for _ in range(18):
        mid = (lo + hi) * 0.5
        trial = [_resize(fr, mid) for fr in frames]
        got = fig_h(trial[0])
        best, best_scale = trial, mid
        if got == target_h:
            return trial, mid
        if got > target_h:
            hi = mid
        else:
            lo = mid
    # Snap to the scale that lands on the target height.
    for scale in (best_scale, best_scale * target_h / max(fig_h(best[0]), 1)):
        trial = [_resize(fr, scale) for fr in frames]
        if fig_h(trial[0]) == target_h:
            return trial, scale
    raise SystemExit("could not match figure height %s (got %s)" % (target_h, fig_h(best[0])))


def _resize(im: Image.Image, scale: float) -> Image.Image:
    w, h = im.size
    nw = max(1, int(round(w * scale)))
    nh = max(1, int(round(h * scale)))
    return im.convert("RGBA").resize((nw, nh), Image.Resampling.LANCZOS)


def pack_class(cls: str) -> dict:
    raw = [
        Image.open(SRC / cls / f"{cls}_walk_S_f{i:02d}.png").convert("RGBA")
        for i in range(FRAMES)
    ]
    target_h = OLD_FIG_H[cls]
    target_foot_y = OLD_FOOT_Y[cls]
    scaled, scale = scale_to_height(raw, target_h)
    boxes = [opaque_bounds(im, ALPHA_FIT) for im in scaled]
    fp0 = foot_point(scaled[0])
    if fp0 is None or any(b is None for b in boxes):
        raise SystemExit("missing foot or pixels for %s" % cls)
    minx = min(b[0] for b in boxes)
    miny = min(b[1] for b in boxes)
    maxx = max(b[2] for b in boxes)
    maxy = max(b[3] for b in boxes)
    left = fp0[0] - minx
    right = maxx - fp0[0]
    above = fp0[1] - miny
    below = maxy - fp0[1]
    pad = 2
    half = int(math.ceil(max(left, right) + pad))
    cell_w = max(half * 2, 2)
    # local_y = foot_y - cell_h/2 + OFFSET_Y. Keep the previous plant.
    old_local_y = target_foot_y - (OLD_CELL_H / 2.0) + OFFSET_Y
    # foot_y = old_local_y + cell_h/2 - OFFSET_Y, and the pose must fit.
    half_need = max(
        pad + above - old_local_y + OFFSET_Y,
        old_local_y - OFFSET_Y + below + 1 + pad,
    )
    cell_h = max(OLD_CELL_H, int(math.ceil(half_need * 2.0)))
    if cell_h % 2:
        cell_h += 1
    foot_y = int(round(old_local_y + cell_h / 2.0 - OFFSET_Y))
    if cell_h == OLD_CELL_H:
        foot_y = target_foot_y
    foot_x = cell_w / 2.0
    dx = int(round(foot_x - fp0[0]))
    dy = int(round(foot_y - fp0[1]))
    # paste() with the image as its own mask drops the last opaque row.
    # alpha_composite keeps the scaled pixels intact.
    cells = []
    for im in scaled:
        canvas = Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
        canvas.alpha_composite(im, (dx, dy))
        cells.append(canvas)
    placed = foot_point(cells[0])
    nudge_x = int(round(foot_x - placed[0]))
    nudge_y = int(round(foot_y - placed[1]))
    if nudge_x or nudge_y:
        dx += nudge_x
        dy += nudge_y
        cells = []
        for im in scaled:
            canvas = Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
            canvas.alpha_composite(im, (dx, dy))
            cells.append(canvas)
    sheet = Image.new("RGBA", (cell_w * FRAMES, cell_h), (0, 0, 0, 0))
    for i, cell in enumerate(cells):
        sheet.paste(cell, (i * cell_w, 0))
    png = ROOT / "art/export_2x/characters" / cls / "anims" / f"{cls}_walk_e.png"
    bin_path = ROOT / "art/export_2x/walk_src" / f"{cls}_walk_e.pngbin"
    sheet.save(png, format="PNG")
    shutil.copyfile(png, bin_path)
    final_foot = foot_point(cells[0])
    final_h = fig_h(cells[0])
    if final_foot is None:
        raise SystemExit("%s lost its contact foot" % cls)
    if abs(final_h - target_h) > 1:
        raise SystemExit("%s figure height %s != %s" % (cls, final_h, target_h))
    if abs(final_foot[1] - foot_y) > 1:
        raise SystemExit("%s foot row %s != %s" % (cls, final_foot[1], foot_y))
    for im in cells:
        bb = opaque_bounds(im, ALPHA_FIT)
        if bb[0] < 0 or bb[1] < 0 or bb[2] >= cell_w or bb[3] >= cell_h:
            raise SystemExit("%s clipped a frame %s in %sx%s" % (cls, bb, cell_w, cell_h))
    # Lowest-foot travel across the cycle, in world pixels (sprite scale).
    spr = SPRITE_SCALE[cls]
    travels = []
    for cell in cells:
        fp = foot_point(cell)
        travels.append(((fp[0] - final_foot[0]) * spr, (fp[1] - final_foot[1]) * spr))
    local_y = final_foot[1] - cell_h / 2.0 + OFFSET_Y
    return {
        "class": cls,
        "scale": scale,
        "cell": (cell_w, cell_h),
        "foot": final_foot,
        "fig_h": final_h,
        "old_fig_h": target_h,
        "local_y": local_y,
        "world_h": final_h * spr,
        "old_world_h": target_h * spr,
        "sprite_scale": spr,
        "travels": travels,
        "png": png,
    }


def patch_tres(cls: str, cell_w: int, cell_h: int) -> None:
    path = ROOT / "art/export_2x/characters" / cls / f"{cls}_frames.tres"
    if not path.exists():
        return
    text = path.read_text()
    ext = re.search(
        r'\[ext_resource type="Texture2D" path="res://art/export_2x/characters/%s/anims/%s_walk_e\.png" id="([^"]+)"\]'
        % (cls, cls),
        text,
    )
    if ext is None:
        raise SystemExit("no walk_e ext_resource in %s" % path)
    ext_id = ext.group(1)
    block = re.compile(
        r'\[sub_resource type="AtlasTexture" id="AtlasTexture_walk_e_\d+"\]\n'
        r'atlas = ExtResource\("[^"]+"\)\n'
        r'region = Rect2\([^)]+\)\n\n'
    )
    found = block.findall(text)
    if len(found) != 6:
        raise SystemExit("%s expected 6 walk_e atlas blocks, found %s" % (cls, len(found)))
    text = block.sub("", text, count=6)
    inserts = []
    for i in range(FRAMES):
        inserts.append(
            '[sub_resource type="AtlasTexture" id="AtlasTexture_walk_e_%d"]\n'
            'atlas = ExtResource("%s")\n'
            "region = Rect2(%d, 0, %d, %d)\n"
            % (i, ext_id, i * cell_w, cell_w, cell_h)
        )
    anchor = '[sub_resource type="AtlasTexture" id="AtlasTexture_walk_n_0"]'
    if anchor not in text:
        raise SystemExit("walk_n anchor missing in %s" % path)
    text = text.replace(anchor, "\n".join(inserts) + "\n" + anchor, 1)
    frames = ",\n".join(
        '{\n"duration": 1.0,\n"texture": SubResource("AtlasTexture_walk_e_%d")\n}' % i
        for i in range(FRAMES)
    )
    anim = re.compile(
        r'"frames": \[\{\n"duration": 1\.0,\n"texture": SubResource\("AtlasTexture_walk_e_0"\)\n\}.*?\],\n"loop": 1,\n"name": &"walk_e",\n"speed": 12\.0',
        re.S,
    )
    repl = '"frames": [%s],\n"loop": 1,\n"name": &"walk_e",\n"speed": 12.0' % frames
    text, n = anim.subn(repl, text, count=1)
    if n != 1:
        raise SystemExit("walk_e animation block missing in %s" % path)
    path.write_text(text)


def main() -> None:
    reports = []
    for cls in CLASSES:
        info = pack_class(cls)
        patch_tres(cls, info["cell"][0], info["cell"][1])
        reports.append(info)
        dxs = [t[0] for t in info["travels"]]
        dys = [t[1] for t in info["travels"]]
        print(
            "%s scale=%.4f cell=%dx%d foot=(%.1f,%d) fig_h=%d (old %d) "
            "local_y=%.2f world_h=%.2f (old %.2f) foot_dx_world=%+.1f..%+.1f "
            "foot_dy_world=%+.1f..%+.1f"
            % (
                cls,
                info["scale"],
                info["cell"][0],
                info["cell"][1],
                info["foot"][0],
                info["foot"][1],
                info["fig_h"],
                info["old_fig_h"],
                info["local_y"],
                info["world_h"],
                info["old_world_h"],
                min(dxs),
                max(dxs),
                min(dys),
                max(dys),
            )
        )


if __name__ == "__main__":
    main()
