# Gloam walk v1 (Claude): painted legs on blockout v3

The Gloam walk for S and E, 12 frames each. W and N are mirrors of these two. This is a first pass for review. It is not locked.

The method is the one used for the locked Kestrel walk (`kestrel/v3_claude/`). The scripts were copied and adapted here, and Kestrel was not changed:

- **Legs.** Each leg is one continuous painted leg cut from the approved target. It runs hip → thigh → knee → wrapped boot → sole and is bent onto every frame's blockout joints with smooth 3-bone mesh skinning (hip, knee, ankle). There is no cut between hip and sole.
- **Roots and feet.** The legs hang from the target's belt hips. The boot is pinned to the blockout heel and toe.
- **Upper body.** The hood, eyes, torso, arms, daggers and cloak are the approved target itself. They are placed with one uniform scale and follow the blockout pelvis and bob.

**Blockout.** On `claude/class-walk-blockouts`:
- **S** uses Gloam **v3.1** (`42d8d7cc`), the wider S foot track (`foot_w` 1.5) that Mauro picked on 4 Oct.
- **E** uses Gloam v3 (`ffbfe3a9`), which v3.1 leaves unchanged.

**Targets.** `targets/gloam_rp_{S,E}_f00.jpg` and their alphas (approved, `c9a85564` / `c7a44f40`).

## Files

| file | what |
|---|---|
| `frames/gloam_walk_{S,E}_f00..f11.png` | 512x360 RGBA cells, pivot (256,329), binary alpha, black under alpha 0. `_build_info.json` holds the rig joints and settings for each frame. |
| `walk_S.gif`, `walk_E.gif`, `walk_W.gif` | 12-frame loops on grey 172, 60 ms per frame (the 10 ms GIF step closest to 17.144 fps). W is the mirror of S. |
| `strip_S_target_f00_f03_f06_f09.png`, `strip_E_target_f00_f03_f06_f09.png` | The approved target beside walk f00, f03, f06 and f09, full figure at the same height. |
| `legs_sheet.png`, `legs_sheet.json` | Lower body for the target and f00/f03/f06/f09 at the same figure height, with belt, knee and sole lines and the target's lines dashed. The json has every number for all 12 frames, plus skate. |
| `side_by_side_f00_f06.png` | Target, f00 and f06, full figure, S and E. |
| `feet_S_far_boot.png`, `.json` | All 12 S frames zoomed on the feet, with the far boot's visible % and the gap between the boots. |
| `s_checks_S.json`, `s_checks_E.json` | For each frame: crotch gap (background inside the legs' hull above the knees), thigh angles, the swing thigh's forward angle, and far-boot visibility. |
| `metric_S.json`, `metric_E.json` | Bastion metric (`bastion/v2/scripts/bastion_metric.py`, unchanged; the same one Kestrel's `run_metric.py` uses) against the v3 clay. |
| `s_track_options.png` | The S foot-track options for the knock-knee fix, set beside Kestrel's approved and rejected tracks (see the section below). |
| `parts/` | The cut layers: `leg_F`, `legfar_F`, `back_F`, `front_F` and `rig_F.json`. |
| `scripts/` | `gcut.py` (cut), `grig.py` (rig and render), `sheets.py`, `run_metric.py`, `boot_vis.py`, `s_checks.py`, `gcfg.json` (Gloam settings). |

## What changed from the Kestrel pipeline

- **Source leg.**
  - S uses the screen-right forward leg, which is blockout L (same as Kestrel).
  - E uses the screen-right forward leg seen from behind, which is blockout R. The E screen-left leg is hidden under the cloak in the painting.
  - `grig.SRC` maps the painted leg to its blockout side. The other side gets the same painting, darkened 10% when it is the far leg. There is no strap to paint out on Gloam.
- **Cut colours.**
  - The cloak test is purple (a* > 2.5, b* < −3.5), not Kestrel's green.
  - The fills and thigh-top shadows use Gloam's black leather (19, 17, 20).
  - There is no bow. The daggers do not cross the legs in either target.
- **Scale and height (`gcfg.json`).** The painted Gloam legs are longer than the clay legs in S and shorter in E.
  - At Kestrel's "hood on the clay head row" placement, the S stance legs had to bend 38–90°.
  - So S uses s = 0.362 and E uses s = 0.354, with the whole figure 6 px lower (`dy` 6).
  - Planted legs are then straight (7° bend), with the along-bone k at 0.91–0.97 in S and 0.95–1.10 in E.
  - The tallest walk frame now matches the idle height exactly (`height_vs_idle` 1.000). Hood on the clay row gave 1.026, because the clay walk frames are taller than the clay idle.
- **Toe-off pin.** The painted foot is longer than the clay foot, so its length scale is clipped. While the heel is pinned, the painted toe therefore does not sit on the blockout toe.
  - At toe-off, the toe is now pinned where the painted toe was on the last flat frame.
  - This removed a 2.4–3.3 px toe slide at the heel → toe pin switch. Skate is now ≤ 0.56 px.
- **Kestrel lessons applied from the start.**
  - `crotch_fill`: dark under-cloth between the thighs above the knee. Its lower edge is ragged (`crotch_rag` 5 px), so it never ends on a straight knee row.
  - `thigh_fwd_max` 25° on S and E.
  - Cut specks: small see-through holes between cloak strands where the removed leg was are closed with the same dark fill.
- **Swing clearance keys (`swing_keys`, S only).** These are per-frame offsets of a swing foot, used only on frames where that foot is not planted, so nothing skates.
  - L f02 (−8, −8): the heel trails up and back after toe-off.
  - L f03 (0, +4).
  - Keys on the R swing at f10/f11 were tried and dropped: f11 still did not reach 60%, and they moved the metric's support sole by 13 px.
- **Knee line on the E target.** On the E target, the lowest sole belongs to the hidden back leg, whose knee is under the cloak. The target knee line is therefore measured against the painted leg's own sole. The walk frames already use the lowest leg's knee and sole.

## Scores (Bastion metric on the v3 clay)

| | look | ssim upper / lower | iou | palette | height vs idle | bob err | motion | sole_err per frame (px) |
|---|---|---|---|---|---|---|---|---|
| S | **88.6** (PASS) | 0.989 / 0.542 | 0.810 | 0.980 | 1.000 | 0 | 83.3 | 0.42 0.38 0.09 1.04 0.22 0.54 1.72 0.33 0.17 0.45 5.57 10.26 |
| E | **87.8** (PASS) | 0.975 / 0.574 | 0.775 | 0.979 | 1.000 | 0 | 91.7 | 3.41 1.02 1.77 1.44 1.40 0.86 1.33 1.24 1.36 1.29 1.58 0.10 |

Motion misses:

- **S f10 and f11.** The metric takes the R foot as support because it is lower on screen, but R is the swing foot there. The 25° thigh clamp moves that swing foot about 4 px.
- **E f00.** Toe-off: the metric's sole point is the boot toe corner.

The real skate on planted heels and toes is ≤ 0.56 px (`legs_sheet.json` → `skate`).

## Checks

- **Proportions against the target, all 12 frames.**

  | | thigh/shoulder | boot/shoulder | belt→sole | knee line |
  |---|---|---|---|---|
  | S | −0.8 to +0.9% | −1.7 to +0.8% | −0.8 to +2.0 pts | −1.5 to +2.3 pts |
  | E | −0.7 to +0.7% | −0.9 to +1.5% | −1.6 to +1.2 pts | −1.5 to +1.3 pts |

- **Crotch.** 0 background px between the thighs above the knee on every S and E frame.
- **Swing thigh.** At most 25.0° forward on every frame (S: f02–f04 and f09–f11 are clamped to 25).
- **Skate.** S 0.56 px max, E 0.53 px max.
- **Stance.** Planted legs bend 7° on every S and E frame, and 9.5° at S f06 (`stance_kmin` 0.82 on S: the late-stance legs foreshorten along the bone, down to k 0.82, instead of bending).
- **Facing.**
  - S: the hood and the two violet eyes face down-right, toward the travel direction, on every frame.
  - E: the back of the hood faces up-right.
  - Both are the approved target's head, unchanged.

**Far boot visible share, S** (`feet_S_far_boot.json`):

| f00 | f01 | f02 | f03 | f04 | f05 | f06 | f07 | f08 | f09 | f10 | f11 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 68.9 | 69.3 | 68.6 | 84.2 | 100 | 100 | 100 | 100 | 100 | 99.5 | 88.3 | 67.0 |

## Review round 2: S on blockout v3.1 (Mauro's pick, foot_w 1.5)

- **Blockout.** Gloam v3.1 (`42d8d7cc`) changes S only (clay, ID and the `idle_S` / `walk_S` joints). E stays on v3.
- **S settings** (`scripts/gcfg.json`):
  - `stance_kmin` 0.82. Late stance foreshortens along the bone instead of bending, so planted legs sit at 7°, with 9.5° at f06.
  - Swing clearance keys (swing frames only, so nothing skates):
    - L f02 (+6, +6): the foot comes through a little early.
    - R f10 (−3, −3) and f11 (−6, −6): the swing foot trails slightly before heel strike, which uncovers the planted far boot.
  - `speck_px` 20: cloak specks up to 20 cell px are filled.
- **Shins.** They no longer cross below the knee on any S frame.
- **Far boot.** At least 67% visible on every S frame (table above).
- **Skate.** At most 0.56 px.
- **Motion cost.** The R keys move the metric's support sole on f10 and f11 (5.6 and 10.3 px), because the metric picks the lower foot (the swing foot) as support there. Motion stays 83.3.
- **What is left.**
  - The S track is wider than Kestrel's approved one: at contact the feet sit nearly side by side at f06/f09. This is the option Mauro chose.
  - One painted cloak hole (about 64 cell px, in the left cloak tatters, also present in the approved target) is kept as part of the design.

## Review round 1: E specks fixed, the S track is still open

**E specks (fixed).** `speck_px` in `gcfg.json` (E 10 px, S 4 px) fills enclosed background islands up to that size in the final cell, coloured from their opaque neighbours. Larger enclosed gaps (between the two legs below the knee) are kept. The strips and the legs sheet now tile the shipped cell frame, so they show exactly what the GIFs show.

**S knock-knee: blockout track sweep (no blockout committed).** I rendered Gloam S at `foot_w` 0.3, 0.5, 0.65, 0.9 (the current v3), 1.2, 1.35, 1.5, 1.65 and 1.8, rigged each one, and checked three things:

- **(a) Shins crossing** below the knee.
- **(b) Far boot** visible on every frame.
- **(c) Sideways splay.** This is the angle of the front heel minus the back heel at the contacts, against the 27° travel diagonal. Kestrel v3.2 (approved) is 41° / 27°. Kestrel v3.1 (rejected, splayed) is 78° / 9°.

| foot_w | shins cross (a) | far boot min (b) | contact angle f00 / f06 (c) |
|---|---|---|---|
| 0.3–0.65 | f00–f03 (and f11) | 20–37% | closer to the diagonal |
| 0.9 (v3 now) | f00–f02, f11 | 23% | 66° / 14° |
| 1.2 | none | 39% | 77° / 10° |
| 1.5 (+ f02 swing key, straight late stance) | none | 48% (f11) | 88° / 6° |
| 1.65 (same) | none | 61% (f11) | 92° / 5° |
| 1.8 | none | 79% | 96° / 3° |

- **The conflict.** Every track that passes (a) and (b) is splayed sideways at least as much as the rejected Kestrel v3.1, because the lateral foot offset projects onto the screen's down-left / up-right axis. The current v3 track is already at about Kestrel v3.1's angle.
- **Why narrowing doesn't help.** A narrower track brings the feet back to the diagonal, but the legs hang from the wide painted belt hips, so the shins cross and the far boot hides.
- **So I committed nothing.** No track meets all three conditions, so there is no Gloam blockout v3.1, and S is unchanged on v3.
- **The options sheet.** `s_track_options.png` shows Kestrel v3.2 and v3.1 next to Gloam v3, 1.5 and 1.65, rigged.
- **Late-stance bend.** Straightening the late-stance knees on v3 (`stance_kmin` 0.82) lowers the far boot to 25% (f00) and 13% (f11), so it is not applied on v3. With a 1.5 or 1.65 track, all 12 planted legs come out straight (7°).

## Open issues (honest list)

1. **(Round 1, fixed in round 2 on v3.1.) The far boot was below 60% on S f00, f01, f02 and f11.** The blockout's S plants cause this:
   - The trailing L foot is planted, or has just left the ground, directly behind the near R shin. The L leg crosses behind R below the knee (an X).
   - The clay itself shows only 35%, 36%, 28% and 25% of the L boot on those frames (ID map: L boot pixels against the fully visible L boot at f08).
   - f00 and f01 have both feet planted, so nothing can move without skating.
   - On f02 (L swing) and f11 (R swing), clearance offsets up to 8 px reach only 47–49% and 46%. Reaching 60% needed 16–18 px jumps in a single frame.
   - Changing the hip width does not fix it: widening to 1.6× gains at most 10 points (f11 to 35%), and narrowing makes it worse.
   - The S track is not too wide; the legs do not splay. It is narrow enough that the feet stack. Fixing it needs a blockout change to the S foot plants (the Kestrel v3.2-style track fix), so I have not hacked the foot offsets.
2. **The painted leg length does not match the clay.** S legs are long and E legs are short against the clay. Scales of 0.362 (S) and 0.354 (E) with a 6 px lower body fit them, but this means:
   - E stance k runs up to 1.10, the stretch limit (f04, and 1.08–1.09 at f02, f03 and f10).
   - S late-stance legs are compressed along the bone down to k 0.82 (f06, f11) to stay straight.
3. **(Fixed in round 2 on v3.1.) Legs crossed below the knee in S f00–f03 and f10–f11 on the v3 track.** The depth order follows the blockout ID maps.
4. **The upper body is rigid.** The arms, daggers and cloak do not swing or lag. This is the same as Kestrel.
5. **One source leg per side.** Both legs are the target's one fully visible leg; the far copy is 10% darker. Toe-off and swing boots are the painted contact boot rotated, not separately painted heel-up boots.
6. **Leg axis against the target's back leg.** The target's back leg is posed far back: −21° in S and −30° in E, with the foot up in toe-off. The walk's back leg sits 12–34° more upright. It follows the clay plants, and no axis rule was set for Gloam.
7. **Small see-through gaps below the knees.** A few pixels show where the two legs touch or cross below the knee line (S f00, f01, f03–f05). This is allowed by the "above the knee" rule.
8. **E `look_hold_upper` drops to 0.90 at f03.** Only f00 is scored, but the upper SSIM against the target moved with the pelvis is lowest on the passing frames.

## How to re-run

```
cd docs/pc/art_help/class_walk_looks/gloam/v1_claude/scripts
python3 gcut.py            # parts/
python3 grig.py --gif      # frames/ + walk_{S,E,W}.gif
python3 sheets.py          # legs_sheet.png/.json, side_by_side_f00_f06.png, strip_{S,E}_target_f00_f03_f06_f09.png
python3 run_metric.py      # metric_{S,E}.json
python3 boot_vis.py S ../feet_S_far_boot.png
python3 s_checks.py S ../frames ../s_checks_S.json; python3 s_checks.py E ../frames ../s_checks_E.json
```

- **Blockout files.** The blockouts are extracted with `git archive` on the first run: S from `42d8d7cc` into `$GBLOCK_S` (default `/tmp/gloam_blockout_v31`) and E from `ffbfe3a9` into `$GBLOCK_E` (default `/tmp/gloam_blockout_v3`). Fetch `claude/class-walk-blockouts` first.
- **Dependencies.** numpy, pillow, opencv-python and scikit-image.
