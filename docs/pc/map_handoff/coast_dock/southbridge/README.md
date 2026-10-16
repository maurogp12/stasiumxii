# SOUTHBRIDGE swamp theme kit (STASIUM XII open-world outskirts)

Painted 2D isometric, PC-only. Built Sat 3 Oct 2026 (ET) on the box from Luca's raws in `raw/outskirts_themes/southbridge/` (`swamp_pool.jpg`, `mud_swatch.jpg`, `swamp_props.jpg`). Replaces the flat colour wash PR #241 (`cursor/crosshaven-outskirts-a156`) draws for Southbridge. Nothing was committed or pushed. Suggested repo folder: `art/pc/look/outskirts/southbridge/`.

## Look target (Crosshaven plate, applied Sat 3 Oct ~20:35 ET)
Southbridge is the **fen** material in the same storybook-gouache daylight as the plate, not a second style. Mud was regraded to a warmer
olive-brown (~140,122,71) and water to a warmer green (~107,128,87); both stay mid-value so they sit next to the hay-gold golden_plains.
The fog was lightened (warm white 0.97 to 0.89, 25-38 % alpha), so it reads as morning mist, not night fog. The grass side of every join is
the repo's golden_plains pixels.

Format matches the Crosshaven world kit (`art/world/crosshaven/`, loader `scenes/world/crosshaven/crosshaven_art.gd`):
- Ground tiles are 2:1 iso diamonds, **128x64 @2x / 64x32 @1x**, bottom-centre on the cell's south tip. Floors are an exact opaque
  diamond with a 1 px AA rim (passes the gate's feathered-diamond check); corner decals and flat overlays are transparent outside their wedge.
- Every id ships as `<id>@2x.png` (master) + `<id>.png` (exact half, premultiplied LANCZOS, straight alpha). NOTE: the parallel Northgate
  kit uses the Crosshaven `tiles/_2x/<id>.png` layout; this kit keeps the brief's `<id>@2x.png` naming, so a loader needs one path rule per kit
  (or rename on import).
- Props: bottom-centre = south tip of the footprint cell; y-sort by the anchor.
- Autotile: Crosshaven picker unchanged. `g` = sides `nw, ne, se, sw` (that order) whose neighbour is in the family's *against* set;
  `g` empty -> interior by `h(x,y)`, else `<edge_prefix><g joined by _>`, then `<corner_prefix><c>` decals for diagonal corners whose two
  sides are not in `g`. Sides nw=(x-1,y), ne=(x,y-1), se=(x+1,y), sw=(x,y+1); corners n=(x-1,y-1), e=(x+1,y-1), s=(x+1,y+1), w=(x-1,y+1).
  **All 15 side combinations ship** (the brief's single sides plus the 11 multi-side pieces the loader asks for).
- Seams: every interior shares one uv-periodic border band; transition masks and noise are functions of the cell uv on a torus, so values
  agree across every shared edge. Grass pixels in the joins are the repo's own `golden_plains_a@2x` pixels (all golden_plains variants share
  their outer ~4 px), so grass cells next to a join stay seamless.

## Files
| Path | What |
|---|---|
| `kit.json` | Flat index: id, file (+1x), size, anchor, kind `tile/edge/corner/overlay/prop`, autotile family + side, footprint (props). |
| `atlas_meta.json` | Same pieces in the world-gate schema (`stasium.world_atlas` v2, like L9). |
| `props.json` | World-gate checker index. |
| `animated/anim_meta.json` | Lists the fog/haze overlays as 1-frame scroll layers (so the world gate checks them). |
| `animated/sway_masks/` (+`_2x/`) | L sway masks for reeds/trees (0 at the base, rising with height). |
| `tiles/`, `props/` (+`props/props.json`), `overlays/` | The art. |

## Autotile families

| Family (cell terrain) | Interiors | Edge prefix | Corner prefix | Against |
|---|---|---|---|---|
| mud | `mud_a..d` | `mud_edge_` | `mud_corner_` | golden_plains |
| swamp_water | `swamp_water_a..d` | `swamp_bank_edge_` | `swamp_bank_corner_` | mud |

- **Mud vs golden_plains**: noisy contour ~10-24 px into the mud cell, blade-shaped damp-grass tufts crossing into the mud, mud flecks in the
  grass lip, grass darkening to a damp olive near the join, soft dark wet lip. Never a straight line.
- **Swamp bank** (`swamp_bank_*`) is drawn **on the water cell**; the listed sides touch mud. From the shared border: mud (identical to the
  `mud_*` band, seamless) -> root-laced bank lip (stakes and roots from `swamp_pool.jpg`, colour-matched to the mud) -> hanging roots ->
  duckweed fringe -> murky water. The bank hugs the land side. Rule: keep a mud ring between grass and a pool (no grass-to-pool piece).
- `lily_pads` is a flat 128x64 decal for **interior** swamp_water cells (draw after the floor, before props). It's listed in the brief under
  props but it's a flat water overlay, so it lives in `tiles/` as a decal and kit.json gives it kind `overlay`.
- Water value: the raw's open water is near-black (mean RGB ~60,69,36). It's lifted to a mid-value, warm olive-green (~107,128,87) with soft
  sky sheen streaks so it reads as water.

## Ids

- Interiors / flat overlays: `mud_a`, `mud_b`, `mud_c`, `mud_d`, `swamp_water_a`, `swamp_water_b`, `swamp_water_c`, `swamp_water_d`, `lily_pads`
- mud vs golden_plains: `mud_edge_nw`, `mud_edge_ne`, `mud_edge_nw_ne`, `mud_edge_se`, `mud_edge_nw_se`, `mud_edge_ne_se`, `mud_edge_nw_ne_se`, `mud_edge_sw`, `mud_edge_nw_sw`, `mud_edge_ne_sw`, `mud_edge_nw_ne_sw`, `mud_edge_se_sw`, `mud_edge_nw_se_sw`, `mud_edge_ne_se_sw`, `mud_edge_nw_ne_se_sw`, `mud_corner_n`, `mud_corner_e`, `mud_corner_s`, `mud_corner_w`
- swamp_water vs mud: `swamp_bank_edge_nw`, `swamp_bank_edge_ne`, `swamp_bank_edge_nw_ne`, `swamp_bank_edge_se`, `swamp_bank_edge_nw_se`, `swamp_bank_edge_ne_se`, `swamp_bank_edge_nw_ne_se`, `swamp_bank_edge_sw`, `swamp_bank_edge_nw_sw`, `swamp_bank_edge_ne_sw`, `swamp_bank_edge_nw_ne_sw`, `swamp_bank_edge_se_sw`, `swamp_bank_edge_nw_se_sw`, `swamp_bank_edge_ne_se_sw`, `swamp_bank_edge_nw_ne_se_sw`, `swamp_bank_corner_n`, `swamp_bank_corner_e`, `swamp_bank_corner_s`, `swamp_bank_corner_w`

Mud comes from `mud_swatch.jpg` x < 640 only: the swatch repeats itself every 606 px horizontally, so the right half is a copy.
Water comes from the clean centre of `swamp_pool.jpg` (x 460-760, y 330-590), clear of the three painted lily pads.

## Props (fighter = 124 px tall at 2x)

| id | canvas 2x | footprint | art height 2x | kind | sway | note |
|---|---|---|---|---|---|---|
| `reeds_a` | 128x128 | 1x1 | 113 | plant | yes | cattail clump on a moss tuft; place on mud or bank cells; sway mask |
| `reeds_b` | 128x128 | 1x1 | 116 | plant | yes | taller, denser cattail clump; sway mask |
| `reeds_c` | 128x128 | 1x1 | 102 | plant | yes | small cattail clump; sway mask |
| `dead_trunk_tall` | 128x224 | 1x1 | 188 | tree | yes | tall dead swamp trunk with hanging moss (tree class 64x112@1x); sway mask moves only the moss/branch tips |
| `dead_stump` | 128x128 | 1x1 | 126 | decor_block | - | broken dead trunk stump with moss beards |
| `rotten_log` | 128x128 | 1x1 | 71 | decor_block | - | rotten mossy log with bracket mushrooms (diagonal along the iso axis) |
| `stepping_stones` | 128x128 | 1x1 | 65 | decor_flat | - | two flat mossy stepping stones; walkable dressing, place on mud or shallow bank |
| `marker_lantern_post` | 128x224 | 1x1 | 177 | tall | - | crossbar marker post with an UNLIT hanging lantern (no emit mask) |
| `root_tangle` | 128x128 | 1x1 | 82 | decor_block | - | upturned tangle of dead roots with moss |

## Overlays (`overlays/`, screen-space, draw above props)

| id | size 2x | alpha peak | tileable | note |
|---|---|---|---|---|
| `fog_low_a` | 512x192 | 0.341 | False | low swamp fog wisp, ~4 cells wide; draw above props, anchor = image centre on a cell centre; drift slowly along x |
| `fog_low_b` | 512x192 | 0.302 | False | low swamp fog wisp, ~4 cells wide; draw above props, anchor = image centre on a cell centre; drift slowly along x |
| `fog_low_c` | 512x192 | 0.38 | False | low swamp fog wisp, ~4 cells wide; draw above props, anchor = image centre on a cell centre; drift slowly along x |
| `fog_tile_swatch` | 512x512 | 0.224 | True | tileable low-alpha fog sheet (wraps on both axes) for a slow scrolling screen-space layer |

## Gate

- `python3 tools/check_assets.py ship/outskirts_themes/southbridge --package world`: **PASS**, 60 files, 0 WARN, 0 FAIL
  (47 tiles, 9 props, 4 overlays via anim_meta). Report: `ship/check_report_world_outskirts_southbridge.md`.
- `python3 tools/check_assets.py ship/outskirts_themes/southbridge/props --package props`: **PASS**, 0 WARN, 0 FAIL. Report:
  `ship/check_report_props_outskirts_southbridge.md` (moved out of the ship folder).
- Chroma: the sheet's backdrop is ~#0FF70D (not #00B140). Keyed by hue distance from that chroma plus an edge-band green-excess matte and
  despill, so olive reeds and moss stay opaque. Green on soft edge pixels is 0.06-1.1 % for all props except
  `dead_stump` (3.5 %) and `dead_trunk_tall` (6.1 %). On those two, the flagged pixels are the painted pale-green hanging moss (checked over
  magenta), not backdrop spill.

## Previews

`previews/outskirts_themes/southbridge/`: `contact_sheet.png` (all pieces at 2x on neutral grey, labelled, cell grid, fighter bar), `mock_southbridge.png` (14x10 patch, 2x render with the 1x render below; ground fills the frame, captions sit in a grey bar, never on the ground, and there is no dark field or floating slab), plus `mock_southbridge_2x.png` / `mock_southbridge_1x.png`.

## Weak spots (honest)

- The mud/grass contour still shows a soft per-cell scallop rhythm along long straight grass runs.
- At the pool's convex corners the bank strip smears radially (the root texture is laid out along the cell edge). It reads as roots
  but is less crisp than along straight banks.
- The mud interiors are fairly even (the swatch is low-contrast). Large mud fields want props or puddle decals to break them up.
- `root_tangle` had to shrink to 82 px tall to keep its splayed roots inside the footprint with a ≤4 px gap.
- The fog wisps are procedural (layered periodic noise + tapered curved brush strokes, dithered alpha, 77-97 alpha levels, no banding).
  They're soft and flat on purpose; there's no painted light direction in them.

## Raws

- `swamp_props.jpg`: the lantern glass is painted warm amber, so it reads half-lit. I desaturated and darkened the glass in the cut
  (`marker_lantern_post` is unlit now). A repaint should paint the glass dusty grey-green with no warm core.
- `mud_swatch.jpg`: obvious horizontal repeat at 606 px. A repaint should be one continuous 1280-wide painting with a little more value
  variation (puddles, darker wet patches).
- `swamp_pool.jpg`: the open water is near-black. A repaint at mid value would save the grade; the reflection streaks under the stakes
  (rows ~300-360) are left out of the bank strip.

Build scripts (box only): `/workspace/scratch/outskirts/` (okit.py, cut.py, props_lib.py, overlay_lib.py, write_kit.py, engine.py, contact.py, build_*_south*.py). Nothing was committed or pushed.
