# Asset check report: `world`

- Folder: `ship/outskirts_themes/eastmarch`
- Overall: **PASS**
- Files: 94 checked; PASS 94, WARN 0, FAIL 0
- Rules: size classes (Stasium Bot + WP10a manifest), anchor bottom-centre on the footprint south tip (±2 px@2x), base = lowest 12 opaque rows inside the footprint diamond ±8 px, overhang above the base allowed, border overlap per manifest, per-zone glow palette, neon WARN, exact-half 1x, sway masks L, strips frame-exact; terrace faces 64 x (32 + 20n) at 2x (board step 20 px@2x = visual_sort.gd ELEVATION_PIXELS 10 @1x), SW offset (-64,0) / SE (0,0) from the lifted centre, top edge on the cell edge (WARN > 1.5, FAIL > 4.0 px), seam x2.5, faces h1..h2 per edge, face step == looks.json height drop; props.json blocks none|cover|los agrees with map data.

## Props

| File | Status | Size | Details |
|---|---|---|---|
| `props/cave_mouth_sandstone@2x.png` | **PASS** | 192x160 RGBA | INFO: size class wide; INFO: base x -63..36, inside footprint ±8 (max 7.4 px out); INFO: art spans -94..60 px above the base (footprint corners ±64); overhang allowed (y-sort by anchor); INFO: top -160 px; INFO: lowest opaque row 15 px above anchor (base lies on the cell; OK) |
| `props/cave_mouth_grey@2x.png` | **PASS** | 192x160 RGBA | INFO: size class wide; INFO: base x -67..30, inside footprint ±8 (max 7.4 px out); INFO: art spans -93..60 px above the base (footprint corners ±64); overhang allowed (y-sort by anchor); INFO: top -160 px; INFO: lowest opaque row 15 px above anchor (base lies on the cell; OK) |
| `props/tidepool_rocks_a@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -43..42, inside footprint ±8 (max 6.9 px out); INFO: art spans -59..58 px; INFO: top -102 px |
| `props/tidepool_rocks_b@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -39..44, inside footprint ±8 (max 7.4 px out); INFO: art spans -60..59 px; INFO: top -94 px |
| `props/driftwood_long@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -36..33, inside footprint ±8 (max 4.2 px out); INFO: art spans -52..64 px; INFO: top -91 px |
| `props/driftwood_fork@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -29..36, inside footprint ±8 (max 4.2 px out); INFO: art spans -49..61 px; INFO: top -97 px |
| `props/shell_heap@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -38..36, inside footprint ±8 (max 7.8 px out); INFO: art spans -54..59 px; INFO: top -86 px |
| `props/mooring_post@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -28..33, inside footprint ±8 (max 2.9 px out); INFO: art spans -50..59 px; INFO: top -119 px |

## Tiles

| File | Status | Size | Details |
|---|---|---|---|
| `tiles/sand_a@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_b@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_c@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_d@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/wet_sand_a@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/wet_sand_b@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sea_shallow_a@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sea_deep_a@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sea_shallow_b@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sea_deep_b@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_edge_nw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_edge_ne@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_edge_nw_ne@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_edge_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_edge_nw_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_edge_ne_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_edge_nw_ne_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_edge_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_edge_nw_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_edge_ne_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_edge_nw_ne_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_edge_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_edge_nw_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_edge_ne_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_edge_nw_ne_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_corner_n@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_corner_e@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_corner_s@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_corner_w@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/wet_sand_edge_nw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/wet_sand_edge_ne@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/wet_sand_edge_nw_ne@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/wet_sand_edge_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/wet_sand_edge_nw_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/wet_sand_edge_ne_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/wet_sand_edge_nw_ne_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/wet_sand_edge_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/wet_sand_edge_nw_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/wet_sand_edge_ne_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/wet_sand_edge_nw_ne_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/wet_sand_edge_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/wet_sand_edge_nw_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/wet_sand_edge_ne_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/wet_sand_edge_nw_ne_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/wet_sand_corner_n@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/wet_sand_corner_e@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/wet_sand_corner_s@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/wet_sand_corner_w@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_surf_edge_nw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_surf_edge_ne@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_surf_edge_nw_ne@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_surf_edge_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_surf_edge_nw_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_surf_edge_ne_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_surf_edge_nw_ne_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_surf_edge_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_surf_edge_nw_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_surf_edge_ne_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_surf_edge_nw_ne_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_surf_edge_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_surf_edge_nw_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_surf_edge_ne_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_surf_edge_nw_ne_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_surf_corner_n@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_surf_corner_e@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_surf_corner_s@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sand_surf_corner_w@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sea_deep_edge_nw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sea_deep_edge_ne@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sea_deep_edge_nw_ne@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sea_deep_edge_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sea_deep_edge_nw_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sea_deep_edge_ne_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sea_deep_edge_nw_ne_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sea_deep_edge_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sea_deep_edge_nw_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sea_deep_edge_ne_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sea_deep_edge_nw_ne_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sea_deep_edge_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sea_deep_edge_nw_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sea_deep_edge_ne_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sea_deep_edge_nw_ne_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sea_deep_corner_n@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sea_deep_corner_e@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sea_deep_corner_s@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/sea_deep_corner_w@2x.png` | **PASS** | 128x64 RGBA | OK |

Status rules: FAIL blocks import; WARN needs review; INFO is measurement only.
