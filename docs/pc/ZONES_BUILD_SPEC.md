# STASIUM XII (PC): open world zones build spec, levels 1–50

Owner: **Mauro**. Spec written 3 Oct 2026 for the build team (Stasium Bot with
the Cursor cloud coding agents, the Scenario art agent, the Technical Artist
agent and the combat-feel agent). The writer of this spec does not build it.

Status: Mauro approved the zone plan **to try** (3 Oct 2026) and placed
Stormspire / Coilgate **south of Gloomfen at 35–40**. Everything else marked
**Proposed** is a suggestion that Mauro can change. Items marked **Open** wait on
Mauro: do not decide them in code.

Map image of the plan: Proposed zones on the regions concept
(`pc_zone_map_proposed.png`, shared in chat 3 Oct 2026). It shows the zones
before Stormspire was placed.

---

## 0. The main goal: high graphics, great visuals

Mauro, 3 Oct 2026: **"MAIN GOAL A HIGH GRAPHICS GREAT VISUALS"** and
**"DOFUS / WAKFU / WAVEN COMBINED"**.

Every work package is judged first on how it looks and moves. Systems that
work but look placeholder are not done; they are "stand-in" and must say so.

The visual bar:

- **Dofus:** a readable, painted, 2:1 isometric map. Every cell is clear to
  click, clean silhouettes, warm and detailed props.
- **Wakfu:** a living world. Things sway, critters move, light changes,
  weather and day/night run. Characters glide when they walk (click to walk,
  smooth corners, no stop and go), the camera drifts with them, and zones fade
  into each other.
- **Waven:** bold, saturated colour; strong lighting and rim light; chunky
  readable characters; punchy VFX and UI.
- **Never 3D.** Painted 2D isometric only (Mauro rejected 3D).

Mauro, 3 Oct 2026: **"combine game visuals of waven and wakfu into this
game"**. What each package borrows:

| From | What to bring into Stasium XII | Where in this spec |
|---|---|---|
| Wakfu | Living painted world: sway loops, critters, water ripples, cloud shadows, day/night and weather | WP5, WP11 |
| Wakfu | Click-to-walk glide, smooth corners, camera that drifts with the walker, soft fades between zones | WP4, WP12, WP13 |
| Wakfu | Zone title card on entry; NPCs that turn to face you | WP2, WP6 |
| Waven | Bold saturated colour, strong key light and rim light, chunky readable silhouettes | WP10, WP11 |
| Waven | Punchy UI: banners, panels and buttons with weight, short pop-in motion | WP2, WP6, WP7 |
| Waven | Big readable landmarks: each dungeon door is a hero prop with glow on hover | WP7, WP10 |
| Dofus | Clean, clickable cells; warm detailed props; every walkable cell reads as walkable | WP5, WP10 |
- Reference frames: `overview/reference_vs_wakfu/` in the Crosshaven handoff
  package, and Mauro's Wakfu clips.

Every package ends with a before/after video or screenshot set (section 6) that
Mauro can judge on a phone screen.

---

## 1. Rules

### 1.1 PC only

- This is the **PC game**. **Never touch the `mobile` branch** (no commits, no
  merges, no APKs, no PRs into it).
- **Never merge into `main` or `mobile`.** Only Mauro merges. Open PRs only when
  Mauro asks, and only into the integration branch named in WP0.
- Copying code *from* the mobile line into PC files is allowed where a package
  says so. Copying never changes the mobile branch.

### 1.2 Branches

| Branch | What it is | Rule |
|---|---|---|
| `cursor/crosshaven-v6-world-2bb7` (PR #214, draft, "do not merge") | Head of the Crosshaven stack #210 → #211 → #212 → #214 | **Do not push to it.** Base only. |
| `claude/pc-zones-spec` | This spec (docs only), based on the #214 head | Docs only |
| `pc/world-zones` (**Proposed** name) | Integration branch for this whole build, created from the #214 head | Every work package merges here by PR, after its tests and video pass |
| `pc/world-zones-wpN-<topic>` | One branch per work package, from `pc/world-zones` | One package per branch |
| `claude/stasium-xii-pc` | Combat glide walk (from `main`, not merged) | Combat feel only; separate from the world |

When Mauro merges #210–#214 into `main`, `pc/world-zones` is rebased onto `main`
by the code agent, on Mauro's word.

### 1.3 Locked: do not change

- The 5 classes, their kits and every combat number and rule (GDD Blueprint,
  `README.md`, `data/select_class_lock_kits_*`).
- The 5 Koliseo maps and their tag files.
- **The Crosshaven kit contract:** tile / prop ids, pixel sizes, anchors and
  footprints in `art/world/crosshaven/atlas_meta.json`. Repaints go in place.
  New ids are only added, never renamed.
- **`stasium.zone` format version 1** (`backend/world_zone.gd`,
  `data/world/crosshaven/schema/zone.schema.json`). Do not add fields to it.
  New data in this spec goes in **sidecar files** (section 4), so the zone
  files and their validator stay as they are.
- The 11 Crosshaven chunk files and their builders. If a chunk really must
  change, regenerate in order (`build_crosshaven_zones.py`, then
  `build_crosshaven_dressing.py`, then `build_crosshaven_density.py`): the
  zone builder wipes the other two passes.
- The Crosshaven walker (`scenes/world/crosshaven/crosshaven_walker.gd`). The
  known quarter-turn facing bug waits on Mauro's go (Open Q7).
- The locked facing rule: **N** = back view walking up-left, **E** = back view
  up-right, **S** = front view down-right, **W** = front view down-left.
- Character art comes from the character handoff and is read-only.
- 2D only. Never 3D.

### 1.4 Proposed: Mauro may change

Zone names (working names), level bands, dungeon names (except the four
existing doors), door spots, NPC names and roles, the level curve, gate spots,
placeholder chunk sizes, file and branch names in this spec.

### 1.5 House rules for every agent

- Each package: its own branch, its tests green, the full suite list in 5.2
  green, the before/after media attached to the PR.
- Every change is recorded in `docs/pc/CHANGE_LOG_PC.md` (what, why, who
  asked, commit) in the same push.
- New backend scripts are loaded with `preload` (no new `class_name`: the
  headless class cache is not rebuilt without an editor import).
- New PNGs need `godot --headless --path . --import` before tests can load them.
- Commit the `.uid` files Godot creates for new scripts.
- Never invent a rule or number for an Open item. Write "Open" and ask.

---

## 2. Team

| Who | Owns |
|---|---|
| **Code** (Cursor cloud agents, coordinated by Stasium Bot) | Data files, backend scripts, scenes, UI, tests, capture scripts |
| **Art** (Scenario) | New painted sprites: region tiles and props, NPC bodies, dungeon doors, monsters. Exact list in WP10 |
| **Technical Artist** | Import settings, atlas entries, the kit rebuild, scale, anchors, y-sort, performance, grade / rim / weather per region |
| **Feel** (combat-feel agent) | World walk and camera on the new zones, zone entry, NPC approach, door entry; the combat glide on `claude/stasium-xii-pc` |

---

## 3. The zone plan (approved to try)

Levels rise outward from the Crossroads. Two zones can share a band so
players can choose a route.

| # | Zone id | Name (working) | Where | Levels | Dungeon door | Door status |
|---|---|---|---|---|---|---|
| 1 | `crosshaven_heart` | Crosshaven Heart | Crossroads + 5 road chunks (`crosshaven_crossroads`, `crosshaven_road_north`, `_west`, `_east`, `_southwest`, `_south`) | 1–5 | Old Granary Cellar | New, Proposed |
| 2 | `crosshaven_towns` | Crosshaven Towns | `crosshaven_northgate`, `_stoneford`, `_eastmarch`, `_westwatch`, `_southbridge` | 5–10 | **Threshgate** | Existing package |
| 3 | `rowanvale` | Rowanvale | West, past Stoneford (farmland) | 10–15 | Rotting Orchard Barrow | New, Proposed |
| 4 | `windmere` | Windmere | North, past Northgate (white city on the cliffs) | 15–20 | **Galevault** | Existing package |
| 5 | `brinewake` | Brinewake | East, past Eastmarch (coast and islands) | 20–25 | **Tidehold** | Existing package |
| 6 | `slagcrown` | Slagcrown | South, past Southbridge (volcanic) | 25–30 | **Ashmarch** | Existing package |
| 7 | `eastmarch_fen_edge` | Eastmarch Fen Edge | Off the east road, the way into the swamp | 25–30 | Sunken Mill | New, Proposed |
| 8 | `gloomfen_mire` | Gloomfen Mire (swamp) | Southeast dark wilds | 30–38 | Drowned Abbey | New, Proposed |
| 9 | `stormspire` | Stormspire | **South of Gloomfen** (Mauro, 3 Oct) | **35–40** | **Coilgate** | Existing package |
| 10 | `ashen_shardfields` | Ashen Shardfields | Southwest dark wilds | 38–45 | Shard Hollow | New, Proposed |
| 11 | `blightwood_hollow` | Blightwood Hollow (dark zone) | Northwest dark wilds | 45–50 | Heart of the Blight | New, Proposed |

The four "existing package" doors use the boss and pack names Mauro approved for
the phone Stasis doors (`backend/stasis_catalog.gd` `DOORS` on the mobile line):
Threshgate (Sheaf Sovereign), Galevault (Serra White-Spire Regent), Tidehold
(Tide-Lord Brineclaw), Ashmarch (Slagheart, Caldera Crown), Coilgate (High
Coilspire). Their HP and damage numbers are provisional on the phone and stay
Open on PC.

Region links (**Proposed**): Rowanvale from Stoneford; Windmere from Northgate;
Brinewake from Eastmarch; Slagcrown from Southbridge; Fen Edge from the east
road; Gloomfen from Fen Edge; Stormspire from Gloomfen's south edge; Ashen
Shardfields from Westwatch and from Slagcrown; Blightwood from Rowanvale and
from Windmere.

---

## 4. Data formats

All new data is **sidecar JSON** next to the Crosshaven data. The `stasium.zone`
v1 files are not changed. Every file below has a JSON Schema under
`data/world/schema/` and a validator test. Unknown keys are errors (same habit
as `WorldZone._unknown`).

### 4.1 World index: `data/world/world_index.json`

Lists every region and where its chunks live. Crosshaven keeps its own
`data/world/crosshaven/index.json` unchanged.

```json
{
  "format": "stasium.world_index",
  "format_version": 1,
  "start_region": "crosshaven",
  "regions": [
    {"region": "crosshaven", "index": "res://data/world/crosshaven/index.json", "status": "built"},
    {"region": "rowanvale", "index": "res://data/world/rowanvale/index.json", "status": "placeholder"}
  ]
}
```

`status` is `built` (final art) or `placeholder` (walkable stand-in). Each new
region has its own `data/world/<region>/index.json` and
`data/world/<region>/zones/*.json` in the **unchanged v1 zone format**, with
`region` set to the region id.

### 4.2 Level zones: `data/world/level_zones.json`

```json
{
  "format": "stasium.level_zones",
  "format_version": 1,
  "status": "proposed",
  "zones": [
    {
      "id": "crosshaven_heart",
      "name": "Crosshaven Heart",
      "level_min": 1,
      "level_max": 5,
      "chunks": ["crosshaven_crossroads", "crosshaven_road_north", "crosshaven_road_west",
                 "crosshaven_road_east", "crosshaven_road_southwest", "crosshaven_road_south"],
      "color": "#3fbf4f",
      "dungeon": "old_granary_cellar"
    }
  ]
}
```

Rules: every chunk id in every region index belongs to exactly one level zone;
`1 <= level_min <= level_max <= 50`; the 11 zones of section 3 are all present;
`gloomfen_mire.level_min >= 30`; `blightwood_hollow.level_min >= 45`;
`stormspire` is 35–40. Colours are the green-to-purple ramp from the map image.

### 4.3 Level curve: `data/world/level_curve.json` (Proposed)

PC gets its own level system, capped at **50** (Open Q3: the phone one stops at
30 and must not change).

```json
{
  "format": "stasium.level_curve",
  "format_version": 1,
  "status": "proposed",
  "max_level": 50,
  "xp_to_next": [100, 300, 580]
}
```

`xp_to_next[i]` is the XP to go from level `i+1` to `i+2`, so it has 49 entries.
Proposed formula: `xp_to_next(L) = round(100 * L^1.6 / 10) * 10` for `L = 1..49`
(level 1 → 2 needs 100 XP, 2 → 3 needs 300, 10 → 11 needs 3,980, 25 → 26
needs 17,250, 49 → 50 needs 50,620; about 979,000 XP in total). The file stores the numbers;
the formula only fills them once. XP sources, rewards and stat points per level
are **Open** (Q3): build only the curve, the level counter and a "level up"
event, with no stat changes.

### 4.4 Gates between regions: `data/world/gates.json`

A gate is a clickable spot (gold arrow, like the chunk exits) that moves the
player to another region. Gates are sidecar data, so Crosshaven chunk files do
not change.

```json
{
  "format": "stasium.world_gates",
  "format_version": 1,
  "gates": [
    {
      "id": "stoneford_to_rowanvale",
      "from": {"zone_id": "crosshaven_stoneford", "x": 1, "y": 16},
      "to": {"zone_id": "rowanvale_meadow", "x": 30, "y": 16},
      "label": "To Rowanvale (10–15)",
      "two_way": true
    }
  ]
}
```

Rules: both cells passable; `from` on a walkable cell next to the chunk edge;
the level band in `label` matches `level_zones.json`; `two_way` gates have a
matching reverse.

### 4.5 NPCs: `data/world/npcs.json`

```json
{
  "format": "stasium.world_npcs",
  "format_version": 1,
  "npcs": [
    {
      "id": "crossroads_guide",
      "name": "Guide",
      "role": "guide",
      "zone_id": "crosshaven_crossroads",
      "cell": {"x": 24, "y": 18},
      "facing": "S",
      "body": "npc_guide",
      "lines": ["Welcome to Crosshaven.", "Click the ground to walk. Gold arrows lead on."],
      "status": "proposed"
    }
  ]
}
```

`role` is one of `warden`, `trader`, `door_keeper`, `guide`, `herald`,
`banker`, `elder`, `smith`, `fisher`, `farmer`, `woodcutter`, `archivist`,
`ferry_captain`, `forge_master`, `fen_guide`, `hermit`, `seer`,
`last_watcher`. In v1 every role only talks (lines of text). Shops, quests,
storage, travel and healing are **Open** (Q4): the dialogue panel shows the
role and a disabled "Coming soon" button for them.

NPC cells block walking (an NPC stands on a passable cell, not on a prop or
gate). `facing` uses the locked N/E/S/W rule.

NPC list (**Proposed**): every level zone has a **Warden** (zone story and level
band), a **Trader** and a **Door Keeper** standing next to its dungeon door.
Extras:

| Zone | Extra NPCs |
|---|---|
| Crosshaven Heart | Guide at the spawn, Koliseo Herald, Banker |
| Crosshaven Towns | One Elder per town (5), Smith in Stoneford, Fisher in Eastmarch |
| Rowanvale | Farmer, Woodcutter |
| Windmere | Spire Archivist |
| Brinewake | Ferry Captain |
| Slagcrown | Forge Master |
| Eastmarch Fen Edge | Fen Guide |
| Gloomfen Mire | Hermit |
| Stormspire | Coil Engineer |
| Ashen Shardfields | Shard Seer |
| Blightwood Hollow | Last Watcher |

That is 33 core NPCs (3 × 11) plus 18 extras: **51 NPCs**.

### 4.6 Dungeon doors: `data/world/dungeons.json`

```json
{
  "format": "stasium.world_dungeons",
  "format_version": 1,
  "dungeons": [
    {
      "id": "threshgate",
      "name": "Threshgate",
      "level_zone": "crosshaven_towns",
      "level_min": 5,
      "level_max": 10,
      "door": {"zone_id": "crosshaven_southbridge", "x": 22, "y": 24},
      "door_art": "door_threshgate",
      "package": "existing",
      "biome": "crosshaven",
      "boss": "Sheaf Sovereign",
      "party": {"min": 1, "max": 4},
      "status": "proposed"
    }
  ]
}
```

Rules: exactly one dungeon per level zone (11); `level_min/max` equal the zone's
band; the door cell is passable, inside a chunk of that zone, not an NPC or gate
cell; `package` is `existing` (one of the five approved doors) or `new`. For
`new`, `boss` is a Proposed name. Door spots in the example are placeholders:
the code agent picks a clear passable cell near the zone's most important
point of interest and lists it in the PR for Mauro.

Dungeon names and one-line ideas (**Proposed**, except the existing five):

| Dungeon | Zone | Idea |
|---|---|---|
| Old Granary Cellar | Crosshaven Heart | Tutorial cellar under the market: rats, scarecrow drudges, small boss |
| **Threshgate** | Crosshaven Towns | Existing: Sheaf Sovereign, Plaza Guard pack |
| Rotting Orchard Barrow | Rowanvale | Barrow under an old orchard: blighted farm beasts, Orchard Warden |
| **Galevault** | Windmere | Existing: Serra White-Spire Regent, Ice Warden pack |
| **Tidehold** | Brinewake | Existing: Tide-Lord Brineclaw, Silt Raider pack |
| **Ashmarch** | Slagcrown | Existing: Slagheart, Cinder Imp pack |
| Sunken Mill | Eastmarch Fen Edge | Flooded watermill: fen crawlers, Millwheel Hag |
| Drowned Abbey | Gloomfen Mire | Half-sunk abbey: bog dead, Mire Abbess |
| **Coilgate** | Stormspire | Existing: High Coilspire, Coil Brute pack |
| Shard Hollow | Ashen Shardfields | Crystal cave: shard golems, Ashen Prism |
| Heart of the Blight | Blightwood Hollow | End-game root maze: blight horrors, the Rotting Elder |

---

## 5. Work packages

Order matters: each package names what it needs first. Packages with no
dependency on each other can run in parallel (marked ∥).

### 5.1 Packages

#### WP0: Integration branch and baseline (Code)

- **Goal:** a clean starting point, and "before" media for everything after.
- **Base:** `cursor/crosshaven-v6-world-2bb7` (head of #214).
- **Do:** create `pc/world-zones`; add `docs/pc/CHANGE_LOG_PC.md`; run the
  #214 suites plus `main`'s suites (5.2); record the before clips with
  `--movie` (all six town tours) and a 20 s free walk from the Crossroads.
- **Files:** `docs/pc/CHANGE_LOG_PC.md` (new), `docs/pc/media/before/`.
- **Accept:** every suite green; the clips play.
- **Media:** "before" world tour, 1920×1080, 30 fps.

#### WP1: Level zones data and loader (Code)

- **Goal:** every chunk knows its level zone and band.
- **Base:** `pc/world-zones`. **Needs:** WP0.
- **Add:** `data/world/level_zones.json`, `data/world/schema/level_zones.schema.json`,
  `backend/world_levels.gd` (preload; `load_default()`, `zone_for_chunk(id)`,
  `band(id)`, `validate()`), `tests/run_world_levels_tests.gd`.
- **Accept:** the rules in 4.2 hold; every Crosshaven chunk resolves to zone 1
  or 2; unknown chunk → empty result, not a crash; swamp ≥ 30, dark zone ≥ 45,
  Stormspire 35–40.
- **Media:** none (data only).

#### WP2: Zone entry banner and level band in the HUD (Code + Feel) ∥ WP3

- **Goal:** walking into a new level zone shows a Wakfu-style title card:
  zone name, level band, a short fade in and out; the HUD corner always shows
  the current zone and band.
- **Change:** `scenes/world/crosshaven/crosshaven_world.gd` (`_show_banner`,
  `_refresh_hud`, `enter_zone` hook only; walking code not touched).
- **Add:** `scenes/world/ui/zone_banner.gd` / `.tscn`.
- **Accept:** test that entering a chunk of another zone emits one banner with
  the right text; re-entering the same zone shows none; the banner never blocks
  clicks.
- **Media:** a clip walking from the Crossroads (1–5) into Northgate (5–10).

#### WP3: Level curve and PC level counter (Code) ∥ WP2

- **Goal:** a PC hero level from 1 to 50 that can be saved, with a level-up
  event. No stats change (Open Q3).
- **Add:** `data/world/level_curve.json` + schema, `backend/pc_progress.gd`
  (preload; `level`, `xp`, `add_xp(n) -> Array[events]`, save/load to
  `user://pc_progress.json`), `tests/run_pc_progress_tests.gd`.
- **Accept:** 49 increasing entries; level never exceeds 50; XP past level 50 is
  kept but does not level; save/load round-trips; the phone level code is not
  imported or changed.
- **Media:** none.

#### WP4: Multi-region map and gates (Code)

- **Goal:** the world loads several regions and gates move the player between
  them with the same fade as chunk exits.
- **Add:** `data/world/world_index.json` + schema, `data/world/gates.json` +
  schema, `backend/world_atlas.gd` (preload; loads every region index through
  the existing `WorldMap.load_index`, resolves gates, `validate()`),
  `tests/run_world_atlas_tests.gd`.
- **Change:** `crosshaven_world.gd`: load through `world_atlas.gd`; a click on a
  gate walks there (existing `walk_to`) and then calls `enter_zone` on the
  target; gate arrows drawn with the existing exit-arrow look.
- **Accept:** every gate's cells are passable; two-way gates pair up; every
  region is reachable from the Crossroads; the Crosshaven tests still pass with
  zero changes to the 11 chunk files.
- **Media:** a clip of Stoneford → gate → Rowanvale placeholder → back.

#### WP5: Placeholder region chunks (Code + Technical Artist)

- **Goal:** every region exists as walkable, good-looking stand-in chunks,
  ready for Scenario art.
- **Needs:** WP4.
- **Add:** per region `data/world/<region>/index.json` and
  `data/world/<region>/zones/<region>_<part>.json` (v1 format), and a builder
  `data/world/<region>/build_<region>_zones.py` modelled on the Crosshaven one.
  Proposed sizes: **2 chunks per region** (an entry chunk 36×32 and a deep
  chunk 40×32 with the dungeon door), 9 regions → 18 chunks.
- **Look rules for stand-ins (Technical Artist):** only existing tile and prop
  ids; a per-region grade (`crosshaven_grade.gdshader` parameters per region,
  e.g. cold blue for Windmere, ember orange for Slagcrown, green fog for
  Gloomfen, violet dark for Blightwood) and per-region weather defaults in the
  sidecar, not in the zone file.
- **Accept:** the zone validator passes every new chunk; connectivity check
  passes; every POI, NPC, gate and door cell is passable; frame time on Full
  stays within 10% of the Crosshaven bench.
- **Media:** a still per region at zoom 1.6 + a 10 s walk.

#### WP6: NPCs (Code + Feel)

- **Goal:** 51 NPCs standing in the world, clickable, with a dialogue panel.
- **Needs:** WP1 (zones), WP5 for NPCs outside Crosshaven.
- **Add:** `data/world/npcs.json` + schema, `scenes/world/npc/world_npc.gd` /
  `.tscn` (sprite, name plate, idle loop, shadow, y-sorted with props using
  `UNIT_Z_BIAS`), `scenes/world/ui/npc_dialogue.gd` / `.tscn`,
  `tests/run_world_npc_tests.gd`.
- **Change:** `crosshaven_world.gd` and `backend/world_walk.gd` (one optional argument): spawn the NPCs of the loaded chunk; make
  NPC cells block the click-to-walk search. `WorldWalk.find_path` has no
  extra-blocked parameter today: add an optional `extra_blocked: Dictionary =
  {}` argument (default keeps every current call and test unchanged) and pass
  the NPC cells from the call site in `walk_to`. The walk rules themselves do
  not change; clicking an NPC
  walks to the nearest free neighbouring cell, faces the NPC, then opens the
  dialogue.
- **Stand-in art until WP10:** the 5 class world sprites in
  `art/characters/world/` with a palette tint per role and a name plate.
  Character art itself is not edited.
- **Feel:** the walker's arrival eases into a stop facing the NPC; the NPC turns
  to face the player (locked facing rule); the dialogue slides in.
- **Accept:** all NPC cells are passable and not on gates or doors; NPCs block
  the path; the dialogue opens only after arrival; Esc / click outside closes.
- **Media:** a clip talking to the Guide at the spawn and to a town Elder.

#### WP7: Dungeon doors in the world (Code)

- **Goal:** 11 doors, one per level zone, with a door panel.
- **Needs:** WP1, WP5.
- **Add:** `data/world/dungeons.json` + schema, `scenes/world/dungeon/dungeon_door.gd`
  / `.tscn` (door prop drawn like a 2×2 landmark, glow when hovered, name and
  band on hover), `scenes/world/ui/door_panel.gd` / `.tscn` (name, level band,
  boss, party size, Enter button), `tests/run_world_dungeons_tests.gd`.
- **Accept:** the rules in 4.6 hold; clicking a door walks to it, faces it and
  opens the panel; the panel's Enter calls a stub
  `DungeonLauncher.enter(dungeon_id)` that shows "Dungeon run: not built yet"
  until WP8 is approved.
- **Media:** a clip opening Threshgate's door panel in Southbridge.

#### WP8: Dungeon runs on PC (Code), **blocked on Open Q2**

- **Goal:** Enter starts the dungeon fight.
- **Proposed approach:** port the Stasis dungeon code from the mobile line into
  new PC files (copy, never change mobile): door packages, rooms A → B, packs,
  bosses, stars. The PC combat engine on `main` is 1v1; party dungeons need the
  team engine from the mobile line. Both need Mauro's yes before any code.
- **Accept (when approved):** each existing package loads its own boss and pack
  names; the six new dungeons have Proposed names and stand-in foes; numbers
  marked Open stay Open.

#### WP9: Visible monsters per zone (Code), **Open Q6**

Dofus- and Wakfu-style worlds show monster groups walking in the zones. Not in
Mauro's list: build nothing until he says yes.

#### WP10: Art for the new zones (Scenario, then Technical Artist)

- **Goal:** replace every stand-in with painted art at the Crosshaven v7 level
  or better, in the Dofus / Wakfu / Waven look.
- **Needs:** Open Q1 (PC art was paused by Mauro on 1 Oct 2026). Do not start
  until Mauro unpauses it.

Style rules (from the Crosshaven kit, `kit_meta/KIT_README.md`):

- 2D isometric diamond, 2:1. Tile top face **64×32 px** at 1x, master **128×64
  px** at 2x (`tiles/_2x/<id>.png`). Height step **10 px**.
- Paint masters at 8x supersampling, then downsample to 2x and 1x. The game
  prefers the 2x masters drawn at scale 0.5.
- Light: one warm key light from the top-left (`#fff0c8`), cool shade
  (`#5a6fa0`), shadow tint `#3b3a66`. SW walls lit, SE walls in shade. Soft
  contact AO only, **no baked cast shadows**.
- Straight (not premultiplied) alpha, no RGB under alpha 0. Linear filter, no
  mipmaps.
- Anchors: tiles bottom-centre on the cell's south tip; props bottom-centre on
  the south tip of the footprint's south-most cell.
- Names: `snake_case`, file name = id; autotiles `<family>_edge_<sides>`,
  `<family>_corner_<c>`; sway strips `<prop>_sway` + `<prop>_shadow_sway`.
- Saturation and contrast: Waven-bold but readable; every walkable cell must
  read as walkable at zoom 1.0.

Asset list per region (**Proposed** counts; 1x and 2x for every item):

| Region | Ground tiles (64×32 / 128×64) | Props and buildings | Paths |
|---|---|---|---|
| Rowanvale | meadow ×4 variants, orchard_soil ×3, autotile edges + corners | 4 tree species + stumps, 3 farmhouses (2×2), barn (3×3), windmill (2×2, sail strip 16 f), hedges ×6, barrow mound (2×2) | `art/world/rowanvale/{tiles,props,animated}/` |
| Windmere | white_flagstone ×4, snow_grass ×3, cliff_white edges | 3 white houses, spire (2×2), walls ×6, frozen pines ×3, Galevault door (2×2) | `art/world/windmere/...` |
| Brinewake | sand ×4, wet_sand ×2, shallow water ripple strips | docks ×6, fishing huts ×3, boats ×2, palms ×3, Tidehold door | `art/world/brinewake/...` |
| Slagcrown | basalt ×4, ash ×3, lava (animated 12 f) | lava vents (animated), charred trees ×3, forge (2×2), Ashmarch door | `art/world/slagcrown/...` |
| Eastmarch Fen Edge | fen_grass ×3, reeds ×2, shallow bog | willows ×2, reed clumps ×4, broken fence ×4, Sunken Mill (3×3, wheel strip) | `art/world/eastmarch_fen_edge/...` |
| Gloomfen Mire | bog ×4, peat ×3, murk water (bubbles 12 f) | dead trees ×4, boardwalk ×6, lily pads, wisps (animated), Drowned Abbey (3×3) | `art/world/gloomfen_mire/...` |
| Stormspire | slate ×4, charged slate (pulse 12 f) | conduits ×4 (match the Koliseo map's look), towers ×2, Coilgate door | `art/world/stormspire/...` |
| Ashen Shardfields | ash_dune ×4, crystal_ground ×2 | crystal spires ×5 (glow strips), ruins ×4, Shard Hollow (2×2) | `art/world/ashen_shardfields/...` |
| Blightwood Hollow | blight_soil ×4, root_ground ×3 | twisted trees ×5, roots ×6, ruined watch walls ×4, spores (animated), Heart of the Blight (3×3) | `art/world/blightwood_hollow/...` |
| Crosshaven (zones 1–2) | none (kit is final) | Old Granary Cellar door (2×2), Threshgate door (2×2); bridges and fords from `tiles/_box_only_not_in_kit/` wired in | `art/world/crosshaven/props/` |

NPC bodies (Scenario): one painted body per role (18 roles), 4 facings (N, E,
S, W under the locked rule), an idle loop of 8 frames at 8 fps per facing, on a
**256×256 px** canvas at 2x with the feet on the bottom-centre pivot, drawn to
match the world character scale (`ironjaw_tall` at 0.33, see PR #214).
Path: `art/characters/npc/<role>/idle_<facing>.png` (horizontal strip).

Monster art for the six new dungeons and for Rowanvale, the fen, the swamp,
the shardfields and Blightwood: only after Open Q2 and Q6.

#### WP11: Technical art pass (Technical Artist)

- **Goal:** the new art in the game looking right and running fast.
- **Do:** add every new id to `atlas_meta.json` (or a per-region
  `art/world/<region>/atlas_meta.json`) with footprint and anchor; import with
  linear filter, no mipmaps; extend `tools/rebuild_godot_kit.sh` per region;
  per-region grade, rim, weather and critters; check y-sort against the walker
  and NPCs; bench every region with the existing `--bench Full` and `--bench
  Minimal`.
- **Accept:** no id missing art; no sprite with RGB under alpha 0; Full within
  10% of the Crosshaven bench; every prop sorts right against the walker
  walking behind and in front.
- **Media:** side-by-side stills, stand-in vs painted, per region.

#### WP12: Feel pass on the world (Feel)

- **Goal:** walking, camera and transitions in the new zones feel like Wakfu:
  smooth glide, camera that drifts with the walker, soft fades at gates, a
  short settle when the walker arrives.
- **Change:** camera and transition code in `crosshaven_world.gd` only. The
  walker script is Locked (Open Q7); the feel agent proposes walker changes to
  Mauro first.
- **Accept:** no camera snap on any gate or chunk exit; zoom 1.0–2.5 stays
  usable; Mauro's judgement on the clip.
- **Media:** a 30 s clip across three zones, before vs after.

#### WP13: Combat glide walk (Feel), separate track

- **Goal:** finish the combat walk on `claude/stasium-xii-pc` (from `main`):
  the glide through corners is done there (not merged, waiting for Mauro);
  next come a forward lean while moving and a cleaner move preview (dotted
  line, target diamond, range outline), from Mauro's reference clip.
- **Rule:** combat only; it does not touch the world walker.

### 5.2 Suites to run before every push

```bash
for f in tests/run_*_tests.gd; do godot --headless --path . -s res://$f; done
```

On the #214 base that is 20 suites, including `run_crosshaven_zone_tests.gd`,
`run_crosshaven_world_tests.gd`, `run_crosshaven_tour_tests.gd` and
`run_visual_settings_tests.gd`. New packages add `run_world_levels_tests.gd`,
`run_pc_progress_tests.gd`, `run_world_atlas_tests.gd`,
`run_world_npc_tests.gd` and `run_world_dungeons_tests.gd`. Godot 4.7.2
headless.

---

## 6. Media for every package

- Record from the game, not mock renders: `godot --path . --fixed-fps 30
  res://scenes/world/crosshaven/crosshaven_world.tscn -- --movie <mode>`
  (extend `_play_movie` with a mode per package), or a capture script under
  `tests/` like the existing tour test.
- 1920×1080 or 960×720, 30 fps, MP4 (H.264), under 25 MB; stills as PNG.
- Always a **before and after** pair from the same camera spot and zoom,
  side by side or one after the other, with a caption saying what changed.
- Put them in `docs/pc/media/<wp>/` and link them in the PR.

---

## 7. Open questions for Mauro

1. **PC art:** is the 1 Oct pause lifted so Scenario can start WP10? Until
   then, every new zone uses stand-in art.
2. **Dungeon runs on PC:** the design doc says dungeons stay on `mobile`. May
   the team port the Stasis dungeon code and the team (party) combat engine
   into PC files (WP8)?
3. **Level system to 50:** where does XP come from (monsters, dungeons,
   Koliseo, quests)? What does a level give (stat points, AP at some level,
   like the phone's 2 points per level and AP at 20)?
4. **NPC jobs:** shops, quests, storage, travel, healing: which first, and with
   which rules? v1 NPCs only talk.
5. **Region size:** 2 chunks per region to start (Proposed), or more?
6. **Monsters in the world:** visible monster groups in each zone (Dofus /
   Wakfu style), or fights only inside dungeons?
7. **Crosshaven walker facing fix** (a quarter-turn off the locked rule): may
   the team fix it now?
8. **Where Eastmarch Fen Edge sits:** off the east road (concept image) or past
   Eastmarch town?
