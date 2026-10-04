# Farmer NPC sprites (pilot)

Built by `build_npc.py --role farmer` from `raw/npc_sprites/farmer/` keys
(front_stand, front_stride_a, front_talk, back_stand, back_stride). Concept: `ship/npc_concepts/npc_farmer.png`.

## Files
- `_2x/<anim>_<facing>.png`: horizontal strips, 256x256 frames, no gaps. 1x exact halves (box filter) beside `farmer.json`.
- Shipped facings are **S** and **N** only. `farmer.json` mirror flags: `W = S flip_h` and `E = N flip_h` (ZONES_BUILD_SPEC L194:
  N = back up-left, E = back up-right, S = front down-right, W = front down-left).
- The raw back keys face up-right (E), so the **N strip is the back art flipped horizontally**. E is the json flip of N, which gives back the painted orientation.
- Per-frame PNGs, GIFs and contact sheets are in `previews/npc_sprites/farmer/`, not here, because the gate fails any stray PNG in a ship folder.

## Anims (farmer.json)
| anim | frames | fps | loop | notes |
|---|---|---|---|---|
| idle | 10 | 8 | yes | breathing (1.2 %) is baked in, so the engine should add none. Fork tilts about its planted butt, basket sways ±2° |
| walk | 8 | 10 | yes | `stride_px` 54 = ground covered per cycle (2 steps) at 2x, measured from the contact-foot spacing (S 56.1, N 51.4, averaged) |
| talk | 6 | 8 | **no** | one-shot: idle pose → painted talk pose plus a small nod, ending on a hold pose. Hold the last frame while talking, then blend back to idle |

`talk_n` is a real back-view talk built from the back key (same gesture seen from behind: head tilt, shoulder/arm lift; the face is not visible), via the npc_work part-warp path like `work_n`.

## Pivot, scale, shadow
- `pivot_px_2x` [128,240] is the midpoint between the soles on the ground line. That line is 16 px above the frame bottom.
- **Scale:** the head-top-to-sole height is 120 px at 2x, about 124–127 px including the near boot and fork tines. This matches ironjaw_tall at its walker scale of 0.33 (190 px source → about 124 px at 2x, PR #214).
- **Shadow:** one shared soft contact-AO ellipse (~70x24 px@2x centred on the pivot (128,240), #3b3a66, peak alpha 0.20, smooth falloff), identical in every frame of every strip (idle/walk/talk/work, S and N), under the figure; no cast shadow. RGB is 0 wherever alpha is 0.

## Light / grade
- The sprites are pre-graded toward the world light: key #fff0c8 from the top-left, shade #5a6fa0, shadow tint #3b3a66. The grade is a warm-highlight/cool-shadow split, a top-left key gradient, a rim on the key and shade sides, and a dark contour (0.42) for the kit's crisp outline. Processing is at 8x supersampling (1024 → 256 with INTER_AREA).
- Crosshaven's runtime grade (warm_mul 1.02/1/0.96, sat 1.06, contrast 1.04, gentle bloom) is applied on top in-engine. It is emulated in `previews/.../in_world_zoom10/16.png`, not baked in.

## Known limitations
- **Contact B** (left foot forward) is synthesised by warping the stand-key legs; there is no painted B key.
- **Walk is in place:** the painted step axis is not iso-exact, so the feet are only mostly locked in frame. Expect slight foot slide at `stride_px`, the same as the baked hero strips. Painted `front_stride_b` and `back_stride_b` keys would fix both.
- **W and E mirrors swap the hands** for the fork and basket. If that matters at zoom 1.6, paint native down-left/up-left keys and drop the flag.
- **Raw keys drift from the concept** (older, grey hair, smiling).

## Gate
`python3 tools/check_assets.py ship/npc_sprites/farmer --package npc` → `ship/check_report_npc_farmer.md`, `previews/npc/farmer_contact.png`.
No FAILs. The WARNs are explained in the report notes and the pilot hand-off:
- **Stance centred on the pivot** (TA fix 2026-10-03): the feet midpoint is at x=128 in every anim (props ignored), so W/E mirroring and anim switches do not jump.
- **Walk support foot pinned on the pivot row** (TA fix 2026-10-03): every walk frame has the support sole on row 239/240 (flat ground line; the support foot slides in x only), the bob is in the hips/torso (legs stretch/compress), and only the swing foot lifts in the passing frames. Prop ground contact never pushes the body up.

## Rebuild
Scripts live in `/workspace/scratch/npc_sprites/` (copy them into `tools/` to keep them).
```
.venv/bin/python build_npc.py --role farmer        # ~9 s, writes this folder + previews/npc_sprites/farmer/frames
.venv/bin/python make_previews.py --role farmer    # ~8 s
python3 tools/check_assets.py ship/npc_sprites/farmer --package npc
```
The role config is `roles/farmer.json` (keys, views, prop polygons/grips, grade overrides). Start a new role with `new_role.py --role <name>`.

## Role action `work` (added 2026-10-03)
- Strips: `_2x/work_s.png`, `_2x/work_n.png` (+1x halves). 12 f @ 10 fps, loop. W/E come from the json mirror flags, as for the other anims. json: `"work": {"frames": 12, "fps": 10, "loop": true}`.
- Digging with the pitchfork. The painted keys only have a pitchfork, no hoe, so the fork turns tines-down: raise, drive the tines into the soil beside her feet with a forward lean, lever back with a small earth fleck, then reset.
- Method: the stand keys are cut into rigid layers (tools and arm segments with grip points), then moved with 2-bone arm IK, tool aim and body lean/bob/nod channels. This is the same rigid-layer method as the walk, built by `tools/npc/npc_work.py` from the `work` block in `roles/farmer.json`. The pivot, ground and scale match the idle exactly, so switching between anims does not pop the feet.
- Gate note: action anims are not planted-feet anims, so a tool butt in the bottom rows can shift the feet centroid. That is a WARN, never a FAIL.
- Idle liveliness: the idle now has breathing, weight-shift sway, a lagged hem/cloak sway, a small look-around head shift in the second half of the loop, and a nod (`idle_lively` in the role config). Feet stay planted (drift ≤1.4 px).
- Weak spots:
  - This is a fork dig, not a hoe chop, because the keys have no hoe. A painted hoe prop would make it read as a true hoe chop.
  - When the anim switches from idle, the fork snaps from tines-up to tines-down. It is a pose change, not a turnover.
  - The earth flecks are only 1–1.5 px and barely show at zoom 1.0.
