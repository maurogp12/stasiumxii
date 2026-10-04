# Warden NPC sprite (Crosshaven patrol)

Source keys are in `raw/npc_sprites/warden/` (1280x720 jpgs on white, keyed out the same way as the other roles):
- `front_stand.png` is the 3/4 front view facing down-right, used as **S as painted (not flipped)**. The halberd is in his right hand (screen-left), the lantern in his left hand (screen-right), and the horn is at his belt.
- `back_stand.png` is the 3/4 back view facing up-left, used **directly as N (not flipped)**.

## Files
| anim | strips | frames | fps | loop |
|---|---|---|---|---|
| idle | `_2x/idle_s.png`, `_2x/idle_n.png` (+1x halves) | 12 | 8 | true |
| walk | `_2x/walk_s.png`, `_2x/walk_n.png` (+1x halves) | 8 | 8 | true |
| talk | `_2x/talk_s.png`, `_2x/talk_n.png` (+1x halves) | 6 | 8 | false |
| patrol_look | `_2x/patrol_look_s.png`, `_2x/patrol_look_n.png` (+1x halves) | 12 | 8 | true |

- `warden.json`: frame 256x256 at 2x, `pivot_px_2x` [128, 240], mirror W = S flip_h, E = N flip_h. Walk `stride_px` = **43**, measured from the world-locked support foot (S 41.0, N 44.2; template 44). This is shorter and slower (8 fps) than the townsfolk's 52–55 px at 10 fps, for a heavy patrol pace.
- Scale: head top to mean sole is about 124 px at 2x (figure plus helmet 129–130 px above the pivot). Margin is 4 px or more. RGB is 0 under alpha 0. Contact AO: one shared soft contact-AO ellipse (~70x24 px@2x centred on the pivot (128,240), #3b3a66, peak alpha 0.20, smooth falloff), identical in every frame of every strip (idle/walk/talk/work, S and N), under the figure. Light is pre-graded to key #fff0c8 (top-left) with shade #5a6fa0.

## Anims
- **idle** (12 f): breathing, weight-shift sway, a lagged cloak-hem sway, a lantern pendulum swing (±5°), a slight halberd sway about its planted butt, and a small look-around head shift with a nod in the second half. Feet are planted (drift 0 px).
- **walk** (8 f @ 8 fps): a heavy patrol stride, synthesised from the stand keys (layered legs, synth contacts, bob 2.6 px, 4 px foot lift). The lantern swings and the halberd travels upright in the hand.
- **talk** (6 f, no loop): **placeholder** (procedural lift and nod of the head, lantern dips slightly). It needs a painted `front_talk` key. `talk_n` is a real back-view talk built from the back key (same gesture seen from behind: head tilt, shoulder/arm lift; the face is not visible), via the npc_work part-warp path like `work_n`.
- **patrol_look** (12 f @ 8 fps, loop): he stops, raises the lantern to shoulder height (upper arm and forearm rotate, and the lantern hangs plumb from the hand), looks to either side, then lowers it. The halberd stays upright with a small butt tap on the ground at f1. It is built by `tools/npc/npc_work.py` (rigid prop and arm layers with grip points on the stand keys) from the `work` block in `roles/warden.json`.

## Gate
`python3 tools/check_assets.py ship/npc_sprites/warden --package npc` gives **PASS 9, WARN 0, FAIL 0** (2026-10-03 rebuild). Report: `ship/check_report_npc_warden.md`.

Former WARNs, fixed:
- **Stance centred on the pivot** (TA fix 2026-10-03): the feet midpoint is at x=128 in every anim (props ignored), so W/E mirroring and anim switches do not jump.
- **Walk support foot pinned on the pivot row** (TA fix 2026-10-03): every walk frame has the support sole on row 239/240 (flat ground line; the support foot slides in x only), the bob is in the hips/torso (legs stretch/compress), and only the swing foot lifts in the passing frames. Prop ground contact never pushes the body up.

## Previews
`previews/npc_sprites/warden/`: `actions_zoom10.gif` / `.mp4` / `_x2.mp4` (walk, idle and patrol_look, S and N, at zoom 1.0 on Crosshaven grass), `walk_*.gif`, `idle_s.gif`, `talk_s.gif`, `in_world_zoom10.png` / `16.png`, `concept_vs_sprite.png`, `walk_contact.png`.

## Known weak points
- The talk is a placeholder.
- The walk is synthesised from one stand pose per view, so the knees barely bend and the heavy cloak moves as one hem sway. Painted stride keys would be better.
- In patrol_look the look-around is a ±2 px head shift, not a real head turn. In N the forearm alone raises the lantern, so it rises beside the head rather than out front.

## Rebuild
```
cd /workspace/stasium-pc-look/tools/npc
/workspace/scratch/npc_sprites/.venv/bin/python new_role.py ...   # (done once: roles/warden.json + keyed keys)
/workspace/scratch/npc_sprites/.venv/bin/python build_npc.py --role warden
/workspace/scratch/npc_sprites/.venv/bin/python make_previews.py --role warden
/workspace/scratch/npc_sprites/.venv/bin/python make_action_previews.py warden
cd /workspace/stasium-pc-look && python3 tools/check_assets.py ship/npc_sprites/warden --package npc
```
