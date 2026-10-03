# l9_outdoor_board: Crosshaven combat board look kit (L9 outdoor, option A) — v1.1

## v1.1 polish pass (Sat 3 Oct 2026, ET)
Same ids, file names, canvas sizes, anchors and json schema as v1 (verified by a key-by-key diff of all four json files, a file-list diff and a PNG size diff against the v1 folder). The json `version` fields stay `1` (int) so no type changes; this README is the revision record.

New raws used (`raw/l9_outdoor_board/v1_1/`):

| Raw | Rebuilt |
|---|---|
| `grass_swatch_v2.jpg` | `grass_top_a..d`, grass fringes + corners, `raised_rim_*`, overhang tops. Deeper meadow green with value variation, lifted a touch (gain 1.18, gamma 0.84, warm ×[1.12,1.0,0.86]) so it stays sunny next to sample_A. Shared identical border band kept. Tile mean ≈ (74,149,34). |
| `grass_lip_short.jpg` | `grass_overhang_left/_right`, `grass_overhang_corner_front/left/right`. ≈ 8 % vertical squash only (v1: ≈ 2.3x). |
| `cliff_strip_v2.jpg` | `cliff_left_h1-h3`, `cliff_right_h1-h3`. Grey fieldstones in brown earth, lit left face, right face shaded toward #5a6fa0. Clearly separate from wet earth now. |
| `water_swatch_v2.jpg` | `water_a..b`. Native turquoise with light grading only (sat 1.06, gain 0.96, gamma 1.04); no luminance recolour. |
| `wet_earth_v2.jpg` | `wet_earth_a..b`. Code puddles dropped. `a` = puddle-free crop, `b` = one painted puddle, centred. |
| `props_wall_log_1cell.jpg` | `ruined_wall_short`, `fallen_log_short` (native 1-cell pieces, no cut edge, no disc). |
| `props_1cell_nodisc.jpg` | `standing_stone`, `boulder_cluster`, `boulder_small` (no discs). The sheet's shrub was NOT used (leaves drifted all-purple); `lilac_shrub` is still the v1 cut with the disc fade. |
| `seal_topdown.jpg` | `seal_slab`: the true top-down square is mapped onto the exact 2:1 diamond in cell uv (same pipeline, grout seam and bevel as the sandstone slabs), tone matched to `sandstone_a` by channel medians. |

Other v1.1 changes:
- **Softer sandstone seams (~30 %)**: grout colour moved 30 % toward the slab tone, grout AO 0.35 → 0.245, edge bevel 30 % weaker (lit 0.10 → 0.07, shade 0.18 → 0.126), inset 3.5 % → 3.0 %. Paths read as paving; each slab stays countable.
- **Lip anchor fix**: in v1 the overhang edge sat 2 px above the documented canvas y 8. It now sits exactly on y 8 (canvas still 64x52).
- **Wet earth variants**: `b` (puddle) on ≈ 1/5-1/3 of mud cells by hash, never next to another `b` (left/up), never under a prop; 5 of 30 cells.
- **Decor policy**: raised cells are now CLEAN (all 15 cliff-top decor removed). 12 decor pieces on flat grass cells touching a path or water, never adjacent to each other, never on a prop cell, a 2-cell back cell or a cliff-foot cell.
- **2-cell wall/log placement**: only on old fence cells, and only where the back cell (x-1,y) is on the board, not water, same height and free of other props (see Replacement map).
- **Board edge**: mocks use the kit's earth edge (2-step `cliff_*_h2` skirt + grass overhang) as the board edge.

Built Sat 3 Oct 2026 (ET) on the box from Luca's painted raws in `raw/l9_outdoor_board/`. This is a drop-in for a NEW repo folder, **`art/pc/look/crosshaven_board/`**. The repo was read-only for this pass: nothing was committed, and shared `tiles/` and the map tags json are untouched.

Option A (Luca):
- There is no sand family and no mud family.
- **Grass** and **honey sandstone** are both looks on `ground` cells (1 MP). Sandstone is one slab per cell.
- The 30 `mud` cells are painted as **wet earth**.
- `water` cells are turquoise water.
- Map data (terrain, heights, prop cells) is unchanged.

Light follows the Crosshaven v7 kit rules:
- Key #fff0c8 from the top-left; shade #5a6fa0 on the SE faces.
- Contact AO only; no baked long or cast shadows.
- Neutral warm daylight, **not** pre-graded. Mauro picks the grade later.

Every image ships as `<id>@2x.png` (master) plus a half-size `<id>.png` (premultiplied LANCZOS). Both are straight alpha with black RGB under alpha 0.

## Files

| Path | What |
|---|---|
| `atlas_meta.json` | Kit index in the v7 `atlas_meta` convention (`tiles[]`, `props[]`, plus a custom `terrace[]`). Holds grid, anchors, lighting, palette and the replacement map. |
| `props.json` | Checker index (world package): id, size_2x, footprint_cells, anchor_px_2x. |
| `looks.json` | Per-cell look layer for **crosshaven_15**: `{x, y, terrain, height, look, variant, tile, overlays[], terrace[]}` for all 225 cells. Also `props[]` (old prop cell → new id), `decor[]`, the overlay rules and the per-cell draw order. |
| `tiles/` | 128x64 @2x / 64x32 @1x, all in `atlas_meta.tiles[]`. See below. |
| `terrace/` | Cliff faces and grass overhang for raised cells, in `atlas_meta.terrace[]`. |
| `props/` + `props/props.json` | Props in the Thunderwell `props.json` convention (props package). They are also listed in `atlas_meta.props[]`. |

### Tiles (`kind: floor`: exact opaque diamond with a 1 px AA rim)
- `grass_top_a..d`: v1.1 meadow green from `grass_swatch_v2.jpg` (deeper, with value variation), with a few yellow flowers.
  - Variants come from the swatch at different offsets, scales, flips and small rotations, plus tone and clump noise.
  - All four share an **identical border band**, so any variant can sit next to any other with no seam. Seamless was checked on random 5x5 patches.
  - A soft cell groove at the border keeps grass cells countable, as in sample_A.
- `sandstone_a..d`: the 4 painted slabs warped into the diamond, one slab per cell, with a grout seam and bevel (lit NW/NE, shaded SE/SW). v1.1: seam and bevel ~30 % softer.
  - a = plain, b = crack, c = chipped corner, d = cross-knot.
  - d is rare: `variant_weight` 0.12, and 4 of the 65 path cells use it.
- `wet_earth_a..b`: painted wet soil from `wet_earth_v2.jpg`. `a` has no puddle; `b` has one painted sky-reflecting puddle (about half the cell wide). No procedural puddles.
- `water_a..b`: native turquoise from `water_swatch_v2.jpg`, light grading only; `b` is a flipped crop.

### Overlays (`kind: decal`, 128x64, drawn on the receiving cell after its tile)
- Side names: `ne`=(x,y-1), `nw`=(x-1,y), `se`=(x+1,y), `sw`=(x,y+1).
- Corner names: `n`=(x-1,y-1), `e`=(x+1,y-1), `s`=(x+1,y+1), `w`=(x-1,y+1).

| Overlay | What it does |
|---|---|
| `grass_fringe_<ne,nw,se,sw>`, `grass_fringe_corner_<n,e,s,w>` | Grass blades spilling from a grass neighbour onto sandstone or wet earth, with soft contact AO. They sample the grass border band, so they continue the neighbour seamlessly. This is what makes the paths read as sunken. |
| `wet_earth_fringe_<4 sides>` | Wet earth spilling onto sandstone, with a damp stain. |
| `water_edge_<4 sides>`, `water_edge_corner_<4>` | Pale wet-sand/stone shore lip on the water cell, along the sides facing non-water. |
| `foot_ao_ne/nw` | Contact AO at the foot of a higher back neighbour. |
| `raised_rim_ne/nw` | Lit grass edge plus a thin dark silhouette on a raised cell whose back neighbour is lower. This helps the bumps read. |
| `seal_slab` | Replaces `floor_seal`. v1.1: a top-down square honey-sandstone seal mapped onto the exact diamond like the other slabs (same seam/bevel), so it reads as a carved paving slab. It is flat and drawn as the first overlay (no prop node, no height). |

### Terrace (raised cells; step = 20 px @2x / 10 px @1x)
- **Cliff faces** `cliff_left_h1/h2/h3` (SW face, lit) and `cliff_right_h1/h2/h3` (SE face, multiplied toward #5a6fa0).
  - Parallelograms 64 x (32 + 20·steps) @2x, from `cliff_strip_v2.jpg` (grey fieldstones in brown earth; top 46 rows cropped).
  - They darken with depth (absolute px, so stacked heights match), with AO under the lip and at the foot.
  - Each face is periodic along its edge, so collinear faces of neighbouring raised cells join.
  - Anchor: canvas top-left = LIFTED cell centre + (-64,0) for left / (0,0) for right @2x. Draw before the tile top.
  - Use h(n) for a drop of n steps to the (x,y+1) or (x+1,y) neighbour.
- **Overhang** `grass_overhang_left/_right` (64x52 @2x).
  - v1.1: cut from `grass_lip_short.jpg` (despilled, colour-matched to the grass tiles), ≈ 8 % vertical squash.
  - The lip covers 8 px of the top face and **hangs about 12 px** over the cliff top, with a soft AO band below. The edge sits exactly at canvas y 8 (v1 was 2 px high).
  - Anchor: canvas top-left = lifted centre + (-64,-8) / (0,-8) @2x. The cell's front edge runs through canvas y 8→40.
- **Corners** `grass_overhang_corner_front/left/right` (40x40 @2x).
  - The vertex sits at canvas (20,12): front = south vertex, left = west vertex, right = east vertex.
  - Draw after the strips. Front is used when both faces exist; left and right when that face exists.
- Raised cells always use grass tops. h3 is made for L1 even though crosshaven_15 only uses 0/1/2.

### Props (anchor = canvas bottom-centre on the anchor cell's south tip, as in tile.gd; lifted by height)
- Base and baked contact AO sit inside the cell's lower half. The AO is a soft cool ellipse, alpha ≤ 0.30.
- v1.1: standing_stone, boulder_cluster, boulder_small, ruined_wall_short and fallen_log_short come from the new no-disc sheets. lilac_shrub, stone_well, the 2c pieces and the decor are the v1 cuts (disc front faded so no hard ellipse rim shows).
- No white fringe: alpha is unmixed from white, eroded and despilled.
- Fighter ≈ 124 px @2x.

| id | canvas @2x | art height @2x | replaces | note |
|---|---|---|---|---|
| standing_stone | 128x224 | 170 (≈1.35x fighter) | ruins (x5) | v1.1 carved standing stone, no disc |
| boulder_cluster | 128x128 | 113 (≈0.9x) | rock_pillar (x3) | v1.1 mossy boulder cluster with a fern, no disc |
| lilac_shrub | 128x128 | 86 (≈0.7x) | hay (x6) | round lilac shrub (v1 cut, kept) |
| boulder_small | 128x128 | 67 (≈0.55x) | rubble (x7) | v1.1 the no-disc boulder cluster mirrored and scaled down |
| ruined_wall_short | 128x128 | 103 | fence (where a 2c does not fit) | v1.1 native wall stub with ivy and two loose blocks. **Long axis runs along the y diagonal (screen SW→NE), as painted**, unlike the 2c wall (+x) |
| fallen_log_short | 128x128 | 79 | fence (where a 2c does not fit) | v1.1 native hollow log section with fern and mushrooms, +x diagonal |
| stone_well | 128x224 | 133 (≈1.05x) | well (x1) | stone well |
| seal_slab | tile overlay | flat | floor_seal (x4) | see Overlays |
| ruined_wall_2c | 192x160 | 129 | fence at (3,12), (13,14) | footprint 2x1 (v1 cut) |
| fallen_log_2c | 192x160 | 103 | fence at (5,13) | footprint 2x1 (v1 cut) |
| lilac_bush, lilac_tuft, flower_tuft, clover_patch, pebbles_moss, fern | 128x128 | 51-89 | (decor) | small decor for grass by paths and water (v1.1: never on raised cells). Their lowest opaque row is 23 px above the tip, so the front half of the cell (fighter feet, cell highlight) stays clear. |

**2-cell props** (`ruined_wall_2c`, `fallen_log_2c`): `footprint_size` [2,1], laid along the +x diagonal (screen NW→SE, as painted).
- They are **anchored on the FRONT (south-most) cell** (x,y); the second cell is (x-1,y), back along the diagonal.
- The canvas is centred on the front cell's south tip. The art runs from x -95 to +31 @2x, over the axis between the two cell centres.
- Sort by the front cell. Both cells are covered visually; the sim is unaffected (paint_only).

## Replacement map (looks.json `props[]`; same cells, map data unchanged)
| Old kind | New id | Cells |
|---|---|---|
| ruins (tower) x5 | standing_stone | (0,0) (14,0) (2,10) (0,14) (4,14) |
| rock_pillar x3 | boulder_cluster | (14,4) (0,10) (10,12) |
| hay (coin stack) x6 | lilac_shrub | (6,0) (11,3) (0,6) (1,7) (6,13); (8,14) dropped, see below |
| rubble x7 | boulder_small | (9,1) (12,1, on wet earth) (3,3) (13,8) (12,10) (2,13) (14,14) |
| fence x7 | 2c where both cells fit, else short piece | `ruined_wall_2c` (3,12)+back (2,12, wet earth); `fallen_log_2c` (5,13)+back (4,13); `ruined_wall_2c` (13,14)+back (12,14); `ruined_wall_short` (1,0) (back cell (0,0) holds the standing stone); `fallen_log_short` (8,14) (water cell + stacked); (0,6) and (0,14) dropped, see below |
| floor_seal x4 | seal_slab (flat overlay) | (4,6) (8,6) (6,8) (10,8), all on the sandstone paths |
| well x1 | stone_well | (14,7) |

**Stacked cells** (two old props on one cell). Only one new prop is placed, so two props never overlap:
- (0,6) fence+hay → lilac_shrub only.
- (0,14) ruins+fence → standing_stone only.
- (8,14) hay+fence on a **water** cell → fallen_log_short only. A half-sunk log reads in water; a shrub does not.

The dropped entries are kept in looks.json with `layer: "dropped"` and a note. If you want both, the second could become a decor piece on a neighbour cell.

**Decor** (`looks.json decor[]`, optional, visual only):
- v1.1: **raised cells are clean**. 12 pieces total, all on flat grass touching a path or water: (7,13) clover, (14,9) lilac tuft, (10,1) fern, (11,9) flower tuft, (10,6) pebbles, (5,14) lilac bush, (12,6) clover, (10,13) lilac tuft, (4,1) fern, (13,4) flower tuft, (3,10) pebbles, (2,0) lilac bush.
- Rules: no two decor cells touch (incl. diagonals), none on prop cells, 2c back cells or cliff-foot cells.

## Looks design (looks.json)
| Look | Cells |
|---|---|
| grass | 112 (all 18 raised cells, plus every old-prop cell except the seals) |
| sandstone | 65 = **36.7 % of the 177 ground cells** |
| wet_earth | 30 (= mud) |
| water | 18 |

- The sandstone is laid as sunken paths, point-symmetric like the map.
- A ring of slabs runs round the central (7,7) bump and through the two inner seals.
- Arms run out to the four open areas and the board edges, with a slab plaza in the NW and SE quadrants.
- Paths cross the wet-earth patches, which stay wet earth.
- Prop cells stay grass so shrubs and stones sit on turf.
- Variants are hashed per cell with no equal variant on the left/up neighbour (wet earth: `b` ≈ 1 in 3 by hash, never next to another `b`, never under a prop; the rest `a`).
- Overlays are derived by the rules in `looks.json.rules` (the same code generated the mock).

## Loader needs (found in task 1; nothing implemented)
- The current loader (`board/koliseo_art.gd`) has **no @2x support**, and the stock `tiles/` base files are shared with 4 other maps. So the new look needs a **PC-only loader** that, for crosshaven_15:
  1. Reads `art/pc/look/crosshaven_board/looks.json`.
  2. Swaps each BoardTile texture for `tiles/<tile>@2x.png` drawn at scale 0.5, or the 1x file.
  3. Adds the overlay sprites (same placement and z as the tile) and the terrace sprites. Faces go before the top; overhang strips and corners go after the overlays. Height lift = h·10 at 1x / h·20 at 2x. Sort stays (x+y)·10 + h·8, fighters +4.
- **Do not touch shared `tiles/` or `crosshaven_15x15_tags.json`.**
- **Thunderwell pattern:** `tile.gd:175-177` hides the stock paint_only props when the Thunderwell theme is active, and the theme places its own art from its own `props.json`. Do the same here:
  - Hide the stock crosshaven prop nodes.
  - Place `looks.json props[]` (layer `prop`) and `decor[]` from `props/props.json`, with the anchor on the south tip and lifted by height.
  - `seal_slab` is a tile overlay, not a prop.
- Canopy tint: the jungle canopy tint on terrain (≈ 0.896, 0.949, 0.912) still applies through BoardTile. It was used in the 1280/1920 mocks.
- Board edge: per Stasium Bot's direction (pending Luca's answers) the mocks use the kit's earth edge, a **2-step earth skirt** on the front edges (x=14 column and y=14 row) using `cliff_*_h2`, plus grass overhang on grass edge cells. This gives the sample_A slab look. The jungle layer already draws its own earth skirt (z -40) and contact (z -24), and the loader should use one or the other.
- Props are paint_only and non-blocking, so a fighter can stand on a standing-stone cell and will draw over it (fighters +4), exactly like the old towers. If that reads badly, make the tall props blocking in data or fade them under units.

## Shadow convention
**Baked.** Each prop PNG carries its own soft contact AO ellipse:
- Cool #17171f-ish, alpha ≤ 0.30, inside the cell's lower half. Decor uses a smaller one at alpha 0.22.

Tiles carry contact AO only through the fringe, foot_ao and lip decals. No long or cast shadows anywhere, so a global day/night or weather tint can recolour freely. If code later adds its own contact ellipse (the Thunderwell style, multiply ~0.35), strip the baked one or halve it to avoid doubling.

## Gate (`python3 tools/check_assets.py`, run from /workspace/stasium-pc-look) — re-run for v1.1, same results as v1
- `ship/l9_outdoor_board --package world` → **Overall WARN, 52 checked: 52 PASS, 0 WARN, 0 FAIL**, exit 0. Report: `ship/check_report_world_l9_outdoor_board.md`.
  - The only WARN is **UNREFERENCED terrace/*.png (22 files)**. This is intentional: the terrace pieces are not 128x64 tiles and the world schema has no slot for them. They are listed in `atlas_meta.terrace[]` and `looks.json`.
- `ship/l9_outdoor_board/props --package props` → **Overall WARN, 0 FAIL, 0 unexpected**, exit 0. The report was moved to `ship/check_report_props_l9_outdoor_board.md` (the checker writes it into `ship/l9_outdoor_board/`, which the wiring PR copies, so it is moved out).
  - All 15 WARNs are "anchor y vs lowest opaque row". This is intentional and the same trade-off Thunderwell accepted. The props-package rule wants the art to touch the anchor, but this kit's rule (and the world gate, which PASSes) puts the base inside the cell's lower half, 10-12 px above the south tip (decor 23 px). Touching the tip would push the base into the front neighbours.

## Previews (`previews/l9_outdoor_board/`)
| File | What |
|---|---|
| `mock_l9_board_2x.png` | Full crosshaven_15 board at 2x on neutral grey, using the real cell math (centre ((x-y)·64, (x+y)·32 − h·20), sort (x+y)·10 + h·8). Includes the new looks, overlays, terraces, overhangs, replacement props and decor, plus a 2-step front skirt. |
| `mock_l9_1280.png`, `mock_l9_1920.png` | The board in the ship/crosshaven_jungle v4 backdrop: back_far + back_mid behind, front leaves on top with a cut-out over every cell. Camera matches the L7 capture (board ≈ 680 px wide at 1280, zoom 0.71 at 1x); canopy tint on, no leaf dapple on the board, no grade. |
| `before_after_1280.jpg` | `current_ref_l7_cast_outdoor_1280.png` vs the new board, labelled. |
| `kit_contact.png` | Every tile, overlay, terrace piece, assembled h1/h2/h3 blocks and props at 2x with a fighter bar. |
| `v1_vs_v11_closeup.png` | Same 2x crop of the board centre (600,450)-(1400,950) of `mock_l9_board_2x`: v1 left, v1.1 right. |
| `*_v1.*` | The v1 renders kept for comparison: `mock_l9_board_2x_v1.png`, `mock_l9_1280_v1.png`, `mock_l9_1920_v1.png`, `before_after_1280_v1.jpg`, `kit_contact_v1.png`. |

## Open questions (v1.1 applies Stasium Bot's direction; still pending Luca's answers)
1. Board edge: kit skirt (now used in the mocks) vs the jungle earth skirt. The loader should draw only one.
2. Stacked old prop cells (0,6), (0,14), (8,14): one prop each is still the rule.
3. Tall standing stones (170 px): blocking, or fade when a unit stands on or behind them?
4. 2c pieces overdraw a fighter standing on their back cell (paint_only, sorted by the front cell). OK, or fade/block?
5. Grade: everything is neutral. Mauro to choose.

## Still weak after v1.1 (art that would still help)
- **Wet-earth puddle** (`wet_earth_b`) is big, about half the cell wide, and reads as a grey slab at 1280. A swatch with smaller puddles (≈ 1/4 cell) would sit better.
- **Wall stub orientation**: `ruined_wall_short` runs along the y diagonal as painted, while both 2c pieces run along +x. It only appears at (1,0) now, but a +x stub would match.
- **lilac_shrub** is still the v1 cut with a faded disc (the new sheet's shrub was all-purple). A no-disc shrub with green leaves and lilac flowers would finish the prop set.
- **Board-edge skirt**: the fieldstone face repeats every cell along the long front edges and reads a little like a cobble plinth at 2x.
- **Sandstone grid**: seams are ~30 % softer as asked; at rest the slab grid is still visible (by design, each slab countable). If Mauro wants less, the next step is another ~30 % on grout darkness only.

Build scripts (box only): `/workspace/scratch/l9_build/` (v1 versions backed up in `/workspace/scratch/l9_build_v1_backup/`): `build_tiles.py`, `build_overlays.py`, `build_terrace.py`, `cut.py`, `build_props.py`, `build_seal.py`, `design_looks.py`, `make_meta.py`, `make_atlas.py`, `mock.py`, `contact.py`.
