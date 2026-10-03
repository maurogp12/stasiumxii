# Thunderwell Core decoration props v2, STASIUM XII PC

Six decoration props cut from the Scenario paintings in `raw/thunderwell_props_v1/`. Masters `<id>@2x.png`, half-size fallback `<id>.png`,
emission mask `<id>_emit.png` for the five glowing props. RGBA colour art: straight alpha, soft anti-aliased edges, RGB = 0 wherever alpha = 0.
Metadata: `props.json`. Build: `/workspace/scratch/v3/tw_props.py` (cut-out) then `tw_props_v2.py` (anchors, emit masks, metadata).

| id | canvas @2x | footprint | anchor @2x (south tip) | height @2x | edge rule | emission |
|---|---|---|---|---|---|---|
| `coil_pylon` | 120x232 | 1x1 | (60.0, 225.0) | 218 | back-edge only | `coil_pylon_emit.png` 60x116, strength 0.45 |
| `broken_generator` | 248x224 | 2x2 | (124.0, 217.0) | 213 | back-edge only | `broken_generator_emit.png` 124x112, strength 0.45 |
| `cable_bundle` | 120x120 | 1x1 | (72.0, 118.0) | 109 | any room edge (front/south allowed) | `cable_bundle_emit.png` 60x60, strength 0.35 |
| `capacitor_crystal` | 120x152 | 1x1 | (60.0, 145.0) | 138 | back-edge only | `capacitor_crystal_emit.png` 60x76, strength 0.3 |
| `conduit_pipe` | 96x112 | 1x1 | (24.5, 106.0) | 100 | any room edge (front/south allowed) | `conduit_pipe_emit.png` 48x56, strength 0.35 |
| `slate_rubble` | 104x112 | 1x1 | (52.0, 105.0) | 95 | any room edge (front/south allowed) | none |

## Anchor and footprint
- The anchor is the footprint's real south tip, not the lowest painted pixel. A 1x1 footprint at 2x is a 128x64 diamond with its west/east corners at
  x = anchor -64 / +64 and y = anchor - 32; a 2x2 footprint is 256x128 (corners at +-128, y - 64).
- Props on a slab (`coil_pylon`, `capacitor_crystal`, `broken_generator`, `slate_rubble`) are centred on their slab; slabs are slightly narrower than the cell,
  so the tip sits up to 4 px below the slab's front corner. `cable_bundle` and `conduit_pipe` lie or arc across their cell, so the tip is the lowest diamond
  that contains every ground contact (the tip is empty floor 5 px (conduit) to 17 px (cable) in front of the art; the checker's "anchor y vs lowest opaque row" WARN is expected for these two).
- Canvases were padded with transparent rows at the bottom so the anchor lies inside the canvas; the art itself is unchanged.

## Emission masks
- `<id>_emit.png`: same size as the 1x fallback, 8-bit greyscale, white where the prop glows (coil glass, generator cracks, crystal, green sleeve/connector ends,
  conduit joint), black on metal and stone, soft edges. Data texture: import without source_color (linear), no mipmaps.
- Suggested shading: `rgb += albedo * emit * strength` before bloom. `emission_strength_default` in `props.json` is only a starting value; the live strength
  lives in Thunderwell's data file, like the floor glow strength (`thunderwell_floor.json`).

## Import notes
- Linear filter, no mipmaps (same as the floor kit).
- Y-sort with fighters using the anchor (south tip of the footprint); a 2x2 prop sorts by its own south tip.
- Place on room-edge cells only (just outside the board), never on board cells, so props never hide playable cells.
- No baked cast shadow in the art.

## Placement notes (Technical Artist)
- Tall props (`coil_pylon`, `broken_generator`, `capacitor_crystal`; over about 110 px at 2x) go only on back-edge rows, north of the board's left-right corner line.
- Front and south edges get low props only (`slate_rubble`, `conduit_pipe`, `cable_bundle`).
- Code adds a soft contact shadow under each footprint (multiply, about 0.35).
- No resizing; the current scale is approved.
