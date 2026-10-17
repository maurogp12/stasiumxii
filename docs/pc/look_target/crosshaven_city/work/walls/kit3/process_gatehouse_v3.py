#!/usr/bin/env python3
"""Process gatehouse diag v3 + horizontal: key, scale towers to 1000px, sheet."""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

OUT = Path("/workspace/crosshaven_paint/walls/kit3")
OUT.mkdir(parents=True, exist_ok=True)

SRC_A = Path(
    "/cursor/stores/store-ffac70a3-4b50-4a40-b765-f28cdf82cbbd/"
    "grok-bot/agents/ce4006dd-4e98-48dd-b991-fa7565b86bf2/attachments/"
    "1502629138b51e23da5ddbd909122528edad16d7ecba949452c143b5903f2be1.jpg"
)
SRC_B = Path(
    "/cursor/stores/store-ffac70a3-4b50-4a40-b765-f28cdf82cbbd/"
    "grok-bot/agents/ce4006dd-4e98-48dd-b991-fa7565b86bf2/attachments/"
    "53f15647ea7d91772e936a0425d2179eaac9a499132e85b716b7a41dd0e886bc.jpg"
)

TOWER_REF = Path("/workspace/crosshaven_paint/walls/kit/tower_CONCEPTO.png")
SEG_H = Path("/workspace/crosshaven_paint/walls/kit2/segment_horizontal_CONCEPTO.png")
SEG_DIAG = Path("/workspace/crosshaven_paint/walls/kit2/segment_short_CONCEPTO.png")
HERO = Path("/workspace/meshy_pilot/ironjaw_new/v7_sheathed_hd/frames/E_00.png")

TARGET_TOWER_H = 1000
TARGET_PARAPET = 550
MIN_PASSAGE = 96  # 2 * hero width 48


def key_rgba(im: Image.Image) -> Image.Image:
    """Distance-to-median-border > 70, plus shadow key, MinFilter(3), blur, despill."""
    rgb = np.asarray(im.convert("RGB"), dtype=np.float32)
    h, w, _ = rgb.shape
    border = np.concatenate(
        [
            rgb[0, :, :],
            rgb[-1, :, :],
            rgb[:, 0, :],
            rgb[:, -1, :],
        ],
        axis=0,
    )
    med = np.median(border, axis=0)  # (3,)
    dist = np.linalg.norm(rgb - med[None, None, :], axis=2)
    fg = dist > 70.0

    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    shadow = (g > r + 25) & (g > b + 25) & (g > 110)
    fg = fg & ~shadow

    alpha = (fg.astype(np.uint8) * 255)
    a_im = Image.fromarray(alpha, mode="L")
    a_im = a_im.filter(ImageFilter.MinFilter(3))
    a_im = a_im.filter(ImageFilter.GaussianBlur(0.8))
    alpha = np.asarray(a_im, dtype=np.float32)

    # despill: g = min(g, max(r,b)) where alpha > 0
    out = rgb.copy()
    mask = alpha > 0
    out_g = np.minimum(g, np.maximum(r, b))
    out[:, :, 1] = np.where(mask, out_g, g)

    rgba = np.dstack([out.astype(np.uint8), alpha.astype(np.uint8)])
    return Image.fromarray(rgba, mode="RGBA")


def crop_bbox(im: Image.Image, pad: int = 2) -> Image.Image:
    a = np.asarray(im.split()[-1])
    ys, xs = np.where(a > 8)
    if len(xs) == 0:
        return im
    x0, x1 = int(xs.min()), int(xs.max()) + 1
    y0, y1 = int(ys.min()), int(ys.max()) + 1
    x0 = max(0, x0 - pad)
    y0 = max(0, y0 - pad)
    x1 = min(im.width, x1 + pad)
    y1 = min(im.height, y1 + pad)
    return im.crop((x0, y0, x1, y1))


def scale_tower_to(im: Image.Image, target_h: int = TARGET_TOWER_H) -> Image.Image:
    """Scale so full image height (finial to base after crop) = target_h.
    The flanking towers define the full bbox height after key+crop."""
    w, h = im.size
    scale = target_h / float(h)
    nw = max(1, int(round(w * scale)))
    nh = target_h
    out = im.resize((nw, nh), Image.Resampling.LANCZOS)
    out = out.filter(ImageFilter.UnsharpMask(radius=1, percent=30, threshold=0))
    return out


def measure_passage_width(im: Image.Image) -> dict:
    """Find the inner gate passage: darkest/empty column gap near mid-height.
    Returns width in px of the largest contiguous low-alpha gap across the
    curtain/opening band (roughly mid building, above base, below parapet)."""
    a = np.asarray(im.split()[-1])
    h, w = a.shape
    # Scan horizontal rows in the lower-middle third where the arch opening sits
    y0 = int(h * 0.35)
    y1 = int(h * 0.85)
    best = {"width": 0, "y": None, "x0": None, "x1": None}
    for y in range(y0, y1):
        row = a[y]
        # transparent = passage or outside; we want interior hole
        # Find runs of alpha < 40 that are fully interior (opaque on both sides)
        transparent = row < 40
        # find runs
        i = 0
        while i < w:
            if not transparent[i]:
                i += 1
                continue
            j = i
            while j < w and transparent[j]:
                j += 1
            # run [i, j)
            left_ok = i > 0 and row[i - 1] >= 40
            right_ok = j < w and row[j] >= 40
            width = j - i
            if left_ok and right_ok and width > best["width"]:
                best = {"width": int(width), "y": int(y), "x0": int(i), "x1": int(j)}
            i = j
    return best


def measure_parapet_height(im: Image.Image) -> dict:
    """Curtain parapet height above the base.
    Heuristic: find the curtain wall body between the two towers — the
    continuous opaque band whose top is the parapet walk / crenellation
    and bottom is the ground baseline of the image.
    We take the image bottom as base (bbox already cropped to feet), and
    find the top of the curtain (lowest roof/parapet y in the central
    horizontal band between towers)."""
    a = np.asarray(im.split()[-1])
    h, w = a.shape
    # Central 40% of width = curtain between flanking towers
    cx0 = int(w * 0.30)
    cx1 = int(w * 0.70)
    center = a[:, cx0:cx1]
    # For each row, fraction opaque
    frac = (center > 40).mean(axis=1)
    # From top, find first row where curtain becomes substantial
    # Parapet top = first row with frac > 0.25 in the center band
    parapet_top = None
    for y in range(h):
        if frac[y] > 0.25:
            parapet_top = y
            break
    # Also try: within center, the topmost opaque pixel median across columns
    tops = []
    for x in range(cx0, cx1):
        col = a[:, x]
        ys = np.where(col > 40)[0]
        if len(ys):
            tops.append(int(ys[0]))
    med_top = int(np.median(tops)) if tops else parapet_top
    # Prefer median of column tops (more stable for crenellations)
    top_y = med_top if med_top is not None else parapet_top
    if top_y is None:
        return {"parapet_h": None, "top_y": None, "base_y": h - 1}
    parapet_h = h - top_y  # from parapet top down to base (image bottom)
    # But wait: the towers stick above the parapet. Curtain parapet height
    # should be from BASE up to the curtain walk / crenellation top —
    # which IS h - top_y only if top_y is the curtain top, not tower top.
    # Using center band excludes towers, so top_y should be curtain parapet.
    return {
        "parapet_h": int(parapet_h),
        "top_y": int(top_y),
        "base_y": h - 1,
        "med_top": med_top,
        "frac_top": parapet_top,
    }


def process_one(src: Path, name: str) -> dict:
    raw = Image.open(src)
    keyed = key_rgba(raw)
    cropped = crop_bbox(keyed)
    # Save debug pre-scale
    cropped.save(OUT / f"_dbg_{name}_keyed.png")
    scaled = scale_tower_to(cropped, TARGET_TOWER_H)
    out_path = OUT / f"{name}_CONCEPTO.png"
    scaled.save(out_path)
    passage = measure_passage_width(scaled)
    parapet = measure_parapet_height(scaled)
    info = {
        "name": name,
        "path": str(out_path),
        "size": list(scaled.size),
        "pre_scale_size": list(cropped.size),
        "scale_factor": TARGET_TOWER_H / cropped.size[1],
        "passage": passage,
        "parapet": parapet,
        "parapet_vs_550_pct": (
            None
            if parapet["parapet_h"] is None
            else round(100.0 * (parapet["parapet_h"] - TARGET_PARAPET) / TARGET_PARAPET, 2)
        ),
    }
    print(json.dumps(info, indent=2))
    return {"im": scaled, "info": info}


def make_sheet(diag, diag_mirror, horiz):
    tower = Image.open(TOWER_REF).convert("RGBA")
    seg_d = Image.open(SEG_DIAG).convert("RGBA")
    seg_h = Image.open(SEG_H).convert("RGBA")
    hero_raw = Image.open(HERO).convert("RGBA")
    # Hero display: content bbox, keep native then scale so height ~156
    ha = np.asarray(hero_raw.split()[-1])
    ys, xs = np.where(ha > 8)
    hero = hero_raw.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    hero_target_h = 156
    hs = hero_target_h / hero.size[1]
    hero = hero.resize(
        (max(1, int(round(hero.size[0] * hs))), hero_target_h),
        Image.Resampling.LANCZOS,
    )

    # Layout: two rows
    # Row A: diag gatehouse | tower | segment_short | hero
    # Row B: horiz gatehouse | tower | segment_horizontal | hero
    # All on same baseline per row; red line at 550 above baseline.
    gap = 40
    title_h = 70
    label_h = 36
    margin = 40

    def row_width(pieces):
        return sum(p.size[0] for p in pieces) + gap * (len(pieces) - 1)

    row_a_pieces = [diag, tower, seg_d, hero]
    row_b_pieces = [horiz, tower, seg_h, hero]
    # Cap very wide segments for sheet readability — scale down if needed for display only?
    # Task says put them next to — use as-is. Sheet may be wide.
    # Shrink segments to fit reasonably if > 1200 wide for sheet
    def shrink_seg(seg, max_w=1100):
        if seg.size[0] <= max_w:
            return seg
        s = max_w / seg.size[0]
        return seg.resize(
            (max_w, max(1, int(round(seg.size[1] * s)))),
            Image.Resampling.LANCZOS,
        )

    # Keep full size for accurate scale comparison — but sheet could be huge.
    # segment_horizontal is 2811 wide. Total row ~ 2811+1460+469+48 ~ 4800. OK.
    row_a_h = max(p.size[1] for p in row_a_pieces)
    row_b_h = max(p.size[1] for p in row_b_pieces)
    # Also include mirror as third mini row or side panel
    row_m_pieces = [diag_mirror, tower, hero]
    row_m_h = max(p.size[1] for p in row_m_pieces)

    sheet_w = max(
        row_width(row_a_pieces),
        row_width(row_b_pieces),
        row_width(row_m_pieces),
    ) + 2 * margin
    sheet_h = (
        title_h
        + label_h
        + row_a_h
        + label_h
        + row_b_h
        + label_h
        + row_m_h
        + 2 * margin
        + 60
    )

    bg = (96, 96, 96, 255)
    sheet = Image.new("RGBA", (sheet_w, sheet_h), bg)
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype(
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 28
        )
        font_s = ImageFont.truetype(
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 18
        )
    except Exception:
        font = ImageFont.load_default()
        font_s = font

    draw.text((margin, 20), "IMAGEN / CONCEPTO", fill=(255, 255, 255, 255), font=font)
    draw.text(
        (margin, 48),
        "gatehouse v3 — towers=1000px  red line=550px wall  hero=156px",
        fill=(220, 220, 220, 255),
        font=font_s,
    )

    def paste_row(pieces, labels, y_top, row_label):
        draw.text((margin, y_top), row_label, fill=(255, 230, 120, 255), font=font_s)
        y_base = y_top + label_h + max(p.size[1] for p in pieces)
        x = margin
        # red line at 550 above baseline
        red_y = y_base - TARGET_PARAPET
        draw.line([(margin - 10, red_y), (sheet_w - margin + 10, red_y)], fill=(255, 40, 40, 255), width=2)
        for p, lab in zip(pieces, labels):
            py = y_base - p.size[1]
            sheet.alpha_composite(p, (x, py))
            draw.text((x, y_base + 4), lab, fill=(230, 230, 230, 255), font=font_s)
            x += p.size[0] + gap
        return y_base + 28

    y = title_h
    y = paste_row(
        row_a_pieces,
        ["diag v3", "tower 1000", "seg_short", "hero"],
        y,
        "A  diagonal gatehouse_diag_v3 (+ segment_short)",
    )
    y = paste_row(
        row_b_pieces,
        ["horizontal", "tower 1000", "seg_horizontal", "hero"],
        y,
        "B  horizontal gatehouse_horizontal (+ segment_horizontal)",
    )
    y = paste_row(
        row_m_pieces,
        ["diag mirror", "tower 1000", "hero"],
        y,
        "A mirror  gatehouse_diag_v3_mirror",
    )

    # Flatten to RGB jpeg
    rgb = Image.new("RGB", sheet.size, (96, 96, 96))
    rgb.paste(sheet, mask=sheet.split()[-1])
    out = OUT / "gatehouse_v3_sheet_CONCEPTO.jpg"
    rgb.save(out, quality=92, optimize=True)
    print(f"sheet: {out} {rgb.size}")
    return out


def main():
    a = process_one(SRC_A, "gatehouse_diag_v3")
    # mirror
    mirror = ImageOps.mirror(a["im"])
    mpath = OUT / "gatehouse_diag_v3_mirror_CONCEPTO.png"
    mirror.save(mpath)
    print(f"mirror: {mpath} {mirror.size}")
    b = process_one(SRC_B, "gatehouse_horizontal")
    sheet = make_sheet(a["im"], mirror, b["im"])

    summary = {
        "diag": a["info"],
        "diag_mirror": {"path": str(mpath), "size": list(mirror.size)},
        "horizontal": b["info"],
        "sheet": str(sheet),
        "notes": {
            "target_tower_h": TARGET_TOWER_H,
            "target_parapet": TARGET_PARAPET,
            "min_passage": MIN_PASSAGE,
            "hero_width_ref": 48,
        },
    }
    (OUT / "gatehouse_v3_metrics.json").write_text(json.dumps(summary, indent=2))
    print("---SUMMARY---")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
