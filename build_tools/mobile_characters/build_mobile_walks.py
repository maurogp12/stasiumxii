#!/usr/bin/env python3
"""Build the mobile painted character strips from the locked PC walk frames.

Re-run from the repo root:

    python3 build_tools/mobile_characters/build_mobile_walks.py

It reads the locked frames straight from git (the commits are pinned below),
so the source branches do not need to be checked out. It writes:

  art/characters/<class>/walk/<class>_walk_<n|e|s|w>.pngbin
      One horizontal sheet per mobile facing: 12 cells, left to right.
      Raw PNG bytes, not imported (the Android preset packs *.pngbin), so the
      phone reads the same pixels as the desktop.
  art/characters/<class>/<class>_<n|e|s|w>.png
      The standing look: frame f00 of that facing, same cell.
  units/character_strip_specs.gd
      The cell, pivot, frame count, fps and frames-per-tile that the loader
      reads. Generated; do not edit by hand.

Cell layout (every class, every facing): the source pivot lands on
(cell_w / 2, 152), the mobile sole line (Pawn.FOOT_PIVOT_Y), so
Pawn.pivot_offset_for(cell_h) stands the figure on the tile without any
per-texture metadata.

Facings. Source art letters follow the locked PC rule (S front down-right,
E back up-right, W = mirror of S, N = mirror of E). Mobile letters are the
old handoff (Pawn.FACING_ISO): e = down-right, s = down-left, n = up-right,
w = up-left. So: e <- S, s <- mirror(S), n <- E, w <- mirror(E). The
mirror is baked here; nothing sets flip_h.

Scale. The figure's height above the ground point on f00 of the front view
matches the old mobile static (same draw scale, Pawn.sprite_scale_for), and
is capped so that no frame reaches above the 152 px sole line, and the
texture is never upscaled.

Speed. Mobile moves one tile (hypot(32, 16) board px) every
Pawn.WALK_TILE_SEC. The planted foot of the S walk is tracked across the
stance to get the source px per frame. frames_per_tile_no_slide is the number
of frames whose foot travel equals one tile on the board at the class draw
scale. frames_per_tile is that, capped at MAX_LEG_RATE x the authored fps
(natural leg speed); a capped class has a small foot slide.

Actions. ACTION_SOURCES below holds the LOCKED painted idle, attack, skill,
hit and death of every class (4 Oct 2026), read from git at the lock
commits. They land in art/characters/<class>/<kind>/<class>_<kind>_<n|e|s|w>.pngbin
with the same facing map and baked mirrors, binary alpha and the walk's scale
(no size jump). walk and idle share one cell, pivot centred on the 152 sole
line, so standing never jumps between the two. Each action kind has its own
tight cell (<= 256): its sole row drops below 152 when a raised weapon needs
head room, and its pivot x is per facing (a body lying on its side reaches far
to one side). The spec's "pivots" holds that pivot per mobile facing.

Ironjaw's walk is the dark-steel HD v7 (Mauro: "Dark-steel for all"), so it
matches his actions. Its pin holes and dark edge pixels are cleaned here the
same way the LOCKED actions were (clean_frame).
"""
from __future__ import annotations

import io
import json
import math
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageOps

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# Locked sources. commit is pinned so a re-run gives the same bytes.
WALK_SOURCES = {
    "bastion": {
        "commit": "7f65035ef5226277ff466305175a00272285844c",
        "branch": "art/ironjaw-walk-help",
        "dir": "docs/pc/art_help/class_walk_looks/bastion/v3/frames",
        "pivot": {"S": (256, 329), "E": (256, 329)},
        "note": "Bastion v3, locked by Luca 4 Oct 2026",
    },
    "kestrel": {
        "commit": "d08e0b7d248ce121e2c24b22dff8056d1b80cee2",
        "branch": "claude/kestrel-legs",
        "dir": "docs/pc/art_help/class_walk_looks/kestrel/v3_claude/frames",
        "pivot": {"S": (256, 329), "E": (256, 329)},
        "note": "Kestrel v3_claude, locked d08e0b7",
    },
    "gloam": {
        "commit": "bdf0ff3753f6e045133d3105135a7687c3232511",
        "branch": "claude/gloam-legs",
        "dir": "docs/pc/art_help/class_walk_looks/gloam/v1_claude/frames",
        "pivot": {"S": (256, 329), "E": (256, 329)},
        "note": "Gloam v1_claude, locked bdf0ff3",
    },
    "mender": {
        "commit": "08ea869b459fa4d40d84ddf070a325d14d542824",
        "branch": "claude/mender-legs",
        "dir": "docs/pc/art_help/class_walk_looks/mender/v1_claude/frames",
        "pivot": {"S": (256, 329), "E": (256, 329)},
        "note": "Mender v1_claude, locked 08ea869",
    },
    "ironjaw": {
        # Dark-steel HD walk v7 (Mauro: "Dark-steel for all"; the v7 walk he
        # approved apart from the legs, not v8). 512x360, pivot (256,329),
        # 12 frames at 17.144 fps, like the other classes (BRIEF.md on that
        # branch). Replaces the older red v3.1 set (pc/combat-look a0aec2e).
        "commit": "0f3eeb801f5bf679d6082e248e99490a81ff2580",
        "branch": "art/ironjaw-walk-help",
        "dir": "docs/pc/art_help/ironjaw_walk/v7/frames",
        "pivot": {"S": (256, 329), "E": (256, 329)},
        # v7 has pin holes and dark halo pixels on the silhouette edge; the
        # LOCKED actions were cleaned the same way (actions_v1 README, lesson 7).
        "clean": True,
        "note": "Ironjaw dark-steel HD walk v7 (art/ironjaw-walk-help 0f3eeb8)",
    },
}

# LOCKED painted actions (4 Oct 2026). Every class: 512x360 cells, pivot
# (256,329), 17.144 fps, S and E (W and N are mirrors). Read from git at the
# lock commits. "impact" is the 0-based contact cell (the blockout key):
# release_sec and the hit flinch read it.
_ACTION_FRAMES = {"idle": 12, "attack": 12, "skill": 12, "hit": 8, "death": 13}
_ACTION_LOCKS = {
    "kestrel": ("claude/kestrel-actions", "0227894a777b9cddf4d21ffbb9f4ced200c3164f", {"attack": 9, "skill": 9}),
    "bastion": ("claude/bastion-actions", "b50c5983b0b70e389eb28dec707c5793e1e13740", {"attack": 6, "skill": 4}),
    "gloam": ("claude/gloam-actions", "94891db0c1710c78b167d36664749618e1320e04", {"attack": 6, "skill": 4}),
    "mender": ("claude/mender-actions", "0afabd727874e1c401f1f4a1779e738c5cebc457", {"attack": 6, "skill": 4}),
    "ironjaw": ("claude/ironjaw-actions", "9d784a1678e92b0af633747f87c816346c765330", {"attack": 6, "skill": 6}),
}


def _action_sources() -> dict:
    out: dict = {}
    for cls, (branch, commit, impacts) in _ACTION_LOCKS.items():
        out[cls] = {}
        for kind, n in _ACTION_FRAMES.items():
            a = {
                "branch": branch,
                "commit": commit,
                "dir": f"docs/pc/art_help/class_walk_looks/{cls}/actions_v1/frames",
                "pivot": {"S": (256, 329), "E": (256, 329)},
                "pattern": kind + "_{F}_f{i:02d}.png",
                "frames": n,
                "fps": 17.144,
                "loop": kind == "idle",
                "clean": False,
            }
            if kind in impacts:
                a["impact"] = impacts[kind]
            out[cls][kind] = a
    return out


ACTION_SOURCES: dict = _action_sources()
ACTION_KINDS = ("idle", "attack", "skill", "hit", "death")

FRAMES = 12
AUTHORED_FPS = 17.144
FOOT_ROW = 152  # Pawn.FOOT_PIVOT_Y
MAX_ABOVE = FOOT_ROW - 1
PAD = 2
MAX_CELL = 256  # phone memory cap per cell side

# Old mobile static (origin/mobile de0b900): rows above the 152 sole line,
# mean of the front views e and s (alpha > 20). Kept as numbers so a re-run
# after the statics are replaced gives the same scale.
OLD_STATIC_ABOVE_SOLE = {
    "bastion": (133 + 136) / 2.0,
    "kestrel": (151 + 143) / 2.0,
    "gloam": (146 + 122) / 2.0,
    "mender": (145 + 147) / 2.0,
    "ironjaw": (148 + 148) / 2.0,
}
# Pawn.CLASS_PRESENTATION_SCALE x Pawn.SPRITE_SCALE.
DRAW_SCALE = {
    "bastion": 0.5 * 1.18,
    "ironjaw": 0.5 * 1.18,
    "kestrel": 0.5 * 0.88,
    "gloam": 0.5 * 0.88,
    "mender": 0.5 * 0.88,
}
# Leg rate cap (Mauro 4 Oct 2026, "natural leg speed"). Matching the foot to
# the board at WALK_TILE_SEC would cycle the legs 1.6-3.7x the authored
# 17.144 fps (up to 63 fps), which reads as flailing. The walk never plays
# faster than MAX_LEG_RATE x the authored fps; a class whose stride is shorter
# than that allows accepts a small foot slide. WALK_TILE_SEC is not changed.
MAX_LEG_RATE = 1.6
TILE_STEP_PX = math.hypot(32.0, 16.0)  # board/tile.gd 64x32 diamond
WALK_TILE_SEC = 0.34  # Pawn.WALK_TILE_SEC

# mobile letter -> (source letter, mirrored)
LETTER_FROM_ART = {"e": ("S", False), "s": ("S", True), "n": ("E", False), "w": ("E", True)}
LETTERS = ("n", "e", "s", "w")


def git_bytes(commit: str, path: str) -> bytes:
    return subprocess.run(
        ["git", "-C", ROOT, "show", f"{commit}:{path}"],
        check=True, capture_output=True,
    ).stdout


def load_frames(src: dict, art: str, pattern: str, count: int) -> list[Image.Image]:
    out = []
    for i in range(count):
        name = pattern.format(F=art, i=i)
        data = git_bytes(src["commit"], f"{src['dir']}/{name}")
        out.append(Image.open(io.BytesIO(data)).convert("RGBA"))
    return out


def alpha_bbox(img: Image.Image) -> tuple[int, int, int, int]:
    a = np.asarray(img)[..., 3]
    ys, xs = np.nonzero(a > 0)
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def resize_binary(img: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Premultiplied Lanczos, then a hard 50% alpha cut (binary alpha)."""
    arr = np.asarray(img).astype(np.float32) / 255.0
    rgb = arr[..., :3] * arr[..., 3:4]
    pre = np.concatenate([rgb, arr[..., 3:4]], axis=2)
    chans = []
    for c in range(4):
        ch = Image.fromarray(pre[..., c], mode="F").resize(size, Image.LANCZOS)
        chans.append(np.asarray(ch))
    out = np.stack(chans, axis=2)
    alpha = np.clip(out[..., 3], 0.0, 1.0)
    keep = alpha >= 0.5
    safe = np.where(alpha > 1e-4, alpha, 1.0)[..., None]
    color = np.clip(out[..., :3] / safe, 0.0, 1.0)
    res = np.zeros(out.shape, dtype=np.uint8)
    res[..., :3] = np.where(keep[..., None], np.round(color * 255.0), 0).astype(np.uint8)
    res[..., 3] = np.where(keep, 255, 0).astype(np.uint8)
    return Image.fromarray(res, mode="RGBA")


def stance_px_per_frame(frames: list[Image.Image], start: int, span: int = 3) -> float:
    """Source px per frame of the planted foot, along the 2:1 walk axis.

    Template = the lowest foot on the contact frame (RGBA, with a transparent
    margin so a match inside the body scores badly). Each next frame is
    searched near the last hit by sum of squared differences.
    """
    arrs = [np.asarray(f).astype(np.float32) / 255.0 for f in frames]
    pre = [np.concatenate([a[..., :3] * a[..., 3:4], a[..., 3:4]], axis=2) for a in arrs]
    a0 = arrs[start][..., 3] > 0
    h, w = a0.shape
    ys, xs = np.nonzero(a0)
    yb = ys.max()
    rows = max(4, int(h * 0.05))
    band = a0.copy()
    band[: yb - rows] = False
    ys2, xs2 = np.nonzero(band)
    bx = xs2[ys2.argmax()]
    near = np.abs(xs2 - bx) < max(8, int(w * 0.06))
    m = max(3, int(h * 0.012))
    y0 = max(0, int(ys2[near].min()) - m)
    y1 = min(h - 1, int(ys2[near].max()) + m)
    x0 = max(0, int(xs2[near].min()) - m)
    x1 = min(w - 1, int(xs2[near].max()) + m)
    tpl = pre[start][y0:y1 + 1, x0:x1 + 1]
    th, tw = tpl.shape[:2]
    reach = max(8, int(h * 0.05))
    prev = (0, 0)
    for k in range(1, span + 1):
        cur = pre[(start + k) % len(pre)]
        best = None
        for dy in range(prev[1] - reach, prev[1] + reach + 1):
            for dx in range(prev[0] - reach, prev[0] + reach + 1):
                yy, xx = y0 + dy, x0 + dx
                if yy < 0 or xx < 0 or yy + th > h or xx + tw > w:
                    continue
                d = float(((cur[yy:yy + th, xx:xx + tw] - tpl) ** 2).sum())
                if best is None or d < best[0]:
                    best = (d, dx, dy)
        prev = (best[1], best[2])
    axis = np.array([2.0, 1.0]) / math.sqrt(5.0)
    along = abs(float(np.dot(np.array(prev, dtype=float), axis)))
    return along / float(span)


def clean_frame(img: Image.Image) -> tuple[Image.Image, dict]:
    """Speckles, pin holes and dark edge pixels, the actions_v1 lesson 7 pass.

    Islands under 8 px are dropped. Transparent pin holes under 24 px inside
    the figure are closed with the paint around them. Opaque pixels on the
    silhouette edge darker than 0.55x the paint just inside are recoloured
    from it. Deterministic: same input, same bytes.
    """
    from scipy import ndimage as ndi

    a = np.asarray(img).copy()
    m = a[..., 3] > 0
    eight = np.ones((3, 3), dtype=bool)
    lab, n = ndi.label(m, structure=eight)
    dropped = 0
    if n:
        sizes = ndi.sum(m, lab, range(1, n + 1))
        small = np.isin(lab, np.nonzero(sizes < 8)[0] + 1)
        dropped = int(small.sum())
        m &= ~small
    holes = ~m
    hl, hn = ndi.label(holes)
    border = set(np.unique(np.concatenate([hl[0], hl[-1], hl[:, 0], hl[:, -1]])).tolist())
    filled = 0
    if hn:
        hs = ndi.sum(holes, hl, range(1, hn + 1))
        ids = [i + 1 for i, v in enumerate(hs) if v < 24 and (i + 1) not in border]
        pin = np.isin(hl, ids)
        filled = int(pin.sum())
        rgb = a[..., :3].astype(np.float64)
        known = m.copy()
        todo = pin.copy()
        while todo.any():
            w = ndi.uniform_filter(known.astype(np.float64), 3)
            ring = todo & (w > 0)
            for c in range(3):
                acc = ndi.uniform_filter(rgb[..., c] * known, 3)
                rgb[..., c] = np.where(ring, acc / np.maximum(w, 1e-9), rgb[..., c])
            known |= ring
            todo &= ~ring
        a[..., :3] = np.where(pin[..., None], np.round(rgb).astype(np.uint8), a[..., :3])
        m |= pin
    inner = ndi.binary_erosion(m, structure=eight)
    edge = m & ~inner
    lum = a[..., :3].astype(np.float64) @ np.array([0.299, 0.587, 0.114])
    den = ndi.uniform_filter(inner.astype(np.float64), 5)
    ref = np.zeros(a.shape[:2] + (3,))
    for c in range(3):
        ref[..., c] = ndi.uniform_filter(a[..., c].astype(np.float64) * inner, 5) / np.maximum(den, 1e-9)
    ref_lum = ref @ np.array([0.299, 0.587, 0.114])
    dark = edge & (den > 0) & (lum < 0.55 * ref_lum)
    a[..., :3] = np.where(dark[..., None], np.round(ref).astype(np.uint8), a[..., :3])
    a[..., 3] = np.where(m, 255, 0).astype(np.uint8)
    a[..., :3] = np.where(m[..., None], a[..., :3], 0)
    return Image.fromarray(a, mode="RGBA"), {"specks": dropped, "holes": filled, "dark_edge": int(dark.sum())}


def build_class(cls: str, src: dict, actions: dict) -> dict:
    """Walk plus the painted actions for one class, all at the walk's scale.

    walk and idle share one cell, pivot centred on the 152 sole line, so the
    standing idle and the stride never jump. Each action kind (attack, skill,
    hit, death) gets its own tight cell at the same scale: its sole row is
    152, or lower when a raised weapon needs the head room, and its pivot x is
    per facing (a lying body reaches far to one side). The cell's pivot is
    written per facing into the spec; the pawn stands every cell on it.
    """
    sets = {"walk": (src, {F: load_frames(src, F, f"{cls}_walk_{{F}}_f{{i:02d}}.png", FRAMES) for F in ("S", "E")})}
    for kind, a in actions.items():
        merged = dict(src)
        merged.update(a)
        sets[kind] = (merged, {F: load_frames(merged, F, a["pattern"], int(a["frames"])) for F in ("S", "E")})
    clean_log = {"specks": 0, "holes": 0, "dark_edge": 0}
    for kind, (meta, by_face) in sets.items():
        if not meta.get("clean"):
            continue
        for F in ("S", "E"):
            for i, f in enumerate(by_face[F]):
                by_face[F][i], log = clean_frame(f)
                for key in clean_log:
                    clean_log[key] += log[key]
    art = sets["walk"][1]
    piv = src["pivot"]

    # Scale: f00 front height above the ground point vs the old static, capped
    # so that walk and idle stay under the 152 sole line. The actions use this
    # same scale (no size jump between walk, idle and actions).
    s_top = alpha_bbox(art["S"][0])[1]
    above_f00 = piv["S"][1] - s_top
    k = OLD_STATIC_ABOVE_SOLE[cls] / float(above_f00)

    def extents(kinds: tuple) -> dict:
        ext = {"top": 0, "below": 0, "L": {"S": 0, "E": 0}, "R": {"S": 0, "E": 0}}
        for kind in kinds:
            if kind not in sets:
                continue
            meta, by_face = sets[kind]
            for F in ("S", "E"):
                px, py = meta["pivot"][F]
                for f in by_face[F]:
                    x0, y0, x1, y1 = alpha_bbox(f)
                    ext["top"] = max(ext["top"], py - y0)
                    ext["below"] = max(ext["below"], y1 - py)
                    ext["L"][F] = max(ext["L"][F], px - x0)
                    ext["R"][F] = max(ext["R"][F], x1 - px)
        return ext

    stand = extents(("walk", "idle"))
    k = min(k, MAX_ABOVE / float(stand["top"]), 1.0)

    layout: dict = {}
    reach = max(max(stand["L"].values()), max(stand["R"].values()))
    half = int(math.ceil(reach * k)) + PAD
    stand_cell = (min(2 * half, MAX_CELL), min(FOOT_ROW + int(math.ceil(stand["below"] * k)) + PAD, MAX_CELL))
    for kind in ("walk", "idle"):
        if kind in sets:
            px = stand_cell[0] // 2
            layout[kind] = {"cell": stand_cell, "piv": {"S": (px, FOOT_ROW), "E": (px, FOOT_ROW)}}
    for kind in sets:
        if kind in layout:
            continue
        e = extents((kind,))
        sole = max(FOOT_ROW, int(math.ceil(e["top"] * k)) + PAD)
        lefts = {F: int(math.ceil(e["L"][F] * k)) + PAD for F in ("S", "E")}
        rights = {F: int(math.ceil(e["R"][F] * k)) + PAD for F in ("S", "E")}
        cw = max(lefts[F] + rights[F] for F in ("S", "E"))
        ch = sole + int(math.ceil(e["below"] * k)) + PAD
        if cw > MAX_CELL or ch > MAX_CELL:
            raise SystemExit(f"{cls} {kind} cell {cw}x{ch} is over the {MAX_CELL} cap")
        # Spare width goes to the right of the S/E art (the left after a mirror).
        layout[kind] = {"cell": (cw, ch), "piv": {F: (lefts[F], sole) for F in ("S", "E")}}

    def place(img: Image.Image, src_piv: tuple, cell: tuple, dst_piv: tuple, mirror: bool) -> Image.Image:
        px, py = src_piv
        sw, sh = img.size
        size = (max(1, round(sw * k)), max(1, round(sh * k)))
        small = resize_binary(img, size)
        spx, spy = px * size[0] / sw, py * size[1] / sh
        out = Image.new("RGBA", cell, (0, 0, 0, 0))
        dx, dy = int(round(dst_piv[0] - spx)), int(round(dst_piv[1] - spy))
        # Nothing may leave the cell (the layout above already reserved room).
        x0, y0, x1, y1 = alpha_bbox(small)
        if x0 + dx < 0 or y0 + dy < 0 or x1 + dx >= cell[0] or y1 + dy >= cell[1]:
            raise SystemExit(f"{cls}: a frame leaves its {cell} cell")
        out.alpha_composite(small, (dx, dy))
        return ImageOps.mirror(out) if mirror else out

    pivots: dict = {}
    for kind, (meta, by_face) in sets.items():
        lay = layout[kind]
        cell_w, cell_h = lay["cell"]
        pivots[kind] = {}
        out_dir = os.path.join(ROOT, "art", "characters", cls, kind)
        os.makedirs(out_dir, exist_ok=True)
        for letter in LETTERS:
            F, mirror = LETTER_FROM_ART[letter]
            dst = lay["piv"][F]
            pivots[kind][letter] = [cell_w - dst[0] if mirror else dst[0], dst[1]]
            cells = [place(f, meta["pivot"][F], lay["cell"], dst, mirror) for f in by_face[F]]
            sheet = Image.new("RGBA", (cell_w * len(cells), cell_h), (0, 0, 0, 0))
            for i, c in enumerate(cells):
                sheet.paste(c, (i * cell_w, 0))
            buf = io.BytesIO()
            sheet.save(buf, format="PNG", optimize=True)
            with open(os.path.join(out_dir, f"{cls}_{kind}_{letter}.pngbin"), "wb") as fh:
                fh.write(buf.getvalue())
            if kind == "walk":
                # Standing look: walk f00 of this facing, same cell.
                cells[0].save(os.path.join(ROOT, "art", "characters", cls, f"{cls}_{letter}.png"), optimize=True)

    # Foot speed: both S stances (f00 and f06 contacts).
    # A track that loses the foot reads near zero; drop it against the other.
    stances = [stance_px_per_frame(art["S"], 0), stance_px_per_frame(art["S"], 6)]
    good = [v for v in stances if v >= 0.5 * max(stances)]
    ppf = sum(good) / len(good)
    board_ppf = ppf * k * DRAW_SCALE[cls]
    measured = TILE_STEP_PX / board_ppf
    fpt = min(measured, MAX_LEG_RATE * AUTHORED_FPS * WALK_TILE_SEC)
    wc = layout["walk"]["cell"]
    out = {
        "walk": {
            "cell": list(wc),
            "pivot": [wc[0] // 2, FOOT_ROW],
            "pivots": pivots["walk"],
            "frames": FRAMES,
            "fps": AUTHORED_FPS,
            "loop": True,
            "contact": 0,
            "frames_per_tile": round(fpt, 3),
            "frames_per_tile_no_slide": round(measured, 3),
            "scale": round(k, 4),
            "src_px_per_frame": round(ppf, 3),
            "playback_fps": round(fpt / WALK_TILE_SEC, 2),
            "source": f"{src['branch']} @ {src['commit'][:7]} {src['dir']}",
            "cleaned": clean_log if src.get("clean") else None,
        }
    }
    for kind, a in actions.items():
        cell = layout[kind]["cell"]
        out[kind] = {
            "cell": list(cell),
            "pivot": list(pivots[kind]["e"]),
            "pivots": pivots[kind],
            "frames": int(a["frames"]),
            "fps": float(a["fps"]),
            "loop": bool(a.get("loop", kind == "idle")),
            "scale": round(k, 4),
            "source": f"{a.get('branch', src['branch'])} @ {a.get('commit', src['commit'])[:7]} {a.get('dir', src['dir'])}",
        }
        if "impact" in a:
            out[kind]["impact"] = int(a["impact"])
    return out


def write_specs(specs: dict) -> None:
    lines = [
        "extends RefCounted",
        "",
        "## GENERATED by build_tools/mobile_characters/build_mobile_walks.py.",
        "## Do not edit by hand: re-run the script.",
        "## Painted character strips for the mobile board. One entry per class",
        "## and kind. cell and pivot are in texture px; the pivot is the ground",
        "## point. walk and idle share one cell with the pivot centred on",
        "## Pawn.FOOT_PIVOT_Y (152). Each action kind has its own cell at the same",
        "## scale; its pivot (per facing, in pivots) can sit lower than 152 to give",
        "## a raised weapon head room, or off centre for a body lying on its side.",
        "## frames_per_tile is how many cells one board tile of travel spans: the",
        "## no-slide value (frames_per_tile_no_slide) capped so the legs never",
        "## cycle faster than MAX_LEG_RATE x the authored fps (Mauro 4 Oct 2026,",
        "## natural leg speed; a capped class accepts a small foot slide). impact",
        "## is the 0-based contact cell of an attack or skill.",
        "",
        f"const MAX_LEG_RATE := {MAX_LEG_RATE!r}",
        "",
        "const SPECS := {",
    ]
    for cls in sorted(specs):
        lines.append(f'\t"{cls}": {{')
        for kind in sorted(specs[cls]):
            s = specs[cls][kind]
            lines.append(f'\t\t"{kind}": {{')
            for key in ("cell", "pivot", "pivots", "frames", "fps", "loop", "contact", "impact", "frames_per_tile", "frames_per_tile_no_slide", "scale", "source"):
                if key not in s:
                    continue
                v = s[key]
                if isinstance(v, dict):
                    val = "{" + ", ".join(f'"{l}": Vector2i({v[l][0]}, {v[l][1]})' for l in LETTERS) + "}"
                elif isinstance(v, list):
                    val = f"Vector2i({v[0]}, {v[1]})"
                elif isinstance(v, bool):
                    val = "true" if v else "false"
                elif isinstance(v, str):
                    val = json.dumps(v)
                elif isinstance(v, float):
                    val = repr(v)
                else:
                    val = str(v)
                lines.append(f'\t\t\t"{key}": {val},')
            lines.append("\t\t},")
        lines.append("\t},")
    lines.append("}")
    lines.append("")
    with open(os.path.join(ROOT, "units", "character_strip_specs.gd"), "w") as fh:
        fh.write("\n".join(lines))


def main() -> int:
    only = set(sys.argv[1:])
    specs: dict = {}
    for cls, kinds in ACTION_SOURCES.items():
        for kind in kinds:
            if kind not in ACTION_KINDS:
                raise SystemExit(f"unknown action kind {kind}")
    for cls, src in WALK_SOURCES.items():
        if only and cls not in only:
            continue
        specs[cls] = build_class(cls, src, ACTION_SOURCES.get(cls, {}))
        w = specs[cls]["walk"]
        print(f"{cls}: cell {w['cell']} scale {w['scale']} src {w['src_px_per_frame']} px/frame "
              f"-> {w['frames_per_tile']} frames/tile (no-slide {w['frames_per_tile_no_slide']}, "
              f"{round(w['frames_per_tile'] / WALK_TILE_SEC, 2)} fps at {WALK_TILE_SEC}s/tile)")
        if w.get("cleaned"):
            print(f"  cleaned walk source: {w['cleaned']}")
        for kind in ACTION_KINDS:
            if kind in specs[cls]:
                a = specs[cls][kind]
                print(f"  {kind}: cell {a['cell']} pivots e{a['pivots']['e']} s{a['pivots']['s']} n{a['pivots']['n']} w{a['pivots']['w']}")
    if only:
        print("partial run: units/character_strip_specs.gd not rewritten")
        return 0
    write_specs(specs)
    return 0


if __name__ == "__main__":
    sys.exit(main())
