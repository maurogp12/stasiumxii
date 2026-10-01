# Crosshaven world scene (PC, `main`)

Walkable Wakfu-style view of the Crosshaven zone data in `data/world/crosshaven/`
(format: `crosshaven_zone_format.md`). Combat, characters and levels are parked;
this is movement, map scrolling, weather and look only.

## Run it

- Editor: open `res://scenes/world/crosshaven/crosshaven_world.tscn` and press **Run Current Scene** (F6).
- Command line: `godot --path . res://scenes/world/crosshaven/crosshaven_world.tscn`
- Tests: `godot --headless --path . -s res://tests/run_crosshaven_world_tests.gd`

`run/main_scene` is unchanged (still `res://scenes/mobile_hub.tscn`).

## Controls

| Input | Does |
| --- | --- |
| Left click | Walk there (path from `WorldWalk.find_path`) |
| Click a gold-arrow edge tile | Walk off the chunk into the linked one (short fade) |
| Mouse wheel | Zoom 1.0–2.5 |
| `1` | Cycle weather: clear, light cloud, light rain, wind |
| `2` | Toggle day/night speed ×30 |

Hover colours: green walkable, red blocked (water, cliff, prop), gold exit.

## How it's built

| File | Role |
| --- | --- |
| `crosshaven_world.gd` | Loads `WorldMap`, input, camera, chunk swaps, HUD |
| `crosshaven_ground.gd` | Terrain, height faces and exit arrows; one canvas item per diagonal |
| `crosshaven_prop.gd` | Trees, fences, cottages, spires, centerpiece; fades when the player is behind |
| `crosshaven_walker.gd` | Player avatar (placeholder Kestrel sprite), step animation |
| `crosshaven_weather.gd` | Day/night tint (12 real minutes per day) and weather looks |
| `crosshaven_pick.gd` | Screen to cell picking, cell geometry |

Draw order: ground rows at `(x+y)*10`, props at `(x+y of south cell)*10 + 2`,
player at `(x+y)*10 + 4`. Height lifts 10 px per step (`BoardVisualSort`).

The client never decides walkability itself. Every walk comes from
`WorldWalk.find_path`, and exits are checked with `WorldWalk.validate_path`
before the chunk swaps.

Weather is client-visual only (zone `presentation` is Proposed). It does not
touch movement or anything the server checks.

## Art drop-in

Painted placeholders draw until a file exists:

- Tiles: `res://art/world/crosshaven/tiles/<terrain>.png` (`golden_plains`, `dirt_road`, `water`, `cliff`).
  64 px wide; the image bottom sits on the diamond's south tip (like `board/tile.gd`).
- Props: `res://art/world/crosshaven/props/<type>.png` (`tree`, `fence`, `red_roof_cottage`,
  `crossroads_centerpiece`, `<town>_spire`). Bottom-centre sits on the footprint's south tip
  (for 2×2 props, the south corner of origin+(1,1)).

## Known limits / Open

- One chunk at a time with a fade at exits. The chunks can't be stitched into
  one seamless world yet: placing them by exit-link offsets overlaps 776 cells
  (`road_west` and `road_southwest` both hang off the crossroads' west edge).
  Seamless scrolling needs non-overlapping global offsets in the data.
- Open in the data: climb limit (no limit now), ortho vs 8-direction walking
  (ortho now), bridge/ford art, weather authority.
- No PC export preset yet (`export_presets.cfg` only has Android).
