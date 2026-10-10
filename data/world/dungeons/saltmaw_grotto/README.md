# Saltmaw Grotto: game data and design choices

Eastmarch's dungeon, levels 20–30. Art: `art/pc/dungeons/saltmaw_grotto/` (manifest + README, branch
`claude/saltmaw-art`). Code: the same files as the Old Granary Cellar and the Frostspire Archive
(`backend/world_dungeons.gd`, `pc_dungeon_run.gd`, `pc_monsters.gd`, `dungeon_ai.gd`, the dungeon section of
`combat_sim.gd`, `scenes/world/dungeon/`). Everything that differs is data: this folder,
`data/world/dungeon_monsters.json` and `data/world/dungeons.json`. Two new data-driven kinds were added for it (see
**New kinds**); the cellar and the archive play exactly as before.

## Door
- Grotto door at `crosshaven_eastmarch` (26, 17). The sea-cave rock stands on (25–27, 14–16): the manifest footprint is
  3x3 with the door at footprint (1, 3), the end of its plank pier. It blocks walking; the door stays passable and
  can be walked to from the chunk spawn round the rock.
- Door Keeper (`eastmarch_door_keeper`) moved from (15, 17) to (25, 17), footprint (0, 3), beside the door. The door
  or the keeper opens the entry panel.

## New kinds
- **Signature kind `pull`** (`signature.kind`, keys `cells`, `min_range`, `max_range`, `los`, `first_turn`,
  `every`, `ap`): the boss slides the hero up to `cells` toward him. Each step goes along the longer axis of the gap
  (on the diagonal when the gap is square), onto a walkable, empty cell; the slide stops at a prop, a body or next to
  him. It needs the hero at `min_range`..`max_range` (Chebyshev) and, with `los`, a straight line not crossed by a prop.
  CombatSim logs a `lure` event (the boss plays his 14-frame `summon` strip) and a `pull` event (from, to, path) the
  room view slides cell by cell from the flare frame (f07). `pc_monsters` checks the pull keys and the kind.
- **Drag hazards** (`signature2` kind `hazard` with `drag`): a hero who ends a turn on the cell is also dragged `drag`
  cells toward the caster (the same slide, a `pull` event with `how: drag`). `lay_text` and `hit_text` give the
  hazard its own coach lines (the frost patch keeps its old lines).
- **`chill.word`** names the MP status in the coach lines ("soaked" here, "chilled" by default), and run.json
  `pads.thaw_text` names the pad's thaw ("The tide pad rinses ...").

## Rooms (`run.json`, tags built by `build_rooms.py`)
- 12x12 boards. Props are the art kit's (`barnacle_rock`, `coral_cluster`, `sunken_crate`, `barrel`, `giant_clam`,
  `anchor`, `treasure_chest`, `sunken_statue`, `rock_spire`), all 1x1 and blocking.
- `build_rooms.py` checks the rules before it writes: every prop is a kit prop, every walkable cell reachable from the
  hero start, the spawns of every star on open floor off the pads, room A spawns on the far rows (y 0–4, 6+ cells from
  the hero), bodies on every spawn still leave every route open, and the props cut some lines from the Harpooners'
  spawns (room A) and Old Saltmaw's (room B) onto the hero's half without sealing a shooter off.
- **Pads** (`run.json` `pads`): teal coral pads in room A, the 3x3 whirlpool in room B. A turn that starts on one
  heals the hero 5 HP and **rinses** the soak (that turn keeps its full MP). Monsters get nothing.
- Room B: six rock spires ring the whirlpool with gaps. A hero behind a spire is out of the lantern's line.
- **Room A packs** (Mauro: at least 6, with ranged monsters):

| Stars | Reef Crabs | Drowned Sailors | Drowned Harpooners | Total |
|---|---|---|---|---|
| ★1–★2 | 2 | 2 | 2 | 6 |
| ★3–★4 | 2 | 2 | 3 | 7 |
| ★5 | 2 abyssal | 2 abyssal + 1 | 3 abyssal | 8 |

- **Room B:** Old Saltmaw with an escort of 1 Drowned Sailor, 1 Drowned Harpooner and 1 Reef Crab behind the
  whirlpool (★5: the Abyssal Saltmaw with an abyssal escort). The room is won when every monster is down. Full heal on
  the tide steps between rooms.

## Monsters (`data/world/dungeon_monsters.json`, Proposed)
Base stats at level 20 (+5% HP, +3% damage per level). The hero side is still the level sheet (80 HP, 6 AP, 3 MP;
class HP per level is Open), so the band's numbers stay near the archive's and the step up comes from the double
cutlass swing, the kiting harpooners, the lure-and-bite and the ★5 mechanics.

| Monster | HP (L20 / L22) | AP | MP | Attack |
|---|---|---|---|---|
| Reef Crab | 30 / 33 | 5 | 2 | Claw Pinch 5, range 1 (slow melee tank) |
| Drowned Sailor | 14 / 15 | 6 | 3 | Cutlass Slash 3 for 3 AP, range 1 (two swings a turn) |
| Drowned Harpooner | 10 / 11 | 4 | 3 | Harpoon Throw 3, range 2–5, line of sight, kites |
| Old Saltmaw | 80 / 88 | 6 | 2 | Angler Bite 8, range 1; Lantern Lure (pull 2) |
| Abyssal Reef Crab (★5) | 30 / 33 | 5 | 2 | Abyssal Pinch 5 + soak 1 |
| Abyssal Drowned Sailor (★5) | 14 / 15 | 6 | 3 | Abyssal Cutlass 3 + soak 1 |
| Abyssal Drowned Harpooner (★5) | 10 / 11 | 4 | 3 | Abyssal Harpoon 3 + soak 1, range 2–5, line of sight |
| Abyssal Saltmaw (★5) | 96 / 106 | 6 | 2 | Abyssal Bite 10 (11 at L22); Abyssal Lure (pull 3); Riptide |

- **Drowned Harpooner:** the Sling Rat / Book Wraith rule. It throws when it has a line (bodies do not block); next to
  the hero it steps back to range 2+ first; otherwise it walks to the nearest cell in range with a line. The harpoon
  (`harpoon`, `abyssal_harpoon` at ★5, turned to its flight) leaves on the release frame (attack f07) at the
  manifest release point and bursts in `harpoon_impact`.
- **Signature, Lantern Lure** (agreed with the art agent; the boss's 14-frame `summon` strip: crouch f00–f02, the
  lantern lifts f03–f06, flare on f07 where the pull fires, the hero slides f07–f10, he settles f10–f13): on his 1st
  turn and every 2nd after, from 2–6 cells with a clear line, he pulls the hero 2 cells toward him, then bites if the
  hero landed in reach (lure 2 AP + bite 4 AP = his 6). Rock spires and props break the line; a body in the way stops
  the slide.
- **★5, the Abyssal Saltmaw** (rule text in `run.json` `text.star5_rule` and `dungeon_monsters.json`
  `stars.by_dungeon.saltmaw_grotto.star5`):
  - Abyssal Lure pulls **3** cells on the same rhythm.
  - **Riptide** (`signature2`, kind `hazard`, hazard `riptide`, `drag` 1): from his 2nd turn and every 2nd after, 2–3
    cells around the hero (the hero's cell first) churn for 3 hero turns. A hero who **ends** a turn on one takes 5
    and is **dragged 1 cell toward him**. Walking across is safe. The cells show the `riptide` decal with their turns
    left; the hero bot never ends a turn on one when it can step off.
  - **Soak:** abyssal monsters' hits take 1 MP off the hero's next turn (no stacking). A coral pad or the whirlpool
    rinses it.

## Stars and rewards
- ★1–★5 per run on the entry panel, no unlock gate, best star kept (`pc_progress.dungeon_stars`), as the others.
- The grotto has its own solo rows (`stars.by_dungeon.saltmaw_grotto.scale`): ★1 [1.0, 1.0], ★2 [1.05, 1.0],
  ★3 [1.1, 1.05] (+1 Harpooner), ★4 [1.15, 1.05], ★5 [1.0, 1.0]. ★5's extra difficulty is the abyssal pack and
  boss, soak, the longer lure and the riptide.
- **Rewards** (`pc_rewards` dungeon row `saltmaw_grotto`: the tier-20 **Saltmaw** set, coin level 20, extras Reef
  Chowder, Pearl Shell, Ship in a Bottle):
  - XP: 27% of xp_to_next(run level) × pace(hero level) **× star**: 2,220 at level 22 ★1.
  - Coins: the grotto's coin roll × star.
  - Loot: Normal Saltmaw parts from ★1, **Rare** parts only from ★3, ★5 guarantees a Rare part and a **Mystery Box**
    (PC has no Legendary tier in a 20–30 band; epics and relics start at level 40).
  - Any star credits `eastmarch_dungeon` (clear_dungeon), now live.

### Sim results (`tests/sim_dungeon_stars.gd saltmaw_grotto 8 22`: solo hero bot, level 22, 8 runs per class per star)
| Star | Scale [HP, dmg] | Win | Kestrel | Ironjaw | Mender | Gloam | Bastion | Lost in A / B |
|---|---|---|---|---|---|---|---|---|
| ★1 | [1.0, 1.0] | 85% | 5/8 | 6/8 | 8/8 | 8/8 | 7/8 | 1 / 5 |
| ★2 | [1.05, 1.0] | 65% | 0/8 | 5/8 | 8/8 | 7/8 | 6/8 | 4 / 10 |
| ★3 | [1.1, 1.05] + 1 Harpooner | 55% | 1/8 | 0/8 | 8/8 | 6/8 | 7/8 | 12 / 6 |
| ★4 | [1.15, 1.05] | 45% | 0/8 | 1/8 | 7/8 | 5/8 | 5/8 | 14 / 8 |
| ★5 | [1.0, 1.0] + abyssal pack, boss, riptide | 38% | 0/8 | 0/8 | 7/8 | 0/8 | 8/8 | 18 / 7 |

Tuning notes: the first numbers (Crab 30 / 6, Sailor 16 HP with Cutlass 4, Harpooner 10 / 4, Saltmaw 90 / 11) gave
★1 30% with most losses in room B: the lure makes him hit every other turn, so he went down to 84 / 9 (★1 65%), then
80 / 8 (★1 85%). The crab, the sailor and the harpoon came down by 1 each. With the archive's ★5 row shape
[0.9, 0.85] the ★5 run was easier than ★1 (60%: a weaker boss), so the mutated boss got his own numbers (96 / 10,
pull 3) and ★5 went to [1.0, 1.0] (38%). As in the other dungeons the bot plays Kestrel, Ironjaw and Gloam poorly
against ranged kiters and Mender slowly but surely; real players do better.
