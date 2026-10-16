# Bastion full sprite set: v4 (PREVIEW ONLY, no git)

These top-level files were regenerated on Oct 3 2026, ~19:38 ET, after the 19:26 restart. They are built from the v4 frames that survived on disk, using the scripts in `work/`. v1, v2 and v3 are untouched.

## Fix pass 5 (Oct 3 2026, ~20:10 ET): E/N swing thigh/shin foreshortening (W kept as fix 4)
In a back view walking up-right, a forward-swinging thigh points away from the camera, so on screen it gets shorter instead of swinging out to horizontal (as in Ironjaw v2).
- `walk4.Walk4(..., fore=(thigh_min, shin_min, thigh_screen_max, knee_cap))`, E/N swing frames only. A screen 2-bone solve reaches the same ankle target (world lift plus screen extra lift) with bone lengths scaled along the bone, width kept (`rig2.limb_M`): s = lerp(base, min, |bone angle|/60 (thigh) or /45 (shin) * sin(pi*min(1,1.25u))^0.6). Constraints: thigh screen angle <= thigh_screen_max, knee 0..knee_cap, shin >= -30. Cost: below-target height x4, along-track error, small thigh-forward and knee-bend penalties. The fix 4 knee-cap path is off for E/N (kmax 0).
- E/N params: [0.062, 0.08, 0.05, -3.8, 0, 0.3, [0.62, 0.75, 65, 70]]. W unchanged: [0.072, 0.08, 0.03, -2.2, 62].
- Results (qa.json):
  - E: clearance near 11.5/18.5/18/12.5, far 10.5/17/15/10.5, min 10.5 px; swing thigh screen peak 65 deg (was ~91); knee peak 70; swing thigh 0.621-0.777x, swing shin 0.75-1.077x.
  - N: near 10.5/16.5/15.5/11, far 14.5/20/19/10.5, min 10.5 px; thigh peak 65 (was ~94); knee 70; thigh 0.621-0.777x, shin 0.75-1.066x.
  - W: 12.0 px, thigh 58, knee 62 (unchanged).
- Swing shin min: E -17.5, N -18.0. Unchanged: heel strike, toe-off, 0 px slide, travel 115, drops. Stance frames f00, f01, f06 and f07 and all W frames are pixel-identical to pre-fix5. E f00-f01 far-leg lightening was re-applied.
- Overall screen leg-length range is now thigh 0.62-1.23x and shin 0.75-1.23x (stance frames still use the 0.80-1.23 clamp).
- Known: at toe-off the thigh drops from 1.19x (stance f07, untouched) to 0.68x (swing f08), mostly hidden by the cape.
- Backup: `work/backup_pre_fix5/`. Check images: `work/chk_fix5_EN_old_new_1x.png`, `work/chk_fix5_EN_old_new_0.6x.png`, `work/chk_fix5_06.png`.

## Fix pass 4 (Oct 3 2026, ~20:00 ET): soften the swing lift (no deep knee fold)
Reason: E f08-f11 read as a high march knee. Goal: drawn swing-foot clearance min 10-14 px, swing knee peak <= ~70 deg (ideally 55-70).
- `walk4.Walk4(..., kmax, lpow)`: new screen knee cap `kmax`. If the swing knee would bend more than `kmax`, the thigh rotates forward and the shin hangs (shin >= -30 deg) at the same ankle height above the floor track. New `lpow` flattens the world lift arc (`sin(pi*u^0.75)^lpow`), which gives a plateau instead of a tall mid-swing peak.
- Params (`work/lift_fix4.json`, [world lift H, toe-flat, screen extra lift H, swing advance exp, knee cap, lift pow]):
  - W [0.072, 0.08, 0.03, -2.2, 62, 0.8]: clearance near 15/18.5/16.5/12, far 17/20.5/17.5/12, min 12.0 px (was 6.5); knee peak 62 deg; screen thigh peak ~58 deg.
  - E [0.062, 0.08, 0.05, -3.8, 66, 0.3]: near f08-11 13/17.5/16/13.5, far f02-05 11.5/18/15.5/11, min 11.0 px; knee peak 66 deg (was ~97); screen thigh peak ~91 deg.
  - N [0.062, 0.08, 0.05, -3.8, 66, 0.3]: near 11/17.5/15.5/11.5, far 17.5/18/15.5/11.5, min 11.0 px; knee peak 66 deg; screen thigh peak ~94 deg.
- Unchanged: heel-first landing, toe-off, swing shin >= -30 deg (min W -17.8, E +6.4, N +7.3), 0 px planted slide, travel 115, drops W/E/N upper 4.20/4.57/4.47 % and pelvis 3.20/3.57/3.47 %. Stance frames f00, f01, f06 and f07 are byte-identical to pre-fix4. E f00-f01 far-leg lightening was re-applied.
- Known limit: on E and N the knee cap means the clearance now comes from the thigh rotating forward, which reaches about horizontal on screen at f03/f09. That still reads as a high step, mostly on E f08-f10. With the shin limited to -30 deg, the foot can't rise behind the body, so a lower thigh would cost clearance.
- Backup: `work/backup_pre_fix4/`.

## Fix pass 3 (Oct 3 2026, ~19:48 ET): drawn swing-foot clearance on E/N
Backup: `work/backup_pre_fix3/`. Only the E/N walk swing frames changed (E/N f02-f05 and f08-f11). The stance frames, W, and all actions are byte-identical.
- **E/N swing changes** (`work/lift_fix3.json` -> `walk4.Walk4(lift, flat, xl, fprof)`):
  - The drawn ankle is raised by up to 0.08 H above the projected swing path. The thigh flexes forward to reach it while the shin keeps its >= -30 deg angle (more knee flex mid-swing).
  - The swing foot advances on 1-(1-u)^3.5 instead of Ironjaw's 1-(1-u)^1.6, so it clears the rising floor track early in swing.
- **Drawn-foot clearance** (`qa.json` `drawn_swing_foot_clearance_*`): the foot piece is rendered alone through the same cell transform. The floor line is that leg's ground track (iso slope) through its lowest drawn sole point on flat-stance frames, and clearance is the minimum over the foot pixels.

| | swing frames, game px | min |
|---|---|---|
| E near f08-f11 | 14.0, 23.5, 20.5, 14.0 | |
| E far f02-f05 | 12.5, 23.0, 19.5, 12.0 | 12.0 |
| N near f08-f11 | 12.0, 22.5, 19.5, 12.5 | |
| N far f02-f05 | 18.5, 24.0, 19.5, 12.0 | 12.0 |
| W (unchanged, not in scope) | | 6.5 |

- **Unchanged:**
  - swing shin min -30.0
  - upper-body drop 4.20 / 4.57 / 4.47 %H, pelvis drop 3.20 / 3.57 / 3.47 %H
  - travel 115
  - planted slide 0.0
  - E f00-f01 far-leg lightening (luma 30.0 -> 53.9, 31.0 -> 55.5)
  - 0 semi / cyan / near-white px
- **Side effect:** the swing knee now flexes much more on screen. The E/N near knee reads 97/89/65/60 deg (E f08-f11) and 95/99/82/75 deg (N), against 34-86 before, so the back-view swing reads as a higher step.

## Fix pass 2 (Oct 3 2026, ~19:42 ET): re-applied the fixes lost in the restart
The touched folders and the previous qa.json/README are backed up in `work/backup_pre_fix2/`.
1. **W/E/N walks** were rebuilt from `work/walk4.py` with two changes:
   - The swing shin is clamped to -30 deg on screen after the IK, by rotating the shin about the knee on swing frames only.
   - The chest settle is 1.0 %H.
   - On-disk numbers (`qa.json`):
     - swing shin min -30.0 / -30.0 / -30.0 deg (W/E/N)
     - upper-body drop 4.20 / 4.57 / 4.47 %H
     - pelvis drop 3.20 / 3.57 / 3.47 %H
     - travel 115 px
     - planted slide 0.0
     - on-screen leg length 0.80-1.23x (stretched along the bone only, painted width kept)
   - The E f00-f01 far-leg lightening was re-applied to the rebuilt frames: far-leg luma 30.0 -> 53.9 and 31.0 -> 55.5.
2. **S idle f00-f03:** the 8 near-white px (2 per frame) were scaled down to luma 190. 0 near-white remain.
3. **S death f04-f05:** the lying body (main component) was moved up 29 px. Its lowest row is now 166, the same row as the dropped shield and mace and the S walk sole row. No overlap with the props, no edge touch. f03 (mid-fall) is unchanged; its lowest body row is 172, 6 px below the floor row.

## Fixes from pass 1 (still in place)
Originals are backed up in `work/backup_pre_fix/`.
1. **E walk f00-f01, trailing far leg:** only the visible far-leg pixels were lightened (RGB x1.6 + 6, capped at 185). Those pixels were found by re-rendering the frame with and without the far-leg parts. Mean luma went from about 30 to about 54-56, close to the body's 49. Nothing else changed. `strips/bastion_walk_E_strip.png` was regenerated.
2. **S death f03-f05, dropped mace:** the mace was mostly hidden under the dropped shield (50 visible px). Its visible pixels were removed and the whole mace layer was re-placed 59 px to the right, beside the shield on the same floor row. It does not overlap anything. `strips/bastion_death_S_strip.png` was regenerated.

## Spec (unchanged)
- Cell 160x196, pivot (80,165). Attack cell 220x196, pivot (110,165). Death cell 330x196, pivot (165,165).
- Hard alpha (0 semi-transparent px). 0 cyan.
- Timings: walk 12 f x 58.33 ms; idle 4f@4fps; attack 6f@12fps (impact f03); hit 4f@12fps; death 6f@10fps.

## Walks W/E/N (`work/walk4.py`)
- **Gait:** Ironjaw v2 world-plane gait, normalised to Bastion's leg length and height and projected onto each facing.
- **Leg length:** hip->ankle about 0.41 H, matching the S v18c proportion. The E/N hip was moved up under the cape.
- **Travel:** 115 game px per cycle on W, E and N (S = 125.06, so 8 % slower).
- **Planted slide:** 0.0.
- **Pelvis drop:** 3.2-3.6 %H.
- **Mid-stance screen knee:** about 10-18 deg. Landing f01 is 18 / 55 / 60 deg.
- **Toe above the sole line:** 9.7-12.7 game px through swing.
- **On-screen leg length:** 0.80x to 1.23x, clamped at 0.80-1.20 with a few E/N swing frames at 1.23. The pieces are not rigid; see the earlier v4 report for why.
- **S walk:** the locked v18c.

## S actions
idle, attack, hit and death are on the v18c part rig. In death the shield and mace are separate pieces that drop to the floor (shown in `qa.json` `multi_piece`).

## Files
- `qa.json`
- `bastion_full_v4_contact_sheet_1x.png`, `bastion_full_v4_contact_sheet_game0.6x.png`
- `bastion_full_v4_preview.mp4`
- `bastion_v4_vs_ironjaw_v2_walks_sbs.mp4`
- frames in `walk/ idle/ attack/ hit/ death/`, `strips/`
