# Ironjaw HD repaint: 3D walk underlay (blockout reference renders)

**Paint-over guide only.** Scenario Art paints over these 100%. They never ship and are never imported into Godot.
Everything lives in `/workspace/art_src/blockout/ironjaw_walk/`, outside the game project. All code here is my own
(Blender Python API + numpy/PIL); nothing was copied from other repos.

## Rebuild
```
cd /workspace/art_src/blockout/ironjaw_walk
.venv/bin/python src/render.py   # Blender 5.2.2 (pip bpy, headless Workbench): model, rig, pose, renders, camera.json, .blend
.venv/bin/python src/post.py     # grid pass, strips, QA (qa.json), preview GIF + contact sheet, manifest.json, SHA256SUMS
.venv/bin/python src/pad512.py   # renders_512/ (512x360 cells), joints_512.json, joints_check.png, manifest_512.json, qa/hold_check.json
```
`src/rig.py` = proportions + procedural walk (2-bone leg IK, planted-boot math, bob, 2-bone arm IK + axe hold, arm swing). `src/model.py` = the part meshes
(boxes, tapered boxes, cylinders, cones, one extruded axe-head outline). `src/geo.py` = primitives.
`ironjaw_blockout.blend` = the mannequin as an object hierarchy (root > pelvis > chest > head / cape / shoulder > upper arm >
forearm > hand > axe; pelvis > thigh > shin > boot), with the S walk keyed on frames 1-12 and the idle on frame 20.

## Outputs
`renders/{clay,sides,sil,grid}/walk_{S,E}_f00..f11.png`, `idle_{S,E}.png`, `walk_{S,E}_strip.png` (12 x 460 = 5520 x 360).
Cell 460x360, pivot (230,329), RGBA. Alpha is only 0/255 (no anti-aliasing) in clay/sides/sil.
* clay: per-face flat grey, key light from screen upper-left (fixed to the camera, so it is the same in every frame).
* sides: flat colours. Near side = his RIGHT (orange family), far side = his LEFT (blue family). Both S and E show his right side
  nearest the camera, so the colours flip under the W/N mirrors. Torso greys, cape dark red, right-hand axe green, left-hand axe magenta.
  Within a limb: pauldron light, upper arm/thigh mid, forearm/shin darker, hand/boot darkest.
* sil: flat black.
* grid: the clay frame over the iso ground grid. Solid lines are a 64x32 board tile at draw_scale 0.30 (=213.3x106.7 cell px), and
  dashes mark quarter tiles. The tile is centred on the body ground point. Also shows a height ruler (px above row 329), the pivot row,
  the body-ground row and the idle top row. Not alpha-clean (it has an overlay).
* `qa/idpass/` holds QA-only passes (per-part ID colours, plus each boot rendered alone so it can be tracked without occlusion).

## Camera (camera.json)
Orthographic, 30 deg down (2:1 ground: world X/Y go to the screen (+-2,+-1) diagonals), azimuth 45 deg, Blender rotation (60, 0, 45) deg,
ortho_scale 494.62 (1 world unit = 0.93 px). The world origin (the ground point under the pelvis) sits at pixel (230.5, 282.90).
Elevation check: v3.2 walk S slides its planted boot (-6,-3) px per frame, which is exactly 2:1, so it is consistent with 30 deg.
**Facing:** travel and the planted-boot slide run along the board diagonal (S = down-right, E = up-right, as the locked facing rule says).
The v3.2 and HD paintings show the body turned closer to the camera axis than a true 45 deg would be: S is about 25 deg off frontal
(the far hand reads higher than the near one), and E is about 10 deg off a pure back view (in both the HD and the v3.2 E the two hands
and boots are almost level). So the body is turned an extra 20 deg toward the camera in S and 35 deg away in E (`rig.CHEAT`). The boots
split it (half). Set `CHEAT` to 0 for a pure 45 deg 3/4.

## Walk
12 frames at 17.144 fps, loop. Heavy flat-foot stomp. Each boot is planted for 7 frames (both boots down on the contact frames) and in
the air for 5.
* S: f00 = right (near) boot contact, f06 = left (far) contact. Bob is lowest on f01/f07 and highest on f04/f10. Same phase as v3.2 S.
* E: f00 = 1 frame after the right-boot contact. Contacts are on f05 (left) and f11 (right), the same as v3.2 walk E (re-phased README).
* Rendered in place. The planted boot slides back by exactly (12,6) px per frame (S: up-left, E: down-left), an integer shift, so
  its pixels match exactly frame to frame. **Travel = 161.0 cell px per cycle on the diagonal (144 x 72) = 48.3 px at draw 0.30
  (43.2 x 21.6).** 13.42 cell px per frame = 4.02 final px per frame.
* Board tile diagonal at 0.30 = 119.26 cell px, so there are **8.89 frames per cell** and 1.35 cells per cycle. At 17.144 fps that
  is 0.519 s per cell (69.0 board px/s). v3.2 was 8.33 frames per cell, 0.486 s.
* Bob: one sine per step. Pelvis range 25.6 px (7.7 final), max step 12.5 px (3.8 final). The head and helm-top rows measure the same.
* Arms swing opposite the legs, +-15 deg at the shoulder, half a frame behind, elbow angle held (see "Arms + axe hold"). The pelvis
  turns +-6 deg and the chest counter-turns, so the shoulders net -+8 deg. The cape is two hinged slabs with a light swing.

## walk_S leg length (HD match, 2026-10-04)
* **walk_S only** (f00-f11): thigh and shin are 1.0275x longer (`rig.LEG_SCALE['S']`) and everything from the pelvis up (torso,
  head, cape, arms, axes) is raised 2.48 world units = **2.0 px straight up** (`rig.LEG_RAISE_PX['S']`).
  Pelvis walk y 211.4-236.9 -> 209.4-234.9; helm-top joint at passing (f10) 66.4 -> 64.4 (512 cell).
* **idle_S is unchanged** (joints and renders identical to before): it sits on the painted HD idle legs. E is untouched
  (all E images pixel-identical, E joints identical).
* How 2 px was chosen: Scenario's walk rig, rebuilt on these joints in a sandbox (their make_walk.py + qa_walk.py), scores
  height_vs_idle 1.000 on Claude's match_metric.py (it was 0.992; passing helm top row 66 -> 64, HD idle top 64).
  Their torso follows (neck+pelvis) of the walk joints, so the painted walk rises by the same 2 px.
* **Feet IK-pinned:** every ankle (planted and swing, including the base rig's swing-leg clamp on two frames) is first solved
  exactly as before, then the longer legs are re-solved from the raised hips to that same ankle. Ankle/heel/toe joints are identical
  (0.000 px). Stride, phase, contacts and soles are unchanged. Planted drift 0.0 px. Bob unchanged: pelvis range 25.6 px,
  max step 12.5 px; helm-top rows 26 / 13 px. LEG_SCALE keeps the straightest walk leg as straight as before (0.979).
* Arms and hold ride the chest: every arm, wrist, grip and axe joint moves by exactly (0, -2) px. Wrist and grip stay inside the
  fist, and there are no arm/axe-leg intersections.
* The leg meshes are stretched copies along the bone (render.py `get_mesh`). The bone matrices in `rig.pose()` carry the length
  as a local -Z scale, so `M @ (0, 0, -THIGH)` is still the knee.
* To change the raise: set `LEG_RAISE_PX['S']` and scale `LEG_SCALE['S']` so the straightest walk leg stays at 0.979
  (1.5 px -> 1.0206, 2 px -> 1.0275, 2.5 px -> 1.0344). Re-run render, post and pad512.

## Additive joints_512.json keys for rig_fx (existing keys unchanged)
Per frame (walk and idle, both facings):
* `arm_swing_deg` {R, L}: the rig shoulder swing about the travel X axis (+ = forward); the whole arm + axe swings rigidly by it
  (+-15 deg, half a frame behind the legs; 0 in idle).
* `arm_swing_screen_deg` {R, L}: in-plane screen angle of shoulder->axe_grip minus the idle angle (same convention as
  parts.rotation_deg: 0 = down, + = clockwise). Use it as `lbs_swing` deg in S (R runs -9.6..+8.1 deg).
* `cape_points` {collar, hem}: cell px of the cape top centre (cape_up hinge) and the bottom centre of the lower cape slab. For
  `cape_sway`: top/hem rows, and dx_hem = hem x - collar x.
E frames only:
* `reach_vs_idle` {R, L}: `length_scale` = 2D |shoulder->axe_grip| / idle (use it as the `lbs_swing` stretch along shoulder->grip),
  `depth_delta_units` = change of the grip depth relative to the shoulder vs idle (+ = toward the camera), `toward_away` =
  toward / away / level (|delta| < 0.5 units).
Meta:
* `meta.fx.cape_lag_frames` {S: 2.43, E: 2.3}: frames by which the cape hem's sideways swing trails the pelvis' sideways sway
  (character frame, circular cross-correlation at 1/100-frame steps). Claude's prototype used 0.9 rad = 1.7 frames.
* `meta.walk_leg_raise` {S: raise_px 2.0, leg_bone_scale 1.0275; E: 0 / 1.0}, walk frames only.

## Arms + axe hold (rebuilt to match Luca's reference picture, `ref/luca_hold_reference.png`; per-facing cheat for Scenario, v3)
* Chunky arms (upper arm 36, forearm 34-44 thick = shin thickness), big fist block built around the handle.
* 2-bone arm IK from the shoulder (UPPER 74, FORE 70), solved in the TRAVEL frame (+Y = walk direction). The whole arm swings
  rigidly about the travel X axis through the shoulder (+-15 deg, opposite the legs), so the elbow angle is held through the walk
  and the fist never moves sideways.
* The hold is a per facing/side table `rig.ARM[(facing, side)]` (grip or fist_x/reach/bend, haft, yaw, roll, pole, wf).
  The painted cutouts are seen from two fixed cameras, so the hold is cheated per facing:
  * **Luca's raise is baked in.** R `axe_head_centre` is level with L on screen: S idle -0.3 px, S walk -3.1..+2.4 px;
    E idle -0.2 px, E walk -1.2..+1.2 px. Scenario can drop their +24.9 deg R-forearm correction.
  * **S, near (R) arm:** the upper arm swings out/back, so the fist sits out by the right hip, 32 px screen-left of the approved
    hold (27-35 px through the walk) and 31 px higher. The elbow bend is about 124 deg (the old 100 deg plus the raise). The handle
    is turned 30 deg outward and is almost level (5 deg down), so the head hangs outside the right leg at thigh height (head x 197
    vs thigh x 213-240 at idle). The axe is rolled 60 deg about its handle so the blade face reads to this camera as well as it
    did before (|cos| 0.61). Without the roll, the outward-turned blade was seen edge-on.
  * **S, far (L) arm:** this is the approved hold, with the handle 34 deg down instead of 28 so it meets the R head.
  * **E:** both elbows hang by the ribs. L elbow (202,202) sits 5 px below the chest joint at idle and 1-9 px below it in every
    walk frame; before, it stuck out at shoulder height, about 40 px above. R elbow is pulled in from x 333 to 318, 14 px below the
    chest. Forearms run forward and the handles stay forward-down (R 42 deg, L 55 deg). The heads trail the arm swing about the
    wrist (wf -1.0/-0.9). Without that, the opposite swings on this camera push the two heads up to 90 px apart in the walk.
* The hand/axe share one frame at the grip (fist centre on the handle axis). The wrist (end of the forearm bone) is fixed at
  (0, -7, 7) in that frame, so wrist and grip are inside the fist block in every frame (wrist-to-grip 9.9 units, <= 9.0 px).
* Grip near the butt end, head eye 70 units ahead. The head is turned in the blade plane so the big crescent hangs down.
* No arm/axe-leg intersection in any frame (BVH check in pad512.py); lowest axe point 10.95 units above the ground.
  In E the far (L) forearm/fist touches the pelvis block in idle E and 8 of the 12 walk frames. It is behind the torso from this camera,
  and no leg is involved.
* `draw_order` (joints_512.json) is still nearest-camera first by part centre. Where an arm or axe overlaps another part on
  screen, it is now checked against the rendered id pass, and whichever part is actually visible in the overlap goes in front
  (pad512.py `refine_order`). Leg/torso/cape order is untouched.
* Pauldron tilt is unchanged from the previous rig, so the top silhouette and the bob rows are identical.

## Notes / known differences from the references
* **Soles at y=329:** in a true 2:1 view a boot's screen row depends on where it is on the ground (forward in S = lower, forward in
  E = higher, and the near boot is lower than the far one). A body ground point at row 329 would push the S contact toe about 46 px
  below the pivot, outside the 360 px cell. So the body ground point sits at row 282.9, and the lowest planted sole of the whole walk
  (S f00 right-boot contact) lands exactly on row 329. Other contacts land higher: S f06 far boot on 316, E f05 on 276 and E f11 on
  282 (E contacts land forward, which is up-screen). The lowest planted boot in E is 318 (trailing boot on f05). Both facings use the
  same body point (no pop when facing changes). If the HD slice wants the pivot on the body, use (230,283).
* Idle: neutral stance with both boots flat. Lowest sole: row 314 in S, 298 in E.
* Height: helm (with horns) to lowest sole in idle is 269 px in S and 250 px in E (about 260 on average). Pauldron spikes reach row 35 in S.
* Axe heads (v3): level by construction (see above). S heads at y 225 idle / 223-248 walk (thigh). E heads at y 206 idle /
  208-232 walk, i.e. hip to upper thigh: the far E axe cannot hang lower without hitting the ground or the far leg.
* Idle/walk E: the far (left) axe head stays mostly hidden behind the body. A thin edge of its blade shows beside the cape in idle
  E and walk E f02-f08 (up to ~570 px). The near (right) axe reads clearly.
* The S/E painted views are not geometrically consistent (perspective-style pauldrons, near-level shoulders). The blockout is true
  orthographic, so the painter will need to cheat the pauldron sizes by hand.
