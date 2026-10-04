# Mender actions v1: idle, attack, skill, hit and death

> **LOCKED, 4 Oct 2026, at `73e4d7bd`.** Mauro: "Lock all three". These frames ship as they are. Every rough spot and every change from the approved poses is listed in this README's open-issues section for a future pass. To change anything, re-run `scripts/` from the same pipeline; don't hand-edit frames.

The Mender's combat actions for S and E, painted with the same part-rig method as the LOCKED Kestrel and Bastion actions (`../../kestrel/actions_v1`, `../../bastion/actions_v1`). W and N are the game-side mirrors of S and E. This is the first pass for review. It is not locked.

Every part is cut from the approved look targets `targets/mender_rp_{S,E}_f00` (repaint `3250c2ba`). The cut starts from the LOCKED Mender walk's own layers (`mender/v1_claude` at the lock commit `08ea869b`, on `claude/mender-legs`), which are read-only here.
- The parts are bent onto the action blockout of `mender/mender_actions.mp4`.
- Nothing is repainted frame by frame.
- The walk folder is not copied into this branch. The scripts extract it with `git archive` (see How to re-run).

## Files

| file | what |
|---|---|
| `frames/<action>_{S,E}_fNN.png` | 512x360 RGBA cells, pivot (256,329), binary alpha, black under alpha 0. `_build_info.json` holds the rig numbers per frame: torso tilt, twist, head snap, skirt lag, leg k, arm k, staff turn / slide, lantern swing and the death fall. |
| `gifs/<action>_{S,E}.gif` | On grey 172, 60 ms per frame (the 10 ms GIF step nearest 17.144 fps). Death holds its last frame. |
| `contact_{S,E}.png` | Every frame of every action, in three rows: the painted frames, the blockout clay they are rigged on (aim fix), and the approved blockout clay (the `mender_actions.mp4` poses). |
| `closeup_keys.png` | The key frames at 2x, S over E: idle f00; attack f04, f06, f07 and f09; skill f03 and f06; hit f02; death f03, f08 and f12. |
| `mender_actions.mp4` | All 5 actions in all 4 facings, one facing at a time, then each action with S/E/W/N side by side. A copy is at `scratchpad/kclip/mender_actions.mp4`. |
| `metric_idle_{S,E}.json` | Look score of idle f00 against the target (see Scores). |
| `qa.json` | Format, inside-the-cell, frame-count, planted-feet, `arm_stretch` and leg-k checks (`scripts/qa.py`). |
| `blockout/` | The action blockout at the house cell: `clay/`, `id/` and `joints_actions_512.json`, from `scripts/act_blockout.py` in `aimfix` mode. `blockout/approved/` holds the same render in `approved` mode (`actions.py` exactly as in the mp4). |
| `parts/` | The cut parts (`scripts/mcut_act.py`):<br>• `back_F` and `front_F`: the walk's body layers minus the arms, staff and lantern, with the holes filled from robe paint.<br>• `wbody_F`: body skin weights.<br>• `uarm_{R,L}_F` and `fore_{R,L}_F`: sleeve, forearm and fist/hand pieces.<br>• `drape_R_E`: the E right bell sleeve.<br>• `staff_F` and `lantern_F`: the rigid staff and lantern.<br>• `mjoints_F.json`: joints in target px. |
| `scripts/` | `act_blockout.py` (bpy), `mcut_act.py`, `marig.py`, `asheets.py`, `closeup.py`, `run_metric.py`, `qa.py` and `clip.py`. |

## Frame counts (from the blockout, `actions.py` lengths)

| action | frames | loops | notes |
|---|---|---|---|
| idle | 12 | yes | f00 is the walk's upper body on the stance legs. The chest rises, the staff arm settles and the lantern sways a few degrees. |
| attack | 12 | starts and ends on idle f00 | The lantern swing:<br>• f04: wind-up, staff arm back, torso twisted;<br>• f06: strike;<br>• f07–f09: the staff swept out along the facing with the lantern at the crook end;<br>• f11: back to rest. The right foot steps in (forward and inward). |
| skill (heal) | 12 | starts and ends on idle f00 | The staff is lifted at his side and the lantern raised above shoulder height, from f03, held f04–f09. The free hand is open toward the ally (forward). No effects are painted; they are separate. |
| hit | 8 | starts and ends on idle f00 | A 22° recoil with a 10° head snap (f02), the robe skirt lags, then he recovers. |
| death | 13 | no (holds f12) | The knees go (f00–f03), he falls (f04–f09) and lies flat (f10–f12). |

## Method (per frame, `scripts/marig.py`)

**Body.** The body is the walk's `back_F` and `front_F` with the arms, staff and lantern removed. It is skinned on one triangle mesh with 4 affine bones and feathered weights (`wbody_F`), so there is no cut anywhere.
- **base:** one similarity at the walk's scale s (S 0.372, E 0.368). Its rotation and along-axis foreshortening follow the change of the blockout pelvis→neck axis since idle f00. The pin is the painted hip centre, which follows the blockout pelvis.
  - Idle f00 uses the walk's placement rule: x on the hip centre, hood top on the clay's head-top row plus dy.
- **upper:** the torso twist. The blockout shoulder line's foreshortening (cyaw in the attack, 0.85–1.10) is applied to the upper body about the neck.
  - The twist belongs to the torso. The arms are separate pieces that hang in the facing frame (aimfix), so the staff swing stays on the facing line.
- **head:** a rotation of the hood and face about the neck. This is the hit's head snap.
- **skirt:** the robe below the belt turns about the hip line with an exponential lag behind the torso, plus a pelvis-velocity trail. It is clamped at 8°. The idle adds a slow ±0.6° sway.
- **Hit:** the blockout recoil (lean −16°, about 10° on screen) is scaled so the painted torso recoils 22° at f02.

**Legs.** These are the walk's continuous painted legs (`leg_F`, `legfar_F`) on the walk's 3-bone mesh skin (knee blend 24, ankle blend 14).
- The hips are on the painted hip line.
- The boot is a rigid similarity on the blockout heel and toe, pinned at the heel, so a planted foot only moves when the blockout foot moves.
- The knee is 2-bone IK at the painted lengths, with k from 0.82 to 1.10 along the bone. The far leg is 10% darker.

**Arms.** Each arm is two rigid painted pieces: the robe sleeve (shoulder → elbow) and the forearm with the fist or hand. They are posed by FK from the painted shoulder on the upper body bone.
- Each bone keeps its painted length times the blockout's projected length change, clamped to ±15%.
- Each bone turns by the blockout bone's change of screen angle since idle f00. When the key is posed, it blends to the blockout bone's own direction (Bastion's `turn`).
- A raised arm is the painted sleeve and fist turned. A hanging arm is never stretched.
- The sleeve part hidden under the mantle is grown from the sleeve's own painted section, so a moved arm shows no gap at the shoulder.
- **E right bell sleeve:** it is its own piece, hinged on the forearm. It turns only 35% of the forearm's turn, so it hangs.
- **Skill, staff arm:** the arm goes straight from the painting to the f06 hold, each bone turning by the progress times its hold turn. On S the hold opens 55° (sleeve) and 32° (forearm) outward on screen, and keeps the painted arm length.
  - The blockout path raises the arm forward through the camera line. On S that put the fist and lantern across the face for three frames.

**Staff.** The staff is one rigid piece (shaft and crook) held in the fist. Its grip rides on the painted forearm.
- It turns like the blockout staff (grip → top, using `staff_fix` in `act_blockout.py`).
- **Skill:** it stays near-upright, with the top tipped 14° (S) or 8° (E) toward the facing.
- **Hit and the death buckle:** it tilts with the recoil. On S it tilts with the body (×0.8). On E it leans away (×−0.6), because the fist is pulled back toward the camera about 40 px.
- **Floor:** a near-upright staff whose butt would go through the floor slides up through the fist (at most 40 px), so the butt stays on the ground. Otherwise it tips the least way that keeps it in the cell. No frame needed the tip.

**Lantern.** The lantern is rigid (cage, chain and, on S, the vines) and hangs from the crook tip.
- It swings as a damped pendulum driven by the hook's motion.
- In the looped actions the swing starts from rest and settles over the last 3 frames, so every action chains on idle f00.

**Death.**
- **f00–f03:** rigged. The knees go and the arms are thrown out.
- **From f04:** the f03 figure falls as one painted key. Its painting plane turns onto the iso ground with the blockout tilt (0 → 86°) and pivots at its feet.
  - At 86° the painting's up axis lies along the ground direction up-left, at ×0.91 (the walk camera's ground foreshortening). Its width lies across the ground.
  - The robe keeps its full painted length. It is never squashed toward a hinge.
  - **S** lies on his back (front painting). **E** falls to his left side and lies prone (back painting). Both fall up-left, the approved S path.
  - The staff and lantern are their own layer. They slip 10 px from his side and lie flat with him: in front of him on S, behind him on E.
  - **E:** the fall pivots on his planted left boot, which the blockout keeps on the ground through the side fall. That leg is re-skinned every frame from the falling hip to the planted boot.
  - **S:** an eased in-cell shift of (+13, −7) px keeps the lying figure inside the cell. He lands 13 px right of and 7 px above the blockout spot. Nothing is lifted.

**Draw order (back to front).**
- **S:** back, legs, front, free arm, lantern, staff, staff arm (the fist is over the staff).
- **E:** the same layers, plus:
  - the staff forearm and fist go behind the body when the blockout depth says so (attack f06–f10);
  - the free arm goes behind once it is raised forward (skill).

**Output.** Each frame is rendered on a padded canvas at the cell scale from premultiplied Lanczos-prescaled textures, then binarised.

## Rules applied from Kestrel and Bastion

- **The strike and the cast go along the facing.** S is down-right and E is up-right.
  - `act_blockout.py` `aimfix` hangs the arms in the facing frame. The torso twist stays the torso's.
  - The attack staff sweeps out along the facing: S to the screen right and slightly down, E up-right.
  - In the skill the staff top tips toward the facing and the free hand reaches along it.
- **Every frame is inside the 512x360 cell, death included.**
  - E death falls to his side instead of toward the camera (the approved straight-back fall leaves the cell).
  - No frame loses a pixel. No figure touches the cell border. The widest union is death S at x 3–337, and the lowest row is death S at y 357.
- **The raised and casting arms are painted keys from the target.** They are the painted sleeve, bracer and fist turned. The staff with its crook and the green lantern are rigid painted pieces held in the fist.
- **Arm stretch** is within ±15% on every frame (see Checks).
- **Holes are filled from real robe texture.** The areas behind the arms and staff are copied from shifted patches of the same robe painting (`patch_fill`), with a 1.5 px seam feather only. The action cut adds no smooth fill and no Telea. The walk's own S slit fill inside `back_S`, from the locked walk, is unchanged.
- **Death has a lying-down key.** The robe lies flat at its full painted length, not squashed.
- **The hit has a clear recoil (22°) and a 10° head snap.**
- **The head faces the action direction.** It is the target's head: S faces down-right and E's hood faces up-right.

## Changes from the approved blockout (`actions.py` and `mender_actions.mp4`; the approved files are not changed)

1. **Aim.** The attack and skill arms are in the facing frame (aimfix). In `actions.py` the arms hang in the torso frame, so the attack's cyaw (−18° at the wind-up, +16° at the sweep) turned the staff sweep 16–18° off the facing.
2. **Attack step-in.** The step goes forward and inward (0.6 forward and 0.4 inward) instead of straight toward the camera.
3. **E death** falls to his left (world −X). Straight back leaves the cell.
4. **Continuous staff (`staff_fix`).** `actions.py` switches the staff from upright to along the forearm in one frame, and to −forearm when the forearm points down. That flips the staff by up to 130° between two frames (attack f05→f06, skill f10→f11). Here the two directions are blended with a smoothstep over shoulder angle 20–60°.
5. **Skill staff arm.** The arm takes a direct path to the hold. On S the hold is opened outward. The staff stays near-upright. The blockout swings the staff through horizontal (attack-like) at skill f02, which read as a strike.
6. **Hit staff and recoil.** The staff tilts with the recoil and doesn't follow the thrown-out fist. The torso recoil is scaled to 22°.
7. **Death from f04** is the painted lying key turned onto the ground, not the blockout's thrown-back arms and knees-up legs.
8. **Facings never shown.** The mp4 shows only S for idle, skill, hit and death (attack has S and E). The E versions of those four are new here and have not been approved.

## Scores (idle f00, same metric as the walk)

`scripts/run_metric.py` runs `bastion/v2/scripts/bastion_metric.py` unchanged, which is the metric the LOCKED Mender walk was scored with. It uses the same binary target-alpha copy. The 12 idle frames and the idle clay are linked under the metric's frame names, and the idle joints are its `walk_F`.

| | look | ssim upper / lower | iou | palette | height vs idle | bob err | metric motion |
|---|---|---|---|---|---|---|---|
| S | **88.4** (PASS) | 0.948 / 0.649 | 0.858 | 0.916 | 1.000 | 0.5 | 100 |
| E | **87.3** (PASS) | 0.965 / 0.768 | 0.861 | 0.983 | 0.951 | 4.08 | 50 |

- **E motion 50.** This has the same cause as the walk's E motion (8.3). The metric's `head_top` reads columns 200–312, and the idle clay's staff crook is inside that window, so it is read as the head. The painted staff stays outside the window. The same crook sets the idle top, so `height_vs_idle` reads 0.951.
- **E dy.** E uses dy −1.0, where the walk uses −2.0. The E score is sensitive to 1 px: at the walk's s 0.368, the 1-px dy/dx sweep scored from 82.2 to 87.3. dy −1.0 is the robust choice; its ±1 px x neighbours score 85.8 and 85.9.
  - The cost is that the E idle sits 1 px higher than the E walk f00. This is a 1 px step at the walk↔idle switch.
  - Changing s instead would have been a 2–3 px size pop.

## Checks (`qa.json`)

- **Format.** All 114 frames are 512x360 with alpha 0/255 only and RGB 0 under alpha 0. Nothing lands outside the cell and nothing touches the border.
- **Frame counts.** Every action and facing matches the blockout.
- **Planted feet.** In every pair of consecutive frames where the blockout heel and toe stay put, the painted heel and toe move 0.00 px. The one exception is the E death planted boot, at **0.24 px**.
  - In idle, skill and hit both feet are planted throughout.
  - In the attack the right foot steps (5 pairs move).
  - In death the blockout moves the feet from f03 (S both, E right). E's left boot stays planted to the end.
- **`arm_stretch`.** Every arm bone is between **0.85 and 1.15** of its painted length (max |15.0%|), on the clamp.
  - Idle stays in 0.98–1.02.
  - The attack, skill and hit reach the clamp: S skill sleeve 0.87–1.15, E attack, skill and hit 0.85–1.15.
  - The staff, lantern, bell sleeve and every arm piece are otherwise rigid at the scale s.
- **Leg k.** The maximum is 0.998 on S and 1.068 on E, under 1.10. No leg falls short of its boot.

## Open issues (honest list)

- **The attack strike frame turns the staff a lot.** From f05 to f06 the staff turns about 130° on S and 67° on E in one frame, and back at f10→f11. The blockout's arm moves 55° there. At 17 fps it reads as a fast whip, but the staff and lantern pop.
- **Long staff butt in the attack.** The fist holds the staff where the painting does, a third of the way down from the crook. Swept forward, the crook end reaches only about 85 px past the fist, and the butt sticks out about 160 px behind the shoulder (up-left on S, behind him on E). There is no re-grip.
- **The staff slides in the fist.**
  - Up to 8 px (S) and 16 px (E) in the attack wind-up.
  - 7 and 15 px in the hit.
  - Up to 29 px in the E death buckle.
  - This happens wherever the butt would go through the floor. The fist does not move along the painted shaft, so the grip point changes.
- **Torso twist is foreshortening only.** The painted torso cannot turn. The attack twist is a 0.85–1.10 squeeze of the shoulder line.
- **S cast arm.**
  - It is opened 55° outward from the blockout so that the lantern clears the hood.
  - It keeps the painted length (k 1.0) where the blockout shortens it to 0.85.
  - The raised sleeve is the hanging sleeve turned. Its cuff does not fall back toward the elbow.
  - At the hold (f04–f09) the fist is beside the hood's left edge and the lantern hangs at hood height to his right side (screen left). The lantern is raised but not high overhead, because the crook must stay in the cell.
- **E bell sleeve.** When the forearm is raised (skill, attack), the bell turns only 35% of the forearm's turn. It reads as hanging, but it is a rigid piece and does not drape or fold.
- **Death lying key.**
  - It is the f03 standing painting mapped onto the iso ground (a shear). It is not repainted lying down.
  - S on his back shows the front painting, so the face is seen as if from above. The bent knees of f03 are under the robe, and the boots are the standing boots.
  - E prone shows the back painting.
  - On S, the dropped staff lies across the front of his robe.
  - The fall pivots at the feet. On S, the lying figure lands 13 px right of and 7 px above the blockout's spot to stay inside the cell.
- **Holes behind the arms.** Where the S staff arm and the free arm covered the cloak or robe, the fill is copied robe paint.
  - The silhouette under a removed arm follows the body polygon. When an arm is lifted away (skill S, hit), the shoulder outline under the mantle has a short straight edge on both facings.
  - The fill under the S staff arm repeats the cloak folds from about 45–100 px lower.
- **Lantern swing.** It is a simulated pendulum: up to 40° in the attack, 22–24° in the skill and hit, and ±4° in the idle. It has no light flare (effects are separate).
- **Hit.** The 22° recoil is the blockout lean scaled ×2.2 on screen. The head snap is a mesh rotation of the hood about the neck, over a 14–16 px feathered weight. The mantle edge under the hood bends with it at f02, rather than the head turning as a separate piece.
- **Robe.** The robe skirt turns rigidly with lag (at most 8°). The hem does not react to the knees or the attack step.
- **E metric.** E is 1 px higher than the walk (dy −1.0 vs −2.0); see Scores. The E look score swings by up to 5 points for 1 px offsets.
- **Rig points, not E-ALT poses.** These are rig points on the blockout poses. The E idle, skill, hit and death have not been approved.

### Frames to check first
- attack S/E f06 and f10 (the staff turn);
- skill S f02–f03 (the lantern passing the hood);
- hit E f02–f03 (the staff leaning out, the hand pulled back);
- death S f08–f12 (the sheared lying read, the staff across the robe);
- death E f07–f12 (prone, legs re-skinned to the planted boot).

## How to re-run

```
cd docs/pc/art_help/class_walk_looks/mender/actions_v1/scripts
<bpy venv>/bin/python act_blockout.py ../blockout aimfix [blockout_scripts_dir]       # clay, id, joints (Blender 4.2 as a module)
<bpy venv>/bin/python act_blockout.py ../blockout/approved approved [blockout_scripts_dir]
python3 mcut_act.py [debug.png]                                                      # parts/
python3 marig.py --gif                                                               # frames/ + gifs/ (about 1 min)
python3 qa.py; python3 run_metric.py; python3 asheets.py; python3 closeup.py
python3 clip.py ../mender_actions.mp4
```

- `act_blockout.py` extracts `actions.py` and `blockout.py` from `claude/class-walk-blockouts` at `ca1a7c30` with `git archive`, into `/tmp/mender_blockout_act`, unless a scripts dir is given.
- `mcut_act.py` and `marig.py` extract the LOCKED walk (`mender/v1_claude` at `08ea869b`, branch `claude/mender-legs`) into `$MWALK` (default `/tmp/mender_walk_lock`). Fetch both branches first.
- **Dependencies:** numpy, pillow, opencv-python, scipy and scikit-image.
