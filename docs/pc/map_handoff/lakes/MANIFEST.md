# Lakes v1 kit, v2 update, Oct 12 (Proposed, art only, not committed)

Two Proposed fishing lakes for STASIUM XII PC: Rowanvale farm lake (rowanvale_farmland_3) and Windmere frozen lake (windmere_outer_3, x=20-29, y=2-7, ice holes at (22,3), (25,4), (27,6)).
Conventions: floor tiles are 64x32 diamonds at 1x with a 128x64 master in `_2x/`, pivot bottom-centre (the cell's south tip). Props use a bottom-centre pivot, and nothing has a painted cast shadow. Painted fantasy, no emissive or neon.

## What changed in v2
- **Windmere tiles were repainted to match the crisp mock**: all 4 ice tiles and all 12 shore_snow_ice tiles. The ice is hard-edged grey-blue with less frost haze, and the cracks are crisp with a dark shadow line. The bank is now a hard edge: a dark ice lip, then a bright ice rim line, then a packed-snow band with snow-capped stones painted in. There is no soft blend.
- **Windmere edge/outer/inner tiles also got a geometry fix.** In v1 the bank line sat off the diamond, so the edge pieces were nearly all snow. Now the ice really fills its side, and the hard bank runs exactly on the tile midline with larger snow-capped stones. The ice has crisp 2 px white cracks with a dark shadow line (2 on plain tiles, 6 to 10 on cracked tiles).
- **Windmere ice holes are bigger.** `ice_hole` went from 34x19 to 77x44 at 1x (about 1.2 cells wide), with a thick white ice collar and chunks. `ice_hole_small` went from 22x13 to 48x27.
- **`mock_windmere_lake_1280.png` is now built from the kit tiles** (cell map in `windmere/cellmap.json`) instead of a free-painted field. Ironjaw is drawn on top, so he's visible and no longer painted over. The SE trees are restored on top as before.
- **Rowanvale lake reshaped** into a winding pond that runs through the grass between the plots (about 30 cells touched, x=20..26, y=3..8). Every existing farm plot stays visible, Ironjaw stands dry on a grass point, and the lake fish ring and jump sit at (21.8,6.5) and (24.1,6.1). Details are in WIRING_NOTES. `rowanvale_plots_check_1280.png` overlays the plots in magenta as proof: 0 plot pixels are covered by water.
- The v1 files are kept in `_archive_v1/`, and side-by-sides are in `windmere_v1_vs_v2.png` and `rowanvale_v1_vs_v2.png`.

Generators:
- `src/build.py`: v1 kit. **Do not re-run it**, because it would overwrite the v2 Windmere tiles.
- `src/windmere_v2.py`: Windmere tiles and holes.
- `src/windmere_mock_v2.py`
- `src/rowanvale_mock_v2.py`
- `src/clean.py` and `src/common.py`: helpers.

Mocks are at true capture scale (1 cell = 46x23 px). The Windmere floor is composed at _2x and scaled once, so it has no tile seams.

| file (1x; 2x in `_2x/`) | 1x | 2x | pivot | use |
|---|---|---|---|---|
| rowanvale/tiles/lake_water_shallow_a.png | 64x32 | 128x64 | (32,32) 1x | shallow lake water, inner ring |
| rowanvale/tiles/lake_water_shallow_b.png | 64x32 | 128x64 | (32,32) 1x | shallow lake water, inner ring |
| rowanvale/tiles/lake_water_mid_a.png | 64x32 | 128x64 | (32,32) 1x | mid lake water |
| rowanvale/tiles/lake_water_mid_b.png | 64x32 | 128x64 | (32,32) 1x | mid lake water |
| rowanvale/tiles/lake_water_deep_a.png | 64x32 | 128x64 | (32,32) 1x | deep lake water, centre |
| rowanvale/tiles/lake_water_deep_b.png | 64x32 | 128x64 | (32,32) 1x | deep lake water, centre |
| rowanvale/tiles/shore_grass_water_edge_ne.png | 64x32 | 128x64 | (32,32) 1x | shore_grass_water: water/ice on the NE side of the cell |
| rowanvale/tiles/shore_grass_water_edge_sw.png | 64x32 | 128x64 | (32,32) 1x | shore_grass_water: water/ice on the SW side of the cell |
| rowanvale/tiles/shore_grass_water_edge_nw.png | 64x32 | 128x64 | (32,32) 1x | shore_grass_water: water/ice on the NW side of the cell |
| rowanvale/tiles/shore_grass_water_edge_se.png | 64x32 | 128x64 | (32,32) 1x | shore_grass_water: water/ice on the SE side of the cell |
| rowanvale/tiles/shore_grass_water_outer_n.png | 64x32 | 128x64 | (32,32) 1x | shore_grass_water: outer corner, water on NE+NW |
| rowanvale/tiles/shore_grass_water_inner_ne_nw.png | 64x32 | 128x64 | (32,32) 1x | shore_grass_water: inner corner (land only in the NE/NW wedge opposite), concave bank |
| rowanvale/tiles/shore_grass_water_outer_e.png | 64x32 | 128x64 | (32,32) 1x | shore_grass_water: outer corner, water on NE+SE |
| rowanvale/tiles/shore_grass_water_inner_ne_se.png | 64x32 | 128x64 | (32,32) 1x | shore_grass_water: inner corner (land only in the NE/SE wedge opposite), concave bank |
| rowanvale/tiles/shore_grass_water_outer_s.png | 64x32 | 128x64 | (32,32) 1x | shore_grass_water: outer corner, water on SW+SE |
| rowanvale/tiles/shore_grass_water_inner_sw_se.png | 64x32 | 128x64 | (32,32) 1x | shore_grass_water: inner corner (land only in the SW/SE wedge opposite), concave bank |
| rowanvale/tiles/shore_grass_water_outer_w.png | 64x32 | 128x64 | (32,32) 1x | shore_grass_water: outer corner, water on SW+NW |
| rowanvale/tiles/shore_grass_water_inner_sw_nw.png | 64x32 | 128x64 | (32,32) 1x | shore_grass_water: inner corner (land only in the SW/NW wedge opposite), concave bank |
| windmere/tiles/ice_plain_a.png | 64x32 | 128x64 | (32,32) 1x | plain ice (crisp v2) |
| windmere/tiles/ice_plain_b.png | 64x32 | 128x64 | (32,32) 1x | plain ice, darker deep (crisp v2) |
| windmere/tiles/ice_cracked_a.png | 64x32 | 128x64 | (32,32) 1x | cracked ice (crisp v2) |
| windmere/tiles/ice_cracked_b.png | 64x32 | 128x64 | (32,32) 1x | cracked ice, heavy (crisp v2) |
| windmere/tiles/shore_snow_ice_edge_ne.png | 64x32 | 128x64 | (32,32) 1x | shore_snow_ice: ice on the NE side, hard bank (crisp v2) |
| windmere/tiles/shore_snow_ice_edge_sw.png | 64x32 | 128x64 | (32,32) 1x | shore_snow_ice: ice on the SW side, hard bank (crisp v2) |
| windmere/tiles/shore_snow_ice_edge_nw.png | 64x32 | 128x64 | (32,32) 1x | shore_snow_ice: ice on the NW side, hard bank (crisp v2) |
| windmere/tiles/shore_snow_ice_edge_se.png | 64x32 | 128x64 | (32,32) 1x | shore_snow_ice: ice on the SE side, hard bank (crisp v2) |
| windmere/tiles/shore_snow_ice_outer_n.png | 64x32 | 128x64 | (32,32) 1x | shore_snow_ice: outer corner, ice on NE+NW, hard bank (crisp v2) |
| windmere/tiles/shore_snow_ice_inner_ne_nw.png | 64x32 | 128x64 | (32,32) 1x | shore_snow_ice: inner corner (ice only in the NE/NW wedge), hard bank (crisp v2) |
| windmere/tiles/shore_snow_ice_outer_e.png | 64x32 | 128x64 | (32,32) 1x | shore_snow_ice: outer corner, ice on NE+SE, hard bank (crisp v2) |
| windmere/tiles/shore_snow_ice_inner_ne_se.png | 64x32 | 128x64 | (32,32) 1x | shore_snow_ice: inner corner (ice only in the NE/SE wedge), hard bank (crisp v2) |
| windmere/tiles/shore_snow_ice_outer_s.png | 64x32 | 128x64 | (32,32) 1x | shore_snow_ice: outer corner, ice on SW+SE, hard bank (crisp v2) |
| windmere/tiles/shore_snow_ice_inner_sw_se.png | 64x32 | 128x64 | (32,32) 1x | shore_snow_ice: inner corner (ice only in the SW/SE wedge), hard bank (crisp v2) |
| windmere/tiles/shore_snow_ice_outer_w.png | 64x32 | 128x64 | (32,32) 1x | shore_snow_ice: outer corner, ice on SW+NW, hard bank (crisp v2) |
| windmere/tiles/shore_snow_ice_inner_sw_nw.png | 64x32 | 128x64 | (32,32) 1x | shore_snow_ice: inner corner (ice only in the SW/NW wedge), hard bank (crisp v2) |
| rowanvale/props/reeds_a.png | 28x38 | 56x76 | (13,38) 1x | reed clump at the bank (place on shore_edge cells) |
| rowanvale/props/lily_pads_a.png | 36x22 | 72x44 | (18,21) 1x | lily pads, floor-layer decal on shallow water |
| rowanvale/props/lily_pads_b.png | 30x21 | 60x42 | (15,20) 1x | lily pads decal |
| rowanvale/props/lily_pads_c.png | 37x22 | 74x44 | (18,22) 1x | lily pads decal |
| rowanvale/props/rowboat.png | 75x60 | 150x120 | (37,59) 1x | moored rowboat on water next to jetty |
| rowanvale/props/fishing_stake.png | 32x42 | 64x84 | (16,42) 1x | fishing-spot marker post at bank |
| rowanvale/props/lake_spot_ring.png | 60x43 | 120x86 | (30,43) 1x | lake fishing-spot ripple decal (under lake_jump anim) |
| rowanvale/props/reeds_b.png | 21x29 | 42x58 | (10,29) 1x | smaller mirrored reed clump |
| rowanvale/props/jetty.png | 114x65 | 228x130 | (56,65) 1x | small wooden jetty, 3 cells long running +x (SE); anchor = south tip of its last cell |
| windmere/props/ice_hole.png | 77x44 | 154x88 | (38,43) 1x | ice-fishing hole decal v2 (bigger, about 1.2 cells wide), floor layer; anchor bottom-centre at cell centre y+12 (1x) |
| windmere/props/ice_hole_small.png | 48x27 | 96x54 | (23,27) 1x | small ice hole variant v2 |
| windmere/props/sled.png | 58x33 | 116x66 | (28,32) 1x | wooden sled with sack + logs (1 cell) |
| windmere/props/fishing_hut.png | 111x98 | 222x196 | (55,98) 1x | ice-fishing hut, 2x2 cells footprint; anchor = south tip of its SE cell; window has a warm painted light (no emissive needed) |
| windmere/props/snow_rocks_a.png | 32x32 | 64x64 | (16,32) 1x | reused from map_polish (snow-capped rocks, shore scatter) |
| windmere/props/snow_rocks_b.png | 32x32 | 64x64 | (16,32) 1x | reused from map_polish (snow-capped rocks, shore scatter) |
| windmere/props/shore_boulder_a.png | 52x22 | 104x44 | (26,21) 1x | snowy boulder cluster for the lake bank (1 cell) |
| windmere/props/shore_boulder_b.png | 54x20 | 108x40 | (26,19) 1x | snowy boulder cluster for the lake bank (1 cell) |
| rowanvale/anim/lake_jump_strip(.png/_2x) | 16 frames 138x144 | 276x288 | see anim_meta.json (74.1,107.4) | fish jump, reused unchanged from map_polish_2 |
| windmere/anim/ice_bob_strip(.png/_2x) | 12 frames 48x80 @10fps | 96x160 | (32,60) 1x = bobber rest | stick, line and bobber bobbing in an ice hole; preview ice_bob_preview.gif |

## Oct 12 quality pass (Luca: keep shapes/positions, raise quality; docks = minimum bar)
- mock_rowanvale_lake_1280.png: final. v1 oval, same position (centre (25,5.6)), quality pass: docks water textures with depth, foam lace, sun glints, darker stone/mud lip, AO blend, crisp pass on plots/hedges/props. src/rowanvale_quality.py. v1 kept as mock_rowanvale_lake_v1_1280.png. Compare: rowanvale_v1_vs_final.png
- mock_windmere_lake_1280.png: final. v1 ice oval, same position, painted ice (frost, specks, 34 crisp cracks), snow drifts on the bank, re-rimmed holes with dark water, crisp pass on cabin/pines, Ironjaw re-drawn (v8 S idle) on the ice at about (23.3,6.6) instead of being painted over. src/windmere_quality.py. Compare: windmere_before_vs_final.png
- windmere/tiles + props/ice_hole*: crisp v2 kit (hard bank, bigger holes), from src/windmere_v2.py. v1 kit in _archive_v1/windmere.
- Rowanvale kit tiles/props are unchanged v1. The quality pass is in the mock only.
