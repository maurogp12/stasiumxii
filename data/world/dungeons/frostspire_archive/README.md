# Frostspire Archive: game data and design choices

Northgate's dungeon, levels 10–20. Art: `art/pc/dungeons/frostspire_archive/` (manifest + README, branch
`claude/frostspire-art`). Code: the same files as the Old Granary Cellar (`backend/world_dungeons.gd`,
`pc_dungeon_run.gd`, `pc_monsters.gd`, `dungeon_ai.gd`, the dungeon section of `combat_sim.gd`, `scenes/world/dungeon/`).
Everything that differs from the cellar is data: this folder, `data/world/dungeon_monsters.json` and `data/world/dungeons.json`.

## Door
- Archive door at `crosshaven_northgate` (21, 10). The archive tower stands on (19–21, 7–9): the manifest footprint is
  3x3 with the door at footprint (2, 3), in front of the frosted steps (the cellar's is (1, 3)). It blocks walking.
- Door Keeper (`northgate_door_keeper`) at (20, 10), footprint (1, 3). The door or the keeper opens the entry panel.
- `world_dungeons.validate_world` reads each door's footprint from its art manifest (`town_door.footprint_size`,
  `door_cell_from_nw`), so a dungeon's building sits where its art says.

## Rooms (`run.json`, tags built by `build_rooms.py`)
- 12x12 boards. Props are the art kit's (`frozen_bookshelf`, `book_pile`, `reading_desk`, `ice_crystals`,
  `frozen_chest`, `frost_brazier`). The room B shell already paints the ice throne on its dais behind the back wall,
  so the kit's `ice_throne` prop is not stood on the board.
- `build_rooms.py` checks the rules before it writes: every walkable cell reachable from the hero start, the
  spawns of every star on open floor off the pads, room A spawns on the far rows (y 0–4, 6+ cells from the hero), and
  bodies on every spawn still leave every route open. In room A, short shelf runs on the middle rows cut some Book
  Wraith lines onto the hero (tests check that some lines are cut and none are sealed).
- **Pads** (`run.json` `pads`): rune pads in room A, the 3x3 rune circle in room B. A turn that starts on one heals
  the hero 5 HP and **thaws** it (that turn keeps its full MP, see chill). Monsters get nothing.
- **Room A packs** (Mauro: at least 6, with ranged monsters):

| Stars | Ice Constructs | Book Wraiths | Total |
|---|---|---|---|
| ★1–★2 | 2 | 4 | 6 |
| ★3–★4 | 3 | 4 | 7 |
| ★5 | 2 frozen + 1 | 4 frozen + 1 | 8 |

- **Room B:** the Pale Archivist with an escort of 2 Book Wraiths and 1 Ice Construct in front of the throne (★5: the
  Frozen Archivist, 2 Frozen Book Wraiths, 1 Frozen Ice Construct). The room is won when every monster is down; his
  called wraiths scatter when he falls, the escort fights on. Full heal on the stair between rooms.

## Monsters (`data/world/dungeon_monsters.json`, Proposed)
Base stats at level 10 (+5% HP, +3% damage per level). The hero side is the level sheet (`level_rewards.json`
`sheet`: 80 HP, 6 AP, 3 MP); class HP per level is Open and 2 points a level add only a few %, so a level 12 hero is
close to a level 2 one. The band's numbers therefore sit near the cellar's, and the step up comes from the ranged
pack, the boss's range and the ★5 mechanics.

| Monster | HP (L10 / L12) | AP | MP | Attack |
|---|---|---|---|---|
| Ice Construct | 28 / 31 | 5 | 2 | Frost Slam 6, range 1 (slow melee tank) |
| Book Wraith | 9 / 10 | 4 | 3 | Frost Bolt 3, range 2–5, line of sight, kites |
| The Pale Archivist | 82 / 90 | 6 | 2 | Ledger Strike 10 (11 at L12), range 1–2; Unbound Pages |
| Frozen Ice Construct (★5) | 28 / 31 | 5 | 2 | Rime Slam 6 + chill 1 |
| Frozen Book Wraith (★5) | 9 / 10 | 4 | 3 | Rime Bolt 3 + chill 1, range 2–5, line of sight |
| The Frozen Archivist (★5) | 82 / 90 | 6 | 2 | Frozen Ledger 10; Unbound Frozen Pages; Rime Patches |

- **Book Wraith:** the cellar's Sling Rat rule. It shoots when it has a line (the straight line may not cross a prop
  cell; bodies do not block); next to the hero it steps back to range 2+ first; otherwise it walks to the nearest cell
  in range with a line. The bolt (`frost_bolt`, turned to its flight) leaves on the release frame (attack f07) at the
  manifest release point and bursts in `frost_bolt_impact`.
- **Signature, Unbound Pages** (agreed with the art agent; the boss's 14-frame `summon`: tome raised f03–f09, pages
  burst out and the wraiths spawn on f09, arms lower f10–f13): 2 Book Wraiths on his 2nd turn and every 3rd turn
  after. **One cap** counts every live Book Wraith, escort and called together: 3 alive, 4 called in all. With both
  escort wraiths up, a call brings 1.
- **★5, the Frozen Archivist** (rule text in `run.json` `text.star5_rule` and `dungeon_monsters.json`
  `stars.by_dungeon.frostspire_archive.star5`):
  - Unbound Frozen Pages calls Frozen Book Wraiths on the same rhythm with a bigger cap (**4** alive, **6** in all).
  - **Rime Patches** (`signature2`, kind `hazard`, hazard `frost_patch`): every other turn from his 1st he freezes 2–3
    cells around the hero (the hero's cell first) for 3 hero turns. A hero who **ends** a turn on a patch takes 5 frost
    (4 after the ★5 row) and starts the next turn with **2 MP less**. Walking across is safe. The cells show the
    `frost_patch` decal with their turns left; the hero bot never ends a turn on one when it can step off.
  - **Chill:** frozen monsters' hits take 1 MP off the hero's next turn (no stacking).
  - A turn that starts on a rune pad thaws: no MP lost.

## Stars and rewards
- ★1–★5 per run on the entry panel, no unlock gate, best star kept (`pc_progress.dungeon_stars`), as the cellar.
- The archive has its own solo rows (`stars.by_dungeon.frostspire_archive.scale`; the cellar keeps the top-level
  rows): ★1 [1.0, 1.0], ★2 [1.05, 1.0], ★3 [1.05, 1.0] (+1 Ice Construct), ★4 [1.1, 1.0], ★5 [0.875, 0.85]. ★5's
  difficulty comes from the frozen pack, chill, the stronger call and the frost patches, not from bigger numbers.
- **Rewards** (`pc_rewards` dungeon row `frostspire_archive`: the tier-15 **Pale Archivist** set, coin level 15,
  extras Frost Tonic, Rime Ink, Frozen Bookshelf):
  - XP: 27% of xp_to_next(run level) × pace(hero level) **× star**: 1,359 at level 12 ★1.
  - Coins: the archive's coin roll × star.
  - Loot: Normal Pale Archivist parts from ★1, **Rare** parts only from ★3, ★5 guarantees a Rare part and a
    **Mystery Box** (PC has no Legendary tier in a 10–20 band; epics and relics start at level 40).
  - Any star credits `northgate_dungeon` (clear_dungeon).

### Sim results (`tests/sim_dungeon_stars.gd frostspire_archive 8 12`: solo hero bot, level 12, 8 runs per class per star)
| Star | Scale [HP, dmg] | Win | Kestrel | Ironjaw | Mender | Gloam | Bastion | Lost in A / B |
|---|---|---|---|---|---|---|---|---|
| ★1 | [1.0, 1.0] | 78% | 4/8 | 6/8 | 8/8 | 6/8 | 7/8 | 0 / 9 |
| ★2 | [1.05, 1.0] | 62% | 4/8 | 4/8 | 8/8 | 2/8 | 7/8 | 1 / 14 |
| ★3 | [1.05, 1.0] + 1 Construct | 58% | 5/8 | 0/8 | 8/8 | 3/8 | 7/8 | 12 / 5 |
| ★4 | [1.1, 1.0] | 48% | 3/8 | 1/8 | 7/8 | 1/8 | 7/8 | 12 / 9 |
| ★5 | [0.875, 0.85] + frozen pack, boss, patches | 35% | 4/8 | 0/8 | 8/8 | 0/8 | 2/8 | 16 / 10 |

Tuning notes: the first numbers (Construct 30 HP / 7, Wraith 10 / 4, Archivist 88 / 10, cap 4 alive) gave ★1 25%
with 23 of 30 losses in room B, so the boss, the wraith and the live cap were cut; Archivist 76 / 9 gave ★1 90%, so
he went back up to 82 / 10. The ★5 row is sensitive to rounding (a 3-damage bolt drops to 2 below ×0.84): [0.9, 0.9]
gave 28%, [0.9, 0.85] 32%, [0.85, 0.85] 52%, [0.875, 0.85] 35%. As in the cellar, the bot plays Gloam and Ironjaw
poorly against ranged kiters and Mender slowly but surely; real players do better.
