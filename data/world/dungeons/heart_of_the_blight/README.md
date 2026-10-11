# Heart of the Blight: game data and design choices

Westwatch's dungeon, levels 40–50. Westwatch is a danger zone: the blighted dark side of the town. This is the fifth and
last Crosshaven town dungeon.

- **Art:** `art/pc/dungeons/heart_of_the_blight/` (manifest and README, branch `claude/blight-art`).
- **Code:** the same files as the other four dungeons: `backend/world_dungeons.gd`, `pc_dungeon_run.gd`,
  `pc_monsters.gd`, `dungeon_ai.gd`, the dungeon section of `combat_sim.gd`, and `scenes/world/dungeon/`.
- **Data:** everything that differs lives in this folder, `data/world/dungeon_monsters.json` and
  `data/world/dungeons.json`.

Three new data-driven kinds were added for it (see **New kinds**). The Old Granary Cellar, the Frostspire Archive, the
Saltmaw Grotto and the Drowned Abbey play exactly as before.

## Door
- **Blight door:** at `crosshaven_westwatch` (5, 13), on the open west plain, the blighted side of the town.
  - The rotting stump stands on (2–5, 9–12). The manifest footprint is 4x4, with the door at footprint (3, 4).
  - The stump blocks walking. The door stays passable and can be walked to from the chunk spawn (16, 10).
  - The door is not an NPC, gate, exit or spawn cell.
- **Door Keeper** (`westwatch_door_keeper`): moved from the square (14, 10) to (6, 13), beside the door on the east.
  - The door or the keeper opens the entry panel.
  - His line warns of the signature: "The Rotting Elder walls you in with roots. Keep a way out, and break the horrors'
    lines."
- **Capture offsets:** `view.door` holds still_from_door [3, 1], movie_from_door [0, 5] and back_from_door [0, 3].

## New kinds
- **Signature kind `wall`** (`signature.kind`)
  - Keys:
    - `cells`, `turns`, `first_turn`, `every`, `ap`;
    - optional: `prop` (the board prop drawn), `on_pads`, `beam`, `wall_text`, `wither_text`.
  - **What it does:** on the boss's `first_turn`-th turn, then every `every` turns (a fixed beat), roots erupt on up to
    `cells` free cells next to the hero (Chebyshev 1).
    - The farthest cells from the caster go first (straight-line distance), so the hero's back row rises first.
    - The wall stands as blocking terrain: no walking through it, and it cuts lines of sight both ways.
    - It withers once the hero has ended `turns` turns, and the cells open again.
  - **Where it never rises:**
    - on a pad (unless `on_pads`), so the cleansing pads stay usable;
    - on a body, a corpse or a hazard cell;
    - on any cell that would seal a live unit off from another. Each candidate is checked with an ortho flood
      (`CombatSim._units_connected`).
  - **Events, snapshot and view:**
    - CombatSim logs a `wall` event (cells, prop, beam, turns) and a `wall_wither` event. The snapshot lists
      `dungeon.walls`.
    - The room view plays the boss's 14-frame `summon` strip. On the flare frame (f07), it draws a `root_crack` from
      the manifest `staff_point` to each wall cell.
    - Each wall is a `WallProp` (`dungeon_props.gd`). It plays the kit's `rise` strip, then `idle` with a pulsing glow,
      then `wither`.
  - **Validation:** `pc_monsters` checks the keys, and that `cells` and `turns` are 1 or more.
- **Fused hazards** (`signature2` kind `hazard` with `fuse`)
  - Keys: `fuse` (hero turns before a pod bursts), `splash` (Chebyshev radius), `ap_loss`, `burst_text`, `miss_text`.
  - **What it does:**
    - A fused pod does nothing where it stands, and it never hurts like a pool.
    - When the hero has ended `fuse` turns, every pod bursts.
    - The hero takes one hit (the strongest pod) if any bursting pod is within its splash. The hit costs `ap_loss` AP
      on the hero's next turn.
  - **Events and view:**
    - CombatSim logs a `bloom` event (cells, hit, damage).
    - The view draws the pod's `swell` loop and tints the splash cells as danger on the turn they burst. It then plays
      the `<hazard>_burst` strip (`star5.board.anims`) on each pod.
  - **Hero bot:** it treats a bursting pod's splash as a pool. It does not end a turn there when it can step out.
- **Wither** (attack key `wither {ap, word}`, and the hero's `ap_drain`)
  - A hit takes `ap` AP off the hero's next turn, with no stacking.
  - A thawing pad (`pads.thaw`) cleanses it, as it does the MP drains.
- **View additions:**
  - `view.walls.<prop>` sets the stand-in colours.
  - `view.hazard.<id>.splash` sets the danger tint.
  - `view.pads.<kind>.glow` makes a decal pad draw the pad glow too (the rune circle's inner 3x3).
  - The `sprout` pad mark is a placeholder.
  - The manifest `staff_point` is read like the lure and rite points.
- **Capture:**
  - `view.still_wait` names what the room B still waits for per star (the blight waits for the root wall, and at ★5 the pods too).
  - The fight clip prints the signature casts it saw.
  - `view.showcase_zoom` is 1.8.

## Rooms (`run.json`, tags built by `build_rooms.py`)
- **Boards:** both rooms are 12x12, with props from the art kit (the manifest's room lists).
- **Room A, the Rotting Hollow:**
  - Props: `root_mound` (2x2), `root_knot`, `violet_crystals`, `fungus_clump`, `bone_pile`.
  - Six violet `blight_pad`s.
  - `root_veins` floor decals (walkable).
- **Room B, the Elder's Heart:**
  - The `root_rune_circle` is a 5x5 walkable decal on (4–8, 4–8). Its inner 3x3 is the nine pads, drawn with the pad
    glow.
  - Four `crystal_spire`s stand on the circle's corners and break the horror's lines.
  - `chained_cocoon`, `broken_masonry`, `blight_eggs`, `violet_crystals`, `root_knot` and `bone_pile` stand round the
    walls, under the painted heart.
- **`build_rooms.py` checks the rules before it writes:**
  - every prop is a kit prop of that room (from the manifest);
  - every walkable cell is reachable;
  - the spawns of every star are on open floor, off the pads;
  - room A spawns are on the far rows (y 0–4, 6+ cells from the hero);
  - bodies on every spawn leave every route open;
  - props cut some of the horrors' lines without sealing a shooter off;
  - the hero start keeps three open sides.
- **Pads:** a turn that starts on one heals the hero 5 HP and keeps its full MP and AP (cleansing the wither). Monsters
  get nothing. Root walls never rise on a pad.
- **Room A packs** (Mauro: at least 6, with ranged monsters):

| Stars | Hounds | Horrors | Total |
|---|---|---|---|
| ★1 | 4 Blight Hounds | 2 Blight Horrors | 6 |
| ★2–★4 | 4 Blight Hounds | 3 Blight Horrors | 7 |
| ★5 | 4 Crystal Hounds | 4 Crystal Horrors | 8 |

- **Room B:** the Rotting Elder with an escort of 2 Blight Hounds and 1 Blight Horror behind the rune circle.
  - At ★5, the Crystal Colossus has a crystal escort.
  - The room is won when every monster is down. The between-rooms rest is a full heal.

## Monsters (`data/world/dungeon_monsters.json`, Proposed)
Base stats are at level 40, with +5% HP and +3% damage per level. The hero side is still the level sheet (80 HP, 6 AP,
3 MP; class HP per level is Open), so the band's numbers stay near the abbey's. The step up comes from:
- the fast hounds (4 MP, they all arrive together);
- the kiting horrors;
- the Root Wall (the board shuts your retreat and moves the lines of fire);
- the ★5 bloom and wither.

| Monster | HP (L40 / L42) | AP | MP | Attack (damage at L40) |
|---|---|---|---|---|
| Blight Hound | 18 / 20 | 5 | 4 | Blight Bite 5, range 1 (fast melee) |
| Blight Horror | 13 / 14 | 4 | 3 | Spore Bolt 3, range 2–5, line of sight, kites |
| The Rotting Elder | 92 / 101 | 6 | 2 | Root Claw 8, range 1; Root Wall (3 cells, 2 hero turns, turn 1 and every 3rd) |
| Crystal Hound (★5) | 18 / 20 | 5 | 4 | Crystal Bite 5 |
| Crystal Horror (★5) | 13 / 14 | 4 | 3 | Crystal Shard 3 + crystallise 1 AP, range 2–5, line of sight |
| The Crystal Colossus (★5) | 108 / 119 | 6 | 2 | Crystal Lance 10, range 1–2; Crystal Wall (4 cells); Crystal Bloom |

- **Blight Hound:** a fast melee runner, with 4 MP against the Bog Dead's 2.
- **Blight Horror:** the gaunt root figure from the approved sheet, and the room's RANGED monster.
  - It uses the Sling Rat / Book Wraith / Harpooner / Mire Leech rule: it throws when it has a line (bodies do not
    block).
  - Next to the hero it steps back to range 2+ first. Otherwise it walks to the nearest cell in range with a line.
  - The bolt (`spore_bolt`; `crystal_shard` at ★5) leaves on attack f07 at the manifest `release` point and bursts in
    `spore_impact` (`crystal_shard_impact` at ★5).
- **Signature, Root Wall** (agreed with the art agent; the boss's 14-frame `summon` strip):
  - **Timing:**
    - f00–f02: he lifts the staff and the crystal heart dims.
    - f03–f06: the staff goes high and the heart flares.
    - f07: he drives the staff into the floor. The wall fires here, the root cracks run from the `staff_point` to
      each wall cell, and the walls play `rise`.
    - f08–f10: the shock ripples.
    - f11–f13: he settles.
  - **Rule:** on his 1st turn and every 3rd after, roots rise on 3 cells next to you, your back row first, and stand
    until you have ended 2 turns. That is 2 AP for the wall plus 4 for the claw, his 6.
  - **Why it plays differently:**
    - The Ratking and the Archivist add bodies, Old Saltmaw moves the hero, and the Abbess raises the dead. The Elder
      changes the board.
    - The wall cuts off your retreat and pins you near the hounds.
    - It also cuts the horrors' lines both ways, so you can hide behind your own cage.
    - Stepping off the pads before he walls you in matters, and so does keeping a side open.
- **★5, the Crystal Colossus** (Mauro's pick, 11 Oct: "Coloso de Cristal")
  - **Look:** the violet crystal has consumed the Elder. He is an angular crystal golem with a crystal spear-staff,
    with his own rig: `star5/monsters/crystal_colossus` (idle, walk, the Crystal Lance thrust, hit, death, and the
    14-frame Root Wall strip with its own `staff_point`, all with glow maps).
  - **Ids:** the ★5 ids live only in data. Renaming them touches `dungeon_monsters.json` and `run.json`; the tests read
    them from `variant_of`.
  - **Rule text:** `run.json` `text.star5_rule` and `dungeon_monsters.json` `stars.by_dungeon.heart_of_the_blight.star5`.
  - **Crystal Wall:** the same rule on 4 cells, drawn as the kit's `crystal_wall`.
  - **Crystal Bloom** (`signature2`, kind `hazard`, hazard `crystal_bloom`, `fuse` 1, `splash` 1, `ap_loss` 2):
    - From his 1st turn and every 2nd after, 2–3 crystal pods swell round the hero, the hero's cell first.
    - When the hero ends the next turn they burst. A hero on or next to a pod takes 6 (5 at ★5's 0.8 damage row) and
      is crystallised: 2 AP less next turn.
    - Pods do not block. Step two cells clear.
    - The splash cells glow as danger on the turn they burst.
  - **Crystal Horrors crystallise:** a shard hit takes 1 AP off the hero's next turn (no stacking). The Crystal Hounds
    are the crystal look with the same stats. A hound wither made room A unwinnable for the bot: 6 AP against 3-AP
    spells means one cast a turn.
  - A blight pad or the rune circle cleanses both.

## Stars and rewards
- **Stars:** ★1–★5 per run on the entry panel, with no unlock gate. The best star is kept (`pc_progress.dungeon_stars`).
- **The blight's own solo rows** (`stars.by_dungeon.heart_of_the_blight.scale`):
  - ★1 [1.0, 1.0];
  - ★2 [1.0, 1.0], +1 Blight Horror;
  - ★3 [1.2, 1.05];
  - ★4 [1.25, 1.05];
  - ★5 [0.8, 0.8]. ★5's extra difficulty is the crystal pack of 8, the Colossus, the Crystal Bloom and the crystallise.
- **Rewards** (`pc_rewards` dungeon row `heart_of_the_blight`, unchanged: the **Rotting Elder** set (tier 50, spec 4.9),
  class tier 50, coin level 50, extras Elderroot Feast, Blight Heartwood, Blight Seedling, title "Blightbane"):
  - XP: 27% of xp_to_next(run level) × pace(hero level) **× star**.
  - Coins: the blight's coin roll × star.
  - Loot: Normal parts from ★1. **Rare** parts only from ★3. ★5 guarantees a Rare part and a **Mystery Box**.
  - **Open: the band's set is level 50.** The Rotting Elder set and the tier-50 class sets (spec 4.9 says tier 50)
    have `min_level` 50, so a level 40–49 hero cannot wear the parts yet. The Abbey drops its tier-30 set from level
    30. Whether this band should drop the tier-40 class sets (and coin level 40) instead is Open for Mauro.
  - **Epics and relics:** the 40–50 band's epics have `drop: Open`, and the dungeon does not drop them:
    - Gale Signet (40), Ember Crown (45), Stormheart Gauntlet (45), Prism Striders (50);
    - the Abbey's Abbess's Rosary (40).

    The relics are Heart of the Elder (50), Crown of Crosshaven (50) and Blightroot Ring (50), all with `drop: Open`.
    Heart of the Elder and Blightroot Ring look made for this dungeon. The ★5 Legendary slot stays a Mystery Box.
  - Any star credits `westwatch_dungeon` (clear_dungeon), now live.

### Sim results (`tests/sim_dungeon_stars.gd heart_of_the_blight 8 42`: solo hero bot, level 42, 8 runs per class per star)
| Star | Scale [HP, dmg] | Win | Kestrel | Ironjaw | Mender | Gloam | Bastion | Lost in A / B |
|---|---|---|---|---|---|---|---|---|
| ★1 | [1.0, 1.0] | 85% | 4/8 | 8/8 | 8/8 | 7/8 | 7/8 | 1 / 5 |
| ★2 | [1.0, 1.0] + 1 Blight Horror | 70% | 5/8 | 6/8 | 8/8 | 3/8 | 6/8 | 11 / 1 |
| ★3 | [1.2, 1.05] | 55% | 0/8 | 4/8 | 8/8 | 3/8 | 7/8 | 17 / 1 |
| ★4 | [1.25, 1.05] | 50% | 0/8 | 5/8 | 8/8 | 3/8 | 4/8 | 18 / 2 |
| ★5 | [0.8, 0.8] + crystal pack, Colossus, bloom, crystallise | 38% | 2/8 | 5/8 | 5/8 | 0/8 | 3/8 | 19 / 6 |

Tuning notes:
- **First numbers** were hounds 20 HP with two 3-damage bites (6 AP), horrors 13 / 4 and the Elder 96 / 9. They gave
  ★1 50% and ★2–★5 0–20%.
  - Two bites from four 4-MP hounds that all arrive on turn 2 is about 22 a turn.
  - Hounds at 16 / 4 (one bite) gave 100%. 18 / 5 is the middle.
- **The horror's damage** is a cliff. At 4, the extra ★2 horror took ★2 from 85% to 30%. At 3 it is 60–70%.
- **The Elder:** HP barely moves the bot (86–101 the same). Claw damage 9 → 8 (10 → 8 at level 42) moved ★1 from 75% to
  85–88%.
- **★5:**
  - The first try (wither on every crystal hit, pack 4 + 1 + 3) gave 0–10% at any row from [1.0, 0.9] to [0.75, 0.8].
    Losing 1 AP from 6 against 3-AP spells halves the hero's damage, and the bot is hit by almost every monster every
    turn.
  - The 8th monster at (7, 3) pulled the bot into the open centre. It now spawns at (7, 0) as a fourth horror.
  - With wither on the horrors only, [0.8, 0.8] gives 38%.
- **Damage rounds:** at these numbers ×0.9 does not change the hounds' 5 (5.3 → 5 → 4.8 → 5). Use ×0.85 or less to see
  a step.
- **Classes:** as in the other dungeons, the bot plays Kestrel and Gloam poorly against ranged kiters, and Mender slowly
  but surely. Real players do better.
