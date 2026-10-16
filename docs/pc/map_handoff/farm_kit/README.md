# Farm kit (Crosshaven farmer plot, gatherable crops)

Crosshaven-schema dressing kit for `res://art/world/farm_kit/`, built from the painted raws in `raw/farm_kit/`
(look target: `farm_target_mock.png`). Same grid, scale and light as `art/world/crosshaven/`:
2:1 iso, 64x32 tile at 1x (128x64 at 2x), key light #fff0c8 from the top-left, shade #5a6fa0, no baked cast
shadows, soft contact AO only. Import: linear filter, no mipmaps, straight (not premultiplied) alpha; RGB under alpha 0 is black.

Gate: `python3 tools/check_assets.py ship/farm_kit --package world --ref-atlas <crosshaven atlas_meta.json>`
(report `../check_report_world_farm_kit.md`). Result 2026-10-03: **0 FAIL**, 79 PASS, 19 WARN (see "Known WARNs").

Mocks (review only): `previews/farm_kit/mock_farm_crosshaven_2x.png` (+ `_1x`, `_2x_zoom160`), `mock_farm_gather_2x.png` (+ `_1x`).

## Layout

```
farm_kit/
  atlas_meta.json        tiles, props, anchors, footprints, palette, lighting, icons, gather hooks (TODO numbers)
  props.json             checker index (all 43 props, anchor_px_2x / size_class / art extents)
  tiles/<id>.png         1x 64x32        tiles/_2x/<id>.png  2x 128x64
  props/<id>.png         1x              props/_2x/<id>.png  2x master (draw at 0.5, same placement)
  animated/              sway strips, crop_glint, harvest_pop_<crop>, sway_masks/, anim_meta.json
  icons/pickup_<crop>.png  64x64          icons/_2x/pickup_<crop>.png  128x128
```

## Tiles (44)

- `tilled_soil_a/b/c` (furrows along +y) and `tilled_soil_x_a/b/c` (furrows along +x): loamy raked soil from
  `soil_swatch.png`, resampled so furrow crests line up on the cell centre (crop sprites sit on the crest) and tile seamlessly.
- 15 `..._edge_<sides>` autotiles each: ragged grass lip against Crosshaven `golden_plains` on the listed sides.
- 4 `..._corner_<n|e|s|w>` decals each. Autotile rule = Crosshaven `dirt_road` (edge piece by grass sides, corner decal where
  both sides are soil but the diagonal is grass).
- Rowanvale `tilled_rows` was not reused: the target wants darker, wetter loam than Rowanvale's dry rows.

## Props (43, all anchor = image bottom-centre on the south tip of the south-most footprint cell)

| group | ids | canvas 1x | footprint | notes |
|---|---|---|---|---|
| crops | `cabbage_*`, `wheat_*`, `pumpkin_*`, `carrot_*` with `_young`, `_ripe`, `_ripe_b`, `_harvested` | 64x64 (small) | 1x1 | walkable dressing on soil; **all states of a crop share canvas, anchor and footprint: swap the texture in place**. `_ripe_b` = second ripe look, pick by cell hash |
| crops | `crop_seedling` | 64x64 | 1x1 | optional just-planted state |
| buildings | `farm_shed_2x2` | 128x192 (landmark) | 2x2 | thatched shed, door faces SW (+y); raw 3/4 view warped onto the iso grid |
| props | `hay_cart_2x2` | 128x192 (landmark) | 2x2 | straw-loaded cart |
| props | `scarecrow_farm` | 64x112 (tree) | 1x1 | |
| yard | `water_barrel`, `clay_pots`, `hay_bale_square`, `bucket`, `grain_sack`, `wheelbarrow` | 64x64 | 1x1 | blocking |
| fence | `rail_fence_nwse`, `rail_fence_nesw`, `rail_fence_corner_n/e/s/w`, `rail_fence_end_nw/ne/se/sw`, `rail_fence_post` | 64x64 | 1x1 | weathered split rail; post on the cell centre, rails to side midpoints so cells chain; `end_*` pieces make a road/gate gap (leave the gap cell empty) |
| decor | `wildflowers_a/b/c/d`, `grass_tuft_meadow_a/b` | 64x64 | 1x1 | walkable meadow dressing in the Crosshaven grass palette |

Scale reference: farmer NPC frame 256 px @2x, pivot (128,240), body ~120 px tall @2x. Crops are 40-84 px tall @2x
(below his waist), the shed ridge is ~220 px @2x (taller than him), the hay cart bed is about hip height.

## Animated (`animated/anim_meta.json`)

- `wheat_<young|ripe|ripe_b>_sway`, `carrot_<...>_sway`: Crosshaven grass sway method, 16 f @ 8 fps (2 s loop), frame
  76x64 at 1x (6 px pad each side), bend grows with height, base pinned, per-plant phase; sway masks (L) in `sway_masks/`.
  Randomise start frame and speed_scale 0.85-1.15 per cell.
- `crop_glint`: 8 f @ 8 fps loop, 64x64 frame, same anchor as the crop. Soft warm sparkles plus a faint ground halo, no neon.
  Draw over every `*_ripe` crop to mark it gatherable; random start frame per cell; hide on harvest.
- `harvest_pop_<crop>`: 8 f @ 12 fps one-shot, frame 64x96 at 1x (bottom-centre = south tip of the cell). Leaf or straw burst,
  dust puff, then the pickup icon rises about 44 px (1x) and fades. Swap `_ripe` -> `_harvested` on frame 0.

## Pickup icons

`icons/pickup_<cabbage|wheat|pumpkin|carrot>.png` 64x64, `icons/_2x/...` 128x128, cut from the ripe art with a thin dark outline.
They are UI art, so atlas_meta does not list them as world sprites (that is why the gate lists them as unreferenced).

## NPC nameplates (UI)

`ui/nameplate_farmer.png` 65x23 (`ui/_2x/` 130x46): dark wood strip, thin gold edge, gold cap rivets, warm cream
small-caps serif text "Farmer", soft cool drop shadow (3 px margin at 1x around the body). No proper name exists for the
farmer in the repo (docs/pc/ZONES_BUILD_SPEC.md names NPCs by role, e.g. "Guide"; no `data/world/npcs.json` yet), so the
text is the role title. Float it over the head: body bottom 5 px (1x) above the head top (pivot - 60 px at 1x).
`ui/nameplate_blank.png` 54x23 (`_2x` 108x46) is the same plate with no text, for other NPCs: 9-slice margins
L/R 11, T/B 8 at 1x (22/16 at 2x), stretch horizontally only. Draw the name in-engine: Alegreya SC Bold (SIL OFL),
11.5 px at 1x, `#f5e3bd`, about 1 px `#170d08` outline. See `atlas_meta.json > ui`. Screen space, never y-sorted, not graded
by the world light.

## Changes v2 (2026-10-03, map composite pass)

- `pumpkin_young`: greener (hue pulled toward leaf green, +28 % saturation, -10 % value) and smaller (36 px tall at 2x, was 42),
  so it no longer reads like `pumpkin_harvested`. Leftover white paper specks in the pumpkin vine cut are removed.
- `crop_glint`: stronger so it reads at 1x: sparkles +30 % longer with wider rays, a thin warm-umber edge under the rays
  (so they read on bright wheat), a stronger warm halo and motes, and a broader on-time per sparkle. Still warm cream and gold, no neon.
- `ui/` nameplates added (see above). Other sprites are unchanged.

## Gather hooks (TODO for Stasium Bot)

`atlas_meta.json > gather.crops.<crop>` names the state sprites, marker, pop strip and icon. These fields are set to
`TODO(Stasium Bot)` on purpose: `item_id`, `yield_per_gather`, `regrow_time_s`, `growth_time_young_to_ripe_s`,
`harvested_resets_to`, `gather_range_cells`, `tool_required`. The art does not set any gameplay numbers.

## Known WARNs (world gate)

- 19 props report "lowest opaque row 25-30 px above the anchor (>24)": the 4 pumpkin states, the 11 fence pieces,
  scarecrow_farm, bucket, wildflowers_c and wildflowers_d. This is by design. Their footing is on the cell centre (32 px above
  the south tip at 2x): pumpkins sit on the furrow crest, and fence posts stand on the centre so rails meet at the side
  midpoints. Every base is inside the footprint (0.0 px out).
- The 8 pickup icon PNGs and the 4 nameplate PNGs show as "unreferenced" because they are UI art (see the `icons` and `ui` blocks),
  which the world gate does not read.
- `--package props` (room-edge prop rules) also runs at 0 FAIL. Its WARNs are the same base-height note, because that
  package expects art to touch the canvas bottom.

STATUS: PROPOSED 2026-10-03, waiting for Luca to approve the mock. Not wired in-engine and not committed to the repo.
