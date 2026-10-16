# L9 Crosshaven v1 decor, v2: decorations where mock v1 puts them

Luca (7:42): "the decorations should be at the same place as the old one; the only changes are the tiles."
Reference: `previews/l9_outdoor_board/mock_l9_1280_v1.png`. Its compositor is `/workspace/scratch/l9_build_v1_backup/mock.py compose()`; `/workspace/scratch/l9_render.py` only renders the tile board. The tools re-render the mock from that source with 0 px difference (`tools/l9_v1_decor_v2/mock_v1.py`).
Scratch only: nothing committed or pushed. The branch is `cursor/l9b-v1-decor-ae16` @ af040d7.

## 1. Mock v1 layer table (as composited, 1280×720 mock px, Z = 0.71)
| layer | source | scale | rect in mock px (x, y, w, h) | order / notes |
|---|---|---|---|---|
| sky (back_far) | v4 `crosshaven_jungle/back_far@2x` | 1.06·0.71·0.5 | (−130, −122, 1541, 963) | bottom; no modulate |
| clearing (back_mid) | v4 `back_mid@2x` | 0.355 | (−87, −94, 1454, 909) | over sky; its alpha hole is the sky gap, with the silhouette tree in the sky art |
| board shadow | board alpha, gaussian | — | under the board | opacity 0.45 |
| board + props | 2x render, origin (1000, 280), 2000×1380 | 0.355 | (285, 42, 710, 490) | cell (7,7) centre at (640, 300.5); canopy tint (0.896, 0.949, 0.912) on the board only |
| leaf top | v4 `front_leaves_top` @1x | 1 | (0, 0, 1280, 240) | leaves drawn top, bottom, left, right |
| leaf bottom | `front_leaves_bottom` | 1 | (0, 480, 1280, 240) | |
| leaf left | `front_leaves_left` | 1 | (0, 0, 512, 720) | |
| leaf right | `front_leaves_right` | 1 | (768, 0, 512, 720) | every leaf is masked by the board+props alpha dilated 6 px |
| props | `l9_v1_ship/props/<id>@2x` on their cells | 0.5 (board px) | origin = cell centre + (0, 16) − anchor·0.5 | anchors @2x: standing_stone and stone_well (64, 224) on 128×224; all others (64, 128) on 128×128 |

Mock px → board px: `bx = ((xm − 285)/0.355 − 1000)/2`, `by = ((ym − 42)/(490/1380) − 280)/2`.

## 2. Game camera and mapping
The only camera is the fit camera: zoom 0.64, camera at board (0, 307.75), screen = (640, 163.04) + 0.64·board.
Mock → game screen: `xg = 0.90141·xm + 63.098`, `yg = 0.901224·ym + 35.589`. The mock frame lands on game px (63.1, 35.6)–(1216.9, 684.5).
Every layer is therefore placed in **board space**, at the mock position mapped through that transform. Mirror bleed fills the rim outside the mock frame, the pans (±220 world px) and 21:9.

| slot | centre (board px) | world size | z |
|---|---|---|---|
| sky | (0.0, 308.5) | 2847.843 × 1440.023 | — |
| clearing | (0.0, 308.5) | 2847.843 × 1440.023 | — |
| leaf_frame_left | (-702.817, 144.449) | 1045.07 × 1363.102 | 722 |
| leaf_frame_right | (702.817, 144.449) | 1045.07 × 1363.102 | 723 |
| leaf_frame_top | (0.0, -199.143) | 2450.704 × 675.918 | 720 |
| leaf_frame_bottom | (0.0, 651.388) | 2450.704 × 349.224 | 721 |

- Leaves are pinned to the board (they move with it on a pan), so the mock's baked keep-out around the board always lines up.
- Sky and clearing keep their JSON parallax on pans and sit exactly at the mock spot at rest.
- Leaves are cut at screen y 545 (`hud_clear_px` 175, the action-bar tab top), so no leaf pixel ever lands on the HUD.

## 3. Wiring patch for Stasium Bot: `v1_mock_placement.patch` (apply with `patch -p1` on af040d7)
`board/pc/jungle_backdrop.gd`:
- `v1_placement()` / `_placed()` read the optional `v1_decor.placement` block (empty means the old behaviour).
- `_layout_backs`: in v1 placement mode, the drawn plate size is the placement `world_size`.
- `_layout_plate`: in v1 placement mode, plate position = `center + pan·(1 − parallax)`. That is exact at rest and keeps the parallax slide.
- `_layout_leaves` → new `_place_leaf_at`: no margins, no contain-fit, no `_leaf_crop`, no recentring. Each frame goes at its explicit centre and size, with a per-slot z (top 720, bottom 721, left 722, right 723 = the mock order). Sway amplitude is clamped to the pad.
- Sway shader: new uniform `cut_y` discards pixels below `SCREEN_UV.y > cut_y`. It defaults to 2.0 (no cut) and is set to `1 − hud_clear_px/view_h` in placement mode.
- `_leaf_sway_image` reads `leaf_frame_<edge>_sway.png` from the v1 kit when the kit is live.

`board/pc/crosshaven_board.gd`:
- When `props_live` is on, v1 plants may sit on raised cells. Mock v1 has 15 plants on h1/h2 cells, and `DECOR_ON_RAISED` would drop them.

Data:
- `crosshaven_backdrop.json` `v1_decor` gets the block in `crosshaven_backdrop.v1_decor.additions.json` (placement, `hud_clear_px` 175, `props_live` true).
- `art/pc/look/crosshaven_board/looks.json`: `v1_frame` and `v1_plants` are replaced by `looks_v1_mock_props.json`.
- Art: copy `sky`, `clearing`, `leaf_frame_*` (+@2x, +_sway) to `art/pc/look/crosshaven_decor/`. Copy `props/*.png` (the v1 paint for all 13 ids) to `art/pc/look/crosshaven_board/props/`.
- Deploy recipe: `tools/l9_v1_decor_v2/deploy_v2.sh`.

## 4. Props: mock v1 cells and anchors, not the branch's v1_frame / v1_plants
- `looks_v1_mock_props.json` (branch schema): 26 v1_frame rows (layer 'prop') and 25 v1_plants rows. The seal-slab tile_overlay rows stay.
- `props_diff_branch_vs_mock.md`: 77 differing rows (40 prop, 37 plant). The branch rim sat off-grid at x/y = −1 or 15; the mock puts everything on cells.
- Mock v1 includes 3 `ruined_wall_short` and 2 `fallen_log_short`. That breaks the earlier "no walls/logs" note, but they're kept because Luca's rule wins.
- Two props sit on non-ground cells, as in the mock: boulder_small (12,1) on mud, fallen_log_short (8,14) on water.

## 5. Match (real game, scratch copy + patch, fit camera, 1280, sway frozen, grade off for the numbers)
| check | result |
|---|---|
| board footprint vs mock (tiles differ, footprint must not) | shift (-0.03, -0.11) px, IoU 0.9938 |
| sky + clearing plate (gradient phase correlation, outside board) | shift (+0.00, +0.02) px, mean RGB diff 1.7 |
| props, all 51 (per-prop centroid) | max 1.32 px, mean 0.28 px; global shift (-0.04, -0.02), IoU 0.9297 |
| whole non-tile frame structure | shift (+0.01, +0.01) px |
| non-tile colour diff above the HUD line | median 1.11, mean 3.5 (0–255); 2.75% of px > 24 |
| leaf pixels at y ≥ 545 / ≥ 572 | 0 / 0 (lowest leaf row 544) |
| leaf pixels over any cell (1920) | 0 |

| leaf slot | phase shift px | centroid Δ px | IoU (mock frame, above HUD) |
|---|---|---|---|
| top | (+0.09, -0.28) | (+1.09, +0.31) | 0.982 |
| bottom | (+0.11, +0.35) | (-0.42, -0.14) | 0.954 |
| left | (-0.44, +0.08) | (+0.44, -0.02) | 0.993 |
| right | (+0.20, +0.08) | (-0.69, -0.07) | 0.988 |

### What does not match, and why
1. **Bottom leaf cluster is mostly gone.** 96.9% of the mock's bottom ferns sit below game y 545 once the mock is mapped to the game camera. The game puts the HUD there, and the rule is zero leaf pixels on the HUD. In total 123149 mock leaf px fall in that band, including the lower ends of the side clusters. The remaining 3% (the tips above y 545) are in place.
2. **Board edge shadow.** The game draws its contact rim and skirt; the mock used a 0.45 gaussian. This is board rendering, not decor, so it is left as is (the orange ring in `diff_nontile_1280.png`).
3. **Colour grade.** The mock tints the board and props by the canopy colour; the game uses its own light grade. The numbers were taken with the grade off, and the beauty shots use the shipped preset.
4. **Rim outside the mock frame** (63 px sides and 36 px top at 16:9 rest, more on pans and at 21:9) shows mirrored bleed of the leaves and plates, because the mock has no art there. See `pans_and_21x9_sheet.png`.
5. **Sway.** Live leaves sway (±14 px, clamped to the 12 px pad); the proof has sway frozen at rest.

## 6. Cell coverage by the mock props (kept, per Luca's rule)
- Full table: `prop_cell_coverage_mock_v1.md` / `.json`. It gives the visible share of each cell's top diamond, measured in game at 1920 after tile occlusion.
- The TA-flagged cells (4,15), (15,7), (15,13) and (14,15) are branch v1_frame off-grid spots. Mock v1 doesn't use them, so those 20–44% numbers no longer apply.

## 7. Branch tests on the scratch copy (expected design changes)
- Board 527 pass / 7 fail. These assert the branch's off-grid rim, the "no plants on raised cells" rule and the old v1 data.
- Jungle 432 pass / 5 fail. "front leaves stay locked to the screen" fails because the leaves are now pinned to the board. The other four (v4 modulate ×3, far slide) were already failing on the branch once v1 files exist.

## Files
- ship: sky/clearing/leaf_frame_* (+@2x, +_sway), `props/`, `placement_v1_mock.json`, `crosshaven_backdrop.v1_decor.additions.json`, `looks_v1_mock_props.json`, `props_diff_branch_vs_mock.md`, `prop_cell_coverage_mock_v1.*`, `match_1280.json`, `v1_mock_placement.patch`.
- previews (`previews/l9_v1_decor_v2/`): `sbs_game_vs_mock_1280_{off,ship}.png`, `diff_nontile_1280.png`, `edges_nontile_1280.png`, `blend_50_game_mock_1280.png`, `leaf_silhouettes_*`, `prop_silhouettes_*`, `game_fit_*`, `mock_v1_mapped_to_game_camera_1280.png`, `pans_and_21x9_sheet.png`.
- tools (`tools/l9_v1_decor_v2/`): `mock_v1.py`, `build_v2.py`, `props_v2.py`, `deploy_v2.sh`, `capture_l9_v2.gd`, `capture_l9_v2_pans.gd`, `cap_v2.sh`, `analyze_v2.py`, `coverage_v2.py`.
