# Mender walk v1 (Claude): painted legs on blockout v3.1 (S) / v3 (E)

The Mender walk for S and E, 12 frames each; W and N are mirrors of S and E. First pass for review, not locked.

Same method as the locked Kestrel (`kestrel/v3_claude/`) and Gloam (`gloam/v1_claude/`) walks. Their scripts were copied and adapted here; neither was changed.

- **Legs.** Each leg is one continuous painted leg cut from the approved target (hip → thigh → knee → wrapped boot → sole). It is bent onto every frame's blockout joints with 3-bone mesh skinning (hip, knee, ankle). It hangs from the target's belt hips, and the boot is pinned to the blockout heel and toe.
- **Upper body.** The hood, face, mantle, robe, sash, pouches, arms, staff and lantern are the approved target, placed with one uniform scale. They follow the blockout pelvis and bob.

## Inputs

- **Approved look.** `targets/mender_rp_{S,E}_f00.jpg` and `_alpha.png`: the design-B repaint `3250c2ba` (on `art/ironjaw-walk-help`), which Mauro approved. The rejected first pair in `targets/_orig/` is not used.
- **Blockout** on `claude/class-walk-blockouts`:
  - S uses Mender **v3.1** (`ca1a7c30`): the narrow S foot track (`foot_w` 0.3) Mauro picked from `s_track_options.png`. Contact foot-pair angle is 44° at f00 and 27° at f06, against the 27° walk diagonal.
  - E uses Mender **v3** (`ffbfe3a9`). v3.1 leaves E byte-identical.
- **Gate change for Mender only (Mauro).** The far-boot ≥ 60% gate is dropped because the robe covering the boots is accepted. Far-boot % is still reported below.

## What changed from the Gloam pipeline

- **Robe cut (`mcut.py`).** The ivory robe hangs to the boot tops, so the robe, staff and lantern are the front layer in S and E. The legs only show below the hem and, in S, through the robe's front slit.
  - S source leg: the forward leg in the slit, cut from the trouser to the wrapped boot (blockout L).
  - E source leg: the planted screen-right boot (blockout R). The staff in front of its toe is painted out.
  - Above the visible part, each leg is grown from its own pixels (Gloam's method) and is hidden under the robe.
  - The S slit is filled with the robe's dark inside. The fill is darkest at the slit's apex and has a ragged edge at the hem.
  - The right panel's grey lining, beside the forward leg, stays painted but is drawn behind the legs.
  - Where a boot was removed, the robe hem ends in ragged tatter tips instead of the cut polygon's straight edge. Light robe tatters that hang over a boot top are kept.
- **Hood top, not staff.** The figure top used for placement is the hood. The E staff crook rises above the hood, so `clay_top` only looks within 15 px of the `head_top` joint. The crook can enter Gloam's fixed column window on some E clay frames.
- **Settings (`mcfg.json`).**
  - S: s 0.372, dy −0.3, `foot_o` (−3.3, +3.0).
  - E: s 0.368, dy −2.0, `foot_o` (+2.6, +4.0). `foot_o` puts the painted sole on the clay sole; sole error is ≤ 1.35 px in S and ≤ 2.3 px in E.
  - E dy is set so the belt stays inside ±2.5 (it was −3.9 at the first auto dy) with no planted foot pulled.
- **S f03 shin X fixed with one swing key.** `swing_keys` L f03 = (+5, +3) cell px moves the L swing foot slightly forward and down. f03 is a swing frame for L, so nothing planted moves. The shins no longer cross below the knee on any S frame.
- **Kept from Kestrel and Gloam:** `thigh_fwd_max` 25°, crotch fill, speck fill (S 20 px, E 10 px), straight late stance (`stance_kmin` 0.82), and the toe-off toe pin.

## Scores (Bastion metric, `run_metric.py`, unchanged; against the clay above)

| | look | ssim upper / lower | iou | palette | height vs idle | bob err | motion | sole_err per frame (px) |
|---|---|---|---|---|---|---|---|---|
| S | **90.5** (PASS) | 0.980 / 0.710 | 0.895 | 0.948 | 1.013 | 0 | **100** | 0.06 0.01 0.04 0.14 0.04 0.37 1.35 0.05 0.08 1.08 0.28 0.66 |
| E | **87.0** (PASS) | 0.985 / 0.673 | 0.816 | 0.949 | 0.971 | 6.58 | 8.3 | 2.30 1.79 1.11 0.61 1.27 1.32 1.83 0.13 0.61 0.13 0.61 1.88 |

E motion fails on bob, not on the feet. The metric's `head_top` reads columns 200–312. On clay E f00–f03 and f11, the clay's staff crook (x ≈ 310) is inside that window and is read as the head, so the clay "bob" jumps 6–9 px. The painted staff stays outside the window, so the walk's head top is the hood. On f04–f10, where the clay reading is also the hood, the walk is a steady 2 px above it (dy −2). The same staff crook sets the idle top, so E `height_vs_idle` reads 0.971.

## Checks (all 12 frames)

| | thigh/shoulder | boot/shoulder | belt→sole | knee line | stance bend | swing thigh max | crotch bg px | skate |
|---|---|---|---|---|---|---|---|---|
| S | −1.5 to +1.4% | −0.8 to +2.2% | −0.9 to +0.7 pts | −1.7 to +0.2 pts | 7.6° every frame | 23.8° | 0 | 0.56 px |
| E | −1.0 to +1.6% | −1.6 to +1.2% | −2.3 to +0.8 pts | −1.6 to +1.0 pts | 7.2° every frame | 24.8° | 0 | 0.54 px |

- **Shins.** No X below the knee on any S frame (`s_checks_S.json` → `shins_cross`).
- **Stance.** Stance legs are straight on every frame. The only bent planted legs are toe-off legs (heel up, toe pinned): S f06 R 16.5° and f07 R 36.9°, the same pattern as Gloam's locked S (34–62°).
- **Along-bone k.** 0.87–1.05 in S and 0.93–1.08 in E, under the 1.10 cap. No planted foot is pulled.
- **Facing.**
  - S: the face and hood look down-right, toward the travel direction, on every frame.
  - E: the back of the hood faces up-right.
  - Both are the approved target's head, unchanged.

**Far boot visible share, S** (report only, `feet_S_far_boot.json`; the robe hem counts as cover):

| f00 | f01 | f02 | f03 | f04 | f05 | f06 | f07 | f08 | f09 | f10 | f11 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 71.5 | 57.9 | 58.6 | 27.6 | 91.9 | 86.7 | 77.0 | 71.6 | 72.6 | 79.0 | 9.4 | 75.6 |

## Files

| file | what |
|---|---|
| `frames/mender_walk_{S,E}_f00..f11.png` | 512x360 RGBA cells, pivot (256,329), binary alpha, black under alpha 0. `_build_info.json` holds each frame's rig joints and settings. |
| `walk_S.gif`, `walk_E.gif`, `walk_W.gif` | 12-frame loops on grey 172 at 60 ms per frame. W is the mirror of S. |
| `strip_{S,E}_target_f00_f03_f06_f09.png` | The approved target beside walk f00/f03/f06/f09, tiled from the shipped cells. |
| `legs_sheet.png`, `legs_sheet.json` | Lower body for the target and f00/f03/f06/f09 at the same figure height. The json has every number for all 12 frames, plus skate. |
| `side_by_side_f00_f06.png` | Target, f00 and f06, full figure, S and E. |
| `feet_S_far_boot.png`, `.json` | S feet zoom with the far-boot %, for reporting only. |
| `s_checks_{S,E}.json` | Per frame: crotch gap, shins cross, thigh angles, swing-thigh angle, far boot. |
| `metric_{S,E}.json` | Bastion metric output. |
| `s_track_options.png`, `s_track_sweep.json` | The S foot-track options Mauro picked from (foot_w 0.0–1.8, rigged), with Kestrel and Gloam for reference. |
| `parts/` | The cut layers: `leg_F`, `legfar_F`, `back_F`, `front_F`, `rig_F.json`. |
| `scripts/` | `mcut.py`, `mrig.py`, `mcfg.json`, `sheets.py`, `run_metric.py`, `boot_vis.py`, `s_checks.py`, `s_track.py`, `s_track_options.py`. |

The 4-direction clip (S, E, W, N, then a loop) was rendered outside the repo as `mender_all_movement.mp4`.

## Open issues (honest list)

1. **The far boot is hidden on some S frames: f10 9%, f03 28%, f01 and f02 about 58%.** This is the accepted cost of the narrow track.
   - f10: the R swing foot passes in front of the planted L boot.
   - f03: the L swing passes behind the R stance leg. The f03 key fixes the X, not the cover.
   - The robe hem covers the far boot's top on most frames.
2. **The robe is rigid.** The robe, sash tail, staff and lantern do not swing or lag, and the hem does not react to the knees. This is the same limit as the Gloam cloak and the Kestrel bow.
3. **One painted leg per side.** Each far leg is the same painting, 10% darker. Swing and toe-off boots are the painted contact boot rotated, not separately painted heel-up boots.
4. **E shins cross on f00, f01, f10 and f11.** The X gate is for S only.
5. **The S slit is a flat fill.** When neither leg is in the slit (f06, f07), it shows the dark robe inside: a smooth shaded fill with no painted folds.
6. **The E metric is sensitive to scale.** The metric's coarse fit swings E `ssim_upper` between 0.93 and 0.98 for scale changes of about 1% (look 84–88 for E s 0.360–0.370). s 0.368 was picked inside that range; it keeps every proportion within ±2.5%.
7. **E motion is 8.3.** The cause is the staff and head-top window described under Scores, not foot sliding. Real skate is ≤ 0.54 px.
8. **A few dark cell pixels in the E hem.** The removed back leg's trouser leaves a 5×2 px dark spot under the left hem tatters (E, target x≈560, y≈502), where it reads as hem shadow.
9. **Leg axis against the target.** The target's legs are posed wider than the narrow track. The walk's leg axis differs from the target's by up to +16° in S (back leg, f04) and +19° in E (f02). The legs follow the clay plants, and no axis rule was set for Mender.

## How to re-run

```
cd docs/pc/art_help/class_walk_looks/mender/v1_claude/scripts
python3 mcut.py            # parts/
python3 mrig.py --gif      # frames/ + walk_{S,E,W}.gif
python3 sheets.py          # legs_sheet, side_by_side, strips
python3 run_metric.py      # metric_{S,E}.json
python3 boot_vis.py S ../feet_S_far_boot.png
python3 s_checks.py S ../frames ../s_checks_S.json; python3 s_checks.py E ../frames ../s_checks_E.json
```

- **Blockout files.** These are extracted with `git archive` on the first run: S from `ca1a7c30` into `$MBLOCK_S` (default `/tmp/mender_blockout_v31`), and E from `ffbfe3a9` into `$MBLOCK_E` (default `/tmp/mender_blockout_v3`). Fetch `claude/class-walk-blockouts` first.
- **Dependencies.** numpy, pillow, opencv-python and scikit-image.
