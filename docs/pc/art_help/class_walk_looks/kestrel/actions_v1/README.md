# Kestrel actions v1: idle, attack, skill, hit and death

This is the pilot for painting the combat actions onto the blockout motion. Bastion, Gloam, Mender and Ironjaw follow the same method.

> **Round 2 (arms fixed before lock).** The arms are now swapped painted keys, and no bone stretches more than 15% on any frame. The draw hand is a real painted fist at the cheek in S and E. The cloak behind the arms is patch-cloned from the painted cloak. The bow and string are traced on the painting. Hit has a 22–24° recoil with a head snap, and the E death cloak drapes on the ground. Close-ups are in `closeups.png`.

It uses the same painted-part rig as the LOCKED walk (`../v3_claude`, locked at `1abc051`). Every part is cut from the approved look target (`targets/kestrel_rp_{S,E}_f00.jpg`). Each part is bent onto the blockout joints with smooth mesh skinning. Nothing is repainted frame by frame, and the walk frames in `../v3_claude/frames/` are not touched. The legs reuse the walk's cut parts read-only: `leg_F`, `legfar_F`, `back_F` and `front_F`.

## Files

| file | what |
|---|---|
| `frames/<action>_{S,E}_fNN.png` | 512x360 RGBA cells, pivot (256,329), binary alpha, black under alpha 0. `_build_info.json` holds the rig numbers per frame (torso angle and foreshortening, cloak angles, leg k, arm stretch, death lift). |
| `gifs/<action>_{S,E}.gif` | On grey 172, 60 ms per frame (the 10 ms GIF step nearest 17.144 fps). Death holds its last frame. W and N are the game-side mirrors of S and E. |
| `closeups.png` | Close-up strip at 3x: idle S f00, attack S f05, skill S f06, hit S f03, idle E f00, attack E f05 and death E f12. |
| `contact_{S,E}.png` | Every frame of every action. Three rows per action: the painted frames, the blockout clay they are rigged on, and the approved blockout clay (the `kestrel_actions.mp4` poses). |
| `kestrel_actions.mp4` | All 5 actions in all 4 facings, one facing at a time, then each action with S/E/W/N side by side. A copy is at `scratchpad/kclip/kestrel_actions.mp4`. |
| `metric_idle_{S,E}.json` | Look score of idle f00 against the target (see Scores). |
| `qa.json` | House-format, frame-count and planted-feet checks (`scripts/qa.py`). |
| `blockout/` | The action blockout rendered at the house cell: `clay/`, `id/` and `joints_actions_512.json`, from `scripts/act_blockout.py` in `aimfix` mode. `blockout/approved/` holds the same render in `approved` mode (`actions.py` exactly as in the mp4: clay and joints). |
| `parts/` | The extra cut parts (`scripts/acut.py`): `body_F`, `front_F`, `wcape_F` (cloak and head skin weights), `arm_{R,L}_F` (the arms as painted), `sleeve_F_{bow,draw}` and `fore_F_{bow,draw}` (the arm-key sources), `cover_F_{R,L}` (shoulder covers), `bow_hang_F`, `bow_aim_F` and `arig_F.json`. |
| `scripts/` | `act_blockout.py` (bpy), `acut.py`, `arig.py`, `asheets.py`, `run_metric.py`, `qa.py` and `clip.py`. |

## Frame counts (taken from the blockout, `actions.py` lengths)

| action | frames | loops | notes |
|---|---|---|---|
| idle | 12 | yes | f00 = the walk's upper body on the stance legs. The chest rises and the bow arm settles. |
| attack | 12 | starts and ends on idle f00 | f00 rest, f03 raised, f06–f08 full draw, f09 loose (string snaps straight, arrow gone, draw hand flies back), f12 = rest. |
| skill (Mark Shot) | 12 | starts and ends on idle f00 | Aims 35° high. Raised by f04, held to f09, loosed at f10, back to rest. |
| hit | 8 | starts and ends on idle f00 | Recoil back with the arms thrown out, then recover. |
| death | 13 | no (hold f12) | The knees go, she falls and settles lying down. |

W and N are mirrors of S and E, game-side.

## Method (per frame, `scripts/arig.py`)

- **Torso.** `body_F` is the target minus the legs, both moving arms and the bow, with the holes filled.
  - The fills are patch-cloned (round 2). Each hole is filled in 40 px tiles from the best-matching offset copy of the clean painted cloak (at least 96% of the source tile on cloak), Poisson-blended into the hole's border with `cv2.seamlessClone`. The cloak keeps its brush texture. Only slivers under 150 px use Telea.
  - Cloak cloth hanging over an arm inside its outline stays with the body.
  - An arm that hung over background leaves background. Only its part over the body (`fill_poly`) is filled, so the torso edge under it is a drawn contour, never a straight cut.
  - The bow and string removal follows the traced lines (see Bow).
  - It is placed by one similarity: the walk's scale s (253/686 S, 247/665 E), plus a rotation and an along-axis foreshortening.
  - The rotation and foreshortening follow the change of the blockout's pelvis→neck axis since idle f00. This is the torso tilt for hit and death.
  - The pin is the painted hip centre, which follows the blockout pelvis.
  - At idle f00 the placement is the walk rule: x on the hip centre, hood top on the clay's head-top row.
  - The head is part of the torso painting, so it faces the facing direction. The S face looks down-right and the E hood up-right, which is also the aim direction under the rule below.
- **Cloak.** Two panels with lag, on the same mesh, with feathered weights (`wcape_F`), so there is no cut.
  - The upper panel turns about the shoulder and the lower panel about the hip line.
  - Each panel follows the torso angle with an exponential lag and trails the pelvis velocity. The lower panel lags more.
  - Idle adds a slow sway. Loops are simulated three times so the cycle closes.
  - In the S death the cloak folds toward its hinges, and nothing hangs below the body's lowest contact.
  - In the E death (round 2) both panels are laid into the ground plane (iso: the painted 'down' along the ground toward her feet at half height, the 'across' along the ground, spread 15%), pinned at the shoulders and blended in as she falls. The cloak drapes on the ground instead of squashing.
- **Head (round 2).** It is a fourth, feathered bone on the body mesh. In hit it snaps 9° back at f02 and settles by f06. Hit also multiplies the blockout torso angle by 1.75 (−24° S and −22° E at f02); f00 and the last frame stay idle.
- **Legs.** These are the walk's continuous painted legs on the walk's 3-bone skin (`krig.mesh`).
  - The feet lie on the blockout heel and toe joints, pinned at the heel. A foot moves only when the blockout foot moves.
  - The knee is 2-bone IK at the painted lengths, k 0.90–1.10.
- **Arms: painted keys swapped by phase (round 2).** Every frame uses a painted key whose upper sleeve and forearm are within ±15% of the length that frame needs. The worst frame is 15.0% (`qa.json` → `arm_stretch`).
  - **Hang.** The arm exactly as cut from the target, shoulder → elbow → bracer → fist, on a 2-bone skin with an elbow blend of ±16 target px (no elbow seam). It is used while both its bones fit: idle, most of hit, and the start of death.
  - **Keys.** Each key is one continuous texture with no seam at the elbow. The upper part is a crop of `sleeve_F_role`: the painted visible sleeve, straightened and extended from random crops of its own folds, never mirrored or stretched. Upper keys run 0.41–2.44x the painted upper arm in 1.25x steps. The lower part is a crop of `fore_F_role`: the painted forearm + fist. Forearm keys run 0.40–1.0x, cropped from the elbow end. The forearm fades in over the sleeve end; a short (foreshortened) forearm ends in a rounded cuff in shadow.
  - **Bow arm keys.** The bow arm (her right) uses the target's own bow forearm and fist.
  - **Draw arm keys.** The draw arm (her left) is the painted left bracer with the bow hand's closed fist, gripping the string. In E it is the same painting lit like E. It is never a mirror of the bow arm.
  - **Rest frames.** The painted shoulder rides on the torso. The elbow and hand are the blockout's, carried into the painted body by the idle offset, so idle reproduces the painting.
  - **Raised frames.** Bone lengths are the blockout's projected lengths (its foreshortening), rounded to the nearest key. The elbow is 2-bone IK from the painted shoulder to the hand target, bending to the blockout elbow's side. Hit and death frames whose reach does not fit the hang arm use the same IK.
  - **Draw hand.** At full draw the nock and the draw fist sit on the painted cheek: S on her left jaw, in front of the shoulder; E at the cheek past the hood's left edge. The string meets the fist. The draw forearm is the 0.5x key, foreshortened because it points back, away from the camera.
  - **Shoulder covers.** `cover_F_{R,L}` is the pauldron or cloak over each shoulder, cut with its own ragged alpha and redrawn over the arm root.
- **Bow.**
  - **Traced on the painting (round 2).** The S string runs 9 px off the tip-to-tip chord: it was found with a thin-line response along the chord, and so was the E string. Removal uses those traces (string ±4.5 px, limbs ±12 px), plus the walk's old bow bands in the front layer.
  - Hanging (idle, hit, death): the painted bow and string are rigid with the bow forearm. This is the forearm + fist + bow piece, limbs down as in the walk rule.
  - Raised: the painted limbs are warped along the blockout bow's projected chord and belly, belly toward the aim and string toward her. The fist is drawn over the grip.
  - The string is drawn tip → nock → tip at full draw, and straight when braced or loosed.
  - In death the bow comes down with her and lies flat. It slips a third of the way from her hand toward her body.
- **Arrow.** A separate piece: an ash shaft with a lit edge, two-tone fletching and a dark iron head. It runs from the nock along the aim while drawn and disappears at the loose.
- **Draw order.**
  - S: (raised: draw arm) → body → legs → front → draw forearm + fist (raised) or the whole draw arm (rest) → pauldron → bow arm and bow → arrow → cloak cover.
  - E: draw arm (behind the cloak and quiver) → legs → body → draw forearm + fist (raised) → bow → arrow → bow arm → cover.
- **Output.** Each frame is rendered at 3x, area-downsampled, and binarised.

## Mauro's rules

- **The bow hangs limbs-down at idle.** Idle is the painted target bow.
- **The bow faces the aim when she shoots.** S aims down-right and E aims up-right. `act_blockout.py` in `aimfix` mode re-solves the attack and skill:
  - In `actions.py` the torso turns by cyaw −40° and the bow arm turns with it, so the arrow flies 40° right of the facing: straight down the screen on S and flat right on E (see `contact_*.png`, bottom rows).
  - In `aimfix` the torso stays square to the facing. The painted torso cannot yaw anyway.
  - The arrow line runs from the draw-side cheek along the facing (35° up for the skill). The bow hand sits 0.27 H out along that line and the draw hand sits on the nock, both by 2-bone IK at the blockout arm lengths.
  - Timing, lean, drop and feet are the blockout's.
- **The head faces the action direction.** It is the target head, facing S down-right and E up-right, which is the aim direction.
- **S is the front facing down-right and E is the back facing up-right.** W and N are mirrors.

## Scores (idle f00, same metric as the walk)

`scripts/run_metric.py` runs `bastion/v2/scripts/bastion_metric.py` unchanged, with the same binary target-alpha copy as the walk's `run_metric.py`. The 12 idle frames are linked under the metric's frame names, and the idle joints are fed as its `walk_F`.

| | look | ssim upper / lower | iou | palette | height vs idle | bob err | metric motion |
|---|---|---|---|---|---|---|---|
| S | **89.2** (PASS) | 0.977 / 0.601 | 0.845 | 0.954 | 1.000 | 1.08 | 83.3 |
| E | **89.7** (PASS) | 0.948 / 0.681 | 0.845 | 0.970 | 1.000 | 0.58 | 100 |

The metric's motion part compares the idle with its own clay. On S the head-top bob differs by 1.1 px in f01 and f11 (the bar is 1 px). The breathing drop is under 2 px, so a 1 px row step of the painted hood against the clay decides it; the sole errors are the walk's heel-corner effect.

## Checks (`qa.json`)

- **Format.** All 114 frames are 512x360 with alpha 0/255 only and RGB 0 under alpha 0. Every figure is inside the cell without touching an edge. The widest union is death E at x 24–321, and the lowest row is hit S and death S at y 357.
- **Frame counts.** Every action and facing matches the blockout.
- **Planted feet.** In every pair of consecutive frames where the blockout heel and toe stay put, the painted heel and toe move at most 0.24 px. Most pairs are 0.00.
  - Idle, attack, skill and hit keep both feet planted throughout.
  - In death the blockout moves the feet from f03 on. S death is also lifted 4 px from f04 (5 px at f12) so the folded hem stays in the cell.
- **Arm stretch (round 2).** The maximum deviation of any upper sleeve or forearm from its key is 15.0% (death E f12, hit E f05, death S f12). Attack and skill stay within 9%. Per frame, `qa.json` → `arm_stretch` lists the key and the stretch of each bone.
  - This is measured on the rig's heel and toe points. The boot texture is pinned to them, so the painted boot does the same.

## Open issues (honest list)

- **No torso twist.** The torso is the rigid target painting. The archer stance is square, there is no shoulder turn into the draw, and the head does not tilt up for the skill.
- **Draw fist.** The draw fist is the bow hand's fist re-used, so in S it covers part of her right jaw at full draw (attack and skill S f03–f09). In E it reads as a small dark fist beside the hood (attack and skill E f02–f09), with the arm hidden behind the cloak and quiver. A painted fist with the fingers hooked on the string would read better.
- **Key swaps.** When an arm leaves the hang painting for a key (attack and skill f01 and f11, hit S f01, death f02–f04), the sleeve texture changes in one frame. Keys switch at 1.25x steps, so the sleeve end, which sits under the shoulder cover, can jump a few pixels. The sleeve keys are straight tubes, so a raised upper arm has a uniform width with no muscle taper.
- **Fill patches.** The patch-cloned cloak behind the S bow arm is real cloak texture. A soft Poisson-blended patch remains near the right shoulder (target x 513–535, y 235–258), visible only when the arm is raised.
- **Bow detail.** The aimed bow is the painted limbs warped, with the grip under the fist filled from the wood. The drawn string is a 0.7 px line and breaks into dots at cell scale. The arrow is drawn procedurally; the target has no loose arrow to cut.
- **Hit.** The recoil is now 22–24° with a head snap. The pelvis still only moves back 0.03 H, as the blockout does, so there is no step back.
- **Death.**
  - S lies on her back as the front painting rotated by −63°. Its cloak is still a fold toward the hinges, not a ground drape: only E was asked for and redone.
  - E falls to her left side (see Blockout issues). It is the back painting rotated, so lying down you see her back and the draped cloak.
  - The legs are the blockout's knees-up pose on the walk legs, and the boots are rotated, not painted lying down.
- **Stance knees.** Stance legs sit at the k 0.90 floor in many frames (S left leg at idle), so the knees bend slightly more than in the walk.
- **S cloak shape.** The S cloak keeps the target's wind-blown sweep to the left even standing still, as the walk does.
- **Rig points, not E-ALT poses.** These are rig points on the blockout poses. Nobody has signed off the attack, skill or death E poses yet.

## Blockout issues (reported, not changed on `claude/class-walk-blockouts`)

1. **Aim direction.** The attack and skill in `actions.py` aim 40° off Mauro's rule because of cyaw −40 with the arm in the torso frame (S shoots straight down the screen, E flat right). The fix used here is the `aimfix` mode of `act_blockout.py`.
2. **E death leaves the cell.** It falls straight back toward the camera: in the walk camera the head lands at y 376 and the bow at y 510, outside the 360 px cell. The mp4 only ever showed `death_S`. `aimfix` makes E fall to her left (world −X), the same screen path as the S death, and nothing else changes.
3. **S death bow.** The blockout's S death bow string reaches y 364 (cell bottom 359). Here the bow lies flat beside her instead.
4. **Facings never shown.** The mp4 has only S for idle, skill, hit and death (attack has S and E). The E versions of those four are rendered here for the first time.

## How to re-run

```
cd docs/pc/art_help/class_walk_looks/kestrel/actions_v1/scripts
<bpy venv>/bin/python act_blockout.py ../blockout aimfix                 # clay, id, joints (Blender 4.2 as a module)
<bpy venv>/bin/python act_blockout.py /tmp/approved approved             # the mp4 poses, for the contact sheet
python3 acut.py                                                          # parts/
python3 arig.py --gif                                                    # frames/ + gifs/ (about 2 min)
python3 asheets.py; python3 closeup.py; python3 run_metric.py; python3 qa.py
python3 clip.py ../kestrel_actions.mp4
```

`act_blockout.py` extracts `actions.py` and `blockout.py` from `claude/class-walk-blockouts` at `ca1a7c30` with `git archive`, into `/tmp/kestrel_blockout_act`. `arig.py` imports the walk's `krig.py`, which extracts the walk blockouts the same way.
