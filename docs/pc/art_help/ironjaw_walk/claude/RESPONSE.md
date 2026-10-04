# Ironjaw walk: answer to Scenario Art (from Claude)

Reply to `docs/pc/art_help/ironjaw_walk/BRIEF.md` and draft PR #252. Docs and scripts only, no game files. Art changes still go back through Scenario Art and Technical Artist, and this branch merges nowhere.

Everything here runs from the repo root and needs numpy, pillow, opencv-python and scikit-image.

- `scripts/match_metric.py`: the 85% metric (look against the repaint, motion against v2).
- `scripts/rig_fx.py`: the rig fixes. Seamless arm swing, cape sway, leg lengthening with the feet pinned, Lab grade.
- `scripts/proto.py` and `proto_frames/`: a prototype that puts the HD upper body on v2's legs, with arm swing and cape sway. It is a test bed for the fixes, not a candidate walk.
- `media/proto_vs_v2.gif`: v2 next to the prototype, S and E, at 17.144 fps.
- `media/proto_contact.png`: every second frame.
- `media/metric_*`: the metric reports, plus f00 check images (candidate | fitted target | difference).
- `media/boots.png`: the repaint's boots next to v2's (see 1b).

## 1. Pipeline verdict: keep the hybrid rig (v4)

**a. Upper body.** Cut it once from the repaint as layers: cape, far arm, body, near arm. The look is already in those pixels. My cut gets read-scale SSIM 0.98 (S) and 0.85 (E) on the upper body at f00, which matches your v3 numbers.

**b. Legs.** Use newly painted thigh, greave and boot parts driven by v2's leg transforms, as v4 is doing. Two reasons not to warp the repaint's legs per frame:
- **The repaint's feet point the wrong way for the travel.** The walk scrolls (−12, −6) per frame on S, so Ironjaw travels down-right and the toes must point down-right, as v2's do. The S repaint's near boot points down-left. On E the travel is up-right, but the repaint shows both heels straight on. Legs warped from those frames would moonwalk. See `media/boots.png`.
- **One painted frame can't supply the hidden parts.** Leg overlap changes through the cycle, so the back of the far leg is visible in frames where the repaint has no pixels for it.

**c. Keyframe repaints plus in-betweens.** No. That is what drifted five times.

**d. One leg painted, used twice.** If time is short, paint one HD leg set per facing and use it for both legs, with the far leg darkened about 10%. Nothing is hidden behind the other leg, so nothing is missing.

## 2. Size reference: the idle set, not the repaint

The approved idle/attack/hit/death set is what the game shows next to the walk. All four idle facings are 265 px from head top to sole, with the head top at row 64 and the sole at 329.

- **The repaint's legs are longer than the idle's.** With the repaint's upper body scaled to the idle's (×0.435 S, ×0.447 E), its soles land about 36 px below the pivot. Matching the repaint's leg length would make Ironjaw grow when he goes from idle to walk.
- **The HD upper body is bigger than v2's.** On v2's pelvis it leaves the S legs short. That is your "~11% short", and raising the S pelvis 13 px (legs about +11%) brings the passing frame to 1.015× idle height.
- **E does not need the raise.** It is already at 1.04× idle without it. Ask TA why the facings differ: `joints_512.json` meta has y offsets of 15 for S and 31 for E.
- **Do the raise in Blender, not in 2D.** TA lengthens the thigh and shin bones with the feet IK-pinned to the same world targets and re-exports. Stride, phase, plants and bob stay identical by construction. `rig_fx.axis_stretch` is the 2D fallback: the leg stretches only along the hip–ankle axis, so it gets longer without getting thicker, and the boot is untouched.

**"Chunky" is a width problem.** v2's legs are about 65% as wide as the HD body needs (see the prototype's S f06), so the new legs have to be painted at HD width. Stretching can't fix that.

## 3. The metric (`scripts/match_metric.py`)

```
python3 docs/pc/art_help/ironjaw_walk/claude/scripts/match_metric.py --facing S \
  --cand <frames dir> --v2 docs/pc/art_help/ironjaw_walk/walk_v2_frames \
  --target docs/pc/art_help/ironjaw_walk/repaint_targets/rp_S_f00_t1.jpg \
  --idle docs/pc/art_help/ironjaw_walk/hd_set_idle/ironjaw_idle_S_f00.png \
  --joints docs/pc/art_help/ironjaw_walk/ta_joints/joints_512.json --out report.json --png check.png
```

**Look (f00).** The repaint is the f00 pose. It is alpha-cut from its grey background and fitted into the cell (scale and translation that best overlap the candidate's upper body).

| Measure | Weight | What it is |
|---|---|---|
| `ssim_upper` | 0.35 | Read-scale SSIM (blur 1.2 px, half size) above the pelvis line. Pixel noise doesn't count; form and value do. |
| `ssim_lower` | 0.15 | Same, below the pelvis line. Low weight because the repaint's stride and feet are wrong for the walk. |
| `iou` | 0.20 | Full silhouette IoU. |
| `palette` | 0.20 | 1 − mean CIEDE2000/15 over the steel, cape and bone medians. |
| `height_vs_idle` | 0.10 | Tallest walk frame against the idle height. |

`look_score` = 100 × the weighted sum. `look_hold_upper` gives the same upper SSIM for every frame, with the target moved by the pelvis. Swing costs about 0.1–0.3; a single frame well below its neighbours is a tear, seam or cape break.

**Motion (every frame, against v2).**
- `bob_err`: head-top bob against v2's bob, means removed.
- `sole_err`: support-boot sole point (crimson ignored) against v2's.
- `motion_score`: share of frames with sole within 2 px and bob within 1 px.
- A dark cape hem or an axe head below the boots counts as an error on purpose: it means the hem is dragging on the ground.
- Skate is not measured again. v2 has skate 0, so a sole that matches v2 every frame can't skate. `qa_walk.py` stays the authority for skate, margins and halo.

**Pass.** Look passes at `look_score` ≥ 85 with `ssim_upper` ≥ 0.85 and `palette` ≥ 0.85. Motion passes at `motion_score` ≥ 95.

**Baselines.**

| Frames | Facing | Look | ssim_upper | Palette | height_vs_idle | Motion |
|---|---|---|---|---|---|---|
| v2 | S | 42.0 | 0.05 | 0.86 | 0.99 | 100 |
| v2 | E | 45.4 | 0.23 | 0.82 | 1.01 | 100 |
| prototype | S | 86.7 | 0.98 | 0.98 | 1.02 | 58 (cape tips at the boots, f02 and f05–f08) |
| prototype | E | 75.4 | 0.85 | 0.99 | 1.04 | 92 (far axe at boot height, f06) |
| repaint vs itself (`--selftest`) | S | 98.5 | 1.00 | 1.00 | | |

Our SSIMs are computed differently, so please run v3 and v4 through this one script so both teams read the same number. Don't compare my figures with your 0.73 and 0.71.

## 4. Rig fixes (`scripts/rig_fx.py`)

All of these warp backward (`cv2.remap`), so they can't tear or leave holes.

**Arm swing without a seam (`lbs_swing`).**
- The transform weight ramps from 0 at the pauldron (r < r0) to 1 at the forearm, fist and axe (r > r1). The arm stays welded to the shoulder and bends through the upper arm instead of pivoting as a rigid cutout.
- Cut forearm, fist and axe as one piece, as NOTES says. Remove crimson from the arm cut so the cape doesn't move with the arm.
- **Front 3/4 (S):** use in-plane rotation. Take the timing from TA's shoulder→grip angle, scaled to Luca's ±15°. The repaint is the f00 pose, so f00 = 0°.
- **Back 3/4 (E): don't rotate in plane.** In-plane rotation flings the axes sideways, which was Luca's v1 complaint; I reproduced it. Use about 25% of the rotation plus foreshortening along shoulder→fist (`stretch`, about ±6% at the peak), so the fists bob forward and back.

**Cape sway (`cape_sway`).**
- The offset is 0 at the collar and grows as t^1.6 down to the hem.
- It lags the pelvis by one to two frames. I used 7–8 px at the hem in repaint space, about 3 px in the cell.
- A small travelling ripple runs on the ragged hem, and the hem lifts with the bob.
- The cape mask must include the dark strand tips. Close the crimson mask with 9×9 and take everything below the waist that is neither leg nor arm; otherwise the tips stay in the body layer and break off.

**Hip seam.**
- Keep the repaint's belt, tassets and loincloth on the body layer, drawn above the legs.
- End the leg cut 40–50 repaint px (about 20 cell px) below the belt, so the HD thigh tops stay part of the body.
- Paint the new thigh parts to run about 8 px above the hip joint, under the belt.
- At contact (f00/f06), the loincloth or a dark inner-thigh piece must fill the crotch. The prototype S f06 shows grey background between the thighs.

**Old paint into the HD palette (`lab_match`).** Reinhard mean/std transfer in Lab, for any leftover v2 pieces. Not needed once v4 legs are painted.

## 5. Punch list

**S (front 3/4; W is the mirror)**
- **All frames:** raise the pelvis 12–13 px (legs about +11%) through a TA re-export, so the passing frame reaches idle height.
- **All frames:** paint new legs at HD width and texture, boots toe down-right (the travel direction). Don't copy the repaint's down-left boots.
- **f02 and f05–f08:** cape tips hang to sole level (sole_err 5–19 px). Shorten or lift the hem so it clears the support sole by at least 8 px.
- **f00 and f06 (contact):** the wide stride opens a gap under the loincloth. Extend the loincloth, or add an inner-thigh piece.
- **f03–f08:** the near axe moves forward over the near thigh and knee (also visible in your v3 S f06). Keep the axe head outside the thigh silhouette, either by capping forward swing at +12° or by moving the fist out about 6 px.
- **All frames:** the HD far pauldron and axe sit behind the cape edge. Check the draw order against TA's `draw_order` per frame. My prototype draws the far arm under the legs on S; the HD parts need the same.

**E (back 3/4; N is the mirror)**
- **All frames:** swing as foreshortening, not rotation (see 4).
- **f05–f07:** at full forward reach the far axe head reaches boot height. Cap `stretch` so the axe head stays at least 10 px above the soles.
- **All frames:** the cape is the main read from the back. v3 E keeps it static; it needs about 3 cell px of sway at the hem with a one-frame lag.
- **All frames:** paint boots back 3/4 with the toes up-right (`parts_fix1` E and F). The repaint's straight-on heels are wrong for the travel.
- **All frames:** no raise needed (1.04× idle already). Confirm with TA why S and E are offset differently.
- **v3 E:** the thighs are thin under the wide HD shoulders. That is the same width fix as S.

**Both facings: the order that gets to 85%**
1. TA re-exports the joints with the leg bones lengthened and the feet pinned. `qa_walk.py` must still report 48/48, skate 0.
2. Paint the HD legs: thigh, greave, boot per facing, boots pointing in the travel direction, 8 px of overlap under the belt.
3. Cut the upper body from the repaint as layers: cape with tips, arms with forearm, fist and axe as one piece, body with belt and loincloth on top.
4. Swing with `lbs_swing` (S rotation, E foreshortening) and sway with `cape_sway`.
5. Run `match_metric.py` and `qa_walk.py` on S and E. Show Luca only when look ≥ 85 and motion ≥ 95 on both facings.
