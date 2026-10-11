#!/usr/bin/env python3
"""Visible gear (paper doll) for PC: build Ironjaw's base body and gear layers.

Re-run from the repo root:

    python3 build_tools/pc_gear/build_ironjaw_gear.py [--work DIR] [--looks ...]

Steps (see art/characters/painted/ironjaw_gear/README.md):
  1. gear_cut.py   paintings -> rig parts (base body, one folder per look).
  2. gear_rig.py   parts -> 512x360 frames through the locked action rig,
                   one strip per look ("over" above the body, "__back" behind).
  3. this script   frames -> game sheets, at the locked Ironjaw scale, one
                   shared layout per kind (union of every strip, so all strips
                   of a kind have the same cell and pivot), and the generated
                   table units/pc_gear_specs.gd (cells, pivots, frame counts,
                   world gait numbers, strips on disk).

Sheets: art/characters/painted/ironjaw_gear/<strip>/ironjaw_<strip>_<kind>_<S|E>.png
(one row of cells like the locked sheets; W and N are mirrored by the loaders).
A strip facing with no pixels in a kind is not written.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import os
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
import gear_cut as GC  # noqa: E402

CLS = "ironjaw"
OUT = os.path.join(ROOT, "art", "characters", "painted", "ironjaw_gear")
SPECS_GD = os.path.join(ROOT, "units", "pc_gear_specs.gd")
# The locked Ironjaw scale (units/pc_character_specs.gd, every kind): the
# unarmoured body is drawn exactly as big as the v7 body.
LOCKED_K = 0.5547
KINDS = ("walk", "idle", "attack", "skill", "hit", "death")
IMPACT = {"attack": 6, "skill": 6}
FRAMES = {"walk": 12, "idle": 12, "attack": 12, "skill": 12, "hit": 8, "death": 13}


def pcb():
    p = os.path.join(ROOT, "build_tools", "pc_characters", "build_pc_characters.py")
    spec = importlib.util.spec_from_file_location("build_pc_characters", p)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def strip_file(strip: str, kind: str, F: str) -> str:
    folder = strip.split("__")[0]
    name = strip.replace("__", "_")
    return os.path.join(OUT, folder, f"{CLS}_{name}_{kind}_{F}.png")


def build(work: str, strips: list[str]):
    B = pcb()
    fr = os.path.join(work, "frames")
    k = LOCKED_K
    piv = (256, 329)
    frames = {}
    for st in strips:
        for kind in KINDS:
            for F in "SE":
                fl = [os.path.join(fr, st, f"{kind}_{F}_f{i:02d}.png") for i in range(FRAMES[kind])]
                if all(os.path.exists(p) for p in fl):
                    frames[(st, kind, F)] = [Image.open(p).convert("RGBA") for p in fl]

    def extents(kinds):
        ext = {"top": 0, "below": 0, "L": {"S": 0, "E": 0}, "R": {"S": 0, "E": 0}}
        for (st, kind, F), fl in frames.items():
            if kind not in kinds:
                continue
            for f in fl:
                if not (np.asarray(f)[..., 3] > 0).any():
                    continue
                x0, y0, x1, y1 = B.alpha_bbox(f)
                ext["top"] = max(ext["top"], piv[1] - y0)
                ext["below"] = max(ext["below"], y1 - piv[1])
                ext["L"][F] = max(ext["L"][F], piv[0] - x0)
                ext["R"][F] = max(ext["R"][F], x1 - piv[0])
        return ext

    layout = {}
    stand = extents(("walk", "idle"))
    if stand["top"] * k > B.MAX_ABOVE:
        raise SystemExit("walk/idle taller than the sole line allows at the locked scale")
    reach = max(max(stand["L"].values()), max(stand["R"].values()))
    half = int(math.ceil(reach * k)) + B.PAD
    cell = (2 * half, B.FOOT_ROW + int(math.ceil(stand["below"] * k)) + B.PAD)
    for kind in ("walk", "idle"):
        layout[kind] = {"cell": cell, "piv": {"S": (cell[0] // 2, B.FOOT_ROW), "E": (cell[0] // 2, B.FOOT_ROW)}}
    for kind in ("attack", "skill", "hit", "death"):
        e = extents((kind,))
        sole = max(B.FOOT_ROW, int(math.ceil(e["top"] * k)) + B.PAD)
        lefts = {F: int(math.ceil(e["L"][F] * k)) + B.PAD for F in "SE"}
        rights = {F: int(math.ceil(e["R"][F] * k)) + B.PAD for F in "SE"}
        cw = max(lefts[F] + rights[F] for F in "SE")
        ch = sole + int(math.ceil(e["below"] * k)) + B.PAD
        layout[kind] = {"cell": (cw, ch), "piv": {F: (lefts[F], sole) for F in "SE"}}
    for kind, lay in layout.items():
        if max(lay["cell"]) > B.MAX_CELL:
            raise SystemExit(f"{kind} cell {lay['cell']} over the {B.MAX_CELL} cap")

    def place(img, cellsz, dst):
        sw, sh = img.size
        size = (max(1, round(sw * k)), max(1, round(sh * k)))
        small = B.resize_binary(img, size)
        spx, spy = piv[0] * size[0] / sw, piv[1] * size[1] / sh
        out = Image.new("RGBA", cellsz, (0, 0, 0, 0))
        dx, dy = int(round(dst[0] - spx)), int(round(dst[1] - spy))
        out.alpha_composite(small, (dx, dy))
        return out

    for d in os.listdir(OUT):
        full = os.path.join(OUT, d)
        if os.path.isdir(full) and d != "source":
            shutil.rmtree(full)
    written = {}
    sheets_S = {}
    for (st, kind, F), fl in sorted(frames.items()):
        lay = layout[kind]
        cells = [place(f, lay["cell"], lay["piv"][F]) for f in fl]
        if not any((np.asarray(c)[..., 3] > 0).any() for c in cells):
            continue
        sheet = Image.new("RGBA", (lay["cell"][0] * len(cells), lay["cell"][1]), (0, 0, 0, 0))
        for i, c in enumerate(cells):
            sheet.paste(c, (i * lay["cell"][0], 0))
        path = strip_file(st, kind, F)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        sheet.save(path, optimize=True)
        written.setdefault(st, {}).setdefault(kind, []).append(F)
        if st == "base" and kind == "walk" and F == "S":
            sheets_S["walk"] = fl
    pivots = {}
    for kind, lay in layout.items():
        cw = lay["cell"][0]
        pivots[kind] = {}
        for letter in B.LETTERS:
            F, mirror = B.LETTER_FROM_ART[letter]
            dst = lay["piv"][F]
            pivots[kind][letter] = [cw - dst[0] if mirror else dst[0], dst[1]]
    # walk numbers, measured on the base walk like the locked build
    walkS = frames[("base", "walk", "S")]
    stances = [B.stance_px_per_frame(walkS, 0), B.stance_px_per_frame(walkS, 6)]
    good = [v for v in stances if v >= 0.5 * max(stances)]
    ppf = sum(good) / len(good)
    board_ppf = ppf * k * B.PAWN_SPRITE_SCALE
    measured = B.TILE_STEP_PX / board_ppf
    fpt = min(measured, B.MAX_LEG_RATE * B.AUTHORED_FPS * B.PAWN_WALK_TILE_SEC)
    draw = B.WORLD_IRONJAW_HEIGHT / B.PC_STATIC_ABOVE_SOLE["ironjaw"]
    foot = ppf * k * draw * B.FRAMES
    world = {
        "draw_scale": round(draw, 6),
        "height": round(B.PC_STATIC_ABOVE_SOLE["ironjaw"] * draw, 2),
        "foot_stride": round(foot, 4),
        "walk": {kk: (round(v, 6) if isinstance(v, float) else v) for kk, v in B.world_gait("walk", foot).items()},
        "run": {kk: (round(v, 6) if isinstance(v, float) else v) for kk, v in B.world_gait("run", foot).items()},
        "idle": {"fps": B.AUTHORED_FPS},
    }
    specs = {}
    for kind in KINDS:
        s = {"cell": list(layout[kind]["cell"]), "pivots": pivots[kind], "frames": FRAMES[kind], "fps": B.AUTHORED_FPS,
             "loop": kind in ("walk", "idle"), "scale": round(k, 4)}
        if kind in IMPACT:
            s["impact"] = IMPACT[kind]
        s["source"] = ("paper doll base: build_tools/pc_gear on the locked rig claude/ironjaw-actions @ 9d784a1"
                       + (", walk on the TA walk joints of art/ironjaw-walk-help @ 0f3eeb8" if kind == "walk" else ""))
        if kind == "walk":
            s["frames_per_tile"] = round(fpt, 3)
            s["frames_per_tile_no_slide"] = round(measured, 3)
        specs[kind] = s
    write_specs(B, specs, world, written)
    return specs, world, written


def write_specs(B, specs, world, written):
    L = [
        "extends RefCounted",
        "",
        "## GENERATED by build_tools/pc_gear/build_ironjaw_gear.py. Do not edit by hand.",
        "## Visible gear (paper doll) sheets: the unarmoured base body of a class and",
        "## one strip per gear look, all with the same cells, pivots and frame counts",
        "## per kind, so the game stacks them on one frame clock.",
        "## Files: art/characters/painted/<class>_gear/<folder>/<class>_<strip>_<kind>_<S|E>.png.",
        "## SPECS and WORLD: same format as units/pc_character_specs.gd.",
        "## STRIPS: strip id -> kind -> the art facings on disk (a facing with no",
        "## pixels in a kind is not written: nothing is drawn there).",
        "",
        "const SPECS := {",
        f'\t"{CLS}": {{',
    ]
    for kind in sorted(specs):
        s = specs[kind]
        L.append(f'\t\t"{kind}": {{')
        for key in ("cell", "pivots", "frames", "fps", "loop", "impact", "frames_per_tile", "frames_per_tile_no_slide", "scale", "source"):
            if key in s:
                L.append(f'\t\t\t"{key}": {B._gd(s[key])},')
        L.append("\t\t},")
    L += ["\t},", "}", "", "const WORLD := {", f'\t"{CLS}": {{']
    for key in ("draw_scale", "height", "foot_stride", "walk", "run", "idle"):
        L.append(f'\t\t"{key}": {B._gd(world[key])},')
    L += ["\t},", "}", "", "const STRIPS := {", f'\t"{CLS}": {{']
    for st in sorted(written):
        kinds = written[st]
        body = ", ".join(f'"{kd}": [{", ".join(json.dumps(F) for F in sorted(kinds[kd]))}]' for kd in sorted(kinds))
        L.append(f'\t\t"{st.replace("__", "_")}": {{{body}}},')
    L += ["\t},", "}", ""]
    with open(SPECS_GD, "w") as fh:
        fh.write("\n".join(L))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", default=os.environ.get("GEAR_WORK", "/tmp/ironjaw_gear_work"))
    ap.add_argument("--looks", default="", help="comma list of look strips to render (default: every family in data/pc/gear_looks.json that has art)")
    ap.add_argument("--skip-render", action="store_true")
    ap.add_argument("--placeholder", default=None, help="family name for tinted stand-in looks (layering tests only, never shipped)")
    ap.add_argument("--families", default=None, help="comma list of set families to cut")
    a = ap.parse_args()
    if not a.skip_render:
        extra = (["--placeholder", a.placeholder] if a.placeholder else []) + (["--families", a.families] if a.families is not None else [])
        subprocess.run([sys.executable, os.path.join(HERE, "gear_cut.py"), "--work", a.work] + extra, check=True)
        fr = os.path.join(a.work, "frames")
        if os.path.isdir(fr):
            shutil.rmtree(fr)
        subprocess.run([sys.executable, os.path.join(HERE, "gear_rig.py"), "--work", a.work, "--looks", a.looks], check=True)
    fr = os.path.join(a.work, "frames")
    strips = sorted(d for d in os.listdir(fr) if os.path.isdir(os.path.join(fr, d)))
    specs, world, written = build(a.work, strips)
    for kind in KINDS:
        print(kind, specs[kind]["cell"], specs[kind]["pivots"])
    print("world", world)
    print("strips", {k: {kk: v for kk, v in w.items()} for k, w in written.items()})
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
