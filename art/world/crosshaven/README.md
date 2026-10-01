# Crosshaven open-world art kit (PC, Godot 4.3+)

Art only. Ground tiles and props for the Crosshaven open-world chunks in PR #210 (`data/world/crosshaven/`). They drop into the scene in PR #211 (`scenes/world/crosshaven/`) without code changes: that scene loads `tiles/<terrain>.png` and `props/<type>.png` when they exist and draws stand-ins otherwise.

Look: soft hand-painted, Wakfu-like. Colours are saturated golden plains. Props have clean dark outlines. Lighting is neutral daylight with no baked cast shadows, only small soft contact shadows, so the day/night and weather tint can recolour everything.

## Layout

```
art/world/crosshaven/
  atlas_meta.json        every tile and prop: id, file, size, anchor, footprint, walkable, base zone id
  README.md
  tiles/<id>.png         1x primary (64 px wide), draw at scale 1
  tiles/_2x/<id>.png     2x master (128 px wide), draw at scale 0.5, same placement
  props/<id>.png         1x primary
  props/_2x/<id>.png     2x master
  _mock/                 review renders only (has .gdignore, so Godot does not import it)
```

Import settings: linear filter, no mipmaps, plain (not premultiplied) alpha. All ids are snake_case.

## Zone ids (PR #210): exact file names

| zone id | file | footprint (from NW origin) | image anchor |
| --- | --- | --- | --- |
| `golden_plains` | `tiles/golden_plains.png` (= `golden_plains_a`) | 1 cell | bottom on south tip |
| `dirt_road` | `tiles/dirt_road.png` (= `dirt_road_a`, full road interior) | 1 cell | bottom on south tip |
| `water` | `tiles/water.png` (= `water_a`) | 1 cell | bottom on south tip |
| `cliff` | `tiles/cliff.png` (= `cliff_a`, mossy rock top) | 1 cell | bottom on south tip |
| `tree` | `props/tree.png` (= `tree_oak_a`) | 1x1 | bottom-centre on south tip of the cell |
| `fence` | `props/fence.png` (= `fence_wood_nwse`) | 1x1 | same |
| `red_roof_cottage` | `props/red_roof_cottage.png` | 2x2 | bottom-centre on south tip of origin+(1,1) |
| `crossroads_centerpiece` | `props/crossroads_centerpiece.png` | 2x2 | same (obelisk on the shared vertex of the 4 cells) |
| `northgate_spire`, `stoneford_spire`, `eastmarch_spire`, `westwatch_spire`, `southbridge_spire` | `props/<id>.png` | 2x2 | same |

Every zone id has a file. `atlas_meta.json > zone_id_map` lists the extra variants and autotile pieces for each base id. Every tile entry carries `base_terrain`, and every prop entry carries `base_id` (null when the prop is not in zone data yet).

## Grid

Each tile is a 64x32 diamond (top face), and each height step is 10 px.

`cell_to_local(x, y, elev) = ((x - y) * 32, (x + y) * 16 - elev * 10)`, which is the diamond centre. The south tip is centre + (0, 16).

Neighbour names used in tile ids:
- Sides: `nw` = (x-1, y), `ne` = (x, y-1), `se` = (x+1, y), `sw` = (x, y+1).
- Diagonal corners: `n` = (x-1, y-1), `e` = (x+1, y-1), `s` = (x+1, y+1), `w` = (x-1, y+1).

## Tiles

### Anchor
The image's bottom-centre sits on the cell's south tip, the same rule as `board/tile.gd`:

`draw_texture(tex, cell_to_local(cell, elev) + Vector2(-w/2, 16 - h))`

Floor and decal tiles are exactly 64x32, so the image is the diamond. They tile with no seams; the seam test is in `_mock`. A 0.5 px alpha bleed on the diagonal edges stops hairline gaps.

### Families
All of these are visual variants. None of them changes walkability; zone data stays authoritative.

| family | base id | pieces |
| --- | --- | --- |
| `golden_plains_a/b/c/d`, `golden_plains_golden_a/b`, `golden_plains_flowers_a/b/c` | golden_plains | plain variants; pick by hash or noise |
| `golden_plains_wheat_*` | golden_plains | wheat field: `_a/_b/_c`, 15 `_edge_<sides>`, 4 `_corner_<c>` |
| `golden_plains_sand_*` | golden_plains | sand/shore: same set |
| `dirt_road_a/b/c/d` | dirt_road | road interior |
| `dirt_road_edge_<sides>` | dirt_road | 15 edge pieces: the listed sides touch grass |
| `dirt_road_corner_<c>` | dirt_road | 4 inner-corner decals |
| `dirt_road_path_*` | dirt_road | narrow 1-cell path set: `end_`, straight `nw_se`/`ne_sw`, `turn_`, `t_`, `cross` |
| `dirt_road_cobble_*` | dirt_road | cobble town plaza: `_a/_b/_c`, 15 edges, 4 corners |
| `water_a/b/c/d`, `water_deep_a/b` | water | open water |
| `water_bank_<sides>`, `water_bank_corner_<c>` | water | earthy grass bank |
| `water_shore_<sides>`, `water_shore_corner_<c>` | water | sandy shore, used when every land side is sand |
| `cliff_a/b/c`, `cliff_edge_<sides>`, `cliff_corner_<c>` | cliff | rock top with grass fringe toward plains |
| `<terrain>_side_left_*`, `<terrain>_side_right_*` | (any) | 10 px height-step faces, see below |

`<sides>` is any non-empty subset of `nw, ne, se, sw` in that order, joined by `_`, for example `dirt_road_edge_nw_se`. Here "grass" means any cell that does not join the family:
- road joins road and cobble.
- cobble joins cobble and road.
- wheat joins wheat.
- sand joins sand and water.
- water joins water.
- cliff joins cliff.

### Autotile picker
This ports 1:1 to GDScript. `h(x, y, k)` is `((x*73856093) ^ (y*19349663) ^ (x*y*83492791)) & 0x7fffffff) % k`.

1. Find `g`, the sides in order `nw, ne, se, sw` whose neighbour does not join the cell's family. Cells outside the chunk count as grass.
2. If `g` is empty, use an interior variant chosen by `h`. Otherwise use `<prefix>_edge_<g>`. For water the prefix and piece name are `water_bank_<g>`, or `water_shore_<g>` when every non-water side is sand.
3. For each diagonal corner `c` whose two adjacent sides are not in `g`, but whose diagonal neighbour does not join, draw `<prefix>_corner_<c>` right after the floor tile. For water this is `water_bank_corner_<c>` or `water_shore_corner_<c>`.

The `_mock` renders use this exact picker. They also use visual-only dressing: a cobble ring of radius 4.2 around `crossroads_centerpiece`, rectangular wheat lots, and sand next to water.

### Height faces
PR #211 lifts each tile by `elev * 10` and paints flat placeholder faces. To upgrade, draw strips before the tile top. For each step `k = 0 .. (elev - neighbour_elev - 1)`, measured from the lifted south tip:
- Left face (under the `sw` edge): top-left = south_tip + (-32, -16 + 10k).
- Right face (under the `se` edge): top-left = south_tip + (0, -16 + 10k).

Each strip is 32x26. Variants:
- `top` for k = 0.
- `a`/`b` alternating in the middle.
- `cliff_side_*_base_ground` or `cliff_side_*_base_water` for the lowest cliff step.

Materials:
- `cliff_side_*` is rock.
- `golden_plains_side_*` is earth.
- `dirt_road_side_*` is ashlar stone, used for raised plaza or road edges.

## Props

### Anchor
The image's bottom-centre sits on the SOUTH tip of the footprint's south-most cell, which is the one with max x+y. Lift it by that cell's height:

`draw_texture(tex, cell_to_local(south_cell, elev) + Vector2(0, 16) + Vector2(-w/2, -h))`

For the 2x2 zone props, the south-most cell is origin+(1,1). From the NW anchor cell's diamond centre, the image bottom-centre is at **(0, +48) px at 1x** ((0, +96) at 2x). The NW origin only defines which cells are covered. `atlas_meta.json` gives these per prop:
- `footprint_from_nw`
- `anchor_cell_from_nw`
- `bottom_centre_from_nw_centre_1x`

Overhang (eaves, canopies) extends upward and sideways inside the image. Contact shadows are clipped at the south tip.

### Depth sort
Sort by the south-most footprint cell (x+y), as #211 does with `z = (x+y)*TILE_Z_SCALE + 2`. If you use a y-sort point instead, put it at image bottom - 16 px, which is the centre of the south-most cell, and break ties in favour of characters. With that rule, a character beside a 2x2 building on its east or south side draws in front, and one on its north or west side draws behind.

### Fence direction
`fence.png` is `fence_wood_nwse`: the rail runs along +x, from screen up-left to down-right. When the neighbouring fence cells are at y±1, use `props/fence_wood_nesw.png`. #211 already computes `_fence_axis` but always draws `fence.png`. A two-line switch to the `_nesw` file when `_fence_axis == 1` finishes this; that change belongs in the Godot scene, not here. `fence_post` is a single end post.

### Variants of zone props
These have the same footprint, so pick one per placement, for example by `h(origin)`:
- `tree`: `tree_oak_a` (default), `tree_oak_b`, `tree_autumn_a`, `tree_autumn_b`, `tree_pine`.
- `red_roof_cottage`: default (ridge along x) or `red_roof_cottage_b` (mirrored, taller roof).

### Extra props (not yet in zone data)
These are ready to place once zone data has ids or blockers for them. Walkable ones are marked.
- Trees and plants: `tree_great_oak` (2x2), `bush_a/b/flower/autumn`.
- Walkable decor: `tuft_a/b`, `flowers_a/b`, `rock_small_a/b`.
- Rocks: `rock_medium`, `rock_large`.
- Walls and fence: `stone_wall_low_nwse/nesw`, `fence_post`.
- Signs: `signpost_crossroads` (5 town-colour arms), `signpost_small`.
- Clutter: `crate`, `crate_stack`, `barrel`, `barrels_group`, `haystack`, `hay_bale`.
- Lighting: `lamp_post` plus `lamp_glow`. The glow uses additive blend, so fade it in at night.
- `well`.
- Stalls: `market_stall`, `market_stall_b` (2x1 along x).
- Larger cottages: `red_roof_cottage_3x2`, `red_roof_cottage_3x3`. Their footprints differ from the 2x2 zone id.
- Ground decal: `crossroads_plaza_decal`, a walkable compass inlay of 4x4 cells centred on the centrepiece vertex (origin-1 .. origin+2). Draw it on the ground layer with no y-sort.
- Town gate: `town_gate_<axis>_full` is a single 4-cell sprite. For correct depth, use the split pieces along 4 cells g0..g3 (NW to SE):
  - `_back` pillar on g0.
  - `_arch` over g1 and g2. It is walkable underneath; draw it on an overhead layer or sort it with the front pillar.
  - `_front` pillar on g3.
  - `nwse` means the wall runs along x with the road along y; `nesw` is the reverse.

The bridge, ford and height-block pieces stay off this PR until crossing data exists: `bridge_*`, `dirt_road_bridge_*`, `*_block_h*`. They live on the art box.

## TileMapLayer (optional)
To move from custom `_draw` to TileMapLayer, set up the TileSet like this:
- `tile_shape = ISOMETRIC`, `tile_layout = DIAMOND_DOWN`, `tile_size = (64, 32)`. DIAMOND_DOWN should make `map_to_local` match `cell_to_local` at elev 0; check that `map_to_local(Vector2i(1, 0))` returns (32, 16) when you set it up.
- Add one atlas source per family (or one per PNG) with region 64x32 and `texture_origin = (0, 0)`.
- Use one TileMapLayer per height level, with `position.y = -10 * elev`. Draw the face strips on the same layer, or a layer beneath it.
- Put props in a separate y-sorted Node2D, not in the TileMapLayer.
- For 2x masters, set the layer `scale = 0.5` with 128x64 tiles.

## Mocks (`_mock/`)
Each mock is rendered from these files with the anchors above, over PR #210 zone data (head 00748ed).
- `mock_crossroads_view_2x.png`: zone data plus walkable tufts.
- `mock_crossroads_dressed_view_2x.png` and `mock_northgate_dressed_view_2x.png`: add suggested extra trees, bushes and haystacks that are not in zone data. They are an art-direction suggestion only.
- `*_full_1x.png`: whole chunks.
- `compare_wakfu_crosshaven.png`: side by side with an in-game Wakfu frame.
