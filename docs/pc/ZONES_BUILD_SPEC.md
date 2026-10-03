# STASIUM XII (PC): open world zones build spec, levels 1–50

Owner: **Mauro**. Spec written 3 Oct 2026 for the build team (Stasium Bot with
the Cursor cloud coding agents, the Scenario art agent, the Technical Artist
agent and the combat-feel agent). The writer of this spec does not build it.

Status: Mauro approved the zone plan **to try** (3 Oct 2026) and placed
Stormspire (and its dungeon) **south of Gloomfen at 35–40**. Everything else marked
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
| Wakfu | Living painted world: sway loops, critters, water ripples, cloud shadows, day/night and weather | WP5a, WP5b, WP11 |
| Wakfu | Click-to-walk glide, smooth corners, camera that drifts with the walker, soft fades between zones | WP4, WP12, WP13 |
| Wakfu | Zone title card on entry; NPCs that turn to face you | WP2, WP6 |
| Waven | Bold saturated colour, strong key light and rim light, chunky readable silhouettes | WP10, WP11 |
| Waven | Punchy UI: banners, panels and buttons with weight, short pop-in motion | WP2, WP6, WP7 |
| Waven | Big readable landmarks: each dungeon door is a hero prop with glow on hover | WP7, WP10 |
| Dofus | Clean, clickable cells; warm detailed props; every walkable cell reads as walkable | WP5a, WP5b, WP10 |
- Reference frames: `overview/reference_vs_wakfu/` in the Crosshaven handoff
  package, and Mauro's Wakfu clips.
- Quality examples from Mauro (3 Oct 2026, "these are just examples of quality
  of the game"): the level of quality to reach, not designs to copy.
  - https://www.youtube.com/watch?v=AYvoduE4x7k
  - https://www.youtube.com/watch?v=2S_DDtfYd7s (from minute 6)

Every package ends with a before/after video or screenshot set (section 6) that
Mauro can judge on a phone screen.

---

> **Art is unpaused** (Mauro, 3 Oct 2026: "yes they can work on art for the
> map, npcs, bosses, monsters, open world etc"): Scenario can paint the map,
> regions, NPC bodies, bosses and monsters (WP10).
>
> **Still not now: the player fighters** (Mauro, 3 Oct 2026: "dont focus on
> characters yet"): no new art or animation for the 5 playable classes, no
> fighter readability work (L5), no character scale passes, no walk lean /
> gait feel (WP13 beyond the glide that is already built).

> **Focus now** (Mauro, 3 Oct 2026: "focus on map zones lvl dungs and npc with
> missions"): **map zones, levels, dungeons, and NPCs with missions.** Build in
> this order: WP0 → WP1 → WP3 → **WP15 (balance sim)** → WP4 → WP5a → WP6 →
> **WP14 (coins, items, boxes)** → **WP6b (missions)** → WP7 → WP8 (dungeon
> runs) → **WP9 (world monsters)** → WP5b → WP2. Art (WP10) runs alongside.
> The combat look packages (`docs/pc/LOOK_TARGET.md`) come after this track.

## 1. Rules

### 1.1 PC only

**PC is a different game from the mobile one** (Mauro, 3 Oct 2026). PC has its
own look, maps and rules track. The look every PC package aims at is in
`docs/pc/LOOK_TARGET.md` (Wakfu outdoor + Wakfu dungeon + Waven UI and light,
done our own way and better; height levels kept).

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

### 1.4 Soft Lock: approved, change only with Mauro's or Luca's word

Approved by Mauro / Luca on 3 Oct 2026 (answer to Q5). Build to these. If a
package finds a reason to change one, it asks first; it does not decide.

- **Region sizes** (chunk count per region, section 3.1): Rowanvale 6,
  Windmere 6, Brinewake 6, Slagcrown 6, Eastmarch Fen Edge 3, Gloomfen Mire 8,
  Stormspire 5, Ashen Shardfields 7, Blightwood Hollow 8. That's 55 new chunks;
  Crosshaven stays 11, so the world has 66.
- **Chunk roles:** every region has one **entry** chunk, one **door** chunk,
  a **hub** chunk where the region has a town, and **middle** chunks.
- **One landmark prop per chunk.**
- **WP5 split** into WP5a (critical path first) and WP5b (fill).
- **The connectivity tests** in WP4 and WP5a.

### 1.5 Proposed: Mauro may change

Zone names (working names), level bands, dungeon names (except the four
PC dungeons), door spots, NPC names and roles, the level curve, gate spots
and which chunk each gate sits in, chunk sizes within the range in 3.1, which
regions have a hub, the optional `depth` field (4.2), file and branch names in
this spec.

### 1.6 House rules for every agent

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
| 2 | `crosshaven_towns` | Crosshaven Towns | `crosshaven_northgate`, `_stoneford`, `_eastmarch`, `_westwatch`, `_southbridge` | 5–10 | Millrace Vaults | New, Proposed |
| 3 | `rowanvale` | Rowanvale | West, past Stoneford (farmland) | 10–15 | Rotting Orchard Barrow | New, Proposed |
| 4 | `windmere` | Windmere | North, past Northgate (white city on the cliffs) | 15–20 | Frostspire Archive | New, Proposed |
| 5 | `brinewake` | Brinewake | East, past Eastmarch (coast and islands) | 20–25 | Saltmaw Grotto | New, Proposed |
| 6 | `slagcrown` | Slagcrown | South, past Southbridge (volcanic) | 25–30 | Cinderforge Depths | New, Proposed |
| 7 | `eastmarch_fen_edge` | Eastmarch Fen Edge | Off the east road, the way into the swamp | 25–30 | Sunken Mill | New, Proposed |
| 8 | `gloomfen_mire` | Gloomfen Mire (swamp) | Southeast dark wilds | 30–38 | Drowned Abbey | New, Proposed |
| 9 | `stormspire` | Stormspire | **South of Gloomfen** (Mauro, 3 Oct) | **35–40** | Thunderwell Core | New, Proposed |
| 10 | `ashen_shardfields` | Ashen Shardfields | Southwest dark wilds | 38–45 | Shard Hollow | New, Proposed |
| 11 | `blightwood_hollow` | Blightwood Hollow (dark zone) | Northwest dark wilds | 45–50 | Heart of the Blight | New, Proposed |

**PC dungeons are PC's own** (Mauro, 3 Oct 2026: "same concept, different
dungs"). PC uses the same dungeon *concept* as the phone's Stasis doors (rooms,
monster packs, a boss, star difficulty, solo or party), but **all 11 PC
dungeons are new**: none of the phone's doors (Threshgate, Galevault, Tidehold,
Ashmarch, Coilgate) or their bosses and packs are reused on PC. Names below are
Proposed.

Region links (**Proposed**): Rowanvale from Stoneford; Windmere from Northgate;
Brinewake from Eastmarch; Slagcrown from Southbridge; Fen Edge from the east
road; Gloomfen from Fen Edge; Stormspire from Gloomfen's south edge; Ashen
Shardfields from Westwatch and from Slagcrown; Blightwood from Rowanvale and
from Windmere.

### 3.1 Region sizes (**Soft Lock**, Mauro / Luca 3 Oct 2026)

Rule behind the numbers: about one chunk per level of band, at least 3 and at
most 8, plus a hub where the region has a town. A side route gets fewer
chunks; the end-game zone gets more. One of our chunks (about 36×32 cells) is
about 3–4 Dofus screens, so 6 chunks is roughly a 20-map Dofus / Wakfu
sub-area.

| Region | Levels | Chunks | Shape |
|---|---|---|---|
| Rowanvale | 10–15 | **6** | Hamlet hub, farmland middle chunks, door chunk |
| Windmere | 15–20 | **6** | City hub on the cliffs, 4 outer chunks, Frostspire Archive chunk |
| Brinewake | 20–25 | **6** | Port hub, 3 coast chunks, 2 island chunks (linked by the Ferry Captain) |
| Slagcrown | 25–30 | **6** | Forge-camp hub, 4 volcanic chunks, Cinderforge Depths chunk |
| Eastmarch Fen Edge | 25–30 | **3** | Short transition into the swamp, parallel to Slagcrown |
| Gloomfen Mire | 30–38 | **8** | Boardwalk maze; widest band |
| Stormspire | 35–40 | **5** | Compact plateau south of Gloomfen |
| Ashen Shardfields | 38–45 | **7** | Open dunes split by crystal ridges |
| Blightwood Hollow | 45–50 | **8** | End-game; where players stay longest at the cap |
| **Total new** | | **55** | Crosshaven 11 → 66 chunks, about 63,000 new cells (≈5× Crosshaven) |

Chunk roles (**Soft Lock**):

- **Entry:** the chunk the region gate lands in. Exactly one per region.
- **Door:** holds the dungeon door and its Door Keeper. Exactly one per region.
  Proposed: the door chunk is the deepest chunk from the entry.
- **Hub:** where the region has a town (Rowanvale, Windmere, Brinewake,
  Slagcrown): Warden, Trader and the zone's extra NPCs. The hub can be the
  entry chunk.
- **Middle:** the chunks to explore between them.
- **One landmark prop per chunk** (a ruin, a giant tree, a wreck…), so every
  chunk is memorable, Dofus / Wakfu style.

Chunk size (**Proposed**): stay in Crosshaven's range, 24–40 cells wide by
24–36 high (`WorldZone.MAX_CHUNK` is 128).

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

Each zone's `chunks` list names every chunk of its region (66 chunks in all,
section 3.1). Optional (**Proposed**): a `depth` object
(`{"<chunk_id>": 0..7}`, entry = 0) so monster levels can rise inside a region
later; the band stays the zone's band.

Rules: every chunk id in every region index belongs to exactly one level zone;
`1 <= level_min <= level_max <= max_level` (from 4.3); the 11 zones of section 3 are all present;
`gloomfen_mire.level_min >= 30`; `blightwood_hollow.level_min >= 45`;
`stormspire` is 35–40. Colours are the green-to-purple ramp from the map image.

### 4.3 Level curve: `data/world/level_curve.json` (Proposed)

PC gets its own level system. **Phase 1 (these zones) caps at 50. The next
phase (all the other maps) raises the cap to 100** (Mauro, 3 Oct 2026). Build
everything so that raising the cap is a data change, not a code change (see
the "cap rule" below). The phone's level system (cap 30) is separate and must
not change.

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
the formula only fills them once.

**The same formula runs to level 100** for the next phase (75 → 76 needs
100,020; 99 → 100 needs 155,960; about 6.0 million XP from 1 to 100). Because
every XP reward in 4.8 is a share of `xp_to_next(L)`, each level takes about
the same play time at any level, so 50 → 100 adds roughly another 60 hours
(Proposed; the WP15 simulator reports it).

**Cap rule (for every package):** never write `50` in code. Read
`max_level` from `level_curve.json`. Tests check against that value. Data that
depends on the cap (zone bands, mission tiers, set levels, the Koliseo
normalised level) must accept levels up to `max_level`, so the next phase only
adds entries to `xp_to_next`, new zones, sets and tiers.

### 4.11 What a level gives (**approved: option A**, Mauro 3 Oct 2026)

Mauro picked option A ("I like it"), with the rule that the cap goes to 100 in
the next phase. Numbers are **Proposed**.

- **2 characteristic points per level** (98 by level 50; 198 by level 100),
  spent by the player in four stats, the same buckets as the phone game:
  **Mastery** (more damage), **Vitality** (more HP), **Swift** (more
  Initiative, act earlier), **Ward** (more resistance). Per-point values are
  **Proposed** and tuned with WP15 together with the class kits; the kits
  themselves (spell numbers) never change with level.
- **Class HP growth per level** (a small flat HP gain, different per class,
  Proposed).
- **Milestones:** **+1 AP at level 30** (Proposed). The next phase may add a
  second milestone between 51 and 100 (Open, decided with that phase).
- **Titles** at 10, 20, 30, 40, 50 (and every 10 after, up to 100).
- **Respec:** one free reset of the points, then each reset costs Crypto Coins
  (an Elder does it; price Proposed).
- **Koliseo stays fair:** in Koliseo PvP every fighter is treated as
  `max_level` with their own point spend, and set stats are switched off
  (Proposed). Levels and gear matter in the open world and dungeons.

Data: `data/world/level_rewards.json` (format `stasium.level_rewards` v1):
`points_per_level`, `stat_per_point` per bucket, `class_hp_per_level`,
`milestones` (`[{"level": 30, "ap": 1}]`), `titles`, `respec`. Built in WP3
(points and spending UI) and checked by WP15.

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

Gates are **only between regions** (about 12 two-way gates). Links between
chunks inside a region are normal v1 chunk exits in the region's own zone files,
never gates. Each gate names its exact chunk, and a gate into a region always
lands in that region's **entry** chunk. Proposed gate list:

| Gate | From chunk | To (entry chunk of) |
|---|---|---|
| Stoneford ↔ Rowanvale | `crosshaven_stoneford` | Rowanvale |
| Northgate ↔ Windmere | `crosshaven_northgate` | Windmere |
| Eastmarch ↔ Brinewake | `crosshaven_eastmarch` | Brinewake |
| Southbridge ↔ Slagcrown | `crosshaven_southbridge` | Slagcrown |
| East road ↔ Fen Edge | `crosshaven_road_east` | Eastmarch Fen Edge |
| Fen Edge ↔ Gloomfen | Fen Edge (its far chunk) | Gloomfen Mire |
| Gloomfen south ↔ Stormspire | Gloomfen (a south chunk) | Stormspire |
| Westwatch ↔ Ashen Shardfields | `crosshaven_westwatch` | Ashen Shardfields |
| Slagcrown west ↔ Ashen Shardfields | Slagcrown (a west chunk) | Ashen Shardfields |
| Rowanvale north ↔ Blightwood | Rowanvale (a north chunk) | Blightwood Hollow |
| Windmere west ↔ Blightwood | Windmere (a west chunk) | Blightwood Hollow |

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
      "id": "millrace_vaults",
      "name": "Millrace Vaults",
      "level_zone": "crosshaven_towns",
      "level_min": 5,
      "level_max": 10,
      "door": {"zone_id": "crosshaven_southbridge", "x": 22, "y": 24},
      "door_art": "door_millrace_vaults",
      "theme": "watermill_vaults",
      "boss": "The Millwright",
      "rooms": 2,
      "party": {"min": 1, "max": 4},
      "status": "proposed"
    }
  ]
}
```

Rules: exactly one dungeon per level zone (11); `level_min/max` equal the zone's
band; the door cell is passable, inside a chunk of that zone, not an NPC or gate
cell; `theme` names the dungeon's look kit (floor, light, backdrop); `boss` is a
Proposed name; `rooms` is the room count (Proposed: 2, room A packs then room B
boss, like the phone concept; Open for more). No field points at the phone's
door packages. Door spots in the example are placeholders:
the code agent picks a clear passable cell near the zone's most important
point of interest and lists it in the PR for Mauro.

Dungeon names and one-line ideas (all **Proposed**, all PC's own):

| Dungeon | Zone | Idea |
|---|---|---|
| Old Granary Cellar | Crosshaven Heart | Tutorial cellar under the market: rats, scarecrow drudges, small boss |
| Millrace Vaults | Crosshaven Towns | Vaults under Southbridge's watermill: mill bandits and gear golems, The Millwright |
| Rotting Orchard Barrow | Rowanvale | Barrow under an old orchard: blighted farm beasts, Orchard Warden |
| Frostspire Archive | Windmere | Frozen library under the white spire: ice constructs and book wraiths, The Pale Archivist |
| Saltmaw Grotto | Brinewake | Sea cave under the islands: reef crabs and drowned sailors, Old Saltmaw |
| Cinderforge Depths | Slagcrown | Abandoned forge in the volcano: magma imps and slag hounds, The Ember Smith |
| Sunken Mill | Eastmarch Fen Edge | Flooded watermill: fen crawlers, Millwheel Hag |
| Drowned Abbey | Gloomfen Mire | Half-sunk abbey: bog dead, Mire Abbess |
| Thunderwell Core | Stormspire | A glowing circuit core (look reference B): spark constructs, The Storm Engine |
| Shard Hollow | Ashen Shardfields | Crystal cave: shard golems, Ashen Prism |
| Heart of the Blight | Blightwood Hollow | End-game root maze: blight horrors, the Rotting Elder |

### 4.7 Missions: `data/world/missions.json` (Proposed)

NPCs give missions (Mauro, 3 Oct 2026: "npc with missions"). Everything in
this section is **Proposed** except that missions exist.

```json
{
  "format": "stasium.world_missions",
  "format_version": 1,
  "status": "proposed",
  "missions": [
    {
      "id": "heart_welcome",
      "name": "Welcome to Crosshaven",
      "level_zone": "crosshaven_heart",
      "giver": "crossroads_warden",
      "turn_in": "crossroads_warden",
      "min_level": 1,
      "requires": [],
      "steps": [
        {"type": "talk", "npc": "crossroads_trader"},
        {"type": "talk", "npc": "granary_door_keeper"}
      ],
      "reward_xp": 40,
      "lines": {
        "offer": ["New face? Meet the trader and the cellar keeper."],
        "done": ["Good. Now you know who to ask."]
      }
    }
  ]
}
```

Step types in v1:

| Type | Fields | Done when |
|---|---|---|
| `talk` | `npc` | The player opens that NPC's dialogue |
| `reach` | `zone_id` and either `landmark` (a chunk's landmark id) or `cell` | The walker stands on that cell, or next to that landmark |
| `clear_dungeon` | `dungeon` | That dungeon run ends in a win (needs WP8; until then the mission shows as "coming soon" and cannot be taken) |

| `defeat` | `family` (from 4.10), `count`, optional `zone_id` | The player wins fights against that many monsters of that family |

`collect` / `deliver` (needs quest items) stay **Open**.

**Every NPC can give tasks from level 1 to 50** (Mauro, 3 Oct 2026: "each npc
can assign you a task and it can start for lvl 1 and up to lvl 50"; "some
missions are from passing X dung assigned"). So there are two kinds of
mission:

- **Story missions:** the fixed, written ones below (Warden chains and side
  missions), in `missions.json`.
- **NPC tasks:** generated from templates in `data/world/task_templates.json`,
  **scaled to the player's level**, repeatable. Any NPC with a task role offers
  one task at a time; a new one appears after the last is turned in. The target
  is picked from the zones whose band holds the player's level: *defeat N
  monsters of a family there*, *clear that band's dungeon* (the "pass X
  dungeon" missions), or *reach a landmark there*. Rewards come from 4.8 (XP)
  and 4.9 (coins by level tier, items by mission rank).

Every mission (story or task) carries a `rewards` object that the game fills
from 4.8 / 4.9: `{"xp": n, "coins": n, "items": [...]}`.

Mission states, saved with the hero level in `user://pc_progress.json`:
`locked` → `available` → `active` → `ready` (all steps done, go back to the
turn-in NPC) → `done`. A mission is `available` when the hero level ≥
`min_level` and every id in `requires` is `done`.

Mission set (**Proposed**, about 51):

- **Zone chain from each Warden (3 per zone, 33 in all):** (1) *Welcome*: talk
  to the zone's Trader and Door Keeper; (2) *Scout*: reach the landmarks of 2–3
  of the zone's chunks; (3) *The dungeon*: clear the zone's dungeon. Each chain
  needs the previous zone's chain step 2, so the zones open up in level order.
- **One side mission per extra NPC (18):** talk / reach missions that fit the
  NPC (the Fisher sends you to the Eastmarch docks, the Fen Guide walks you to
  the swamp gate, the Last Watcher sends you to Blightwood's deepest chunk…).

XP rewards (**Proposed**, from the level curve in 4.3, using the zone's
`level_min`): `talk`-only missions 15% of `xp_to_next(level_min)`, `reach`
missions 25%, dungeon missions 60%. The file stores the numbers; the rule only
fills them once.

Rules: every `giver`, `turn_in` and `npc` exists in `npcs.json`; every
`zone_id`, `landmark` and `dungeon` exists; `requires` has no cycles; every
mission can be finished from the start of the game (a test walks the chain).

### 4.8 Progression: XP sources and balance (Mauro's rules + Proposed numbers)

Mauro, 3 Oct 2026, the rules (these are **his**, build them as given):

- XP comes from **levelling in the open world** (fighting world monsters),
  from **missions**, and from **dungeons**.
- **Dungeons give more XP than levelling in the open world.**
- Missions run **from level 1 to 50**; as you level up and advance in missions
  you get **better rewards**.
- "Make all this possible and the best balanced way possible."

Balance targets (**Proposed**, checked by the WP15 simulator):

| Target | Value |
|---|---|
| Time from level 1 to 50 for a normal player mix | about **60 hours** (accept 50–75) |
| Dungeon XP per minute vs open-world XP per minute | **about 1.5×** (accept 1.3–1.8×) |
| Share of total XP by source (normal mix) | open world ~43%, dungeons ~40%, missions ~17%; no source above 50% |
| A player who only fights in the open world | still reaches 50, about 1.5× slower |

Formulas (**Proposed**; all read `xp_to_next(L)` from 4.3; `L` = the monster
group's or dungeon's level):

| Source | XP |
|---|---|
| Open-world fight (one monster group, about 3 min) | `3.5% × xp_to_next(L)` |
| Dungeon run, win (room A + room B, about 15 min) | `27% × xp_to_next(L) × star` with star ★1 1.0, ★2 1.2, ★3 1.45, ★4 1.7, ★5 2.0 |
| Mission | talk / reach: `6%`; defeat monsters: `10%`; clear a dungeon: `30%` of `xp_to_next(player level)` |

Level gap (stops farming far below your level, Proposed): group 6–9 levels
below the player ×0.5, 10+ below ×0.1; above the player +5% per level, up to
+25%. Party (each member's share, Proposed): 1 player ×1.0, 2 ×0.85 each,
3 ×0.75, 4 ×0.7 (party fights are faster and safer).

What a level gives (stats, points, AP) stays **Open** (Q3b).

### 4.9 Crypto Coins, set parts and Mystery Boxes (Mauro's names + Proposed numbers)

Mauro, 3 Oct 2026: the money is **Crypto Coins**. **It is only the name of the
in-game money** (Mauro: "just the name of coin, not planning on putting real
crypto in the game"): no real cryptocurrency, blockchain, wallets or real-money
trading. Never connect it to anything outside the game.

Also from Mauro: mission rewards include
**parts of sets** (regular), and as you advance in missions you can get **rare
parts** or **Mystery Boxes**.

`data/world/rewards.json` (format `stasium.world_rewards` v1) holds every table
below.

**Crypto Coins** (Proposed): open-world fight `3 + 1.5 × L`; dungeon win
`8 ×` that at the dungeon's level × star; missions by level tier: T1 (1–10)
20–40, T2 (11–20) 60–100, T3 (21–30) 150–250, T4 (31–40) 300–500, T5 (41–50)
600–1,000. What coins buy: section 4.12.

**Sets: option A approved** (Mauro, 3 Oct 2026). Parts give stats and sets give
bonuses. Mauro: "in the PC game we are going to build more sets depending on
how we develop the classes, but for now we start with a few, only for
Crosshaven, and next phase we add more."

- **5 slots** (head, cape, belt, boots, amulet; Proposed). A full set fills all
  5, so the choice is one full set (its 5-part bonus) or a 3 + 2 mix (two
  smaller bonuses).
- **Each part gives 1–2 stats** from the four buckets in 4.11 (Mastery,
  Vitality, Swift, Ward). **Rare** = about 1.5× the Regular stats plus one
  extra stat (Proposed).
- **Set bonuses:** 2 parts a small stat bonus, 3 parts a bigger one, 5 parts a
  special bonus (Proposed values; tuned with WP15 and the class kits).
- **Upgrades +1 to +5** with Crypto Coins (and spare parts at +4 / +5), each
  step about +10% of the part's stats (Proposed).
- **Item level:** a part's stats scale with its **item level** = the level of
  the fight, dungeon or mission that gave it (Proposed). You can wear a part
  when your level ≥ its item level. This is how a few sets stay useful from
  level 1 to 50.

**Phase 1 sets: only Crosshaven, 3 sets** (Proposed names and themes):

| Set | Theme | Where it drops | 5-part bonus (Proposed) |
|---|---|---|---|
| Wayfarer | Travelling clothes of the Crossroads | Crosshaven Heart: world fights, Old Granary Cellar, Heart missions | +1 MP on the first turn of a fight |
| Townguard | Armour of the five town watches | Crosshaven Towns: world fights, town missions | Extra Ward when standing next to an ally |
| Millwright | Work gear from the vaults under the mill | Millrace Vaults dungeon only | Extra Mastery on the turn after you are hit |

**Mauro approved these three 5-part bonuses** (3 Oct 2026). They are combat
effects, so they are built only through CombatSim, and off in Koliseo PvP
(set stats are off there).

**Class sets: one balanced set for every class** (Mauro, 3 Oct 2026: "you will
need to create a balanced set for every single class"). Phase 1 adds **5 class
sets**, one per class, on top of the 3 shared sets (8 sets in all). Names,
stats and effects are **Proposed** for Mauro to approve; the numbers are tuned
by WP15.

| Class (role) | Set (Proposed) | Part stats lean to | 2 parts | 3 parts | 5 parts (effect) |
|---|---|---|---|---|---|
| Kestrel (ranged carry, Air) | **Skyfeather** | Mastery, Swift | + Mastery | + Swift | **+1 max range on Mark Shot** |
| Ironjaw (melee bruiser, Earth) | **Quarrybreaker** | Mastery, Vitality | + Vitality | + Mastery | **Start every fight with +1 Impact** |
| Mender (healer, Water) | **Tidewell** | Vitality, Ward | + Ward | + Vitality | **Mend heals 10% more** |
| Gloam (stealth assassin) | **Duskveil** | Mastery, Swift | + Swift | + Mastery | **+1 MP on turns you start Invisible** |
| Bastion (tank) | **Bulwark** | Vitality, Ward | + Vitality | + Ward | **The first hit you take in each fight deals half damage** |

Class set rules (Proposed):

- A class set part can be worn only by its class. Class set parts drop from
  the two Crosshaven dungeons (Old Granary Cellar, Millrace Vaults) and from
  class missions given by the town Elders; a drop picks the player's own class
  60% of the time, so parts for alt classes and for the marketplace still
  appear.
- The same 5 slots: a player picks between the class set, a shared set, or a
  3 + 2 mix.
- Next phase adds class sets as classes develop (Mauro: "we are going to build
  more sets depending how we develop the classes").

**How sets are kept balanced** (Proposed rules; WP15 checks them):

1. **Equal budget.** At the same item level every part of every set has the
   same stat budget (Proposed: `4 + item level` points, priced with the
   per-point values in 4.11). A Rare part = 1.5× the budget + 1 extra stat. A
   2-part bonus = the budget of 1 part; a 3-part bonus = 1.5 parts.
2. **5-part effects are worth about 2 parts.** Each effect is measured in the
   simulator as damage, healing or damage prevented per fight, and tuned until
   it lands near the value of 2 parts' stats.
3. **Class sets fit, they don't dominate.** For its own class, the class set
   beats the best shared set by at most 10% in the simulator.
4. **Classes stay even.** With their best phase 1 set, all five classes clear
   the same dungeon (solo, same level) within ±10% of each other's time.
5. **No single effect above 15%.** No 5-part effect alone raises a class's
   damage, healing or survival by more than 15%.
6. **PvP is untouched.** Set stats and effects are off in Koliseo PvP (4.11),
   so the Locked kit balance there does not change.

**Zones 3–11 in phase 1** have no set of their own yet: their fights,
dungeons and missions drop **the Crosshaven sets at a higher item level**
(Wayfarer and Townguard from world fights and missions; Millwright from
dungeons), plus coins and Mystery Boxes. **Next phase** adds sets per region
and sets built around the classes; `rewards.json` lists sets as data, with an
optional `classes` field for class sets later, so adding them needs no code
change.

**Mystery Box** (Proposed contents, one roll): 50% coins (5× the mission coins
of the opener's tier), 35% a Regular part, 15% a Rare part, from a set at or
below the opener's level.

Drops (Proposed):

| Source | Regular part | Rare part | Mystery Box |
|---|---|---|---|
| Open-world fight | 3% (phase 1: Wayfarer or Townguard, at the fight's item level) | — | — |
| Dungeon win | 1 guaranteed (phase 1: Millwright from Millrace Vaults; Wayfarer / Townguard / Millwright at the dungeon's item level elsewhere) | ★1 0%, ★2 5%, ★3 10%, ★4 20%, ★5 35% | ★4+ 10% |
| Mission, by **mission rank** (below) | rank 1 20%, 2 35%, 3 40%, 4 40%, 5 35% | rank 1–2 0%, 3 5%, 4 10%, 5 15% | rank 1 0%, 2 3%, 3 8%, 4 12%, 5 20% |
| Every 10th mission turned in | — | — | **1 guaranteed** |

**Mission rank** = how many missions the player has finished: rank 1 (0–9),
2 (10–24), 3 (25–49), 4 (50–99), 5 (100+). This is how "advancing in missions
gives better rewards" works, on top of the level tier.

### 4.12 Economy: what Crypto Coins buy, marketplace, crafting, houses (Mauro's direction + Proposed plan)

Mauro, 3 Oct 2026: **"the idea is to put a marketplace where players can trade
or buy pieces; also money will be used to craft, buy houses, buy food,
potions, decorations, buy recipes, food supplies, minerals, etc."**

Coin uses (Mauro's list, plus the ones already proposed):

| Use | Where | What it is |
|---|---|---|
| **Marketplace** | A market board in each hub (Crossroads first) | Players list set parts and goods for a price; other players buy them. Rare parts can be sold here (NPC shops still never sell Rare parts or Mystery Boxes). |
| **Crafting** | Workbenches (forge, kitchen, alchemy table) | Turn resources into food, potions, decorations and gear upgrades; each craft costs coins plus materials |
| **Recipes** | Traders and craft NPCs; some from missions and dungeons | A recipe unlocks a craft; bought once with coins |
| **Houses** | Plots in the towns | Buy a house, then decorate it |
| **Decorations** | Traders, crafting | Furniture and ornaments for your house |
| **Food and potions** | Traders, kitchen, alchemy | Heal between open-world fights; short buffs (Proposed) |
| **Food supplies and minerals** | Traders, farms, mines | Raw materials for crafting; also gathered in the world |
| **Part upgrades +1 to +5** | Smith (Stoneford), Forge Master (Slagcrown) | Already in 4.9 |
| **Crypto Bank** | **One bank only, in the main city: the Crossroads** (Mauro, Q10), run by the Banker | Mauro, 3 Oct: "we should create a Crypto bank, players can deposit their money there". Deposit and withdraw Crypto Coins, and **store any item**: set parts, materials, food, potions, recipes, decorations and other objects (Mauro: "in the bank you have the option to save parts of sets, materials, objects"). In-game only, like the coins. |
| **Fast travel, respec, bank space, cosmetics** | Hub posts, Elders, Banker, Traders | Already proposed |

How it fits together (**Proposed**):

- **Crypto Bank** (Mauro's idea; details Proposed): two balances, **coins on
  hand** (the wallet) and **coins in the bank**. Shops, crafting and travel
  pay from coins on hand; houses, the marketplace and big upgrades can pay
  straight from the bank. Marketplace sales are paid into the bank. Coins in
  the bank are safe: if a later rule makes players lose coins (for example on
  defeat), only coins on hand are at risk. **No interest** and **one bank only,
  in the main city (the Crossroads)** (Mauro, Q10). **Bank item
  storage holds every kind of item** (set parts, materials, food, potions,
  recipes, decorations, objects); stacks for materials and consumables
  (Proposed: up to 999 per slot); starts with 20 slots, more bought with coins.
- **Resources come from the world.** Crosshaven already has harvestable trees
  (six species with stump states) and eight crop types on its farms. Add
  **mineral nodes** (rocks and ore veins) per region. Gathering: click a node,
  the walker goes there, a short gather action, the node turns to its spent
  state (stump, picked field, broken rock) and respawns later.
- **Crafting** = recipe + materials + coins → item, at the right workbench.
  Craft categories in order: food, potions, decorations, upgrade materials.
  Crafting levels (a gathering / crafting skill per profession) are **Open**.
- **Marketplace** = player listings with a price in Crypto Coins and a small
  **sale tax** (Proposed 5%, a coin sink). Listings expire after a few days.
  It must run on a server (to stop duplicated items), and **online servers
  wait until the map is fully developed** (Mauro, Q9).
- **Houses** = a plot in a town bought with coins, an interior room, and
  placed decorations. Housing needs its own scene and saved layouts: a later
  phase (Proposed).
- **Balance:** the WP15 simulator tracks coins in (fights, dungeons,
  missions, market sales) and coins out (crafts, recipes, houses, upgrades,
  travel, tax). Target (Proposed): over time players spend 70–90% of what they
  earn, so prices stay stable.

Build order (**Proposed**, for Mauro to confirm in Q9):

1. **Now (phase 1):** NPC shops (food, potions, supplies, minerals, recipes,
   decorations as items), gathering in Crosshaven (trees, crops, a few mineral
   nodes), crafting food and potions, upgrades, respec, fast travel.
2. **After the map is fully developed, with the online server:** the
   marketplace (Mauro, Q9).
3. **Next:** houses and decorating, more professions and recipes.

### 4.10 World monsters: `data/world/monsters.json` (Mauro's rules + Proposed numbers)

Mauro, 3 Oct 2026, the rules: **monsters walk around the world, but only in
their designated zones**; **monsters above level 25 are aggressive**: they
attack players.

```json
{
  "format": "stasium.world_monsters",
  "format_version": 1,
  "families": [
    {
      "id": "gloomfen_bog_lurker",
      "name": "Bog Lurker",
      "level_zone": "gloomfen_mire",
      "level_min": 30,
      "level_max": 36,
      "group_size": [2, 4],
      "chunks": ["gloomfen_mire_entry", "gloomfen_mire_reedmaze"],
      "art": "bog_lurker",
      "status": "proposed"
    }
  ]
}
```

Rules:

- **Designated zone:** a family spawns and walks only on passable cells of the
  `chunks` it lists, all inside its `level_zone`. It never crosses a chunk exit
  or a gate, and never enters a hub chunk, the Crosshaven town chunks, or the
  cells within 2 of an NPC, a gate or a dungeon door (safe cells, Proposed).
- **Levels:** within the zone's band; deeper chunks (4.2 `depth`) get the
  higher levels (Proposed).
- **Aggressive above 25 (Mauro's rule):** a group whose level is **26 or more**
  is aggressive. When a player comes within **3 cells** (Proposed) and can be
  reached on foot, the group walks to the player and the fight starts. Groups at
  25 or below are passive: the player clicks them to fight.
- Fairness (Proposed): no aggro on safe cells; 10 s of grace after a fight, a
  zone change or a respawn; one aggro at a time per player.
- **Groups per chunk** 3–6 and **respawn** after 90 s, away from players
  (Proposed).
- A world fight uses the PC combat engine (with the team engine from WP8 for
  groups and parties) on the **region's combat board** (Proposed for v1; a
  board cut from the world chunk is a later step). Win → XP, coins and drops
  (4.8, 4.9); loss → the player returns to the zone's entry chunk (Proposed).
- About 3–4 families per level zone (Proposed), with names and art by
  Scenario; each zone's dungeon boss is not a world monster.

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

- **Goal:** a PC hero level from 1 to `max_level` (50 now, 100 next phase)
  that can be saved, with a level-up event, characteristic points and their
  spending (4.11).
- **Add:** `data/world/level_curve.json` + schema,
  `data/world/level_rewards.json` + schema, `backend/pc_progress.gd`
  (preload; `level`, `xp`, `add_xp(n) -> Array[events]`, `points_free`,
  `spend(bucket, n)`, `respec()`, save/load to `user://pc_progress.json`),
  `scenes/world/ui/character_sheet.gd` / `.tscn` (level, XP bar, the four
  stats and + buttons; **C** key, Proposed), `tests/run_pc_progress_tests.gd`.
- **Accept:** `max_level - 1` increasing entries; level never exceeds
  `max_level`; XP past the cap is kept but does not level; points = 2 ×
  (level − 1) minus spent; +1 AP flag from level 30; respec returns every
  point; **a test re-runs with a 100-level curve** and passes with no code
  change (the cap rule); save/load round-trips; the phone level code is not
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
  region is reachable from the Crossroads; gates only join different regions;
  every gate into a region lands in that region's entry chunk, and each region
  has exactly one entry chunk; every chunk in every region index is in exactly
  one level zone (66 chunks once WP5b is done); the Crosshaven tests still pass
  with zero changes to the 11 chunk files.
- **Data note:** the formats do not change for the larger regions.
  `world_index.json` still lists 9 new regions; each region's `index.json`
  simply lists more chunks.
- **Media:** a clip of Stoneford → gate → Rowanvale placeholder → back.

#### WP5a: Region layouts and the critical path (Code + Technical Artist)

- **Goal:** every region's full chunk graph is designed now, and its critical
  path is built and walkable first: **entry → (hub) → door**. The whole world
  can be crossed early, and the links never get redrawn later.
- **Needs:** WP4.
- **Add, per region:**
  - `data/world/<region>/build_<region>_zones.py`, modelled on the Crosshaven
    builder. At its top, a small text map of the region's **full** chunk graph
    (all chunks of section 3.1, their roles, sizes and the edge exits between
    them), so WP5b only fills chunks in.
  - `data/world/<region>/index.json` listing the critical-path chunks.
  - `data/world/<region>/zones/<region>_<part>.json` (v1 format) for the entry
    chunk, the door chunk and the hub where there is one. Chunk ids:
    `<region>_entry`, `<region>_door`, `<region>_hub`, `<region>_<name>` for
    middle chunks.
- **Landmark:** each built chunk gets its one landmark prop (stand-in: the
  biggest existing prop that fits, until WP10 art).
- **Look rules for stand-ins (Technical Artist):** only existing tile and prop
  ids; a per-region grade (`crosshaven_grade.gdshader` parameters per region,
  e.g. cold blue for Windmere, ember orange for Slagcrown, green fog for
  Gloomfen, violet dark for Blightwood) and per-region weather defaults in the
  sidecar, not in the zone file.
- **Accept:**
  - The zone validator passes every new chunk.
  - Every POI, NPC, gate and door cell is passable.
  - **Connectivity:** each region's door chunk is reachable on foot from its
    entry chunk; every built chunk is reachable from the region's entry; each
    region has exactly one entry chunk and one door chunk.
  - The builder's text map has the section 3.1 chunk count for its region.
  - Frame time on Full stays within 10% of the Crosshaven bench (the game loads
    one chunk at a time, so chunk count does not change frame time; bench once
    per region).
- **Media:** a still per region at zoom 1.6 and a walk from the region gate to
  the dungeon door.

#### WP5b: Fill the regions (Code + Technical Artist)

- **Goal:** build the remaining middle chunks so every region has its full
  section 3.1 count (55 new chunks in all).
- **Needs:** WP5a for that region. Regions can be filled in parallel.
- **Add:** the middle chunk files from the WP5a text map, added to the region's
  `index.json` and to its level zone's `chunks` list.
- **Accept:** everything in WP5a, plus: the region has exactly its section 3.1
  chunk count; every chunk is reachable from the entry; every chunk has one
  landmark; `level_zones.json` covers all 66 chunks.
- **Media:** a 30 s walk through each region's middle chunks.

#### WP6: NPCs (Code + Feel)

- **Goal:** 51 NPCs standing in the world, clickable, with a dialogue panel.
- **Needs:** WP1 (zones), WP5a for NPCs outside Crosshaven (WP5b for NPCs in middle chunks).
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

#### WP6b: NPC missions (Code)

- **Goal:** NPCs give missions; the player takes them, does the steps, turns
  them in and gets XP.
- **Needs:** WP3 (levels), WP6 (NPCs). `clear_dungeon` steps light up when WP8
  lands.
- **Add:** `data/world/missions.json` + schema; `backend/pc_missions.gd`
  (preload; pure logic: `available_for(npc_id, progress)`, `accept`,
  `on_talk(npc_id)`, `on_reach(zone_id, cell)`, `on_dungeon_won(id)`,
  `turn_in` → XP through `pc_progress.gd`; no scene code, so a server can run it
  later); `scenes/world/ui/mission_tracker.gd` / `.tscn` (the active missions
  and their next step, top-right); `scenes/world/ui/mission_log.gd` / `.tscn`
  (all missions by zone, opened with **J**, Proposed); `tests/run_pc_missions_tests.gd`.
- **Change:** `npc_dialogue.gd` gets **Accept** and **Turn in** buttons and the
  offer / done lines; `world_npc.gd` shows a mark over the NPC's head: **!** (a
  mission to take) and **?** (a mission to turn in), Dofus / Wakfu style;
  `crosshaven_world.gd` calls `on_reach` when the walker arrives and
  `on_talk` when a dialogue opens.
- **Accept:** every rule in 4.7 holds; a test plays the Crosshaven Heart chain
  from level 1 (talk → talk → turn in → XP → level up event); missions above
  the hero level stay `locked`; progress survives save / load; turning in twice
  gives XP once.
- **Media:** a clip taking *Welcome to Crosshaven* from the Warden, talking to
  the Trader and the Door Keeper, and turning it in (XP and level up shown).

#### WP7: Dungeon doors in the world (Code)

- **Goal:** 11 doors, one per level zone, with a door panel.
- **Needs:** WP1, WP5a (door chunks).
- **Add:** `data/world/dungeons.json` + schema, `scenes/world/dungeon/dungeon_door.gd`
  / `.tscn` (door prop drawn like a 2×2 landmark, glow when hovered, name and
  band on hover), `scenes/world/ui/door_panel.gd` / `.tscn` (name, level band,
  boss, party size, Enter button), `tests/run_world_dungeons_tests.gd`.
- **Accept:** the rules in 4.6 hold; clicking a door walks to it, faces it and
  opens the panel; the panel's Enter calls a stub
  `DungeonLauncher.enter(dungeon_id)` that shows "Dungeon run: not built yet"
  until WP8 is approved.
- **Media:** a clip opening the Millrace Vaults door panel in Southbridge.
- **Focus:** dungeons are one of Mauro's four focus items (3 Oct). WP8 is
  approved (same concept as the phone, PC's own dungeons).

#### WP8: Dungeon runs on PC (Code), **approved: same concept, different dungeons**

Mauro, 3 Oct 2026: **"yes, same concept, different dungs"** (answer to Q2).

- **Goal:** Enter starts the dungeon fight: room A (monster packs) then room B
  (boss), solo or with a party, with star difficulty.
- **Approach:** port the **concept and engine** of the phone's Stasis dungeons
  and its team (party) combat into **new PC files**, by copying from the mobile
  line; never change `mobile`. Proposed PC files: `backend/pc_dungeons.gd`
  (runs, rooms, packs, stars), `backend/pc_dungeon_catalog.gd` (the 11 PC
  dungeons from `data/world/dungeons.json`), the team engine pieces copied into
  PC combat, `scenes/world/dungeon/dungeon_run.gd` / `.tscn`.
- **Different dungeons:** the PC catalog holds only the 11 PC dungeons in 4.6.
  Do not copy the phone's door packages (names, bosses, packs, numbers).
- **Foes:** stand-in sprites from the existing foe art until monster art is
  approved (characters are parked). Monster HP / damage numbers and star
  scaling for PC are **Open**: propose them in the PR, don't invent them as
  final.
- **Accept:** each of the 11 dungeons loads its own Proposed boss and pack
  names; a level 1 hero can enter and finish Old Granary Cellar solo; a party
  of up to 4 can enter a door that allows it; a win fires
  `pc_missions.on_dungeon_won(id)`; the phone files and branch are untouched;
  all suites green.
- **Media:** a clip entering Old Granary Cellar from its door, room A, room B,
  win, mission step done.

#### WP9: World monsters and aggro (Code + Feel), **approved**

Mauro, 3 Oct 2026: "monster can walk around the world but only in their
designated zones also monsters above lvl 25 are agressive".

- **Goal:** monster groups walk in their zones; passive ones fight when clicked;
  groups above level 25 hunt players who come close; a fight gives XP, coins
  and drops.
- **Needs:** WP3, WP5a, WP8 (combat engine with teams), WP14.
- **Add:** `data/world/monsters.json` + schema; `backend/world_monsters.gd`
  (preload; spawn, wander inside the allowed cells, aggro check, respawn; pure
  logic so a server can run it later); `scenes/world/monster/world_monster_group.gd`
  / `.tscn` (the group's sprites, level plate, an aggressive marker);
  `tests/run_world_monsters_tests.gd`.
- **Change:** `crosshaven_world.gd`: spawn the loaded chunk's groups, start a
  fight on click or aggro, return to the world after it.
- **Accept:** a group never stands on a cell outside its `chunks`, on a safe
  cell, or across an exit (10,000-step wander test); level ≤ 25 never starts a
  fight by itself; level ≥ 26 starts one when a player is within 3 reachable
  cells and not on a safe cell, and not during grace; respawn waits 90 s and
  happens away from players; win rewards match 4.8 / 4.9.
- **Media:** a clip of a passive group in Rowanvale (clicked) and an
  aggressive group in Gloomfen charging the player.

#### WP14: Crypto Coins, set parts and Mystery Boxes (Code)

- **Goal:** the rewards exist: a coin wallet, set parts (Regular / Rare) in an
  inventory, Mystery Boxes that open, and the drop rolls from 4.9.
- **Needs:** WP3.
- **Add:** `data/world/rewards.json` + schema (coins, sets, drop tables, box
  contents, mission ranks); `backend/pc_rewards.gd` (preload; `roll(source,
  context, rng)` → coins and items; `open_box(rng)`; seeded rolls for tests);
  wallet and inventory saved in `user://pc_progress.json` via `pc_progress.gd`;
  `scenes/world/ui/inventory_panel.gd` / `.tscn` (coins, parts by set, boxes,
  an Open button; **I** key, Proposed); a "reward" pop-up after fights,
  dungeons and missions; `tests/run_pc_rewards_tests.gd`.
- **Accept:** every drop table sums to ≤ 100%; seeded rolls give fixed results;
  a Mystery Box always gives exactly one thing; the 10th mission always gives a
  box; part stats and 2 / 3-part set bonuses apply through `pc_progress.gd` (stats only; 5-part effects wait on Mauro's yes); item level gates who can wear a part; save / load keeps coins and items.
- **Media:** a clip winning a fight, the reward pop-up, then opening a Mystery
  Box from the inventory.

#### WP15: Balance simulator (Code)

- **Goal:** prove the numbers in 4.3, 4.8 and 4.9 are balanced before anyone
  plays them, and re-check them on every change.
- **Needs:** WP3; reads `level_curve.json`, `rewards.json`, `level_zones.json`.
- **Add:** `tests/sim_pc_progression.gd` (dev tool, not a suite): simulates
  player profiles (normal mix 50% world / 30% dungeons / 20% missions; world
  only; dungeon heavy; party of 4) from level 1 to 50 with seeded rolls and
  prints hours to 50, XP share by source, coins per hour per tier, parts and
  rare parts per hour, boxes per hour; `tests/run_pc_balance_tests.gd` (suite)
  that fails when a target in 4.8 is missed.
- **Accept:** normal mix reaches 50 in 50–75 h; dungeon XP per minute is
  1.3–1.8× open world; no source above 50% of total XP; world-only still
  reaches 50; a printed table goes in the PR for Mauro.
- **Sets:** also simulate each class with no set, each shared set and its class
  set; fail when a 4.9 balance rule (1–6) is broken; print the per-class table
  for Mauro.
- **Media:** none (the printed table).

#### WP10: Art for the new zones (Scenario, then Technical Artist)

- **Goal:** replace every stand-in with painted art at the Crosshaven v7 level
  or better, in the Dofus / Wakfu / Waven look.
- **Unpaused** by Mauro, 3 Oct 2026, for the map, open world, NPCs, bosses and
  monsters. Player fighters stay parked.

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
| Windmere | white_flagstone ×4, snow_grass ×3, cliff_white edges | 3 white houses, spire (2×2), walls ×6, frozen pines ×3, Frostspire Archive door (2×2) | `art/world/windmere/...` |
| Brinewake | sand ×4, wet_sand ×2, shallow water ripple strips | docks ×6, fishing huts ×3, boats ×2, palms ×3, Saltmaw Grotto door | `art/world/brinewake/...` |
| Slagcrown | basalt ×4, ash ×3, lava (animated 12 f) | lava vents (animated), charred trees ×3, forge (2×2), Cinderforge Depths door | `art/world/slagcrown/...` |
| Eastmarch Fen Edge | fen_grass ×3, reeds ×2, shallow bog | willows ×2, reed clumps ×4, broken fence ×4, Sunken Mill (3×3, wheel strip) | `art/world/eastmarch_fen_edge/...` |
| Gloomfen Mire | bog ×4, peat ×3, murk water (bubbles 12 f) | dead trees ×4, boardwalk ×6, lily pads, wisps (animated), Drowned Abbey (3×3) | `art/world/gloomfen_mire/...` |
| Stormspire | slate ×4, charged slate (pulse 12 f) | conduits ×4 (match the Koliseo map's look), towers ×2, Thunderwell Core door | `art/world/stormspire/...` |
| Ashen Shardfields | ash_dune ×4, crystal_ground ×2 | crystal spires ×5 (glow strips), ruins ×4, Shard Hollow (2×2) | `art/world/ashen_shardfields/...` |
| Blightwood Hollow | blight_soil ×4, root_ground ×3 | twisted trees ×5, roots ×6, ruined watch walls ×4, spores (animated), Heart of the Blight (3×3) | `art/world/blightwood_hollow/...` |
| Crosshaven (zones 1–2) | none (kit is final) | Old Granary Cellar door (2×2), Millrace Vaults door (2×2); bridges and fords from `tiles/_box_only_not_in_kit/` wired in | `art/world/crosshaven/props/` |

Landmarks (Scenario, **Soft Lock**: one per chunk): one hero prop per new
chunk, 55 in all, in the region's style (2×2 or 3×3 footprint, sway or glow
strip where it fits). Path `art/world/<region>/props/landmark_<chunk_id>.png`
(+ `_2x/`). The region kits above are shared by all chunks of a region, so the
kit list does not grow with the chunk count; the landmarks are the main
addition.

NPC bodies (Scenario, **unpaused** 3 Oct): one painted body per role (18 roles), 4 facings (N, E,
S, W under the locked rule), an idle loop of 8 frames at 8 fps per facing, on a
**256×256 px** canvas at 2x with the feet on the bottom-centre pivot, drawn to
match the world character scale (`ironjaw_tall` at 0.33, see PR #214).
Path: `art/characters/npc/<role>/idle_<facing>.png` (horizontal strip).

Monsters and bosses (Scenario, **unpaused** 3 Oct): 3–4 world monster
families per level zone (4.10) and each dungeon's packs and boss (4.6), same
canvas, pivot, facings and idle loop rules as NPC bodies, plus a walk loop
(8 frames) for world monsters and an attack / hit pair for fights. Bosses
1.5× the size of a normal monster. Paths:
`art/monsters/<family>/` and `art/bosses/<dungeon_id>/`.

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

#### WP13: Combat glide walk (Feel), separate track, **lean / gait parked (characters not now)**

- **Goal:** finish the combat walk on `claude/stasium-xii-pc` (from `main`):
  the glide through corners is done there (not merged, waiting for Mauro);
  next come a forward lean while moving and a cleaner move preview (dotted
  line, target diamond, range outline), from Mauro's reference clip.
- **Rule:** combat only; it does not touch the world walker.

#### WP16: NPC shops (Code)

- **Goal:** Traders, the Smith, the Banker and others sell and buy with Crypto
  Coins (4.12, phase 1 list).
- **Needs:** WP6, WP14.
- **Add:** `data/world/shops.json` + schema (what each NPC sells, prices,
  buy-back rate, Proposed); `backend/pc_shops.gd` (preload; buy / sell, pure
  logic); `scenes/world/ui/shop_panel.gd` / `.tscn`; `tests/run_pc_shops_tests.gd`.
- **Accept:** no shop sells Rare parts or Mystery Boxes; you can't buy without
  the coins; sell-back is lower than the price (Proposed 30%); save / load.
- **Media:** buying food and a recipe from the Crossroads Trader.

#### WP16b: Crypto Bank (Code + Scenario)

- **Goal:** the Crypto Bank at the Crossroads: deposit and withdraw Crypto
  Coins, and store items (4.12).
- **Needs:** WP6 (the Banker NPC), WP14 (wallet and inventory).
- **Add:** `backend/pc_bank.gd` (preload; `deposit(n)`, `withdraw(n)`,
  `store(item, n)`, `take(item, n)` for every item kind (set parts, materials,
  food, potions, recipes, decorations, objects), stacking, slot limit; pure logic so a server can run it
  later); bank and wallet balances in `user://pc_progress.json`;
  `scenes/world/ui/bank_panel.gd` / `.tscn` (two balances, an amount field,
  Deposit / Withdraw, item slots); the bank building as a Crosshaven landmark
  (Scenario: a 3×3 "Crypto Bank" building in the Crossroads style, 1x + 2x,
  kit rules); `tests/run_pc_bank_tests.gd`.
- **Accept:** coins are never created or lost by deposit / withdraw (the total
  stays the same); you can't withdraw more than the balance or deposit more
  than you carry; slot limit holds; save / load keeps both balances.
- **Media:** walking into the Crypto Bank, depositing coins, storing a part.

#### WP17: Gathering (Code + Technical Artist)

- **Goal:** trees, crops and mineral nodes in Crosshaven can be gathered for
  materials.
- **Needs:** WP14 (inventory).
- **Add:** `data/world/resources.json` + schema (node types, materials,
  respawn, Proposed); node placements as sidecar data per chunk (not in the
  zone files); `backend/pc_gathering.gd`; gather action and spent-state swap in
  the world scene (the kit's `tree_<species>_stump.png` art already exists);
  `tests/run_pc_gathering_tests.gd`.
- **Accept:** a node can't be gathered while spent; respawn time holds;
  materials land in the inventory; nodes never sit on exits, gates, doors or
  NPC cells.
- **Media:** cutting a golden oak to its stump and picking a cabbage field.

#### WP18: Crafting and recipes (Code)

- **Goal:** workbenches craft food and potions (then decorations and upgrade
  materials) from recipes, materials and coins.
- **Needs:** WP16, WP17.
- **Add:** `data/world/recipes.json` + schema; `backend/pc_crafting.gd`;
  `scenes/world/ui/craft_panel.gd` / `.tscn`; workbench props in the town hubs;
  `tests/run_pc_crafting_tests.gd`.
- **Accept:** a craft needs the recipe, every material and the coins, and
  takes them all once; food and potion effects apply only out of combat
  (Proposed) and through `pc_progress.gd`.
- **Media:** buying a recipe, gathering, cooking a meal, eating it.

#### WP19: Marketplace (Code), **after the map is finished** (Q9)

Player listings and purchases in Crypto Coins with a sale tax (4.12). Needs a
server that holds player inventories and coins. Mauro, 3 Oct 2026: online
servers wait until the map is fully developed. Build nothing for it now.

#### WP20: Houses and decorations (Code + Scenario), **later phase**

Plots in the towns, a house interior, placing decorations, saved layouts
(4.12). Not in phase 1.

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

1. ~~**PC art:** is the pause lifted?~~ **Answered 3 Oct 2026 (Mauro): yes,
   for the map, open world, NPCs, bosses and monsters.** Player fighters stay
   parked.
2. ~~**Dungeon runs on PC**~~ **Answered 3 Oct 2026 (Mauro): "yes, same
   concept, different dungs".** Port the Stasis dungeon concept and the team
   engine into PC files; all 11 PC dungeons are PC's own (WP8).
3. ~~**Where does XP come from?**~~ **Answered 3 Oct 2026 (Mauro):** open-world
   levelling, missions (every NPC, levels 1–50, better rewards as you level and
   advance) and dungeons, with dungeons giving more XP than the open world
   (4.8). Rewards: Crypto Coins, Regular set parts, then Rare parts and Mystery
   Boxes (4.9).
   **3b.** What a level gives: **answered 3 Oct 2026 (Mauro): option A**, with
   the cap going to 100 in the next phase (4.3 cap rule, 4.11). What set parts
   do: **answered 3 Oct 2026 (Mauro): option A**, starting with 3 Crosshaven
   sets, more next phase (4.9). What Crypto Coins buy: **Mauro's direction 3
   Oct 2026**: marketplace, crafting, houses, food, potions, decorations,
   recipes, supplies, minerals (4.12). **Still Open:** Mauro's yes to each
   5-part bonus before it is built.
4. **NPC jobs:** ~~which first?~~ **Partly answered 3 Oct 2026 (Mauro): NPCs
   with missions come first** (4.7, WP6b). Shops, crafting, market and houses
   now follow 4.12. Still Open: mission types that need quest items.
5. ~~**Region size:** 2 chunks per region to start, or more?~~ **Answered
   3 Oct 2026 (Mauro / Luca, yes):** 55 new chunks, 3–8 per region, with entry
   / door / hub / middle chunks, one landmark per chunk, WP5 split into WP5a and
   WP5b, and the new connectivity tests. **Soft Lock**: see 1.4 and 3.1.
6. ~~**Monsters in the world?**~~ **Answered 3 Oct 2026 (Mauro): yes**, walking
   only in their designated zones; above level 25 they are aggressive (4.10,
   WP9).
7. **Crosshaven walker facing fix** (a quarter-turn off the locked rule): may
   the team fix it now?
8. **Where Eastmarch Fen Edge sits:** off the east road (concept image) or past
   Eastmarch town?
9. ~~**Economy build order / online server?**~~ **Answered 3 Oct 2026 (Mauro):
   "online servers get pushed until we have fully developed the map".** No
   online server work (accounts, server saves, marketplace) until the map is
   fully built. Phase 1 builds everything offline / single-player with local
   saves: NPC shops, the Crypto Bank, gathering, crafting food and potions,
   upgrades, fast travel. The marketplace (WP19) waits for the server. Keep
   game logic in pure backend scripts (no scene code) so it can move to a
   server later.
10. ~~**Crypto Bank:** interest? branches?~~ **Answered 3 Oct 2026 (Mauro): no
    interest; one bank only, in the main city** (the Crossroads).
11. ~~**Set bonuses**~~ **Answered 3 Oct 2026 (Mauro): yes to the three shared
    set bonuses, and "you will need to create a balanced set for every single
    class"** (4.9 class sets). The class set names, stats and 5-part effects
    in 4.9 are Proposed: Mauro to approve them.
