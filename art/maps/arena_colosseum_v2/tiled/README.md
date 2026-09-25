# Crosshaven 15×15 — Koliseo Tiled map (STASIUM XV)

Built for Mauro · Sep 24 2026 (ET). This pack is an optional `cell_tags` map (15×15). The ship board is Mauro’s **12×12** token grid; 8×8 is proto only. It loads only when the board size matches.

## Orientation (locked)

| Item | Value |
|------|--------|
| Tiled `orientation` | **`isometric`** (classic diamond — **not** `staggered`) |
| Tile size | **64×32** px (diamond bounding box) |
| Screen compass | N = up-right, E = down-right, S = down-left, W = up-left |
| Cell → local | `cell_to_local(x,y) ≈ ((x-y)*32, (x+y)*16)` |
| Godot 4 | Import `.tmx` / use isometric TileMap; same diamond math. Staggered-isometric is a different grid and is **not** used here. |

**Why isometric (not staggered):** Matches historical game tiles and the locked `cell_to_local` formula. Tiled + Godot 4 both handle diamond isometric maps cleanly; staggered is for offset-row layouts and would break the (x−y)/(x+y) projection.

## Playable region

- Map width × height = **15 × 15**. Every cell is playable.
- No decorative outer ring in this deliverable (outer moat / plains stay in look-dev plates only). If a future shell adds OOB cells, mark them `terrain: void` in tags and paint with the `void` tile on `meta`.

## Files

| Path | Role |
|------|------|
| `tileset_koliseo_base.tsx` | Collection tileset (terrain + elev variants + paint props) |
| `tiles/*.png` | Generated 64×32 (or taller) isometric PNGs |
| `crosshaven_15x15.tmx` | Tiled map |
| `crosshaven_15x15_tags.json` | Authoritative per-cell combat tags for Godot |
| `crosshaven_15x15_preview.png` | Render preview with faint grid |
| `build_crosshaven.py` | Reproducible builder |

## Layers

| Layer | Meaning |
|-------|---------|
| `ground` | Base warm ground under every playable cell |
| `terrain` | Mud / water overlays (empty = ground). **Source of combat terrain when JSON absent** |
| `elevation` | Height variants (`ground_e1`, `ground_e2`, `mud_e1`). Empty = elevation 0 |
| `props_paint` | Paint-only placeholders (ruins, well, hay, fence, rubble, rock_pillar, floor_seal). **No combat block / LoS / MP** |
| `meta` | Reserved (all empty on Crosshaven) |

## Terrain tags (Rules Keeper)

Combat-relevant (stamp these):

- `ground` — MP 1
- `mud` — MP 2
- `water` — MP 2
- `lava` — voluntary impassable; push → Burn (**0 cells on Crosshaven**)
- `elevation` — int; climb ≤1 / drop ≤2

Paint-only (NO block / LoS / cost): ruins, wells, hay, fences, rubble, rock pillars, floor seals, outer moat, ice, dressing props. **Do not invent LoS blockers from props.**

### Crosshaven cell counts

- ground: **177**
- mud: **30**
- water: **18**
- lava: **0**
- mud+water share: **21.3%** (target ~15–25%)
- elevation ≥1: **18** cells

## How Godot should load tags

1. Prefer **`crosshaven_15x15_tags.json`** as the combat authority (backend must not invent blockers from art).
2. Schema:
   ```json
   { "size": [15,15], "cells": [ { "x":0, "y":0, "terrain":"ground", "elevation":0, "paint_only":[] }, ... ] }
   ```
3. `terrain` ∈ `ground|mud|water|lava`.
4. `paint_only` is a string array of prop names — visuals only.
5. Optionally cross-check against Tiled layers `terrain` + `elevation` tile custom properties (`terrain`, `elevation`, `paint_only` on each tileset tile).
6. Movement: read `terrain` + `elevation` only. Ignore `props_paint` for pathing / LoS.

## Tileset tile names

Terrain: `ground`, `mud`, `water`, `lava`, `void`, `ground_e1`, `ground_e2`, `mud_e1`  
Props: `prop_ruins`, `prop_well`, `prop_hay`, `prop_fence`, `prop_rubble`, `prop_rock_pillar`, `prop_floor_seal`

## Open in Tiled

```bash
tiled /workspace/art/maps/arena_colosseum_v2/tiled/crosshaven_15x15.tmx
```

Rebuild:

```bash
python3 /workspace/art/maps/arena_colosseum_v2/tiled/build_crosshaven.py
```
