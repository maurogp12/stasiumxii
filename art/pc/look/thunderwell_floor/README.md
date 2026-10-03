# Thunderwell Core floor (L4), STASIUM XII PC — v3b

Ship-ready PNGs for the Thunderwell Core combat floor (Godot 4.7.2, linear filter, no mipmaps, straight alpha).
Masters are `<name>@2x.png`, drawn at half size; plain `<name>.png` is the half-size fallback.
Format "option A" (signed off by Stasium Bot, Technical Artist and Rosie): 8-slot route strip with exact edge-midpoint ports. v3b (Oct 3): slot h is now a side bend; plates restyled to green-slate with a quieter bevel; traces more painted; pillar core toned.
Machine-readable slot map, ports per slot, flip table, glow tint/strength: `thunderwell_floor.json`.
Previous ship contents (v1) are archived at `ship_archive/thunderwell_floor_v1b/` (PNGs identical to `ship_archive/thunderwell_floor_v1/`).
Raws: `raw/thunderwell_floor_v3/` (plates.png, route_pieces_lit.png, route_pieces_dark.png, pads_v2.png, pillar_v2.png).
Build: `/workspace/scratch/v3/tw_build_all.sh [outdir]` (deterministic; a rebuild into a separate folder reproduced every PNG pixel-for-pixel and the json byte-for-byte).

## Files

| File | Size | Mode | Notes |
|---|---|---|---|
| `floor_tiles@2x.png` | 1024x64 | RGBA | 8 slots of 128x64, order **a b c d e f g h**: a plain, b plain, c straight (2 ports), d bend round the top corner (2), e T-junction + ball node (3), f end node (1), g cross + ball node (4), **h side bend round the right corner (2; same profile, radius 0.28 and treatment as d)**. Hard 2:1 diamond alpha (255 inside the checker diamond, 0 outside); transparent texels carry edge colour (push-pull). Base stone for every slot is one of the 4 painted slate plates (homography to 2:1 at 8x, gold glare removed, highlights compressed, bevel symmetrised for light from straight above): a=plate1, b=plate2, c=plate4, d=plate1 mirrored, e=plate2 mirrored, f=plate3 mirrored, g=plate4 mirrored, h=plate3. **v3b restyle, identical on all 8 slots:** green-slate hue 160 (p5–p95 150–168), saturation 0.147 median (0.115–0.176); bevel highlight and shadow contrast cut ~48% (band highlight +0.142 → +0.073, shadow −0.080 → −0.044 relative to the cell interior); low-frequency per-slot value variation (±7% mottling + a small per-slot offset) and fine warped veins inside the cell (seam band kept clean); global gain back to the v1 mean. Traces: dim green glass grooves (hue 140) with dark engraved rims, brush-load variation, slight edge wobble and a faint irregular glow bleed into the stone; all of that fades to one identical look within 14 px of every port, so seams match. |
| `floor_tiles.png` | 512x32 | RGBA | Area half size, hard 64x32 diamond re-applied. |
| `glow_mask@2x.png` | 1024x64 | RGB | Data texture, lossless. **R** = emission 0..1, full range (max 255), no cap. Flat painted core (plateau to 2.5 px from the centreline, soft shoulder to 0.42 at 5.5 px, short exponential halo cut at 16 px), with along-track texture from the lit painting and paint-load variation inside the run (both faded out near ports, so all port profiles are identical; port plateau sits at 0.92 because interior strokes peak higher). Ball nodes have a bright ring and a dim centre; the end node has an emissive dot. **G** = 1 on traced paths (core width 7 px at 2x), 0 elsewhere, identical at every port, no direction encoding. **B** = 0. Slots a and b are all zero. |
| `glow_mask.png` | 512x32 | RGB | Area half size, R renormalised to full range. |
| `pad_blue@2x.png` | 128x96 | RGBA | From pads_v2.png (left chip). Top-face rhombus mapped by affine to a 2:1 face (v1 framing, face x 4..124, y 20..80). Decorative top-face traces calmed (grey opening blended 72%), gloss and highlights compressed, bevel/side/pin rim kept. Hue ~225, every chroma pixel 216–238 (none under 215); mean luminance 0.19, far darker than #73C7EB (0.72). Bottom 128x64 cell diamond opaque (gaps = slot-a slate tinted by the pad glow); outside the diamond alpha = chip coverage only. |
| `pad_blue.png` | 64x48 | RGBA | Premultiplied area half size, base diamond forced opaque. |
| `pad_red@2x.png` | 128x96 | RGBA | Same treatment (right chip). Crimson ~352, every chroma pixel 348.5–356 (no orange, no magenta). |
| `pad_red.png` | 64x48 | RGBA | As above. |
| `light_pillar@2x.png` | 128x512 | RGB | From pillar_v2.png, 1:4 crop on the beam (raw x 848..2192). Background and the dark floor patch estimated outside the beam (push-pull) and subtracted; ground speckle removed, so the surround is pure black (52% of pixels exactly 0). Hue 140, pale green-white. Defined core (centre crest + painted streaks), soft wisp halo, top fade. **v3b:** highlights above 0.30 rolled off so the art peaks at 0.62 luminance (was 0.96); the halo below 0.30 is unchanged. **L4b:** the beam is carried down into the plate, and the base is a filled green pool with a brighter ring (outer radius 28px at 2x, about 14px at 1x) so the emitter reads at half size. Additive at ~0.45; light-pool centre stays (64, 441). |
| `light_pillar.png` | 64x256 | RGB | Area half size, values ≤ 1/255 set to 0. |
| `room_edge_dark@2x.png` | 1024x640 | RGB | v1 vignette with per-pixel luminance unchanged; hue moved from teal 184° (sat 0.54) to green-slate 145° (sat 0.35), because the teal sat in the cyan family the palette now excludes. |
| `room_edge_dark.png` | 512x320 | RGB | Same treatment of the v1 fallback. |
| `thunderwell_floor.json` | — | JSON | Slot map, ports per slot and per flip, port pixel positions, grid convention, glow tint/strength/pulse, pad/pillar anchors, measurements. |

## Ports, flips, routing
- Ports sit exactly on the edge midpoints (NE (96,16), SE (96,48), SW (32,48), NW (32,16) at 2x, continuous coordinates). Paths are built in cell space, run straight through the midpoint perpendicular to the edge and are extended past it, so every port has the same width and glow profile and is mirror-symmetric about the edge normal. Seams join under any h flip (columns c → 127−c) or v flip (rows r → 63−r).
- Canonical ports: c NW+SE, d NW+NE, e NW+SE+NE, f NE, g all four, h NE+SE. `ports_by_flip` in the json lists every orientation.
- **Every turn is covered:** d + flips gives the top (NW+NE) and bottom (SW+SE) corners; h + flips gives the right (NE+SE) and left (NW+SW) corners. Straight, T, end and cross cover all orientations.

## Glow use
`rgb += tint * min(R * strength * pulse(G), cap)` with tint (0.28, 0.95, 0.50) = #47F280 (hue 140), **strength 0.25**, pulse(G) = G · p(t), p(t) = 0.7 + 0.3·sin(2πt/T). At strength 0.25 the brightest trace pixel is 0.28 luminance at mid pulse and 0.34 at full pulse, both below the darkest lit move tile (#73C7EB @ 0.5: 0.37; mean 0.42).

## Checker
`python3 tools/check_assets.py ship/thunderwell_floor --package thunderwell` (Technical Artist's v3 checker: flip-orbit port sets incl. h side bend, bilinear sampling at the exact midpoints, exact W−x mirror, tolerance 0.20) → **Overall PASS, no WARN, no FAIL** (Oct 3, 2026, ~02:27 ET). Only note: "INFO: fully transparent pixels contain non-black RGB values" on floor_tiles and pads (intended edge-colour bleed). Fallbacks recognised and ignored. Report: `ship/check_report_thunderwell.md`.
Port metrics against the checker's own sampler: port sets a – b – c NW+SE, d NW+NE, e NE+NW+SE, f NE, g all, h NE+SE (all valid orientations); max deviation from the median profile 0.007, max asymmetry 0.007 (limit 0.20).

## Previews (outside ship)
`previews/thunderwell_floor/`: `v3b_a_seam_chain_board.png`, `v3b_a_seam_chain_zoom4x.png`, `v3b_b_composite_board.png`, `v3b_b_composite_zoom2x_pillar_move.png`, `v3b_c_v1_vs_new.png`, `v3b_d_asset_sheet.png`, `v3b_measurements.json` (the earlier `v3_*` files are the pre-v3b state).

## Art notes
- Painted route pieces could not be used as geometry (elongated hexagons, ports off the midpoints, ~44 raw px wide cores, cyan hue). Traces are rebuilt on exact paths and dressed from the paintings: core/halo falloff and along-track texture from the lit sheet, the junction ball from the dark sheet (re-tinted green-slate, spec highlight capped), brush-streak and paint-load noise along the stroke. At game zoom they read as painted glass grooves; magnified 4x the lit core still looks fairly even/clean.
- Four plates fill eight slots, so plates repeat (mirrored copies), broken up by per-slot value mottling and veins. The bevel is ~48% quieter; at board scale it recedes behind the move range, but magnified it still reads as a bevelled seam.
- Floor value matches v1: mean luminance 0.1137 (v1 0.1137).
- Pads keep the clip-art QFP chip silhouette of the raw; only the face detail and gloss were calmed.
