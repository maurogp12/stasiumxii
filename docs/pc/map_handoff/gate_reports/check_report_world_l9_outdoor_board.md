# Asset check report: `world`

- Folder: `ship/l9_outdoor_board`
- Overall: **PASS**
- Files: 92 checked; PASS 92, WARN 0, FAIL 0
- Rules: size classes (Stasium Bot + WP10a manifest), anchor bottom-centre on the footprint south tip (±2 px@2x), base = lowest 12 opaque rows inside the footprint diamond ±8 px, overhang above the base allowed, border overlap per manifest, per-zone glow palette, neon WARN, exact-half 1x, sway masks L, strips frame-exact; terrace faces 64 x (32 + 20n) at 2x (board step 20 px@2x = visual_sort.gd ELEVATION_PIXELS 10 @1x), SW offset (-64,0) / SE (0,0) from the lifted centre, top edge on the cell edge (WARN > 1.5, FAIL > 4.0 px), seam x2.5, faces h1..h2 per edge, face step == looks.json height drop; props.json blocks none|cover|los agrees with map data.

## Props

| File | Status | Size | Details |
|---|---|---|---|
| `props/standing_stone@2x.png` | **PASS** | 128x224 RGBA | INFO: size class tree; INFO: base x -38..36, inside footprint ±8 (max 0.0 px out); INFO: art spans -40..37 px; INFO: top -170 px; INFO: lowest opaque row 10 px above anchor (base lies on the cell; OK) |
| `props/boulder_cluster@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -35..36, inside footprint ±8 (max 0.0 px out); INFO: art spans -53..49 px; INFO: top -113 px; INFO: lowest opaque row 10 px above anchor (base lies on the cell; OK) |
| `props/lilac_shrub@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -29..19, inside footprint ±8 (max 0.0 px out); INFO: art spans -37..35 px; INFO: top -86 px; INFO: lowest opaque row 10 px above anchor (base lies on the cell; OK) |
| `props/boulder_small@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -27..27, inside footprint ±8 (max 0.0 px out); INFO: art spans -27..30 px; INFO: top -67 px; INFO: lowest opaque row 10 px above anchor (base lies on the cell; OK) |
| `props/ruined_wall_short@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -39..23, inside footprint ±8 (max 0.0 px out); INFO: art spans -48..49 px; INFO: top -103 px; INFO: lowest opaque row 10 px above anchor (base lies on the cell; OK) |
| `props/fallen_log_short@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -3..41, inside footprint ±8 (max 0.0 px out); INFO: art spans -44..45 px; INFO: top -79 px; INFO: lowest opaque row 12 px above anchor (base lies on the cell; OK) |
| `props/stone_well@2x.png` | **PASS** | 128x224 RGBA | INFO: size class tree; INFO: base x -34..37, inside footprint ±8 (max 0.0 px out); INFO: art spans -50..50 px; INFO: top -133 px; INFO: lowest opaque row 10 px above anchor (base lies on the cell; OK) |
| `props/ruined_wall_2c@2x.png` | **PASS** | 192x160 RGBA | INFO: size class wide; INFO: base x -20..33, inside footprint ±8 (max 0.0 px out); INFO: art spans -79..47 px above the base (footprint corners ±64); overhang allowed (y-sort by anchor); INFO: top -137 px; INFO: lowest opaque row 19 px above anchor (base lies on the cell; OK) |
| `props/fallen_log_2c@2x.png` | **PASS** | 192x160 RGBA | INFO: size class wide; INFO: base x -11..33, inside footprint ±8 (max 0.0 px out); INFO: art spans -76..37 px above the base (footprint corners ±64); overhang allowed (y-sort by anchor); INFO: top -109 px; INFO: lowest opaque row 17 px above anchor (base lies on the cell; OK) |
| `props/lilac_bush@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -33..34, inside footprint ±8 (max 0.0 px out); INFO: art spans -37..36 px; INFO: top -89 px; INFO: lowest opaque row 23 px above anchor (base lies on the cell; OK) |
| `props/lilac_tuft@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -23..23, inside footprint ±8 (max 0.0 px out); INFO: art spans -23..23 px; INFO: top -64 px; INFO: lowest opaque row 23 px above anchor (base lies on the cell; OK) |
| `props/flower_tuft@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -25..27, inside footprint ±8 (max 0.0 px out); INFO: art spans -28..28 px; INFO: top -69 px; INFO: lowest opaque row 23 px above anchor (base lies on the cell; OK) |
| `props/clover_patch@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -26..27, inside footprint ±8 (max 0.0 px out); INFO: art spans -26..27 px; INFO: top -52 px; INFO: lowest opaque row 23 px above anchor (base lies on the cell; OK) |
| `props/pebbles_moss@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -27..29, inside footprint ±8 (max 0.0 px out); INFO: art spans -28..29 px; INFO: top -50 px; INFO: lowest opaque row 23 px above anchor (base lies on the cell; OK) |
| `props/fern@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -16..18, inside footprint ±8 (max 0.0 px out); INFO: art spans -16..36 px; INFO: top -71 px; INFO: lowest opaque row 23 px above anchor (base lies on the cell; OK) |

## Tiles

| File | Status | Size | Details |
|---|---|---|---|
| `tiles/grass_top_a@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/grass_top_b@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/grass_top_c@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/grass_top_d@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sandstone_a@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sandstone_b@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sandstone_c@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sandstone_d@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/wet_earth_a@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/wet_earth_b@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/water_a@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/water_b@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_a@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_b@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_c@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_d@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/stone_flag_a@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/stone_flag_b@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/stone_flag_c@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/stone_flag_d@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/grass_fringe_ne@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/grass_fringe_nw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/grass_fringe_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/grass_fringe_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/grass_fringe_corner_n@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/grass_fringe_corner_e@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/grass_fringe_corner_s@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/grass_fringe_corner_w@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/grass_fringe_sand_ne@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/grass_fringe_sand_nw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/grass_fringe_sand_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/grass_fringe_sand_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/grass_fringe_sand_corner_n@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/grass_fringe_sand_corner_e@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/grass_fringe_sand_corner_s@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/grass_fringe_sand_corner_w@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/grass_fringe_stone_ne@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/grass_fringe_stone_nw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/grass_fringe_stone_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/grass_fringe_stone_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/grass_fringe_stone_corner_n@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/grass_fringe_stone_corner_e@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/grass_fringe_stone_corner_s@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/grass_fringe_stone_corner_w@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/wet_earth_fringe_ne@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/wet_earth_fringe_nw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/wet_earth_fringe_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/wet_earth_fringe_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/water_edge_ne@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/water_edge_nw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/water_edge_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/water_edge_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/water_edge_corner_n@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/water_edge_corner_e@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/water_edge_corner_s@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/water_edge_corner_w@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/foot_ao_ne@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/raised_rim_ne@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/foot_ao_nw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/raised_rim_nw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/seal_slab@2x.png` | **PASS** | 128x64 RGBA | OK |

## Terrace

| File | Status | Size | Details |
|---|---|---|---|
| `terrace/cliff_left_h1@2x.png` | **PASS** | 64x52 RGBA | INFO: size class h1 64x52 (= 64 x (32 + 20x1)); INFO: top edge vs the cell's SW edge: median 0.2 px, max 0.2 px; INFO: side seam (chained along the +x edge) diff 12.3 vs inner 8.5 (x1.45) |
| `terrace/cliff_left_h1_water@2x.png` | **PASS** | 64x52 RGBA | INFO: size class h1 64x52 (= 64 x (32 + 20x1)); INFO: top edge vs the cell's SW edge: median 0.2 px, max 0.2 px; INFO: side seam (chained along the +x edge) diff 12.0 vs inner 11.1 (x1.09) |
| `terrace/cliff_right_h1@2x.png` | **PASS** | 64x52 RGBA | INFO: size class h1 64x52 (= 64 x (32 + 20x1)); INFO: top edge vs the cell's SE edge: median 0.2 px, max 0.2 px; INFO: side seam (chained along the -y edge) diff 7.3 vs inner 6.3 (x1.15) |
| `terrace/cliff_right_h1_water@2x.png` | **PASS** | 64x52 RGBA | INFO: size class h1 64x52 (= 64 x (32 + 20x1)); INFO: top edge vs the cell's SE edge: median 0.2 px, max 0.2 px; INFO: side seam (chained along the -y edge) diff 10.2 vs inner 7.6 (x1.34) |
| `terrace/cliff_left_h2@2x.png` | **PASS** | 64x72 RGBA | INFO: size class h2 64x72 (= 64 x (32 + 20x2)); INFO: top edge vs the cell's SW edge: median 0.2 px, max 0.2 px; INFO: side seam (chained along the +x edge) diff 10.2 vs inner 9.7 (x1.06) |
| `terrace/cliff_right_h2@2x.png` | **PASS** | 64x72 RGBA | INFO: size class h2 64x72 (= 64 x (32 + 20x2)); INFO: top edge vs the cell's SE edge: median 0.2 px, max 0.2 px; INFO: side seam (chained along the -y edge) diff 7.9 vs inner 6.8 (x1.16) |
| `terrace/cliff_left_h3@2x.png` | **PASS** | 64x92 RGBA | INFO: size class h3 64x92 (= 64 x (32 + 20x3)); INFO: top edge vs the cell's SW edge: median 0.2 px, max 0.2 px; INFO: side seam (chained along the +x edge) diff 10.5 vs inner 9.3 (x1.13) |
| `terrace/cliff_right_h3@2x.png` | **PASS** | 64x92 RGBA | INFO: size class h3 64x92 (= 64 x (32 + 20x3)); INFO: top edge vs the cell's SE edge: median 0.2 px, max 0.2 px; INFO: side seam (chained along the -y edge) diff 6.9 vs inner 6.5 (x1.07) |
| `terrace/grass_overhang_left@2x.png` | **PASS** | 64x52 RGBA | INFO: lip covers 5.5 px of the top face, hangs 11.2 px over the face |
| `terrace/grass_overhang_right@2x.png` | **PASS** | 64x52 RGBA | INFO: lip covers 5.5 px of the top face, hangs 11.0 px over the face |
| `terrace/grass_overhang_corner_front@2x.png` | **PASS** | 40x40 RGBA | INFO: corner pivot [20, 12] covered |
| `terrace/grass_overhang_corner_left@2x.png` | **PASS** | 40x40 RGBA | INFO: corner pivot [20, 12] covered |
| `terrace/grass_overhang_corner_right@2x.png` | **PASS** | 40x40 RGBA | INFO: corner pivot [20, 12] covered |

## Kit metadata

| File | Status | Size | Details |
|---|---|---|---|
| `kit:atlas_meta.terrace[]` | **PASS** | 13 pieces | INFO: SW face classes h[1, 2, 3]; INFO: SE face classes h[1, 2, 3]; INFO: h1: SW luma 93 > SE 56 (key top-left OK); INFO: h2: SW luma 85 > SE 51 (key top-left OK); INFO: h3: SW luma 79 > SE 49 (key top-left OK) |
| `kit:looks.json terrace` | **PASS** | 225 cells | INFO: 33 visible faces checked against looks.json heights (step 20 px@2x) |
| `kit:props.json blocks` | **PASS** | 15 props | INFO: cross-checked 61 placements against crosshaven_15x15_tags.json |

Status rules: FAIL blocks import; WARN needs review; INFO is measurement only.
