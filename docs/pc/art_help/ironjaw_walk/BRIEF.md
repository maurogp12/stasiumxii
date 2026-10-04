# Ironjaw HD walk: help request for Claude (from Scenario Art, on Luca's ask)

## Luca's bar
Walk AND look must match the targets at 85-100%.
- WALK motion: v2 (walk_v2_frames/, walk_v2_previews/walk_S.gif, walk_E.gif) is "perfect" per Luca. Lock the leg phase, stride, bob and foot plants exactly.
- LOOK: v2 fails. The cutout arms, fists, axes and cape look stiff and don't match the approved HD Ironjaw. The look targets are repaint_targets/rp_S_f00_t1.jpg (front 3/4 = S) and rp_E_f00_t1.jpg (back = E), plus hd_set_idle/ (the approved idle/attack/hit/death set).
- Hold (Luca approved, refs/luca_hold_reference.png): fists clenched on the handles at belt height; handles pointing forward and down; blades vertical with the edge leading; arm swing about +-15 deg; both axe heads at equal height.

## Facts
- Cells are 512x360, pivot (256,329), 12 frames at 17.144 fps. S contacts f00/f06, E contacts f05/f11. Contact soles sit up to about 15 px (S) / 20 px (E) below row 329; keep that.
- W = mirror of S, N = mirror of E.
- ta_joints/joints_512.json: Technical Artist's Blender walk joints (current 22:55 ET 10/03). The near-axe raise is baked in, so my correction is 0.
- rig_scripts/: make_walk.py (cutout rig), qa_walk.py (skate/bob/margin/halo QA), previews_walk.py.
- parts/: the painted parts sheets the v2 rig cuts from.
- v2 QA: 48/48 pass, skate 0, bob 7.8/7.5 game px, min margin 11 px.

## The problem
- Per-frame AI repaints give the right look but drift the legs and narrow the stride.
- The cutout rig gives the right motion but the wrong look.
- Current plan (v3, in progress): cut the upper body, arms, axes and cape from the repaint targets and mount them on v2's legs, color-matching the legs.

## What we want from you
1. Review the approach. Is there a better pipeline for hitting 85%+ on both look and motion? Options: a hybrid rig; a mesh/warp deform of the repaint per frame driven by the joints; painting the legs to match and then rigging; or keyframe repaints with in-betweens.
2. Propose a measurable "85% match" metric for look (e.g. SSIM/LPIPS on the upper body vs the target at f00, palette deltaE, silhouette IoU) and for motion (joint/foot positions vs v2, skate, bob), and ideally write it as a script.
3. Improve rig_scripts where you can: better arm segmentation and swing without seams, a cape sway, and a hip-join hide.
4. Give a concrete punch list per frame range of what still breaks the look.
Constraints: painted fantasy only (no 3D render look, no neon/cyber). Never touch main/mobile. Art changes go back through Scenario Art and Technical Artist.
