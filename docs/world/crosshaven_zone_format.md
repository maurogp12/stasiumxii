# Crosshaven zone format

Format `stasium.zone` version **1**. The Godot scene and the server both read these JSON files. The fight arena `art/maps/arena_colosseum_v2/tiled/crosshaven_15x15_tags.json` is a separate 15×15 Koliseo board and is not part of this set.

Items marked **Proposed** are layout or presentation choices in this data. Items marked **Open** are undecided. The server does not invent a rule for an Open item.

## Files

| Path | Role |
| --- | --- |
| `data/world/crosshaven/schema/zone.schema.json` | JSON Schema (draft 2020-12) for one chunk |
| `data/world/crosshaven/schema/index.schema.json` | JSON Schema for the region index |
| `data/world/crosshaven/index.json` | Chunk list, player start, climb config |
| `data/world/crosshaven/zones/*.json` | One chunk per file |
| `data/world/crosshaven/build_crosshaven_zones.py` | Regenerates the chunk files |
| `backend/world_zone.gd` | Parses one chunk and checks the format |
| `backend/world_map.gd` | Loads the index and checks exits |
| `backend/world_walk.gd` | Authoritative step check and click-to-walk search |

Regenerate from the repo root:

```bash
python3 data/world/crosshaven/build_crosshaven_zones.py
```

The script checks connectivity before it writes. With the `jsonschema` package installed it also validates every file against the schema.

## Coordinates and grid

Each chunk has its own origin. `x` increases east. `y` increases south. That matches the board: `+x` is screen east, `+y` is screen south (`board/visual_sort.gd`).

Tiles are isometric **64×32** px (`board/tile.gd`). `height` is an integer number of height **steps**. One step lifts the diamond by **10** px (`BoardVisualSort.ELEVATION_PIXELS`). The JSON stores steps, so a client converts with `height * 10`.

Tiles are stored row-major, `y` then `x`, one object per cell. `tiles.length` is `width * height`.

A cell is passable when `walkable` is true and no blocking prop covers it. `walkable` is stored on the cell and must match the tile id:

| Tile id | Sprite name | Walkable | Footprint |
| --- | --- | --- | --- |
| `golden_plains` | `golden_plains` | yes | 1×1 cell |
| `dirt_road` | `dirt_road` | yes | 1×1 cell |
| `water` | `water` | no | 1×1 cell |
| `cliff` | `cliff` | no | 1×1 cell |

`water` is coast, river, and the Stone Ford stream. `cliff` is the Windmere-facing rim at Northgate and the Slagcrown-facing rim at Westwatch and Southbridge. Both are tile sprites. They are blocking ground, so they are not props.

## Prop ids

`props[].type` is the sprite name. `props[].id` is the placed instance and is unique inside the chunk. Every prop in v1 has `blocks: true`. The footprint is the list of cells the prop occupies. Offsets are from `origin` (the northwest cell). `+x` is east and `+y` is south.

| Prop id | Sprite name | Footprint | Offsets from origin | Where it is placed |
| --- | --- | --- | --- | --- |
| `tree` | `tree` | 1×1 | `(0,0)` | Plains, off the roads |
| `fence` | `fence` | 1×1 | `(0,0)` | Short runs beside cottages and fields. A longer fence is several props. |
| `red_roof_cottage` | `red_roof_cottage` | 2×2 | `(0,0) (1,0) (0,1) (1,1)` | The five towns |
| `northgate_spire` | `northgate_spire` | 2×2 | `(0,0) (1,0) (0,1) (1,1)` | Northgate, once |
| `stoneford_spire` | `stoneford_spire` | 2×2 | `(0,0) (1,0) (0,1) (1,1)` | Stoneford, once |
| `eastmarch_spire` | `eastmarch_spire` | 2×2 | `(0,0) (1,0) (0,1) (1,1)` | Eastmarch, once |
| `westwatch_spire` | `westwatch_spire` | 2×2 | `(0,0) (1,0) (0,1) (1,1)` | Westwatch, once |
| `southbridge_spire` | `southbridge_spire` | 2×2 | `(0,0) (1,0) (0,1) (1,1)` | Southbridge, once |
| `crossroads_centerpiece` | `crossroads_centerpiece` | 2×2 | `(0,0) (1,0) (0,1) (1,1)` | Crossroads, once, on the road crossing |

**Proposed:** these footprint sizes. The artist names each sprite with the id. Pixels may overhang the footprint. Gameplay uses only the cells listed. A useful visual pivot is the south tip of the footprint, the same idea as Koliseo props in `board/tile.gd`.

The same catalogs live in `zone.schema.json` (`$defs.tileCatalog`, `$defs.propCatalog`, and the `enum`s) and in `WorldZone.TILE_ORDER` / `WorldZone.PROP_FOOTPRINTS`. The zone test fails if they drift.

## Chunk fields

```json
{
  "format": "stasium.zone",
  "format_version": 1,
  "zone_id": "crosshaven_northgate",
  "region": "crosshaven",
  "width": 40,
  "height": 32,
  "spawn": {"x": 16, "y": 11},
  "points_of_interest": [
    {"id": "northgate_center", "name": "Northgate", "kind": "town", "x": 16, "y": 11}
  ],
  "exits": [],
  "props": [],
  "tiles": [],
  "presentation": {
    "status": "proposed",
    "authority": "client_visual",
    "default_weather": ["clear", "light_cloud", "wind"],
    "day_night": true
  }
}
```

`spawn` and every point of interest must be passable. `kind` is `town`, `crossroads`, or `landmark`.

An exit lists the edge tiles that leave the chunk and the arrival tile in the next chunk:

```json
{
  "id": "to_crosshaven_road_north",
  "edge": "north",
  "target_zone": "crosshaven_road_north",
  "links": [{"from": {"x": 20, "y": 0}, "to": {"x": 12, "y": 31}}]
}
```

`edge` is `north`, `south`, `east`, or `west`. `from` sits on that edge, so one ortho step outward leaves the chunk. The player then stands on `to`. Each link has a reverse link on the opposite edge. Road mouths are five tiles wide.

`presentation` is optional. When present, `status` is `proposed` and `authority` is `client_visual`. The walk code ignores it.

## Movement

v1 adjacency is **ortho**: the four steps `(1,0)`, `(-1,0)`, `(0,1)`, `(0,-1)`. That is the same 4-neighbor rule as `WalkBoard.ORTHO`. A diagonal step is `not_adjacent`.

A zone change is legal only when the current tile has an exit link whose `to` is the next step. The server checks bounds, ortho adjacency, `walkable`, prop blocking, the exit link, and the climb limit.

## Climb limit (Open)

`index.json` field `max_climb_steps` is the config. The code default is `WorldWalk.OPEN_WORLD_MAX_CLIMB_STEPS`.

| Value | Meaning |
| --- | --- |
| `-1` | No climb limit. This is the shipped value. |
| `0` or more | Maximum upward height-step change on one ortho step. |

Any negative value means no limit. Downhill steps are allowed at every setting. There is no drop limit. Koliseo combat still uses its own climb 1 / drop 2 rule in `backend/elevation_cost.gd`. Open-world walks do not read that file.

## Chunks

**Proposed** sizes. Towns are about 36×32 to 40×32. Roads are narrower so they can stream as the player walks. The whole region is 11,840 cells.

| zone_id | Size | Cells | What it is |
| --- | --- | --- | --- |
| `crosshaven_crossroads` | 40×36 | 1440 | Central roads. Player start `(22, 18)`, east of the centerpiece. |
| `crosshaven_road_north` | 24×32 | 768 | Road from the crossroads to Northgate. |
| `crosshaven_northgate` | 40×32 | 1280 | Northern town. North rows are cliffs toward Windmere. |
| `crosshaven_road_west` | 36×24 | 864 | Road toward Stoneford, with the Stone Ford stream. |
| `crosshaven_stoneford` | 36×32 | 1152 | Western town. West columns are coast toward Rowanvale. |
| `crosshaven_road_east` | 36×24 | 864 | Road toward Eastmarch. |
| `crosshaven_eastmarch` | 36×32 | 1152 | Eastern town. East columns are coast toward Brinewake. |
| `crosshaven_road_southwest` | 32×32 | 1024 | Road from the crossroads' southwest edge to Westwatch. |
| `crosshaven_westwatch` | 36×32 | 1152 | Southwestern town. West coast, south cliffs. |
| `crosshaven_road_south` | 24×36 | 864 | Road toward Southbridge. A river crosses it; the road tiles are the bridge. |
| `crosshaven_southbridge` | 40×32 | 1280 | Southern town. South rows are cliffs toward Slagcrown. A pond sits inland. |

```
                 Windmere
          =====================  cliffs, no exit
          |     Northgate     |
          |      40 x 32      |
          +---------+---------+
                    | road_north 24 x 32
                    |
  Rowanvale   +-----+------+          Brinewake
  ~~~~~~~     |            |          ~~~~~~~~~
  Stoneford --+ Crossroads +-- Eastmarch
  36 x 32     |  40 x 36   |   36 x 32
  coast west  |     |      |   coast east
              +--+--+--+---+
                 |     |
     road_sw     |     | road_south 24 x 36
     32 x 32     |     | river bridge
        |        |     |
    Westwatch    |  Southbridge
    36 x 32      |   40 x 32
    coast/cliffs |   cliffs south
                 |
              Slagcrown
```

Roads in the chunks:

- Crossroads: north–south through `x = 20`, east–west through `y = 18`, southwest spur through `y = 28`.
- The centerpiece occupies `(19,17)`, `(20,17)`, `(19,18)`, `(20,18)`. The road around it stays passable. Spawn and the Crossroads point of interest are `(22, 18)`.
- Stoneford's stream is column `x = 8`, forded by the dirt road at `y = 14..18`.
- The south road's river is row `y = 22`, bridged by the dirt road at `x = 10..14`. The point of interest there is Southbridge Crossing.

**Proposed:** the bridge and the ford are `dirt_road` cells interrupting `water`. There is no separate bridge tile id. **Proposed:** the player origin is the crossroads spawn. The spawn on every other chunk is that chunk's stand (town center or road landmark) for when the chunk is loaded on its own. **Proposed:** road point-of-interest names (North Road, Stone Ford, East Road, Westwatch Road, Southbridge Crossing). **Proposed:** walkable neighbors in this data differ by at most one height step, so a later climb limit of 1 would keep the region connected. The server does not enforce that slope. It only applies `max_climb_steps`.

Neighbor regions have no exits. Northgate's north cliffs face Windmere. Stoneford's west water faces Rowanvale. Eastmarch's east water faces Brinewake. Southbridge's south cliffs face Slagcrown. Westwatch meets the southwest coast.

## How Godot should read it

Load the index, then ask a chunk for terrain, height, and props. Depth sorting stays on `BoardVisualSort`. This repo does not ship the Crosshaven scene.

```gdscript
var loaded := WorldMap.load_default()
if not loaded["ok"]:
    push_error(str(loaded["errors"]))
var map: WorldMap = loaded["map"]
var zone := map.zone("crosshaven_northgate")
var cell := Vector2i(20, 16)
var terrain := zone.terrain_at(cell)          # sprite id
var lift := zone.height_at(cell) * 10.0       # BoardVisualSort.ELEVATION_PIXELS
for prop in zone.props:
    var sprite := str(prop["type"])           # sprite id
    var origin: Dictionary = prop["origin"]
```

`zone.presentation` is the optional weather hook. Use `default_weather` as a client-side set. Do not send it to the walk authority.

A click-to-walk search:

```gdscript
var result := WorldWalk.find_path(map, from_zone, from_cell, to_zone, to_cell)
if result["ok"]:
    var path: Array = result["path"]  # [{zone_id, x, y}, ...], start included
```

`result["length"]` is the number of steps. It is a tile count, not combat MP.

The server can check a client polyline with `WorldWalk.validate_path(map, steps)`. Reasons include `empty_path`, `unknown_zone`, `out_of_bounds`, `not_adjacent`, `not_walkable`, `blocked`, `bad_exit`, `climb_too_steep`, `same_tile`, and `unreachable`. Pass an integer as the third argument to try a climb limit. Omit it to use the index value.

```bash
godot --headless --path . -s res://tests/run_crosshaven_zone_tests.gd
```

## Open

- **Climb limit.** `max_climb_steps` / `WorldWalk.OPEN_WORLD_MAX_CLIMB_STEPS` is `-1` (no limit). Design has not chosen a limit. Drops are unlimited too.
- **Diagonal movement.** v1 accepts the four ortho neighbors. Eight-direction movement is not implemented.
- **Weather and day/night.** `presentation` is client-visual data. There is no server weather simulation.
- **Other regions.** Windmere, Rowanvale, Brinewake, and Slagcrown have no zone files and no exits.
- **Bridge and ford art.** The crossing is `dirt_road` through `water` until design asks for another tile id.
- **Sprite overhang and pivot.** Footprints are the blocking cells. How the sprite sits on those cells is up to the scene.

## Proposed

- Chunk sizes and the road-mouth width of five tiles.
- Prop footprints in the table above.
- Player start at crossroads `(22, 18)`. Other `spawn` values are per-chunk stands.
- Road landmark names.
- The weather strings on each chunk (`clear`, `light_cloud`, `light_rain`, `wind`).
- Keeping walkable height changes to one step in this data, without making that a server rule.

## v6 on the integration branch

Farm terrains (`farm_cabbage`, `farm_carrot`, `farm_fallow`, `farm_lavender`, `farm_plowed`, `farm_pumpkin`, `farm_soil`, `farm_sunflower`) are walkable ground, same as plains. The prop catalog grew with the v6 buildings and town props. Every catalog prop still has `blocks: true` in the schema. An **instance** may set `blocks` to `false`, and then its footprint does not block. `decor` is an optional array of `{id, type, x, y}` sprites that never block and never change pathing.

`build_crosshaven_zones.py` rewrites the chunks from scratch. Run `build_crosshaven_dressing.py` after it to put the crops, extra blockers, and decor back. A blocker is written only when every other passable cell stays reachable from that chunk's spawn.

## Town density

`build_crosshaven_density.py` is a third pass on the five towns and the crossroads. It does not add prop ids or tile ids. It rewrites those six zone files in place: a `dirt_road` plaza, cottages around it, door lanes, and street props from the existing catalog. Interior `dirt_road` within seven cells of a point of interest draws as flagstone (`pick_tile` in `scenes/world/crosshaven/crosshaven_art.gd`). Benches are not in the prop catalog, so the squares use stalls, wells, barrels, crates, carts, lamps, and signposts.

Regenerating chunks wipes this pass. Run the zone builder, then dressing, then density. The crossroads spawn stays `(22, 18)`. The other town spawns move onto the open square. Through-roads and exit mouths stay free of new blockers.
