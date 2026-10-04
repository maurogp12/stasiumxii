# Asset check report: `npc`

- Folder: `ship/npc_sprites/farmer`
- Roles: 1
- Overall: **PASS**
- Rows: PASS 9, WARN 0, FAIL 0
- Rules (ZONES_BUILD_SPEC 4.5a + WP10 NPC bodies @ 78e6513): frame 256x256 at 2x, `_2x/<anim>_<facing>.png` + 1x exact halves, idle 8-12 f, walk 8 f, talk 6-8 f; one pivot per role (suggested [128, 240]), support (lowest) foot within ±3 px of the pivot row in every frame (idle/talk FAIL, walk/actions WARN; swing-foot lift INFO; runs <= 6 px wide are tool butts, not feet), stance centre = midpoint of the outermost feet within ±10 px of pivot x (planted FAIL > 24), contact AO ~70x24 peak <= 0.3 and consistent across strips, planted drift <= 2 px (FAIL > 4), 4 px clear frame edge, halo / alpha-0 RGB, mirror flags by the locked rule (W = S flipped, E <-> N flipped), stride_px, loop, neon share <= 1%.

## farmer: **PASS**

| File | Status | Size | Details |
|---|---|---|---|
| `farmer/farmer.json` | **PASS** | json | INFO: pivot [128, 240]; INFO: walk stride 54 px@2x (27.0 px@1x per cycle); INFO: extra anim `work` (not in spec; no frame range) |
| `farmer/_2x/idle_n.png` | **PASS** | 2560x256 RGBA | INFO: body centre (torso band) -5.4 px from pivot x 128 (frame 3); INFO: planted-feet drift 0.0 px@2x (support foot y 239..239, stance x 128.0..128.0); INFO: contact AO 66x22 px@2x, peak alpha 0.20, centre x 129.2, in 10/10 frames; INFO: figure height 125 px@2x above the pivot (62 px@1x; ironjaw_tall ~124@2x); INFO: 1x matches 2x downsample (alpha \|d\| 0.0, colour 0.5); INFO: 10 f @ 8 fps, loop True |
| `farmer/_2x/idle_s.png` | **PASS** | 2560x256 RGBA | INFO: body centre (torso band) -4.5 px from pivot x 128 (frame 8); INFO: legacy bottom-12-row centroid -13.0 px (tool butt / 3-4 stance; not gated); INFO: planted-feet drift 0.0 px@2x (support foot y 239..239, stance x 128.2..128.2); INFO: contact AO 66x22 px@2x, peak alpha 0.20, centre x 130.3, in 10/10 frames; INFO: figure height 128 px@2x above the pivot (64 px@1x; ironjaw_tall ~124@2x); INFO: 1x matches 2x downsample (alpha \|d\| 0.0, colour 0.5); INFO: 10 f @ 8 fps, loop True |
| `farmer/_2x/walk_n.png` | **PASS** | 2048x256 RGBA | INFO: swing/far foot up to 5 px above the support foot; support foot rows 239..239; INFO: body centre (torso band) -6.3 px from pivot x 128 (frame 1); INFO: contact AO 66x22 px@2x, peak alpha 0.20, centre x 128.8, in 8/8 frames; INFO: 1x matches 2x downsample (alpha \|d\| 0.0, colour 0.5); INFO: 8 f @ 10 fps, loop True |
| `farmer/_2x/walk_s.png` | **PASS** | 2048x256 RGBA | INFO: swing/far foot up to 15 px above the support foot; support foot rows 239..240; INFO: body centre (torso band) -5.3 px from pivot x 128 (frame 5); INFO: legacy bottom-12-row centroid -20.9 px (tool butt / 3-4 stance; not gated); INFO: contact AO 66x22 px@2x, peak alpha 0.20, centre x 129.3, in 8/8 frames; INFO: 1x matches 2x downsample (alpha \|d\| 0.0, colour 0.5); INFO: 8 f @ 10 fps, loop True |
| `farmer/_2x/talk_n.png` | **PASS** | 1536x256 RGBA | INFO: body centre (torso band) -5.3 px from pivot x 128 (frame 4); INFO: planted-feet drift 0.0 px@2x (support foot y 239..239, stance x 128.0..128.0); INFO: contact AO 66x22 px@2x, peak alpha 0.20, centre x 129.1, in 6/6 frames; INFO: 1x matches 2x downsample (alpha \|d\| 0.0, colour 0.5); INFO: 6 f @ 8 fps, loop False |
| `farmer/_2x/talk_s.png` | **PASS** | 1536x256 RGBA | INFO: body centre (torso band) -3.3 px from pivot x 128 (frame 0); INFO: legacy bottom-12-row centroid -12.6 px (tool butt / 3-4 stance; not gated); INFO: planted-feet drift 0.0 px@2x (support foot y 239..239, stance x 128.2..128.2); INFO: contact AO 66x22 px@2x, peak alpha 0.20, centre x 130.3, in 6/6 frames; INFO: 1x matches 2x downsample (alpha \|d\| 0.0, colour 0.5); INFO: 6 f @ 8 fps, loop False |
| `farmer/_2x/work_n.png` | **PASS** | 3072x256 RGBA | INFO: swing/far foot up to 1 px above the support foot; support foot rows 239..239; INFO: body centre (torso band) -9.5 px from pivot x 128 (frame 9); INFO: legacy bottom-12-row centroid -16.1 px (tool butt / 3-4 stance; not gated); INFO: contact AO 66x22 px@2x, peak alpha 0.20, centre x 129.1, in 12/12 frames; INFO: 1x matches 2x downsample (alpha \|d\| 0.0, colour 0.5); INFO: 12 f @ 10 fps, loop True |
| `farmer/_2x/work_s.png` | **PASS** | 3072x256 RGBA | INFO: swing/far foot up to 9 px above the support foot; support foot rows 239..239; INFO: body centre (torso band) -7.4 px from pivot x 128 (frame 2); INFO: legacy bottom-12-row centroid -12.6 px (tool butt / 3-4 stance; not gated); INFO: contact AO 66x22 px@2x, peak alpha 0.28, centre x 129.2, in 12/12 frames; INFO: 1x matches 2x downsample (alpha \|d\| 0.0, colour 0.5); INFO: 12 f @ 10 fps, loop True |

Contact sheet: `/workspace/stasium-pc-look/previews/npc/farmer_contact.png`, `/workspace/stasium-pc-look/previews/npc/farmer_contact.jpg`

Status rules: FAIL blocks import; WARN needs review; INFO is measurement only.
