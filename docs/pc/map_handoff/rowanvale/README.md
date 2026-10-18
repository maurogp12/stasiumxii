# Rowanvale world kit (WP10a)

Crosshaven-schema kit for `res://art/world/rowanvale/`, built from the painted raws in `raw/wp10a_rowanvale/`.
Gate: `tools/check_assets.py <kit> --package world` (report: `../check_report_world_wp10a_rowanvale.md`).

- `tiles/` + `tiles/_2x/`: 45 tiles: meadow (a/b/c), orchard_soil (a/b) and tilled_rows (a/b), plus 19 edge and corner autotiles each for orchard_soil and tilled_rows against meadow.
- `props/` + `props/_2x/`: 16 props, including the static `old_windmill` (body plus sails at frame 0).
  - Apple, fruiting apple and pear trees: tree_broad canvas 112x128 (1x) / 224x256 (2x) at full manifest height. Border hedges: border_tall canvas 96x128 (1x).
  - `old_windmill_body` and `old_windmill`: landmark_wide canvas 288x256 (1x) / 576x512 (2x) so the larger sails fit.
- `animated/`: sway strips, sway masks and shadow strips for trees, hedges and the flower bush.
  - `old_windmill_sails.png`: 12 frames, 7.5 deg/frame, 10.8 fps, frame 200x200 at 1x, sail radius 96 px at 1x.
  - `anim_meta.json`.
- `atlas_meta.json`: the full atlas (anchors, footprints, palette, lighting, windmill hub, processing notes).
- `props.json`: checker index (all 16 props).

Windmill hub offset from the body anchor: (-39, -150) px at 1x, (-78, -300) px at 2x.
Sprites have no baked cast or contact shadows. The zone grade is applied at runtime and is not baked into the art.

STATUS: parked 2026-10-03 (plan changed to Crosshaven only; parked, not rejected). Last check: `--package world` PASS (75 files, 0 WARN, 0 FAIL). TA fix list items done: size classes recorded (tree_broad, landmark_wide); metadata rebuilt and cross-checked against the PNGs (sizes, anchors, sway frames all match); fruiting apple and pear canopies hue-shifted to the plain apple's green (pears masked out, red apples kept); hedges shifted to hue ~70, saturation x0.86, run ends trimmed (base now max 7.8 px past the cell, was 22.7); beehive boxes repainted off-white (lid and legs honey-gold wood). Remaining: build step that writes the meta straight from the measured PNGs (only checked after the build so far); orchard_soil_a/b rebuild from orchard_soil_v2.png (leaf litter, apples kept off the tile, brightness matched); visual sign-off on the hedge end trim and beehive recolour; regenerate previews/wp10a_rowanvale (current previews show the pre-fix trees, hedges and beehive).
