# Ironjaw actions v1: idle, attack (Strike), skill (Shoulder), hit and death

> **LOCKED, 4 Oct 2026, at `73cdaab1`.** Mauro: "Lock all three". These frames ship as they are. Every rough spot and every change from the approved poses is listed in this README's open-issues section for a future pass. To change anything, re-run `scripts/` from the same pipeline; don't hand-edit frames.

> These poses were built in our own `act_blockout.py`, because no Ironjaw action blockout existed. Mauro never approved them as poses; he locked the result. The look is the dark-steel HD walk (`ironjaw_walk/v7`). Mauro chose that look for the phone game too ("Dark-steel for all"), so mobile's Ironjaw walk moves from the older red set to v7.

These are Ironjaw's combat actions for S and E, painted with the method of the LOCKED Kestrel and Bastion actions (`../../kestrel/actions_v1`, `../../bastion/actions_v1`), with their lessons applied from the start. W and N are game-side mirrors.

> **The poses were never approved by Mauro.** `claude/class-walk-blockouts` has no Ironjaw class and no Ironjaw actions, so the blockout here is our own (`scripts/act_blockout.py`), built for his kit. Please review the poses before these go to the game.

> **Which walk these match.** The look is his painted HD walk, `ironjaw_walk/v7` on `art/ironjaw-walk-help` (the parts, scale and targets of that walk). **This is not the walk the mobile game shows today.** Mobile (`build_tools/mobile_characters/build_mobile_walks.py` on `origin/mobile`) pins `pc/combat-look` `art/pc/characters/ironjaw/walk` at `a0aec2e`, and those L10 frames are the older red v3.1 sprite set (165x157 cells, `ironjaw.json` status "v3 (v3.1) = technical fix of approved v2"). Next to that red walk these dark-steel actions will not match. Mobile's walk needs to move to the HD walk (v7, or the LOCKED v8 with the same upper body) when these actions go in. The walk frames themselves were not touched.

## Files

| file | what |
|---|---|
| `frames/<action>_{S,E}_fNN.png` | 512x360 RGBA cells, pivot (256,329), binary alpha, black under alpha 0. `_build_info.json` holds the rig numbers per frame: torso angle and foreshortening, head turn, cape angles, leg k and k_effective, arm bone k, edge turn, arm draw order, clean-up counts and pixels lost outside the cell (always 0). |
| `gifs/<action>_{S,E}.gif` | On grey 172, 60 ms per frame (17.144 fps). Death holds its last frame. |
| `contact_{S,E}.png` | Every frame of every action: painted over the rig clay it is bent onto. |
| `closeup_keys.png` | Key frames at 2x, S over E: idle f00, Strike wind-up f04, chop f06 / f08, Shoulder coil f03 and drive f07, hit f02, death f07 and lying f12. |
| `ironjaw_actions.mp4` | All 5 actions in all 4 facings, one facing at a time, then each action with S/E/W/N side by side. A copy is at `scratchpad/kclip/ironjaw_actions.mp4`. |
| `metric_idle_{S,E}.json`, `metric_idle_{S,E}_vs_walk_target.json` | Look score of idle f00 (see Scores). |
| `qa.json` | Format, inside-the-cell, frame-count, planted-feet, `arm_stretch`, leg and clean-up checks (`scripts/qa.py`). |
| `blockout/` | `clay/`, `id/` and `joints_actions_512.json` from `scripts/act_blockout.py`. Also `walk_fit.json` (the walk f00 placement of its target, fitted with the walk metric's own fit) and `ta_idle_joints.json` (the TA idle joints his approved idle set stands on). |
| `parts/` | Full-canvas (1280x720 target px) pieces from `scripts/ijcut.py`, plus `ijoints_{S,E}.json`. |
| `scripts/` | `act_blockout.py` (bpy), `ijcut.py`, `ijrig.py`, `asheets.py`, `closeup.py`, `run_metric.py`, `qa.py` and `clip.py`. |

## Frame counts

| action | frames | notes |
|---|---|---|
| idle | 12 | Loops. f00 is the walk's upper body on his idle stance. Heavy breathing: chest rises, shoulders settle, the axes sink a little, a slight nod. |
| attack (Strike) | 12 | Starts and ends on idle f00. Wind-up f02–f05 (right axe up over the helm, left axe drawn back, torso twisted away), chop f06–f08 (lean in, forward-inward step), recover to f11. |
| skill (Shoulder) | 12 | Starts and ends on idle f00. Coil back f03, drive the left shoulder forward low with a big step f06, hold the hit to f08, recover. |
| hit | 8 | Starts and ends on idle f00. Recoil back with the arms thrown out and a head snap, then recover. |
| death | 13 | No loop (hold f12). Knees go f03, he falls (S straight back, E onto his left side), lying-down key f11–f12. |

Total: 114 frames (57 S, 57 E).

## The action blockout (own, not approved)

`act_blockout.py` adds an `ironjaw` class to the class-walk framework (`blockout.py` / `actions.py` at `ca1a7c30`, extracted read-only with `git archive`): his proportions (hip at 0.45 H, big upper body, broad shoulders and limbs, helm, pauldrons, cape) and two axes, one per fist, haft forward-down out of the fist, blade vertical. The idle is his hold: fists at belt height, elbows out, axes forward and down.

Poses for his kit (`data/kits.gd`: Advance, Strike, Shoulder, Crush), with Bastion's attack and hit timing as the template:

- **attack = Strike**, a heavy overhead chop with the right axe.
- **skill = Shoulder**, a shoulder charge.
- **Advance** (a 2-tile hop) and **Crush** (a heavier strike) have no action slot of their own in the game's drop (`ACTION_KINDS` idle/attack/skill/hit/death in `build_mobile_walks.py`), so they are not separate animations.

## Lessons applied from the start

1. **Strikes go along the facing.**
   - The shoulders ride the twisted torso, but the arm angles are in the facing frame (lean only, no yaw).
   - The Strike lands down-right on S and up-right on E.
   - The torso twist (cyaw −14 at the wind-up, +10/+12 at the chop, −34/−36 in the Shoulder drive) is the torso's alone.
2. **Every frame stays inside the 512x360 cell, death included.**
   - 0 px are lost outside the cell in all 114 frames, and no frame touches the border.
   - No death lift or side shift was needed.
   - S falls straight back, away from the camera. E falls onto his left side instead of toward the camera.
   - Steps go forward and inward.
   - A forearm + axe piece that would cross an edge is turned about the elbow by the smallest angle that clears it. The direction is fixed per action and arm and eased over neighbouring frames so it never flips (see `qa.json` `edge_turn`).
3. **Raised and striking arms are the painted pieces turned.**
   - Each arm is three painted pieces: the pauldron (rigid on the torso, drawn over the arm root), the upper arm (rerebrace, grown under the pauldron from its own painted section), and one rigid vambrace + fist + axe piece, so the fist stays closed on the haft as painted.
   - At rest a bone turns by the blockout bone's change since idle f00, so idle keeps the painting.
   - Posed, it lies on the blockout bone's direction, blended over 90° of key change so nothing jumps.
   - **arm_stretch:** the upper arm stays within ±15% (0.85–1.15). The forearm + axe piece is never stretched (1.00). A hanging arm is never stretched.
4. **Holes are filled from real cloth or armour texture, never Telea.**
   - The cape hidden behind the S near arm is filled with a plain run of the same cape (the E target's cape, mirror-tiled, colour- and shade-matched).
   - The E back plate under the cape, the torso where the arms covered it, and the collar under the helm are filled by block quilting from the same painting.
   - The walk's own layer cut (`layers6.py`) runs unchanged, except that its Telea + noise fill is replaced.
5. **Death has a lying-down key.**
   - The body lies flat (vertical ×0.65 on screen, as anything on the ground at the 30° camera).
   - The cape lies under him (S) or over him (E).
   - The arms lie along the body or on the ground, and the head lolls to the side.
6. **The hit has a clear recoil and a head snap.**
   - The blockout recoil is 24°, which gives 20° of screen tilt at f02 on both facings.
   - The helm snaps back a further 12° (S) / 17° (E).
7. **Source speckles and dark edges are cleaned in every new frame.**
   - Islands under 8 px are dropped.
   - Pin holes under 24 px inside the figure are closed with the paint around them: 2147 px over the set.
   - Dark halo pixels on the silhouette edge (under 0.55× the paint just inside) are recoloured from it: 4600 px.
   - The re-check on the written frames finds 0 small holes and 0 specks.
8. **The head faces the action direction.** It is the walk's painted helm: S down-right, E up-right.

## Rig (`scripts/ijrig.py`)

- **Body:** one similarity at the walk's scale (S 0.3884, E 0.4190, the walk f00 fit). Rotation and foreshortening come from the blockout pelvis→neck axis change since idle f00, pinned at the painted pelvis, which follows the blockout pelvis. Idle f00 is the walk f00 placement moved onto the idle pelvis, with the helm top on row 64 (the approved idle set's height).
- **Head:** the walk's helm, turned about the painted neck by the blockout head's change relative to the torso.
- **Cape:** its own mesh with a 3-bone skin (torso, upper panel, lower panel). Weights are feathered past the ragged hem. The panels lag, trail the pelvis, and give back part of the torso lean so the cape hangs. The S chest tabard is rigid with the torso.
- **Legs:** the walk's painted pieces (`v7/legs_v6_pieces`, graded to the walk's leg colours).
  - The boot is rigid on the blockout heel→toe, on his idle foot placement (TA idle joints).
  - The ankle is the boot's painted ankle point.
  - The knee uses 2-bone IK at the idle leg lengths, with k 1.00 rising to at most 1.10 only when out of reach.
- **Draw order:**
  - S: cape, far arm, legs, body, head, near arm.
  - E: legs, body, cape, head, arms.
  - The blockout depth flips an arm when it passes the torso by more than 0.08 H, and a raised arm passes behind the helm.

## Scores (idle f00, the walk's metric: `match_metric.py` from `claude/ironjaw-walk-help-reply`, unchanged)

| | target | look | ssim upper / lower | iou | palette | height vs approved idle |
|---|---|---|---|---|---|---|
| S | walk target `v7/targets/rp_S_turn_t1.jpg` | **87.8** (PASS ≥ 85) | 0.947 / 0.541 | 0.853 | 0.974 | 1.000 |
| E | walk target `v7/targets/rp_E_stride_t2.jpg` | **88.9** (PASS ≥ 85) | 0.985 / 0.572 | 0.825 | 0.968 | 1.000 |
| S | `repaint_targets/rp_S_f00_t1.jpg` | 47.0 (fail) | 0.140 / 0.114 | 0.645 | 0.872 | 1.000 |
| E | `repaint_targets/rp_E_f00_t1.jpg` | 43.7 (fail) | 0.129 / 0.123 | 0.571 | 0.797 | 1.000 |

The walk was painted on `rp_S_turn_t1` / `rp_E_stride_t2`, and its own v7 scores (S 87.5) are against those. The older `rp_*_f00_t1` targets are a different pose and painting: the LOCKED-look walk v7 f00 itself scores only 47.6 (S) and 45.7 (E) against them with the same script. So the idle passes against his walk's targets and cannot pass against `rp_*_f00_t1` without leaving the walk's look.

The metric's motion part (idle against its own clay) reads 0. It compares the support sole with the clay's, and the painted feet stand on his TA idle foot placement, not the generic clay's. Head-top bob error is 0.75 px (S) and 0.83 px (E), under the 1 px bar.

## Checks (`qa.json`)

- **Format:** all 114 frames are 512x360, alpha 0/255 only, RGB 0 under alpha 0.
- **Inside:** 0 px lost on every side of every frame. No frame touches the border. The widest unions are attack E x 71–497 and hit E x 19–409. The lowest row is 357 (death S).
- **Frame counts:** every action and facing matches the blockout.
- **Planted feet:** 0.00 px in every pair of frames where the blockout heel and toe stay put, except death E's left foot at 0.21 px. Feet move only where the blockout moves them: the Strike step (R), the Shoulder step (L) and the fall.
- **arm_stretch:** upper arm 0.85–1.15 (max ±15%), forearm + axe 1.00.
- **Legs:** IK k ≤ 1.10. Effective span up to 1.20 (see Open issues).

## Open issues (honest list)

- **Mobile match:** these frames match the HD v7 walk, not the red L10 walk mobile shows today (see the top of this file).
- **Poses not approved:** Strike, Shoulder, hit and death are our own blockout keys. Nobody has signed them off.
- **The S cape behind the near arm is a fill.**
  - It shows once the arm moves (attack f02–f10, skill, hit, death).
  - It is real cloth from his own cape, so the folds run on. But its outline is partly a straight polygon edge (the left edge and the top at the shoulder), and the shading is a little flatter than the painted folds.
- **The S death reads as a heap more than a body on its back** (f10–f12), the same issue as Bastion.
  - It is the front painting turned −63° and flattened.
  - The boots are turned, not painted lying, so the near boot stands toes-up.
  - E (on his side, cape over him) reads better.
- **The axes are rigid with the forearm.**
  - Wind-up and fallen axes are turned back about the elbow to stay inside the cell: attack S f03–f04 by 32°, attack E f02–f05 by 35–44°, death S f06–f12 by 7–24°, death E f07–f09 by 17–35°. The wind-up arc is flatter than the clay's there.
  - In death E f10–f12 the right axe still points up off the ground.
- **The legs stretch in the deepest poses:** skill E f06–f09 and death S f10–f12, effective span up to 1.20.
  - The IK bones stop at 1.10, and the shin takes the rest.
  - The near boot in skill S f06–f08 reads flat.
- **The Shoulder drive (skill f05–f09) hides the trailing arm behind the body.** On S the trailing axe shows below the body as a loose blade.
- **E Shoulder** reads as a turn more than a charge from behind. The forward drive is away from the camera, so it foreshortens.
- **The walk's leg pieces:** the walk's S shins came from `legs_v4` (box-only, not in the repo), so S uses the repo's `legs_v6` shins. The S legs therefore differ slightly from the walk's.
- **Cape:** the lag and hang are clamped at 22°. The S cape still swings out a little in the chop and the Shoulder drive.

### Frames I'm unsure about

- attack_S f03–f04 and attack_E f02–f05: the axe turned back about the elbow.
- skill_S f05–f09: the trailing right arm and axe behind the body; the flat near boot.
- skill_E f05–f09: the leg stretch, and the cape swinging out left.
- death_S f09–f12: the heap and the standing boot.
- death_E f10–f12: the right axe pointing up.
- hit_S f02–f03: the cape fill behind the thrown-out near arm shows.

## How to re-run

```
cd docs/pc/art_help/class_walk_looks/ironjaw/actions_v1/scripts
python3 ijcut.py                                              # parts/ + blockout/walk_fit.json + ta_idle_joints.json
<bpy venv>/bin/python act_blockout.py ../blockout             # clay, id, joints (Blender 4.2 as a module)
python3 ijrig.py --gif                                        # frames/ + gifs/ (about 30 s)
python3 asheets.py; python3 closeup.py; python3 run_metric.py; python3 qa.py
python3 clip.py ../ironjaw_actions.mp4
```

- `ijcut.py` and `run_metric.py` extract `docs/pc/art_help/ironjaw_walk` from `art/ironjaw-walk-help` at `0f3eeb80` and the metric scripts from `claude/ironjaw-walk-help-reply` at `19b4ac11` into `$IJ_SRC` (default `/tmp/ironjaw_actions_v1_src`).
- `act_blockout.py` extracts the class-walk blockout scripts at `ca1a7c30` into `$IJ_BO_DIR` (default `/tmp/ironjaw_actions_v1_blockout`).
- Nothing on those branches is changed.
