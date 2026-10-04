# Bastion actions v1: idle, attack, skill, hit and death

These are Bastion's combat actions for S and E. They use the Kestrel pilot's method (`../../kestrel/actions_v1`), with the pilot's lessons applied from the start. W and N are game-side mirrors.

The look is Bastion's LOCKED walk (`../v3`, locked by Luca at `7f65035e`), and the walk frames are not touched. Every part is either:

- cut from the approved targets (`targets/bastion_rp_{S,E}_f00`) with the walk's own polygons, at the walk's scale s_up (S 0.4122, E 0.39399), or
- one of the walk's painted pieces: the S 3/4 helm facing down-right, the S belt with tassets and trident tabard, and the E back helm.

The painted pieces come from `walk_{S,E}_f00`, mapped back to target px by the walk's own trunk transform (S t = (-32.8, 76.75), E t = (-7.2, 69.75)). The legs are the walk v3 target-cut pieces (thigh, knee cop, greave and sabaton) under the walk v3 leg rules.

## Files

| file | what |
|---|---|
| `frames/<action>_{S,E}_fNN.png` | 512x360 RGBA cells with pivot (256,329), binary alpha and black under alpha 0. `_build_info.json` holds the rig numbers per frame: torso angle and foreshortening, cape angles, leg k, arm bone k, mace k, shield stretch, death lift, and pixels lost outside the cell (always 0). |
| `gifs/<action>_{S,E}.gif` | On grey 172, 60 ms per frame (17.144 fps). Death holds its last frame. |
| `contact_{S,E}.png` | Every frame of every action, in three rows per action: painted, the rig clay (aimfix), and the approved clay (the `bastion_actions.mp4` poses). |
| `closeup_keys.png` | Key frames at 2x, S over E: idle f00, attack wind-up f03/f04, smash f06/f08, skill guard f06, hit f02, death f06 and f12. |
| `bastion_actions.mp4` | All 5 actions in all 4 facings, one facing at a time, then each action with S/E/W/N side by side. A copy is at `scratchpad/kclip/bastion_actions.mp4`. |
| `metric_idle_{S,E}.json` | Look score of idle f00 against the target. |
| `qa.json` | Format, inside-the-cell, frame-count, planted-feet and stretch checks (`scripts/qa.py`). |
| `blockout/` | `clay/`, `id/` and `joints_actions_512.json` from `scripts/act_blockout.py` in `aimfix` mode. `blockout/approved/` holds `actions.py` exactly as in the mp4 (clay and joints). |
| `parts/` | Full-canvas (1280x720 target px) pieces from `scripts/bcut.py`, plus `bjoints_{S,E}.json`. |
| `scripts/` | `act_blockout.py` (bpy), `bcut.py`, `barig.py`, `asheets.py`, `closeup.py`, `run_metric.py`, `qa.py` and `clip.py`. |

## Frame counts (from the blockout, `actions.py` lengths)

| action | frames | notes |
|---|---|---|
| idle | 12 | Loops. f00 is the walk's upper body on the stance legs. The chest rises and the mace arm settles. |
| attack | 12 | Overhead mace smash, starting and ending on idle f00. Wind-up f02–f05 (mace up and back over the helm), smash f06–f08 (lean in, step in), recover to f11. |
| skill | 12 | Shield guard, starting and ending on idle f00. The shield is raised and the mace cocked by f04, held to f09, then back. |
| hit | 8 | Starts and ends on idle f00. Recoil back with the arms thrown out, then recover. |
| death | 13 | No loop (hold f12). The knees go, he falls (S backward, E to his side) and lies on the ground. |

Total: 114 frames (57 S, 57 E).

## Pilot lessons applied from the start

1. **Aim and facing in my own `act_blockout.py` (`aimfix`).** Nothing is committed to `claude/class-walk-blockouts`.
   - In `actions.py` the arms hang in the torso frame, so the torso twist (cyaw −14 at the wind-up, +10/+12 at the smash) turns the whole swing 10–14° off the facing.
   - In `aimfix` the shoulders ride on the twisted torso, but the arm angles are applied in the facing frame (lean kept, no yaw). The twist belongs to the torso and the swing plane is the facing.
   - The smash's R-arm abduction is 4° at impact (`actions.py`: 15 and 12), so the mace comes down in front of the right shoulder: S down-right, E up-right. The shield arm gets the same treatment.
2. **Every frame is inside the cell, death included.**
   - The rig renders on a padded canvas and counts every pixel that would land outside the cell. The count is 0 on all four sides in all 114 frames (`qa.json`).
   - E death falls to his left, as Kestrel's does, not straight back toward the camera, so it follows the S death's screen path.
   - The attack step-in goes forward and inward (`step_in`, 0.6x forward plus 0.6x toward the centre line, 0.85 of the step length). Straight forward, the S sabaton leaves the cell bottom (toe joint at y 362).
   - Death adds a lift (S 0→12 px, E 0→6 px) only from the first frame where the blockout moves the feet. It never decreases and grows by at most 3 px per frame.
   - The mace tips back about the fist when its head would cross the top row: E attack f02/f05 by 43–44°, E skill f04–f09 by 13°.
   - The shield is kept inside by a small translation.
3. **Raised and swinging arms are target pieces turned, never a stretched hanging arm.**
   - Each arm is three rigid painted pieces: the upper sleeve, then couter + vambrace + gauntlet fist as one piece, then the mace.
   - They are chained by FK from the painted shoulder. Each bone keeps its painted length times the blockout's projected length change, clamped to ±15%. Max arm bone stretch is 1.15, min 0.85, and the mace stays in the same 0.85–1.15 band.
   - At rest a bone turns by the blockout bone's change since idle f00, so idle keeps the painting. Once the arm key leaves the stance (30° of key change), the bone lies on the blockout bone's own screen direction, so a raised or swinging arm and the mace point where the blockout points.
   - The upper sleeve hidden under the pauldron is continued from its own painted cross-section, tiled along the bone.
4. **The shield arm is its own key, with the shield strapped on the outside of the left forearm.**
   - The shield's centre is carried by the painted left forearm. Its 2D shape follows the blockout shield's projected axes: rotation plus foreshortening clamped to 0.6–1.15, never mirrored, so the trident face always shows.
   - The left arm itself is the mace arm mirrored and 20% darker, because the target hides it behind the shield (S) and the cape (E).
   - S draw order: left arm → body → shield. E: left arm → trunk → shield → cape.
5. **Parts are clipped with alpha or a polygon, and gaps are filled with real paint, not Telea.**
   - Every piece is the target alpha inside the walk's polygons, plus colour masks for the blue cloth.
   - Holes in the body where the arm, mace or shield covered it are filled by copying the cape's or armour's own pixels from shifted patches of the same painting, then a 2 px feather.
   - The mace handle hidden under the fist is continued from its own painted section.
6. **Death has a lying-down key.**
   - The body (torso, arms and mace) flattens on screen like anything lying on the ground: vertical ×0.65 at full lie.
   - The shield turns with the body and lies on his left side.
   - The mace drops flat beside his hand.
   - The cape lies flat under him: S lies on it, so it is pulled in along the body (×0.55) and mostly hidden. On E it drapes over him. Panel lag is clamped to 10° so the tatters never shear.

## Rig (per frame, `scripts/barig.py`)

- **Body:** one similarity (s_up, plus rotation and along-axis foreshortening from the blockout pelvis→neck axis change since idle f00), pinned at the painted hip centre, which follows the blockout pelvis. Idle f00 uses the walk's trunk rule: crest on head_top − crest_drop, x from the pelvis, and the walk's sub-px phase.
- **Head:** the head is the walk's painted helm, so it faces the action direction, down-right on S and up-right on E.
- **Cape:** two lagged panels on the body mesh. The cloth weights reach past the ragged hem and fall off only toward the armour. Every action's cape starts on the painting at f00.
- **Legs (walk v3 rules):**
  - Hips sit at the target hip points on the body.
  - The knee is 2-bone IK at the target lengths, with 1 ≤ k ≤ 1.1 along the bone only (max used 1.098).
  - The sabaton is rigid on the blockout heel→toe, pinned at the heel with the walk's `boot_o`, and E keeps the walk's ×1.1 along the foot.
- **Sampling:** parts are pre-scaled with the walk's premultiplied Lanczos resize and warped at cell resolution, so idle keeps the walk's sharpness. Alpha is binarised at 0.5.
- **Gold:** S gold trim gets +6 L* at target resolution, which gives the walk's cell-level +4 grade (bone dE 0.44, against 3.07 unlifted). The walk pieces already carry that grade.

## Scores (idle f00, same metric as the walk: `bastion/v3/scripts/bastion_metric.py`, unchanged)

| | look | ssim upper / lower | iou | palette | height vs idle | metric motion (idle vs its clay) |
|---|---|---|---|---|---|---|
| S | **85.7** (PASS ≥ 85) | 0.904 / 0.558 | 0.853 | 0.950 | 0.996 | 100 |
| E | **88.0** (PASS ≥ 85) | 0.905 / 0.700 | 0.849 | 0.943 | 1.000 | 91.7 (head-top bob 1.33 px off the clay at f06, bar 1 px) |

For reference, the LOCKED walk f00 scores S 87.2 and E 88.8 under the same idle joints. The S gap is the idle stance: the blockout idle has the R foot forward while the target has the L foot forward (ssim_lower 0.558 against the walk's 0.62).

## Checks (`qa.json`)

- **Format:** all 114 frames are 512x360, with alpha 0/255 only and RGB 0 under alpha 0.
- **Inside:** 0 px lost outside the cell in every frame.
  - The S sabaton toe reaches the last row (y 359) in every S frame up to death f03 (48 frames). It touches the edge but is not cut, the same as the LOCKED walk S f00–f02.
  - No other edge is touched.
- **Frame counts:** every action and facing matches the blockout.
- **Planted feet:** 0.00 px in every pair of frames where the blockout heel and toe stay put. The one exception is E death, where the L foot moves 0.14 px. Feet move only where the blockout moves them (the attack step, the death).
- **Stretch:** arm bones 0.85–1.15, mace 0.85–1.15, legs ≤ 1.098 and never shortened.

## Open issues (honest list)

- **Death reads as a heap more than a body lying on its back (S).** The torso is the front painting rotated by −63° and flattened, so you see the chest and shield face-on with the knees up to the right.
  - There is no painted lying-down figure. The lying key is built from the standing pieces, and the boots are rotated, not painted lying down.
  - E death (on his side, cape over him) reads better.
- **The S death lift** reaches 12 px at f12, so he ends 12 px up the screen of where he would lie. E reaches 6 px.
- **The wind-up arm (attack f02–f05) is short.**
  - The painted arm is foreshortened, as in the target, and is never stretched past 1.15.
  - On S f03/f04 the raised upper arm is mostly behind the pauldron, so the fist seems to come out at the helm.
  - The gauntlet is the hanging painting turned upside down, so its light comes from below.
- **E mace tip-back:** on E attack f02 and f05 the mace head is tipped 43–44° back from the blockout direction to stay under the top row, so the wind-up arc there is flatter than the clay's.
- **E shield arm:** the left arm is a darkened mirror of the mace arm and stays behind the cape. In hit E f01–f03 the shield is thrown out to the left with only a sliver of arm showing, so it looks a little detached.
- **The smash is readable but small:** at impact (f06–f08) the mace lands by the R knee on S and to the right on E, as the clay does, but the lean is a 2D tilt (max 21°) of the rigid torso, with no shoulder turn.
- **S idle look margin:** 85.7 against the 85 bar. The legs follow the blockout idle stance, not the target's.
- **Mesh shear:** cape lag is clamped to 10°. Without the clamp, fast falls shear the hem tatters into streaks.
- **Blockout cell bottom:** the approved clay itself clips at y 359 on S in idle, attack and death. The painted frames keep everything inside instead (step-in, death lift).

### Frames I'm unsure about

- death_S f06–f12: the lying pose and the lift.
- attack_E f02, f05: the mace tipped back.
- attack_S f03, f04: the raised arm hidden behind the pauldron.
- hit_E f01–f03: the shield thrown out.
- skill_E f04–f09: the mace tipped 13° and the shield hidden behind the body, as in the clay.

## Blockout issues (reported, not changed on `claude/class-walk-blockouts`)

1. **Swing direction:** `actions.py` hangs the arms in the twisted torso frame, so the attack turns 10–14° off the facing. Fixed here by `arms_facing`.
2. **S step and death leave the cell:** the forward step puts the S toe joint at y 362, and the S clay touches the bottom row in idle, attack and death. Fixed here by `step_in` and the death lift.
3. **E death falls toward the camera** (straight back) and leaves the cell. `aimfix` makes it fall to his left.
4. **Facings never shown:** the mp4 shows only S for idle, skill, hit and death (attack has S and E). The E versions of those four are rendered here for the first time.

## How to re-run

```
cd docs/pc/art_help/class_walk_looks/bastion/actions_v1/scripts
<bpy venv>/bin/python act_blockout.py ../blockout aimfix              # clay, id, joints (Blender 4.2 as a module)
<bpy venv>/bin/python act_blockout.py ../blockout/approved approved   # the mp4 poses, for the contact sheet
python3 bcut.py                                                       # parts/
python3 barig.py --gif                                                # frames/ + gifs/ (about 30 s)
python3 asheets.py; python3 closeup.py; python3 run_metric.py; python3 qa.py
python3 clip.py ../bastion_actions.mp4
```

`act_blockout.py` extracts `actions.py` and `blockout.py` from `claude/class-walk-blockouts` at `ca1a7c30` with `git archive` into `/tmp/bastion_blockout_act`.
