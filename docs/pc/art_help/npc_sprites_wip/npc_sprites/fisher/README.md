# Fisher NPC sprites (wanderers batch 1)

Built by `tools/npc/build_npc.py --role fisher` (v2 path) from `raw/npc_sprites/fisher/` keys. Concept: `ship/npc_concepts/npc_fisher.png`.

## Identity and facings
- **Identity comes from the stand keys only** (`front_stand`, `back_stand`). The painted stride and talk keys were redrawn by the image tool, and the outfit and identity drifted.
- Stride-key candidates: `back_stride` failed the guard (residual 0.126). The hat and coat were also repainted differently. Both contacts are synthesised.
- The front key faces down-left, so the **S strip is front_stand flipped**. The back key faces up-right, so the **N strip is back_stand flipped**.
- `fisher.json` mirror flags: `W = S flip_h`, `E = N flip_h` (N = back up-left, E = back up-right, S = front down-right, W = front down-left).
- Hands: The fish is in the left hand in both S and N, so S and N are consistent. W/E mirrors move it to the right hand. The fish is small, but the swap reads on turning at zoom 1.6.

## Files
- `_2x/<anim>_<facing>.png`: horizontal strips of 256x256 frames with no gaps. The 1x files are exact box-filter halves and sit beside `fisher.json`. Only S and N are shipped.
- Per-frame PNGs, GIFs and contact sheets are in `previews/npc_sprites/fisher/`, not in this folder.

## Anims
| anim | frames | fps | loop | notes |
|---|---|---|---|---|
| idle | 10 | 8 | yes | breathing (1.2 %) is baked in. `arm` (the fish-holding forearm, static in idle) and `fish` (parented to the arm, so it rides the arm in talk and walk). Idle: **fish sway on the line** ±4° pendulum about the hand. |
| walk | 8 | 10 | yes | `stride_px` 52 = ground covered per cycle at 2x, measured from the leg-layer soles (S 52.6, N 52.4). Both contacts are **synthesised** from the stand legs (details below) |
| talk | 6 | 8 | **no** | **PLACEHOLDER (procedural).** One-shot: the fish arm rotates +8° about the elbow (offering the catch), plus nod and a 1.5 px forward lean. Hold the last frame while talking, then blend back to idle. `talk_n` is a real back-view talk built from the back key (same gesture seen from behind: head tilt, shoulder/arm lift; the face is not visible), via the npc_work part-warp path like `work_n` |

### Walk construction (v2)
- The leg boxes on the stand key are cut into leg layers with a soft top blend. The robe/hem swings with the gaussian-weighted leg motion.
- Feet are placed in iso ground space along the walk diagonal. The painted wide stance is narrowed (lateral ×0.4).
- The cycle runs contact A, down, passing (swing-foot lift), up, contact B, and so on. It adds a body bob, a ±1.2 px sway, and a small prop counter-swing.
- The support foot moves back by exactly `stride_px`/8 per frame, so it stays **world-locked** in x when the engine moves the node at `stride_px` per cycle (since the 2026-10-03 TA fix it stays on the pivot row instead of following the iso diagonal in y).
- Props are cut out as rigid layers along marked outlines with grip points, so they do not shear with the body. The revealed body behind a prop is filled with a ring-mean colour plus inpaint, with no dark patch.

## Pivot, scale, shadow
- `pivot_px_2x` [128, 240] is the stand key's sole contact on the ground line, the same as for the Farmer. Head top to sole is about 120–124 px at 2x.
- Shadow: one shared soft contact-AO ellipse (~70x24 px@2x centred on the pivot (128,240), #3b3a66, peak alpha 0.20, smooth falloff), identical in every frame of every strip (idle/walk/talk/work, S and N), under the figure. RGB is 0 under alpha 0. The light is pre-graded to the world key #fff0c8 (top-left) with shade #5a6fa0, at 8x supersampling.

## Gate
`python3 tools/check_assets.py ship/npc_sprites/fisher --package npc` → **0 FAIL, 0 WARN** (2026-10-03 rebuild). Report: `ship/check_report_npc_fisher.md`; contact sheet: `previews/npc/fisher_contact.png`. Former WARNs, fixed:
- **Stance centred on the pivot** (TA fix 2026-10-03): the feet midpoint is at x=128 in every anim (props ignored), so W/E mirroring and anim switches do not jump.
- **Walk support foot pinned on the pivot row** (TA fix 2026-10-03): every walk frame has the support sole on row 239/240 (flat ground line; the support foot slides in x only), the bob is in the hips/torso (legs stretch/compress), and only the swing foot lifts in the passing frames. Prop ground contact never pushes the body up.

## Known weak points
- The walk is synthesised from a single stand pose, not painted contacts, so the knees do not really bend. It reads as walking at zoom 1.0–1.6, but painted `front_stride_a/b` and `back_stride_a/b` keys that match the stand outfit would be better.
- The talk is a procedural placeholder. It needs a painted `front_talk` key that matches the stand outfit.
- The fills behind props are smooth, without texture; they are only visible during the talk lift.


## Rebuild
```
cd /workspace/stasium-pc-look/tools/npc
<python with numpy/scipy/opencv/pillow> build_npc.py --role fisher      # ~7 s: this folder + previews/npc_sprites/fisher/frames
<python> make_previews.py --role fisher
cd /workspace/stasium-pc-look && python3 tools/check_assets.py ship/npc_sprites/fisher --package npc
```
Role config: `tools/npc/roles/fisher.json` (views, leg boxes, prop outlines/grips, idle/talk motion, walk step).

## Role action `work` (added 2026-10-03)
- Strips: `_2x/work_s.png`, `_2x/work_n.png` (+1x halves). 10 f @ 10 fps, loop. W/E come from the json mirror flags, as for the other anims. json: `"work": {"frames": 10, "fps": 10, "loop": true}`.
- Cast and wait: wind-back over the shoulder, whip forward, the bob flies out and lands, then she waits with small rod dips (a nibble at f8). The line and bob are 2x post fx drawn inside the 4 px margin.
- Method: the stand keys are cut into rigid layers (tools and arm segments with grip points), then moved with 2-bone arm IK, tool aim and body lean/bob/nod channels. This is the same rigid-layer method as the walk, built by `tools/npc/npc_work.py` from the `work` block in `roles/fisher.json`. The pivot, ground and scale match the idle exactly, so switching between anims does not pop the feet.
- Gate note: action anims are not planted-feet anims, so a tool butt in the bottom rows can shift the feet centroid. That is a WARN, never a FAIL.
- Idle liveliness: the idle now has breathing, weight-shift sway, a lagged hem/cloak sway, a small look-around head shift in the second half of the loop, and a nod (`idle_lively` in the role config). Feet stay planted (drift ≤1.4 px).
- Weak spots:
  - There is no rod in the painted keys. The rod is a synthetic tapered wooden pole (dark core with a warm top-left highlight).
  - The fish she carries is hidden during `work` (it is cut out and filled). The pop is visible when switching from idle.
  - The line is about 1 px and the bob sits in the frame corner (on the ground in this preview). In game, put her at the waterline so the bob lands on water. The line is faint at zoom 1.0.
