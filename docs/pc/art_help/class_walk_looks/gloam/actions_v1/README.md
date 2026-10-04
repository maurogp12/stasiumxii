# Gloam actions v1: idle, attack, skill, hit and death

> **LOCKED, 4 Oct 2026, at `83ab63bb`.** Mauro: "Lock all three". These frames ship as they are. Every rough spot and every change from the approved poses is listed in this README's open-issues section for a future pass. To change anything, re-run `scripts/` from the same pipeline; don't hand-edit frames.

These are Gloam's combat actions for S and E. W and N are game-side mirrors. They use the painted-part pipeline of the LOCKED Kestrel and Bastion actions (`../../kestrel/actions_v1`, `../../bastion/actions_v1`), with every lesson from their "Known issues" applied from the start.

The look is Gloam's LOCKED walk (`gloam/v1_claude` on `claude/gloam-legs`, locked at `8119c9e`, lock note `bdf0ff37`). The walk is not on this branch, so `scripts/gwalk.py` extracts it read-only with `git archive` and imports its rig (`grig.py`) and parts from there. Nothing of the walk is changed.

- **Body, hood and cloak:** the walk's own target-cut layers (`back_F`, `front_F`), with the arms taken out (`scripts/gacut.py`). They sit at the walk's scale and height: S s = 0.362, E s = 0.354, dy 6.
- **Legs:** the walk's continuous painted legs (`leg_F`, `legfar_F`) on the walk's 3-bone skin, under the walk's leg limits (S `stance_kmin` 0.82, `stretch_max` 1.10).
- **Arms and daggers:** cut from the approved targets (`targets/gloam_rp_{S,E}_f00`).

## Files

| file | what |
|---|---|
| `frames/<action>_{S,E}_fNN.png` | 512x360 RGBA cells with pivot (256,329), binary alpha and black under alpha 0. `_build_info.json` holds the rig numbers per frame: body angle and foreshortening, cloak angles, cloak keep-in angle, head snap, leg k, arm bone k, arm turn and reflection, arm keep-in angle, death lift, and pixels lost outside the cell (always 0). |
| `gifs/<action>_{S,E}.gif` | On grey 172, 60 ms per frame (17.144 fps). Death holds its last frame. |
| `contact_{S,E}.png` | Every frame of every action, in three rows per action: painted, the rig clay (aimfix) and the approved clay (the `gloam_actions.mp4` poses). |
| `closeup_keys.png` | Key frames at 2x, S over E: idle f00, attack cross f03, lunge f05, slash f06/f08, skill f06, hit f02, death f06 and f12. |
| `gloam_actions.mp4` | All 5 actions in all 4 facings, one facing at a time, then each action with S/E/W/N side by side. A copy is at `scratchpad/kclip/gloam_actions.mp4`. |
| `metric_idle_{S,E}.json` | Look score of idle f00 against the target. |
| `qa.json` | Format, inside-the-cell, frame-count, planted-feet, `arm_stretch` and angle checks (`scripts/qa.py`). |
| `blockout/` | `clay/`, `id/` and `joints_actions_512.json` from `scripts/act_blockout.py` in `aimfix` mode. `blockout/approved/` holds `actions.py` exactly as in the mp4 (clay and joints). |
| `parts/` | Full-canvas (1280x720 target px) pieces from `scripts/gacut.py`, plus `gjoints_{S,E}.json`. |
| `scripts/` | `act_blockout.py` (bpy), `gwalk.py`, `gacut.py`, `garig.py`, `asheets.py`, `closeup.py`, `run_metric.py`, `qa.py` and `clip.py`. |

## Frame counts (from the blockout, `actions.py` lengths)

| action | frames | notes |
|---|---|---|
| idle | 12 | Loops. f00 is the walk's upper body on the stance legs. The chest rises, the right dagger arm settles, the cloak sways. |
| attack | 12 | Cross high, lunge, double slash, starting and ending on idle f00. Daggers cross high over the hood f02–f04, lunge f05, slash f06–f08 (lean in, step in), recover to f11. |
| skill | 12 | Shadow step, starting and ending on idle f00. Crouch low with the daggers swept back by f04, held to f08, rise. |
| hit | 8 | Starts and ends on idle f00. Recoil back with a head snap, then recover. |
| death | 13 | No loop (hold f12). The knees go, he falls to his left side and lies on the ground. |

Total: 114 frames (57 S, 57 E).

## Lessons applied from the start

1. **Strike along the facing (`aimfix` in our own `act_blockout.py`).** Nothing is committed to `claude/class-walk-blockouts`.
   - In `actions.py` the double slash ends with both arms abducted 45–60° (keys f06 (45, 45, 10) and f08 (20, 60, 15)), so the daggers fly out sideways, across the facing.
   - In `aimfix` the arms come down in front of the shoulders: f06 (55, 14, 10) and f08 (32, 18, 15). Both blades travel along the facing, S down-right and E up-right.
   - Arm angles are applied in the facing frame (lean kept, no yaw), so a torso twist stays the torso's.
   - Timing, lean, drop and the lunge are the blockout's.
2. **Every frame is inside the cell, death included.** The rig renders on a padded canvas and counts every pixel that would land outside: 0 on all four sides in all 114 frames. No frame touches the cell border.
   - The lunge goes forward-inward (`step_in`, as Bastion's), so the S boot stays inside.
   - The long cloak swings back (lower panel only, about its hinge, at most 25°) when it would cross the bottom row. It lags the recoil in hit S f02–f04 (14°, 10°, 1°).
   - The arm turns about the shoulder when a dagger would leave the cell. This happens only in death E f10–f12 (left arm, 12–19°).
   - Death needs no lift at all (0 px S and E).
3. **Raised and striking arm keys come from the target, not from stretching a hanging arm.**
   - Each arm is two rigid painted pieces: the upper sleeve, and bracer + fist + curved dagger as one piece with the fist closed on the grip.
   - They are chained by FK from the painted shoulder. Each bone keeps its painted length times the blockout's projected length change, clamped to ±15% (`qa.json` `arm_stretch`: 0.85–1.15).
   - At rest a bone turns by the blockout bone's change since idle f00, so idle keeps the painting. Once the arm key leaves the stance, the bone lies on the blockout bone's own direction.
   - **Raised key:** a piece turned more than 100° from its painting is drawn reflected across its own bone axis. This keeps its lit edge toward the light instead of turning the painting upside down (Bastion's "lit from below" issue). It is used in attack f02–f04 (S) and f01–f05 (E), skill S f03–f10, and the lying arms in death.
   - The sleeve root hidden under the hood cloak is continued from its own painted rows, and the hood cloak's own pixels (`cover_F`) are drawn again over each arm root.
   - **E left arm:** the target hides it under the cloak, so it is the painted right arm mirrored and 18% darker. It stays behind the cloak at rest and comes out when raised.
4. **Holes are filled with real texture.** Where an arm covered the body, the hole is filled by copying the painting's own cloak pixels from shifted patches beside the arm. The largest coherent patch goes first, with a 2 px feather. There is no smooth fill and no Telea. The source is restricted to cloth, so no ghost of a leather sleeve appears. Where the arm hung over background, the hole stays background.
5. **Death has a lying-down key, and the cloak lies flat.**
   - The body is turned rigidly onto the ground along the blockout's body line: S +55°, E −64°. The along-axis foreshortening is 1 in death, so nothing is squashed.
   - The cloak's lower panel turns down onto the ground with the body (S −20°, E −25°). Lying, it may swing a further 40° so the hem stays on the ground instead of hanging below it. These are rotations only: the tatters keep their painted shape.
   - The daggers drop flat beside the hands. The arms turn toward the ground line at their painted length.
6. **Hit has a clear recoil and a head snap.**
   - The painted body recoils 23° at f02 on both facings. The blockout's −21° (S) / −19° (E) is scaled up to 23°, and `aimfix` already deepens the hit lean from −16 to −24.
   - The hood, with the shadowed face and the two violet eyes, is its own feathered skin bone. It snaps back 13° (S) / 12° (E) at f02, then eases out by f05.
7. **Head and eyes face the action direction.** The hood is the target's: S faces down-right and E up-right, along the strike.

## Rig (per frame, `scripts/garig.py`)

- **Body:** one map of the body painting, at scale s, rotated by the change of the blockout pelvis→neck axis since idle f00, and pinned at the painted hip centre, which follows the blockout pelvis.
  - Foreshortening is kept within 0.92–1.08: it reads as a lean, not a squash.
  - Idle f00 sits exactly where the walk puts f00: x on the hip centre, hood top on the clay's head-top row + dy.
- **Skin:** the body mesh has 4 bones with feathered weights (`wcape_F`): torso, upper cloak, lower cloak and head.
  - The cloth weight covers every hem tatter.
  - The rigid core is only the leather torso, so no tatter tip shears against the torso.
- **Cloak lag:** each panel is an exponential follower of the torso angle plus a trail of the pelvis velocity, clamped to ±10°. Every action starts on the painting.
- **Legs:** walk rules on the action blockout. The feet lie on the blockout heel/toe, pinned at the heel, so a planted foot moves only when the blockout foot moves. The knee is 2-bone IK at the painted lengths. The walk's crotch fill is applied in every action except death.
- **Draw order:**
  - S: body → legs → belt and flaps → arms → covers.
  - E: legs → body → coat and cloak → near arm → cover.
  - The blockout depth decides when an arm passes behind the torso.
- **Output:** render at 3x, area-downsample, then the walk's binarise and see-through speck fill.

## Scores (idle f00, same metric as the walk: `bastion/v2/scripts/bastion_metric.py`, unchanged)

| | look | ssim upper / lower | iou | palette | height vs idle | metric motion (idle vs its clay) |
|---|---|---|---|---|---|---|
| S | **85.9** (PASS ≥ 85) | 0.968 / 0.596 | 0.806 | 0.980 | 0.974 | 100 |
| E | **88.1** (PASS ≥ 85) | 0.985 / 0.654 | 0.834 | 0.988 | 0.974 | 100 |

For reference, the LOCKED walk scores S 88.6 and E 87.8. The S gap is the lower body:
- the idle stance legs are the blockout's, not the target's stride;
- the body is 2.6% shorter than the clay idle, because the walk's dy is kept.

## Checks (`qa.json`)

- **Format:** all 114 frames are 512x360, with alpha 0/255 only and RGB 0 under alpha 0.
- **Inside:** 0 px lost outside the cell in every frame. No frame touches the border. The widest union is death E at x 3–363, and the lowest row is hit S at y 354.
- **Frame counts:** every action and facing matches the blockout.
- **Planted feet:** 0.00 px in every pair of frames where the blockout heel and toe stay put. The exception is death, where the L foot moves 0.20 px (S) and 0.18 px (E).
- **arm_stretch:** arm bones 0.85–1.15 (max 15.0%). The dagger is part of the forearm piece. Legs ≤ 1.085.
- **Angles:** hit recoil 23.0° (S and E), head snap 13° (S) / 12° (E), death lie +55° (S) / −64° (E), death lift 0 px.

## Open issues (honest list)

- **The S death reads as a huddle more than a body lying flat.**
  - The lying key is the front painting turned +55° on the blockout's knees-up legs, so the knees bunch under the cloak.
  - There is no painted lying-down figure, and the boots are rotated, not painted lying down.
  - The E death (on his side, cloak over him) reads better.
- **The death direction changed from the approved poses.**
  - Approved: the S death falls straight back (up-left), and the E death falls toward the camera.
  - Here both fall to his left. E has to: straight back leaves the cell.
  - For S, the painted cloak trails far to the left. Falling back, head left, it hangs below the ground, and a 55 px lift was needed. Falling to his left, he lands head up-right and the cloak spreads behind him.
  - Mauro has not seen this change.
- **The lying cloak swings up to 40°** (lower panel, death S f10–f12 and E f10–f12). At that angle the feathered hip band bends visibly. It still lies on the ground and is not squashed.
- **The raised-key reflection pops.** When an arm passes 100° from its painting, the piece flips to its reflected key in one frame. This happens in attack S f01→f02, attack E f00→f01 and skill S f02→f03. The dagger's curve flips with it.
- **E left arm** is a darkened mirror of the right arm. It is hidden at rest, but in attack E f01–f05 both daggers show, and the left one is visibly the same painting.
- **No torso twist.** The body is the rigid target painting with a 2D lean. The cross-high wind-up has no shoulder turn.
- **S attack f02–f04:** the screen-left arm crosses in front of the hood, so the dagger covers part of the face. This is the cross-high pose of the blockout.
- **The cloak in strikes:** in attack S f05–f10 and skill S the long cloak streams out flat to the left (lag plus a 22–32° lean). It is readable, but more wind-blown than the target.
- **Hit recoil scale-up:** 23° is the rig scaling the blockout's −21°/−19° (after `aimfix` deepened the lean to −24). The legs stay planted, so it is a recoil of the upper body, not a knock-back.
- **S idle look margin:** 85.9 against the 85 bar.
- **E arm keep-in:** in death E f10–f12 the left (mirrored) arm is turned 12–19° about the shoulder so its dagger stays inside the left edge.

### Frames I'm unsure about

- death_S f06–f12: the lying key on its side, and the knees bunched under the cloak.
- death_E f10–f12 and death_S f10–f12: the cloak's lower panel turned 40° onto the ground.
- attack_S f02–f04 and attack_E f01–f05: the raised (reflected) arm keys, and the mirrored E left arm.
- hit_S f02–f03: the cloak swung back 10–14° to stay inside the cell bottom.

## Blockout issues (reported, not changed on `claude/class-walk-blockouts`)

1. **Strike direction:** in `actions.py` the double slash spreads both arms 45–60° to the sides, so the strike goes across the facing. Fixed here in `aimfix` (`STRIKE`).
2. **S lunge:** the forward step goes toward the camera. `aimfix` steps forward-inward (`step_in`).
3. **E death falls toward the camera** (straight back) and leaves the cell (the approved clay's E death reaches the cell bottom). `aimfix` makes him fall to his left, on S as well (see Open issues).
4. **Hit lean:** −16 reads as a flinch on the painted body. `aimfix` uses −24 (`HIT_LEAN`).
5. **Facings never shown:** the mp4 shows only S for idle, skill, hit and death (attack has S and E). The E versions of those four are rendered here for the first time.

## How to re-run

```
cd docs/pc/art_help/class_walk_looks/gloam/actions_v1/scripts
<bpy venv>/bin/python act_blockout.py ../blockout aimfix              # clay, id, joints (Blender 4.2 as a module)
<bpy venv>/bin/python act_blockout.py ../blockout/approved approved   # the mp4 poses, for the contact sheet
python3 gacut.py                                                      # parts/
python3 garig.py --gif                                                # frames/ + gifs/ (about 2.5 min)
python3 asheets.py; python3 closeup.py; python3 run_metric.py; python3 qa.py
python3 clip.py ../gloam_actions.mp4
```

- `act_blockout.py` extracts `actions.py` and `blockout.py` from `claude/class-walk-blockouts` at `ca1a7c30` with `git archive` into `$GABLOCK_SRC` (default `/tmp/gloam_blockout_act`).
- `gwalk.py` extracts the LOCKED walk from `bdf0ff37` into `$GWALK` (default `/tmp/gloam_walk_v1`), and its blockouts (S v3.1 `42d8d7cc`, E v3 `ffbfe3a9`) into `$GBLOCK_S` / `$GBLOCK_E`.
- Fetch `claude/gloam-legs` and `claude/class-walk-blockouts` first.
- Dependencies: numpy, pillow, opencv-python, scipy and scikit-image.
