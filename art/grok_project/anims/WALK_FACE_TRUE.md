# Walk Face-True Soft Lock

## Godot WalkDraw audit (CRITICAL)
- Engine is correct: E step picks `walk_e`; `flip_h` off; mid-tile shows cell 4.
- **No Godot PR for SW lock.** Root cause is **art bake**.
- On east (and west) strips: cell 0 was true side plant, but cells 1–5 drifted to
  front three-quarter (same pose family as `walk_s`) — reads as SW during an east hop.

## Soft Lock — face-into-move
- Hop cells 1–5 MUST face the **same way as cell 0** on that strip
  (true E/W **side** stride), not camera-facing.
- No mirror shortcuts that keep S pose on E.
- Completeness Soft Lock still applies: connected silhouette every frame
  (torso+head+arms+weapon). Hop/displacement Soft Lock candidate stays.

## Method
1. Every cell of `walk_<face>` is built only from Locked master
   `characters/<class>/game/<class>_<face>.png` — **no S body on E hop**.
2. Completeness compositor unchanged (v3 idle underlay + distal erase + torso fill).
3. Face-true pose modulation for **E/W only**:
   - lean ×0.25 (large lean on side masters reads as turn-to-camera)
   - arm screen-X / rot ×0.55 / ×0.70
   - leg stride slightly damped (×0.85) to avoid front-read width
   - bob / squash kept in Soft Lock hop-candidate range
4. S/N strips keep full Batch-1 hop amplitudes (already camera-axis facings).
5. Identity HOLD — no GenerateImage. Live `export_2x` **untouched**.

## Paths (staging only)
| What | Path |
|------|------|
| Face-true strips | `/workspace/art/grok_project/anims/walk_completeness_fix/<class>/<class>_walk_{e,s,n,w}.png` |
| Masters 288×320 | `/workspace/art/grok_project/anims/walk_completeness_fix/masters/` |
| Per-frame masters | `/workspace/art/grok_project/anims/walk_completeness_fix/frames/` |
| Face-wrong archive (pre this fix) | `/workspace/art/grok_project/anims/archive_walk_face_wrong/` |
| Contact sheet | `/workspace/art/grok_project/anims/walk_face_true_contact.png` |
| Script | `/workspace/art/grok_project/anims/fix_walk_face_true.py` |
| Completeness base | `/workspace/art/grok_project/anims/fix_walk_completeness.py` |

## Live export + pngbin (NOT written yet)
When greenlit later, swap **both**:
1. `export_2x/characters/<class>/anims/<class>_walk_<face>.png`
2. `art/export_2x/walk_src/<class>_walk_<face>.pngbin`

Expected pngbin dir: `/workspace/art/export_2x/walk_src/`
Existing pngbin on box now:
  - (none on box today — directory may be created at greenlight)

Prepare at greenlight: encode staging PNG strips into pngbin beside the PNG swap.
Do **not** write into live export until Godot confirms face-true read in-game.

## Stats
- ironjaw_walk_e: hole before max=0.068 after max=0.079; hop_amp before=15.058135192238495 after=16.1px; face cues OK
- ironjaw_walk_s: hole before max=0.091 after max=0.091; hop_amp before=17.318647921029026 after=17.3px; face cues OK
- ironjaw_walk_n: hole before max=0.143 after max=0.143; hop_amp before=12.312452690621626 after=12.3px; face cues OK
- ironjaw_walk_w: hole before max=0.225 after max=0.215; hop_amp before=11.671949040744494 after=13.2px; face cues OK
- kestrel_walk_e: hole before max=0.389 after max=0.359; hop_amp before=10.869938806256869 after=12.5px; face cues OK
- kestrel_walk_s: hole before max=0.315 after max=0.315; hop_amp before=11.663731603473124 after=11.7px; face cues OK
- kestrel_walk_n: hole before max=0.355 after max=0.355; hop_amp before=14.862362089825822 after=14.9px; face cues OK
- kestrel_walk_w: hole before max=0.300 after max=0.315; hop_amp before=14.119273715676712 after=14.4px; face cues OK
- gloam_walk_e: hole before max=0.389 after max=0.350; hop_amp before=10.190245665392709 after=11.0px; face cues OK
- gloam_walk_s: hole before max=0.309 after max=0.309; hop_amp before=10.182458942637439 after=10.2px; face cues OK
- gloam_walk_n: hole before max=0.409 after max=0.409; hop_amp before=10.898586529752649 after=10.9px; face cues OK
- gloam_walk_w: hole before max=0.367 after max=0.337; hop_amp before=12.328908944348555 after=13.2px; face cues OK

## Weak frames / notes
- Ironjaw E/W: face cues OK (hammer side matches master every cell); hop readable (~16px E, ~13px W).
- Ironjaw N: residual mid-torso hole max=0.143 — watch hip seam on high-stride cells.
- Ironjaw W: residual hole max=0.215 on some hop cells — connected but hip seam possible.
- Kestrel E: hole max=0.359 (cloak/edge); body core solid; hop ~12.5px.
- Kestrel W: hole max=0.315; hop ~14.4px.
- Gloam N: weakest hole max=0.409 — hood/cloak thin seams under stride; still connected.
- Gloam E/W: hole max≈0.35/0.34; side silhouette held; verify in-engine.
- No hammer-side flips on Ironjaw E/W after rebuild.


## Ship gate
Staging only. export_2x + walk_src pngbin wait for greenlight.
