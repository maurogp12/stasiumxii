# WESTWATCH blight (ash) theme kit (STASIUM XII open-world outskirts)

Painted 2D isometric, PC-only. Built Sat 3 Oct 2026 (ET) on the box from Luca's raws in `raw/outskirts_themes/westwatch/` (`blight_ground.jpg`, `cracked_earth.jpg`, `blight_props.jpg`). Replaces the flat colour wash PR #241 (`cursor/crosshaven-outskirts-a156`) draws for Westwatch. Nothing was committed or pushed. Suggested repo folder: `art/pc/look/outskirts/westwatch/`.

## Look target (Crosshaven plate, applied Sat 3 Oct ~20:35 ET)
Westwatch is the **ash** material in the same daylight gouache as the plate, not a purple biome. The raw's violet-grey (~146,135,153) is
graded to a warm ash grey with only a slight violet cast: blight ~157,152,153, cracked clay ~172,166,165. Prop violets were pulled to warm
ash. The haze is light warm grey (0.90 to 0.82) at 23-27 % alpha, normal blend, so there's no glow and no neon. The grass side of every
join is the repo's golden_plains pixels.

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
| blight | `blight_a..d` | `blight_edge_` | `blight_corner_` | golden_plains |
| cracked | `cracked_a..d` | `cracked_edge_` | `cracked_corner_` | blight |

- **Blight vs golden_plains (withering join)**: past the shared border (exact golden_plains pixels), the grass in the blight cell dulls
  and yellows to straw, then dies to a warm ash grey right at a noisy contour about 16-30 px in. Dead tufts cross into the ash and ash
  flecks sit in the grass lip. Never a straight line.
- **Cracked vs blight**: ash drifts over the clay plates with a noisy contour, ash clumps in the cracks, clay flecks in the ash and a darker
  lip. Rule: keep an ash ring between grass and cracked clay (no grass-to-clay piece).

## Ids

- Interiors / flat overlays: `blight_a`, `blight_b`, `blight_c`, `blight_d`, `cracked_a`, `cracked_b`, `cracked_c`, `cracked_d`
- blight vs golden_plains: `blight_edge_nw`, `blight_edge_ne`, `blight_edge_nw_ne`, `blight_edge_se`, `blight_edge_nw_se`, `blight_edge_ne_se`, `blight_edge_nw_ne_se`, `blight_edge_sw`, `blight_edge_nw_sw`, `blight_edge_ne_sw`, `blight_edge_nw_ne_sw`, `blight_edge_se_sw`, `blight_edge_nw_se_sw`, `blight_edge_ne_se_sw`, `blight_edge_nw_ne_se_sw`, `blight_corner_n`, `blight_corner_e`, `blight_corner_s`, `blight_corner_w`
- cracked vs blight: `cracked_edge_nw`, `cracked_edge_ne`, `cracked_edge_nw_ne`, `cracked_edge_se`, `cracked_edge_nw_se`, `cracked_edge_ne_se`, `cracked_edge_nw_ne_se`, `cracked_edge_sw`, `cracked_edge_nw_sw`, `cracked_edge_ne_sw`, `cracked_edge_nw_ne_sw`, `cracked_edge_se_sw`, `cracked_edge_nw_se_sw`, `cracked_edge_ne_se_sw`, `cracked_edge_nw_ne_se_sw`, `cracked_corner_n`, `cracked_corner_e`, `cracked_corner_s`, `cracked_corner_w`

`blight_*` comes from `blight_ground.jpg` x < 630 only: the swatch repeats every 638 px horizontally. `cracked_*` comes from
`cracked_earth.jpg`, scaled so about 2-3 plates fit across a cell (with one plate per cell, the cells read as a quilt).

## Props (fighter = 124 px tall at 2x)

| id | canvas 2x | footprint | art height 2x | kind | sway | note |
|---|---|---|---|---|---|---|
| `dead_tree_tall` | 224x256 | 1x1 | 182 | tree | yes | tall dead twisted tree on an ash patch (tree_broad class 112x128@1x); sway mask moves only the upper branches |
| `dead_tree_mid` | 128x224 | 1x1 | 149 | tree | yes | mid dead twisted tree (tree class 64x112@1x); sway mask |
| `dead_tree_lean` | 224x256 | 1x1 | 134 | tree | yes | leaning dead tree (kept inside the props-gate ±72 px span, so it is smaller than the raw suggests); sway mask |
| `hollow_stump` | 128x128 | 1x1 | 101 | decor_block | - | hollow broken stump, ash and roots |
| `thorn_brush_a` | 128x128 | 1x1 | 119 | plant | - | dense thorn bramble mound |
| `thorn_brush_b` | 128x128 | 1x1 | 125 | plant | - | wide low thorn bramble |
| `thorn_brush_c` | 128x128 | 1x1 | 105 | plant | - | small looping thorn bramble |
| `withered_reeds` | 128x128 | 1x1 | 113 | plant | yes | withered pale reeds on an ash tuft; sway mask (dry, stiff: play it slow) |
| `skull_stone` | 128x128 | 1x1 | 74 | decor | - | horned beast skull against a grey stone |
| `broken_fence_cloth` | 128x128 | 1x1 | 126 | decor_block | - | broken picket fence run with a tattered cloth frozen mid-flap (static, the broken-hour detail; no sway) |

## Overlays (`overlays/`, screen-space, draw above props)

| id | size 2x | alpha peak | tileable | note |
|---|---|---|---|---|
| `haze_a` | 640x160 | 0.271 | False | wide soft ash haze band, ~5 cells wide; draw above props, normal blend (no add/screen = no glow) |
| `haze_b` | 640x160 | 0.231 | False | wide soft ash haze band, ~5 cells wide; draw above props, normal blend (no add/screen = no glow) |
| `haze_tile_swatch` | 512x512 | 0.2 | True | tileable low-alpha ash haze sheet (wraps on both axes) for a slow scrolling layer |

## Gate

- `python3 tools/check_assets.py ship/outskirts_themes/westwatch --package world`: **PASS**, 59 files, 0 WARN, 0 FAIL
  (46 tiles, 10 props, 3 overlays via anim_meta). Report: `ship/check_report_world_outskirts_westwatch.md`.
- `python3 tools/check_assets.py ship/outskirts_themes/westwatch/props --package props`: **PASS**, 0 WARN, 0 FAIL. Report:
  `ship/check_report_props_outskirts_westwatch.md` (moved out of the ship folder).
- Chroma: the backdrop is ~#09E20B (not #00B140). Same hue-distance key + edge matte + despill as the other kits. Green on soft edge
  pixels is 0.0-0.7 % for every prop.

## Previews

`previews/outskirts_themes/westwatch/`: `contact_sheet.png` (all pieces at 2x on neutral grey, labelled, cell grid, fighter bar), `mock_westwatch.png` (14x10 patch, 2x render with the 1x render below; ground fills the frame, captions sit in a grey bar, never on the ground, and there is no dark field or floating slab), plus `mock_westwatch_2x.png` / `mock_westwatch_1x.png`.

## Weak spots (honest)

- The ash interiors still show a faint per-cell lattice at full-screen zoom (the raw's big mottles against a one-cell period). The
  contrast is turned down to hide it, so the ash is fairly flat. Props and haze break it up in play.
- The cracked clay has some crack lines that line up along cell rows.
- The withering band is narrow (it has to fit inside the blight cell). The neighbouring grass cell stays fully hay-gold, so from far away
  it reads as a straw rim. Dead-grass decals on the grass side would sell the die-off better.
- Trees are capped by the one-cell base rule: dead_tree_tall is 182 px (~1.5 fighters), dead_tree_mid 149 px, and dead_tree_lean 134 px
  (it also has to fit the props gate's ±72 px span). Bigger trees would need a 2x2 landmark footprint.
- The haze is light on purpose (look target), so over pale ash it's subtle.

## Raws

- `blight_ground.jpg`: obvious horizontal repeat at 638 px. It's also quite violet (mean 146,135,153). A repaint in warm ash grey with a
  faint violet and smaller mottles would remove most of the grade and the lattice.
- `blight_props.jpg`: the wood, thorns and ground discs are painted violet. I pulled them to warm ash in the cut (hue-selective, 40 % of
  the violet saturation kept). A repaint in ash-grey wood would hold up better. The tree ground discs are wide, which caps the tree size
  on one cell; tighter root spreads would let the trees scale up.
- `cracked_earth.jpg`: fine. The plates are large for a 64x32 cell.

Build scripts (box only): `/workspace/scratch/outskirts/` (okit.py, cut.py, props_lib.py, overlay_lib.py, write_kit.py, engine.py, contact.py, build_*_westw*.py). Nothing was committed or pushed.
