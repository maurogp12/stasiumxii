#!/usr/bin/env python3
"""Build Stormspire 15×15 electric Koliseo (5th arena). Does not rewrite other arenas' tags."""
from __future__ import annotations

import json
import xml.etree.ElementTree as ET
from pathlib import Path

from koliseo_common import (
    ROOT,
    apply_elev,
    apply_props,
    apply_terrain,
    counts_of,
    empty_board,
    generate_full_catalog,
    validate_board,
    write_preview,
    write_tags,
    write_tmx,
    write_tsx,
)


def design_stormspire():
    """Dark slate spire — wet pools + scorched mud; conduits/sparks paint-only; lava 0."""
    cells = empty_board()

    # Wet water pools for cyan contrast (~24)
    water = [
        # Corner storm pools
        (1, 1), (2, 1), (1, 2),
        (12, 1), (13, 1), (13, 2),
        (1, 12), (1, 13), (2, 13),
        (12, 13), (13, 12), (13, 13),
        # Side cisterns
        (0, 6), (0, 7), (0, 8),
        (14, 6), (14, 7), (14, 8),
        # Mid-ring wet pads (avoid elev2 cross)
        (4, 4), (10, 4), (4, 10), (10, 10),
        (3, 7), (11, 7),
        (7, 3), (7, 11),
    ]
    # Scorched-earth mud patches (~18) → mud+water ≈ 18.7%
    mud = [
        (3, 1), (11, 1), (1, 3), (13, 3),
        (3, 13), (11, 13), (1, 11), (13, 11),
        (2, 5), (12, 5), (2, 9), (12, 9),
        (5, 2), (9, 2), (5, 12), (9, 12),
        (5, 6), (9, 8),
    ]
    apply_terrain(cells, water, "water")
    apply_terrain(cells, mud, "mud")

    # Spire shelves + ring platforms; elev2 cross needs ortho e1 ramps
    elev1 = [
        # Ramps / ring around center cross
        (7, 5), (7, 7), (7, 9),
        (5, 7), (9, 7),
        (6, 6), (8, 6), (6, 8), (8, 8),
        # Outer platforms
        (3, 3), (11, 3), (3, 11), (11, 11),
        (4, 7), (10, 7),  # note: (3,7)/(11,7) are water elev0 — OK
        (7, 4), (7, 10),  # (7,3)/(7,11) water
        (2, 7), (12, 7),
        (5, 5), (9, 5), (5, 9), (9, 9),
    ]
    # Drop water/mud conflicts on elev cells if any
    water_set = set(water)
    mud_set = set(mud)
    elev1 = [(x, y) for x, y in elev1 if (x, y) not in water_set]
    # mud_e1 allowed — keep mud elev1 if present
    elev2 = [(7, 6), (7, 8), (6, 7), (8, 7)]
    elev2 = [(x, y) for x, y in elev2 if (x, y) not in water_set]
    apply_elev(cells, elev1, 1)
    apply_elev(cells, elev2, 2)

    # Paint-only: conduits / sparks / crystal bolts — NO combat tags
    props = {
        # Central spire seal + bolts
        (7, 7): ["floor_seal", "crystal_bolt"],
        (7, 6): ["crystal_bolt"],
        (7, 8): ["crystal_bolt"],
        (6, 7): ["spark"],
        (8, 7): ["spark"],
        # Conduit spokes (N/E/S/W) — paint glow only
        (7, 2): ["conduit"],
        (7, 12): ["conduit"],
        (2, 7): ["conduit"],
        (12, 7): ["conduit"],
        (7, 5): ["conduit"],
        (7, 9): ["conduit"],
        (5, 7): ["conduit"],
        (9, 7): ["conduit"],
        # Diagonal conduit nodes
        (5, 5): ["conduit"],
        (9, 5): ["conduit"],
        (5, 9): ["conduit"],
        (9, 9): ["conduit"],
        # Corner sparks / bolts
        (0, 0): ["crystal_bolt"],
        (14, 0): ["spark"],
        (0, 14): ["spark"],
        (14, 14): ["crystal_bolt"],
        (0, 4): ["conduit"],
        (14, 4): ["conduit"],
        (0, 10): ["conduit"],
        (14, 10): ["conduit"],
        (4, 0): ["spark"],
        (10, 0): ["spark"],
        (4, 14): ["spark"],
        (10, 14): ["spark"],
        # Accent props
        (3, 5): ["rock_pillar"],
        (11, 5): ["rock_pillar"],
        (3, 9): ["rock_pillar"],
        (11, 9): ["rock_pillar"],
        (6, 3): ["rubble"],
        (8, 3): ["rubble"],
        (6, 11): ["rubble"],
        (8, 11): ["rubble"],
        (4, 6): ["arc"],
        (10, 6): ["arc"],
        (4, 8): ["spark"],
        (10, 8): ["spark"],
        (8, 5): ["conduit"],
        (6, 9): ["conduit"],
        (6, 5): ["arc"],
        (8, 9): ["arc"],
    }
    apply_props(cells, props)
    return cells


def write_readme_five(all_counts: dict):
    def row(c):
        share = (c["mud"] + c["water"]) / 225 * 100
        return (
            f"ground **{c['ground']}** · mud **{c['mud']}** · water **{c['water']}** · "
            f"lava **{c['lava']}** · mud+water **{share:.1f}%** · elev≥1 **{c['elev']}**"
        )

    ch, br, sl, wi, st = (
        all_counts["crosshaven"],
        all_counts["brinewake"],
        all_counts["slagcrown"],
        all_counts["windmere"],
        all_counts["stormspire"],
    )
    text = f"""# Koliseo 15×15 Tiled maps (STASIUM XV)

Built for Mauro · Sep 24 2026 (ET). Ship size **15×15** for all five arenas.

**Tiles:** painted dress **v1** (Dofus/Wakfu isometric vibes — warm Crosshaven golds/greens, mud brown, water teal; region tints for Brinewake / Slagcrown / Windmere / Stormspire). Replaces flat placeholder diamonds; terrain/elev tags unchanged. Crosshaven shell composite: `crosshaven_15x15_painted_preview.png`.

## Orientation (locked)

| Item | Value |
|------|--------|
| Tiled `orientation` | **`isometric`** (classic diamond — **not** `staggered`) |
| Tile size | **64×32** px (diamond bounding box) |
| Screen compass | N = up-right, E = down-right, S = down-left, W = up-left |
| Cell → local | `cell_to_local(x,y) ≈ ((x-y)*32, (x+y)*16)` |
| Godot 4 | Import `.tmx` / isometric TileMap; same diamond math. |

## Maps

| Arena | TMX | Tags | Preview |
|-------|-----|------|---------|
| Crosshaven | `crosshaven_15x15.tmx` | `crosshaven_15x15_tags.json` | `crosshaven_15x15_preview.png` |
| Brinewake | `brinewake_15x15.tmx` | `brinewake_15x15_tags.json` | `brinewake_15x15_preview.png` |
| Slagcrown | `slagcrown_15x15.tmx` | `slagcrown_15x15_tags.json` | `slagcrown_15x15_preview.png` |
| Windmere | `windmere_15x15.tmx` | `windmere_15x15_tags.json` | `windmere_15x15_preview.png` |
| Stormspire | `stormspire_15x15.tmx` | `stormspire_15x15_tags.json` | `stormspire_15x15_preview.png` |

Shared: `tileset_koliseo_base.tsx`, `tiles/*.png`, `koliseo_common.py`.

### Cell counts

| Arena | Counts |
|-------|--------|
| Crosshaven | {row(ch)} |
| Brinewake | {row(br)} |
| Slagcrown | {row(sl)} |
| Windmere | {row(wi)} |
| Stormspire | {row(st)} |

## Layers

| Layer | Meaning |
|-------|---------|
| `ground` | Region-tinted base ground under every playable cell |
| `terrain` | Mud / water / lava overlays (empty = ground) |
| `elevation` | Height variants (`*_e1`, `*_e2`, `*_mud_e1`). Empty = elevation 0 |
| `props_paint` | Paint-only placeholders — **no combat block / LoS / MP** |
| `meta` | Reserved (empty) |

## Terrain tags (Rules Keeper)

Combat-relevant:

- `ground` — MP 1
- `mud` — MP 2
- `water` — MP 2
- `lava` — voluntary impassable; push → Burn (**Slagcrown only** among these five)
- `elevation` — int; climb ≤1 / drop ≤2; every elev≥2 cell has an ortho neighbor elev≥1 ramp

Paint-only (NO block / LoS / cost): ruins, wells, hay, fences, rubble, rock pillars, floor seals, driftwood, waterfall, rock_cluster, basalt_pillar, steam_vent, ash_rock, crystal, ice_shard, ice_sheet, spark, conduit, crystal_bolt, arc. **Ice / electric conduits are paint-only — no Locked ice or charged terrain.**

### Per-region notes

- **Crosshaven** — warm gold plains; mud+water texture; no lava. Builder: `build_crosshaven.py`.
- **Brinewake** — teal stone + ocean floods; more water than Crosshaven; silt mud; lava 0.
- **Slagcrown** — ash/basalt; Locked lava spoke channels; steam-pool water; little mud. Non-lava cells form one reachable set with lava impassable.
- **Windmere** — ice-blue ground; meltwater + sparse mud; ice/crystal/spark props are paint-only.
- **Stormspire** — dark slate/charcoal; wet cyan pools + scorched mud; conduit/spark/arc/crystal_bolt props paint-only (no charged MP / block / LoS). Builder: `build_stormspire.py`.

## How Godot should load tags

1. Prefer `{{arena}}_15x15_tags.json` as combat authority.
2. Schema: `{{ "size": [15,15], "cells": [ {{ "x", "y", "terrain", "elevation", "paint_only" }}, ... ] }}`
3. `terrain` ∈ `ground|mud|water|lava`.
4. Movement: read `terrain` + `elevation` only. Ignore `props_paint`.

## Rebuild

```bash
# Crosshaven only (does not touch other arenas' layouts)
python3 /workspace/art/maps/arena_colosseum_v2/tiled/build_crosshaven.py

# Brinewake + Slagcrown + Windmere (extends shared tileset; leaves Crosshaven board)
python3 /workspace/art/maps/arena_colosseum_v2/tiled/build_koliseo_regions.py

# Stormspire only (extends tileset with storm_* + conduit props; does not rewrite other tags)
python3 /workspace/art/maps/arena_colosseum_v2/tiled/build_stormspire.py
```

## Open in Tiled

```bash
tiled /workspace/art/maps/arena_colosseum_v2/tiled/brinewake_15x15.tmx
tiled /workspace/art/maps/arena_colosseum_v2/tiled/slagcrown_15x15.tmx
tiled /workspace/art/maps/arena_colosseum_v2/tiled/windmere_15x15.tmx
tiled /workspace/art/maps/arena_colosseum_v2/tiled/stormspire_15x15.tmx
```
"""
    path = ROOT / "README.md"
    path.write_text(text)
    return path


def main():
    print("Generating full tile catalog (base GIDs stable + region tints + storm)…")
    catalog = generate_full_catalog()
    print(f"  {len(catalog)} tiles")

    print("Writing extended tileset…")
    tsx, id_of = write_tsx(catalog)
    ET.parse(tsx)
    print(f"  XML OK: {tsx.name}")

    expected_base = [
        "ground", "mud", "water", "lava", "void",
        "ground_e1", "ground_e2", "mud_e1",
        "prop_ruins", "prop_well", "prop_hay", "prop_fence",
        "prop_rubble", "prop_rock_pillar", "prop_floor_seal",
    ]
    for i, name in enumerate(expected_base):
        assert id_of[name] == i, (name, id_of[name], i)
    assert "storm_ground" in id_of
    assert "prop_conduit" in id_of
    assert "prop_crystal_bolt" in id_of
    assert "prop_arc" in id_of
    print("  Base GID stability OK; storm tiles present")

    # Read existing arena counts — do NOT rewrite their tags
    results = {}
    for name in ("crosshaven", "brinewake", "slagcrown", "windmere"):
        tags = json.loads((ROOT / f"{name}_15x15_tags.json").read_text())
        results[name] = counts_of(tags)

    cells = design_stormspire()
    print("\n=== stormspire ===")
    counts, share, _ = validate_board(
        cells, expect_lava=False, mud_water_band=(0.15, 0.25)
    )
    assert counts["lava"] == 0
    # Voluntary walk fully reachable (no lava): all 225 cells walkable
    from koliseo_common import lava_reachability

    reached, walkable, ok = lava_reachability(cells)
    assert ok and walkable == 225, (reached, walkable)

    tmx = write_tmx(cells, id_of, "stormspire", "storm")
    tags_path, tags = write_tags(cells, "stormspire")
    preview = write_preview(
        cells, "stormspire", "15×15 Stormspire Tiled", (36, 40, 52), "storm"
    )
    ET.parse(tmx)
    assert tags["size"] == [15, 15]
    assert len(tags["cells"]) == 225
    # Combat terrain only
    for c in tags["cells"]:
        assert c["terrain"] in ("ground", "mud", "water", "lava")
        for p in c["paint_only"]:
            assert p not in ("charged", "block", "los")

    results["stormspire"] = counts
    readme = write_readme_five(results)

    print(f"  COUNTS {counts} share={share:.3f} reach={reached}/{walkable}")
    print(f"  tmx {tmx}")
    print(f"  tags {tags_path}")
    print(f"  preview {preview}")
    print(f"  README → {readme}")
    print("DONE — Stormspire built; other arenas' tags untouched.")


if __name__ == "__main__":
    main()
