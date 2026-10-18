# Asset check report: `world`

- Folder: `ship/outskirts_themes/westwatch`
- Overall: **PASS**
- Files: 59 checked; PASS 59, WARN 0, FAIL 0
- Rules: size classes (Stasium Bot + WP10a manifest), anchor bottom-centre on the footprint south tip (±2 px@2x), base = lowest 12 opaque rows inside the footprint diamond ±8 px, overhang above the base allowed, border overlap per manifest, per-zone glow palette, neon WARN, exact-half 1x, sway masks L, strips frame-exact; terrace faces 64 x (32 + 20n) at 2x (board step 20 px@2x = visual_sort.gd ELEVATION_PIXELS 10 @1x), SW offset (-64,0) / SE (0,0) from the lifted centre, top edge on the cell edge (WARN > 1.5, FAIL > 4.0 px), seam x2.5, faces h1..h2 per edge, face step == looks.json height drop; props.json blocks none|cover|los agrees with map data.

## Props

| File | Status | Size | Details |
|---|---|---|---|
| `props/dead_tree_tall@2x.png` | **PASS** | 224x256 RGBA | INFO: size class tree_broad (Luca 3 Oct decision extension, not in the Stasium Bot list); INFO: base x -44..39, inside footprint ±8 (max 7.8 px out); INFO: art spans -57..64 px; INFO: top -182 px; INFO: sway mask 112x128/224x256 L |
| `props/dead_tree_mid@2x.png` | **PASS** | 128x224 RGBA | INFO: size class tree; INFO: base x -36..40, inside footprint ±8 (max 7.4 px out); INFO: art spans -47..56 px; INFO: top -149 px; INFO: sway mask 64x112/128x224 L |
| `props/dead_tree_lean@2x.png` | **PASS** | 224x256 RGBA | INFO: size class tree_broad (Luca 3 Oct decision extension, not in the Stasium Bot list); INFO: base x -39..31, inside footprint ±8 (max 7.4 px out); INFO: art spans -49..66 px above the base (footprint corners ±64); overhang allowed (y-sort by anchor); INFO: top -134 px; INFO: sway mask 112x128/224x256 L |
| `props/hollow_stump@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -36..33, inside footprint ±8 (max 6.0 px out); INFO: art spans -51..50 px; INFO: top -101 px |
| `props/thorn_brush_a@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -41..43, inside footprint ±8 (max 7.8 px out); INFO: art spans -58..59 px; INFO: top -119 px |
| `props/thorn_brush_b@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -35..31, inside footprint ±8 (max 5.6 px out); INFO: art spans -54..63 px; INFO: top -125 px |
| `props/thorn_brush_c@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -31..36, inside footprint ±8 (max 5.1 px out); INFO: art spans -43..46 px; INFO: top -105 px |
| `props/withered_reeds@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -35..37, inside footprint ±8 (max 4.2 px out); INFO: art spans -42..42 px; INFO: top -113 px; INFO: sway mask 64x64/128x128 L |
| `props/skull_stone@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -37..42, inside footprint ±8 (max 7.8 px out); INFO: art spans -49..55 px; INFO: top -74 px |
| `props/broken_fence_cloth@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -35..35, inside footprint ±8 (max 7.8 px out); INFO: art spans -56..50 px; INFO: top -126 px |

## Tiles

| File | Status | Size | Details |
|---|---|---|---|
| `tiles/blight_a@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/blight_b@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/blight_c@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/blight_d@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/cracked_a@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/cracked_b@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/cracked_c@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/cracked_d@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/blight_edge_nw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/blight_edge_ne@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/blight_edge_nw_ne@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/blight_edge_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/blight_edge_nw_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/blight_edge_ne_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/blight_edge_nw_ne_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/blight_edge_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/blight_edge_nw_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/blight_edge_ne_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/blight_edge_nw_ne_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/blight_edge_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/blight_edge_nw_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/blight_edge_ne_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/blight_edge_nw_ne_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/blight_corner_n@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/blight_corner_e@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/blight_corner_s@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/blight_corner_w@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/cracked_edge_nw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/cracked_edge_ne@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/cracked_edge_nw_ne@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/cracked_edge_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/cracked_edge_nw_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/cracked_edge_ne_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/cracked_edge_nw_ne_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/cracked_edge_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/cracked_edge_nw_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/cracked_edge_ne_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/cracked_edge_nw_ne_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/cracked_edge_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/cracked_edge_nw_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/cracked_edge_ne_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/cracked_edge_nw_ne_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/cracked_corner_n@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/cracked_corner_e@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/cracked_corner_s@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/cracked_corner_w@2x.png` | **PASS** | 128x64 RGBA | OK |

Status rules: FAIL blocks import; WARN needs review; INFO is measurement only.
