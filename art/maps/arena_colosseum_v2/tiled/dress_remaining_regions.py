#!/usr/bin/env python3
"""Paint-dress Brinewake / Slagcrown / Windmere / Stormspire.

- Regenerates region terrain + ALL props at human-perception scale
  (houses > heroes; pillars tall; conduits remain accents).
- Refreshes board previews + koliseo shell painted previews.
- Does NOT rewrite any *_15x15_tags.json.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFont, ImageOps

from koliseo_common import (
    BASE_C,
    BRINE_C,
    ROOT,
    SLAG_C,
    STORM_C,
    TILE_H,
    TILE_W,
    TILES,
    WIND_C,
    cell_to_local,
    generate_full_catalog,
    write_preview,
    write_tsx,
)

TAG_FILES = [
    "crosshaven_15x15_tags.json",
    "brinewake_15x15_tags.json",
    "slagcrown_15x15_tags.json",
    "windmere_15x15_tags.json",
    "stormspire_15x15_tags.json",
]

REGIONS = {
    "brinewake": {
        "prefix": "brine",
        "plate": ROOT.parent / "brinewake.png",
        "chars_plate": ROOT.parent / "brinewake_chars.png",
        "bg": (55, 130, 145),
        "label": "15×15 Brinewake · painted v1",
        "shell_label": "15×15 Brinewake · painted dress v1",
        "banner": (20, 50, 55, 210),
        "text": (180, 245, 240, 255),
        "sub": (140, 210, 205, 230),
    },
    "slagcrown": {
        "prefix": "slag",
        "plate": ROOT.parent / "slagcrown.png",
        "chars_plate": ROOT.parent / "slagcrown_chars.png",
        "bg": (55, 42, 38),
        "label": "15×15 Slagcrown · painted v1",
        "shell_label": "15×15 Slagcrown · painted dress v1",
        "banner": (40, 22, 14, 210),
        "text": (255, 200, 120, 255),
        "sub": (220, 150, 80, 230),
    },
    "windmere": {
        "prefix": "wind",
        "plate": ROOT.parent / "windmere.png",
        "chars_plate": ROOT.parent / "windmere_chars.png",
        "bg": (150, 175, 200),
        "label": "15×15 Windmere · painted v1",
        "shell_label": "15×15 Windmere · painted dress v1",
        "banner": (30, 45, 70, 210),
        "text": (220, 240, 255, 255),
        "sub": (170, 210, 240, 230),
    },
    "stormspire": {
        "prefix": "storm",
        "plate": ROOT.parent / "stormspire.png",
        "chars_plate": ROOT.parent / "stormspire_chars.png",
        "bg": (28, 32, 48),
        "label": "15×15 Stormspire · painted v1",
        "shell_label": "15×15 Stormspire · painted dress v1",
        "banner": (18, 16, 40, 220),
        "text": (180, 230, 255, 255),
        "sub": (160, 120, 255, 230),
    },
}

# Hero sprite height on the *board* (native tile px) so ruins (~112) read ~1.8–2.2× taller
HERO_BOARD_H = 56
KESTREL = Path("/workspace/art/export_2x/characters/kestrel/kestrel_s.png")
BASTION = Path("/workspace/art/export_2x/characters/bastion/bastion_s.png")


def md5_file(path: Path) -> str:
    return hashlib.md5(path.read_bytes()).hexdigest()


def snapshot_tags():
    return {name: md5_file(ROOT / name) for name in TAG_FILES}


def load_cells(arena: str):
    tags = json.loads((ROOT / f"{arena}_15x15_tags.json").read_text())
    n = tags["size"][0]
    cells = [
        [{"terrain": "ground", "elevation": 0, "paint_only": []} for _ in range(n)]
        for _ in range(n)
    ]
    for c in tags["cells"]:
        cells[c["y"]][c["x"]] = {
            "terrain": c["terrain"],
            "elevation": c["elevation"],
            "paint_only": list(c["paint_only"]),
        }
    return cells


def ensure_stormspire_plate():
    plate = ROOT.parent / "stormspire.png"
    try:
        im = Image.open(plate)
        im.load()
        if im.size == (1280, 720):
            print(f"  stormspire plate OK {plate}")
            return plate
    except Exception as e:
        print(f"  stormspire plate bad ({e}); regenerating")

    src = Image.open(ROOT.parent / "crosshaven.png").convert("RGBA")
    gray = ImageOps.grayscale(src)
    a = src.split()[-1]
    slate = Image.merge(
        "RGBA",
        (
            gray.point(lambda v: int(v * 0.22 + 18)),
            gray.point(lambda v: int(v * 0.26 + 22)),
            gray.point(lambda v: int(v * 0.38 + 40)),
            a,
        ),
    )
    glow = Image.new("RGBA", src.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    pw, ph = src.size
    for i, col in enumerate(
        [(60, 30, 120, 40), (40, 80, 160, 45), (40, 180, 230, 55), (160, 100, 255, 35)]
    ):
        pad = 80 + i * 40
        gd.ellipse(
            [pw // 2 - 280 + pad, ph // 2 - 80 + pad // 2, pw // 2 + 280 - pad, ph // 2 + 160 - pad // 2],
            fill=col,
        )
    sky = Image.new("RGBA", src.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(sky)
    for y in range(ph // 2):
        t = y / (ph // 2)
        sd.line([(0, y), (pw, y)], fill=(18, 12, 48, int(100 * (1 - t))))
    for pts, col in [
        ([(180, 80), (260, 140), (220, 200), (300, 260)], (120, 220, 255, 160)),
        ([(980, 60), (920, 130), (1000, 180), (940, 240)], (180, 120, 255, 140)),
    ]:
        sd.line(pts, fill=col, width=3)
    out = Image.alpha_composite(Image.alpha_composite(slate, glow), sky)
    out = ImageEnhance.Contrast(out).enhance(1.15)
    out = ImageEnhance.Color(out).enhance(1.2)
    out.convert("RGB").save(plate, optimize=True, quality=92)
    print(f"  synthesized {plate}")
    return plate


def render_board(cells, tile_prefix: str) -> Image.Image:
    N = 15
    pts = [cell_to_local(x, y) for y in range(N) for x in range(N)]
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    pad = 40
    min_x, max_x = min(xs) - 40, max(xs) + 40
    min_y, max_y = min(ys) - 40, max(ys) + 80
    W = int(max_x - min_x + pad * 2)
    H = int(max_y - min_y + pad * 2 + 20)
    board = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cache = {}

    def get_tile(name):
        if name not in cache:
            cache[name] = Image.open(TILES / f"{name}.png").convert("RGBA")
        return cache[name]

    def tname(base):
        return f"{tile_prefix}_{base}" if tile_prefix else base

    order = sorted(
        ((x, y) for y in range(N) for x in range(N)), key=lambda p: (p[0] + p[1], p[0])
    )
    for x, y in order:
        c = cells[y][x]
        if c["elevation"] == 1:
            base_name = tname("mud_e1") if c["terrain"] == "mud" else tname("ground_e1")
        elif c["elevation"] >= 2:
            base_name = tname("ground_e2")
        elif c["terrain"] != "ground":
            base_name = tname(c["terrain"])
        else:
            base_name = tname("ground")
        tile = get_tile(base_name)
        lx, ly = cell_to_local(x, y)
        px = int(lx - min_x + pad - TILE_W // 2)
        py = int(ly - min_y + pad)
        if tile.height > TILE_H:
            py -= tile.height - TILE_H
        board.alpha_composite(tile, (px, py))
        for pi, prop in enumerate(c["paint_only"]):
            pt = get_tile(f"prop_{prop}")
            ppx = px + pi * 4
            ppy = py if tile.height > TILE_H else py - (pt.height - TILE_H)
            board.alpha_composite(pt, (ppx, ppy))
    return board


def _place_hero(canvas: Image.Image, sprite_path: Path, foot_xy, flip=False):
    """Place export_2x hero so on-canvas height ≈ HERO_BOARD_H * board_scale already applied."""
    sp = Image.open(sprite_path).convert("RGBA")
    if flip:
        sp = ImageOps.mirror(sp)
    # foot_xy is where feet should sit; sprite already scaled by caller
    sx = int(foot_xy[0] - sp.width // 2)
    sy = int(foot_xy[1] - sp.height + 4)
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse(
        [sx + 6, foot_xy[1] - 6, sx + sp.width - 6, foot_xy[1] + 8],
        fill=(0, 0, 0, 80),
    )
    out = Image.alpha_composite(canvas, shadow)
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    layer.paste(sp, (sx, sy), sp)
    return Image.alpha_composite(out, layer)


def write_painted_shell(arena: str, cells, cfg: dict):
    plate = Image.open(cfg["plate"]).convert("RGBA")
    board = render_board(cells, cfg["prefix"])
    pw, ph = plate.size
    target_w = int(pw * 0.52)
    scale = target_w / board.width
    target_h = int(board.height * scale)
    board_s = board.resize((target_w, target_h), Image.Resampling.LANCZOS)

    shadow = Image.new("RGBA", plate.size, (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    cx, cy = pw // 2, int(ph * 0.52)
    bx = cx - board_s.width // 2
    by = cy - board_s.height // 2 + 8
    sdraw.ellipse(
        [bx + 20, by + target_h - 36, bx + target_w - 20, by + target_h + 10],
        fill=(10, 8, 16, 100),
    )

    # Feather board edges
    mask = Image.new("L", board_s.size, 0)
    ImageDraw.Draw(mask).ellipse([4, 4, board_s.width - 5, board_s.height - 5], fill=255)
    small = mask.resize(
        (max(8, board_s.width // 12), max(8, board_s.height // 12)), Image.Resampling.BILINEAR
    )
    mask = small.resize(board_s.size, Image.Resampling.BILINEAR)
    board_feather = board_s.copy()
    board_feather.putalpha(
        Image.composite(board_s.split()[-1], Image.new("L", board_s.size, 0), mask)
    )
    placed = Image.new("RGBA", plate.size, (0, 0, 0, 0))
    placed.paste(board_feather, (bx, by), board_feather)

    out = Image.alpha_composite(Image.alpha_composite(plate.copy(), shadow), placed)

    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 20)
        font_sm = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 13)
    except Exception:
        font = ImageFont.load_default()
        font_sm = font
    draw = ImageDraw.Draw(out)
    bw, bh = 460, 48
    lx0, ly0 = (pw - bw) // 2, 16
    draw.rounded_rectangle([lx0, ly0, lx0 + bw, ly0 + bh], radius=8, fill=cfg["banner"])
    draw.text((lx0 + 16, ly0 + 6), cfg["shell_label"], font=font, fill=cfg["text"])
    draw.text(
        (lx0 + 16, ly0 + 28),
        "STASIUM XV · board in koliseo shell · props scaled",
        font=font_sm,
        fill=cfg["sub"],
    )

    path_out = ROOT / f"{arena}_15x15_painted_preview.png"
    out.convert("RGB").save(path_out, optimize=True, quality=92)

    # Chars variant: plain plate + board + export_2x heroes at board-relative scale
    # so houses (112px native) clearly tower over heroes (~56px native).
    hero_h = max(24, int(HERO_BOARD_H * scale))
    chars_out = None
    if KESTREL.exists() and BASTION.exists():
        base = Image.alpha_composite(plate.copy(), shadow)
        # heroes under board feet line so buildings occlude correctly where overlapping
        kest = Image.open(KESTREL).convert("RGBA")
        bast = Image.open(BASTION).convert("RGBA")
        kest = kest.resize(
            (max(1, int(kest.width * hero_h / kest.height)), hero_h), Image.Resampling.LANCZOS
        )
        bast = ImageOps.mirror(
            bast.resize(
                (max(1, int(bast.width * hero_h / bast.height)), hero_h),
                Image.Resampling.LANCZOS,
            )
        )
        # Place on lower-left / lower-right of board floor
        foot_k = (bx + int(target_w * 0.32), by + int(target_h * 0.72))
        foot_b = (bx + int(target_w * 0.68), by + int(target_h * 0.72))
        mixed = _place_hero(base, KESTREL, foot_k, flip=False)
        # re-scale manually since _place_hero loads full-size — do inline instead
        mixed = Image.alpha_composite(plate.copy(), shadow)

        def paste_scaled(canvas, sp, foot, flip=False):
            if flip:
                sp = ImageOps.mirror(sp)
            sx = int(foot[0] - sp.width // 2)
            sy = int(foot[1] - sp.height + 4)
            sh = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
            ImageDraw.Draw(sh).ellipse(
                [sx + 4, foot[1] - 4, sx + sp.width - 4, foot[1] + 6], fill=(0, 0, 0, 70)
            )
            canvas = Image.alpha_composite(canvas, sh)
            layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
            layer.paste(sp, (sx, sy), sp)
            return Image.alpha_composite(canvas, layer)

        mixed = paste_scaled(mixed, kest, foot_k, False)
        mixed = paste_scaled(mixed, bast, foot_b, False)
        # board on top so tall props read in front of / with heroes
        mixed = Image.alpha_composite(mixed, placed)
        draw2 = ImageDraw.Draw(mixed)
        draw2.rounded_rectangle([lx0, ly0, lx0 + bw, ly0 + bh], radius=8, fill=cfg["banner"])
        draw2.text(
            (lx0 + 16, ly0 + 6),
            cfg["shell_label"].replace("dress v1", "+ chars"),
            font=font,
            fill=cfg["text"],
        )
        draw2.text(
            (lx0 + 16, ly0 + 28),
            f"STASIUM XV · houses > heroes (hero≈{hero_h}px on plate)",
            font=font_sm,
            fill=cfg["sub"],
        )
        chars_out = ROOT / f"{arena}_15x15_painted_preview_chars.png"
        mixed.convert("RGB").save(chars_out, optimize=True, quality=92)
    elif cfg["chars_plate"].exists():
        # fallback: chars plate underlay, board on top
        chars = Image.open(cfg["chars_plate"]).convert("RGBA")
        mixed = Image.alpha_composite(Image.alpha_composite(chars, shadow), placed)
        draw2 = ImageDraw.Draw(mixed)
        draw2.rounded_rectangle([lx0, ly0, lx0 + bw, ly0 + bh], radius=8, fill=cfg["banner"])
        draw2.text(
            (lx0 + 16, ly0 + 6),
            cfg["shell_label"].replace("dress v1", "+ chars"),
            font=font,
            fill=cfg["text"],
        )
        draw2.text(
            (lx0 + 16, ly0 + 28),
            "STASIUM XV · shell chars plate + scaled props",
            font=font_sm,
            fill=cfg["sub"],
        )
        chars_out = ROOT / f"{arena}_15x15_painted_preview_chars.png"
        mixed.convert("RGB").save(chars_out, optimize=True, quality=92)

    return path_out, chars_out


def refresh_crosshaven_props_preview():
    """Shared props changed — refresh Crosshaven board preview + shell so scale matches."""
    cells = load_cells("crosshaven")
    write_preview(cells, "crosshaven", "15×15 Crosshaven · painted v1", (210, 175, 110), "")
    # reuse shell writer with crosshaven cfg
    cfg = {
        "prefix": "",
        "plate": ROOT.parent / "crosshaven.png",
        "chars_plate": ROOT.parent / "crosshaven_chars.png",
        "shell_label": "15×15 Crosshaven · painted dress v1",
        "banner": (35, 25, 12, 210),
        "text": (255, 235, 180, 255),
        "sub": (220, 200, 150, 230),
    }
    return write_painted_shell("crosshaven", cells, cfg)


def main():
    print("=== Snapshot tag MD5s (must stay identical) ===")
    before = snapshot_tags()
    for k, v in before.items():
        print(f"  {k}: {v}")

    print("\n=== Ensure Stormspire plate ===")
    ensure_stormspire_plate()

    print("\n=== Regenerate full tile catalog (props at perception scale) ===")
    catalog = generate_full_catalog()
    tsx, id_of = write_tsx(catalog)
    print(f"  {len(catalog)} tiles → {tsx.name}")
    # prove prop heights
    from PIL import Image as _I

    for name in ("prop_ruins", "prop_well", "prop_rock_pillar", "prop_basalt_pillar", "prop_conduit", "prop_spark"):
        im = _I.open(TILES / f"{name}.png")
        print(f"  {name}: {im.size}")

    print("\n=== Refresh region previews + painted shells from frozen tags ===")
    for arena, cfg in REGIONS.items():
        cells = load_cells(arena)
        preview = write_preview(cells, arena, cfg["label"], cfg["bg"], cfg["prefix"])
        painted, chars = write_painted_shell(arena, cells, cfg)
        print(
            f"  {arena}: {preview.name} | {painted.name} | {chars.name if chars else None}"
        )

    print("\n=== Refresh Crosshaven previews (shared props resized) ===")
    ch_painted, ch_chars = refresh_crosshaven_props_preview()
    print(f"  crosshaven painted={ch_painted.name} chars={ch_chars.name if ch_chars else None}")

    print("\n=== Verify tags untouched ===")
    after = snapshot_tags()
    ok = True
    for name in TAG_FILES:
        same = before[name] == after[name]
        mark = "OK" if same else "CHANGED!"
        print(f"  {name}: {after[name]} {mark}")
        if not same:
            ok = False
    if not ok:
        raise SystemExit("TAGS CHANGED — abort")
    print("\nDONE — dress complete; all five tag MD5s unchanged.")
    print("TAG_MD5S=" + json.dumps(after, indent=2))


if __name__ == "__main__":
    main()
