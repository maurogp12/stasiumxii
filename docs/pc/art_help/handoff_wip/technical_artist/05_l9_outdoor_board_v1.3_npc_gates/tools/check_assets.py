#!/usr/bin/env python3
"""Validate Stasium painted PNG assets before importing them into Godot."""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path
from typing import Callable


def _imports():
    try:
        from PIL import Image
        import numpy as np
        return Image, np
    except ImportError:
        print("Pillow/numpy missing; installing with pip --user...", file=sys.stderr)
        subprocess.check_call([sys.executable, "-m", "pip", "install", "--user", "Pillow", "numpy"])
        from PIL import Image
        import numpy as np
        return Image, np


Image, np = _imports()

PASS, WARN, FAIL = 0, 1, 2
STATUS_NAMES = {PASS: "PASS", WARN: "WARN", FAIL: "FAIL"}

JUNGLE = {
    "back_far": ((2048, 1280), "opaque"),
    "back_mid": ((4096, 2560), "back_mid"),
    "front_leaves_left": ((1024, 1440), "rgba"),
    "front_leaves_right": ((1024, 1440), "rgba"),
    "front_leaves_top": ((2560, 480), "rgba"),
    "front_leaves_bottom": ((2560, 480), "rgba"),
    "leaf_shadow": ((1024, 1024), "leaf_shadow"),
    "back_mid_sway": ((2048, 1280), "sway"),
    "front_leaves_left_sway": ((512, 720), "sway"),
    "front_leaves_right_sway": ((512, 720), "sway"),
    "front_leaves_top_sway": ((1280, 240), "sway"),
    "front_leaves_bottom_sway": ((1280, 240), "sway"),
}
COILGATE = {
    "floor_tiles": ((1024, 64), "floor_tiles"),  # v2 route strip: 8 slots a-h
    "glow_mask": ((1024, 64), "glow_mask"),
    "pad_blue": ((128, 96), "pad"),
    "pad_red": ((128, 96), "pad"),
    "light_pillar": ((128, 512), "light_pillar"),
    "room_edge_dark": ((1024, 640), "room_edge_dark"),
}


def luminance(rgb):
    return 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]


class Result:
    def __init__(self, name: str):
        self.name = name
        self.status = PASS
        self.notes: list[str] = []
        self.infos: list[str] = []
        self.dimensions = "?"

    def add(self, status: int, text: str):
        self.status = max(self.status, status)
        self.notes.append(text)

    def info(self, text: str):
        self.infos.append(text)

    def summary(self) -> str:
        parts = self.notes + [f"INFO: {x}" for x in self.infos]
        return "; ".join(parts) if parts else "OK"


def mode_properties(im):
    mode = im.mode
    alpha = "A" in mode or mode in ("LA", "PA")
    # Pillow's I;16* modes are 16-bit channels; I is 32-bit integer.
    if mode.startswith("I;16"):
        depth = 16
    elif mode == "I":
        depth = 32
    elif mode == "F":
        depth = 32
    else:
        depth = 8
    channels = len(im.getbands())
    return mode, alpha, depth, channels


def as_rgb(im):
    return np.asarray(im.convert("RGB"), dtype=np.uint8)


def as_rgba(im):
    return np.asarray(im.convert("RGBA"), dtype=np.uint8)


def require_mode(r: Result, im, allowed: set[str], label: str = "mode"):
    if im.mode not in allowed:
        r.add(FAIL, f"{label} {im.mode}, expected {','.join(sorted(allowed))}")


def check_general(r: Result, im, expected_size):
    mode, has_alpha, depth, _ = mode_properties(im)
    r.dimensions = f"{im.width}x{im.height} {mode}"
    if (im.width, im.height) != expected_size:
        r.add(FAIL, f"dimensions {im.width}x{im.height}, expected {expected_size[0]}x{expected_size[1]}")
    if im.width % 4 or im.height % 4:
        r.add(FAIL, "dimensions are not divisible by 4 (BC7)")
    if depth == 16:
        r.add(WARN, "16-bit per channel; Godot import expects 8-bit")
    elif depth > 16:
        r.add(WARN, f"{depth}-bit channel data; Godot import expects 8-bit")
    if mode == "P":
        r.add(WARN, "palette color mode; convert to explicit RGB/RGBA before import")

    if mode in ("RGBA", "LA", "PA") or has_alpha:
        rgba = as_rgba(im)
        alpha_halo(r, rgba)


def alpha_halo(r: Result, rgba):
    rgb = rgba[..., :3].astype(np.float32)
    alpha = rgba[..., 3]
    transparent = alpha == 0
    if np.any(transparent):
        trgb = rgb[transparent]
        if np.all(trgb == 0):
            r.info("fully transparent RGB values are all black (Godot fix_alpha_border can bleed them)")
        else:
            r.info("fully transparent pixels contain non-black RGB values")

    semi = (alpha > 0) & (alpha < 255)
    if np.count_nonzero(semi) >= 16:
        # This is intentionally a heuristic: premultiplied art keeps color <= alpha.
        premul_fraction = np.mean(np.all(rgb[semi] <= alpha[semi, None] + 1, axis=1))
        if premul_fraction >= 0.98:
            r.add(WARN, f"possible premultiplied alpha ({premul_fraction * 100:.0f}% of semi-transparent pixels RGB<=alpha)")

    # Opaque pixels adjacent to transparent pixels are edge samples too.  Use an
    # 8-neighbour dilation without requiring scipy.
    near_zero = np.zeros_like(transparent)
    near_zero[:-1, :] |= transparent[1:, :]
    near_zero[1:, :] |= transparent[:-1, :]
    near_zero[:, :-1] |= transparent[:, 1:]
    near_zero[:, 1:] |= transparent[:, :-1]
    near_zero[:-1, :-1] |= transparent[1:, 1:]
    near_zero[1:, 1:] |= transparent[:-1, :-1]
    near_zero[:-1, 1:] |= transparent[1:, :-1]
    near_zero[1:, :-1] |= transparent[:-1, 1:]
    edge = ((alpha >= 10) & (alpha <= 245)) | ((alpha == 255) & near_zero)
    interior = (alpha == 255) & ~edge
    if np.count_nonzero(edge) and np.count_nonzero(interior):
        edge_l = float(np.mean(luminance(rgb[edge])))
        interior_l = float(np.mean(luminance(rgb[interior])))
        delta = edge_l - interior_l
        if delta < -40:
            r.add(WARN, f"alpha halo: edge is {abs(delta):.1f} luminance darker than opaque interior")
        elif delta > 40:
            r.add(WARN, f"alpha halo: edge is {delta:.1f} luminance brighter than opaque interior")


def diamond_mask(width=128, height=64):
    yy, xx = np.indices((height, width), dtype=np.float32)
    # Pixel centres make the outermost inside band deterministic and include
    # the actual diamond edge pixels used by the 128x64 art spec.
    return (np.abs(xx - (width - 1) / 2) / (width / 2) +
            np.abs(yy - (height - 1) / 2) / (height / 2)) <= 1.0 + 1e-6


def check_back_mid(r: Result, im):
    require_mode(r, im, {"RGBA"}, "back_mid mode")
    if im.mode != "RGBA":
        return
    a = np.asarray(im.getchannel("A"), dtype=np.uint8)
    h, w = a.shape
    # Spec v4 (2026-10-03): the ground runs up behind the board's lower half,
    # so only the band ABOVE the corner line (image mid-height) must open onto
    # back_far. Below the corner line ground is expected (0% hole is ideal).
    upper = a[h // 4:h // 2, w // 4:3 * w // 4]
    lower = a[h // 2:3 * h // 4, w // 4:3 * w // 4]
    up_t, lo_t = np.mean(upper < 32), np.mean(lower < 32)
    if up_t < 0.30:
        r.add(FAIL, f"hole above corner line too small ({up_t * 100:.1f}% alpha<32, need >=30%)")
    else:
        r.info(f"hole above corner line {up_t * 100:.1f}%")
    if lo_t > 0.10:
        r.add(WARN, f"hole below corner line {lo_t * 100:.1f}% (board may float; want ~0%)")
    else:
        r.info(f"hole below corner line {lo_t * 100:.1f}%")
    edge_names = (("top", a[0, :]), ("bottom", a[-1, :]),
                  ("left", a[:, 0]), ("right", a[:, -1]))
    for name, line in edge_names:
        if np.all(line == 0):
            r.add(WARN, f"{name} edge is fully transparent")
        elif not np.any(line >= 200):
            r.add(FAIL, f"no opaque-ish foliage touches {name} edge")


def check_opaque(r: Result, im, label: str):
    if im.mode in ("RGBA", "LA"):
        a = np.asarray(im.getchannel("A"))
        if np.any(a != 255):
            r.add(FAIL, f"{label} is not opaque (alpha below 255 present)")
    elif "A" in im.getbands():
        r.add(FAIL, f"{label} has unsupported alpha mode {im.mode}")


def check_leaf_shadow(r: Result, im):
    # RGB is tolerated for legacy exports, but non-equal channels need review.
    if im.mode not in ("L", "RGB", "RGBA"):
        r.add(FAIL, f"leaf_shadow mode {im.mode}; expected greyscale")
        return
    a = np.asarray(im.convert("RGB"), dtype=np.uint8)
    if im.mode in ("RGB", "RGBA"):
        rgb = a
        if not (np.all(rgb[..., 0] == rgb[..., 1]) and np.all(rgb[..., 1] == rgb[..., 2])):
            r.add(WARN, "RGB leaf_shadow is not greyscale")
    gray = np.asarray(im.convert("L"), dtype=np.float32)
    if float(np.mean(gray)) <= 150:
        r.add(FAIL, f"not mostly white (mean {np.mean(gray):.1f}, need >150)")
    lr = float(np.mean(np.abs(gray[:, 0] - gray[:, -1])))
    tb = float(np.mean(np.abs(gray[0, :] - gray[-1, :])))
    for name, diff in (("left/right", lr), ("top/bottom", tb)):
        if diff >= 20:
            r.add(FAIL, f"not seamless {name} edge mean abs diff {diff:.1f}")
        elif diff >= 8:
            r.add(WARN, f"seam {name} edge mean abs diff {diff:.1f} (under 20 only)")


def check_sway(r: Result, im):
    require_mode(r, im, {"L"}, "sway mode")


def check_rgba(r: Result, im, label: str):
    require_mode(r, im, {"RGBA"}, f"{label} mode")


def check_diamond_alpha(r: Result, im, region_label: str, slot_count=1):
    if im.mode not in ("RGBA", "LA"):
        return
    a = np.asarray(im.getchannel("A"), dtype=np.uint8)
    # Pads are 128x96: their cell diamond is the bottom 64 rows.
    if a.shape[0] == 96 and a.shape[1] == 128:
        a = a[-64:, :]
    mask = diamond_mask()
    bad = 0
    band_bad = 0
    for slot in range(slot_count):
        sl = a[:, slot * 128:(slot + 1) * 128]
        bad += int(np.count_nonzero(sl[mask] != 255))
        # Approximate the outermost two-pixel inside band by a shrunken
        # normalized diamond; all pixels in it must also remain fully opaque.
        yy, xx = np.indices((64, 128), dtype=np.float32)
        edge_distance = 1 - (np.abs(xx - 63.5) / 64 + np.abs(yy - 31.5) / 32)
        band = mask & (edge_distance <= (2 / 32))
        band_bad += int(np.count_nonzero(sl[band] != 255))
    if bad:
        r.add(FAIL, f"{region_label} diamond has {bad} non-opaque inside pixels (feathered edge)")
    if band_bad:
        r.add(FAIL, f"{region_label} outer 2px diamond band is feathered ({band_bad} pixels)")


def check_floor_tiles(r: Result, im):
    check_rgba(r, im, "floor_tiles")
    if im.size[0] == 1024:
        check_diamond_alpha(r, im, "floor_tiles", slot_count=8)


def check_glow_mask(r: Result, im):
    if im.mode not in ("RGB", "RGBA"):
        r.add(FAIL, f"glow_mask mode {im.mode}; greyscale/L is not allowed")
        return
    arr = as_rgb(im)
    if not np.any(arr[..., 0] > 0):
        r.add(FAIL, "glow_mask R channel is empty")
    if int(arr[..., 1].min()) == int(arr[..., 1].max()):
        r.add(FAIL, "glow_mask G channel is constant")
    route_ports(r, arr)


# Route strip v3 (2026-10-03): a,b plain; c straight, d top/bottom bend, e T, f end,
# g cross, h side bend. An h/v flip of an iso tile is a diagonal mirror
# (h: NE<->NW, SE<->SW; v: NE<->SE, NW<->SW), so each slot's traced port set must be one
# of the orientations reachable by flips from its canonical set.
H_FLIP = {"NE": "NW", "NW": "NE", "SE": "SW", "SW": "SE"}
V_FLIP = {"NE": "SE", "SE": "NE", "NW": "SW", "SW": "NW"}


def _orbit(ports):
    base = frozenset(ports)
    out = set()
    for hf in (False, True):
        for vf in (False, True):
            s = base
            if hf:
                s = frozenset(H_FLIP[p] for p in s)
            if vf:
                s = frozenset(V_FLIP[p] for p in s)
            out.add(s)
    return out


SLOT_PORTS = {
    0: _orbit([]), 1: _orbit([]),
    2: _orbit(["NE", "SW"]),            # straight (h flip gives NW+SE)
    3: _orbit(["NW", "NE"]),            # bend round top corner (v flip: bottom)
    4: _orbit(["NW", "NE", "SE"]),      # T, all 4 via flips
    5: _orbit(["NE"]),                  # end node
    6: _orbit(["NE", "SE", "SW", "NW"]),
    7: _orbit(["NE", "SE"]),            # bend round right corner (h flip: left)
}
SLOT_NAMES = "abcdefgh"


def _bilinear(img, x, y):
    """Sample at continuous coords where pixel i spans [i, i+1) (centre i+0.5).
    A texture flip maps x -> W - x exactly (pixel i -> W-1-i)."""
    h, w = img.shape
    fx, fy = x - 0.5, y - 0.5
    x0, y0 = int(np.floor(fx)), int(np.floor(fy))
    tx, ty = fx - x0, fy - y0

    def px(xx, yy):
        return img[min(max(yy, 0), h - 1), min(max(xx, 0), w - 1)]
    return ((1 - tx) * (1 - ty) * px(x0, y0) + tx * (1 - ty) * px(x0 + 1, y0) +
            (1 - tx) * ty * px(x0, y0 + 1) + tx * ty * px(x0 + 1, y0 + 1))


def route_ports(r: Result, arr):
    h, w = arr.shape[:2]
    if w != 1024 or h != 64:
        return
    R = arr[..., 0].astype(np.float32) / 255.0
    G = arr[..., 1].astype(np.float32) / 255.0
    # exact continuous edge midpoints of a 128x64 diamond (corners at x=0/64/128, y=0/32/64)
    mids = {"NE": (96.0, 16.0), "SE": (96.0, 48.0), "SW": (32.0, 48.0), "NW": (32.0, 16.0)}
    inward = {"NE": (-1.0, 0.5), "SE": (-1.0, -0.5), "SW": (1.0, -0.5), "NW": (1.0, 0.5)}
    along = {"NE": (2.0, 1.0), "SE": (2.0, -1.0), "SW": (2.0, 1.0), "NW": (2.0, -1.0)}
    profiles = []
    for slot in range(8):
        found = set()
        for name, (mx, my) in mids.items():
            ix, iy = inward[name]
            cx, cy = slot * 128 + mx + 3 * ix, my + 3 * iy   # ~3 px inside the edge
            ax, ay = along[name]
            n = np.hypot(ax, ay)
            prof = np.array([_bilinear(R, cx + t * ax / n, cy + t * ay / n) for t in np.arange(-6, 6.5, 1.0)])
            if _bilinear(G, cx, cy) > 0.5:
                found.add(name)
                profiles.append((SLOT_NAMES[slot], name, prof))
        if frozenset(found) not in SLOT_PORTS[slot]:
            r.add(WARN, f"slot {SLOT_NAMES[slot]}: traced ports {sorted(found) or 'none'} not a valid orientation for this slot")
    if profiles:
        ref = np.median(np.stack([p for _, _, p in profiles]), axis=0)
        for sl, name, p in profiles:
            if np.max(np.abs(p - ref)) > 0.20:
                r.add(WARN, f"slot {sl} {name} port profile differs from the others (seam may not join)")
            if np.max(np.abs(p - p[::-1])) > 0.20:
                r.add(WARN, f"slot {sl} {name} port profile is not mirror-symmetric about the exact edge midpoint (breaks under flip)")


def check_pad(r: Result, im):
    check_rgba(r, im, "pad")
    check_diamond_alpha(r, im, "pad bottom", slot_count=1) if im.mode in ("RGBA", "LA") else None


def check_light_pillar(r: Result, im):
    if im.mode not in ("RGB", "RGBA"):
        r.add(FAIL, f"light_pillar mode {im.mode}; expected opaque RGB")
        return
    arr = as_rgb(im).astype(np.float32)
    if im.mode == "RGBA":
        alpha = np.asarray(im.getchannel("A"))
        if np.any(alpha < 255):
            r.add(WARN, "light_pillar has alpha below 255 (expected opaque RGB)")
    top_l = float(np.mean(luminance(arr[:16])))
    bottom_l = float(np.mean(luminance(arr[-16:])))
    if top_l > 32:
        r.add(FAIL, f"top 16 rows are not near black (mean luminance {top_l:.1f})")
    if bottom_l > 32:
        r.add(FAIL, f"bottom 16 rows are not near black (mean luminance {bottom_l:.1f})")
    black_fraction = float(np.mean(np.max(arr, axis=2) <= 2))
    if black_fraction < 0.01:
        r.add(WARN, "little or no pure-black painted background detected")


def check_file(path: Path, expected_size, kind) -> Result:
    r = Result(path.name)
    try:
        with Image.open(path) as im:
            im.load()
            check_general(r, im, expected_size)
            if kind == "opaque":
                check_opaque(r, im, path.stem)
            elif kind == "back_mid":
                check_back_mid(r, im)
            elif kind == "rgba":
                check_rgba(r, im, path.stem)
            elif kind == "sway":
                check_sway(r, im)
            elif kind == "leaf_shadow":
                check_leaf_shadow(r, im)
            elif kind == "floor_tiles":
                check_floor_tiles(r, im)
            elif kind == "glow_mask":
                check_glow_mask(r, im)
            elif kind == "pad":
                check_pad(r, im)
            elif kind == "light_pillar":
                check_light_pillar(r, im)
            # room_edge_dark intentionally uses the general checks only.
    except Exception as exc:
        r.add(FAIL, f"cannot read PNG: {exc}")
    return r


def expected_for(package):
    return JUNGLE if package == "jungle" else COILGATE  # "thunderwell" is the PC name for the coilgate kit


def write_report(report_path: Path, package: str, folder: Path, results: list[Result], missing: list[str], unexpected: list[str]):
    overall = max((r.status for r in results), default=PASS)
    if missing or unexpected:
        overall = max(overall, FAIL)
    lines = [f"# Asset check report: `{package}`", "", f"- Folder: `{folder}`", f"- Overall: **{STATUS_NAMES[overall]}**", "", "| File | Status | Details |", "|---|---|---|"]
    for r in results:
        detail = r.summary().replace("|", "\\|")
        lines.append(f"| `{r.name}` | **{STATUS_NAMES[r.status]}** | {detail} |")
    if missing:
        lines += ["", "## Missing expected files", ""] + [f"- `{x}.png`" for x in missing]
    if unexpected:
        lines += ["", "## Unexpected PNG files", ""] + [f"- `{x}`" for x in unexpected]
    lines += ["", "Status rules: FAIL blocks import; WARN needs review. Dimensions must be divisible by 4 for BC7.", ""]
    report_path.write_text("\n".join(lines), encoding="utf-8")



# ---- props package (2026-10-03): driven by props.json in the folder ----
PROP_OVERHANG = 8          # px at 2x allowed past the footprint's left/right corners
PROP_FRONT_MAX_H = 110     # px at 2x; taller props are back-edge only (placement note)


def check_props(folder: Path) -> tuple[list[Result], list[str], list[str]]:
    import json, colorsys
    meta = json.loads((folder / "props.json").read_text())
    results, missing = [], []
    listed = set()
    for pr in meta["props"]:
        pid = pr["id"]
        r = Result(pr["file_2x"])
        listed |= {pr["file_2x"], pr["file_1x"], f"{pid}_emit.png"}
        f2, f1 = folder / pr["file_2x"], folder / pr["file_1x"]
        if not f2.exists():
            missing.append(pr["file_2x"]); continue
        im = Image.open(f2); im.load()
        r.dimensions = f"{im.size[0]}x{im.size[1]} {im.mode}"
        if im.mode != "RGBA":
            r.add(FAIL, f"mode {im.mode}, need RGBA")
            results.append(r); continue
        a = np.asarray(im, dtype=np.uint8)
        al = a[..., 3]
        if np.any(a[al == 0][:, :3] > 0):
            r.add(WARN, "RGB under alpha 0 is not black (fine if bled on purpose)")
        if list(im.size) != list(pr["size_2x"]):
            r.add(FAIL, f"size {im.size} != props.json size_2x {pr['size_2x']}")
        if f1.exists():
            s1 = Image.open(f1).size
            want = ((im.size[0] + 1) // 2, (im.size[1] + 1) // 2)
            if s1 != want:
                r.add(FAIL, f"1x fallback {s1}, expected {want}")
        else:
            r.add(WARN, "1x fallback missing")
        ax, ay = pr["anchor_px_2x"]
        n = max(pr["footprint_cells"])
        fw = 64 * (pr["footprint_cells"][0] + pr["footprint_cells"][1]) / 2
        ys, xs = np.nonzero(al > 128)
        left, right = xs.min() - ax, xs.max() - ax
        if left < -fw - PROP_OVERHANG or right > fw + PROP_OVERHANG:
            r.add(FAIL, f"art spans {left:.0f}..{right:.0f} px from anchor; footprint corners are at \u00b1{fw:.0f} "
                        f"(anchor not on footprint south tip, or art overhangs the neighbour cell)")
        if abs(ys.max() + 1 - ay) > 4:
            r.add(WARN, f"anchor y {ay} vs lowest opaque row {ys.max()}")
        h = ay - ys.min()
        r.info(f"height {h:.0f}px@2x" + (" (back-edge only)" if h > PROP_FRONT_MAX_H else " (any edge)"))
        if str(pr.get("emissive", "no")).lower() in ("yes", "true", "1"):
            if not (folder / f"{pid}_emit.png").exists():
                r.add(WARN, f"emissive but no {pid}_emit.png (half-size greyscale emission mask for HDR glow)")
            # glow hue check on bright saturated pixels
            rgb = a[..., :3].astype(np.float32) / 255.0
            mx, mn = rgb.max(-1), rgb.min(-1)
            m = (al > 200) & (mx > 0.6) & ((mx - mn) / np.maximum(mx, 1e-6) > 0.5)
            if m.sum() > 20:
                hs = np.array([colorsys.rgb_to_hsv(*px)[0] * 360 for px in rgb[m][::max(1, int(m.sum() // 2000))]])
                bad = np.mean(~(((hs >= 120) & (hs <= 160)) | ((hs >= 215) & (hs <= 235)) | (hs >= 340) | (hs <= 5)))
                if bad > 0.15:
                    r.add(WARN, f"{bad * 100:.0f}% of bright saturated pixels outside green/cobalt/crimson")
        results.append(r)
    unexpected = sorted(p.name for p in folder.glob("*.png") if p.name not in listed)
    return results, missing, unexpected


# ---- glyphs package (2026-10-03, PR #229 board glyphs) ----
GLYPH_PEAK = {"glyph_zone": 0.62, "glyph_deploy": 0.70, "glyph_occupied": 0.62}


def check_glyphs(folder: Path):
    results, missing = [], []
    listed = set()
    for gid, peak in GLYPH_PEAK.items():
        for fname, size in ((f"{gid}@2x.png", (64, 40)), (f"{gid}.png", (32, 20))):
            listed.add(fname)
            f = folder / fname
            if not f.exists():
                missing.append(fname); continue
            r = Result(fname)
            im = Image.open(f); im.load()
            r.dimensions = f"{im.size[0]}x{im.size[1]} {im.mode}"
            if im.size != size:
                r.add(FAIL, f"size {im.size}, expected {size}")
            if im.mode != "RGBA":
                r.add(FAIL, f"mode {im.mode}, need RGBA"); results.append(r); continue
            a = np.asarray(im, dtype=np.float32) / 255.0
            al = a[..., 3]
            if max(al[0].max(), al[-1].max(), al[:, 0].max(), al[:, -1].max()) > 0:
                r.add(FAIL, "1 px border not fully clear (bilinear bleed into neighbour cell)")
            if np.any(a[al == 0][:, :3] > 0):
                r.add(WARN, "RGB under alpha 0 is not black")
            if al.max() > peak + 0.02:
                r.add(FAIL, f"peak alpha {al.max():.2f} above spec {peak:.2f}")
            r.info(f"peak alpha {al.max():.2f} (spec {peak:.2f})")
            results.append(r)
    unexpected = sorted(p.name for p in folder.glob("*.png") if p.name not in listed)
    return results, missing, unexpected


# ---- world package (2026-10-03, WP10a open-world dressing kits) ----
# World kits are NOT combat room-edge props: they live in the open world, are
# y-sorted by their anchor, and canopies / sails / spires may overhang the
# neighbour cells above the base. Driven by atlas_meta.json (Crosshaven schema
# `stasium.art_atlas` v1) plus props.json and animated/anim_meta.json.
WORLD_SIZE_CLASSES_1X = {          # Stasium Bot size classes (1x; 2x = double)
    "tile": (64, 32), "small": (64, 64), "tree": (64, 112), "wide": (96, 80),
    "landmark": (128, 192), "hero": (192, 256),
}
WORLD_SIZE_CLASSES_EXTRA_1X = {    # extensions (not in the Stasium Bot list)
    "border_tall": (96, 128),      # WP10a manifest: snowy pine wall (kind=border only)
    "tree_broad": (112, 128),      # Luca 3 Oct: broad single-cell orchard canopy (kind=tree, sway mask required)
    "landmark_wide": (288, 256),   # Luca 3 Oct: 2x2 landmark with sails / overhang
    "tree_conifer": (96, 128),     # TA 3 Oct: tall single-cell conifer (kind=tree, sway mask required)
}
WORLD_CLASS_KINDS = {"border_tall": ("border",), "tree_broad": ("tree",), "tree_conifer": ("tree",)}   # classes limited to these kinds
WORLD_CLASSES_BY_FOOTPRINT = {
    (1, 1): ("small", "tree", "border_tall", "tree_broad", "tree_conifer"),
    (2, 1): ("wide",), (1, 2): ("wide",),
    (2, 2): ("landmark", "hero", "landmark_wide"),
    (3, 3): ("hero",),
}
WORLD_ANCHOR_X_TOL = 2       # px at 2x
WORLD_BASE_ROWS = 12         # lowest opaque rows (2x) that make the "base"
WORLD_BASE_TOL = 8           # base may sit this far (2x px) outside the footprint diamond
WORLD_GAP_WARN_2X = 24       # anchor-y vs lowest opaque row: WARN above this gap
# Border pieces that must overlap each neighbour (manifest: "art overlaps each
# neighbour by 16 px (1x)"). Keyed by id prefix; value in 1x px.
WORLD_BORDER_OVERLAP_1X = {"border_snowy_pine_wall": 16}
WORLD_BORDER_BASE_OVERLAP_1X = 16   # any kind=border piece: base may run this far into the neighbour (chained runs)
# Per-zone glow palettes (hue ranges in degrees) for emissive props. Read from
# props.json "glow_palette" when present, else this dict.
WORLD_ZONE_GLOWS = {
    "rowanvale": {},                                   # manifest: no emissive props
    "windmere": {"pale_ice_blue": (185, 235), "warm_amber_lantern": (15, 50)},
}
WORLD_NEON = {"electric_cyan": (180, 195), "neon_magenta": (285, 330)}   # S>0.8 and V>0.9
WORLD_NEON_PX = 50           # WARN when at least this many neon pixels


def _hsv_arrays(rgb):
    rgb = rgb.astype(np.float32) / 255.0
    mx, mn = rgb.max(-1), rgb.min(-1)
    d = mx - mn
    s = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.zeros_like(mx)
    nz = d > 1e-6
    rm = nz & (mx == r)
    gm = nz & (mx == g) & ~rm
    bm = nz & ~rm & ~gm
    h[rm] = (60 * ((g[rm] - b[rm]) / d[rm])) % 360
    h[gm] = 60 * ((b[gm] - r[gm]) / d[gm]) + 120
    h[bm] = 60 * ((r[bm] - g[bm]) / d[bm]) + 240
    return h, s, mx


def _in_hue(h, lo, hi):
    return (h >= lo) & (h <= hi) if lo <= hi else (h >= lo) | (h <= hi)


def _neon_counts(rgba):
    h, s, v = _hsv_arrays(rgba[..., :3])
    m = (rgba[..., 3] > 200) & (s > 0.8) & (v > 0.9)
    return {k: int(np.count_nonzero(m & _in_hue(h, lo, hi))) for k, (lo, hi) in WORLD_NEON.items()}


def _footprint_poly_2x(fx: int, fy: int):
    """Footprint diamond corners (N, E, S, W) at 2x, relative to the south tip
    of the footprint's south-most cell (= the prop anchor)."""
    s = np.array([(fx - fy) * 32, (fx + fy - 1) * 16], dtype=np.float32)
    pts = np.array([(0, -16), (fx * 32, (fx - 1) * 16), ((fx - fy) * 32, (fx + fy - 1) * 16),
                    (-fy * 32, (fy - 1) * 16)], dtype=np.float32)
    return (pts - s) * 2


def _dist_outside_poly(px, py, poly):
    """Distance (px) of points outside a convex polygon (0 inside)."""
    n = len(poly)
    inside = np.ones(px.shape, bool)
    dmin = np.full(px.shape, np.inf, dtype=np.float32)
    area = sum(poly[i][0] * poly[(i + 1) % n][1] - poly[(i + 1) % n][0] * poly[i][1] for i in range(n))
    sgn = 1 if area > 0 else -1
    for i in range(n):
        ax, ay = poly[i]
        bx, by = poly[(i + 1) % n]
        cross = (bx - ax) * (py - ay) - (by - ay) * (px - ax)
        inside &= (cross * sgn >= 0)
        ex, ey = bx - ax, by - ay
        t = np.clip(((px - ax) * ex + (py - ay) * ey) / (ex * ex + ey * ey), 0, 1)
        dmin = np.minimum(dmin, np.hypot(px - (ax + t * ex), py - (ay + t * ey)))
    return np.where(inside, 0, dmin)


def _load(path: Path):
    im = Image.open(path)
    im.load()
    return im


def _half(size):
    return ((size[0] + 1) // 2, (size[1] + 1) // 2)


def _check_1x_pair(r: Result, f2: Path, f1: Path, label=""):
    if not f1.exists():
        r.add(FAIL, f"{label}1x fallback missing ({f1.name})")
        return
    im2, im1 = _load(f2), _load(f1)
    if im1.size != _half(im2.size):
        r.add(FAIL, f"{label}1x {im1.size[0]}x{im1.size[1]} is not the exact half of 2x {im2.size[0]}x{im2.size[1]} "
                    f"(want {_half(im2.size)[0]}x{_half(im2.size)[1]})")
        return
    if im1.mode != im2.mode:
        r.add(WARN, f"{label}1x mode {im1.mode} != 2x mode {im2.mode}")
    # content check: area-downsampled 2x vs shipped 1x (alpha, or L)
    ch = "A" if "A" in im2.getbands() else "L"
    if ch in im1.getbands():
        a2 = np.asarray(im2.getchannel(ch).resize(im1.size, Image.BOX), dtype=np.float32)
        a1 = np.asarray(im1.getchannel(ch), dtype=np.float32)
        diff = float(np.mean(np.abs(a2 - a1)))
        if diff > 8:
            r.add(WARN, f"{label}1x {ch} differs from a box-downsample of the 2x (mean |d| {diff:.1f}/255; misaligned?)")


def _alpha_basics(r: Result, rgba):
    al = rgba[..., 3]
    t = al == 0
    if np.any(t):
        if np.any(rgba[t][:, :3] > 0):
            r.info("RGB under alpha 0 is not black (OK only if bled on purpose)")
    semi = (al > 0) & (al < 255)
    if np.count_nonzero(semi) >= 16:
        rgb = rgba[..., :3]
        premul = float(np.mean(np.all(rgb[semi] <= al[semi, None] + 1, axis=1)))
        if premul >= 0.98:
            r.add(WARN, f"possible premultiplied alpha ({premul * 100:.0f}% of semi-transparent px RGB<=alpha); need straight alpha")


def _world_size_class(size_1x, footprint, kind=""):
    allowed = WORLD_CLASSES_BY_FOOTPRINT.get(tuple(footprint), tuple(WORLD_SIZE_CLASSES_1X))
    allowed = tuple(c for c in allowed if kind in WORLD_CLASS_KINDS.get(c, (kind,)))
    allc = {**WORLD_SIZE_CLASSES_1X, **WORLD_SIZE_CLASSES_EXTRA_1X}
    for c in allowed:
        if tuple(allc[c]) == tuple(size_1x):
            return c, allowed
    return None, allowed


def _world_hub_per_frame(strip, frames, squash_y=0.9):
    """Find the rotation hub of each frame of a 4-fold symmetric sail strip:
    alpha centroid, refined by the centre that best matches the frame rotated
    by 90 deg in un-squashed space."""
    fw = strip.size[0] // frames
    out = []
    for i in range(frames):
        fr = strip.crop((i * fw, 0, (i + 1) * fw, strip.size[1])).getchannel("A")
        a = np.asarray(fr, dtype=np.float32)
        ys, xs = np.indices(a.shape)
        tot = a.sum()
        cx, cy = float((xs * a).sum() / tot), float((ys * a).sum() / tot)
        best = (1e9, cx, cy)
        M = np.array([[0, -1 / squash_y], [squash_y, 0]])
        for step, span in ((1.0, 6), (0.25, 1.5)):
            bx, by = best[1], best[2]
            for dx in np.arange(-span, span + 1e-6, step):
                for dy in np.arange(-span, span + 1e-6, step):
                    c = np.array([bx + dx, by + dy])
                    off = c - M @ c
                    rot = fr.transform(fr.size, Image.AFFINE, (M[0, 0], M[0, 1], off[0], M[1, 0], M[1, 1], off[1]),
                                       resample=Image.BILINEAR)
                    cost = float(np.mean(np.abs(np.asarray(rot, dtype=np.float32) - a)))
                    if cost < best[0]:
                        best = (cost, c[0], c[1])
        out.append({"centroid": (cx, cy), "sym": (best[1], best[2]), "sym_cost": best[0]})
    return fw, out


def _schema_diff(meta: dict, ref: dict, region: str) -> list[str]:
    """Diff a region atlas against the reference (Crosshaven) atlas schema."""
    lines = []
    top_ref, top = set(ref), set(meta)
    lines.append(f"- top-level keys missing vs reference: {sorted(top_ref - top) or 'none'}")
    lines.append(f"- top-level keys extra vs reference: {sorted(top - top_ref) or 'none'}")
    for k in ("format", "format_version"):
        ok = meta.get(k) == ref.get(k)
        lines.append(f"- `{k}`: {meta.get(k)!r} ({'matches' if ok else 'DIFFERS from ' + repr(ref.get(k))})")
    want_root = f"res://art/world/{region}/"
    lines.append(f"- `root`: {meta.get('root')!r} ({'OK' if meta.get('root') == want_root else 'expected ' + want_root})")
    for k in ("grid", "files", "anchors"):
        if k in ref and k in meta:
            diff = sorted(kk for kk in set(ref[k]) | set(meta[k]) if ref[k].get(kk) != meta[k].get(kk))
            lines.append(f"- `{k}` block: {'identical to reference' if not diff else 'differs in ' + ', '.join(diff)}")
    for sect in ("tiles", "props"):
        ref_entries, entries = ref.get(sect, []), meta.get(sect, [])
        if not ref_entries:
            continue
        core = set.intersection(*(set(e) for e in ref_entries))
        common = {k for k in set().union(*(set(e) for e in ref_entries))
                  if sum(k in e for e in ref_entries) >= 0.9 * len(ref_entries)}
        miss = {}
        for e in entries:
            for k in sorted(common - set(e)):
                miss.setdefault(k, []).append(e.get("id"))
        extra = sorted(set().union(*(set(e) for e in entries)) - set().union(*(set(e) for e in ref_entries))) if entries else []
        lines.append(f"- `{sect}` ({len(entries)} entries): keys in every reference entry: {sorted(core)}")
        if miss:
            for k, ids in miss.items():
                lines.append(f"  - missing `{k}` (in >=90% of reference {sect}) on {len(ids)}: {', '.join(map(str, ids[:8]))}{' ...' if len(ids) > 8 else ''}")
        else:
            lines.append(f"  - no reference-standard keys missing")
        lines.append(f"  - region-only keys (not in any reference entry): {extra or 'none'}")
        bad_path = [e.get("id") for e in entries
                    if not str(e.get("file", "")).startswith(("tiles/", "props/", "animated/"))
                    or not str(e.get("file_2x", "")).startswith(("tiles/_2x/", "props/_2x/", "animated/_2x/"))]
        lines.append(f"  - file/file_2x not in `<kind>/` + `<kind>/_2x/` layout: {bad_path or 'none'}")
        if sect == "props":
            bad_anchor = [e["id"] for e in entries if not str(e.get("anchor", "")).startswith("image bottom-centre = south tip of cell origin+")]
            lines.append(f"  - anchor string not in reference format: {bad_anchor or 'none'}")
    ra = ref.get("animated", {})
    ma = meta.get("animated", {})
    lines.append(f"- `animated` keys: reference {sorted(ra)}; region {sorted(ma)}")
    return lines


# ---- terrace pieces (2026-10-03, L9 outdoor board kit) ----
# Board height step from the repo (claude/pc-zones-spec @ 6e0c3a4):
#   board/visual_sort.gd:10   const ELEVATION_PIXELS := 10.0   (1x; cell_to_local lifts y by elev*10)
#   board/visual_sort.gd:12   const ELEVATION_Z_SCALE := 8      (z = (x+y)*10 + elev*8)
#   backend/elevation_cost.gd:8-9  MAX_CLIMB 1, MAX_DROP 2 (walk); crosshaven_15 heights are 0..2
# A side face under a 2:1 cell edge (64x32 at 2x) dropping n steps is exactly 64 x (32 + 20n)
# at 2x: h1 64x52, h2 64x72, h3 64x92. SW face top-left = lifted centre + (-64,0), SE face (0,0).
TERRACE_STEP_PX_2X = 20
TERRACE_MAX_DROP = 2                  # faces 1..MAX_DROP are required; L1 asks for 1-3
TERRACE_EDGE_WARN, TERRACE_EDGE_FAIL = 1.5, 4.0   # median |dev| of the top edge vs the cell edge (px@2x)
TERRACE_SEAM_RATIO_WARN = 2.5         # end-column seam diff vs the piece's own adjacent-column diff
TERRACE_FACE_OFFSET_2X = {"SW": (-64, 0), "SE": (0, 0)}
TERRACE_OVERHANG_OFFSET_2X = {"SW": (-64, -8), "SE": (0, -8)}
PROPS_BLOCKS = ("none", "cover", "los")


def _terrace_edge(e: dict):
    for k in ("edge", "face", "id"):
        v = str(e.get(k, "")).upper()
        if "SW" in v or "LEFT" in v:
            return "SW"
        if "SE" in v or "RIGHT" in v:
            return "SE"
    return None


def _terrace_xy(e: dict, key: str, pattern: str):
    import re
    v = e.get(key)
    if isinstance(v, (list, tuple)) and len(v) == 2:
        return int(v[0]), int(v[1])
    m = re.search(pattern, str(e.get("anchor", "")))
    return (int(m.group(1)), int(m.group(2))) if m else None


def _terrace_face_metrics(rgba, edge: str, n: int, step: int):
    al = rgba[..., 3].astype(np.float32) / 255.0
    H, W = al.shape
    yy, xx = np.indices((H, W))
    top = (xx + 0.5) / 2 if edge == "SW" else 32 - (xx + 0.5) / 2
    tdev, bdev = [], []
    for x in range(2, W - 2):
        col = np.nonzero(al[:, x] > 0.5)[0]
        if len(col):
            tdev.append(col.min() - top[0, x]); bdev.append(col.max() + 1 - (top[0, x] + step * n))
    inside = (yy + 0.5 > top + 1.5) & (yy + 0.5 < top + step * n - 1.5)
    outside = (yy + 0.5 < top - 1.5) | (yy + 0.5 > top + step * n + 1.5)
    s_ = step * n
    A, B = (rgba[32:32 + s_, W - 1], rgba[0:s_, 0]) if edge == "SW" else (rgba[0:s_, W - 1], rgba[32:32 + s_, 0])
    A, B = A.astype(np.float32), B.astype(np.float32)
    both = (A[:, 3] > 128) & (B[:, 3] > 128)
    seam = float(np.abs(A[both, :3] - B[both, :3]).mean()) if both.any() else float("nan")
    f = rgba.astype(np.float32)
    inner = [np.abs(f[:, x, :3] - f[:, x + 1, :3])[(f[:, x, 3] > 128) & (f[:, x + 1, 3] > 128)].mean()
             for x in range(4, W - 5) if np.any((f[:, x, 3] > 128) & (f[:, x + 1, 3] > 128))]
    m = rgba[..., 3] > 200
    lum = float(luminance(f[..., :3])[m].mean()) if m.any() else 0.0
    return {"top": float(np.median(np.abs(tdev))) if tdev else 99.0, "top_max": float(np.max(np.abs(tdev))) if tdev else 99.0,
            "bot": float(np.median(np.abs(bdev))) if bdev else 99.0,
            "cov": float((al[inside] > 0.5).mean()) if inside.any() else 0.0,
            "leak": float((al[outside] > 0.1).mean()) if outside.any() else 0.0,
            "seam": seam, "inner": float(np.mean(inner)) if inner else float("nan"), "lum": lum}


def check_terrace(folder: Path, meta: dict, ref):
    """Terrace pieces listed in atlas_meta.terrace[] (+ looks.json cross-check)."""
    import json
    results = []
    entries = meta.get("terrace", []) or []
    if not entries:
        return results
    grid_step = (meta.get("grid") or {}).get("step_px_2x")
    kr = Result("kit:atlas_meta.terrace[]")
    kr.dimensions = f"{len(entries)} pieces"
    if grid_step is not None and grid_step != TERRACE_STEP_PX_2X:
        kr.add(FAIL, f"atlas grid.step_px_2x {grid_step} != board step {TERRACE_STEP_PX_2X} (visual_sort.gd ELEVATION_PIXELS 10 @1x)")
    faces, lums = {}, {}
    by_id = {}
    for e in entries:
        tid = e.get("id", "?")
        by_id[tid] = e
        f2, f1 = ref(e["file_2x"]), ref(e["file"])
        r = Result(e["file_2x"])
        if not f2.exists():
            r.add(FAIL, "2x file missing"); results.append(r); continue
        im = _load(f2)
        r.dimensions = f"{im.size[0]}x{im.size[1]} {im.mode}"
        if im.mode != "RGBA":
            r.add(FAIL, f"mode {im.mode}, need RGBA"); results.append(r); continue
        rgba = np.asarray(im, dtype=np.uint8)
        _alpha_basics(r, rgba)
        if list(e.get("size_2x", [])) != list(im.size):
            r.add(FAIL, f"atlas size_2x {e.get('size_2x')} != file {list(im.size)}")
        kind = str(e.get("kind", e.get("role", "")))
        edge = _terrace_edge(e)
        if kind in ("side", "face"):
            n = e.get("height_steps", e.get("steps"))
            step = e.get("step_px_2x", TERRACE_STEP_PX_2X)
            if not isinstance(n, int) or n < 1:
                r.add(FAIL, f"height_steps/steps {n!r} missing or not a positive int")
                results.append(r); continue
            if step != TERRACE_STEP_PX_2X:
                r.add(FAIL, f"step_px_2x {step} != board step {TERRACE_STEP_PX_2X}")
            want = (64, 32 + TERRACE_STEP_PX_2X * n)
            if im.size != want:
                r.add(FAIL, f"face for {n} step(s) is {im.size[0]}x{im.size[1]}; size class is 64 x (32 + 20n) = {want[0]}x{want[1]} at 2x")
            else:
                r.info(f"size class h{n} {want[0]}x{want[1]} (= 64 x (32 + {TERRACE_STEP_PX_2X}x{n}))")
            if edge is None:
                r.add(FAIL, "cannot tell the edge (SW/left or SE/right); add \"edge\": \"SW\"|\"SE\"")
                results.append(r); continue
            off = _terrace_xy(e, "offset_2x", r"\+ \((-?\d+),\s*(-?\d+)\) at 2x")
            if off is None:
                r.add(WARN, "anchor offset not machine-readable; add \"offset_2x\": [dx, dy] from the lifted cell centre")
            elif tuple(off) != TERRACE_FACE_OFFSET_2X[edge]:
                r.add(FAIL, f"{edge} face offset {list(off)} from the lifted centre; want {list(TERRACE_FACE_OFFSET_2X[edge])}")
            if im.size == want:
                mt = _terrace_face_metrics(rgba, edge, n, TERRACE_STEP_PX_2X)
                msg = f"top edge vs the cell's {edge} edge: median {mt['top']:.1f} px, max {mt['top_max']:.1f} px"
                if mt["top"] > TERRACE_EDGE_FAIL:
                    r.add(FAIL, msg + " (seam with the tile top)")
                elif mt["top"] > TERRACE_EDGE_WARN:
                    r.add(WARN, msg)
                else:
                    r.info(msg)
                if mt["bot"] > TERRACE_EDGE_FAIL:
                    r.add(WARN, f"bottom edge {mt['bot']:.1f} px off the lower cell's edge ({n} step(s) down)")
                if mt["cov"] < 0.98:
                    r.add(WARN, f"face parallelogram only {mt['cov'] * 100:.1f}% opaque (holes show the backdrop)")
                if mt["leak"] > 0.01:
                    r.add(WARN, f"{mt['leak'] * 100:.1f}% of px outside the face parallelogram carry alpha (bleeds onto the tile/neighbour)")
                ratio = mt["seam"] / max(mt["inner"], 1e-3)
                smsg = f"side seam (chained along the {'+x' if edge == 'SW' else '-y'} edge) diff {mt['seam']:.1f} vs inner {mt['inner']:.1f} (x{ratio:.2f})"
                if ratio > TERRACE_SEAM_RATIO_WARN:
                    r.add(WARN, smsg + " - not tileable")
                else:
                    r.info(smsg)
                lums[(edge, n)] = mt["lum"]
            faces.setdefault(edge, set()).add(n)
        elif kind == "overhang":
            off = _terrace_xy(e, "offset_2x", r"\+ \((-?\d+),\s*(-?\d+)\) at 2x")
            if edge and off is not None and tuple(off) != TERRACE_OVERHANG_OFFSET_2X[edge]:
                r.add(WARN, f"overhang offset {list(off)}; kit rule {list(TERRACE_OVERHANG_OFFSET_2X[edge])} (front edge through canvas y 8..40)")
            if edge and im.size == (64, 52):
                al = rgba[..., 3].astype(np.float32) / 255.0
                t, b = [], []
                for x in range(2, 62):
                    col = np.nonzero(al[:, x] > 0.5)[0]
                    d = 8 + (x + 0.5) / 2 if edge == "SW" else 40 - (x + 0.5) / 2
                    if len(col):
                        t.append(d - col.min()); b.append(col.max() + 1 - d)
                cover, hang = float(np.median(t)), float(np.median(b))
                msg = f"lip covers {cover:.1f} px of the top face, hangs {hang:.1f} px over the face"
                if not (2 <= cover <= 10) or not (4 <= hang <= 16):
                    r.add(WARN, msg + " (want ~2-10 / ~4-16 px@2x: must not hide the cell top or a step)")
                else:
                    r.info(msg)
        elif kind in ("overhang_corner", "corner"):
            pv = _terrace_xy(e, "pivot_px_2x", r"canvas \((\d+),\s*(\d+)\) at 2x")
            if pv is None:
                r.add(WARN, "corner pivot not machine-readable; add \"pivot_px_2x\": [x, y] (the cell vertex)")
            elif rgba[pv[1], pv[0], 3] < 128:
                r.add(WARN, f"corner pivot {list(pv)} is not covered (alpha {rgba[pv[1], pv[0], 3]})")
            else:
                r.info(f"corner pivot {list(pv)} covered")
        else:
            r.info(f"terrace kind {kind!r} not checked")
        _check_1x_pair(r, f2, f1)
        results.append(r)
    # set-level: height classes per edge, light direction
    for edge in ("SW", "SE"):
        have = sorted(faces.get(edge, set()))
        need = set(range(1, TERRACE_MAX_DROP + 1))
        if need - set(have):
            kr.add(FAIL, f"{edge} faces for step(s) {sorted(need - set(have))} missing (board MAX_DROP {TERRACE_MAX_DROP})")
        kr.info(f"{edge} face classes h{have}")
    for n in sorted({k[1] for k in lums}):
        if ("SW", n) in lums and ("SE", n) in lums:
            sw, se = lums[("SW", n)], lums[("SE", n)]
            if sw <= se:
                kr.add(WARN, f"h{n}: SW face (key side) mean luma {sw:.0f} <= SE face {se:.0f}; key light is top-left")
            else:
                kr.info(f"h{n}: SW luma {sw:.0f} > SE {se:.0f} (key top-left OK)")
    results.append(kr)
    # looks.json cross-check: each face's step count == height drop to that neighbour
    lp = folder / "looks.json"
    if lp.exists():
        lr = Result("kit:looks.json terrace")
        lk = json.loads(lp.read_text())
        cells = {(c["x"], c["y"]): c for c in lk.get("cells", [])}
        lr.dimensions = f"{len(cells)} cells"
        bad, unknown, missing_faces, n_faces = [], set(), [], 0
        for (x, y), c in cells.items():
            h = int(c.get("height", 0))
            listed_faces = {}
            for tid in c.get("terrace", []) or []:
                e = by_id.get(tid)
                if e is None:
                    unknown.add(tid); continue
                if str(e.get("kind")) in ("side", "face"):
                    listed_faces[_terrace_edge(e)] = int(e.get("height_steps", e.get("steps", 0)))
            for edge, nb in (("SW", (x, y + 1)), ("SE", (x + 1, y))):
                drop = h - int(cells[nb].get("height", 0)) if nb in cells else None
                got = listed_faces.get(edge)
                if drop is not None and drop > 0:
                    n_faces += 1
                    if got is None:
                        missing_faces.append(f"({x},{y}) {edge} drop {drop}")
                    elif got != drop:
                        bad.append(f"({x},{y}) {edge} h{got} vs drop {drop}")
                elif got is not None and drop is not None:
                    bad.append(f"({x},{y}) {edge} face h{got} but neighbour is not lower")
        if unknown:
            lr.add(FAIL, f"terrace ids not in atlas_meta.terrace[]: {sorted(unknown)}")
        if bad:
            lr.add(FAIL, f"face step != height drop: {', '.join(bad[:8])}")
        if missing_faces:
            lr.add(WARN, f"visible drop without a face: {', '.join(missing_faces[:8])}")
        lr.info(f"{n_faces} visible faces checked against looks.json heights (step {TERRACE_STEP_PX_2X} px@2x)")
        results.append(lr)
    return results


def check_props_blocks(folder: Path, pj: dict, map_tags: Path | None):
    """props.json `blocks` (none|cover|los) must agree with the map data, never drive it."""
    import json
    r = Result("kit:props.json blocks")
    props = pj.get("props", [])
    r.dimensions = f"{len(props)} props"
    # combat-board kits only (a looks.json per-cell layer, or any prop already carrying `blocks`);
    # world-zone kits (WP10a etc.) are not CombatSim boards
    if not props or not ((folder / "looks.json").exists() or any("blocks" in p for p in props)):
        return []
    have = {p["id"]: p.get("blocks") for p in props}
    absent = [k for k, v in have.items() if v is None]
    badv = [f"{k}={v!r}" for k, v in have.items() if v is not None and v not in PROPS_BLOCKS]
    if badv:
        r.add(FAIL, f"blocks must be one of {list(PROPS_BLOCKS)}: {', '.join(badv)}")
    if absent:
        r.add(WARN, f"{len(absent)}/{len(props)} props have no `blocks` field (spec: blocks none|cover|los, must agree with "
                    f"the map data; Crosshaven map data marks every prop paint_only, so today every value is `none`)")
    lp = folder / "looks.json"
    if map_tags and map_tags.exists() and lp.exists():
        tags = json.loads(map_tags.read_text())
        tcell = {(c["x"], c["y"]): c for c in tags.get("cells", [])}
        lk = json.loads(lp.read_text())
        mism = []
        for pl in list(lk.get("props", [])) + list(lk.get("decor", [])):
            pid = pl.get("new_id") or pl.get("id")
            c = tcell.get((pl["x"], pl["y"]), {})
            want = str(c.get("blocks", "none"))      # future map key; absent = paint_only = none
            if want not in PROPS_BLOCKS:
                want = "none"
            got = have.get(pid)
            if got is not None and got != want:
                mism.append(f"{pid}@({pl['x']},{pl['y']}) {got} vs map {want}")
        if mism:
            r.add(FAIL, f"props.json blocks disagrees with the map data: {', '.join(mism[:8])}")
        r.info(f"cross-checked {len(lk.get('props', [])) + len(lk.get('decor', []))} placements against {map_tags.name}")
    else:
        r.info("blocks not cross-checked against map data (pass --map-tags <tags.json>)")
    return [r]


def check_world(folder: Path, ref_atlas: Path | None = None, map_tags: Path | None = None):
    import json, re
    meta = json.loads((folder / "atlas_meta.json").read_text())
    pj_path = folder / "props.json"
    pj = json.loads(pj_path.read_text()) if pj_path.exists() else {"props": []}
    am_path = folder / "animated" / "anim_meta.json"
    anims = json.loads(am_path.read_text()).get("animations", {}) if am_path.exists() else {}
    region = meta.get("region", folder.name.split("_")[-1])
    glows = pj.get("glow_palette") or WORLD_ZONE_GLOWS.get(region)
    results, missing, extra_lines = [], [], []
    listed = {"atlas_meta.json", "props.json"}
    pj_by_id = {p["id"]: p for p in pj.get("props", [])}

    def ref(path):
        listed.add(str(path))
        return folder / path

    # ---------- tiles ----------
    for t in meta.get("tiles", []):
        r = Result(t["file_2x"])
        f2, f1 = ref(t["file_2x"]), ref(t["file"])
        if not f2.exists():
            missing.append(t["file_2x"]); continue
        im = _load(f2)
        r.dimensions = f"{im.size[0]}x{im.size[1]} {im.mode}"
        if im.size != (128, 64) or tuple(t.get("size_2x", ())) != (128, 64):
            r.add(FAIL, f"tile 2x size {im.size}, atlas size_2x {t.get('size_2x')}; want 128x64")
        if im.mode != "RGBA":
            r.add(FAIL, f"mode {im.mode}, need RGBA")
        else:
            rgba = np.asarray(im, dtype=np.uint8)
            _alpha_basics(r, rgba)
            a = rgba[..., 3]
            mask = diamond_mask()
            if t.get("kind") == "floor":
                check_diamond_alpha(r, im, "tile")
            # Crosshaven tiles carry a 1 px seam-closing rim just outside the
            # diamond; only alpha further out than that is a problem.
            yy, xx = np.indices(a.shape)
            edge_d = (np.abs(xx - 63.5) / 64 + np.abs(yy - 31.5) / 32 - 1) * 32
            far = (edge_d > 1.5) & (a > 8)
            if np.count_nonzero(far) > 4:
                r.add(WARN, f"{int(np.count_nonzero(far))} px of alpha more than 1.5 px outside the diamond")
            n = _neon_counts(rgba)
            if any(v >= WORLD_NEON_PX for v in n.values()):
                r.add(WARN, f"neon pixels {n}")
        _check_1x_pair(r, f2, f1)
        results.append(r)

    # ---------- props ----------
    for p in meta.get("props", []):
        pid = p["id"]
        r = Result(p["file_2x"])
        f2, f1 = ref(p["file_2x"]), ref(p["file"])
        if not f2.exists():
            missing.append(p["file_2x"]); continue
        im = _load(f2)
        r.dimensions = f"{im.size[0]}x{im.size[1]} {im.mode}"
        fp = tuple(p.get("footprint_size", (1, 1)))
        if pid not in pj_by_id:
            r.add(WARN, "not listed in props.json (checker index); add it")
        else:
            q = pj_by_id[pid]
            if list(q.get("size_2x", [])) != list(im.size):
                r.add(FAIL, f"props.json size_2x {q.get('size_2x')} != file {list(im.size)}")
            if tuple(q.get("footprint_cells", fp)) != fp:
                r.add(FAIL, f"props.json footprint {q.get('footprint_cells')} != atlas {list(fp)}")
        # size class
        if list(im.size) != list(p.get("size_2x", [])) or [s * 2 for s in p.get("size", [0, 0])] != list(im.size):
            r.add(FAIL, f"file {im.size} vs atlas size {p.get('size')} / size_2x {p.get('size_2x')}")
        cls, allowed = _world_size_class(_half(im.size), fp, p.get("kind", ""))
        if cls is None:
            r.add(FAIL, f"1x canvas {_half(im.size)} matches no size class for footprint {fp[0]}x{fp[1]} kind {p.get('kind')} "
                        f"({', '.join(f'{c} {WORLD_SIZE_CLASSES_1X.get(c) or WORLD_SIZE_CLASSES_EXTRA_1X.get(c)}' for c in allowed)})")
        elif cls in WORLD_SIZE_CLASSES_EXTRA_1X:
            src_ = "WP10a manifest" if cls == "border_tall" else "Luca 3 Oct decision"
            r.info(f"size class {cls} ({src_} extension, not in the Stasium Bot list)")
        else:
            r.info(f"size class {cls}")
        if im.mode != "RGBA":
            r.add(FAIL, f"mode {im.mode}, need RGBA"); results.append(r); continue
        rgba = np.asarray(im, dtype=np.uint8)
        _alpha_basics(r, rgba)
        al = rgba[..., 3]
        W, H = im.size
        # anchor: bottom-centre on the south tip of the south-most footprint cell
        q = pj_by_id.get(pid, {})
        ax, ay = q.get("anchor_px_2x", (W / 2, H))
        poly = _footprint_poly_2x(*fp)
        want_x = W / 2.0   # schema: image bottom-centre = south tip
        if abs(ax - want_x) > WORLD_ANCHOR_X_TOL:
            r.add(FAIL, f"anchor x {ax} is not on the footprint south tip (canvas centre {want_x:.0f} \u00b1{WORLD_ANCHOR_X_TOL})")
        if abs(ay - H) > WORLD_ANCHOR_X_TOL:
            r.add(FAIL, f"anchor y {ay} is not the canvas bottom ({H})")
        ys, xs = np.nonzero(al > 128)
        if not len(ys):
            r.add(FAIL, "no opaque pixels"); results.append(r); continue
        left, right, top = int(xs.min() - ax), int(xs.max() + 1 - ax), int(ys.min() - ay)
        low = int(ys.max())
        # base = lowest WORLD_BASE_ROWS rows of opaque art
        bm = ys > low - WORLD_BASE_ROWS
        bx, by = xs[bm] + 0.5 - ax, ys[bm] + 0.5 - ay
        dist = _dist_outside_poly(bx, by, poly)
        base_tol = WORLD_BASE_TOL + (2 * WORLD_BORDER_BASE_OVERLAP_1X if p.get("kind") == "border" else 0)
        out = dist > base_tol
        bl, br = int(xs[bm].min() - ax), int(xs[bm].max() + 1 - ax)
        if np.count_nonzero(out) > max(5, 0.01 * len(dist)):
            r.add(FAIL, f"base (lowest {WORLD_BASE_ROWS} opaque rows, x {bl}..{br}) leaves the footprint diamond by up to "
                        f"{dist.max():.1f} px ({np.count_nonzero(out)} px beyond \u00b1{base_tol})")
        else:
            r.info(f"base x {bl}..{br}, inside footprint \u00b1{base_tol} (max {dist.max():.1f} px out"
                   + (", border overlap allowance" if base_tol > WORLD_BASE_TOL and dist.max() > WORLD_BASE_TOL else "") + ")")
        fw = poly[:, 0].max()
        kind = p.get("kind", "")
        is_big = kind in ("landmark", "building") or p.get("layer") == "hero" or fp[0] * fp[1] >= 4
        over = [k for k in WORLD_BORDER_OVERLAP_1X if pid.startswith(k)]
        if over:
            want = fw + 2 * WORLD_BORDER_OVERLAP_1X[over[0]]
            half_w = max(-left, right)
            if half_w < want - WORLD_BASE_TOL:
                r.add(WARN, f"border art spans {left}..{right} px (2x); manifest neighbour overlap "
                            f"{WORLD_BORDER_OVERLAP_1X[over[0]]} px@1x needs about \u00b1{want:.0f} "
                            f"(now overlaps by {max(0, (half_w - fw) / 2):.0f} px@1x)")
            elif half_w > want + WORLD_BASE_TOL:
                r.add(WARN, f"border art spans {left}..{right} px, wider than the \u00b1{want:.0f} overlap allowance")
            else:
                r.info(f"border art spans {left}..{right} px (overlap OK)")
        elif left < -fw or right > fw:
            r.info(f"art spans {left}..{right} px above the base (footprint corners \u00b1{fw:.0f}); "
                   + ("landmark may be wider" if is_big else "overhang allowed (y-sort by anchor)"))
        else:
            r.info(f"art spans {left}..{right} px")
        r.info(f"top {top} px")
        # anchor y vs lowest opaque row
        gap = int(ay - (low + 1))
        explained = not np.count_nonzero(out)
        if gap > WORLD_GAP_WARN_2X:
            r.add(WARN, f"lowest opaque row is {gap} px above the anchor (>{WORLD_GAP_WARN_2X} at 2x)")
        elif gap > 4:
            if explained:
                r.info(f"lowest opaque row {gap} px above anchor (base lies on the cell; OK)")
            else:
                r.add(WARN, f"lowest opaque row {gap} px above anchor and base off the footprint")
        # stale art extents in the metadata
        meta_x = p.get("art_x_from_anchor_2x")
        if meta_x and (abs(meta_x[0] - left) > 2 or abs(meta_x[1] - (right - 1)) > 2):
            r.add(WARN, f"atlas art_x_from_anchor_2x {meta_x} is stale (measured {left}..{right - 1})")
        # colour: neon + per-zone glow palette
        n = _neon_counts(rgba)
        if any(v >= WORLD_NEON_PX for v in n.values()):
            r.add(WARN, f"neon pixels (S>0.8, V>0.9): {n}")
        elif any(n.values()):
            r.info(f"a few neon-range pixels (below {WORLD_NEON_PX}): {n}")
        emit = p.get("emit")
        if emit:
            e2 = ref(emit["file_2x"])
            ref(emit["file"])
            if not e2.exists():
                r.add(WARN, f"emit mask missing: {emit['file_2x']}")
            else:
                em = _load(e2)
                if em.mode != "L":
                    r.add(WARN, f"emit mask mode {em.mode}, want L (8-bit grey data)")
                if em.size != im.size:
                    r.add(FAIL, f"emit 2x {em.size} != sprite {im.size}")
                _check_1x_pair(r, e2, folder / emit["file"], "emit ")
                ea = np.asarray(em.convert("L"), dtype=np.float32) / 255.0
                g = (ea > 0.25) & (al > 200)
                if np.count_nonzero(g) > 20 and glows is not None:
                    h, s, v = _hsv_arrays(rgba[..., :3])
                    hh, ss, vv = h[g], s[g], v[g]
                    ok = ss < 0.15  # near-white glow cores are fine
                    for lo, hi in glows.values():
                        ok |= _in_hue(hh, lo, hi)
                    bad = 1 - float(np.mean(ok))
                    white = float(np.mean((ss < 0.12) & (vv > 0.85)))
                    r.info(f"emit cover {np.mean(ea > 0.2) * 100:.1f}%, strength {emit.get('strength_default')}, "
                           f"glow albedo off-palette {bad * 100:.0f}%, on near-white (snow/stone?) {white * 100:.0f}%")
                    if bad > 0.15:
                        r.add(WARN, f"{bad * 100:.0f}% of emit pixels outside the {region} glow palette {list(glows)}")
                    if white > 0.30:
                        r.add(WARN, f"{white * 100:.0f}% of emit pixels sit on near-white albedo (false glow on snow/white stone?)")
        elif glows == {} and str(q.get("emissive", "no")).lower() in ("yes", "true", "1"):
            r.add(WARN, f"emissive, but the {region} manifest has no glow")
        # sway mask (trees, reeds, banners must have one)
        needs_sway = kind == "tree" or "reed" in pid or "banner" in pid
        sm = p.get("sway_mask")
        if sm:
            m2 = ref(sm.replace("sway_masks/", "sway_masks/_2x/"))
            m1 = ref(sm)
            if not m2.exists() or not m1.exists():
                r.add(FAIL, f"sway mask missing ({sm} / _2x)")
            else:
                mk2, mk1 = _load(m2), _load(m1)
                if mk2.mode != "L" or mk1.mode != "L":
                    r.add(FAIL, f"sway mask mode {mk1.mode}/{mk2.mode}, need L (8-bit grey data)")
                if mk1.size != _half(mk2.size):
                    r.add(FAIL, f"sway mask 1x {mk1.size} is not half of 2x {mk2.size}")
                an = anims.get(f"{pid}_sway", {})
                if an and tuple(an.get("frame_size_2x", ())) != mk2.size:
                    r.add(WARN, f"sway mask 2x {mk2.size} != sway frame {an.get('frame_size_2x')}")
                r.info(f"sway mask {mk1.size[0]}x{mk1.size[1]}/{mk2.size[0]}x{mk2.size[1]} L")
        elif needs_sway:
            r.add(WARN, "tree/reed/banner without a sway mask (spec: trees, reeds and banners get sway masks)")
        for a in p.get("animated", []) or []:
            ref(a)
            ref(a.replace("animated/", "animated/_2x/", 1))
        _check_1x_pair(r, f2, f1)
        # windmill hub (meta vs art)
        if "sail_hub_from_anchor_2x" in p:
            r.info(f"meta sail hub {p['sail_hub_from_anchor_2x']} (2x) / {p.get('sail_hub_from_anchor_1x')} (1x)")
        results.append(r)

    # ---------- animated strips ----------
    for name, an in anims.items():
        r = Result(an["file_2x"])
        f2, f1 = ref(an["file_2x"]), ref(an["file"])
        if not f2.exists():
            missing.append(an["file_2x"]); continue
        im = _load(f2)
        r.dimensions = f"{im.size[0]}x{im.size[1]} {im.mode}"
        n = int(an.get("frames", 1))
        fw2, fh2 = an.get("frame_size_2x", (0, 0))
        if im.size != (fw2 * n, fh2):
            r.add(FAIL, f"strip {im.size} != {n} x frame {fw2}x{fh2}")
        if [x * 2 for x in an.get("frame_size", (0, 0))] != [fw2, fh2]:
            r.add(FAIL, f"frame_size {an.get('frame_size')} is not half of frame_size_2x {an.get('frame_size_2x')}")
        if im.mode != "RGBA":
            r.add(FAIL, f"mode {im.mode}, need RGBA")
        else:
            _alpha_basics(r, np.asarray(im, dtype=np.uint8))
        _check_1x_pair(r, f2, f1)
        r.info(f"{n} f @ {an.get('fps')} fps, frame {fw2}x{fh2}")
        if "sail" in name and n > 1:
            if n != 12:
                r.add(FAIL, f"sail strip has {n} frames, spec WP10a wants 12")
            fw, hubs = _world_hub_per_frame(im, n)
            sx = [h["sym"][0] for h in hubs]; sy = [h["sym"][1] for h in hubs]
            cx = [h["centroid"][0] for h in hubs]; cy = [h["centroid"][1] for h in hubs]
            spread = max(max(sx) - min(sx), max(sy) - min(sy))
            r.info(f"hub (symmetry fit) x {min(sx):.1f}..{max(sx):.1f}, y {min(sy):.1f}..{max(sy):.1f} "
                   f"(spread {spread:.2f} px@2x; frame centre {fw2 / 2:.1f},{fh2 / 2:.1f}); "
                   f"alpha centroid x {min(cx):.1f}..{max(cx):.1f}, y {min(cy):.1f}..{max(cy):.1f}")
            if spread > 2:
                r.add(WARN, f"hub pivot wanders {spread:.1f} px@2x across frames")
            mx = np.mean(sx) - fw2 / 2; my = np.mean(sy) - fh2 / 2
            if max(abs(mx), abs(my)) > 2:
                r.add(WARN, f"hub is {mx:+.1f},{my:+.1f} px off the frame centre (meta says frame centre = hub)")
            # where does the static composite put the sails?
            pw = an.get("pairs_with")
            body = next((pp for pp in meta.get("props", []) if pp["id"] == pw), None)
            if body and body.get("sail_hub_from_anchor_2x"):
                bw, bh = body["size_2x"]
                hx, hy = body["sail_hub_from_anchor_2x"]
                fx0, fx1 = hx - fw2 / 2, hx + fw2 / 2
                fy0, fy1 = hy - fh2 / 2, hy + fh2 / 2
                r.info(f"frame {fw2}x{fh2} placed centre-on-hub spans x {fx0:.0f}..{fx1:.0f}, y {fy0:.0f}..{fy1:.0f} "
                       f"from the anchor; body canvas {bw}x{bh} spans x \u00b1{bw / 2:.0f}, y -{bh}..0")
                if fx0 < -bw / 2 or fx1 > bw / 2 or fy0 < -bh or fy1 > 0:
                    r.add(WARN, f"sail frame placed at the hub leaves the {bw}x{bh} body canvas (static fallback would clip)")
                if fw2 != bw:
                    r.info(f"sail frame width {fw2} != body canvas width {bw} (frame-centre = hub convention, like Crosshaven)")
            static = next((pp for pp in meta.get("props", []) if pw and pp.get("derived_from") and pw in pp["derived_from"]), None)
            if body and static and (folder / static["file_2x"]).exists():
                b = np.asarray(_load(folder / body["file_2x"]).convert("RGBA"), dtype=np.float32)
                s = np.asarray(_load(folder / static["file_2x"]).convert("RGBA"), dtype=np.float32)
                diff = (np.abs(s - b).sum(-1) > 30) & (s[..., 3] > 128)
                f0 = np.asarray(im.crop((0, 0, fw2, fh2)).getchannel("A")) > 128
                best = (-1, 0, 0)
                ys_, xs_ = np.nonzero(diff)
                if len(ys_):
                    cy0, cx0 = int(np.mean(ys_)), int(np.mean(xs_))
                    for oy in range(cy0 - fh2 // 2 - 40, cy0 - fh2 // 2 + 41, 2):
                        for ox in range(cx0 - fw2 // 2 - 40, cx0 - fw2 // 2 + 41, 2):
                            y0, x0 = max(oy, 0), max(ox, 0)
                            y1, x1 = min(oy + fh2, diff.shape[0]), min(ox + fw2, diff.shape[1])
                            if y1 <= y0 or x1 <= x0:
                                continue
                            sc = np.count_nonzero(diff[y0:y1, x0:x1] & f0[y0 - oy:y1 - oy, x0 - ox:x1 - ox])
                            if sc > best[0]:
                                best = (sc, ox, oy)
                    sc, ox, oy = best
                    hub_static = (ox + np.mean(sx) - b.shape[1] / 2, oy + np.mean(sy) - b.shape[0])
                    r.info(f"sails frame 0 sit in {static['id']} with hub at ({hub_static[0]:.0f},{hub_static[1]:.0f}) px@2x from the anchor")
                    mh = body.get("sail_hub_from_anchor_2x")
                    m = re.search(r"\((-?\d+),\s*(-?\d+)\) px \(1x\)", an.get("anchor", ""))
                    if mh and (abs(mh[0] - hub_static[0]) > 3 or abs(mh[1] - hub_static[1]) > 3):
                        r.add(WARN, f"meta hub {mh} (2x) != static composite hub ({hub_static[0]:.0f},{hub_static[1]:.0f})")
                    if m and mh and [int(m.group(1)) * 2, int(m.group(2)) * 2] != list(mh):
                        r.add(WARN, f"anim_meta anchor hub ({m.group(1)},{m.group(2)})@1x != atlas {mh}@2x")
        results.append(r)

    # sway masks / shadow strips referenced by anim_meta
    for an in anims.values():
        for k in ("sway_mask",):
            if an.get(k):
                ref(an[k]); ref(an[k].replace("sway_masks/", "sway_masks/_2x/"))

    # ---------- terrace pieces + props blocks (L9 kit) ----------
    results += check_terrace(folder, meta, ref)
    results += check_props_blocks(folder, pj, map_tags)

    all_png = sorted(str(p.relative_to(folder)) for p in folder.rglob("*.png"))
    unexpected = [p for p in all_png if p not in listed]
    if ref_atlas and ref_atlas.exists():
        extra_lines = _schema_diff(meta, json.loads(ref_atlas.read_text()), region)
    return results, missing, unexpected, extra_lines


def write_world_report(report_path: Path, folder: Path, results, missing, unexpected, schema_lines, ref_atlas):
    overall = max((r.status for r in results), default=PASS)
    if missing:
        overall = FAIL
    if unexpected:
        overall = max(overall, WARN)
    counts = {s: sum(r.status == s for r in results) for s in (PASS, WARN, FAIL)}
    lines = ["# Asset check report: `world`", "", f"- Folder: `{folder}`", f"- Overall: **{STATUS_NAMES[overall]}**",
             f"- Files: {len(results)} checked; PASS {counts[PASS]}, WARN {counts[WARN]}, FAIL {counts[FAIL]}",
             "- Rules: size classes (Stasium Bot + WP10a manifest), anchor bottom-centre on the footprint south tip "
             f"(\u00b1{WORLD_ANCHOR_X_TOL} px@2x), base = lowest {WORLD_BASE_ROWS} opaque rows inside the footprint diamond "
             f"\u00b1{WORLD_BASE_TOL} px, overhang above the base allowed, border overlap per manifest, per-zone glow palette, "
             f"neon WARN, exact-half 1x, sway masks L, strips frame-exact; terrace faces 64 x (32 + {TERRACE_STEP_PX_2X}n) at 2x "
             f"(board step {TERRACE_STEP_PX_2X} px@2x = visual_sort.gd ELEVATION_PIXELS 10 @1x), SW offset (-64,0) / SE (0,0) from the lifted centre, "
             f"top edge on the cell edge (WARN > {TERRACE_EDGE_WARN}, FAIL > {TERRACE_EDGE_FAIL} px), seam x{TERRACE_SEAM_RATIO_WARN}, "
             f"faces h1..h{TERRACE_MAX_DROP} per edge, face step == looks.json height drop; props.json blocks none|cover|los agrees with map data.", ""]
    for title, sel in (("Props", "props/"), ("Animated", "animated/"), ("Tiles", "tiles/"), ("Terrace", "terrace/"), ("Kit metadata", "kit:")):
        rows = [r for r in results if r.name.startswith(sel)]
        if not rows:
            continue
        lines += [f"## {title}", "", "| File | Status | Size | Details |", "|---|---|---|---|"]
        for r in rows:
            lines.append(f"| `{r.name}` | **{STATUS_NAMES[r.status]}** | {r.dimensions} | {r.summary().replace('|', chr(92) + '|')} |")
        lines.append("")
    if missing:
        lines += ["## Missing files referenced by the atlas", ""] + [f"- `{x}`" for x in missing] + [""]
    if unexpected:
        lines += ["## PNGs not referenced by atlas_meta / anim_meta", ""] + [f"- `{x}`" for x in unexpected] + [""]
    if schema_lines:
        lines += [f"## atlas_meta.json vs reference schema (`{ref_atlas}`)", ""] + schema_lines + [""]
    lines += ["Status rules: FAIL blocks import; WARN needs review; INFO is measurement only.", ""]
    report_path.write_text("\n".join(lines), encoding="utf-8")


# ---- npc package (2026-10-03): in-game NPC body sprites ----
# Source: ZONES_BUILD_SPEC.md on claude/pc-zones-spec @ 78e6513
#   - 4.5a "NPC look" (L562-619): idle 8-12 f, walk 8 f per direction, talk 6-8 f,
#     2x masters like the Crosshaven v7 kit, locked N/E/S/W rule, "E/W may mirror
#     where the prop allows", readable at zoom 1.0, stills at zoom 1.0 and 1.6.
#   - WP10 "NPC bodies" (L2036-2040): 256x256 canvas at 2x, feet on the
#     bottom-centre pivot, world character scale = ironjaw_tall at 0.33 (PR #214),
#     path art/characters/npc/<role>/idle_<facing>.png (horizontal strip).
#   - 1.3 locked facing rule (L194-195): N = back view up-left, E = back view
#     up-right, S = front view down-right, W = front view down-left.
#   - WP10 style rules (L1989-2000) / WP11 accept (L2056): straight alpha, no
#     RGB under alpha 0, linear filter, no mipmaps, no baked cast shadows.
# Layout (Crosshaven kit convention, like the world package's `<kind>/_2x/`):
#   <role>/<role>.json, <role>/_2x/<anim>_<facing>.png (2x master strips),
#   <role>/<anim>_<facing>.png (1x = exact half). Facing letters lowercase in
#   file names (repo convention: ironjaw_tall_idle_s.png), any case in the json.
NPC_FRAME_2X = (256, 256)              # WP10: 256x256 canvas at 2x
NPC_PIVOT_2X_SUGGESTED = (128, 240)    # TA brief; spec only says "bottom-centre pivot". json is authoritative.
NPC_FACINGS = ("N", "E", "S", "W")
NPC_FACING_VIEW = {"N": "back, up-left", "E": "back, up-right", "S": "front, down-right", "W": "front, down-left"}
NPC_MIRROR_OF = {"W": "S", "S": "W", "N": "E", "E": "N"}   # flip_h partners under the locked rule
NPC_ANIM_FRAMES = {"idle": (8, 12), "walk": (8, 8), "talk": (6, 8)}   # 4.5a (WP10 still says idle 8 f)
NPC_PLANTED = ("idle", "talk")         # feet must stay on the pivot
NPC_IDLE_FPS_SPEC = 8                  # WP10: idle loop at 8 fps (walk/talk fps not specified)
NPC_DIR_2X = "_2x"
NPC_EDGE_MARGIN_2X = 4                 # no alpha > NPC_EDGE_ALPHA within this many px of a frame edge
NPC_EDGE_ALPHA = 0.02
NPC_OPAQUE = 0.5                       # "opaque" for feet / silhouette measurements
NPC_PIVOT_Y_TOL = 3                    # lowest opaque row vs pivot y (px@2x)
NPC_FEET_ROWS = 12                     # bottom rows used for the horizontal feet centroid
NPC_CONTACT_ROWS = 4                   # bottom rows used for planted-feet drift
NPC_FEET_X_WARN, NPC_FEET_X_FAIL = 10, 24
NPC_DRIFT_WARN, NPC_DRIFT_FAIL = 2, 4  # px@2x across idle/talk frames
NPC_1X_DIFF_WARN = 8                   # mean |d| /255, same threshold as world _check_1x_pair
NPC_HALO_BRIGHT_WARN, NPC_HALO_BRIGHT_FAIL = 0.05, 0.15   # share of semi edge px that are a light fringe
NPC_HALO_DARK_WARN = 0.15              # share of semi edge px that are near-black against a lit interior
NPC_ALPHA0_POLICY = "black"            # "black" = WP11 accept (no RGB under alpha 0); "bleed" = TA brief
NPC_NEON_SHARE = 0.01                  # S>0.8 & V>0.9 share of opaque px (world neon thresholds)
NPC_FIGURE_H_2X = (100, 170)           # ironjaw_tall: ~189 px x 0.33 = ~62 px@1x -> ~124 px@2x
NPC_SHADOW_PX_WARN = 120               # dark low-alpha px around the feet row (baked shadow heuristic)
# Feet model (2026-10-03 TA tune, farmer pilot): measure the FEET, not "everything in the
# bottom 12 rows". In the feet band, column runs narrower than NPC_TOOL_MAX_W are a tool
# butt / staff / hem tassel and are ignored; the rest are feet. The support foot is the
# lowest foot. Stance x = midpoint of the outermost feet's sole centroids, so a 3/4
# stance (far foot ~8-12 px higher, depth) and a fork butt on the ground no longer skew it.
NPC_FEET_BAND = 18                     # rows above the pivot (2x) searched for feet
NPC_TOOL_MAX_W = 6                     # px@2x; runs this narrow are not feet
NPC_SOLE_ROWS = 4                      # bottom rows of a foot run used for its sole centroid
NPC_FEET_DEPTH = 14                    # a second foot counts if its sole is within this many rows of the lowest foot
# Contact AO (agreed NPC spec): soft painted ellipse, tint #3b3a66, peak alpha <= 0.3,
# ~70x24 px at 2x, centred on the pivot; no cast shadow.
NPC_AO_TINT = (59, 58, 102)
NPC_AO_TINT_DIST = 45                  # sum |rgb - tint| for a px to count as AO
NPC_AO_PEAK = 0.30
NPC_AO_SIZE_2X = (70, 24)
NPC_AO_SIZE_TOL = 0.5                  # WARN when bbox w is outside (1 +- tol) x spec


def _npc_box_sum(arr, r):
    """Sum over a (2r+1)^2 window (zero padded), via an integral image."""
    p = np.pad(arr.astype(np.float64), ((r + 1, r), (r + 1, r)))
    c = p.cumsum(0).cumsum(1)
    k = 2 * r + 1
    return c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]


def _npc_get(d: dict, *keys, default=None):
    for k in keys:
        if isinstance(d, dict) and k in d:
            return d[k]
    return default


def _npc_facing_key(d: dict, f: str):
    if not isinstance(d, dict):
        return None
    for k in (f, f.lower()):
        if k in d:
            return d[k]
    return None


def _npc_plan(meta: dict, an: dict):
    """facing -> (src, flip_h). Drawn facings map to (F, False)."""
    glob_m = _npc_get(meta, "mirror", "facings", default={}) or {}
    per_m = _npc_get(an, "mirror", "facings", default={}) or {}
    plan = {}
    for f in NPC_FACINGS:
        e = _npc_facing_key(per_m, f)
        if e is None:
            e = _npc_facing_key(glob_m, f)
        if isinstance(e, dict) and ("src" in e or "flip_h" in e):
            src = str(e.get("src", f)).upper()
            plan[f] = (src, e.get("flip_h", False), e)
        else:
            plan[f] = (f, False, e if isinstance(e, dict) else {})
    return plan


def _npc_frames_of(an: dict, f: str):
    pf = _npc_facing_key(_npc_get(an, "facings", "mirror", default={}) or {}, f)
    if isinstance(pf, dict) and "frames" in pf:
        return pf["frames"]
    fr = an.get("frames")
    if isinstance(fr, dict):
        return _npc_facing_key(fr, f)
    return fr


def _npc_find_png(folder: Path, name: str):
    p = folder / name
    if p.exists():
        return p, False
    stem, _, ext = name.rpartition(".")
    alt = folder / (stem[:-1] + stem[-1].upper() + "." + ext)
    if alt.exists():
        return alt, True
    return None, False


def _npc_runs(mask):
    out, s0 = [], None
    for x, v in enumerate(mask):
        if v and s0 is None:
            s0 = x
        elif not v and s0 is not None:
            out.append((s0, x - 1)); s0 = None
    if s0 is not None:
        out.append((s0, len(mask) - 1))
    return out


def _npc_feet(op, py):
    """Feet in one frame (op = opaque mask). Scans the feet band bottom-up with a 3-row
    window; every span wider than NPC_TOOL_MAX_W that does not overlap an already found
    foot becomes a foot (sole x-range + its lowest row). Scanning stops NPC_FEET_DEPTH rows
    above the lowest foot, so a 3/4 far foot (8-12 px higher) is found even when a robe
    joins both legs further up, while a robe hem, a fork tine or a staff butt is not.
    Returns (feet, tools); tools = narrow runs that reach lower than every foot."""
    y0 = max(0, py - NPC_FEET_BAND)
    H = op.shape[0]
    feet, stop = [], y0
    for y in range(H - 1, y0 - 1, -1):
        if feet and y < stop:
            break
        seg = op[max(0, y - 2):y + 1].any(0)
        for a, b in _npc_runs(seg):
            if b - a + 1 <= NPC_TOOL_MAX_W:
                continue
            if any(a <= f["x1"] + 2 and b >= f["x0"] - 2 for f in feet):
                continue
            rows_ = np.nonzero(op[max(0, y - 2):y + 1, a:b + 1].any(1))[0]
            low_ = int(rows_.max()) + max(0, y - 2)          # true sole row inside the window
            yy, xx = np.nonzero(op[max(0, low_ - NPC_SOLE_ROWS + 1):low_ + 1, a:b + 1])
            feet.append({"x0": a, "x1": b, "low": low_, "cx": float(xx.mean() + a + 0.5) if len(xx) else (a + b + 1) / 2})
            if len(feet) == 1:
                stop = low_ - NPC_FEET_DEPTH
    tools = []
    lowest_foot = max((f["low"] for f in feet), default=-1)
    band = op[y0:]
    for x0, x1 in _npc_runs(band.any(0)):
        if x1 - x0 + 1 <= NPC_TOOL_MAX_W:
            low = int(np.nonzero(band[:, x0:x1 + 1].any(1))[0].max()) + y0
            if low > lowest_foot:
                tools.append({"x0": x0, "x1": x1, "low": low})
    return feet, tools


def _npc_frame_metrics(a, pivot):
    """a: frame alpha 0..1. Returns dict or None for an empty frame."""
    op = a > NPC_OPAQUE
    ys, xs = np.nonzero(op)
    if not len(ys):
        return None
    low = int(ys.max())
    bm = ys > low - NPC_FEET_ROWS
    cm = ys > low - NPC_CONTACT_ROWS
    feet, tools = _npc_feet(op, pivot[1])
    if feet:
        sup = max(feet, key=lambda f: f["low"])
        lo_f, hi_f = min(feet, key=lambda f: f["cx"]), max(feet, key=lambda f: f["cx"])
        stance = (lo_f["cx"] + hi_f["cx"]) / 2
        others = [f for f in feet if f is not sup]
        swing = max((sup["low"] - f["low"] for f in others), default=0)
        fx0, fx1 = min(f["x0"] for f in feet), max(f["x1"] for f in feet)
    else:   # no foot-sized run (long robe to the floor etc.): fall back to the old model
        sup = {"low": low, "cx": float(xs[cm].mean() + 0.5)}
        stance, swing = sup["cx"], 0
        fx0, fx1 = int(xs[cm].min()), int(xs[cm].max())
    top = int(ys.min())
    hh = max(1, pivot[1] - top)
    tm = (ys > top + 0.2 * hh) & (ys < top + 0.6 * hh)
    torso_cx = float(xs[tm].mean() + 0.5) if np.any(tm) else float(xs.mean() + 0.5)
    return {"low": low, "top": top, "torso_cx": torso_cx, "feet_cx": float(xs[bm].mean() + 0.5),
            "contact_cx": float(xs[cm].mean() + 0.5), "feet_x0": fx0, "feet_x1": fx1,
            "n_feet": len(feet), "n_tools": len(tools), "support_low": int(sup["low"]),
            "support_cx": float(sup["cx"]), "stance_cx": float(stance), "swing_lift": int(swing)}


def _npc_ao(rgba, pivot):
    """Contact-AO pixels (tint-matched, low alpha, near the pivot row) in one frame."""
    al = rgba[..., 3].astype(np.int32)
    d = np.abs(rgba[..., :3].astype(np.int32) - np.array(NPC_AO_TINT)).sum(-1)
    m = (al > 0) & (al <= int(round(255 * 0.5))) & (d <= NPC_AO_TINT_DIST)
    # drop the 1 px anti-aliased ring of the figure (the painted contour uses the same cool tint)
    m &= _npc_box_sum((al > 127).astype(np.float32), 1) == 0
    m[:max(0, pivot[1] - NPC_FEET_BAND)] = False
    if np.count_nonzero(m) < 12:
        return None
    ys, xs = np.nonzero(m)
    return {"w": int(xs.max() - xs.min() + 1), "h": int(ys.max() - ys.min() + 1),
            "peak": float(al[m].max()) / 255.0, "cx": float(xs.mean() + 0.5), "cy": float(ys.mean() + 0.5), "mask": m}


def _npc_strip_pixels(r: Result, rgba, fw: int, fh: int, n: int, pivot, anim: str, label: str):
    """Per-frame checks on a 2x strip: gaps, edge margin, pivot / feet, drift, shadow, AO."""
    al = rgba[..., 3].astype(np.float32) / 255.0
    mets, empty, edge_bad = [], [], []
    m = NPC_EDGE_MARGIN_2X
    lum = luminance(rgba[..., :3].astype(np.float32))
    shadow_px, aos = [], []
    yy_, xx_ = np.indices((fh, fw))
    # spec AO envelope: 1.3x the agreed ellipse, centred on the pivot
    env = (((xx_ + 0.5 - pivot[0]) / (NPC_AO_SIZE_2X[0] * 0.65)) ** 2
           + ((yy_ + 0.5 - pivot[1]) / (NPC_AO_SIZE_2X[1] * 0.65)) ** 2) <= 1.0
    for k in range(n):
        a = al[:, k * fw:(k + 1) * fw]
        if a.shape[1] != fw:
            break
        if not np.any(a > NPC_EDGE_ALPHA):
            empty.append(k); mets.append(None); continue
        band = np.ones_like(a, bool)
        band[m:fh - m, m:fw - m] = False
        nb = int(np.count_nonzero(band & (a > NPC_EDGE_ALPHA)))
        if nb:
            edge_bad.append((k, nb))
        mt = _npc_frame_metrics(a, pivot)
        mets.append(mt)
        aos.append(_npc_ao(rgba[:, k * fw:(k + 1) * fw], pivot))
        if mt:
            y0, y1 = max(0, pivot[1] - 3), min(fh, pivot[1] + 11)
            L = lum[y0:y1, k * fw:(k + 1) * fw]
            aa = a[y0:y1]
            xx = np.arange(fw)[None, :]
            outside = (xx < mt["feet_x0"] - 4) | (xx > mt["feet_x1"] + 4)
            # spec-conformant contact AO (soft, inside the envelope) is not a cast shadow
            ao_ok = env[y0:y1] & (aa <= NPC_AO_PEAK + 0.02)
            shadow_px.append(int(np.count_nonzero((aa > 0.03) & (aa < 0.7) & (L < 70) & outside & ~ao_ok)))
    if empty:
        r.add(FAIL, f"{label}empty frame(s) {empty} (gap in the strip; frames must be contiguous)")
    if edge_bad:
        r.add(FAIL, f"{label}alpha>{NPC_EDGE_ALPHA} within {m} px of the frame edge in frame(s) "
                    + ", ".join(f"{k} ({c} px)" for k, c in edge_bad[:6]) + (" ..." if len(edge_bad) > 6 else ""))
    good = [x for x in mets if x]
    if not good:
        return mets
    px, py = pivot
    planted = anim in NPC_PLANTED
    # (a) nothing may sit more than the tolerance BELOW the ground line (any anim)
    below = [(k, x["low"] - py) for k, x in enumerate(mets) if x and x["low"] - py > NPC_PIVOT_Y_TOL]
    if below:
        r.add(FAIL if planted else WARN, f"{label}art reaches below the pivot row {py} by more than {NPC_PIVOT_Y_TOL} px in frame(s) "
              + ", ".join(f"{k} (+{d})" for k, d in below[:6]))
    # (b) support (lowest) foot on the ground line. Planted anims: FAIL. Walk/actions: WARN,
    #     because one foot is always on the ground in a walk (no flight phase); a lifted
    #     support foot means the whole body hops. The swing foot's lift is INFO only.
    off = [(k, x["support_low"] - py) for k, x in enumerate(mets) if x and x["support_low"] - py < -NPC_PIVOT_Y_TOL]
    if off:
        msg = (f"{label}support (lowest) foot above the pivot row {py} by more than {NPC_PIVOT_Y_TOL} px in frame(s) "
               + ", ".join(f"{k} ({d:+d})" for k, d in off[:8]))
        r.add(FAIL if planted else WARN, msg + ("" if planted else
              " - both feet off the ground: the body hops; keep the planted foot on the pivot row and put the bob in the hips"))
    if not planted:
        sw = max(good, key=lambda x: x["swing_lift"])
        r.info(f"{label}swing/far foot up to {sw['swing_lift']} px above the support foot; support foot rows "
               f"{min(x['support_low'] for x in good)}..{max(x['support_low'] for x in good)}")
    # (c) stance centre (midpoint of the outermost feet) vs pivot x
    # Stance centre is only trusted where two feet are found (one foot is not the centre).
    dx = [(k, x["stance_cx"] - (px + 0.5)) for k, x in enumerate(mets) if x and x["n_feet"] >= 2]
    if dx:
        worst = max(dx, key=lambda t: abs(t[1]))
        smsg = f"{label}stance centre (feet midpoint) {worst[1]:+.1f} px from pivot x {px} (frame {worst[0]})"
        if abs(worst[1]) > NPC_FEET_X_FAIL and planted:
            r.add(FAIL, smsg)
        elif abs(worst[1]) > NPC_FEET_X_WARN and anim in NPC_ANIM_FRAMES:
            r.add(WARN, smsg)
        elif abs(worst[1]) > NPC_FEET_X_WARN:
            r.info(smsg + " (role action anim: a tool head in the ground can read as a foot; not gated)")
    else:
        r.info(f"{label}stance centre not measured (second foot not found in the feet band)")
    # Body (torso band) centre vs pivot x: W = S flipped and E = N flipped mirror about the
    # pivot, so an off-centre body jumps 2x the offset sideways when the facing flips.
    tx = [(k, x["torso_cx"] - (px + 0.5)) for k, x in enumerate(mets) if x]
    tw = max(tx, key=lambda t: abs(t[1]))
    tmsg = f"{label}body centre (torso band) {tw[1]:+.1f} px from pivot x {px} (frame {tw[0]})"
    if abs(tw[1]) > NPC_FEET_X_WARN and anim in NPC_ANIM_FRAMES:
        r.add(WARN, tmsg + f"; the W/E mirror flip jumps the body ~{2 * abs(tw[1]):.0f} px@2x sideways")
    else:
        r.info(tmsg)
    legacy = max(((k, x["feet_cx"] - (px + 0.5)) for k, x in enumerate(mets) if x), key=lambda t: abs(t[1]))
    if abs(legacy[1]) > NPC_FEET_X_WARN and not (dx and abs(worst[1]) > NPC_FEET_X_WARN):
        r.info(f"{label}legacy bottom-{NPC_FEET_ROWS}-row centroid {legacy[1]:+.1f} px (tool butt / 3-4 stance; not gated)")
    # (d) planted drift: support foot row + stance centre (tool butts swaying do not count)
    if planted and len(good) > 1:
        lows = [x["support_low"] for x in good]
        nf = [x["n_feet"] for x in good]
        modal = max(set(nf), key=nf.count)       # frames where the foot count flips are a detection change, not drift
        cxs = [x["stance_cx"] for x in good if x["n_feet"] == modal]
        drift = max(max(lows) - min(lows), max(cxs) - min(cxs))
        txt = f"planted-feet drift {drift:.1f} px@2x (support foot y {min(lows)}..{max(lows)}, stance x {min(cxs):.1f}..{max(cxs):.1f})"
        if drift > NPC_DRIFT_FAIL:
            r.add(FAIL, f"{label}{txt}, limit {NPC_DRIFT_WARN} (FAIL > {NPC_DRIFT_FAIL})")
        elif drift > NPC_DRIFT_WARN:
            r.add(WARN, f"{label}{txt}, limit {NPC_DRIFT_WARN}")
        else:
            r.info(f"{label}{txt}")
    if shadow_px and np.mean(shadow_px) > NPC_SHADOW_PX_WARN:
        r.add(WARN, f"{label}possible baked ground shadow: ~{np.mean(shadow_px):.0f} dark low-alpha px/frame around the feet row "
                    f"outside the feet and outside the soft contact-AO envelope (spec: AO only, no baked cast shadows)")
    # (e) contact AO measurement (role-level consistency is judged in check_npc_role)
    got = [x for x in aos if x]
    r.ao = None
    if got:
        w = max(x["w"] for x in got); h = max(x["h"] for x in got); pk = max(x["peak"] for x in got)
        cx = float(np.mean([x["cx"] for x in got]))
        r.ao = {"w": w, "h": h, "peak": pk, "cx": cx, "frames": len(got), "n": len(aos)}
        r.info(f"{label}contact AO {w}x{h} px@2x, peak alpha {pk:.2f}, centre x {cx:.1f}, in {len(got)}/{len(aos)} frames")
        if pk > NPC_AO_PEAK + 0.02:
            r.add(WARN, f"{label}contact AO peak alpha {pk:.2f} > {NPC_AO_PEAK} (spec: soft AO only)")
    else:
        r.ao = {"w": 0, "h": 0, "peak": 0.0, "cx": None, "frames": 0, "n": len(aos)}
    return mets


def _npc_halo(r: Result, rgba, label=""):
    rgb = rgba[..., :3].astype(np.float32)
    al = rgba[..., 3]
    L = luminance(rgb)
    opaque = (al >= 230).astype(np.float32)
    cnt = _npc_box_sum(opaque, 2)
    loc = _npc_box_sum(opaque * L, 2) / np.maximum(cnt, 1)
    semi = (al >= int(0.02 * 255) + 1) & (al <= 127) & (cnt > 0)
    ns = int(np.count_nonzero(semi))
    if ns >= 30:
        bright = semi & (L - loc > 60) & (L > 170)
        dark = semi & (rgb.max(-1) < 24) & (loc > 50)
        fb, fd = np.count_nonzero(bright) / ns, np.count_nonzero(dark) / ns
        if fb > NPC_HALO_BRIGHT_FAIL:
            r.add(FAIL, f"{label}light/white fringe: {fb * 100:.0f}% of {ns} soft edge px are much brighter than the interior (halo)")
        elif fb > NPC_HALO_BRIGHT_WARN:
            r.add(WARN, f"{label}light fringe on {fb * 100:.0f}% of soft edge px")
        if fd > NPC_HALO_DARK_WARN:
            r.add(WARN, f"{label}near-black fringe on {fd * 100:.0f}% of soft edge px (black matte or premultiplied edge)")
    semi_all = (al > 0) & (al < 255)
    if np.count_nonzero(semi_all) >= 16:
        premul = float(np.mean(np.all(rgb[semi_all] <= al[semi_all, None] + 1, axis=1)))
        if premul >= 0.98:
            r.add(WARN, f"{label}looks premultiplied ({premul * 100:.0f}% of semi px RGB<=alpha); need straight alpha")
    t = al == 0
    near = (_npc_box_sum((al > 0).astype(np.float32), 2) > 0) & t
    nn = int(np.count_nonzero(near))
    if nn:
        white = float(np.mean(rgb[near].min(-1) > 200))
        nonblack = float(np.mean(rgb[near].max(-1) > 0))
        if white > 0.02:
            r.add(WARN, f"{label}{white * 100:.0f}% of alpha-0 px next to the silhouette are white (halo under linear filtering)")
        if NPC_ALPHA0_POLICY == "black" and np.any(rgb[t].max(-1) > 0):
            allnb = float(np.mean(rgb[t].max(-1) > 0))
            r.add(WARN, f"{label}RGB under alpha 0 is not black ({allnb * 100:.1f}% of alpha-0 px, {nonblack * 100:.0f}% next to the silhouette); "
                        f"WP11 accept says no RGB under alpha 0 (Godot fix_alpha_border bleeds on import)")


def _npc_neon(r: Result, rgba, label=""):
    h, s, v = _hsv_arrays(rgba[..., :3])
    op = rgba[..., 3] > 200
    n_op = int(np.count_nonzero(op))
    if not n_op:
        return
    m = op & (s > 0.8) & (v > 0.9)
    share = np.count_nonzero(m) / n_op
    hues = {k: int(np.count_nonzero(m & _in_hue(h, lo, hi))) for k, (lo, hi) in WORLD_NEON.items()}
    if share > NPC_NEON_SHARE:
        r.add(WARN, f"{label}neon-bright pixels (S>0.8, V>0.9) are {share * 100:.1f}% of opaque area "
                    f"(> {NPC_NEON_SHARE * 100:.0f}%; guide lock: painted fantasy, no neon); cyan/magenta {hues}")
    elif share > 0:
        r.info(f"{label}neon-bright px {share * 100:.2f}% (cyan/magenta {hues})")


def _npc_1x(r: Result, f2: Path, f1: Path | None, fw: int, fh: int):
    if f1 is None or not f1.exists():
        r.add(FAIL, "1x strip missing" + (f" ({f1.name})" if f1 else ""))
        return
    im2, im1 = _load(f2), _load(f1)
    want = _half(im2.size)
    if im1.size != want:
        r.add(FAIL, f"1x {im1.size[0]}x{im1.size[1]} is not the exact half of 2x {im2.size[0]}x{im2.size[1]} (want {want[0]}x{want[1]})")
        return
    if im1.mode != "RGBA":
        r.add(FAIL, f"1x mode {im1.mode}, need RGBA")
        return
    d2 = np.asarray(im2.convert("RGBA").resize(im1.size, Image.BOX), dtype=np.float32)
    d1 = np.asarray(im1, dtype=np.float32)
    da = float(np.mean(np.abs(d2[..., 3] - d1[..., 3])))
    both = (d1[..., 3] > 200) & (d2[..., 3] > 200)
    dc = float(np.mean(np.abs(d2[..., :3][both] - d1[..., :3][both]))) if np.any(both) else 0.0
    if da > NPC_1X_DIFF_WARN or dc > 2 * NPC_1X_DIFF_WARN:
        r.add(WARN, f"1x differs from a box-downsample of the 2x (alpha mean |d| {da:.1f}, colour {dc:.1f} /255; misaligned or repainted?)")
    else:
        r.info(f"1x matches 2x downsample (alpha |d| {da:.1f}, colour {dc:.1f})")
    a1 = d1[..., 3] / 255.0
    m1 = max(1, NPC_EDGE_MARGIN_2X // 2)
    hw, hh = fw // 2, fh // 2
    for k in range(im1.size[0] // max(hw, 1)):
        fr = a1[:, k * hw:(k + 1) * hw]
        band = np.ones_like(fr, bool); band[m1:hh - m1, m1:hw - m1] = False
        if np.any(band & (fr > NPC_EDGE_ALPHA)):
            r.add(WARN, f"1x frame {k} has alpha within {m1} px of the frame edge")
            break


def check_npc_role(folder: Path, make_sheet=True, previews: Path | None = None, backdrop: Path | None = None):
    """Returns (results, missing, unexpected, info_lines, sheet_paths)."""
    import json
    role = folder.name
    jr = Result(f"{role}/{role}.json")
    results, missing, unexpected, lines, sheets = [jr], [], [], [], []
    jpath = folder / f"{role}.json"
    if not jpath.exists():
        js = sorted(folder.glob("*.json"))
        if len(js) == 1:
            jpath = js[0]
            jr.add(WARN, f"json is {jpath.name}, expected {role}.json")
        else:
            jr.add(FAIL, f"{role}.json missing")
            unexpected = sorted(str(p.relative_to(folder)) for p in folder.rglob("*.png"))
            return results, missing, unexpected, lines, sheets
    try:
        meta = json.loads(jpath.read_text())
        if not isinstance(meta, dict):
            raise ValueError("top level is not an object")
    except Exception as exc:
        jr.add(FAIL, f"json not parseable: {exc}")
        return results, missing, unexpected, lines, sheets
    jr.dimensions = "json"
    anims = _npc_get(meta, "anims", "animations", default=None)
    if not isinstance(anims, dict) or not anims:
        jr.add(FAIL, "json has no `anims` object")
        return results, missing, unexpected, lines, sheets
    # frame size
    fs = _npc_get(meta, "frame_size_2x", "frame_size", default=None)
    if fs is None and "frame_w" in meta:
        fs = [meta.get("frame_w"), meta.get("frame_h")]
    if fs is None:
        fw, fh = NPC_FRAME_2X
        jr.info(f"no frame_size_2x in json; using spec {fw}x{fh}")
    else:
        fw, fh = int(fs[0]), int(fs[1])
        if (fw, fh) != NPC_FRAME_2X:
            jr.add(FAIL, f"frame size {fw}x{fh}, spec WP10 wants {NPC_FRAME_2X[0]}x{NPC_FRAME_2X[1]} at 2x")
    # pivot
    pv = _npc_get(meta, "pivot_px_2x", "pivot", default=None)
    if not (isinstance(pv, (list, tuple)) and len(pv) == 2 and all(isinstance(v, (int, float)) for v in pv)):
        jr.add(FAIL, f"pivot missing or malformed ({pv!r}); want \"pivot_px_2x\": [x, y] in 2x frame pixels")
        pivot = NPC_PIVOT_2X_SUGGESTED
    else:
        pivot = (int(round(pv[0])), int(round(pv[1])))
        if pv[0] < 0 or pv[1] < 0:
            jr.add(FAIL, f"pivot {list(pv)} is negative: looks like a Sprite2D offset (ironjaw_tall.json style [0,-104]); "
                         f"NPC json wants the feet pixel in the 2x frame (measuring with {list(NPC_PIVOT_2X_SUGGESTED)})")
            pivot = NPC_PIVOT_2X_SUGGESTED
        if pivot[1] > fh - NPC_EDGE_MARGIN_2X - 1:
            jr.add(FAIL, f"pivot y {pivot[1]} leaves no {NPC_EDGE_MARGIN_2X} px bottom margin in a {fh} px frame")
        if abs(pivot[0] - fw / 2) > 1:
            jr.add(WARN, f"pivot x {pivot[0]} is not the frame centre {fw // 2}; flip_h mirrors would move the feet")
        if tuple(pivot) != NPC_PIVOT_2X_SUGGESTED:
            jr.info(f"pivot {list(pivot)} (suggested {list(NPC_PIVOT_2X_SUGGESTED)})")
        else:
            jr.info(f"pivot {list(pivot)}")
    for name, an in anims.items():
        if isinstance(an, dict):
            apv = _npc_get(an, "pivot_px_2x", "pivot", default=None)
            if apv is not None and [int(round(v)) for v in apv] != list(pivot):
                jr.add(FAIL, f"{name}: pivot {list(apv)} differs from the role pivot {list(pivot)} (one pivot for all anims)")
    for req in NPC_ANIM_FRAMES:
        if req not in anims:
            jr.add(FAIL, f"anim `{req}` missing (4.5a: idle, walk, talk)")
    d2, d1 = folder / NPC_DIR_2X, folder
    if not d2.is_dir():
        jr.add(FAIL, f"no `{NPC_DIR_2X}/` folder: 2x masters go in {NPC_DIR_2X}/<anim>_<facing>.png, 1x halves beside the json")
    listed = {str(jpath.relative_to(folder))}
    mirrored_files = []
    sheet_items = []   # (anim, facing, path2x, path1x, src, flip, frames)
    for name, an in anims.items():
        if not isinstance(an, dict):
            jr.add(FAIL, f"anim `{name}` is not an object"); continue
        lo_hi = NPC_ANIM_FRAMES.get(name)
        if lo_hi is None:
            jr.info(f"extra anim `{name}` (not in spec; no frame range)")
        if not isinstance(an.get("fps"), (int, float)) or an.get("fps", 0) <= 0:
            jr.add(FAIL, f"{name}: fps missing or not a positive number")
        elif name == "idle" and an["fps"] != NPC_IDLE_FPS_SPEC:
            jr.add(WARN, f"idle fps {an['fps']}; WP10 / brief say {NPC_IDLE_FPS_SPEC} fps")
        if not isinstance(an.get("loop"), bool):
            jr.add(WARN, f"{name}: `loop` flag missing or not a bool")
        if name == "walk":
            sp = an.get("stride_px", meta.get("stride_px"))
            if not isinstance(sp, (int, float)) or isinstance(sp, bool) or sp <= 0:
                jr.add(WARN, "walk: `stride_px` missing (ground covered per cycle at 2x; the walker picks frames by distance)")
            else:
                jr.info(f"walk stride {sp} px@2x ({sp / 2:.1f} px@1x per cycle)")
        plan = _npc_plan(meta, an)
        for f in NPC_FACINGS:
            src, flip, entry = plan[f]
            n_meta = _npc_frames_of(an, f)
            if src != f or flip is not False:
                # mirror flag validation
                if not isinstance(flip, bool):
                    jr.add(FAIL, f"{name} {f}: flip_h {flip!r} is not a bool")
                if src not in NPC_FACINGS:
                    jr.add(FAIL, f"{name} {f}: mirror src {src!r} is not one of N/E/S/W"); continue
                if plan[src][0] != src or plan[src][1] not in (False,):
                    jr.add(FAIL, f"{name} {f}: mirror src {src} is itself mirrored (chain)"); continue
                if flip is True and NPC_MIRROR_OF[f] != src:
                    jr.add(FAIL, f"{name} {f} ({NPC_FACING_VIEW[f]}) mirrors {src} ({NPC_FACING_VIEW[src]}): under the locked rule "
                                 f"{f} can only be {NPC_MIRROR_OF[f]} flipped")
                elif flip is False and src != f:
                    jr.add(FAIL, f"{name} {f}: src {src} without flip_h shows the wrong view")
                srcp, _ = _npc_find_png(d2, f"{name}_{src.lower()}.png")
                if srcp is None:
                    jr.add(FAIL, f"{name} {f}: mirror src strip {NPC_DIR_2X}/{name}_{src.lower()}.png does not exist")
                n_src = _npc_frames_of(an, src)
                if n_meta is not None and n_src is not None and n_meta != n_src:
                    jr.add(WARN, f"{name} {f}: json frames {n_meta} != mirror src {src} frames {n_src}")
                for dd in (d2, d1):
                    p, _ = _npc_find_png(dd, f"{name}_{f.lower()}.png")
                    if p is not None:
                        listed.add(str(p.relative_to(folder)))
                        mirrored_files.append(str(p.relative_to(folder)))
                if srcp is not None and isinstance(flip, bool):
                    sheet_items.append((name, f, srcp, _npc_find_png(d1, f"{name}_{src.lower()}.png")[0], src, flip, n_src))
                continue
            fname = f"{name}_{f.lower()}.png"
            r = Result(f"{role}/{NPC_DIR_2X}/{fname}")
            p2, upper = _npc_find_png(d2, fname)
            p1, upper1 = _npc_find_png(d1, fname)
            if p1 is not None:
                listed.add(str(p1.relative_to(folder)))
            if p2 is None:
                missing.append(f"{NPC_DIR_2X}/{fname}")
                r.add(FAIL, "2x strip missing"); results.append(r); continue
            listed.add(str(p2.relative_to(folder)))
            if upper or upper1:
                r.add(WARN, "upper-case facing letter in the file name; use lower case (repo: ironjaw_tall_idle_s.png)")
            im = _load(p2)
            r.dimensions = f"{im.size[0]}x{im.size[1]} {im.mode}"
            if im.mode != "RGBA":
                r.add(FAIL, f"mode {im.mode}, need RGBA (straight alpha)"); results.append(r); continue
            W, H = im.size
            if not isinstance(n_meta, int) or isinstance(n_meta, bool) or n_meta <= 0:
                r.add(FAIL, f"json frames {n_meta!r} missing or not a positive int")
                n = W // fw if fw else 0
            else:
                n = n_meta
            if H != fh:
                r.add(FAIL, f"strip height {H} != frame height {fh} (one row of frames, no hand-packed atlas)")
            if W != n * fw:
                r.add(FAIL, f"strip width {W} != {n} frames x {fw} (json frames {n_meta})" +
                      (f"; the file holds {W / fw:g} frames" if fw else ""))
            n_file = W // fw if fw else 0
            count = n_file if (fw and W == n_file * fw) else n
            if lo_hi and not (lo_hi[0] <= count <= lo_hi[1]):
                rng = f"{lo_hi[0]}" + (f"-{lo_hi[1]}" if lo_hi[1] != lo_hi[0] else "")
                r.add(FAIL, f"{count} frames; spec 4.5a wants {rng} for {name}")
            if H != fh:
                r.info("pixel checks skipped (strip is not one row of frames)")
                results.append(r); continue
            rgba = np.asarray(im, dtype=np.uint8)
            nn = min(n, n_file) if n_file else 0
            mets = _npc_strip_pixels(r, rgba[:fh, :nn * fw], fw, fh, nn, pivot, name, "")
            _npc_halo(r, rgba)
            _npc_neon(r, rgba)
            if name == "idle":
                g = [m for m in mets if m]
                if g:
                    hgt = pivot[1] - min(m["top"] for m in g)
                    msg = f"figure height {hgt} px@2x above the pivot ({hgt / 2:.0f} px@1x; ironjaw_tall ~124@2x)"
                    if not (NPC_FIGURE_H_2X[0] <= hgt <= NPC_FIGURE_H_2X[1]):
                        r.add(WARN, msg + f", outside {NPC_FIGURE_H_2X[0]}-{NPC_FIGURE_H_2X[1]} (tall props count too)")
                    else:
                        r.info(msg)
            _npc_1x(r, p2, p1, fw, fh)
            r.info(f"{n_file} f @ {an.get('fps')} fps, loop {an.get('loop')}")
            results.append(r)
            sheet_items.append((name, f, p2, p1, f, False, n))
    # contact AO consistency across drawn strips (agreed spec: soft AO ~70x24, peak <= 0.3)
    ao_rows = [(rr.name.split("/")[-1], getattr(rr, "ao", None)) for rr in results[1:] if getattr(rr, "ao", None) is not None]
    if ao_rows:
        with_ao = [(nm, a) for nm, a in ao_rows if a["frames"]]
        partial = [f"{nm} ({a['frames']}/{a['n']} f)" for nm, a in ao_rows if 0 < a["frames"] < a["n"]]
        none = [nm for nm, a in ao_rows if not a["frames"]]
        if not with_ao:
            jr.info("no baked contact AO in any strip (engine may draw one)")
        else:
            if none or partial:
                jr.add(WARN, "contact AO present in some strips/frames but not others (pops on anim switch): "
                             + ", ".join([f"none in {n}" for n in none] + [f"partial {p}" for p in partial]))
            sw, sh = NPC_AO_SIZE_2X
            small = [f"{nm} {a['w']}x{a['h']}" for nm, a in with_ao
                     if not ((1 - NPC_AO_SIZE_TOL) * sw <= a["w"] <= (1 + NPC_AO_SIZE_TOL) * sw)]
            if small:
                jr.add(WARN, f"contact AO size off the agreed ~{sw}x{sh} px@2x ellipse: " + ", ".join(small))
            offc = [f"{nm} cx {a['cx']:.0f}" for nm, a in with_ao if abs(a["cx"] - (pivot[0] + 0.5)) > 12]
            if offc:
                jr.info("contact AO not centred on the pivot (per-sole AO?): " + ", ".join(offc))
    for mf in sorted(set(mirrored_files)):
        jr.add(WARN, f"{mf} exists but the json mirrors that facing (which one ships?)")
    all_png = sorted(str(p.relative_to(folder)) for p in folder.rglob("*.png"))
    unexpected = [p for p in all_png if p not in listed]
    if unexpected:
        jr.add(FAIL, f"stray PNGs not described by the json: {', '.join(unexpected)}")
    if make_sheet and sheet_items:
        try:
            sys.path.insert(0, str(Path(__file__).resolve().parent))
            import npc_contact
            sheets = npc_contact.make_contact(role, sheet_items, pivot, (fw, fh), previews, backdrop)
        except Exception as exc:
            jr.add(WARN, f"contact sheet failed: {exc}")
    return results, missing, unexpected, lines, sheets


def check_npc(folder: Path, make_sheet=True, previews: Path | None = None, backdrop: Path | None = None):
    """folder = one role folder (has <role>.json or _2x/) or the npc_sprites/ dir."""
    is_role = (folder / f"{folder.name}.json").exists() or (folder / NPC_DIR_2X).is_dir() or any(folder.glob("*.json"))
    roles = [folder] if is_role else sorted(p for p in folder.iterdir() if p.is_dir() and not p.name.startswith((".", "_"))
                                            and p.name != "previews")
    out = []
    for rd in roles:
        out.append((rd.name,) + check_npc_role(rd, make_sheet, previews, backdrop))
    return out


def write_npc_report(report_path: Path, folder: Path, per_role):
    allres = [r for _, res, *_ in per_role for r in res]
    overall = max([r.status for r in allres] + [FAIL if any(m for _, _, m, *_ in per_role) else PASS], default=PASS)
    counts = {s: sum(r.status == s for r in allres) for s in (PASS, WARN, FAIL)}
    lines = ["# Asset check report: `npc`", "", f"- Folder: `{folder}`", f"- Roles: {len(per_role)}",
             f"- Overall: **{STATUS_NAMES[overall] if per_role else 'FAIL (no roles found)'}**",
             f"- Rows: PASS {counts[PASS]}, WARN {counts[WARN]}, FAIL {counts[FAIL]}",
             f"- Rules (ZONES_BUILD_SPEC 4.5a + WP10 NPC bodies @ 78e6513): frame {NPC_FRAME_2X[0]}x{NPC_FRAME_2X[1]} at 2x, "
             f"`{NPC_DIR_2X}/<anim>_<facing>.png` + 1x exact halves, idle {NPC_ANIM_FRAMES['idle'][0]}-{NPC_ANIM_FRAMES['idle'][1]} f, "
             f"walk {NPC_ANIM_FRAMES['walk'][0]} f, talk {NPC_ANIM_FRAMES['talk'][0]}-{NPC_ANIM_FRAMES['talk'][1]} f; one pivot per role "
             f"(suggested {list(NPC_PIVOT_2X_SUGGESTED)}), support (lowest) foot within \u00b1{NPC_PIVOT_Y_TOL} px of the pivot row in every frame "
             f"(idle/talk FAIL, walk/actions WARN; swing-foot lift INFO; runs <= {NPC_TOOL_MAX_W} px wide are tool butts, not feet), "
             f"stance centre = midpoint of the outermost feet within \u00b1{NPC_FEET_X_WARN} px of pivot x (planted FAIL > {NPC_FEET_X_FAIL}), "
             f"contact AO ~{NPC_AO_SIZE_2X[0]}x{NPC_AO_SIZE_2X[1]} peak <= {NPC_AO_PEAK} and consistent across strips, "
             f"planted drift <= {NPC_DRIFT_WARN} px (FAIL > {NPC_DRIFT_FAIL}), {NPC_EDGE_MARGIN_2X} px clear frame edge, halo / alpha-0 RGB, "
             f"mirror flags by the locked rule (W = S flipped, E <-> N flipped), stride_px, loop, neon share <= {NPC_NEON_SHARE * 100:.0f}%.", ""]
    for role, res, missing, unexpected, _info, sheets in per_role:
        st = max([r.status for r in res] + ([FAIL] if missing or unexpected else [PASS]))
        lines += [f"## {role}: **{STATUS_NAMES[st]}**", "", "| File | Status | Size | Details |", "|---|---|---|---|"]
        for r in res:
            lines.append(f"| `{r.name}` | **{STATUS_NAMES[r.status]}** | {r.dimensions} | {r.summary().replace('|', chr(92) + '|')} |")
        if missing:
            lines += ["", "Missing strips: " + ", ".join(f"`{m}`" for m in missing)]
        if unexpected:
            lines += ["", "Stray PNGs: " + ", ".join(f"`{u}`" for u in unexpected)]
        if sheets:
            lines += ["", "Contact sheet: " + ", ".join(f"`{s}`" for s in sheets)]
        lines.append("")
    lines += ["Status rules: FAIL blocks import; WARN needs review; INFO is measurement only.", ""]
    report_path.write_text("\n".join(lines), encoding="utf-8")


def _npc_ship_root(folder: Path):
    for p in [folder] + list(folder.resolve().parents):
        if p.name == "ship":
            return p
    return None



def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Stasium painted PNG assets for Godot 4.7.2")
    parser.add_argument("folder", type=Path)
    parser.add_argument("--package", choices=("jungle", "thunderwell", "coilgate", "props", "glyphs", "world", "npc"), required=True)
    parser.add_argument("--ref-atlas", type=Path, default=None,
                        help="world: reference atlas_meta.json (Crosshaven) for the schema diff")
    parser.add_argument("--map-tags", type=Path, default=None,
                        help="world: map tags json (CombatSim data, e.g. crosshaven_15x15_tags.json) for the props.json `blocks` cross-check")
    parser.add_argument("--report", type=Path, default=None, help="world/npc: report path (default ship/check_report_world_<folder>.md, ship/check_report_npc_<role|all>.md)")
    parser.add_argument("--previews", type=Path, default=None, help="npc: contact sheet folder (default <ship>/../previews/npc)")
    parser.add_argument("--backdrop", type=Path, default=None, help="npc: Crosshaven square screenshot for the contact sheet")
    parser.add_argument("--no-contact", action="store_true", help="npc: skip the contact sheet")
    args = parser.parse_args()
    folder = args.folder
    if not folder.is_dir():
        print(f"FAIL: folder does not exist: {folder}", file=sys.stderr)
        return 2
    if args.package == "npc":
        ship = _npc_ship_root(folder)
        is_role = (folder / f"{folder.name}.json").exists() or (folder / NPC_DIR_2X).is_dir() or any(folder.glob("*.json"))
        root = folder.parent if is_role else folder          # the npc_sprites/ level
        previews = args.previews or ((ship.parent if ship else root.parent) / "previews" / "npc")
        per_role = check_npc(folder, not args.no_contact, previews, args.backdrop)
        single = len(per_role) == 1 and per_role[0][0] == folder.name
        report_path = args.report or ((ship or folder.parent) / f"check_report_npc_{folder.name if single else 'all'}.md")
        write_npc_report(report_path, folder, per_role)
        print(f"Asset check: npc ({folder}), {len(per_role)} role(s)")
        bad = not per_role
        for role, res, missing, unexpected, _info, sheets in per_role:
            for r in res:
                print(f"{r.name:40} {STATUS_NAMES[r.status]:6} {r.dimensions} — {r.summary()}")
            if missing:
                print(f"MISSING ({role}): " + ", ".join(missing))
            if unexpected:
                print(f"STRAY ({role}): " + ", ".join(unexpected))
            for s in sheets:
                print(f"Contact sheet: {s}")
            bad |= bool(missing or unexpected or any(r.status == FAIL for r in res))
        if not per_role:
            print("FAIL: no role folders found")
        print(f"Markdown report: {report_path}")
        return 1 if bad else 0
    if args.package == "world":
        results, missing, unexpected, schema = check_world(folder, args.ref_atlas, args.map_tags)
        report_path = args.report or folder.parent / f"check_report_world_{folder.name}.md"
        write_world_report(report_path, folder, results, missing, unexpected, schema, args.ref_atlas)
        for r in results:
            if r.status != PASS or not r.name.startswith(("tiles/", "terrace/")):
                print(f"{r.name:48} {STATUS_NAMES[r.status]:6} {r.dimensions} — {r.summary()}")
        terr = [r for r in results if r.name.startswith("terrace/")]
        if terr:
            print(f"terrace: {len(terr)} checked, {sum(r.status == PASS for r in terr)} PASS")
        tiles = [r for r in results if r.name.startswith("tiles/")]
        print(f"tiles: {len(tiles)} checked, {sum(r.status == PASS for r in tiles)} PASS")
        if missing:
            print("MISSING: " + ", ".join(missing))
        if unexpected:
            print("UNREFERENCED: " + ", ".join(unexpected))
        print(f"Markdown report: {report_path}")
        return 1 if missing or any(r.status == FAIL for r in results) else 0
    if args.package in ("props", "glyphs"):
        results, missing, unexpected = (check_props if args.package == "props" else check_glyphs)(folder)
        report_path = folder.parent / f"check_report_{args.package}_{folder.name}.md"
        write_report(report_path, args.package, folder, results, missing, unexpected)
        for r in results:
            print(f"{r.name:34} {STATUS_NAMES[r.status]:6} {r.dimensions} — {r.summary()}")
        if missing:
            print("MISSING: " + ", ".join(missing))
        if unexpected:
            print("UNEXPECTED: " + ", ".join(unexpected))
        print(f"Markdown report: {report_path}")
        return 1 if max([r.status for r in results] + ([FAIL] if missing or unexpected else [PASS])) == FAIL else 0
    specs = expected_for(args.package)
    # Loader convention: 2x masters are `name@2x.png`; plain `name.png` is an optional small fallback.
    files = [p for p in folder.iterdir() if p.is_file() and p.suffix.lower() == ".png"]
    pngs = {p.stem[:-3]: p for p in files if p.stem.endswith("@2x")}
    fallbacks = sorted(p.name for p in files if not p.stem.endswith("@2x") and p.stem in pngs)
    for p in files:
        if not p.stem.endswith("@2x") and p.stem not in pngs:
            pngs[p.stem] = p
    missing = sorted(set(specs) - set(pngs))
    unexpected = sorted(set(pngs) - set(specs))
    results = [check_file(pngs[name], specs[name][0], specs[name][1]) for name in sorted(set(specs) & set(pngs))]
    report_path = folder.parent / f"check_report_{args.package}.md"
    write_report(report_path, args.package, folder, results, missing, unexpected)

    print(f"Asset check: {args.package} ({folder})")
    print(f"{'FILE':34} {'STATUS':6} DIMENSIONS / DETAILS")
    print("-" * 110)
    for r in results:
        print(f"{r.name:34} {STATUS_NAMES[r.status]:6} {r.dimensions} — {r.summary()}")
    if missing:
        print(f"MISSING ({len(missing)}): " + ", ".join(x + ".png" for x in missing))
    if unexpected:
        print(f"UNEXPECTED ({len(unexpected)}): " + ", ".join(unexpected))
    if fallbacks:
        print("Ignored 1x fallbacks (2x master present): " + ", ".join(fallbacks))
    print(f"Markdown report: {report_path}")
    return 1 if max([r.status for r in results] + ([FAIL] if missing or unexpected else [PASS])) == FAIL else 0


if __name__ == "__main__":
    raise SystemExit(main())
