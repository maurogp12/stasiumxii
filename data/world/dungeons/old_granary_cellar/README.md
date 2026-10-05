# Old Granary Cellar: game data and design choices

Stoneford's dungeon, levels 1–10. Art: `art/pc/dungeons/old_granary_cellar/` (manifest + README).
Code: `backend/world_dungeons.gd`, `backend/pc_dungeon_run.gd`, `backend/pc_monsters.gd`,
`backend/dungeon_ai.gd`, the dungeon section of `backend/combat_sim.gd`, `scenes/world/dungeon/`.

## Door
- Hatch at `crosshaven_stoneford` (16, 11); granary building on (15–17, 8–10), blocks walking.
- Door Keeper at (15, 11). Hatch or keeper opens the entry panel.

## Rooms (`run.json`, tags built by `build_rooms.py`)
- 12x12 boards. Props block cells; pads (wheat pads in A, the 3x3 drain grate in B) heal the hero 4 HP at turn start.
- **Room A packs** (Mauro: "at least 6 monsters the first room"), spawned on the far rows, off the pads, never sealing a route:

| Stars | Granary Rats | Sling Rats | Scarecrow Drudges | Total |
|---|---|---|---|---|
| ★1–★2 | 2 | 2 | 2 | 6 |
| ★3–★4 | 3 | 2 | 2 | 7 |
| ★5 | 3 radioactive | 3 radioactive | 2 | 8 |

- **Room B:** the Ratking with an escort of 2 Granary Rats and 1 Scarecrow Drudge in front of his throne.
  His call adds 2 rats on his 2nd turn and every 3rd turn after. **One cap** counts every live rat of the
  summoned kind (escort and summons together): 4 alive, 4 summoned in all (★5: 4 alive, 6 in all).
  When he falls his summons scatter; the escort fights on. The room is won when every monster is down.
- Full heal between rooms.

## Monsters (`data/world/dungeon_monsters.json`, Proposed)
Base stats at level 1 (lowered when room A grew to 6–8 monsters; +5% HP, +3% damage per level):

| Monster | HP | AP | MP | Attack |
|---|---|---|---|---|
| Granary Rat | 13 | 4 | 3 | Gnaw 4, range 1 |
| Sling Rat | 9 | 4 | 3 | Sling 3, range 2–5, line of sight |
| Scarecrow Drudge | 24 | 5 | 2 | Sickle 6, range 1 |
| The Ratking | 82 | 6 | 2 | Crook 10, range 1; Call the Swarm |

- **Sling Rat:** needs a line of sight. The Koliseo has no LoS rule, so dungeons add one: the straight line
  may not cross a prop cell; bodies do not block. AI: shoot when it can; adjacent to the hero it steps back to
  range 2+ first (kiting); otherwise it walks to the nearest cell in range with a clear line. The stone leaves on
  the release frame (f07) at the manifest release point, flies an arc and bursts in the impact puff.
- **★5 (Mauro: "Boss 5 stars should be a radioactive rat"):** the Radioactive Ratking replaces the Ratking; his
  calls bring radioactive rats; every other turn (from his 1st) he spills **toxic pools** on 2–3 cells around the
  hero (the hero's cell first). A hero who **ends a turn** on a pool takes 6 poison; pools last 3 hero turns.
  Walking through a pool is safe; only ending a turn there hurts. The danger cells glow green with their turns
  left on them, and the hero bot never ends a turn on one. Radioactive Sling Rats add a small poison (2 HP for
  2 turns, no stacking).

## Stars (mirrors mobile `stasis_catalog.gd`, `hero_progress.gd`, `gear_bag.gd`)
- **Picker:** ★1–★5 on the entry panel, chosen per run. **No unlock gate**, as on mobile. The best star cleared
  per dungeon is kept in `pc_progress` (`dungeon_stars`) and shown on the panel.
- **Scaling:** monster HP and damage = level-band stats × the star row. Mobile's `STAR_SCALE`
  `{1:[1.0,1.0], 2:[1.4,1.2], 3:[4.0,2.8], 4:[6.8,4.2], 5:[8.8,5.2]}` is tuned for a **party of 4** from ★3
  (`PARTY_FOR_STAR`, `PARTY_SCALE`). PC runs are solo for now, so only the solo row applies and the raw mobile
  rows are impossible solo at levels 1–10 (0% at ★3+ in the sim). Chosen solo rows (`stars.scale`):
  ★1 [1.0, 1.0], ★2 [1.1, 1.05], ★3 [1.15, 1.1], ★4 [1.2, 1.1], ★5 [1.0, 1.0] — ★5's difficulty comes from
  the radioactive pack, the radioactive boss and the pools instead of bigger numbers.
- **Sim** (`tests/sim_granary_stars.gd`, hero bot, solo, level 2, 8 runs × 5 classes per star): see
  the table below. The bot plays Gloam poorly (no Shade / Ambush combos) and Mender slowly (its damage needs
  Pulse first); real players do better.
- **Rewards:**
  - XP: the PC base win XP (27% × xp_to_next × pace, 43 at level 1) **× star**, as mobile's 60 × star.
  - Coins: the cellar's `pc_rewards` coins × star.
  - Loot, gated like mobile's gear sources: Normal (regular set parts) from ★1; **Rare** parts only from ★3 (a
    rare roll below ★3 is turned into a regular part); ★5 guarantees a Rare part and a **Mystery Box**, the
    Legendary slot (PC has no Legendary rarity for a level 1–10 band; epics and relics start at level 40).
  - Any star credits the `clear_dungeon` mission.

### Sim results (solo hero bot, level 2, 8 runs per class per star)
| Star | Scale [HP, dmg] | Win | Kestrel | Ironjaw | Mender | Gloam | Bastion |
|---|---|---|---|---|---|---|---|
| ★1 | [1.0, 1.0] | 85% | 7/8 | 7/8 | 8/8 | 4/8 | 8/8 |
| ★2 | [1.1, 1.05] | 68% | 7/8 | 4/8 | 8/8 | 0/8 | 8/8 |
| ★3 | [1.15, 1.1] | 60% | 7/8 | 2/8 | 8/8 | 0/8 | 7/8 |
| ★4 | [1.2, 1.1] | 58% | 5/8 | 2/8 | 8/8 | 2/8 | 6/8 |
| ★5 | [1.0, 1.0] + radioactive pack, boss, pools | 38% | 6/8 | 1/8 | 4/8 | 0/8 | 4/8 |

★1 sits at the ~80% target for every class the bot plays well (Gloam is a bot limit). Mender wins nearly
everything but slowly (long runs); recorded, not changed. ★4 at [1.25, 1.15] gave 30%, so it was eased to
[1.2, 1.1]. Mobile's targets (~80/65/50% at ★3/★4/★5) are for a party; solo the curve lands near 60/58/38%.
