# Ironjaw full set v3 (technical fix of the approved v2)
Built Oct 3 2026, 20:34–20:50 ET. v2 is untouched (read-only source). **No pixel of the art changed**: every v3 frame is
the v2 frame moved by a whole-pixel offset into a larger transparent cell. No repaint, recolour, restyle or resampling.
Same folder structure, file names, frame counts, fps and facings as v2.

## What changed vs v2
1. **Cells grown so every frame has >= 4 px of clear margin on all sides** (v2: 51 of 128 frames had < 4 px, 10 within 2 px,
   walk W f11 and attack W f02 touching the left edge, 4 and 8 px).
2. **Pivot y moved onto the feet**: v2 pivot y 133 sat 4–5 px above the soles. v3 pivot = v2 row **138** (the idle S/W sole row)
   + the 2 px top pad = **140**. Same foot point in every state, so state switches move nothing (same as v2).
3. **Centred pivot x** (82 of 165, 104 of 209): W = plain left/right flip of S and N = plain flip of E (file flip, no offset).
   v2 needed "flip about x = 78" (a 4 px offset). Regenerated as exact flips and checked pixel-identical to the padded v2 W/N.
4. qa.json recomputed, contact sheets at 1x and at the real combat draw scale **0.5x** (v2 sheets said 0.6x), strips rebuilt.

## Cells and pivots (centered = false, offset = -pivot)
| state | frames | v2 cell / pivot | **v3 cell / pivot** | shift applied (x, y) |
|---|---|---|---|---|
| walk / idle / attack / hit (one shared cell) | 12 / 4 / 6 / 4 | 161x155 / (78,133) | **165x157 / (82,140)** | +4, +2 |
| death | 6 | 205x178 / (102,133) | **209x183 / (104,140)** | +2, +2 (+3 rows at the bottom) |

All four facings use the same cell and pivot. Content bbox over all frames (v2 coords): x 0–156, y 2–150 (death x 2–202, y 2–176),
i.e. exactly ±78 (±100) around the pivot x, so the centred cell is the tightest one with 4 px margins.

## Clipping: no pixels were lost, none reconstructed
* walk W f11 and attack W f02 are exact flips of walk S f11 / attack S f02 about x = 78. The S frames end at column 156 (4 px
  inside their right edge), which maps to column 0 in W. The flip itself dropped 0 pixels (checked for every W/N frame).
* Searched for un-clipped sources (pixel-exact template search of both axe tips over ~14k PNGs in /workspace, /home/box, /tmp,
  incl. ironjaw_uploads, stasium-ref/chars, stasium-repo art/characters/ironjaw, scratch/l9_src, wakfu-ship*): the tips exist
  only in v2 itself (frames, strips, contact sheet), all ending at the same column. No v1/v7/work folder is on disk.
* Shape check says the tips are complete, not cut: walk S f11's blade tip is the same 4-px blunt end as walk S f00 and attack
  S f05 / hit S f03 (mask match, shifted 1 px), which end at column 155 with nothing cut. The attack S f02 blade edge follows a
  circle fitted to its un-clipped lower edge (r ~ 11–17 px), which peaks at column 155.7–156.5, i.e. the painted edge (col 156).
* So **0 pixels were reconstructed**; v3 only gives these tips room. If Mauro reads the blunt tips as cut, that is the painted shape.

## Feet / pivot (measured, lowest opaque row vs pivot, v3)
* idle: S/W **0**, N/E **-1** (sole row 139 = bottom edge exactly on the pivot line). attack/hit/death f0 N/E -1.
* S/W attack, hit, death f0–f3 and walk use the v1 stride: the front boot's toe reaches +12 (v2 +17) and the back foot is ~5–13 px
  above the pivot, so the stride straddles the pivot; the torso lines up with idle (best shift walk 0,0; attack 2,-4; hit/death
  ±2,+4/5 = the authored lean/flinch, as in v2). A per-state pivot cannot "fix" this without making the body jump 12 px, so the
  shared pivot is kept. State-switch jumps are therefore identical to v2: N/E sole 0–1 px; S/W lowest-row 12 px from pose (idle S
  is a neutral stand, the actions start in a stride), body as above.
* S/W death f04–f05 lie 36–38 px toward the camera of the pivot (v2 41–43; accepted).

## QA (`qa.json`, same schema as v2)
{"semi": 0, "near_white": 0, "cyan": 0, "isolated_light": 82, "light_fixed": 0}; edge touches: **none** (min margin 4 px, all 128 frames).
RGB under alpha 0 is (0,0,0) everywhere; alpha only 0/255. isolated_light carried per frame from v2 (pixels identical; painted
metal highlights, none near-white). light_fixed 0 = no pixel edits in v3 (v2's 666 were v2 fixes).

## Files
* `<state>/ironjaw_<state>_<F>_fNN.png` (128 frames) + `<state>/ironjaw_<state>_<F>_strip.png` (20 strips, = frames)
* `ironjaw_full_v3_contact_sheet_1x.png`, `ironjaw_full_v3_contact_sheet_game0.5x.png`, `qa.json`, `_cells_pivots.json`
* Build/QA code: /workspace/scratch/ij_v3/ (`build_v3.py`, `qa_v3.py`, `sheet_v3.py`, `pics_v3.py`, `scan.py`)
* Wiring values: /workspace/stasium-pc-look/ship/characters_pc/json/ironjaw.json (v2 json kept as `ironjaw_v2.json`)
* Draw scale: per class (size tier "big", target 78 board px): `draw_scale` 0.578, `world_draw_scale` 0.532, `head_hp_y` -87.
