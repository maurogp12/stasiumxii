#!/usr/bin/env python3
"""Build the PC painted character sheets from the locked walk and action frames.

Re-run from the repo root:

    python3 build_tools/pc_characters/build_pc_characters.py

PC port of build_tools/mobile_characters/build_mobile_walks.py (origin/mobile,
mobile PRs #263 and #274). The source table (WALK_SOURCES, the action locks)
and the conversion (git reads at pinned commits, the Ironjaw v7 clean pass,
premultiplied resize with binary alpha, pivot alignment, the planted-foot
stride measure) are copied from it unchanged. The source branches do not need
to be checked out. It writes:

  art/characters/painted/<class>/<class>_<kind>_<S|E>.png
      One horizontal sheet per kind and art facing, cells left to right.
      kind is walk, idle, attack, skill, hit or death. Art letters follow the
      locked rule: S = front walking down-right, E = back walking up-right.
      W and N are mirrors and are not on disk: the loaders mirror S and E.
  units/pc_character_specs.gd
      Cell, pivot (per pawn letter), frame count, fps and impact cell for the
      dungeon pawn, and the world walker numbers (draw scale, walk/run/idle
      fps and stride). Generated; do not edit by hand.

Facings. Pawn and world letters: e = down-right, s = down-left, n = up-right,
w = up-left. e <- S, s <- mirror(S), n <- E, w <- mirror(E).

Scale. One bake serves the dungeon pawn and the world walker. The figure's
height above the ground point on walk f00 of the front view matches the old
PC pawn static (art/characters/<class>/<class>_e.png, drawn at Pawn.SPRITE_SCALE
0.5), capped so that walk and idle stay above the 152 sole line and the source
is never upscaled. Every cell is at most MAX_CELL (256) px a side.

World. The world walker draws the same sheets at WORLD_DRAW_SCALE, so the
Ironjaw stands WORLD_IRONJAW_HEIGHT px tall on screen at zoom 1 (the height of
the old ironjaw_tall hero) and the other classes keep their pawn proportions.
Ground speed stays the #271 hero pace (55.10 px/s walking, 109.59 px/s
running). The walk stride is the measured planted-foot travel of one cycle,
so the foot does not skate, unless that needs the legs to cycle faster than
MAX_LEG_RATE x the authored 17.144 fps (Mauro, natural leg speed on mobile).
Then the leg rate is capped and the stride grows to keep the pace (a small
foot slide). The run is the same walk sheet, played faster (capped at
RUN_LEG_RATE x the authored fps) with a longer stride. The idle is the painted
idle at the authored fps.

Dungeon. The pawn plays the painted idle (standing loop), walk, attack, skill
(as `cast`), hit and death. walk and idle share one cell, pivot centred on the
152 sole line. Each action kind has its own tight cell; its pivot can sit
lower than 152 (head room for a raised weapon) or off centre (a body lying on
its side). The walk plays at frames_per_tile cells per board tile, the no-slide
rate capped at MAX_LEG_RATE x the authored fps, like mobile.
"""
from __future__ import annotations

import io
import json
import math
import os
import subprocess
import sys

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# --- Locked sources: copied from build_tools/mobile_characters/build_mobile_walks.py
# (origin/mobile 132e676b). Commits are pinned so a re-run gives the same bytes.
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
FOOT_ROW = 152  # Pawn sole line: centred 144x160 static, offset (0, -72)
MAX_ABOVE = FOOT_ROW - 1
PAD = 2
MAX_CELL = 256  # memory cap per cell side (same as mobile)

# Old PC pawn statics (art/characters/<class>/<class>_<e|s>.png on
# pc/world-zones fabeb25): rows above the 152 sole line, mean of the front
# views e and s (alpha > 20). Kept as numbers so a re-run gives the same scale.
PC_STATIC_ABOVE_SOLE = {
    "bastion": (133 + 136) / 2.0,
    "kestrel": (119 + 119) / 2.0,
    "gloam": (120 + 120) / 2.0,
    "mender": (120 + 118) / 2.0,
    "ironjaw": (137 + 137) / 2.0,
}

# Dungeon pawn (units/pawn.gd).
PAWN_SPRITE_SCALE = 0.5
PAWN_WALK_TILE_SEC = 0.22
TILE_STEP_PX = math.hypot(32.0, 16.0)  # board/tile.gd 64x32 diamond

# Leg rate caps (Mauro 4 Oct 2026, "natural leg speed" on mobile).
MAX_LEG_RATE = 1.6
RUN_LEG_RATE = 2.0

# World walker (scenes/world/crosshaven/crosshaven_walker.gd, #271).
# The old ironjaw_tall hero stood 62.7 px above the ground at zoom 1
# (idle_s rows 26..216 at scale 0.33).
WORLD_IRONJAW_HEIGHT = 62.7
HERO_WALK_PACE = 2.2
HERO_RUN_PACE = 2.0
WALK_ANIM_CAP = 1.8
# On-screen hero speed kept from #271 (walker.speed_of): px/s.
WORLD_WALK_SPEED = 55.1034
WORLD_RUN_SPEED = 109.593

# pawn letter -> (source letter, mirrored)
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



def walk_stride_scale() -> float:
    return max(1.0, HERO_WALK_PACE / WALK_ANIM_CAP)


def anim_scale(gait: str) -> float:
    if gait == "run":
        return HERO_RUN_PACE
    return HERO_WALK_PACE / walk_stride_scale()


def world_gait(gait: str, foot_stride: float) -> dict:
    """Authored fps and stride for one world gait, as world_strips reads them.

    The walker shows fps * anim_scale and a stride of stride * stride_scale,
    and moves at fps * stride / FRAMES * pace. The shown stride is the foot's
    own travel per cycle (no skate) unless the leg rate would pass the cap.
    """
    speed = WORLD_RUN_SPEED if gait == "run" else WORLD_WALK_SPEED
    cap = (RUN_LEG_RATE if gait == "run" else MAX_LEG_RATE) * AUTHORED_FPS
    leg = speed * FRAMES / foot_stride
    capped = leg > cap
    if capped:
        leg = cap
    shown_stride = speed * FRAMES / leg
    stride_mul = 1.0 if gait == "run" else walk_stride_scale()
    return {
        "fps": leg / anim_scale(gait),
        "stride": shown_stride / stride_mul,
        "shown_fps": leg,
        "shown_stride": shown_stride,
        "capped": capped,
    }


def build_class(cls: str, src: dict, actions: dict) -> dict:
    """Walk plus the painted actions for one class, all at one scale.

    Same layout as the mobile build: walk and idle share one cell, pivot
    centred on the 152 sole line; each action kind gets its own tight cell
    with a per-facing pivot. Only the art facings S and E are written.
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

    s_top = alpha_bbox(art["S"][0])[1]
    above_f00 = piv["S"][1] - s_top
    k = PC_STATIC_ABOVE_SOLE[cls] / float(above_f00)

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
    stand_cell = (2 * half, FOOT_ROW + int(math.ceil(stand["below"] * k)) + PAD)
    if stand_cell[0] > MAX_CELL or stand_cell[1] > MAX_CELL:
        raise SystemExit(f"{cls} walk/idle cell {stand_cell} is over the {MAX_CELL} cap")
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
        layout[kind] = {"cell": (cw, ch), "piv": {F: (lefts[F], sole) for F in ("S", "E")}}

    def place(img: Image.Image, src_piv: tuple, cell: tuple, dst_piv: tuple) -> Image.Image:
        px, py = src_piv
        sw, sh = img.size
        size = (max(1, round(sw * k)), max(1, round(sh * k)))
        small = resize_binary(img, size)
        spx, spy = px * size[0] / sw, py * size[1] / sh
        out = Image.new("RGBA", cell, (0, 0, 0, 0))
        dx, dy = int(round(dst_piv[0] - spx)), int(round(dst_piv[1] - spy))
        x0, y0, x1, y1 = alpha_bbox(small)
        if x0 + dx < 0 or y0 + dy < 0 or x1 + dx >= cell[0] or y1 + dy >= cell[1]:
            raise SystemExit(f"{cls}: a frame leaves its {cell} cell")
        out.alpha_composite(small, (dx, dy))
        return out

    out_dir = os.path.join(ROOT, "art", "characters", "painted", cls)
    os.makedirs(out_dir, exist_ok=True)
    pivots: dict = {}
    for kind, (meta, by_face) in sets.items():
        lay = layout[kind]
        cell_w, cell_h = lay["cell"]
        for F in ("S", "E"):
            cells = [place(f, meta["pivot"][F], lay["cell"], lay["piv"][F]) for f in by_face[F]]
            sheet = Image.new("RGBA", (cell_w * len(cells), cell_h), (0, 0, 0, 0))
            for i, c in enumerate(cells):
                sheet.paste(c, (i * cell_w, 0))
            sheet.save(os.path.join(out_dir, f"{cls}_{kind}_{F}.png"), optimize=True)
        pivots[kind] = {}
        for letter in LETTERS:
            F, mirror = LETTER_FROM_ART[letter]
            dst = lay["piv"][F]
            pivots[kind][letter] = [cell_w - dst[0] if mirror else dst[0], dst[1]]

    # Planted-foot travel of the front walk (both S stances, f00 and f06).
    # A track that loses the foot reads near zero; drop it against the other.
    stances = [stance_px_per_frame(art["S"], 0), stance_px_per_frame(art["S"], 6)]
    good = [v for v in stances if v >= 0.5 * max(stances)]
    ppf = sum(good) / len(good)

    # Dungeon pawn: cells per board tile (mobile rule, PC tile time and scale).
    board_ppf = ppf * k * PAWN_SPRITE_SCALE
    measured = TILE_STEP_PX / board_ppf
    fpt = min(measured, MAX_LEG_RATE * AUTHORED_FPS * PAWN_WALK_TILE_SEC)

    # World walker: same sheets at one draw scale for every class.
    out = {"_k": k, "_ppf": ppf, "_clean": clean_log if src.get("clean") else None}
    wc = layout["walk"]["cell"]
    out["walk"] = {
        "cell": list(wc),
        "pivots": pivots["walk"],
        "frames": FRAMES,
        "fps": AUTHORED_FPS,
        "loop": True,
        "frames_per_tile": round(fpt, 3),
        "frames_per_tile_no_slide": round(measured, 3),
        "scale": round(k, 4),
        "source": f"{src['branch']} @ {src['commit'][:7]} {src['dir']}",
    }
    for kind, a in actions.items():
        cell = layout[kind]["cell"]
        out[kind] = {
            "cell": list(cell),
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


def world_numbers(specs: dict) -> dict:
    draw = WORLD_IRONJAW_HEIGHT / PC_STATIC_ABOVE_SOLE["ironjaw"]
    world = {}
    for cls, s in specs.items():
        foot = s["_ppf"] * s["_k"] * draw * FRAMES
        walk = world_gait("walk", foot)
        run = world_gait("run", foot)
        world[cls] = {
            "draw_scale": round(draw, 6),
            "height": round(PC_STATIC_ABOVE_SOLE[cls] * draw, 2),
            "foot_stride": round(foot, 4),
            "walk": {k: (round(v, 6) if isinstance(v, float) else v) for k, v in walk.items()},
            "run": {k: (round(v, 6) if isinstance(v, float) else v) for k, v in run.items()},
            "idle": {"fps": AUTHORED_FPS},
        }
    return world


def _gd(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return json.dumps(v)
    if isinstance(v, float):
        return repr(v)
    if isinstance(v, dict):
        if set(v.keys()) == set(LETTERS):
            return "{" + ", ".join(f'"{l}": Vector2i({v[l][0]}, {v[l][1]})' for l in LETTERS) + "}"
        return "{" + ", ".join(f'"{key}": {_gd(val)}' for key, val in v.items()) + "}"
    if isinstance(v, list):
        return f"Vector2i({v[0]}, {v[1]})"
    return str(v)


def write_specs(specs: dict, world: dict) -> None:
    lines = [
        "extends RefCounted",
        "",
        "## GENERATED by build_tools/pc_characters/build_pc_characters.py.",
        "## Do not edit by hand: re-run the script.",
        "## Painted character sheets for PC (dungeon pawn and world walker).",
        "## Files: art/characters/painted/<class>/<class>_<kind>_<S|E>.png, one",
        "## row of cells. S is the front (down-right, pawn letter e), E the back",
        "## (up-right, n); s and w are mirrors made by the loaders.",
        "## SPECS: cell and per-letter pivot (ground point, texture px), frames,",
        "## fps, loop, impact (0-based contact cell of an attack or skill), and",
        "## frames_per_tile for the pawn walk (no-slide rate capped at",
        "## MAX_LEG_RATE x the authored fps).",
        "## WORLD: the walker's draw scale and gait numbers in the world_strips",
        "## format (fps and stride before the hero pace scales).",
        "",
        f"const MAX_CELL := {MAX_CELL}",
        f"const MAX_LEG_RATE := {MAX_LEG_RATE!r}",
        f"const RUN_LEG_RATE := {RUN_LEG_RATE!r}",
        f"const AUTHORED_FPS := {AUTHORED_FPS!r}",
        "const ART_LETTER := {\"e\": \"S\", \"s\": \"S\", \"n\": \"E\", \"w\": \"E\"}",
        "const MIRRORED := {\"e\": false, \"s\": true, \"n\": false, \"w\": true}",
        "",
        "const SPECS := {",
    ]
    for cls in sorted(specs):
        lines.append(f'\t"{cls}": {{')
        for kind in sorted(k for k in specs[cls] if not k.startswith("_")):
            s = specs[cls][kind]
            lines.append(f'\t\t"{kind}": {{')
            for key in ("cell", "pivots", "frames", "fps", "loop", "impact", "frames_per_tile", "frames_per_tile_no_slide", "scale", "source"):
                if key in s:
                    lines.append(f'\t\t\t"{key}": {_gd(s[key])},')
            lines.append("\t\t},")
        lines.append("\t},")
    lines.append("}")
    lines.append("")
    lines.append("const WORLD := {")
    for cls in sorted(world):
        w = world[cls]
        lines.append(f'\t"{cls}": {{')
        for key in ("draw_scale", "height", "foot_stride", "walk", "run", "idle"):
            lines.append(f'\t\t"{key}": {_gd(w[key])},')
        lines.append("\t},")
    lines.append("}")
    lines.append("")
    with open(os.path.join(ROOT, "units", "pc_character_specs.gd"), "w") as fh:
        fh.write("\n".join(lines))


def main() -> int:
    specs: dict = {}
    for cls, kinds in ACTION_SOURCES.items():
        for kind in kinds:
            if kind not in ACTION_KINDS:
                raise SystemExit(f"unknown action kind {kind}")
    for cls, src in WALK_SOURCES.items():
        specs[cls] = build_class(cls, src, ACTION_SOURCES.get(cls, {}))
    world = world_numbers(specs)
    for cls in sorted(specs):
        s = specs[cls]
        w = world[cls]
        print(f"{cls}: scale {s['walk']['scale']} walk cell {s['walk']['cell']} src {s['_ppf']:.3f} px/frame")
        print(f"  pawn walk {s['walk']['frames_per_tile']} cells/tile (no-slide {s['walk']['frames_per_tile_no_slide']})")
        print(f"  world h {w['height']} px, foot stride {w['foot_stride']}, walk {w['walk']['shown_fps']:.2f} fps x {w['walk']['shown_stride']:.2f} px"
              f"{' (capped)' if w['walk']['capped'] else ''}, run {w['run']['shown_fps']:.2f} fps x {w['run']['shown_stride']:.2f} px{' (capped)' if w['run']['capped'] else ''}")
        if s.get("_clean"):
            print(f"  cleaned walk source: {s['_clean']}")
        for kind in ACTION_KINDS:
            if kind in s:
                print(f"  {kind}: cell {s[kind]['cell']} pivots {s[kind]['pivots']}")
    write_specs(specs, world)
    return 0


if __name__ == "__main__":
    sys.exit(main())
