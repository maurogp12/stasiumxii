# Kestrel walk v3 (Claude): legs rework

This is the Kestrel 8-direction walk for S and E, 12 frames each. W and N are mirrors of these two.

It is built on Kestrel blockout v3.1 (commit `ec4beff`). Each leg is **one continuous painted leg**, cut from the approved target and running from the hip under the tunic, through the knee and the laced knee-high boot, to the sole. That leg is bent onto every frame's joints with smooth 3-bone mesh skinning. There is no cut anywhere between the hip and the sole: no knee seam, no boot-top seam, and no pasted pieces.

The upper body is the approved target itself. It is placed with one uniform scale and follows the blockout's pelvis and bob.

## Files

| file | what |
|---|---|
| `frames/kestrel_walk_{S,E}_f00..f11.png` | 512x360 RGBA cells, pivot (256,329), binary alpha, black under alpha 0. `_build_info.json` holds the rig joints per frame. |
| `walk_S.gif`, `walk_E.gif` | The 12-frame loops on grey 172, 60 ms per frame (the 10 ms GIF step closest to 17.144 fps). |
| `legs_sheet.png` | One row per facing: target, f00, f03, f06, f09. Every tile is scaled to the same figure height. Solid lines are this tile's belt (blue), knee (orange; knee = boot top) and sole (green). Dashed lines are the target's belt and knee at the same % of height. The numbers are printed under each tile. |
| `side_by_side_f00_f06.png` | Target, walk f00 and walk f06 as full figures at the same height, for S and E. |
| `legs_sheet.json` | Every number for all 12 frames, plus skate for each planted heel and toe. |
| `metric_S.json`, `metric_E.json` | Bastion metric (`bastion/v2/scripts/bastion_metric.py`, unchanged) against the v3.1 clay. |
| `parts/` | The cut layers (output of `kcut.py`): `leg_F`, `legfar_F`, `back_F`, `front_F`, and `rig_F.json`. |
| `feet_S_far_boot.png`, `.json` | All 12 S frames zoomed on the feet, with the far boot's visible % and the gap between the boots. |
| `scripts/` | `kcut.py` (cut), `krig.py` (rig and render), `sheets.py` (sheet, side-by-side and numbers), `run_metric.py` (scores), `boot_vis.py` (far-boot visibility), `kcfg.json` (S boots fix). |

## Method

### 1. Cut (`kcut.py`, target px)

- **The source leg.** One fully visible painted leg is used per facing:
  - S: the screen-right forward leg.
  - E: the screen-left near leg, seen from behind.

  The thigh top is hidden by the tunic in the painting. It is grown upward by mirroring the visible thigh about its top line, which keeps the painted grain. It then fades into the under-tunic shadow colour, so a thigh top never shows as a flat edge. Cloak green and the bow are painted out of the leg using the leg's own browns.
- **`legfar_F`.** This is the same leg with the S thigh strap and buckle painted out, so the figure has one strap and not two.
- **`back_F`.** This is the target minus both legs. The area the legs covered is filled with the target's dark under-tunic and cape-interior colour, down to an irregular tatter line under the hem. A 22 px shadow band blends the painted thigh tops into that fill. The result has no grey boxes and no holes at the crotch.
- **`front_F`.** These are the parts that hang in front of the legs:
  - S: belt, pouches, tunic and the hem flaps, plus the bow limb and string.
  - E: the whole cape, tunic and bow.

  The approved E alpha drops pieces of the upper bow limb and string, so those bow-coloured pixels are re-added inside thin bands.

### 2. Rig (`krig.py`)

- **Body.** The scale is s = 253/686 for S and 247/665 for E. x is on the blockout hip centre. The hood top sits on the clay's own head-top row, so the bob is exactly the blockout's and the painted torso and leg proportions are kept.
- **Hips.** The legs hang from the target's painted hip centre ± half the blockout hip vector. This is the "target belt hips" rule, so the hip offset is 0 px.
- **Foot.**
  - The boot is laid on the blockout heel and toe joints: rotated, scaled by s across, and scaled by s·kf along, where kf is the iso foot foreshortening clipped to 0.88–1.12.
  - Pinned point: the heel while the heel is planted, the toe at toe-off, the middle in swing. Planted contact points therefore move exactly with the ground.
  - A constant `foot_o` offset puts the sole on the clay's sole row.
- **Knee.**
  - The knee comes from 2-bone IK at the target thigh and boot lengths, bending to the side of the blockout knee.
  - Planted legs aim for straight. The along-bone k follows the iso foreshortening, within 0.90–1.10 (E-ALT ruling).
  - Swing legs aim for the blockout's knee bend minus its ~20° rest bend, with k between 0.85 and 1.10, as a depth bend. The knee folds toward the viewer instead of the leg swinging out sideways.
  - Nothing is ever scaled across the bone, so the thigh and boot widths stay at the target ratio.
- **Skin.**
  - The painted leg is a triangle mesh on a 4 px grid.
  - It is deformed by linear-blend skinning of three affine bones: thigh, shin and foot.
  - The weights are smoothstep blends across the knee bisector (±24 px) and the ankle line (±14 px).
  - Each triangle is rasterised to a source-coordinate map, and the painting is resampled from it. All the painted shading is kept.
  - Near and far follow the blockout ID maps (the `draw_order` is listed front to back). The far leg is 10% darker, eased over ±1 frame so a near/far swap never pops.
- **Output.** Each frame is rendered at 3x the cell and area-downsampled to 512x360, then the alpha is binarised.

## How to re-run

```
cd docs/pc/art_help/class_walk_looks/kestrel/v3_claude/scripts
python3 kcut.py            # parts/ (about 1 min)
python3 krig.py --gif      # frames/ + walk_{S,E}.gif
python3 sheets.py          # legs_sheet.png, side_by_side_f00_f06.png, legs_sheet.json
python3 run_metric.py      # metric_{S,E}.json
```

- **Dependencies:** numpy, pillow, opencv-python and scikit-image (the system python3 has all four).
- **Blockout files.** The blockout v3.1 joints and clay are read from `/tmp/kestrel_blockout_v31` (override with `KBLOCK`). On the first run they are extracted from commit `ec4beff` with `git archive`, so fetch `claude/class-walk-blockouts` first.
- **S target alpha.** `run_metric.py` passes the metric a binary L copy of each target alpha. The S alpha file is an RGBA cut-out, and the metric's `.convert('L')` would otherwise read the painting instead of the mask.
- **Overrides.** Per-facing settings can be overridden in `scripts/kcfg.json`, using the same keys as `krig.CFG`.

## Checks (all 12 frames are in `legs_sheet.json`; the sheet frames are below)

Target S: thigh/shoulder 0.372, boot/shoulder 0.264, belt→sole 61.4% of H, knee line 73.3%. Leg axis: fwd +10.7°, back −2.4°.
Target E: thigh/shoulder 0.353, boot/shoulder 0.339, belt→sole 55.0%, knee line 74.1%. Leg axis: fwd +6.5°, back −13.2°.

| frame | thigh/sh (dev) | boot/sh (dev) | belt→sole (vs tgt) | knee line (vs tgt) | stance bend, k | axis R / L (dev vs the target leg with the same role) |
|---|---|---|---|---|---|---|
| S f00 | −0.4 / −0.4% | +1.0 / +2.0% | 62.5% (+1.1) | 74.2% (+0.9) | 7°, 0.97 | +12.8 fwd (+2.1) / +1.4 back (+3.8) |
| S f03 | +0.9 / −0.4% | +2.0 / +0.6% | 62.3% (+0.9) | 73.9% (+0.6) | 7°, 0.93 | +5.5 back (+7.9) / +5.1 fwd (−5.6) |
| S f06 | +0.9 / +0.9% | +3.4 / +0.6% | 59.7% (−1.6) | 76.5% (+3.2) | 7°, 1.01 | −5.9 back (−3.5) / +18.1 fwd (+7.4) |
| S f09 | +0.6 / +0.6% | +1.0 / +1.0% | 59.7% (−1.6) | 75.9% (+2.6) | 7°, 0.97 | −4.9 back (−2.5) / +9.0 fwd (−1.7) |
| E f00 | −0.1 / +1.7% | +0.3 / −1.1% | 56.3% (+1.2) | 74.7% (+0.5) | 7°, 1.00 | −8.7 back (+4.5) / +8.5 fwd (+2.0) |
| E f03 | +1.2 / +1.2% | +1.3 / −0.7% | 53.3% (−1.8) | 74.3% (+0.1) | 7°, 1.00 | +8.3 fwd (+1.8) / −6.0 back (+7.2) |
| E f06 | +0.3 / +0.8% | −0.2 / +0.3% | 53.5% (−1.6) | 76.3% (+2.1) | 7°, 0.91 | +14.2 fwd (+7.7) / −17.9 back (−4.7) |
| E f09 | −0.6 / +0.3% | +0.3 / −0.2% | 56.3% (+1.2) | 75.2% (+1.1) | 7°, 1.03 | −1.2 fwd (−7.7) / −3.0 back (+10.2; swing leg, 60° blockout bend) |

How the full cycle sits against each rule:

- **Thigh/shoulder:** within ±2.2% in every frame (the rule is ±8%).
- **Boot/shoulder:** within ±2.4%.
- **Belt→sole:** within −2.3 to +2.5 points (the rule is ±5%).
- **Knee line:** within −1.6 to +2.4 points.
- **Hip offset:** 0 px. The rule's hips are 7–9 px from the painted hip points (more on S since the boots fix, which uses `hip_w` 1.6), because the blockout's hip vector is wider and tilted.
- **Stance legs:** 7° knee bend with k between 0.90 and 1.06. The painted target bend is 4–5°. A planted leg bends more only where the clay leg is shorter than 0.90 of the target leg: S f04 (14°), S f05 (40°, toe-off), S f11 (30°, toe-off) and E f05 (29°, heel strike).

Leg axis against the same-role target leg:

- **S:** every planted leg is within 8.0° (the rule is ±8°). Swing legs reach −10.0° at f08 R and +14.2° at f11 R.
- **E:** f04 R (+11.9°) and f05 R (+12.9°, contact) and the swing L at f02 and f09 (+11.9°, +10.2°) are outside ±8°. The blockout's E stride puts the two feet about 80 px apart in x around contact. With the hips at the target belt and the feet on the clay plants, the angle is fixed by geometry. Moving the plants would skate the feet. I swept the hip width from 0.8 to 1.6 and 1.0 is the best setting.

**Skate.** Planted heels and toes move with the ground to within 0.57 px in every consecutive planted pair, for S and E (`legs_sheet.json` → `skate`).

## Scores (Bastion metric on the v3.1 clay)

| | look | ssim upper / lower | iou | palette | height vs idle | bob err | motion | sole_err per frame (px) |
|---|---|---|---|---|---|---|---|---|
| S | **89.1** (PASS) | 0.987 / 0.653 | 0.831 | 0.972 | 1.013 | 0 | 0.0 (feet deliberately off the clay plants, see S boots fix) | 10.69 8.10 5.16 5.41 5.63 5.29 5.34 9.94 10.61 10.50 4.26 6.03 |
| E | **86.5** (PASS) | 0.977 / 0.635 | 0.785 | 0.941 | 1.017 | 0 | 41.7 | 5.56 2.11 5.64 2.73 2.41 8.13 1.09 1.81 1.49 1.89 1.68 4.76 |

The motion score fails only because of the metric's sole point, the mean x of the lowest three rows of the support boot:

- In flat-foot frames the error is ≤ 0.7 px (S) and ≤ 2 px (E).
- In heel-strike and toe-off frames the lowest point of the painted boot is its heel corner or its toe. That point sits 3–8 px from the clay box's corner. A per-frame shift to chase this number would make the planted heel slide by the same amount, so I left it.

The real skate, measured on the planted points, is ≤ 0.57 px.

## S boots fix (after Mauro's review: "when walking west / south the boots disappear")

In the first version the far boot hid straight behind the near leg in S f00–f02 and f11 (44–47 % visible). W mirrors S, so W had the same problem.

S-only settings in `scripts/kcfg.json` (E is unchanged):
- `foot_lat`: a constant lateral offset of each foot track, L +10 px and R −6 px in x. It is constant over the whole cycle, so a planted foot still moves exactly with the ground (skate ≤ 0.57 px, unchanged).
- `hip_w` 1.6: the hips spread with the feet, so the legs stay upright. Every planted S leg is still within 8.0° of the same-role target axis.
- `fill_line`: the S fill behind the legs now ends in a smooth crotch arch, not tatters, so the wider gap between the thighs reads as the legs and not as a grey sawtooth.

Results:
- `feet_S_far_boot.png` / `.json` (made by `scripts/boot_vis.py S feet_S_far_boot.png`) show the far boot from boot top to toe, rendered alone. Its visible share is the part not covered by the near leg or by the belt and bow layer.
- Visible share by frame: S f00 76 %, f01 72 %, f02 78 %, f03 84 %, f04 95 %, f05–f08 100 %, f09 100 %, f10 99 %, f11 92 %. The minimum is 72 % against the 60 % target.
- The boots are apart by 4–42 px in f03–f10. They overlap in f00–f02 and f11, where the far boot is 10 % darker so the edge between them stays visible.
- Thigh/shoulder, boot/shoulder, belt→sole and knee line stay inside their rules (see `legs_sheet.json`).
- The Bastion metric's motion score for S drops to 0, with a sole error of 4–11 px. The metric compares the sole point against the clay plants, and the S feet now sit deliberately off those plants. Look rises to 89.1.
- E was not re-rendered. Its far boot is still hidden behind the near leg in f00 (28 %), f10 (37 %) and f11 (23 %). It is left that way because Mauro approved E.

## Known flaws (honest list)

- **Arm swing and cape lag are not done.** The upper body is the rigid approved painting moving with the pelvis. The arms do not swing ±20° and the cape and hem do not lag. Legs were the priority.
- **One source leg per side.** Both legs come from the target's one fully visible leg; the far copy has the strap removed and is 10% darker. The target's other leg is mostly hidden by the near thigh and the bow, so it could not be used as a second pose source. In toe-off and swing, the boot is the painted contact boot rotated, not a separately painted heel-up boot.
- **E leg axis.** E contact and passing frames lean more sideways than the target, up to 13° off it (see above). Fixing this needs a narrower E stride in the blockout.
- **Crossing legs.** E f00/f01 show the legs crossing at the ankles in screen space, as the v3.1 plants do, and the E far boot is mostly hidden in f00, f10 and f11. Depth order follows the blockout ID maps, so it reads as one leg behind the other, but it is busy at sprite size. The S boots fix (above) separated the S boots.
- **Small artefacts.** A small hem tatter painted on the E thigh moves with the leg. The thin E bow string breaks into dots at cell scale, as it does on the approved target at that scale.
