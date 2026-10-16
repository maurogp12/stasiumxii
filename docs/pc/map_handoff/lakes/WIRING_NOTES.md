# Wiring notes, lakes v1 (Proposed)
Cell (x,y) = zone tile coords. "Edge X" means the water/ice is on side X of the cell (NE = toward -y, SW = toward +y, NW = toward -x, SE = toward +x). Lakes are walk-blocking except for the jetty cells. Every existing decor item stays. Lakes only replace floor tiles, and props go on top.

## Rowanvale, rowanvale_farmland_3 (v2: reshaped around the plots; roads x=16 and y=12 and gate (0,16) untouched)
Luca's rule: never remove existing decor. The v1 ellipse covered farm plots. v2 is a winding pond chain through the grass gaps between plots, in the area x=20..26, y=3..8.
- Plot-free water cells (use the lake_water_* tiles; shallow at the edges, mid inside): (20,3), (21,3), (21,6), (21,8), (22,4), (22,6), (22,7), (24,4), (24,7), (25,3), (25,4), (25,6), (25,7).
- Mixed cells contain both plot and water: (21,4), (21,7), (22,3), (22,5), (22,8), (23,4), (23,5), (23,6), (23,7), (23,8), (24,3), (24,5), (24,6), (25,5), (26,3), (26,4). The plot pixels in these cells must stay. Keep the existing farmland floor tile, and draw the water as a floor-decal overlay masked to the grass part, or leave the cell as dry bank. Do not swap a lake tile in here. Per-cell water and plot fractions are in `rowanvale/cellmap_v2.json`.
- The shore_grass_water_* edge pieces are only for plot-free cells next to water.
- Fishing spots (lake): (21.8,6.5) and (24.1,6.1). Each gets a lake_spot_ring decal plus the lake_jump anim, with a fishing_stake on the nearest grass bank.
- Reeds, stakes and lily pads were placed by script only on clean grass or water pixels (3 px away from any plot). The rowboat sits fully on water, clear of the rings and plots. The v1 jetty is dropped because there's no plot-free run long enough for it.
- Ironjaw's spot (around cell (24,6)) is kept dry, as a little grass point he fishes from. The rowboat is drawn only when its anchor lands on water.
- Proof: `rowanvale_plots_check_1280.png` (plots in magenta). Every plot pixel is restored after the water pass, so 0 plot px are covered by water. About 120 plot px, at the very edges of plots, sit under small props (reeds, stake, ring rim). Move those props 1 tile if even that matters.

## Windmere, windmere_outer_3, rect x=20..29, y=2..7 (gate (0,16) untouched); v2 crisp kit
The ice is fully walkable (frozen). The exact cell-to-tile map used by the mock is in `windmere/cellmap.json`, with 62 cells. Wire it 1:1.
- Ice: interior cells use ice_plain_a, or ice_plain_b for deep cells (more than 1.6 cells from the bank). About 1 in 3 is swapped for ice_cracked_a/b, never on a hole cell.
- Bank (hard edge): a land cell with ice on exactly one side gets shore_snow_ice_edge_<side>. Ice on two adjacent sides gets outer_n (NE+NW), outer_e (NE+SE), outer_s (SW+SE) or outer_w (SW+NW). Ice only on a diagonal gets inner_<wedge>. Side meanings: NE = -y, SW = +y, NW = -x, SE = +x.
- Ice holes (v2, bigger): (22,3), (25,4) and (27,6). Put the windmere/props/ice_hole decal (77x44 at 1x) on the floor-decal layer, anchored bottom-centre at the cell centre +12 px (1x). The ice_bob anim pivot goes at the hole centre. These are the 3 fishing interact points.
- Fishing hut: footprint (20,6)-(21,7), anchored at the south tip of (21,7), blocking. Sled at (22,7).
- Rocks: shore_boulder_a at (20,3) and (25,2); shore_boulder_b at (23,7) and (28,3); snow_rocks_a at (21,2) and (29,5); snow_rocks_b at (26,7).
- The existing trees along the SE edge (x=27..29, y=6..7) stay and draw above the bank.
- The mock draws Ironjaw (v8 S idle) on top, at his capture spot.

## Honest caveats
- `rowanvale/tiles/shore_grass_water_*` (v1, from build.py) still have the v1 bank-geometry bug: the bank line sits off the diamond, so the edge tiles read almost all grass. The Windmere v2 tiles have this fixed in `src/windmere_v2.py`. Apply the same 2-line fix to Rowanvale before wiring its shore tiles.
- `clip_rowanvale_lake.mp4`, `clip_windmere_lake.mp4` and `contact_sheet.png` are still v1 and haven't been re-rendered.
- The cell rects come from the overlay grid in the annotated captures (1 cell = 46x23 px), not from zone data.
- Rowanvale v2 reads as a winding pond chain with the plots as islands. That's the only shape that keeps every plot visible inside this farmland. If Luca wants one round lake instead, it needs a grass area with no plots (none exists in this chunk) or a new chunk.
- The mocks' ground inside the old annotation rect is de-overlaid from the capture, so it's slightly lighter than the real tiles.

## Oct 12 update
- Rowanvale lake: v1 shape and position are unchanged (Luca's call), so the cell wiring above still applies. It still covers some farmland plot floor cells. Luca chose shape over avoiding the plots.
- Windmere: same cells and holes (22,3),(25,4),(27,6). ice_hole v2 is bigger (~1.2 cells): anchor bottom-centre at cell centre y+12 (1x). Tiles keep the same names, now crisp v2.
