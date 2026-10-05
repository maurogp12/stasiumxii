# Crosshaven dungeons: design and build plan

*Read this before working on dungeons, dungeon doors or monsters.*

**Status (5 Oct 2026)**
- **Old Granary Cellar:** design approved by Mauro ("Wow love it").
- **The other four:** designs sent to Mauro and waiting for his approval.
- **Build:** not started.
- **Rule:** Mauro confirms every step from pictures before it is built ("send me images of how you design and wait for confirmation").

**Sources**
- **Design images:** painted in Scenario (team "Maurogarza06's Organization", project "stasium") with a game screenshot as the style reference. Asset ids are listed in each dungeon's README or below.
- **Spec:** `docs/pc/ZONES_BUILD_SPEC.md` §4.6 (dungeons.json) and §1 (town order and levels). Look rule B (Wakfu dungeon, glowing floor per theme) is in `docs/pc/LOOK_TARGET.md`.

## The five town dungeons

| Town | Levels | Dungeon | Monsters | Boss | Floor glow | Design |
|---|---|---|---|---|---|---|
| Stoneford | 1–10 | Old Granary Cellar | Granary Rat, Scarecrow Drudge | The Ratking | amber wheat pads | **Approved** |
| Northgate | 10–20 | Frostspire Archive | Ice Construct, Book Wraith | The Pale Archivist | ice-blue rune pads | Waiting |
| Eastmarch | 20–30 | Saltmaw Grotto | Reef Crab, Drowned Sailor | Old Saltmaw | teal coral pads | Waiting |
| Southbridge | 30–40 (danger) | Drowned Abbey | Bog Dead, Mire Leech | The Mire Abbess | green candle-rune pads | Waiting |
| Westwatch | 40–50 (danger) | Heart of the Blight | Blight Hound, Blight Horror | The Rotting Elder | violet pulse pads | Waiting |

Each dungeon folder holds four images:
- `1_door_keeper.jpg`: the entrance in town, with the Door Keeper next to it.
- `2_room.jpg` (`2_cellar_room.jpg` in the Granary folder): room A, the pack fight.
- `3_boss_room.jpg`: room B, the boss fight.
- `4_monsters.jpg`: the monster sheet.

**Scenario asset ids (not yet approved)**

| Dungeon | Entrance | Room | Boss | Monsters |
|---|---|---|---|---|
| Frostspire | `asset_GLwpNouG2xFCuZVy6yq6HQkE` | `asset_MS9xcNUb5ptmey33cQxjGkVJ` | `asset_harbtJDyQXeHW6jJtVRPkHEJ` | `asset_2jFCfHX4asMQhqVv5cfjkjYo` |
| Saltmaw | `asset_dyNRMqWJrGuLGYhk1WaXLeZz` | `asset_J1BK4mxv6goNHE5WUyS2TzMq` | `asset_DYsbbY4vsBWh9Sf2KjDqS144` | `asset_1hYRQsqtN5JyDU4xaLgjm7LS` |
| Drowned Abbey | `asset_3bnqDTvUKjdMRFh1EFhQhwoJ` | `asset_tSezcNcX2vqpHMhgJhENAfnD` | `asset_2vYkm5hjXTc9UXnwSL2yaNoq` | `asset_vwinBLmpLNkAZJDrc337NBeZ` |
| Heart of the Blight | `asset_ytHpKyCFtkbWLjYTTTFnvNp7` | `asset_wvnYdeFQRkAeZp5inWRAKBbM` | `asset_FGV7azjoJmUgPmYuYkRg5b9i` | `asset_mqo1jKKPekD2Dh5EaL1sLKBd` |

**Style references uploaded to Scenario**
- `asset_TQPWy66Pbfv9iRpz7w8NYud3`: Eastmarch world still.
- `asset_KAamhEK1FDAcir7fULWgNYyh`: Northgate snow still.

The approved Granary images are the reference for consistency across the other four.

## How the designs go into the game

The paintings are look targets. The game needs the floor, walls, props and characters as **separate pieces** so the grid, depth sorting and clicks work. Every piece is repainted in Scenario to match the approved image.

### 1. Door in town
- **Building:** the entrance is one painted building sprite in the town kit style: transparent, with 1x and 2x masters under `art/world/crosshaven/`. It sits on a fixed cell in that town's chunk.
- **Hatch or door:** a clickable cell that glows on hover.
- **Door Keeper:** the existing painted `door_keeper` NPC role, standing beside the entrance.
- **Data:** `data/world/dungeons.json` (spec §4.6), one entry per dungeon:
  - `door.zone_id` / `x` / `y`
  - `door_art`
  - `theme`
  - `boss`
  - `rooms: 2`
  - `party 1–4`
  - `level_min` / `level_max`

  The door cell must be passable and inside the town chunk, and must not be an NPC or gate cell.
- **Entering:** clicking the door or talking to the Door Keeper opens a panel showing the name, level band, party size (1–4) and an **Enter** button. The level check is shown there.

### 2. Rooms are combat boards
- **Combat system:** dungeon fights use the existing turn-based combat (`CombatSim`, `board_view.gd`, the 64x32 iso grid): the same moves, spells and turns as the Koliseo. Each room is a new map for that system, in the same tags JSON format as the Koliseo maps, giving terrain and blocked cells.
- **Pieces painted for each theme:**
  - floor tiles (tileable);
  - props that block tiles (crates, sacks, barrels, statues, roots);
  - glowing pads as special tiles;
  - a painted backdrop (walls and lit edges on a dark surround) behind and around the board.

  These follow look rule B. The backdrop is the L2 backdrop layer and the floor is the L4 floor kit (`LOOK_TARGET.md`).
- **Room A:** a pack fight against 2–4 monsters.
- **Room B:** the boss fight.

### 3. Monsters
- **Art:** each monster gets painted animations from its approved design:
  - idle, walk, attack, hit and death;
  - S and E facings, with W and N mirrored;
  - built with the same painted-part pipeline as the five heroes (`docs/pc/art_help/class_walk_looks/*/`).
- **AI:** simple combat logic in `CombatSim`: move toward the nearest hero, then attack. Each boss gets one signature move, for example the Ratking summons rats.
- **Stats:** fitted to the dungeon's level band (`data/world/balance_inputs.json`, `pc_balance`).

### 4. A full run
1. Enter at the door.
2. Win room A.
3. Win room B (the boss).
4. Collect the rewards: coins and items through the existing `pc_rewards`.
5. Return to the town at the door cell.

NPC missions of type `clear_dungeon` count the win.

## Build order (each step: pictures to Mauro, then wait for his OK)

1. **Stoneford door:** the granary entrance plus the Door Keeper in the game. Send in-game stills.
2. **Room A board:** the Old Granary Cellar room A as a real combat board. Send a still.
3. **Granary monsters:** the 3 monsters animated on that board. Send a clip.
4. **Playable run:** room A, then room B, then rewards, then back to town. Send a clip, then merge into `pc/world-zones` and make a new Windows build.
5. **The other four dungeons:** repeat steps 1–4 for each, in town order (Northgate, Eastmarch, Southbridge, Westwatch), once their designs are approved.

**Rules (as everywhere)**
- PC only.
- Never touch `main` or `mobile`.
- All 35 PC suites pass before any merge.
- Log every decision in `docs/pc/CHANGE_LOG_PC.md`.
