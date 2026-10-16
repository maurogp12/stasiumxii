# Asset check report: `world`

- Folder: `ship/outskirts_themes/southbridge`
- Overall: **PASS**
- Files: 60 checked; PASS 60, WARN 0, FAIL 0
- Rules: size classes (Stasium Bot + WP10a manifest), anchor bottom-centre on the footprint south tip (±2 px@2x), base = lowest 12 opaque rows inside the footprint diamond ±8 px, overhang above the base allowed, border overlap per manifest, per-zone glow palette, neon WARN, exact-half 1x, sway masks L, strips frame-exact; terrace faces 64 x (32 + 20n) at 2x (board step 20 px@2x = visual_sort.gd ELEVATION_PIXELS 10 @1x), SW offset (-64,0) / SE (0,0) from the lifted centre, top edge on the cell edge (WARN > 1.5, FAIL > 4.0 px), seam x2.5, faces h1..h2 per edge, face step == looks.json height drop; props.json blocks none|cover|los agrees with map data.

## Props

| File | Status | Size | Details |
|---|---|---|---|
| `props/reeds_a@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -25..26, inside footprint ±8 (max 3.4 px out); INFO: art spans -31..33 px; INFO: top -113 px; INFO: sway mask 64x64/128x128 L |
| `props/reeds_b@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -30..30, inside footprint ±8 (max 3.4 px out); INFO: art spans -37..41 px; INFO: top -116 px; INFO: sway mask 64x64/128x128 L |
| `props/reeds_c@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -26..24, inside footprint ±8 (max 2.0 px out); INFO: art spans -30..29 px; INFO: top -102 px; INFO: sway mask 64x64/128x128 L |
| `props/dead_trunk_tall@2x.png` | **PASS** | 128x224 RGBA | INFO: size class tree; INFO: base x -29..32, inside footprint ±8 (max 7.8 px out); INFO: art spans -64..64 px; INFO: top -188 px; INFO: sway mask 64x112/128x224 L |
| `props/dead_stump@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -33..45, inside footprint ±8 (max 7.8 px out); INFO: art spans -41..45 px; INFO: top -126 px |
| `props/rotten_log@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -29..24, inside footprint ±8 (max 3.4 px out); INFO: art spans -63..25 px; INFO: top -71 px |
| `props/stepping_stones@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -25..24, inside footprint ±8 (max 1.1 px out); INFO: art spans -64..27 px; INFO: top -65 px |
| `props/marker_lantern_post@2x.png` | **PASS** | 128x224 RGBA | INFO: size class tree; INFO: base x -24..31, inside footprint ±8 (max 3.4 px out); INFO: art spans -44..53 px; INFO: top -177 px |
| `props/root_tangle@2x.png` | **PASS** | 128x128 RGBA | INFO: size class small; INFO: base x -39..28, inside footprint ±8 (max 7.8 px out); INFO: art spans -44..44 px; INFO: top -82 px |

## Tiles

| File | Status | Size | Details |
|---|---|---|---|
| `tiles/mud_a@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/mud_b@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/mud_c@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/mud_d@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/swamp_water_a@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/swamp_water_b@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/swamp_water_c@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/swamp_water_d@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/mud_edge_nw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/mud_edge_ne@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/mud_edge_nw_ne@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/mud_edge_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/mud_edge_nw_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/mud_edge_ne_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/mud_edge_nw_ne_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/mud_edge_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/mud_edge_nw_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/mud_edge_ne_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/mud_edge_nw_ne_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/mud_edge_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/mud_edge_nw_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/mud_edge_ne_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/mud_edge_nw_ne_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/mud_corner_n@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/mud_corner_e@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/mud_corner_s@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/mud_corner_w@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/swamp_bank_edge_nw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/swamp_bank_edge_ne@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/swamp_bank_edge_nw_ne@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/swamp_bank_edge_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/swamp_bank_edge_nw_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/swamp_bank_edge_ne_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/swamp_bank_edge_nw_ne_se@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/swamp_bank_edge_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/swamp_bank_edge_nw_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/swamp_bank_edge_ne_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/swamp_bank_edge_nw_ne_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/swamp_bank_edge_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/swamp_bank_edge_nw_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/swamp_bank_edge_ne_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/swamp_bank_edge_nw_ne_se_sw@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/swamp_bank_corner_n@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/swamp_bank_corner_e@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/swamp_bank_corner_s@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/swamp_bank_corner_w@2x.png` | **PASS** | 128x64 RGBA | OK |
| `tiles/lily_pads@2x.png` | **PASS** | 128x64 RGBA | OK |

Status rules: FAIL blocks import; WARN needs review; INFO is measurement only.
