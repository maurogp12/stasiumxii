# Windmere world kit (WP10a)

Crosshaven-schema kit for `res://art/world/windmere/`, built from the painted raws in `raw/wp10a_windmere/`.
Gate: `tools/check_assets.py <kit> --package world` (report: `../check_report_world_wp10a_windmere.md`).

- `tiles/` + `tiles/_2x/`: 45 tiles: snow_grass (a/b/c), white_flagstone (a/b) and glossy_ice (a/b), plus 19 edge and corner autotiles each for flagstone and ice against snow_grass.
- `props/` + `props/_2x/`: 13 props.
  - `border_snowy_pine_wall`, `_b` and `_c` are the three wall variants on the manifest 96x128 (1x) canvas. Each overlaps its neighbours by about 15 px at 1x.
  - The three pines: tree_conifer canvas 96x128 (1x) / 192x256 (2x) at full manifest height, unclipped.
- `props/emit/` + `props/emit/_2x/`: greyscale emission masks.
  - ice_crystal_cluster: crystal cores.
  - lantern_post_warm: warm glass.
  - frost_spire: windows plus crystal crown.
- `animated/`: sway strips, sway masks and shadow strips for the three pines and the pine walls, plus `anim_meta.json`.
- `atlas_meta.json`: the full atlas. `props.json`: the checker index.

All art is painted in natural colour. The Windmere stand-in grade is recorded in atlas_meta for reference only and is not baked in.
Sprites have no baked cast or contact shadows.

STATUS: parked 2026-10-03 (plan changed to Crosshaven only; parked, not rejected). Last check: `--package world` PASS (70 files, 0 WARN, 0 FAIL). TA fix list items done: pines moved to tree_conifer (96x128 at 1x) with size class recorded; metadata rebuilt and cross-checked against the PNGs (sizes, anchors, sway frames all match). Remaining: build step that writes the meta straight from the measured PNGs; snow_grass_a/b/c rebuild from snow_grass_v2.png (separate crops per variant); new walkable ice_crust tiles (ice_crust_a/_b plus edges) from ice_crust_walkable.png; glossy_ice still needs walkable:false / frozen_water in atlas_meta, and the mock board needs ice_crust on the walkable ice cells; brightness match across tiles; regenerate previews/wp10a_windmere (current props sheets show the pines on the earlier canvas). Note: the v2 swatches on disk are 1280x720, not the 1024x576 stated in the hand-off.
