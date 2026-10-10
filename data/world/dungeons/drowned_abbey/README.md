# Drowned Abbey: game data and design choices

Southbridge's dungeon, levels 30–40 (Southbridge is a danger zone: the swamp under the bridge). Art:
`art/pc/dungeons/drowned_abbey/` (manifest + README, branch `claude/abbey-art`). Code: the same files as the other
three dungeons (`backend/world_dungeons.gd`, `pc_dungeon_run.gd`, `pc_monsters.gd`, `dungeon_ai.gd`, the dungeon
section of `combat_sim.gd`, `scenes/world/dungeon/`). Everything that differs is data: this folder,
`data/world/dungeon_monsters.json` and `data/world/dungeons.json`. Two new data-driven kinds were added for it (see
**New kinds**). The Old Granary Cellar, the Frostspire Archive and the Saltmaw Grotto play exactly as before.

## Door
- **Abbey door:** at `crosshaven_southbridge` (24, 26), on the south grass spit, with the swamp water on row 27 just
  south of it.
  - The drowned chapel stands on (23–25, 23–25). The manifest footprint is 3x3, with the door at footprint (1, 3).
  - The chapel blocks walking. The door stays passable and can be walked to from the chunk spawn.
- **Door Keeper** (`drowned_abbey_door_keeper`): moved from (12, 21) to (23, 26), beside the door on the west.
  - The door or the keeper opens the entry panel.
  - His line warns of the rite: "The Mire Abbess raises what you fell. Put her down first, or stand where they dropped."

## New kinds
- **Signature kind `raise`** (`signature.kind`)
  - Keys:
    - `raise`: the monster ids it may raise;
    - `hp_pct`;
    - `cap_total`;
    - `first_turn`;
    - `every`;
    - `ap`;
    - optional: `max_range`, `beam`, `raise_text`, `scatter_text`.
  - **What it does:** from the boss's `first_turn`-th turn, she raises one corpse of a `raise` kind, back on the cell
    where it fell, at `hp_pct` of its HP.
  - **When a corpse can rise:** it must lie on a free walkable cell, not be raised already, and not be a risen one
    itself. The nearest corpse to her goes first.
  - **Rhythm:** `every` is a cooldown here (turns between rites), not a fixed beat, because the rite needs a body.
  - **The risen one:** a new body, flagged `risen`. It takes its turn after the others and sinks back when she falls
    (the summon scatter, with the data's `scatter_text`).
  - **What stops it:**
    - a hero standing on the corpse keeps it down;
    - a risen one struck down stays down;
    - `cap_total` limits the risings per fight.
  - **Events and view:** CombatSim logs a `raise` event (cell, corpse seat, risen seat, glow). The room view plays her
    14-frame `summon` strip, draws the `rite_glow` from her censer (manifest `rite_point`) to the corpse on the flare
    frame, and plays the risen body's death strip backwards (lying down to standing).
  - **Validation:** `pc_monsters` checks the keys, the ids, `hp_pct` in (0, 1], and that the kind is known.
- **Root hazards** (`signature2` kind `hazard` with `root: true`)
  - A hero who ends a turn on the cell takes its damage and gets no MP on the next turn (the drain is the hero's full
    MP).
  - `word` and `drain_text` give the coach lines ("The mire holds {name}: no MP this turn.").
  - A pad that thaws (`pads.thaw`) cleanses it like any MP drain.
  - Frost patches and the riptide keep their records and lines.
- **View: walkable 1x1 floor decals.** A walkable cell that names a kit decal that is not the pad decal draws it
  under the units. This is how the kit's `lily_pads` are drawn.
- **Pad mark `candle`:** the placeholder for the candle pad.

## Rooms (`run.json`, tags built by `build_rooms.py`)
- **Boards and props:** 12x12 boards. The props are the art kit's.
  - Room A: `pew`, `broken_pillar`, `fallen_statue`, `candle_cluster`, `coffin`, `gravestone`, `gnarled_roots`.
  - Room B: `altar`, `fallen_bell` (2x2: anchor on its south cell, `fallen_bell:part` on the other three),
    `candle_stand`, `floating_coffin`, `coffin`, `saint_statue`, `gnarled_roots`.
  - Lily pads are walkable floor decor.
- **`build_rooms.py` checks the rules before it writes:**
  - every prop is a kit prop (it reads the manifest's prop list and footprints when they are there);
  - every walkable cell is reachable from the hero start;
  - the spawns of every star are on open floor, off the pads;
  - room A spawns are on the far rows (y 0–4, 6+ cells from the hero);
  - bodies on every spawn still leave every route open;
  - the props cut some lines from the Mire Leeches' spawns onto the hero's half without sealing a shooter off.
- **Pads** (`run.json` `pads`):
  - Room A has green candle-rune pads. Room B has the rune circle's inner 3x3.
  - A turn that starts on one heals the hero 5 HP and **cleanses** it: that turn keeps its full MP, clearing the mire
    and the root. Monsters get nothing.
- **Room B layout:**
  - The rune circle is the art's 5x5 walkable floor decal on (4–8, 4–8), and its inner 3x3 is the nine pads.
  - Tall candle stands on its four corners break the leech's line.
  - The fallen bell lies in the north-west corner, the altar sits under the rose window, and coffins float by the walls.
- **Room A packs** (Mauro: at least 6, with ranged monsters):

| Stars | Bog Dead | Mire Leeches | Total |
|---|---|---|---|
| ★1 | 4 | 2 | 6 |
| ★2–★4 | 4 | 3 | 7 |
| ★5 | 4 bellbound + 1 | 3 bellbound | 8 |

- **Room B:** the Mire Abbess with an escort of 2 Bog Dead and 1 Mire Leech behind the rune circle.
  - ★5: the Bell Wraith with a bellbound escort.
  - The room is won when every monster is down; the risen sink back when she falls.
  - Full heal on the flooded stair between the rooms.

## Monsters (`data/world/dungeon_monsters.json`, Proposed)
Base stats are at level 30 (+5% HP, +3% damage per level). The hero side is still the level sheet (80 HP, 6 AP,
3 MP; class HP per level is Open), so the band's numbers stay near the grotto's. The step up comes from the bigger
Bog Dead pack, the kiting leeches, the rite (a fight that grows back) and the ★5 mechanics.

| Monster | HP (L30 / L32) | AP | MP | Attack |
|---|---|---|---|---|
| Bog Dead | 22 / 24 | 5 | 2 | Bog Grasp 5, range 1 (slow melee shambler) |
| Mire Leech | 12 / 13 | 4 | 3 | Bile Spit 3, range 2–5, line of sight, kites |
| The Mire Abbess | 84 / 92 | 6 | 2 | Censer Lash 8, range 1–2; Rite of Rising (raise, 2 a fight, 50%) |
| Bellbound Bog Dead (★5) | 22 / 24 | 5 | 2 | Bellbound Grasp 5 + mire 1 |
| Bellbound Mire Leech (★5) | 12 / 13 | 4 | 3 | Bellbound Bile 3 + mire 1, range 2–5, line of sight |
| The Bell Wraith (★5) | 96 / 106 | 6 | 2 | Spectral Grasp 9 (10 at L32); Tolling Rite (4 a fight, 60%, leeches too); Grasping Mire |

- **Mire Leech:** the giant worm from the approved sheet, and the room's RANGED monster.
  - It uses the Sling Rat / Book Wraith / Harpooner rule. It spits when it has a line (bodies do not block). Next to
    the hero it slithers back to range 2+ first; otherwise it walks to the nearest cell in range with a line.
  - The bile (`bile_spit`, `gravebound_bile` at ★5) leaves on the release frame and bursts in `bile_impact`.
- **Signature, Rite of Rising** (agreed with the art agent; the boss's 14-frame `summon` strip):
  - **Timing:** she lowers the censer on f00–f02 and swings it high on f03–f06 while the floating candles flare. The
    green smoke bursts on f07, where the rite fires and the `rite_glow` reaches the corpse. The risen one plays its
    death strip reversed from f07, and she settles on f10–f13.
  - **Rule:** from her 2nd turn, when a Bog Dead lies fallen on a free cell, she raises it where it fell at half HP,
    then the rite rests a turn. That is 2 a fight; rite 2 AP plus lash 4 AP is her 6.
  - **Why it plays differently:** the Ratking and the Archivist summon new bodies on a timer, and Old Saltmaw moves
    the hero. The Abbess turns your own kills against you, so kill order matters:
    - drop her first and the risen sink back;
    - or burn the escort and stand on a corpse to keep it down.
- **★5, the Bell Wraith** (Mauro's pick, 10 Oct: a full transformation. The Abbess rises as a ghost out of the
  chained bronze bell, with long spectral arms and candles circling her; she floats. She has her own rig (art
  `star5/monsters/bell_wraith`: idle, a gliding walk, Spectral Grasp, hit, death, the 14-frame rite, all with glow
  maps; `rite_point` on f07). The run file sets `view.monster_glow` 0.7 so the ghost glow does not wash the ★5 room out. The ★5 ids live only in data: renaming them
  touches `dungeon_monsters.json` and `run.json`, and the tests read them from `variant_of`. Rule text in `run.json` `text.star5_rule` and `dungeon_monsters.json`
  `stars.by_dungeon.drowned_abbey.star5`):
  - **Tolling Rite:** raises Bog Dead and Mire Leeches at 60% HP, 4 a fight.
  - **Grasping Mire** (`signature2`, kind `hazard`, hazard `grasping_mire`, `root`):
    - From her 1st turn and every 2nd after, she tolls the bell and 2–3 cells around the hero (the hero's cell first) turn to grasping bog
      water for 3 hero turns.
    - A hero who **ends** a turn on one takes 5 and is **rooted**: no MP on the next turn. Walking across is safe.
    - The cells show the `grasping_mire` decal with their turns left. The hero bot never ends a turn on one when it
      can step off.
  - **Mire:** bellbound monsters' hits take 1 MP off the hero's next turn (no stacking). A candle pad or the rune
    circle cleanses it, and the root too.

## Stars and rewards
- **Stars:** ★1–★5 per run on the entry panel, with no unlock gate. The best star is kept
  (`pc_progress.dungeon_stars`), as in the other dungeons.
- **The abbey's own solo rows** (`stars.by_dungeon.drowned_abbey.scale`):
  - ★1 [1.0, 1.0];
  - ★2 [1.05, 1.0], +1 Mire Leech;
  - ★3 [1.1, 1.05];
  - ★4 [1.12, 1.05];
  - ★5 [1.0, 0.9]. ★5's extra difficulty is the bellbound pack and boss, the mire, the stronger rite and the
    grasping mire.
- **Rewards** (`pc_rewards` dungeon row `drowned_abbey`: the tier-30 **Mire Abbess** set, coin level 30, extras Swamp
  Elixir, Abbey Candle Wax, Sunken Bell):
  - XP: 27% of xp_to_next(run level) × pace(hero level) **× star**.
  - Coins: the abbey's coin roll × star.
  - Loot: Normal Mire Abbess parts from ★1. **Rare** parts only from ★3. ★5 guarantees a Rare part and a
    **Mystery Box**.
  - Epics: the 30–40 band has one epic in `rewards.json`, the **Abbess's Rosary** (amulet, `min_level` 40,
    `drop: Open`). Epics start at level 40 and no dungeon drop source is named for them, so the abbey does not drop
    it. The ★5 Legendary slot stays a Mystery Box, as in the other three dungeons. Whether ★5 abbey runs at level 40
    should roll the Rosary is Open for Mauro.
  - Any star credits `southbridge_dungeon` (clear_dungeon), now live.

### Sim results (`tests/sim_dungeon_stars.gd drowned_abbey 8 32`: solo hero bot, level 32, 8 runs per class per star)
| Star | Scale [HP, dmg] | Win | Kestrel | Ironjaw | Mender | Gloam | Bastion | Lost in A / B |
|---|---|---|---|---|---|---|---|---|
| ★1 | [1.0, 1.0] | 78% | 1/8 | 8/8 | 8/8 | 8/8 | 6/8 | 1 / 8 |
| ★2 | [1.05, 1.0] + 1 Mire Leech | 55% | 1/8 | 4/8 | 7/8 | 4/8 | 6/8 | 13 / 5 |
| ★3 | [1.1, 1.05] | 52% | 1/8 | 3/8 | 8/8 | 2/8 | 7/8 | 12 / 7 |
| ★4 | [1.12, 1.05] | 38% | 0/8 | 4/8 | 7/8 | 0/8 | 4/8 | 18 / 7 |
| ★5 | [1.0, 0.9] + bellbound pack, boss, mire, grasping mire | 35% | 0/8 | 1/8 | 8/8 | 0/8 | 5/8 | 18 / 8 |

Tuning notes:
- **First numbers** (Bog Dead 24 / 6, Mire Leech 13 / 4, Abbess 92 / 9): ★1 35%, with most losses in room B.
- **Base cut:** Bog Dead 20 / 5, leech 12 / 3, Abbess 80 / 8 gave ★1 95%. 22 / 5 and 84 / 8 gave ★1 78–80%.
- **Rite rhythm:** the rite on a fixed 2nd-turn beat hardly fired (2 rites in 20 real fights), so `every` became a
  cooldown. Corpses then rise as soon as they fall.
- **Why the rows are lumpy:**
  - The bot is sensitive to the Bog Dead's HP threshold. At level 32 a ×1.1 Bog Dead has 26 HP, ×1.12 has 27 and ×1.15
    has 28, and the win rate drops sharply across 27→28 (★2 at [1.1, 1.0]: 78%; [1.15, 1.0]: 58%; [1.25, 1.0]: 50%).
  - Damage ×1.05 rounds away entirely at these numbers (5→5, 3→3, 8→8), and ×1.1 turns the grasp into 6 (★2 [1.1, 1.1]
    38%).
  - So ★2 adds a leech instead of more HP.
- **★5:** [0.95, 0.95] gave 30% and [0.9, 0.9] 40%. [1.0, 0.9] gives 35%. Re-run after the Bell Wraith rename with the rite cap at 4 (was 3): still 35%; the bot rarely sees a 4th rising.
- **Classes:** as in the other dungeons, the bot plays Kestrel and Gloam poorly against ranged kiters and Mender slowly
  but surely. Real players do better.
