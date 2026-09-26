# Koliseo 15×15 Tiled maps (STASIUM XV)

## See it in Godot

1. Open `project.godot` in Godot 4.7+. The main scene is `res://scenes/class_select.tscn` (960×720).
2. Press **F5 / Play**.
3. Click **Hot-seat**. There is no map chooser.
4. P1 picks a class, then P2. The duel opens `res://main.tscn` on a uniform random arena: Crosshaven, Brinewake, Slagcrown, Windmere, or Stormspire. **New Match** rolls again.
5. `BoardView` paints that arena from `{arena}_15x15_tags.json` on the 64×32 diamonds. `paint_only` never blocks pathing, LoS, or MP. Middle-mouse pans.
6. Online queue stays on Crosshaven (the dedicated host does not share a map pick).

Combat authority is the tags JSON. The sibling `.tmx` is isometric art.

Built for Mauro · Sep 24 2026 (ET). Ship size **15×15** for all five arenas.

**Tiles:** slices of the original isometric sheets in `art/tilesets/original/` (64×32 diamonds). Crosshaven is grassland. Brinewake is coast stone. Slagcrown is lava. Windmere is pale stone until the ice sheet lands. Stormspire is dark stone until the electric sheet lands. See `art/tilesets/original/THEMES.md`. Terrain/elev tags unchanged.

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
| Crosshaven | ground **177** · mud **30** · water **18** · lava **0** · mud+water **21.3%** · elev≥1 **18** |
| Brinewake | ground **174** · mud **16** · water **35** · lava **0** · mud+water **22.7%** · elev≥1 **18** |
| Slagcrown | ground **171** · mud **2** · water **8** · lava **44** · mud+water **4.4%** · elev≥1 **24** |
| Windmere | ground **191** · mud **10** · water **24** · lava **0** · mud+water **15.1%** · elev≥1 **24** |
| Stormspire | ground **181** · mud **18** · water **26** · lava **0** · mud+water **19.6%** · elev≥1 **27** |

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

1. Prefer `{arena}_15x15_tags.json` as combat authority.
2. Schema: `{ "size": [15,15], "cells": [ { "x", "y", "terrain", "elevation", "paint_only" }, ... ] }`
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
