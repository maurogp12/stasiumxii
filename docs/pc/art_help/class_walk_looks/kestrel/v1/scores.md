# Kestrel walk v1: hybrid rig on Claude's v2 blockouts

Built 9:58–10:30 AM ET, Oct 4 2026. The rig uses only the v2 blockout `kestrel/blockout_v2/` (clay, id, `joints_512.json`,
fetched from branch `claude/class-walk-blockouts` of maurogp12/stasiumxii). Hip 0.62 H, stride 0.32 H. Nothing was committed or pushed.
Mauro's feedback on Bastion v2 (uniform leg scale, legs rooted under the body, low swing peak) is built in. The checks are below.

## Scores

| facing | look | ssim_upper | ssim_lower | iou | palette | height | motion | bob_err | max sole err | qa |
|---|---|---|---|---|---|---|---|---|---|---|
| S | **90.1** | .990 | .679 | .896 | .934 | 1.013 | **100** | 0.83 | 1.26 px | 12/12 |
| E | **88.7** | .977 | .648 | .803 | .977 | 1.008 | **100** | 0.83 | 1.87 px | 12/12 |
| W (S mirror) | - | | | | | | | | | 12/12 |
| N (E mirror) | - | | | | | | | | | 12/12 |

**qa_walk: 48/48.** Skate max: S 0.43 px, E 0.93 px. Pivot slide max: S 0.35 px, E 0.01 px (rule below). Cape hem clearance:
S 22 px, E 26 px. Bob error: 0.83 px (whole-pixel body placement on the blockout head top).
W and N are mirrors of S and E (the bow swaps hands, as Mauro accepted).

## Legs first (legs_check.png / legs_check.json)

Target at the body scale: s_up S .3688 (253/686), E .3714 (247/665). Leg length = belt to lowest sole.

| frame | belt→sole, belt at hip (Bastion v2 definition) | from the leg's own root: straight leg | other leg |
|---|---|---|---|
| S f00 | **99.0%** (R) | R 99.1% | L 80.9% (passing/bent) |
| S f06 | **100.9%** (L) | L 91.9% | R 88.0% |
| E f00 | **97.6%** (R) | R 97.7% | L 81.4% |
| E f06 | **98.2%** (L) | L 89.5% | R 88.7% |

- The Bastion v2 definition puts the belt at the blockout's iso hip height and compares the same leg to the target. All four values are within 2.4%.
- The from-root column measures from the target hip point. At f06 the straight leg is 8–10% short there. Mauro's item 2 roots both legs at the target's
  level hips, but the blockout plants the far (L) foot about 13 px higher on screen (iso lateral offset, its L hip is 13 px above its R
  hip). So the far leg reaches up and bends a little. The legs aren't scaled down: shin width matches the target (check 1 below).

## Mauro's checks (mauro_checks.json)

| check | rule | S | E |
|---|---|---|---|
| 1 boot-shaft width ÷ shoulder width vs target ratio | ≤ 8% | max 6.0%, mean 2.3% ✔ | max 5.9%, mean 1.9% ✔ |
| 1 stretch along the bone | ≤ 1.10 | max 1.022 (min 0.70 = blockout foreshortening) ✔ | max 1.10 (min 0.87) ✔ |
| 1 scale across the bone | = s_up | exactly s_up (foot length ratio dev 0.0%) ✔ | same ✔ |
| 2 hip midpoint to target belt centre (+ pelvis delta) | ≤ 4 px at f00, f06 | 1.11 / 1.11 px ✔ | 1.48 / 1.49 px ✔ |
| 3 swing-foot peak above its ground track | ≤ blockout + 2 px | R 13.8 / L 12.6 px vs blockout 12.6 (9.0% of leg) ✔ | 12.6 / 12.6 vs 12.6 (9.4%) ✔ |

- **Check 1 measure:** the rendered shin layer is measured across the bone at mid-shaft in every frame (24 per facing). It is divided by the shoulder width (target shoulder points
  through the frame's body map) and compared with the same measure on the target (S .2735, E .3367). The leftover deviation is pixel rounding on an ~18 px
  wide shaft. By construction every leg piece is scaled by exactly s_up across the bone.
- **Check 2:** each leg is rooted at the target's own hip (belt-corner hips S (600,280)/(650,280), E (675,330)/(625,330) target px) plus the
  per-frame pelvis delta. The blockout joints are used only for the knee bend side and the foot-plant targets.
- **Check 3:** in swing frames the foot and the IK ankle are lowered (`swing_drop`, solved by `swing_solve.py`, 0.4–3.6 px) so the visible heel/toe isn't
  higher than the blockout's. Frames where the leg is the metric's support leg are left alone. That's why S R peaks at 13.8 px (+1.2 px) at f10.
  There is no march or kick lift: the first swing frame after toe-off was 4.6 px above the blockout before the fix and is now at it.

## Other requirements

- **Head and eyes:** S uses the new head-turned target head. It faces down-right, the S travel direction. E is the back view and the hood faces up-right (travel). The head is rigid
  with the chest, so head minus blockout chest yaw (shoulder line, atan2(2dy, dx), minus the cycle mean) is S f00 −4.2°, f06 +4.2°; E f00
  +3.6°, f06 −3.6°. The maximum over the cycle is 4.2° (limit ±10°).
- **Knees:** the share of a 3 px disc at the knee owned by that leg's thigh or shin in the stride frames (f11, f00, f01, f05, f06, f07):
  - S: 0.69–1.00, and 1.00 at f00 and f06.
  - E at f06: 0.69 on both legs.
  - E front L knee: 0.31 at f00 and 0.38 at f11, because it sits under the cape hem (the cape is drawn over the legs, as in the target).
- **Toe-off without slide:**
  - S holds the visible ball of the boot exactly: 0.00 px slide on every toe-off pair.
  - E follows the blockout toe joint (point on the joint 0.01 px). The E blockout's toe joint sits about 7 px above its toe sole, and the support-sole metric follows it. As a result the visible ball of the E boot moves 4.4 px (f10→f11, f04→f05) and 5.8 / 2.9 px (f11→f00, f05→f06) relative to the ground, mostly back and up, as the blockout's own toe does.
  - Holding the ball in E too (`"toe_pin": "full"` in kcfg.json) removes that slide, but E motion then drops to 75: the visible sole sits 3–8 px below the blockout's.
  - QA pivot rule: the point on the blockout pivot joint (the Bastion rule) or the visible contact point must slide ≤1 px. Both numbers are in qa_walk.json.
- **Cape hem:** at least 22 px (S) and 26 px (E) above the soles.

## Method

- **Body:** the approved target minus both legs (`cut_target.py`), placed with one scale s_up. The hood top goes on the blockout head top (whole-pixel rows, so the bob is the blockout's) and x on the pelvis.
  - S: the belt, pouches, tunic hem and bow are drawn over the legs.
  - S: the hole behind the legs is inpainted from the cloak greens only, which removes the white jpg bleed at the hem. Its lower edge is ragged like the tatters.
  - E: the cape hangs over the legs. A dark under-tunic fill sits behind the legs, so no background shows at the hem when the thighs swing.
- **Legs:** one target leg at target scale, cut into thigh, boot shaft and boot foot (E shaft from the near boot, because the far one is foreshortened).
  - The leg is re-posed by 2-bone IK from the target hip toward the blockout ankle, bending toward the blockout knee.
  - Along-bone scale = the blockout's foreshortening (capped at 1.10).
  - 3 thigh keys per leg (fwd/down/back) from the blockout thigh swing about its cycle mean. The keys differ only in tone, because the target shows one thigh view.
  - The foot is rigid on the blockout heel/toe and moves exactly with the ground while planted.
- **Bow string:** redrawn as a 1 px line between the target string end points (the painted string breaks into dots at sprite scale).
- **Arms:** part of the static upper body (no arm swing).

## Weak spots

1. Arms don't swing. They are part of the painted upper body.
2. E toe-off follows the blockout's toe roll: the visible ball moves 3–6 px over two frames. The alternative is listed above.
3. Thigh keys differ only in tone. The silhouette comes from the re-posed single thigh.
4. S legs look a little bent or "seated" in places (far leg at f06 89–92% from its root). This is the iso hip offset against the target's level hips.
5. E front knee is under the cape at f00/f11. The E thighs show only below the cape (the target shows the thigh from y 410 only).
6. The fill behind the S legs (cape between the parted legs) is synthetic and smooth.
7. S R swing peak is 1.2 px over the blockout at f10, where it is the metric's support leg and was left alone.

## Repaints that can't be faked

- Thigh views for the forward and back keys (the target paints one standing thigh).
- A far-leg S piece and the E far-leg / thigh tops hidden under the cape.
- Separable arms in swing poses (bow arm and draw arm).
- E boot at the toe-off angle, or a blockout toe joint on the sole. Either would let the E toe stay planted without losing the sole match.
- A painted cape back between the parted S legs.
- A clean bow string at sprite scale (now drawn synthetically).
- parts_src (`legs_S`, `arms_S`, `body_S`, `body_legs_E`) differ in style from the approved target (green sleeves, other boots), so all parts are cut from the target.

## Files

`frames/kestrel_walk_{S,E}_fNN.png` (+ `_build_info.json`), `walk_{S,E}.gif` (60/60/60/60/60/50 ms ×2), `compare_f00_f06_vs_target.png`,
`legs_check.png/.json`, `mauro_checks.json`, `metric_{S,E}.json`, `qa_walk.json`, `scripts/`.

Rebuild:
```
cd scripts
python cut_target.py
python kbuild.py
python kestrel_metric.py ...   # see score lines in this file
python qa_walk.py ../frames ../qa_walk.json
python mauro_checks.py
python legs_check.py
python previews_walk.py
```
Parts are written to `$KPARTS` (default `/workspace/scratch/k2/parts/`).
