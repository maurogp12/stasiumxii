# Crosshaven walled city in the PC world (CX1)

Status: **prototype, stand-in art**. Branch `claude/pc-crosshaven-city`, from `pc/world-seamless`.
Source: the Rosebud plate package on `docs/pc-map-handoff` (`docs/pc/map_handoff/crosshaven/rosebud/`, v9).

## What the world does today

- `crosshaven_world.gd` loads a region index (`data/world/crosshaven/index.json`, 33 chunks) through
  `WorldMap` / `WorldZone`. Each chunk is a cell grid of 64x32 diamonds
  (`BoardVisualSort.cell_to_local`). The world plane (`backend/world_plane.gd`) lays chunks side by
  side from their exit links and mounts the neighbours, so the walk is seamless.
- The ground is drawn per cell from the tile kit (`crosshaven_ground.gd`); props and decor are nodes
  with absolute `z_index = (x + y) * 10`. The hero (`crosshaven_walker.gd`) sorts by its ground
  screen y (`round(y * 10 / 16) + 4`). A prop fades to 0.45 while the hero stands behind it
  (`update_cover`).
- The atlas (`backend/world_atlas.gd`) is strict: 88 level chunks, gates must cross regions,
  every region must be reached from the Crossroads. Tests pin the 33 chunks.
- Dungeons draw painted backdrops with a fitted affine: `build_tools/dungeons/board_kit.py`
  writes `cell00_centre_px`, and the board view draws the image at `-cell00_centre_px`.

## Choice: a plate-backed zone outside the atlas

The city is one painted plate, not tiles, so it cannot be a normal chunk and it must not change the
atlas or the plane (that would move or break the 33-chunk Crossroads world). It is a **separate
one-zone map**:

- `data/world/crosshaven_city/city.json` (`stasium.plate_city` v1): plate fit, the cell grid as
  text rows, heights, gates, bridges, player plots, NPCs and pets, gate stubs.
  `layers.json`: the 393 sprite layers (plate px), each with `sort_y`, a fade flag and a coarse
  alpha mask for the fade test.
- `backend/plate_city.gd` reads it and builds an ordinary `WorldZone` + `WorldMap`, so the walker,
  `WorldWalk.find_path`, picking and hover work unchanged. The zone is 109 x 120 cells (the
  standard zone file caps chunks at 128 and stores one JSON record per tile; the text rows keep
  the file small).
- `scenes/world/crosshaven/crosshaven_city_plate.gd` draws it: ground image, y-sorted layers,
  plot houses, pets, and the fades. The world swaps it in for the tile ground when the zone has a
  plate; nothing else in the world loop changes.
- **Placement is data.** The city is reached by a gate stub in `city.json` (`gate_stubs`, Crossroads
  cell (16, 27) to the city road, and the city's south road end back), by `--start-zone=crosshaven_city`
  and by the dev warp key F8. The Crossroads zone file is untouched. If Mauro keeps the Crossroads,
  set the stub where the city should hang off the map; if the city replaces it, point the atlas
  entry at this zone later. Disabling the stub is `"enabled": false`.

## Scale and angle (measured)

| Measure | Plate | Game | Result |
|---|---|---|---|
| Bridge deck axes (3 bridges) | slope 176.7 / 353.6 = 0.4997 | 2:1 | iso x axis |
| Gate passage axis | slope 102.9 / 205.7 = 0.5002 | 2:1 | iso y axis |
| Ground texture lattice (FFT autocorrelation) | (64, 32) step, 128x64 diamonds | 64x32 cells | ground texture is 2x the game tile |
| Hero | Rosebud hero ~56 px | world heroes 54.5-62.7 px | 1.0 to 1.1 |
| Sprites | 2x kit pieces drawn at k x 0.5 (k = 1.0-1.75) | 2x kit drawn at 0.5 | 1.0-1.75x game scale |

**Fit: translation only, scale 1.0** (1 plate px = 1 world px). The angle is exact 2:1. The cell
lattice is shifted so the three bridge decks and the gate passage run along rows of cell centres:
`cell00_px = (2492.5, -357.25)`; residual offsets from the deck centre lines are +4.9, -0.5 and
-4.9 px (the open deck corridor is 34 px), gate 0.0 px.
Known mismatch: the plate's painted ground repeats at 128x64 (two game cells), and the landmarks
are drawn 1.45-1.75x the game kit scale. The hero reads small next to the castle and cathedral;
that is the plate's choice, kept as is.

## Walkability

`walkmask.png` (white = walkable, sampled at the feet) becomes cells: a cell walks when its centre
is white and at least 60 % of its inner half-size diamond is white. Heights come from
`heightmap.png` (10 px a step, so the bridge crown is step 6). Only the component joined to the
south road is kept. Walls, towers, buildings, trees and the river block; the three bridges are
entered only from their stair bottoms; the gate arch is the only way through the south wall.

## Depth and fade

Every layer is a `Sprite2D` with absolute `z_index = round(world_sort_y * 10 / 16)`, the walker's
own formula, so the hero, NPCs, pets and layers share one y-sort. Bridges and the NW steps sit just
above the ground (Rosebud `under_everything`).
Fade (Luca's rule, every obstacle): a layer at least 40 px tall that draws in front of the hero and
whose opaque pixels (8 px mask) overlap the hero's body box ramps to its `fade_min_alpha`
(0.45, lintel 0.40) over 0.25 s. This includes walls and workshops, which the Rosebud export kept
opaque. Performance mode: the half-size ground, instant fades, no pet hops, NPCs at the lite idle rate.

## Player plots

The 5 plots are moved by a search in `build_tools/crosshaven_city/build_city.py`: the Legendary
clearance (an iso ellipse 350 x 175 px with its bottom on the anchor) must clear streets, the wall
and tower sprites, the river, landmarks and houses, and the other plots. The old houses and their
plants are lifted off, their footprints opened, the plants moved with the plot. Exterior tier per
the README table (P1 rare, P2 legendary, P3 rare, P4 normal, P5 normal); change `plots[].tier` to
swap. No garden beds. Each anchor has 2 walkable front cells joined to the street network (test).

## Rebuild

```
git archive origin/docs/pc-map-handoff docs/pc/map_handoff/crosshaven/rosebud docs/pc/map_handoff/crosshaven/housing_tiers | tar -x -C /tmp/cx
python3 build_tools/crosshaven_city/build_city.py /tmp/cx/docs/pc/map_handoff/crosshaven .
```

Tests: `tests/run_crosshaven_city_tests.gd`.
