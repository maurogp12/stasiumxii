# Wiring note: L9 outdoor board kit → `art/pc/look/crosshaven_board/` (DRAFT)

Status: **draft, not sent.** Send to Stasium Bot only after the kit passes the gate with 0 FAIL / 0 WARN on the `blocks` row, and after Luca rules on the open items below.
Kit: `ship/l9_outdoor_board/` v1.2 (Sat 3 Oct 2026 ET). Map data, grid and CombatSim stay as they are.

## 1. Drop-in
- Copy `ship/l9_outdoor_board/{tiles,terrace,props,looks.json,atlas_meta.json,props.json}` → `art/pc/look/crosshaven_board/` (the gate reports stay behind).
- **Do not overwrite** the shared stock `tiles/` or `art/maps/arena_colosseum_v2/tiled/crosshaven_15x15_tags.json`. This is a PC-only look layer.
- Import every PNG as: Lossless (or BC7 on PC), **mipmaps off**, **filter Linear**, **straight alpha** (no premultiply on import), repeat off. Godot `.import`: `compress/mode=0` (or BC7), `mipmaps/generate=false`, `process/premult_alpha=false`, and texture filter Linear on the CanvasItem.
- Files: `<id>@2x.png` is the master. Draw it at scale 0.5. `<id>.png` (1x) is for low-res or fallback only.

## 2. Loader (new, PC-only; `board/koliseo_art.gd` has no @2x path)
For `map_id == crosshaven_15` with the PC look on:
1. Read `looks.json` (per-cell `look/tile/overlays/terrace`, `props[]`, `decor[]`).
2. Cell math, same as `board/visual_sort.gd` (`ELEVATION_PIXELS := 10.0` at L10, z-scale 8 at L12):
   - 1x centre = `((x-y)*32, (x+y)*16 - h*10)`
   - 2x centre = `((x-y)*64, (x+y)*32 - h*20)`
   - z = `(x+y)*10 + h*8`; fighters get +4.
3. Per-cell draw order (`looks.json.draw_order_per_cell`):
   1. Terrace faces: `cliff_left_h<n>` (SW edge), top-left at centre + (-64, 0)@2x; `cliff_right_h<n>` (SE edge), top-left at centre + (0, 0)@2x.
   2. Tile (128x64@2x), top-left at centre + (-64, -32).
   3. Overlays, in listed order, placed like the tile.
   4. `grass_overhang_left/right`, top-left at centre + (-64, -8) / (0, -8).
   5. Overhang corners (40x40, pivot at (20, 12) on the W/E vertex).
4. Faces come from neighbour heights, not hand placement. A SW face is drawn when `(x, y+1)` is lower; a SE face when `(x+1, y)` is lower. `n` = height drop (1..2 on this map; MAX_DROP 2 in `backend/elevation_cost.gd:9`). looks.json already lists them, and the gate verifies the list matches the heights.
5. Props:
   - **Thunderwell pattern** (`board/tile.gd:175-177`): hide the stock paint_only prop nodes when the look is active.
   - Then place `looks.json props[]` and `decor[]` from `props/props.json`: canvas bottom-centre on the anchor cell's south tip (`tile.gd _paint_prop`: `(-w/2, 16-h)` at 1x), lifted by `h*10` (1x) / `h*20` (2x), z of the anchor cell.
   - `seal_slab` is a tile overlay, not a prop.
   - 2c pieces anchor on the **front** cell, and their art extends over the back cell `(x-1, y)`.
6. Keep the jungle canopy tint on terrain. Draw **one** board-edge skirt only (kit `cliff_*_h2` skirt **or** the jungle earth skirt at z -40, not both).

## 3. Cover / LOS
- `props.json` gets `blocks: none|cover|los` per prop. It is **informational and must agree with map data. It never drives the sim.**
- Today CombatSim has no cover or LOS:
  - `combat_sim.gd` L58/L660/L662 mark height/LoS as "Open".
  - `_blocked_cells` (L88) is only filled by the test-config `blockers` (L2146-2148) and only read by `_is_empty` (L3896-3909).
  - Crosshaven props are all `paint_only` (`backend/cell_tag_map.gd:6`).
- So every value is `none` for now. If design later makes props block, the source of truth becomes a per-cell `blocks` key in the tags json. The gate cross-checks it with `--map-tags`.

## 4. Gate before wiring
```
python3 tools/check_assets.py ship/l9_outdoor_board --package world \
  --map-tags art/maps/arena_colosseum_v2/tiled/crosshaven_15x15_tags.json
python3 tools/check_assets.py ship/l9_outdoor_board/props --package props
```
- World: tiles, the terrace (face size 64×(32+20n), edges, seams, light, looks.json faces vs heights) and the kit metadata (`blocks` vs map) must have 0 FAIL.
- Props: the anchor-gap WARNs (10–23 px@2x) are accepted (see the check notes).

## 5. Open (need Luca / design before or right after wiring)
1. Board edge: kit skirt vs jungle skirt.
2. Tall standing stones (170 px@2x) and the 2c walls/logs overdraw a fighter on or behind them (fighter +4 only wins on the same cell). Fade, block in data, or accept?
3. `wet_earth` (mud, 2 MP) is not one of the guide's five ground materials (grass/stone/water/ash/dock). It needs an explicit guide exception (LOOK_TARGET L9 lists mud).
4. Water-foot terrace faces: 4 faces drop onto water and currently show an earth foot.
5. Grade: everything ships neutral; Mauro grades.
