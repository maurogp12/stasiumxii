# Bastion walk v3: target-scale legs rooted at the target hips, plus the S swing-foot fix

Built 10:02-10:25 AM ET, Oct 4 2026, from a copy of v2. The rig, the blockout (`bastion/blockout_v2/`), the trunk, the helms, the cape, the
arms and the E mace/toe fixes are the same as in v2. Only the legs, the S tabard length and the S swing foot changed. Nothing was committed or pushed.

## Scores

| facing | look | ssim_upper | ssim_lower | iou | palette | height | motion | bob_err | max sole err | qa |
|---|---|---|---|---|---|---|---|---|---|---|
| S | **87.1** (v2 87.2) | .897 | .589 | .877 | .968 | 1.000 | **100** | 0.92 | 1.91 px (v2 1.91) | 12/12 |
| E | **88.7** (v2 88.0) | .954 | .642 | .840 | .964 | 1.004 | **100** | 0.75 | 1.86 px (v2 1.26) | 12/12 |
| W (S mirror) | - | | | | | | | | | 12/12 |
| N (E mirror) | - | | | | | | | | | 12/12 |

**qa_walk: 48/48.**
- Skate max: S 0.23 px, E 0.88 px. Pivot slide max: S 1.46 px (L heel strike f06->f07), E 0.49 px. Both unchanged from v2.
- E right toe pin (f10->f11->f00): 0.41 px and 0.49 px, unchanged.
- Hem clearance: S 42 px, E 18 px.
- Per-frame sole errors are identical to v2 on S. E's worst frame went from 1.26 to 1.86 px (f01) because the sabaton is smaller, but it is still under the 2 px limit.

## 1. Leg size: every leg piece at the trunk scale (`leg_ratio_v3.json`, `legs_v2_v3_{S,E}.png`)

- **Cause in v2:** the target-cut greave, knee cop and sabaton were already at s_up across the bone. Two pieces were oversized:
  - The painted thigh keys (fwd/back) were 17-23% wider than the target thigh.
  - The E sabaton had a uniform x1.15 scale.
  - Also, the per-bone scale `k` (0.9-1.1 along) was set from the blockout bone length.
- **v3:**
  - Every leg piece is a target-cut piece (thigh, knee cop, greave, sabaton) at s_up. The painted fwd/back thigh keys are no longer used: the one target thigh is rotated to the bone.
  - Across the bone the scale is always s_up. Along the bone it is s_up x k, with 1 <= k <= 1.1. Stretch is used only when the foot-plant target is out of reach.
  - E sabaton: tk 1.0 (across = s_up), plus x1.1 along the foot only (`tka`).

| check (limit: greave/shoulder within 8% of target) | target | v2 f00 | v2 f06 | v3 f00 | v3 f06 |
|---|---|---|---|---|---|
| S greave/shoulder | .2025 | .2020 (-0.2%) | .2066 (+2.0%) | **.2032 (+0.3%)** | **.2072 (+2.3%)** |
| E greave/shoulder | .2111 | .2116 (+0.2%) | .2096 (-0.7%) | **.2120 (+0.4%)** | **.2101 (-0.5%)** |
| S thigh width vs target (R / L) | | +18.0% / +0.4% | +2.1% / +20.6% | -0.4% / +0.5% | +2.0% / +2.2% |
| E thigh width vs target (R / L) | | -0.1% / +22.9% | +22.6% / +17.5% | -1.0% / +0.2% | -1.3% / -0.5% |
| E sabaton linear size vs target | | 1.15 | 1.15 | 1.05 (1.1 along, 1.0 across) | 1.05 |

How these are measured:
- Greave width: the posed greave piece, perpendicular to its axis, averaged over 40-60% of its length.
- Shoulder width: the widest row of the trunk + near-pauldron target layers.
- The target values are measured the same way on the target pieces.
- Max along-bone stretch used: S 1.086, E 1.10.

## 2. Leg rooting: hips at the target's own hip points

- Each hip is a target point under the belt. It is mapped like the f00 trunk layer and moved by the per-frame blockout pelvis delta.
- The blockout gives only:
  - the knee bend side (rotation);
  - the foot-plant targets (ankle, plus heel/toe for the sabaton, same anchoring code as v2).
- The knee comes from 2-bone IK with the target thigh and greave lengths.
- Target belt corners (target px): S (642,300)-(762,300); E (614,305)-(722,305).
- Hips:
  - S: (650,300) and (754,300), inset 8 target px from the corners.
  - E: (638,305) and (698,305). (698,305) is the target's own far-leg thigh axis. The other hip is mirrored about the belt centre.

| hip midpoint - target belt centre (limit 4 px) | v2 f00 | v2 f06 | v3 f00 | v3 f06 |
|---|---|---|---|---|
| S | 1.44 px | 1.44 px | **0.00 px** | **0.00 px** |
| E | 9.16 px (9 px low) | 9.16 px | **0.01 px** | **0.01 px** |

- Thighs start at the belt bottom row, under the belt/tabard (S) and the tassets (E).
- **E reach:** the blockout E legs are longer than the target legs measured from the target hip.
  - The far (R) leg needs more than 10% stretch in f01, f09 and f10, so it stops at 1.1.
  - The greave then ends short of the ankle by 8.9 px (f01), 1.9 px (f09), 2.3 px (f10) and 0.1 px (f08). The sabaton shaft covers the gap; no seam is visible.
  - The feet stay exactly on the plants, which keeps motion at 100.

**S tabard (`belt_k` 0.9):**
- With the target hips, the S knees ride about 10 px higher than on the blockout hips, and the painted tabard covered up to half of the R knee cop (f06/f07).
- The painted tabard is shortened to 0.9 along its hang axis.
- Knee cop visible: R 70-94%, L 57-79% (v2: R 87-92%, L 31-70%).
- E knee cops: R 62-100%. L (the near leg) is 0-15% in f02-f08: it is now under the cape, as in the target. 40-100% in the other frames.

## 3. S swing foot (L leg, f03-f07; `swing_fix_S.png`, `swing_drop_S.json`)

Sabaton (heel, toe, whole boot) drop vs v2 in px, with the ankle IK target lowered by the same amount and the knee re-solved:

| f03 | f04 | f05 | f06 | f07 |
|---|---|---|---|---|
| +3.5 (ease in) | **+7.0** | **+6.5** | 0 | 0 |

- Swing heel height above the ground line (v2 -> v3): f03 16.1->12.6, f04 14.2->7.2, f05 7.4->0.9, f06 -0.4 (contact).
- **f06 is not lowered.** It is the heel-strike contact: the L heel is planted f06->f07, and the motion metric uses the L foot as the support foot at f06 and f07.
  - The sabaton's lowest point there (the toe side) is already within 1.91 px of the clay sole.
  - Every px of drop or toe-down rotation moves that sole point: -4 deg gives 2.7 px, -8 deg gives 4.7 px. A 6-8 px drop fails f06, so motion would be 91.7 (11/12).
  - So f06 and f07 match v2, and f05 is the last lowered frame.
  - The f06 toe stays up at heel strike (the clay's pose).

## Kept from v2

- Helms, trunk scale and phase (0.2, 0.75), gold lift, cape.
- E tassets at 0.7, E mace low (gain 1), E toe pin rotations.
- Boot nudges (`boot_fix`) and all other frames' foot plants.

## Weak spots

1. **S look margin:** 87.1, with the 87 limit. The metric's f00 fit lattice is sensitive to the leg silhouette: hips 4 px further out or in move look by ±1-2. The chosen hips and tabard length are the best tested setting that also keeps the knees visible.
2. **S R knee cop:** 70% visible at f06/f07 (v2 87%), because the bent trailing knee rises toward the tabard.
3. **E R leg:** at the 1.1 stretch cap in f01 and f08-f10. Covered by the sabaton, but the far leg reads slightly short at f01.
4. **Single thigh piece:** the fwd/back thigh keys are replaced by the target thigh rotated to the bone. They don't have their own foreshortened drawing (repaint request 2 still stands).
5. legs_check: S f06's straight leg is 91% of the target leg length (v2 102%), because the leg is now the target length from the target hip.
6. The v2 repaint requests (E mace raised, far-leg pieces, helms at travel yaw) still apply.

## Files
- `frames/bastion_walk_{S,E}_f00-f11.png` (512x360, pivot (256,329), binary alpha), `frames/_build_info.json` (per-frame hips, knees, stretch, reach shortfall)
- `walk_S.gif`, `walk_E.gif` (17.144 fps), `compare_f00_f06_vs_target.png`
- `legs_v2_v3_S.png`, `legs_v2_v3_E.png`, `leg_ratio_v2.json`, `leg_ratio_v3.json`, `legs_check.png` / `.json`
- `swing_fix_S.png` (rows: v2 / v3 rig without the swing drop / v3; f03-f07), `swing_drop_S.json`
- `metric_{S,E}.json`, `qa_walk.json`
- `scripts/`:
  - `build_hybrid.py`: new `legs_v3()` and `belt_k`.
  - `cfg_hybrid.json`: `leg_v3`, `swing`, `belt_k`, E boot `tk`/`tka`.
  - New scripts: `leg_ratio.py`, `legs_v2_v3.py`, `swing_strip.py`.
  - `legs_check.py`: now uses the v3 hips.
