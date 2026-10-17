# Crosshaven walled city in the PC world (CX1)

Status: **map base, prototype; buildings hidden**, in the game on branch `claude/pc-crosshaven-city` (from `pc/world-seamless` 7b8d80c6).
Source: the Rosebud plate package on `docs/pc-map-handoff` 98d2cc5c (`docs/pc/map_handoff/crosshaven/rosebud/`, v9).
Change list: `docs/pc/look_target/crosshaven_city/README.md` on `claude/pc-zones-spec` ("Mauro's change list", items 1-9).

## Current state: map base after the review round (supersedes the older sections below where they disagree)

- **Map base only (item 17).** Houses, stalls, landmarks (castle, cathedral, town hall, bank, workshops,
  mill), the fountain and the well are hidden: they keep `hidden: true` in `layers.json` and their walk
  footprints stay reserved. Clearing `map_base_only` in the layout shows them again. F9 draws the
  reserved footprints (`building_footprints`). Plot houses are hidden too.
- **Ground (review 1).** Grass and cobble come from the coordinator tiles, projected on the iso lattice.
  The cobble tile is drawn at 0.35x, so a stone reads a hero foot to shin across. The grass is at 0.7x.
  A second grass layer (rotated 90 degrees, offset, 1.13x) is blended in by low-frequency noise to
  break the clover repeat (`ground_textures` in the layout). Round 3: that layer is at 0.6 contrast
  and 0.8 weight. Very-low-frequency value and hue patches (about +-6%, about 1400 px) are added.
  Outside the walls the meadow is 10% less saturated and 5% darker. Tiles are resized seamlessly
  (3x3, resize, keep the middle).
- **Walls: kit v2 ring.** The approved segments and tower from `work/walls/kit2` + `kit/tower`. The
  ring uses only the two iso diagonals plus horizontal N/S runs. Towers sit at the corners and every
  7 wall heights. **No ring tower stands within 1.3 wall heights of a gatehouse**, corners included
  (review 3, `no_tower_near_gate_wall_heights`), so 5 ring towers remain. The castle is not placed;
  its N-wall footprint stays reserved.
- **Gatehouses: kit3** (`docs/pc-map-handoff` 4bd032f3, `work/walls/kit3`, copied to
  `art/world/crosshaven_city/kit/`).
  - **W, E, SE** use `gatehouse_diag_v3` (and its mirror), with full 1000 px flanking towers.
    Its base slope (-0.433) matches `segment_short`. Its parapet (-0.317) is sheared 0.07 more than the
    segment's (-0.387), so the two parapet lines meet; in data that is `art_slope` -0.3633. It is also
    dropped 30 native px (580 vs 550, about 5%; `drop_px`). The near tower draws in front of the run;
    the far tower draws over the run's tucked-in strips and stays behind a hero in the arch.
  - **N and S** use `gatehouse_horizontal` (the final colour- and roof-matched version), with no shear.
    It is one piece sorted on the wall line, dropped 6 px (556 vs 550).
  - Arch openings: 68 plate px (diagonal) and 103 plate px (horizontal). The art team's hero width is
    48 px at a 156 px hero, so 2.2 hero widths is 37 plate px; the walk passage is 72 plate px.
  - Two water gates sit at the river crossings.
- **Road-wall contacts** (found from the street pixels). N, W, E and SE are gates. The S gate carries
  the spawn road. Five streets are pulled back inside the ring. None crosses the wall without a gate
  (tested).
- **Towers and joins (round 8).**
  - **One tower style.** Every ring and corner tower is the v5 gatehouse's left flanking tower, cropped as its own sprite by `build_tools/crosshaven_city/crop_tower.py` (curtain cut away by mirroring the tower's clean left silhouette; no new art). The old tilted tower is gone.
  - **Placement.** It is painted face-on, so on a diagonal its painted bottom (the front of its base) stands |slope| x base radius in front of the wall line. It sorts at that front point.
  - **Joins.** The kit's diagonal wall face shrinks across the tile (merlon line -0.39 against foot -0.43), so each column is now scaled about the foot to a constant face (`taper`). Both runs tuck half a body radius under the tower, and a strip crossing the tower's silhouette sorts behind it. Merlon and foot lines run on through every tower along a wall (measured from the drawn strips: within 1.2 px).
  - **Known step.** Where a flat N/S run meets a diagonal at a corner tower, the merlon line steps about 35 px, because the approved flat segment's face is 545 art px against 627 for the diagonals.
  - **Snapped gates.** A gatehouse whose outer tower stood within 1.5 tower widths of a corner slides along its edge so that tower is the corner: S 172 px, N 214 px, E 218 px, W 44 px. No doubled tower, no gap.
- **Round 10 (Mauro, the GOAL: "the towers all stand the same").**
  - **One tower, one size.** Ring, corner and water-gate towers are the v5 tower scaled 1.179, like the horizontal gatehouse. The diagonal gatehouse is scaled 1.152, so its near tower is the same height. Tested within 2%.
  - **Centred.** Each tower's axis is on the wall centreline, or on the corner point. Its base sits as in the v5 gatehouse (13 art px under the foot line). The near run ends at the tower body's silhouette and draws in front of it; the far run tucks behind. Both enter one body radius from the axis (tested).
  - **Even rhythm.** Fixed towers are the corners, gatehouse towers and water-gate towers. Every stretch between them is divided evenly with one spacing per side, between 1.8 and 3 wall heights. Spacing varies at most 7.3% on a side (tested, under 10%). The flat N/S sides keep a single 3-wall-height bay between gatehouse tower and corner.
  - **Water gates.** Each is flanked by v5 towers at its wall joins, slid along the wall onto the banks. A gatehouse tower or corner already standing there counts as one flank.
  - **One stone.** The wall segments and water gates get a LAB colour transfer to the v5 stone (the tower body): lightness mean and spread, a*/b* mean only. Recolour only.
  - **Removed (Mauro).** The SE gate is gone, with its road, exit stub and the spur that led to it (`drop_streets`); the wall runs closed. The NE bridge outside the water gate is gone. That leaves 4 land gates, 2 water gates and 2 bridges.
- **Round 11-12.** Stone colour statistics come from stone pixels only, with chroma clamped to the v5 tower body (within 5%, tested). The W and E gates use Grok's diagonal gatehouse v5 (73331b97). Its near tower is a v5 tower copy, scaled 1.1824 to the ring towers' size. It is anchored on both tower bases on the wall line (art_slope -0.263; the curtain itself slopes -0.364), so it needs no drop. No old-style tower art is left (tested).
- **Exits (review 7).** Every gate road runs on to the plate edge and ends in a gate stub (data,
  `gate_stubs`). The links follow the Crossroads road directions:
  - N goes to `crosshaven_road_north` (12,2), toward Northgate (proposed);
  - W goes to `crosshaven_road_west` (2,12), toward Stoneford (proposed);
  - E goes to `crosshaven_road_east` (33,12), toward Eastmarch (proposed);
  - SE goes to `crosshaven_road_south` (12,33) as a **placeholder** until the link is decided;
  - S keeps the Crossroads stub.

  The city is outside the plane, so these links are stubs, not seams. There is no way back from the
  road zones except through the Crossroads.
- **Bridges.** The 3 Rosebud bridges are kept. bridge_1 is outside the ring (NE corner) and still
  walkable.
- **Greenery.** Inside: 20 trees (oak, cypress, blossom) from `trees_keep_ring_v2.json`, on grass
  only; bushes block and flowers are walk-through; lamps, benches and planters sit at the plazas and
  along the ring road. Outside (reviews 6 and round 3): 140 oak and cypress trees in clumps of 5-15
  with overlapping crowns, hugging the wall foot and thickening into woods toward the plate edges
  (`greenery.outer_forest`, seeded). A soft dark multiply blob is baked into the ground under the
  clumps so the woods read as a mass. They keep clear of roads, the river, the gate approaches and
  the bridges. The prototype has no river rock sprites, so no rocks are added.
  Plants and props keep clear of each plot's entrance.
- **Night (review 5).** Every `plaza_lamp_single` and `plaza_lamp_double` gets an additive halo on
  each lamp head and a light circle on the ground (the world lamp glow art). Outside Performance mode
  there is also a 2D point light that lifts the night tint. Lamps are lit from 16:00 to 07:00
  (`lights` in data). In Performance mode there is no point light and no flicker. Lit windows come
  later, with the buildings.
- **Fade (round 3).** Walls, towers, gatehouses, water gates, houses and stalls fade only round the
  hero: a soft ellipse about 58 x 74 world px at 0.5 alpha, with no tint
  (`crosshaven_city_fade.gdshader`, a material set only while the row fades). The rest of the
  sprite stays opaque and its modulate stays white. Trees still fade as a whole sprite.
- **Name plates (review 4).** An NPC's name plate hides while a wall, tower, gate, house or stall
  covers the NPC (the fade's own rect and mask test, `occluded()`).
- **Scale.** `plate.scale` is 1.15, one factor for the whole plate. Ratios to the hero: house 3.08,
  horizontal gatehouse 6.40, stall 2.51. West gate to east gate is 144 cells, about 93 s walking or
  47 s running.
- **Plots.** There are 10: P1 rare, P2 legendary, P3 rare, P4-P6 normal, P7 rare, P8 normal, P9 rare,
  P10 legendary. All plot rules apply and are tested.
- **No thatch.** The 2 thatched cottages are swapped to slate (`thatch_swapped`).
- **Art ownership.** All art paths are data (`art`, `art_file`, kit and green folders, `lights`), so
  final art drops in without code changes. After a rebuild, run `godot --headless --import`: layer
  files keep their names when their pixels change.

## What the world does today

- `crosshaven_world.gd` loads a region index (`data/world/crosshaven/index.json`, 33 chunks) through
  `WorldMap` / `WorldZone`. Each chunk is a grid of 64x32 diamonds (`BoardVisualSort.cell_to_local`).
  The world plane (`backend/world_plane.gd`) lays the chunks out from their exit links and mounts the
  neighbours, so the walk is seamless.
- The ground is drawn per cell from the tile kit (`crosshaven_ground.gd`). Props and decor are nodes with
  an absolute `z_index = (x + y) * 10`. The hero (`crosshaven_walker.gd`) sorts by its ground screen y
  (`round(y * 10 / 16) + 4`). A prop fades to 0.45 while the hero is behind it (`update_cover`).
- The atlas (`backend/world_atlas.gd`) is strict: 88 level chunks, gates must cross regions, every
  region is reached from the Crossroads, and the tests pin the 33 chunks.
- Dungeons draw painted backdrops with a fitted affine: `build_tools/dungeons/board_kit.py` writes
  `cell00_centre_px`, and the board view draws the image at `-cell00_centre_px`.

## Choice: a plate-backed zone outside the atlas

The city is one painted plate, not tiles, so it cannot be a normal chunk. It also must not change the
atlas or the plane, because that would move or break the Crossroads world. It is a **separate one-zone map**:

- `data/world/crosshaven_city/city.json` (`stasium.plate_city` v1) holds the plate fit and scale, the cell
  grid as text rows plus heights, the gates, bridges, plots, NPCs, pets, water, wall contacts and gate stubs.
  `layers.json` holds the sprite layers in plate px, each with `sort_y`, a fade flag and a coarse alpha mask.
- `backend/plate_city.gd` reads it and builds an ordinary `WorldZone` and `WorldMap`, so the walker,
  `WorldWalk.find_path`, picking and hover work unchanged. The grid is 114 x 142 cells. The standard zone
  file caps chunks at 128 cells and stores one JSON record per tile; text rows keep the file small.
- `scenes/world/crosshaven/crosshaven_city_plate.gd` draws the city: ground, river shader, y-sorted
  layers, plot houses, pets, and the fades. The world swaps it in for the tile ground when the zone
  is the city (`_load_city_zone`); the rest of the world loop is shared.
- **Placement is data.** The city is reached three ways:
  - the `gate_stubs` in `city.json`: a marked Crossroads cell (16, 27) leads to the city road, and the
    city's south road end leads back;
  - `--start-zone=crosshaven_city`;
  - the dev warp key F8.

  The Crossroads zone file is untouched. If Mauro keeps the Crossroads, move the stub to where the city
  should hang off the map. If the city replaces it, point the atlas entry at this zone later.
  `"enabled": false` turns a stub off.

## Size-agnostic build

`build_tools/crosshaven_city/build_city.py <handoff crosshaven dir> <repo> [--layout file]`.

- The plate size comes from `ground.jpg`.
- The layout file (`layout_rosebud_v9.json`) holds what the Rosebud export does not carry:
  - the wall polygon in plate px;
  - which wall edge gets the north gate;
  - the plot table and the old plot anchors;
  - the plot search box, as fractions of the plate;
  - `plate_scale`;
  - the Crossroads stub cells.
- Everything else is derived from the walkmask, heightmap, layers and zones of the export:
  - the cell lattice;
  - the wall contacts and gates;
  - the tree clusters and plants;
  - the plots.
- The enlarged plate (item 7, about 7680x4320) needs a new export plus its own layout file. No code changes.

## Scale and angle (measured)

| Measure | Plate | Game | Result |
|---|---|---|---|
| Bridge deck axes (3 bridges) | slope 176.7 / 353.6 = 0.4997 | 2:1 | iso x axis |
| Gate passage axis | slope 102.9 / 205.7 = 0.5002 | 2:1 | iso y axis |
| Ground texture lattice (FFT autocorrelation) | (64, 32) step, 128x64 diamonds | 64x32 cells | the painted ground repeats every 2 cells |
| Hero | Rosebud hero about 56 px | world heroes 54.5-62.7 px (Ironjaw 62.7) | 1.0 to 1.12 |

**Fit:** translation only. The plate scale is data (`plate.scale`, from the layout's `plate_scale`) and is 1.0.
The cell lattice is shifted so the three bridge decks and the south gate passage run along rows of cell
centres: `cell00_px` = (2652.5, -437.25). Residual offsets from the deck centre lines are +4.9, -0.5 and
-4.9 px; the open deck corridor is 34 px wide. The gate offset is 0.0 px.

**Item 8, character to building scale.** Measured in the game at scale 1.0 against Ironjaw (62.7 world px).
At the default zoom 1.6 on a 1280x720 logical view stretched to 1080p, Ironjaw is about 150 px on screen,
close to Mauro's 156.

| Target | Sprite | Ratio at 1.0 | Mauro |
|---|---|---|---|
| Normal house | 168-201 px (rare plot house 185) | 2.7-3.2 (2.95) | about 3x |
| Gate tower | gatehouse 308 px | 4.9 | 4-5x |
| Wall tower | 212 px | 3.4 | (4-5x if counted as a gate tower) |
| Market stall | 122-152 px | 1.95 | 1.5-2x |
| Street width | 68 px across, 152 px measured horizontally over a diagonal street | 1.1 / 2.4 | 3-4x |

A least-squares fit over house, gate tower and stall gives a scale of 0.94-1.0, so **1.0** is kept.
A scale change cannot also fix the street width: houses would grow to 9x. Street width is a layout
change for the re-laid plate (item 7). Walking time at this scale is a separate problem: west gate to
east gate is 130 cells and 4615 px, which takes 84 s walking (55.1 px/s) or 42 s running. At 1.5x
that becomes about 126 s and 63 s.

## Walkability

- **Cells from the walkmask.** A cell walks when its centre is white in the walkmask and at least 60% of
  its inner half-size diamond is white. Only the component joined to the south road is kept.
- **Bridges.** The Rosebud walkmask and heightmap store deck and stair pixels at the drawn feet
  (ground y minus z). Cells are ground points, so those pixels are not used. Each bridge is laid on its
  ground line instead: the stair bottoms (z = 0) fix the line, and z along it is the Rosebud
  `centreline_z` by screen x. Heights are 10 px a step, so the crown is step 6. A bridge is entered only
  from its ends.
- **What blocks.** Walls, towers, buildings, bushes and the river block. The gate passages are the only
  way through the wall; a test seals them and checks for leaks.

## Depth and fade

- **Depth.** Every layer is a `Sprite2D` with an absolute `z_index = round(world_sort_y * 10 / 16)`, the
  walker's own formula, so the hero, NPCs, pets and layers share one y-sort. Bridges and the NW steps sit
  just above the ground (Rosebud `under_everything`). The river sits under them.
- **Fade (Luca: every obstacle).** A layer fades when all three hold:
  - it is at least 40 px tall;
  - it draws in front of the hero;
  - its opaque pixels (8 px mask) overlap the hero's body box.

  It ramps to its `fade_min_alpha` over 0.25 s: 0.45 for most layers, 0.40 for the lintel. This includes
  walls, gates and workshops, which the Rosebud export kept opaque.
- **Performance mode.** Half-size ground, instant fades, no pet hops, NPCs at the lite idle rate, and the
  river shader off (the ground keeps the painted still water).

## Mauro's change list

### Items 1-3: gates at every road-wall contact

`city_gates.find_contacts` compares street pixels in `ground.jpg` against the wall line. The wall
footprint is a 26 px band on that line. A street within 140 px of the line is a contact. Before the build:

| Where (plate px) | Wall edge | Verdict | Done |
|---|---|---|---|
| 2134, 2443 | 5 (south) | existing gate | `gate_0`, the handoff south gate, unchanged |
| 438, 1489 | 7 (west) | road crosses the wall | `gate_1` + roads in and out |
| 4570, 1627 | 3 (east) | road crosses the wall | `gate_2` + roads |
| 1171, 1981 | 6 (south-west) | street runs under the wall | `gate_3` + roads |
| 4175, 2019 | 3 (south-east, diagonal) | long road from the south gate ends 51 px from the wall | `gate_4` + road out to the plate edge |
| 4374, 851 | 2 (north-east) | street runs along the wall, 54 px off its line, and turns at a tower (it touched only the tower's stub, now cut) | no gate; it never meets the wall |
| (item 2) | 1 (north) | the northern streets end short of the wall | `gate_5`: the street is extended to it, and a road runs out north-east toward Northgate |

After the build every contact is a gate or `runs_along` (`wall_contacts.after` in `city.json`; tested).

How a gate is built (`city_gates.fit_gate`):

1. **Art.** It reuses the south gate's two sprites (`cw4_gate_open`, the handoff's `gate_back` +
   `gate_front_lintel`) and fits them to the wall slope the way the handoff fits its gates and water gates:
   mirror for a falling wall, then a vertical shear so both wall joins sit on the wall line. The shears
   are 0.72 west, -0.70 east and south-east, -0.07 south-west, and -0.5 north.
2. **Wall runs.** The runs are cut over the gate span.
3. **Walk.** The gatehouse footprint blocks, and a 60 px passage through the arch opens. The passage
   follows the sheared art's axis.
4. **Roads.** A cobble road is painted where there was none, inside to the nearest street and outside to
   the plate edge. The cobble is the plate's own tile, rebuilt as a per-phase median of every street pixel.
   Trees and plants standing on a new road are lifted off.
5. **Depth.** `gate_back` sorts just behind the passage. The lintel sorts at its art's base, so a hero in
   the arch is under it and a hero past it is in front.

The steep shears are stand-ins: on the west and east walls the towers stay vertical, but the crenels tilt.

### Item 4: tower stubs

All 15 towers share one sprite with a wall stub on each side of its base. `clean_tower` cuts everything
outside the cylinder below row 128 and repaints the cylinder rims. The walk footprint shrinks from a
110x48 ellipse to 92x40, with the freed ground inside the wall only. Tested: no tower layer has opaque
blocks outside the cylinder.

### Items 5-6: beautification, bushes and flowers

Beautification is the art side (Meshy and Scenario).

Item 6 is placeholder scatter. `scatter_plants` places 121 loose plants and reuses the plate's own
`tn_bush`, `tn_wildflowers` and `ww_wild_rose`, with no planters or beds:

- on the grass 22-60 px from a street (90);
- in a ring round the fountain and well plazas (30);
- inside the foot of the wall (60).

Flowers can be walked through, and bushes block a small foot ellipse. The planter boxes that moved with
the plots became bushes.

### Item 7: fewer trees, bigger city

`thin_trees` keeps 26 of 95 trees: the park clusters round the fountain and the well, every other tree
at the wall feet, and up to 10 street trees at least 520 px apart. The rest are cut and their footprints
freed. The 1.5x enlargement waits for the re-laid plate; see "Size-agnostic build".

### Item 9: water

`crosshaven_city_water.gdshader` runs on a sprite of `water_base.png` (alpha = river), drawn above the
ground and under the bridges:

- two ripple layers of `water_ripple_tile.png` (256 px) scroll along `flow_dir` (-0.86, 0.51) at 24 px/s;
- the second layer is flipped, runs at 0.7x speed with offset (97, 41) and alpha 0.55;
- ripple alpha is 0.45 + 0.55 x depth, with depth = distance from the bank (data texture `water_fx.png`,
  R = depth, G = foam zone, A = river);
- foam is a value noise x `foam_zone`.

Parameters come from `water.json` via `city.json`. Performance mode hides the overlay.

## Player plots

The 5 plots are placed by a search. The Legendary clearance is an iso ellipse 350 x 175 px with its
bottom on the anchor. It must clear the streets, the wall, tower and gate sprites, the river, the
landmarks and houses, and the other plots. The old houses and their plants are lifted off and their
footprints opened.

The exterior tier follows the README table: P1 rare, P2 legendary, P3 rare, P4 normal, P5 normal.
Change `plots[].tier` to swap it.

There are no garden beds. Each anchor has 2 walkable front cells joined to the street network. All of
this is tested.

## Rebuild

```
git archive origin/docs/pc-map-handoff docs/pc/map_handoff/crosshaven/rosebud docs/pc/map_handoff/crosshaven/housing_tiers | tar -x -C /tmp/cx
git archive origin/docs/pc-map-handoff docs/pc/look_target/crosshaven_city/work | tar -x -C /tmp/cx
git archive origin/claude/pc-zones-spec docs/pc/look_target/crosshaven_city/work/grass.png docs/pc/look_target/crosshaven_city/work/cobble.png | tar -x -C /tmp/cx
W=/tmp/cx/docs/pc/look_target/crosshaven_city/work
python3 build_tools/crosshaven_city/build_city.py /tmp/cx/docs/pc/map_handoff/crosshaven . \
  --textures $W --kit art/world/crosshaven_city/kit --green $W/green
godot --headless --path . --import
```

Tests: `tests/run_crosshaven_city_tests.gd`. Media: `tests/pc/capture_city.gd` (stills; `--clip` for the walk).
