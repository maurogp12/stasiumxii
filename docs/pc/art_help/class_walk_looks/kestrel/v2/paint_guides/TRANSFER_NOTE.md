# Kestrel v2: getting repainted legs back into the rig

## A. Repainted full-figure keys (`paint_guides/{S,E}_fNN.png`, f00/f03/f06/f09)
Each guide has `{S,E}_fNN_joints.json` with R/L hip, knee, ankle, heel and toe in that image's pixels, plus `cell_to_img` (image = cell * scale + offset).
1. **Mask the legs.** Key out the flat grey 172 (colour distance ramp 8..22, keep the largest component). Then keep only the legs: below the belt line, take the region that overlaps the sheet-B leg alpha dilated by about 6 px. The pelvis/hem stays with the body layer.
2. **Align by joints.** Split the masked legs into near and far using the rig's own leg alphas at that frame. Map each leg back to cell space with `cell_to_img`. Paint drift is fine because the joints are used, not the pixels: re-mark hip, knee, ankle and toe on the repaint if they moved.
3. **Blend the in-betweens.** Don't cross-dissolve. Turn each repainted key into a phase key (B) and let the rig bend the nearest key to every frame's joints with the same 3-bone skin as `kbuild.leg_skin` (smoothstep blends at the knee and ankle, so there are no seams). The far leg gets the rig's 12 % darkening and rim gap.

## B. Phase keys (preferred, Claude 5981325175): `phase_guides/{S,E}_{near,far}_{fwd,under,back}.png`
- Repaint each guide (one hip-to-toe leg on grey 172, about 768 px tall). Keep the joints near the marked positions, or update the JSON.
- Drop the result into `kestrel/v2/phase_keys/` with the same file name and the guide's `.json` next to it.
- `scripts/phase_keys.py` handles the rest:
  - Mask: use the alpha if present, otherwise key out grey 172.
  - Pick a key per frame by phase: nearest thigh angle and leg axis, with the plants as tie-break (heel-only = fwd, toe-only = back).
  - Warp: 3-bone light skin from the key joints to the frame joints. The across-bone scale is fixed at the key's export scale, so the thigh/boot ratios carry over from the painting.
- Round-trip test: `python3 scripts/phase_keys.py --selftest` uses the guides as keys and prints the alpha IoU against the procedural leg for each frame.
- Not wired into `kbuild.render` yet. The hook is `phase_keys.leg_layer(F, role, joints, (CH*RS, CW*RS), RS, heel, toe)`, called in place of `leg_skin` when keys exist. That is about 6 lines and goes in once painted keys are in hand.
