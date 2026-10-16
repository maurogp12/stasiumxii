# EASTMARCH beach theme kit (STASIUM XII open-world outskirts)

Painted 2D isometric, PC-only. Built Sat 3 Oct 2026 (ET) on the box from Luca's raws in `raw/outskirts_themes/eastmarch/`
(`sand_swatch.jpg`, `surf_shore.jpg`, `coast_props.jpg`). Replaces the flat colour wash PR #241 (`cursor/crosshaven-outskirts-a156`) draws for
Eastmarch. Nothing was committed or pushed; `/workspace/stasium-repo` was only read. Suggested repo folder: `art/pc/look/outskirts/eastmarch/`.

## Look target (Crosshaven plate, applied Sat 3 Oct ~20:35 ET)
The kit follows the Crosshaven plate's palette: hay-gold grass, warm grey and cliff-white stone, clear blue sea with white breakers.
- Sea: every tile was regraded pixel-wise (the same colour function on every 2x master, so shared edges stay identical; 1x re-derived).
  Turquoise moves to clear blue, and darker water shifts further. `sea_deep` is now ~36,110,158; `sea_shallow` ~107,181,185, so the shallows
  stay lighter and a little greener next to the sand. Foam, surf and sand are untouched, and the foam stays bright white.
- Caves: rock graded toward warm grey / cliff white. The sandstone cave keeps 45 % of its orange and gets lifted; the grey cave is warmed and
  lifted. Grass and moss crowns are protected. The tide-pool water in `tidepool_rocks_a/b` gets the same sea grade.
- The grass side of the joins was already the repo's golden_plains pixels.
- Ungraded 2x originals are kept on the box: `/workspace/scratch/outskirts/east/orig_2x/`.

Format matches the Crosshaven world kit (`art/world/crosshaven/`, loader `scenes/world/crosshaven/crosshaven_art.gd`):
- Ground tiles are 2:1 iso diamonds, **128x64 @2x / 64x32 @1x**, bottom-centre on the cell's south tip
  (top-left = cell centre + (-32,-16) at 1x). Floors are an exact opaque diamond with a 1 px AA rim (same as the L9 kit; passes the gate's
  feathered-diamond check). Corner decals are transparent outside their wedge.
- Every id ships as `<id>@2x.png` (master) + `<id>.png` (exact half, premultiplied LANCZOS, straight alpha, black RGB under alpha 0).
- Props: bottom-centre = south tip of the south-most footprint cell (y-sort by that cell). 2-cell props use footprint (2,1): the anchor is
  the FRONT cell and the footprint runs back to (x-1,y).

## Files
| Path | What |
|---|---|
| `kit.json` | The flat index asked for: id, file (+1x), size, anchor, kind `tile/edge/corner/overlay/prop`, autotile family + side, footprint (props). |
| `atlas_meta.json` | Same pieces in the world-gate schema (`stasium.world_atlas` v2, like L9): tiles (`floor`/`decal`) and props. |
| `props.json` | World-gate checker index (id, size_2x, footprint_cells, anchor_px_2x). |
| `tiles/` | 86 ground pieces. |
| `props/` + `props/props.json` | 8 props (props-package index). |

## Autotile grammar
Crosshaven picker, unchanged: for a cell of family F, `g` = sides `nw, ne, se, sw` (that order) whose neighbour is in F's *against* set.
`g` empty -> interior by `h(x,y)`; otherwise `<edge_prefix><g joined by _>`; then for each diagonal corner whose two sides are not in `g`
but whose diagonal neighbour is in the against set, draw `<corner_prefix><c>` on top. Sides: nw=(x-1,y), ne=(x,y-1), se=(x+1,y), sw=(x,y+1);
corners n=(x-1,y-1), e=(x+1,y-1), s=(x+1,y+1), w=(x-1,y+1). **All 15 side combinations ship** (the brief's single sides
`_edge_{nw,ne,se,sw}` plus the 11 multi-side pieces the loader asks for when a cell touches grass on several sides).

| Family (cell terrain) | Interiors | Edge prefix | Corner prefix | Against (the "grass" it meets) |
|---|---|---|---|---|
| sand | `sand_a..d` | `sand_edge_` | `sand_corner_` | golden_plains |
| wet_sand (extra) | `wet_sand_a..b` | `wet_sand_edge_` | `wet_sand_corner_` | sand |
| sea_shallow | `sea_shallow_a..b` | `sand_surf_edge_` | `sand_surf_corner_` | sand, wet_sand |
| sea_deep | `sea_deep_a..b` | `sea_deep_edge_` | `sea_deep_corner_` | sea_shallow |

- **Surf set** (`sand_surf_*`) is drawn on **sea_shallow cells**; the listed sides touch sand. From the shared border inward it runs:
  dry sand (identical to the `sand_*` border band, so the sand cell next to it is seamless) -> wet-sand band -> lace foam -> white surf line
  -> sandy shallows -> sea_shallow. The foam therefore hugs the sand with the wet band behind it, as asked. The strip is painted from
  `surf_shore.jpg` (window x 470-890, made horizontally periodic, splash area left out so no splash repeats per cell).
- **Sand vs golden_plains**: grass edge pixels are the repo's `golden_plains_a@2x` pixels, so the shared border (all golden_plains variants share
  their outer ~4 px) is seamless. The join is a noisy contour 6-28 px into the sand cell, with blade-shaped grass tufts crossing into the sand,
  sand flecks inside the grass lip and a soft warm lip shade. Never a straight line.
- `wet_sand_*` and `sea_deep_*` (with their edge sets) are extras so wet flats and the deep shelf blend instead of butting.
- Rule for designers: put at least one sand cell between grass and sea (there is no grass-to-sea surf piece; the Crosshaven `water_bank_*`
  covers grass banks).

### Seams
Every interior shares one border band (uv-periodic base texture, ~5 px). The band is built from a decluttered copy of the swatch so no
pebble repeats on every cell, and its mean/contrast is matched to the interiors so cells don't read as framed pillows. Transition masks,
noise and the surf strip are all functions of the cell uv on a torus, so values agree across every shared edge. Check: random 14x10 patches
give mean colour step across cell borders 26.9 vs 26.6 inside cells (no seam signal).

## Ids
- Interiors: `sand_a`, `sand_b`, `sand_c`, `sand_d`, `wet_sand_a`, `wet_sand_b`, `sea_shallow_a`, `sea_deep_a`, `sea_shallow_b`, `sea_deep_b`
- Sand vs grass: `sand_edge_nw`, `sand_edge_ne`, `sand_edge_nw_ne`, `sand_edge_se`, `sand_edge_nw_se`, `sand_edge_ne_se`, `sand_edge_nw_ne_se`, `sand_edge_sw`, `sand_edge_nw_sw`, `sand_edge_ne_sw`, `sand_edge_nw_ne_sw`, `sand_edge_se_sw`, `sand_edge_nw_se_sw`, `sand_edge_ne_se_sw`, `sand_edge_nw_ne_se_sw`, `sand_corner_n`, `sand_corner_e`, `sand_corner_s`, `sand_corner_w`
- Surf: `sand_surf_edge_nw`, `sand_surf_edge_ne`, `sand_surf_edge_nw_ne`, `sand_surf_edge_se`, `sand_surf_edge_nw_se`, `sand_surf_edge_ne_se`, `sand_surf_edge_nw_ne_se`, `sand_surf_edge_sw`, `sand_surf_edge_nw_sw`, `sand_surf_edge_ne_sw`, `sand_surf_edge_nw_ne_sw`, `sand_surf_edge_se_sw`, `sand_surf_edge_nw_se_sw`, `sand_surf_edge_ne_se_sw`, `sand_surf_edge_nw_ne_se_sw`, `sand_surf_corner_n`, `sand_surf_corner_e`, `sand_surf_corner_s`, `sand_surf_corner_w`
- Wet sand vs sand: `wet_sand_edge_nw`, `wet_sand_edge_ne`, `wet_sand_edge_nw_ne`, `wet_sand_edge_se`, `wet_sand_edge_nw_se`, `wet_sand_edge_ne_se`, `wet_sand_edge_nw_ne_se`, `wet_sand_edge_sw`, `wet_sand_edge_nw_sw`, `wet_sand_edge_ne_sw`, `wet_sand_edge_nw_ne_sw`, `wet_sand_edge_se_sw`, `wet_sand_edge_nw_se_sw`, `wet_sand_edge_ne_se_sw`, `wet_sand_edge_nw_ne_se_sw`, `wet_sand_corner_n`, `wet_sand_corner_e`, `wet_sand_corner_s`, `wet_sand_corner_w`
- Deep vs shallow: `sea_deep_edge_nw`, `sea_deep_edge_ne`, `sea_deep_edge_nw_ne`, `sea_deep_edge_se`, `sea_deep_edge_nw_se`, `sea_deep_edge_ne_se`, `sea_deep_edge_nw_ne_se`, `sea_deep_edge_sw`, `sea_deep_edge_nw_sw`, `sea_deep_edge_ne_sw`, `sea_deep_edge_nw_ne_sw`, `sea_deep_edge_se_sw`, `sea_deep_edge_nw_se_sw`, `sea_deep_edge_ne_se_sw`, `sea_deep_edge_nw_ne_se_sw`, `sea_deep_corner_n`, `sea_deep_corner_e`, `sea_deep_corner_s`, `sea_deep_corner_w`

## Props (fighter = 124 px tall at 2x)
| id | canvas 2x | footprint | art height 2x | note |
|---|---|---|---|---|
| `cave_mouth_sandstone` | 192x160 | 2x1 | 160 | sandstone cave-mouth outcrop with a grass crown; 2-cell footprint (anchor cell + its nw neighbour (x-1,y)); blocks both cells |
| `cave_mouth_grey` | 192x160 | 2x1 | 160 | grey stone cave-mouth outcrop, mossy crown; 2-cell footprint like cave_mouth_sandstone |
| `tidepool_rocks_a` | 128x128 | 1x1 | 102 | barnacled rocks ringing a small tide pool, kelp; sits on sand or wet sand |
| `tidepool_rocks_b` | 128x128 | 1x1 | 94 | second tide-pool rock ring (5 rocks), kelp |
| `driftwood_long` | 128x128 | 1x1 | 91 | long bleached driftwood log, pebbles |
| `driftwood_fork` | 128x128 | 1x1 | 97 | forked driftwood branch, pebbles |
| `shell_heap` | 128x128 | 1x1 | 86 | heap of shells with a red starfish against a grey stone |
| `mooring_post` | 128x128 | 1x1 | 119 | rope-tied mooring post with a frozen splash (painted, static); place on the sand next to a surf cell |

Cutting: keyed off the sheet's real backdrop (sampled **~#07C70A**, not #00B140) by **hue distance** from that chroma plus saturation
(olive/kelp/moss stay opaque), then an edge-band matte from the *green excess* (g - max(r,b)) between the nearest solid colour and the
backdrop, colour decontamination, and a clamp of any green excess above the nearest solid colour's own. Measured green fringe on soft edge
pixels: 0.0-0.17 % (2x and 1x). The painted sand ground patch under each prop is kept as its base, with its rim faded (noisy, soft) so it
melts into sand; object parts are colour-protected from the fade.

## Gate (`python3 tools/check_assets.py ...`, run from /workspace/stasium-pc-look)
- `--package world` on this folder: **PASS, 94 files, 0 WARN, 0 FAIL** -> `ship/check_report_world_outskirts_eastmarch.md`.
- `--package props` on `props/`: **0 FAIL, 2 WARN** -> `ship/check_report_props_outskirts_eastmarch.md`.
  - WARN `cave_mouth_sandstone`, `cave_mouth_grey`: "anchor y 160 vs lowest opaque row 144". A 2-cell (2,1) footprint is a long thin
    parallelogram whose front is a single south tip; the caves' round painted base can't reach within 4 px of that tip while its lowest
    12 rows stay inside the footprint (the world gate's rule, which they pass with 0 px out). 15 px is inside the world gate's 24 px limit.
    The six 1-cell props sit 2-3 px above the tip and pass both gates clean.
- The gates have no chroma-fringe rule for world/props, so the fringe number above comes from my own check (`fringe_metrics` in the build).

## Previews
`previews/outskirts_themes/eastmarch/`: `contact_sheet.png` (every piece at 2x, labelled, cell/footprint diamonds, fighter bar),
`mock_eastmarch.png` (2x render with the 1x render below), plus `mock_eastmarch_2x.png` / `_1x.png`. The mock is a 14x10 patch:
golden_plains -> sand -> surf -> shallows -> deep, a wet-sand flat, both caves on their 2-cell footprints and the other props placed by hand.
There is no Eastmarch fog/haze piece in the brief, so the beach mock has no overlay. The mock now fills the frame with ground (no dark
field, no floating slab) and the captions sit in a grey bar, never on the ground.

## Weak spots (honest)
- A straight shoreline repeats the same surf piece every cell (one-cell period is inherent to per-cell PNGs); staircase coasts show the grid
  as a soft zigzag of foam.
- Water interiors still show a faint one-cell rhythm when you look for it (painted wave patches); it reads fine at 1x.
- The 2-cell caves are only 160 px tall (size class `wide` 192x160 caps them), about 1.3x a fighter.
- Props keep their painted sand patch; on grass they read as small sand islands. They're meant for sand cells.

Build scripts: `/workspace/scratch/outskirts/` (`okit.py`, `build_east_tiles.py`, `cut.py`, `props_lib.py`, `build_east_props.py`,
`write_kit.py`, `finish_east.py`, `engine.py`, `contact.py`, `mock_east.py`).
