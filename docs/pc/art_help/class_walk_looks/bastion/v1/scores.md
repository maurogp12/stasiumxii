# Bastion walk, painted HD (Step 2), v1: S and E

Method: hybrid rig in the Ironjaw v7 style, on Mauro's approved blockout joints (`bastion/joints_512.json`, clay = `bastion/clay`).
- **Upper body:** layers cut from the approved target (trunk, R pauldron, shield, cape; E also tassets). They ride the blockout pelvis/neck/shoulder deltas.
- **R arm:** one target piece (upper arm, forearm, fist and mace), driven by a shoulder + elbow two-bone IK toward the blockout mace head.
- **Head:** a painted helm facing the direction of travel (see below).
- **Belt, L arm (S), legs, knee cops and sabatons:** painted parts on the blockout joints, graded to the target palette.
- **House rules:** 512x360 cells, pivot (256,329), 12 frames at 17.144 fps, binary alpha, black under alpha 0.

## match_metric (`scripts/bastion_metric.py`; full output in `metric_S.json` / `metric_E.json`)

| facing | look | ssim_upper | ssim_lower | iou | palette | height_vs_idle | motion | bob_err | max sole err | PASS |
|---|---|---|---|---|---|---|---|---|---|---|
| S | **85.5** | .883 | .556 | .877 | .936 | 1.000 | **100** | 0.00 | 1.80 px | look + motion |
| E | **85.2** | .953 | .447 | .821 | .958 | 1.004 | **100** | 0.58 | 1.70 px | look + motion |

Acceptance (look >= 85, motion >= 95) is met on both facings, but the look margin is thin: +0.5 on S and +0.2 on E.

## qa_walk (`scripts/qa_walk.py`; full output in `qa_walk.json`)

**48/48 PASS.** S, E, and W/N, where W/N are `np.fliplr` mirrors of S/E so the shield swaps hands.

| facing | pass | skate (fully planted pairs) | pivot slide max | bob err max | hem clearance min |
|---|---|---|---|---|---|
| S / W | 12/12 | 0.67 px | 1.83 px (heel strike) | 0.00 | 19 px |
| E / N | 12/12 | 0.67 px | 3.93 px (R toe-off f11->f00) | 0.58 | 9 px |

**Skate:** 0 in the rig. The boot transforms move exactly with the ground on every fully planted pair (rig_err 0.00). The 0.67 px is the visible-sole centroid, which steps by whole rows.

**Each frame is checked for:**
- RGBA 512x360, binary alpha, black under alpha 0
- left/right/top margin >= 10
- one component
- no near-white edge, no green fringe
- saved PNG identical to the rig render
- each arm and leg >= 300 visible px
- mace head >= 50% visible
- skate <= 1 px
- |bob err| <= 1
- cape hem >= 8 px above the blockout support sole

**Documented differences from the Ironjaw qa:**
- **Bottom margin:** the rule is `bottom >= min(10, clay bottom margin - 2)`. The approved clay's own support sole sits 0-8 px from the cell bottom in S.
- **Bob:** must follow the clay (metric definition) instead of the Ironjaw 6-9 game-px range.
- **Edge chroma:** only green fringe is flagged. The deep-blue cape edge is art.

## Head direction (new rule)

**f00 and f06:**
- **S** faces **down-right**. It uses a painted 3/4-front helm with the visor on screen-right.
- **E** faces **up-right**. It uses a painted back-view helm whose crest ridge runs down to the back of the head on screen-left.

The helm is a fixed painting at the travel direction. Its tilt follows the blockout head_top-neck line. The crest stays on the target crest row, so bob and height are unchanged.

**Blockout chest yaw vs travel direction** (from the shoulder line, de-isometrized):
- S: +2.8, +2.4, +1.4, 0, -1.4, -2.4, -2.8, -2.4, -1.4, 0, +1.4, +2.4 deg
- E: -2.4, -1.4, 0, +1.4, +2.4, +2.8, +2.4, +1.4, 0, -1.4, -2.4, -2.8 deg

Head yaw (the travel direction) is therefore within ±2.8 deg of the chest yaw in every frame, inside the ±10 deg limit.

**Files** are named S/E directly, with no art-letter remap.

## Weak spots (honest)
- **Hybrid:**
  - The trunk, cape, pauldron, shield and R arm come from the approved target painting, warped on the blockout joints. They are not separately painted parts.
  - The look hold drops mid-cycle (upper SSIM vs a pelvis-following target: S .46-.88, E .53-.95).
- **Painted helms differ from the target helms.**
  - The approved target helms face roughly camera-frontal (S) and straight away (E), which breaks the new head rule.
  - The replacement helms are lower-detail, which costs about 3 look points on S (88.2 before the helm rule, 85.5 now).
  - The E helm is drawn at 0.21 of its painting, slightly narrower than the target helm, and the S helm sits about 3 px left of the target helm. Both were chosen by a small look search.
- **E trunk:** anchored at the pelvis, so the E head sits about 30 px left of the clay head.
- **E cape:** the lower panel is shortened per frame (`cape_low_k` 0.83-0.88, at most 0.015/frame change) so the hem clears the support sole by >= 9 px. The target cape is longer than the blockout allows.
- **E mace swing:**
  - The approved target holds the mace about 84 px lower than the blockout, and the target arm is almost straight, so the IK saturates.
  - At the full blockout swing the mace reached 3 px from the cell bottom.
  - `arm_gain` is 0.7, so the E mace travels about 66% of the blockout's mace-head displacement.
  - The mace still swings lower than the blockout's.
- **Sole calibration:** sub-3 px per-frame boot nudges (`boot_fix`) put the painted soles on the blockout soles.
  - Fully planted pairs stay at 0 slide.
  - Heel/toe pivot pairs slide: up to 1.8 px in S, and 2.1 px (f10->f11) and 3.9 px (f11->f00) on the E R toe-off.
- **Proportions:** legs and boots don't match the target exactly. The E greave is scaled up because the E shin is 62-66 px. ssim_lower is low (.45 E).

## Repaint requests (not done)
- **S/E helm at the travel yaw**, in the target's texture detail: S 3/4 front facing down-right, E back 3/4 facing up-right, about 36 px wide at cell scale. This would recover the look points the current helms cost.
- **E R arm + mace held higher and bent**, matching the blockout mace-head height (about 84 px higher than the target at f00), so the full swing fits.
- **Shorter E cape painting**, so the hem clears the soles without squashing.
- **Painted S mace piece:** the hold angle is wrong (head about -80 deg vs blockout +26 deg S / +39 deg E). The piece is unused; the target arm is used instead.

## Rebuild
From `scripts/`:
1. `python cut_target_layers.py`, then `python cut_target_layers_E.py`. Always run S first, then E.
2. `python build_hybrid.py --only S --out ../frames`
3. `python build_hybrid.py --only E --out ../frames`
4. `python previews_walk.py`
5. `python qa_walk.py ../frames ../qa_walk.json`

Settings live in `cfg_hybrid.json` (T = target-layer/helm/cape/boot_fix, C = rig, P = part overrides). Solvers: `boot_solve.py`, `fix_solve.py`, `fix_search.py`, `cape_k_solve.py`, `hem_check.py`.

Not done: action clips and commits (the repo is off-limits in this task).
