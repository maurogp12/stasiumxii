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
- `tree`: `tree.png` is the golden oak in v2 (PROPOSED species, see "Tree species" below). Same-footprint variants: `tree_golden_oak(_v2)`, `tree_birch`, `tree_apple`, `tree_willow`, `tree_chestnut`, `tree_poplar(_v2)`, plus legacy `tree_oak_a/b`, `tree_autumn_a/b`, `tree_pine`.
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


## v2 art pass (Wakfu quality pass + farmland, vegetation, tree species)
It's a drop-in: every v1 file name, id, pixel size, anchor and footprint is unchanged, and `_2x` masters are exactly 2x. Checks are in `tools/validate_v2.py`, with results in `v2/_checks/validate_v2.json` on the art box. The v1 entries in `atlas_meta.json` are untouched apart from `tree` (see below). New entries carry `v2_new: true`, and there's a summary under `v2_art_pass`.

### What changed on existing files
- **Floors:** Scenario textures are the base fill (`golden_plains`, `dirt_road`, `water`, `cliff_rock` on faces, `cobble` for the plaza and town centres). Top surfaces are rotated 45 degrees and squashed 2:1; `cliff_rock` goes on faces unrotated. The textures are colour-matched to the palette and high-passed, then brush dabs and warm-light/cool-shadow shifts go on top. The painted AO, turf lip, edge and lighting overlays are kept above the textures. Water gets depth, shallows, foam and a few glints.
- **Cliff/earth face strips:** facets run continuously across height steps, the top step has a grass overhang with under-lip AO, and base pieces have rubble or foam.
- **Props:** scalloped leaf canopies, painterly hue shifts, height AO, coloured soft outline, and non-clipped contact shadows. Geometry is the same as v1.
- **Alpha:** RGB is zeroed under alpha 0 everywhere. v1 had stray RGB there.

### Texture repetition / world-space note
Tile PNGs repeat per cell, so a texture can repeat at most once per cell. Large-scale variation comes from the walkable 3x3 ground-patch decals instead. A truly seamless world-space look needs a Godot shader that samples a world-UV texture, masked by tile alpha. That isn't part of this kit.

### New tiles (all 64x32 floors use the same anchor as v1)
- **Farmland:** `farm_soil_*`, `farm_cabbage_*`, `farm_pumpkin_*`. Each has `_a/_b` plus 15 `_edge_<sides>` and 4 `_corner_<c>` pieces, with crop rows along +x and 4 per cell. They're walkable visual variants of `golden_plains`. Autotile them like `golden_plains_wheat`: each family joins only itself. `tools/cw_autotile.py` already has `farm_soil`, `farm_cabbage` and `farm_pumpkin` in `PREFIX`, `JOIN` and `VARS`. Golden wheat is the existing `golden_plains_wheat_*`.
- **Out-of-bounds:** `cliff_side_left/right_void_fade` and `_void` (the chunk-edge drop: top, cliff a/b, one fade, then void), plus `border_forest_floor_a/b`.

### New props
- **Farm:** `barn_2x2`, `cart`, `farm_fence_nesw`, `farm_fence_nwse`, `farm_gate_nesw`, `farm_gate_nwse`, `farmhouse_2x2`, `scarecrow`, `windmill_2x2`. These sit alongside v1's `well`, `hay_bale`, `haystack` and `barrels_group`. The 2x2 buildings use the same footprint rules as `red_roof_cottage`. For fences and gates, `nwse` means the rail runs along +x.
- **Vegetation, blocking:** `hedgerow_nesw`, `hedgerow_nwse`, `rock_large_b`, `rock_large_mossy`, `tree_cluster_2x2_a`, `tree_cluster_2x2_b`, `tree_cluster_2x2_c`, `tree_cluster_2x2_d`.
- **Walk-through decor** (walkable, never changes pathing): `bush_small_a`, `bush_small_b`, `flowers_c`, `flowers_d`, `grass_tuft_a`, `grass_tuft_b`, `grass_tuft_tall_a`, `mushrooms_a`, `mushrooms_b`, `reeds_a`, `reeds_b`, `rock_small_c`, `rock_small_d`.
- **Ground decals** (walkable; ground layer, no y-sort): `ground_patch_dark_a`, `ground_patch_dark_b`, `ground_patch_dirt_dark_a`, `ground_patch_dirt_light_a`, `ground_patch_golden_a`, `ground_patch_light_a`, `ground_patch_light_b`.
- **Out-of-bounds forest wall:** `border_forest_a/b/c`. Put these on a 3-4 cell ring outside the chunk only.

### Tree species (PROPOSED, design to confirm; no gameplay values)
Trees are planned as harvestable resources (lumberjack style), so Crosshaven gets its own regional set. The six species have clearly different silhouettes and colours. Each is a 1x1 footprint that blocks, and each has a harvested stump state `tree_<species>_stump.png` on the same cell.
| species (proposed) | files | habitat | reads as |
|---|---|---|---|
| Golden oak | `tree_golden_oak`, `tree_golden_oak_v2`, compat `tree` | open plains, groves | broad round amber-gold canopy |
| White birch | `tree_birch` | grove edges, light woods | slim pale twin trunks, airy lime crown |
| Orchard apple | `tree_apple` | orchards beside farms | small round crown, red fruit |
| Weeping willow | `tree_willow` | river banks, ponds | drooping curtain, sage green |
| Sweet chestnut | `tree_chestnut` | deep groves, old woods | tall dark dome, spiky burrs |
| Lombardy poplar | `tree_poplar`, `tree_poplar_v2` | lining roads, field rows | tall narrow column |

- `props/tree.png` (the zone id `tree`) is now the golden oak, with the v1 size and anchor kept. `tree_oak_a/b`, `tree_autumn_a/b`, `tree_pine` and `tree_great_oak` stay as generic scenery variants.
- The 2x2 `tree_cluster_*` and `border_forest_*` are scenery, not single harvest nodes.
- In `atlas_meta.json`, species entries have `harvestable`, `species` and `status: PROPOSED`. Stumps have `harvestable_state: harvested` and `stump_of`. The species summary is at `v2_art_pass.tree_species_PROPOSED`.

### Caveats
- Walk-through decor and ground decals can't be referenced from zone data yet. Backend needs to add a WorldZone decor layer.
- Every new blocking prop (farm buildings, fences, hedgerows, species trees placed beyond zone data) needs zone-data blockers on every footprint cell before use.
- The mock dressing is an art-direction suggestion and isn't in zone data. That covers farm lots, fences, farmsteads, orchards, hedgerows, poplar rows, willows, reeds, groves, the border forest, and the rule mapping zone `tree` props to species by habitat.

### v2 mocks (`art/pc/crosshaven_world/mock/` on the art box)
- `v2_crossroads_2x.png`: the same spawn view as the v1 dressed mock.
- `v2_crossroads_full_2x.png` / `v2_crossroads_full_1x.png`: the whole chunk with the out-of-bounds border.
- `v2_before_after_crossroads.png`: v1 vs v2, zone-only panels, and a strip of the Scenario textures with the tiles they produced.
- `v2_before_after_northgate.png`, `v2_before_after_eastmarch.png`.
- `v2_crosshaven_world_1x.png` (+ `_preview`): all 11 chunks placed by exit links. `road_southwest` and `westwatch` are shifted 30 cells south, because the links are portals and a literal layout would overlap.
- `v2_tree_species.png`: the species lineup with stumps and a silhouette test.

## v3 art pass (town identities, anti-repetition ground, steep cliffs) - all PROPOSED

Everything below is additive and box-only. v1 file names, ids, pixel sizes and anchors are unchanged, and every new file has an
`atlas_meta.json` entry with `v3: true` and `design_status: PROPOSED`. The dressing in the v3 mocks is an art-direction suggestion
and is not zone data.

**New props** (bottom-centre anchor on the south tip of the south-most footprint cell, as before)
- Walls: `stone_wall_high_nwse` / `stone_wall_high_nesw` (1x1 segments), `wall_tower` (Northgate walls and gate towers).
- `watchtower_2x2` (Westwatch).
- Water and fishing: `dock_nwse` / `dock_nesw` (walkable deck over water; zone data would need those water cells walkable),
  `fishing_hut_2x2`, `rowboat`, `net_rack`, `lilypads_a` (Eastmarch).
- `ford_stones` (Stoneford). Stone bridges reuse the box-only `dirt_road_bridge_stone_*` and `bridge_parapet_*` pieces.
- Quarry: `quarry_rocks_a`, `quarry_blocks` (Stoneford).
- `watermill_2x2` (Southbridge pond). Market stalls reuse `market_stall(_b)`.
- `waystone` (road chunks; `signpost_small` is reused).
- Decal: `ground_patch_marsh_a`, a 3x3 ground decal with no y-sort and walkable.
- Cottage roof variants of zone prop `red_roof_cottage`. They keep the same 2x2 footprint and anchor, so they are a straight swap per town:
  - Northgate: `cottage_slate(_b)`
  - Stoneford: `cottage_stone(_b)`
  - Eastmarch: `cottage_thatch(_b)`
  - Westwatch: `red_roof_cottage(_b)`
  - Southbridge: `cottage_terracotta(_b)`
- `tree_willow` re-drawn with arching strands (same id and size class as v2).

**New tiles** (64x32 floor diamonds)
- `golden_plains_e/f/g/h` and `dirt_road_e/f`: the interior texture is sampled at a different offset and the edges match the shared base, so they are seamless. Use any of them on any cell, picked at random.
- `golden_plains_lit_a/b` (+3.5%), `golden_plains_shade_a/b` (-4.5%), `dirt_road_g` (lighter) and `dirt_road_h` (darker): the tint feathers to 30% at the edges. Place them only in low-frequency world-noise clusters; a lone cell reads as a soft spot.
- `cliff_steep_a/b`: a cliff top painted as a steep rock wall. Use it on cliff cells whose +x or +y neighbour is lower. Draw their 1-step faces with `cliff_side_*_a/b` and put `base_ground` / `base_water` only at the foot, with no grass `top` lip mid-wall. A stack of 1-step cliff rows then reads as one tall wall.
- All `cliff_side_*` strips are re-drawn at the same 32x26 size: stronger facets, strata and joints, vertical streaks that stay continuous across steps, foot darkening, and deeper lip and base AO.

**Height limit:** zone data rises 1 step (10 px) per row, so cliffs can only read taller by stacking rows. Really tall faces need
height jumps of 2 or more steps between neighbouring cells in zone data. The strips already tile vertically for that.

**Mocks:** in `/workspace/art/pc/crosshaven_world/mock/`:
- `v3_<town>_2x.png`
- `v3_crosshaven_world_preview.png`
- `v3_towns_contact.png`

Scripts: `v2/tools/cw_mock_v3.py`, `cw_v3_towns.py`, `cw_world_v3.py`, `cw_v3_contact.py`.

## v4 "alive" pass (PROPOSED, art-direction suggestion)
Additive only. v1 ids, file names, sizes, anchors and footprints are unchanged (validated). Re-pack order: `cw_pack_v2.py`, then `cw_pack_v4.py`.

**Fidelity**
* Masters are still painted at 8x supersampling (SS=8) and area-downsampled to 2x and 1x. That's already above the suggested 4x authoring, so the v4 gain comes from brushwork and detail instead:
  * chunky individually painted roof tiles (value and hue jitter, lit lips, cast lines, a few skewed or missing tiles, moss)
  * bowed timbers and braces
  * mottled plaster with exposed stone patches
  * irregular base stones
  * window flower boxes
  * ridge caps and soot-dark chimney mouths
* These apply to every cottage-family prop (v1 `red_roof_cottage*` plus the v2/v3 variants, `farmhouse_2x2` and `watermill_2x2`), all at the same canvas sizes.
* New light passes on every non-decal prop: a warm ground-bounce light low on the faces and a soft top-to-bottom grade. They sit on top of the existing rim light, AO and painterly passes.
* Scenario was **not** used in v4: this box session has no access to it (0 units spent). All surfaces are procedural.

**New props** (`props/`, PROPOSED):
* `smithy_2x2`: stone forge house, teal tile roof, open-air glowing forge with hood, anvil, quench barrel, tool rack, giant anvil sign.
* `tavern_3x2`: two storeys, teal roof, lanterns, benches, barrels, giant foaming-mug sign.
* `bakery_2x2`: domed bread oven, flour sacks, giant loaf sign.
* `fountain_2x2`: two-tier fountain with a gilded bird finial.
* `brazier`
* clutter: `sacks_a`, `firewood_stack`, `anvil`, `tool_rack`, `laundry_line` (2x1), `potted_plants_a`, `bench_nwse`, `bench_nesw`, `cart_large` (oversized wheels), `crate_apples`
* walkable ground decals: `decal_flowers_pink`, `decal_flowers_yellow`, `decal_pebbles`, `decal_leaves`, `decal_moss`, `decal_path_stones_a`, `decal_path_stones_b`, `decal_dirt_blend`
* overlay bodies: `windmill_2x2_body` (no sails) and `watermill_2x2_body` (no wheel), on the same canvas and anchor as the full props

**New tiles**: `dirt_road_flagstone_a`, `_b`, `_c` and `_d`: big irregular pavers (clean, cracked, mossy, carved rosette), seamless. These are a walkable interior variant of the cobble family for town squares.

**animated/**: sprite-strip loops with `README.md` (frame counts, fps, anchors, Godot wiring) and `anim_meta.json`.
* vegetation sway for 31 tree, bush and grass ids (+ sway masks)
* 44 water ripple flipbooks
* windmill sails, watermill wheel and fountain water overlays
* fire, embers and smoke puffs
* falling leaves and fireflies
* butterflies, bird + shadow, chicken walk/peck, cat idle/walk
* two tileable cloud-shadow textures

**Post FX**: `GODOT_POSTFX_NOTES.md` covers WorldEnvironment glow, the colour-grading LUT, the vignette and haze CanvasLayer, cast shadows and cloud shadows. These are suggestions only.

**Mocks** (`/workspace/art/pc/crosshaven_world/mock/`):
* `v4_crossroads_alive.mp4/.gif` and `v4_southbridge_alive.mp4/.gif` (+ bonus `v4_eastmarch_alive.mp4/.gif`)
* `v4_crossroads_2x.png`, `v4_<town>_2x.png`, `v4_towns_contact.png` and `v4_vs_wakfu.png`

Landmark, clutter and decal placement in the mocks is renderer dressing (`cw_alive_v4.py`), not zone data. Before shipping, it needs zone-data blockers for every blocking footprint cell.
