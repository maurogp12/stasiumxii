# STASIUM XII (PC): open world zones build spec, levels 1–50

Owner: **Mauro**. Spec written 3 Oct 2026 for the build team (Stasium Bot with
the Cursor cloud coding agents, the Scenario art agent, the Technical Artist
agent and the combat-feel agent). The writer of this spec does not build it.

Status: Mauro approved the zone plan **to try** (3 Oct 2026) and placed
Stormspire (and its dungeon) **south of Gloomfen at 35–40**. Everything else marked
**Proposed** is a suggestion that Mauro can change. Items marked **Open** wait on
Mauro: do not decide them in code.

> **Current phase: Crosshaven first** (levels and towns: section 00) (Mauro, 3 Oct 2026: "We only doing
> Crosshaven as of now, Windmere is next phase"; "Crosshaven first until I say
> otherwise"). Build and polish only Crosshaven: the Crossroads, the five road
> chunks and the five towns (levels 1–10), the
> two Crosshaven dungeons (Old Granary Cellar, Millrace Vaults), and its NPCs,
> missions, coins, sets and combat look. Everything for the nine outer regions
> (WP5a/WP5b region layouts, the 4.4 region joins, region dressing and art in
> WP10a, region dungeons) is **next phase: paused**. Keep the region stand-ins
> already merged, but hide them: no join, gate or exit reaches them while the
> phase flag `world.regions_enabled` is false (default false). Missions and
> tasks only target Crosshaven. The open-world rule still holds inside
> Crosshaven: every chunk is walked to from the Crossroads with no jumps, and
> it matches the Crosshaven plate (LOOK_TARGET section D).

Map image of the plan: Proposed zones on the regions concept
(`pc_zone_map_proposed.png`, shared in chat 3 Oct 2026). It shows the zones
before Stormspire was placed.

---

## 00. Crosshaven phase plan: five towns, levels 1–50 (overrides section 3 for this phase)

Mauro, 3 Oct 2026: "crosshaven has 5 towns, each town should have their npcs
and missions, also its difficulty level … 1 to 10, 10 to 20, 20 to 30, 30 to
40 and 40 to 50; above lvl 30 should be the danger zone, like the dark side or
swamp, monsters attack players that pass too close to them." Town order chosen
from the Crosshaven plate (`docs/pc/look_target/crosshaven_plate.jpg`). The
level path goes **clockwise round the island**, from the safe north, west and
east into the **dark south**.

| Order | Town (plate position) | Levels | Feel | Danger | Dungeon (reused design) |
|---|---|---|---|---|---|
| 1 | **Stoneford** (west, river ford) | 1–10 | Farms, mill, river, gentle | Safe: monsters passive | Old Granary Cellar (the Ratking) |
| 2 | **Northgate** (north, under the cliffs) | 10–20 | Cliff town, the only one with light snow | Safe: passive | Frostspire Archive (the Pale Archivist) |
| 3 | **Eastmarch** (east coast) | 20–30 | Docks, coves, sea caves | Safe: passive | Saltmaw Grotto |
| 4 | **Southbridge** (south, the bridge over the gorge) | 30–40 | **The swamp:** fen under the bridge, fog, rain, bog monsters | **Danger zone** | Drowned Abbey |
| 5 | **Westwatch** (south-west, the walled watchtower) | 40–50 | **The dark side:** blight, violet dusk; the watch guards the island against it | **Danger zone** | Heart of the Blight |

- **The Crossroads** is the start (level 1) and the safe hub: Guide, Banker,
  Herald. No monsters ever spawn there.
- **The roads** take their town's band: `road_west` 1–10, `road_north` 10–20,
  `road_east` 20–30, `road_south` 30–40, `road_southwest` 40–50. Their town-side
  half holds the band's higher levels. Each road starts at the Crossroads with
  a level sign. Monsters on `road_south` and `road_southwest` are aggressive only
  past the sign, and never within 6 cells of the Crossroads edge.
- **Each town has its own NPCs and missions.**
  - **NPCs:** its Warden, Trader, Door Keeper (next to its dungeon door), Elder
    and 2–3 townsfolk, using the 4.5 roles.
  - **Missions:** a story chain of about 6 steps for its band, plus repeatable
    tasks from its givers (4.7 rules).
  - **Targets:** missions stay inside the town's band area.
  - **Hand-over:** the last step sends the player to the next town in the order.
- **The danger zone (levels 30–50, Southbridge and Westwatch)** replaces the
  4.10 "above 25" rule for this phase. Every monster group in these bands is
  **aggressive**:
  - **Aggro:** when a player passes within **3 cells** of a group and can reach
    it on foot, the group walks to the player and the fight starts.
  - **Below 30:** all groups are passive; the player clicks them to fight.
  - **Readable danger:** aggressive groups show a red eye mark and a red aggro
    ring on hover. The ground and light darken past each danger sign (swamp
    fog and rain at Southbridge, violet blight at Westwatch).
  - **Fairness:** no aggro on safe cells (within 2 of an NPC, a door or an
    exit, and town squares); 10 s of grace after a fight, a chunk change or a
    respawn; one aggro at a time.
  - **Outlevelled groups:** a group ignores a player who is 15 or more levels
    above the group (Proposed), so high levels can pass through.
- **Room to level (Proposed, Mauro may change):** two chunks a band is too
  little for about 150 h. Each town gets its **outskirts**: the fields, cliffs,
  coves and marsh between the towns on the plate, built as extra chunks on the
  island. Sizes: Stoneford 3, Northgate 4, Eastmarch 4, Southbridge 5,
  Westwatch 6, making 22 new chunks and 33 in all. The merged region stand-ins
  may be reused as the base for outskirts chunks, re-skinned to their town.
- **Next phase:** Windmere and the other outer regions, with the 4.4 joins.
  Their bands will be re-planned on top of this one.

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
- **Chunk roles:** every region has a **border** chunk per join (4.4), one **door** chunk,
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
| 7 | `eastmarch_fen_edge` | Eastmarch Fen Edge | **Off the east road** (branches off `crosshaven_road_east`, before Eastmarch town; Mauro, option 1), the way into the swamp | 25–30 | Sunken Mill | New, Proposed |
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

- **Border (was Entry):** the chunk that touches a walk-across join (4.4).
  One per join; Blightwood and Ashen have two. The zone ids may keep the
  `_entry` suffix for the first one.
- **Door:** holds the dungeon door and its Door Keeper. Exactly one per region.
  Proposed: the door chunk is the deepest chunk from the Crosshaven-side border.
- **Hub:** where the region has a town (Rowanvale, Windmere, Brinewake,
  Slagcrown): Warden, Trader and the zone's extra NPCs. The hub can be the border chunk.
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
XP rewards in 4.8 are a share of `xp_to_next(L)` times a **pace factor** that
slows the later levels (Mauro, option B: about 150 hours to level 50 for a
free player). The pace for levels 51–100 is set with the next phase; the
WP15 simulator reports it.

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
  Initiative, act earlier), **Resist** (more resistance). The kits themselves
  (spell numbers) never change with level.
- **Per-point values** (Proposed, tuned by WP15). Every point is worth about
  the same, so no stat is the obvious pick, and percentages scale with each
  class's base HP and kit:

  | Stat | Per point | 98 points (level 50) all in one stat |
  |---|---|---|
  | Mastery | +0.5% damage and healing done | +49% |
  | Vitality | +0.5% of the class's base max HP | +49% max HP |
  | Resist | +0.4% less damage taken (total Resist capped at **33%**, Soft Lock) | 33% (cap reached at 82.5 points) |
  | Swift | +1 Initiative and **+0.35% damage done** (Soft Lock) | +98 Initiative, +34.3% damage |

  Points are on in Koliseo PvP, and **every PvP fighter has the full point
  budget** (everyone is treated as `max_level` with their own spend). So the
  PvP check is **spread against spread**, not points against no points: for the
  same class, any two point spreads stay within a 45–55% win rate against each
  other (no dominant build), and the five classes stay balanced with their best
  spread. Points against no points is not a PvP case and is not checked
  (corrected 3 Oct 2026; the earlier wording was wrong). Resist points past its
  33% cap give nothing, so a full-Resist spend has to be judged with the cap.

  **Measured (WP3b, 3 Oct 2026, 200 seeded CombatSim duels per class):** the
  Resist cap went from 25% to 33% and Swift gained +0.35% damage per point, both
  numbers on existing effect types (a proposed "extra turn" for Swift was
  rejected: it is a new turn rule and needs Mauro). Nine of ten pooled pairs are
  inside 45–55%; **all Swift vs all Mastery is 63.3%**, and 16 single-class rows
  fall outside 35–65%, because 1v1 fights are short and whoever acts first often
  wins by one hit. No single per-point rate fixes both, so this goes to Mauro as
  Q17. **Q17 answered 3 Oct 2026: option C** (Mauro: Initiative is a chosen
  advantage over damage). No first-turn rule, no cap; "all Swift vs all
  Mastery" may sit up to 65%, every other pair stays 45–55%. Swift +0.35%
  damage per point and the Resist cap 33% are **Soft Lock** (Mauro kept the
  damage: without it a Swift build loses about 90% of fights).
  These numbers only affect Koliseo PvP, not the open world.
- **Class HP growth per level** (a small flat HP gain, different per class,
  Proposed).
- **Milestones:** **+1 AP at level 30** (Proposed). The next phase may add a
  second milestone between 51 and 100 (Open, decided with that phase).
- **Titles** at 10, 20, 30, 40, 50 (and every 10 after, up to 100).
- **Respec:** one free reset of the points, then each reset costs
  **100 × the player's level** in Crypto Coins (an Elder does it; Proposed:
  3,000 at level 30, about 2 hours of income there; 5,000 at 50).
- **Koliseo stays fair:** in Koliseo PvP every fighter is treated as
  `max_level` with their own point spend, and set stats are switched off
  (Proposed). Levels and gear matter in the open world and dungeons.

Data: `data/world/level_rewards.json` (format `stasium.level_rewards` v1):
`points_per_level`, `stat_per_point` per bucket, `class_hp_per_level`,
`milestones` (`[{"level": 30, "ap": 1}]`), `titles`, `respec`. Built in WP3
(points and spending UI) and checked by WP15.

### 4.4 Region joins: one open world, walked on foot (`data/world/joins.json`)

**Open world** (Luca, 3 Oct 2026: "make sure Crosshaven connects with every
map that we have, it should be an open world"; Mauro: "walk from town (A) to
town (B) and zone lvls around it"). Every region joins the world **by walking
across a chunk edge**, exactly like a chunk exit inside Crosshaven: no
clickable gate, no teleport, the WP13 no-snap camera and soft fade. A region
is a place you walk into, not a separate map.

**The world is one grid.** `world_index.json` gives every chunk a grid slot
`{"col": c, "row": r}` (Crossroads = 0,0; north is row −1). Chunks only join
grid neighbours, on opposite edges (west ↔ east, north ↔ south), so the world
map is one picture. Each region grows **outward** from its town: Rowanvale
west of Stoneford, Windmere north of Northgate, Brinewake east of Eastmarch,
Slagcrown south of Southbridge, Fen Edge south of the east road, then
Gloomfen and Stormspire further south; Ashen Shardfields south of Westwatch
and west of Slagcrown; Blightwood in the north-west, north of Rowanvale and
west of Windmere.

**Geography follows the Crosshaven plate** (LOOK_TARGET section D,
`look_target/CROSSHAVEN_OPEN_WORLD_BRIEF.md`). Crosshaven is a cliff-edged
landmass with sea on its coast, and the regions continue off the same coast
and roads. Each join corridor is where a pale road leaves the cliffs or
crosses water, and its art matches the plate.

**The five towns are ringed by water and cliff** (a 3-cell band on every
outer edge). A join cuts a **4-cell-wide road** through that band in the
middle of the edge: a ford or stone bridge over water, a pass with steps
through cliff. The Crosshaven chunk files stay unchanged: `joins.json` is a
sidecar that `world_atlas.gd` applies at load (it sets the corridor cells
walkable with the corridor terrain and adds the two-way edge exit).

```json
{
  "format": "stasium.world_joins",
  "format_version": 1,
  "joins": [
    {
      "id": "stoneford_rowanvale",
      "a": {"zone_id": "crosshaven_stoneford", "edge": "west", "span": [14, 17]},
      "b": {"zone_id": "rowanvale_entry", "edge": "east", "span": [10, 13]},
      "corridor": {"terrain": "ford_stone", "depth": 3},
      "sign": "Rowanvale · levels 10–15"
    }
  ]
}
```

Joins (**Soft Lock**; spans are cell indexes along the edge, 4 wide; the
region side's chunk is the one in that grid slot after the re-route):

| Join | Crosshaven / region side | Region side | Corridor |
|---|---|---|---|
| Stoneford ↔ Rowanvale | `crosshaven_stoneford` west, y 14–17 | Rowanvale border chunk east, y 10–13 | Stone ford over the river |
| Northgate ↔ Windmere | `crosshaven_northgate` north, x 18–21 | Windmere border chunk south, x 14–17 | Cliff pass with steps; snow starts here |
| Eastmarch ↔ Brinewake | `crosshaven_eastmarch` east, y 14–17 | Brinewake border chunk west, y 10–13 | Plank bridge over the harbour inlet |
| Southbridge ↔ Slagcrown | `crosshaven_southbridge` south, x 18–21 | Slagcrown border chunk north, x 14–17 | The south bridge over the gorge |
| East road ↔ Fen Edge | `crosshaven_road_east` south, x 16–19 (already walkable) | Fen Edge border chunk north, x 14–17 | Dirt track into reeds |
| Westwatch ↔ Ashen | `crosshaven_westwatch` south, x 16–19 | Ashen border chunk north, x 14–17 | Cliff pass |
| Fen Edge ↔ Gloomfen | Fen Edge far chunk south | Gloomfen border chunk north | Boardwalk |
| Gloomfen ↔ Stormspire | Gloomfen south chunk south | Stormspire border chunk north | Rock causeway |
| Slagcrown ↔ Ashen | Slagcrown west chunk west | Ashen east chunk east | Cooled lava flats |
| Rowanvale ↔ Blightwood | Rowanvale north chunk north | Blightwood south chunk south | Dead hedgerow lane |
| Windmere ↔ Blightwood | Windmere west chunk west | Blightwood east chunk east | Frozen forest path |

Rules: both spans 4 cells on opposite edges; every corridor cell walkable after
the sidecar; the 2 cells inside each end walkable (no prop or NPC); the
region's border band (WP10a) leaves a gap of exactly the span plus 1 cell each
side; a **level sign** prop stands beside each region-side end (name and band
from `level_zones.json`); crossing shows a one-line toast ("Entering
Rowanvale · levels 10–15"). Nothing blocks a low-level player: like Dofus and
Wakfu, the sign warns, the monsters decide. The **border chunk** is the
region's chunk that touches the join (was "entry"); Blightwood and Ashen each
have two border chunks, one per join. The way back is the same edge, so you
always come back where you went in.

**Edge art** (Scenario Art, WP10a): blend tiles over the 3 corridor cells and
2 cells either side (Rowanvale meadow into Stoneford grass, Windmere snow
fading into Northgate stone, and so on), plus the corridor art (ford, pass,
bridge) and one level sign per region. Order follows the art pairs: Stoneford
→ Rowanvale and Northgate → Windmere first.

**Gates** (`gates.json`) remain only for links you cannot walk: the Brinewake
island ferry (Ferry Captain) and, later, premium fast travel between hubs. A
gate's way back lands next to where it left (within 2 cells, same chunk).

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

That is 33 core NPCs (3 × 11) plus 20 extras (3 + 7 + 2 + 8 × 1): **53 NPCs** (corrected 3 Oct 2026; the earlier "18 extras, 51" was an arithmetic slip).

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
| Old Granary Cellar | Crosshaven Heart | Tutorial cellar under the market: rats, scarecrow drudges, the Ratking (boss, Proposed name) |
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

**Story vs. repeatable (settled 3 Oct 2026, so 4.7 and 4.8 don't clash):**
- **Story and side missions** (the 33 chain + 20 side, each done once) use the
  one-time amounts above, of `xp_to_next(level_min)`, with no pace multiply.
  They are a finite bonus, not a farm.
- **Repeatable NPC tasks** use the 4.8 mission row: talk / reach 6%, defeat
  10%, clear 30% of `xp_to_next(player level)`, **× pace(player level)**, read
  from `level_curve.json` (never hardcoded). Coins for a task = the world-fight
  coin rate at that level × (task minutes ÷ 3), so a task never pays more per
  minute than fighting.
- **Anti-farm:** tasks come only from Wardens, Traders and the region extras
  (not Door Keepers, the Banker or the Herald); **at most 3 active tasks**; no
  two active tasks share a landmark; one task per NPC until it is turned in.
  At the level cap, tasks pay coins only (at the same per-minute rate).
- WP15 re-scores the normal mix with tasks included: missions stay near 20% of
  play time and no single source exceeds 50%.

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
| Time from level 1 to 50, free player, normal mix | about **150 hours** (accept 130–170) (**Mauro, option B**, 3 Oct 2026: "should take longer, we don't want our game to die too soon") |
| Time from level 1 to 50, premium player (+25% XP) | about **120 hours** |
| Milestones, free player (Proposed) | level 10 ≈ 8 h, 20 ≈ 23 h, 30 ≈ 47 h, 40 ≈ 87 h, 50 ≈ 150 h; the last level (49 → 50) ≈ 8 h |
| Dungeon XP per minute vs open-world XP per minute | **about 1.5×** (accept 1.3–1.8×) |
| Share of total XP by source (normal mix) | open world ~43%, dungeons ~40%, missions ~17%; no source above 50% |
| A player who only fights in the open world | still reaches 50, about **1.15–1.2× slower** than the normal mix (corrected 3 Oct 2026: the earlier "1.5×" did not match the formulas below). With the option B pace this is about 172 h free / 138 h premium, which puts the normal mix near 147 h, inside 130–170 |
| Content per level | every level band has enough missions, NPC tasks and dungeon stars to fill its hours (WP15 flags a band with too little to do) |

**Pace factor** (option B): every XP reward below is multiplied by
`pace(L) = 1.6 × 0.9532^(L − 1)` (×1.6 at level 1, ×0.16 at level 49), so the
first levels are quick and each later level takes longer. `L` is the
player's level. The exact factor is tuned by WP15 to hit the targets above;
it is stored in `level_curve.json` (`pace_start`, `pace_ratio`) so it can be
changed without code.

Formulas (**Proposed**; all read `xp_to_next(L)` from 4.3 and are then
multiplied by `pace(player level)`; `L` = the monster group's or dungeon's
level):

| Source | XP |
|---|---|
| Open-world fight (one monster group, about 3 min) | `3.5% × xp_to_next(L)` |
| Dungeon run, win (room A + room B, about 15 min) | `27% × xp_to_next(L) × star` with star ★1 1.0, ★2 1.2, ★3 1.45, ★4 1.7, ★5 2.0 |
| Mission | talk / reach: `6%`; defeat monsters: `10%`; clear a dungeon: `30%` of `xp_to_next(player level)` |

Level gap (stops farming far below your level, Proposed): group 6–9 levels
below the player ×0.5, 10+ below ×0.1; above the player +5% per level, up to
+25%. Party (each member's share, Proposed): 1 player ×1.0, 2 ×0.85 each,
3 ×0.75, 4 ×0.7 (party fights are faster and safer).

**Mission minutes** (Proposed, so WP15 can score the normal mix): talk 3 min;
reach 5 min; defeat N monsters 3 min per fight (N = 4 by default, so 12 min);
clear a dungeon 20 min (15 min run + 5 min travel). The normal mix is 50%
world fights / 30% dungeons / 20% missions by play time, with missions split
evenly between the four types.

What a level gives: 4.11.

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
bonuses. Mauro: **"you will need to create a balanced set for every single
class"** and **"we have to create sets for lvl 1, lvl 10, lvl 20 up to 50,
which is the max."** More sets come later as the classes develop and when the
cap goes to 100.

- **5 set slots** (head, cape, belt, boots, amulet; Proposed), plus 3 non-set
  slots (ring, ring, weapon) in 4.13. A full set fills all
  5, so the choice is one full set (its 5-part bonus) or a 3 + 2 mix (two
  smaller bonuses).
- **Set tiers: level 1, 10, 20, 30, 40, 50.** A set's parts can be worn from
  its tier level. Next phase adds tiers 60, 70, 80, 90, 100 (cap rule, 4.3).
- **Each part gives 1–2 stats** from the four buckets in 4.11 (Mastery,
  Vitality, Swift, Resist). **Rare** = about 1.5× the Regular stats plus one
  extra stat (Proposed).
- **Set bonuses:** 2 parts a stat bonus, 3 parts a bigger one, 5 parts a
  special bonus (Proposed values; tuned with WP15 and the class kits).
- **Upgrades +1 to +5** with Crypto Coins (and spare parts at +4 / +5), each
  step about +10% of the part's stats (Proposed).

#### Class sets: every class, every tier (30 sets)

One set per class at each tier: 5 classes × 6 tiers = **30 class sets**
(150 parts). A class set can be worn only by its class. Names **approved**
by Mauro (3 Oct 2026):

| Tier | Kestrel (ranged, Air) | Ironjaw (bruiser, Earth) | Mender (healer, Water) | Gloam (assassin) | Bastion (tank) |
|---|---|---|---|---|---|
| **1** | Fledgling | Quarryhand | Dewdrop | Shadowstep | Watchpost |
| **10** | Windrunner | Stonefist | Brookmender | Nightcloak | Shieldwall |
| **20** | Skyfeather | Quarrybreaker | Tidewell | Duskveil | Bulwark |
| **30** | Stormquill | Ironclad Ram | Riverheart | Umbral Fang | Ironbastion |
| **40** | Galecrest | Mountainmaw | Deepspring | Voidshroud | Rampart Lord |
| **50** | Zenith Talon | Titan's Jaw | Oceansong | Eclipse | Aegis Eternal |

Stats each class's parts lean to: Kestrel Mastery + Swift; Ironjaw Mastery +
Vitality; Mender Vitality + Resist; Gloam Mastery + Swift; Bastion Vitality +
Resist. The 2- and 3-part bonuses give the same two stats.

5-part effects: each class has one **signature effect** (**approved** by
Mauro, 3 Oct 2026, "just make sure everything ends up balanced") that first
appears at tier 20 and grows with the tiers; tiers 1 and 10 give a plain stat
bonus at 5 parts, so the early game stays simple.

| Class | Signature effect (tier 20) | Tiers 30 / 40 / 50 |
|---|---|---|
| Kestrel | +1 max range on Mark Shot | plus a small second effect, e.g. more damage on the first Mark Shot of each turn, growing with the tier |
| Ironjaw | Start every fight with +1 Impact | plus, e.g., Shoulder costs less on the first use each fight |
| Mender | Mend heals +2 and Pulse Tap heals +1 (about +12%; was "Mend +10%", too small at +1.6 HP, see 4.14) | plus, e.g., a small heal on allies when Cleanse lands |
| Gloam | +1 MP on turns you start Invisible | plus, e.g., more damage on the first hit out of Invisible |
| Bastion | The first hit you take in each fight deals half damage | plus, e.g., Snap Wall also gives an adjacent ally Resist |

The second effects (tiers 30 / 40 / 50) are still ideas for the team to size
inside the balance rules below and bring to Mauro; nothing past the tier 20
signature is built before his yes.

**Balance gate (Mauro: "make sure everything ends up balanced"):** no set,
signature effect, Epic or Relic ships until the WP15 simulator passes every
rule in 4.9 and 4.14 for every class and tier. When a check fails, the team
changes **numbers only** (stat values, effect size, drop rates), never the
approved names or effect types, and shows Mauro the before / after table. A
first read of the five signatures from the kit numbers: Kestrel's (+1 range)
is the most likely to land below "worth 2 parts" and Gloam's (+1 MP while
Invisible) the most likely to land above, because Gloam also gains most from
AP (4.14); WP15 sizes them first.

#### Shared sets (any class)

The three Crosshaven shared sets stay, with **Mauro's approved 5-part
bonuses** (3 Oct 2026):

| Set | Tier (Proposed) | Where it drops | 5-part bonus (approved) |
|---|---|---|---|
| Wayfarer | 1 | Crosshaven Heart: world fights and Heart missions | +1 MP on the first turn of a fight |
| Townguard | 5 | Crosshaven Towns: world fights, town missions | Extra Resist when standing next to an ally |
| Millwright | 8 | Millrace Vaults only (its dungeon set, below) | Extra Mastery on the turn after you are hit |

All set effects are combat effects: built only through CombatSim, and off in
Koliseo PvP (set stats are off there).

#### Where each tier drops (Proposed)

| Tier | Main source | Also from |
|---|---|---|
| 1 | Old Granary Cellar (Crosshaven Heart) | Heart missions, Crosshaven world fights |
| 10 | Rotting Orchard Barrow (Rowanvale) | Rowanvale and Windmere missions and world fights |
| 20 | Saltmaw Grotto (Brinewake) | Brinewake, Slagcrown and Fen Edge missions and world fights |
| 30 | Drowned Abbey (Gloomfen Mire) | Gloomfen and Stormspire missions and world fights; Thunderwell Core |
| 40 | Shard Hollow (Ashen Shardfields) | Shardfields missions and world fights |
| 50 | Heart of the Blight (Blightwood Hollow) | Blightwood missions and world fights |

Dungeons are the main source (a guaranteed part per win, 4.9 drop table);
world fights and missions drop parts at lower chances. A class-set drop picks
the player's own class 60% of the time, so parts for alt classes and for the
marketplace still appear. Dungeons outside this table (Millrace Vaults,
Frostspire Archive, Cinderforge Depths, Sunken Mill) drop the tier just below
their zone's band.

#### Every dungeon has its own loot (Mauro, 3 Oct 2026)

Mauro: **"every dungeon should drop different types of sets and other
rewards."** So no two dungeons share a loot table. Each dungeon drops:

1. **Its own dungeon set** (any class, found only in that dungeon), themed on
   its boss. Tier = the dungeon's level band (Proposed).
2. **The class sets of its tier** (the table above), for the player's class
   60% of the time.
3. **Its own extra rewards:** a recipe, a crafting material, a decoration and
   a cosmetic or title that only it gives, plus its own Mystery Box chance.

| Dungeon | Zone | Dungeon set (Proposed) | Tier | Unique extras (Proposed) |
|---|---|---|---|---|
| Old Granary Cellar | Crosshaven Heart | Ratcatcher | 1 | Recipe: Granary Bread; material: Sackcloth; decoration: Old Grain Barrel; title "Cellar Sweeper" |
| Millrace Vaults | Crosshaven Towns | Millwright (approved bonus) | 8 | Recipe: Millstone Stew; material: Gear Cog; decoration: Water Wheel model; title "Millwright" |
| Rotting Orchard Barrow | Rowanvale | Orchard Warden | 10 | Recipe: Blight-free Cider; material: Grave Apple; decoration: Barrow Lantern; title "Orchard Keeper" |
| Frostspire Archive | Windmere | Pale Archivist | 15 | Recipe: Frost Tonic; material: Rime Ink; decoration: Frozen Bookshelf; title "Archivist" |
| Saltmaw Grotto | Brinewake | Saltmaw | 20 | Recipe: Reef Chowder; material: Pearl Shell; decoration: Ship in a Bottle; title "Grotto Diver" |
| Cinderforge Depths | Slagcrown | Ember Smith | 25 | Recipe: Cinder Draught; material: Ember Ore; decoration: Anvil; title "Forgeborn" |
| Sunken Mill | Eastmarch Fen Edge | Millwheel Hag | 25 | Recipe: Fen Broth; material: Bog Iron; decoration: Rusted Millwheel; title "Fenwalker" |
| Drowned Abbey | Gloomfen Mire | Mire Abbess | 30 | Recipe: Swamp Elixir; material: Abbey Candle Wax; decoration: Sunken Bell; title "Bog Pilgrim" |
| Thunderwell Core | Stormspire | Storm Engine | 35 | Recipe: Charged Tonic; material: Storm Coil; decoration: Tesla Lamp; title "Spark Tamer" |
| Shard Hollow | Ashen Shardfields | Ashen Prism | 40 | Recipe: Crystal Brew; material: Prism Shard; decoration: Glowing Crystal; title "Shardbreaker" |
| Heart of the Blight | Blightwood Hollow | Rotting Elder | 50 | Recipe: Elderroot Feast; material: Blight Heartwood; decoration: Blight Seedling; title "Blightbane" |

That is **11 dungeon sets**; their names are **approved** (Mauro, 3 Oct 2026).
Their 5-part bonuses (except Millwright's, already approved) are ideas the team
sizes inside the balance rules and brings to Mauro; none is built before his
yes. Each dungeon set follows the same budget rules
as the class sets of its tier, so a dungeon set is a side-grade (a different
build), not a straight upgrade.

Total sets in phase 1: 30 class sets + 11 dungeon sets + 2 shared world sets
(Wayfarer, Townguard) = **43 sets**.

#### How sets are kept balanced (Proposed rules; WP15 checks them)

1. **Equal budget per tier** (corrected 3 Oct 2026; the earlier `4 + tier`
   per part made a tier-50 set worth about 405 points, 4× all level points,
   and broke rule 2). A **full set** (5 parts + the 2-part bonus + the 3-part
   bonus = 7.5 part-units) is worth `B(T) = round(98 × 1.3^((T − 50) / 10))`
   points, priced with the per-point values in 4.11, so a full tier-50 set
   equals the level-50 point budget (gear doubles your build at the cap, it
   never dwarfs it). One part = `B(T) / 7.5`:

   | Tier | 1 | 10 | 20 | 30 | 40 | 50 |
   |---|---|---|---|---|---|---|
   | Full set B(T) | 27 | 34 | 45 | 58 | 75 | 98 |
   | One part | 3.6 | 4.6 | 6.0 | 7.7 | 10.0 | 13.1 |

   Round per stat line to whole points; the set total stays within ±1 of
   B(T). A Rare part = 1.5× a part + 1 extra stat. A 2-part bonus = 1 part; a
   3-part bonus = 1.5 parts. Resist from gear counts toward the **33% total
   Resist cap** (4.11), and AP / MP from gear toward the AP 8 / MP 5 caps.
2. **Each tier is a clear step up** but not a wall: a full set of tier N + 10
   is about 25–35% stronger than tier N (Proposed), so upgrading tier N to +5
   is roughly halfway to the next tier.
3. **5-part effects are worth about 2 parts.** Each effect is measured in the
   simulator as damage, healing or damage prevented per fight.
4. **Class sets fit, they don't dominate.** For its own class, the class set
   of a tier beats the best shared or other option at that tier by at most 10%.
5. **Classes stay even.** At each tier, with their own class set, all five
   classes clear that tier's dungeon (solo, same level) within ±10% of each
   other's time.
6. **No single effect above 15%.** No 5-part effect alone raises a class's
   damage, healing or survival by more than 15%.
7. **PvP is untouched.** Set stats and effects are off in Koliseo PvP (4.11),
   so the Locked kit balance there does not change.

`rewards.json` lists every set as data (`id`, `name`, `tier`, `classes`,
`parts`, `bonuses`, `drops`), so the next phase adds tiers 60–100 and new class
sets with no code change.

**Mystery Box** (Proposed contents, one roll): 50% coins (5× the mission coins
of the opener's tier), 35% a Regular part, 15% a Rare part, from a set at or
below the opener's level.

Drops (Proposed):

| Source | Regular part | Rare part | Mystery Box |
|---|---|---|---|
| Open-world fight | 3% (a class set of the zone's tier, or the zone's shared world set in Crosshaven) | — | — |
| Dungeon win | 1 guaranteed, from that dungeon's own table (its dungeon set or a class set of its tier), plus one of its unique extras at Proposed chances | ★1 0%, ★2 5%, ★3 10%, ★4 20%, ★5 35% | ★4+ 10% |
| Mission, by **mission rank** (below) | rank 1 20%, 2 35%, 3 40%, 4 40%, 5 35% | rank 1–2 0%, 3 5%, 4 10%, 5 15% | rank 1 0%, 2 3%, 3 8%, 4 12%, 5 20% |
| Every 10th mission turned in | — | — | **1 guaranteed** |

**Mission rank** = how many missions the player has finished: rank 1 (0–9),
2 (10–24), 3 (25–49), 4 (50–99), 5 (100+). This is how "advancing in missions
gives better rewards" works, on top of the level tier.

### 4.13 Rarities, Epics and Relics (**approved** by Mauro 3 Oct 2026; numbers tuned by WP15)

Mauro, 3 Oct 2026: certain items should be **Epic** and **Relic** "like
Wakfu: rings, weapons, helmets, etc." that you can wear **only one of**; some
at **level 50**; and **at level 30 a Rare set that gives +1 AP or +1 MP, not
both**.

Checked against Wakfu: in Wakfu a character can equip **only one Epic and
one Relic** item at a time (Wakfu wiki, "Equipment"). Everything else below
is **our own design, Proposed**: the item names and effects are invented for
Stasium XII, not copied from Wakfu.

**Slots: 8.** The 5 set slots (head, cape, belt, boots, amulet) plus **3
non-set slots: Ring, Ring, Weapon** (Proposed). Rings and weapons also drop as
Regular and Rare items with the same budget per tier as set parts.

**Rarities** (colours Proposed):

| Rarity | Colour | Rule |
|---|---|---|
| Regular | White | Normal |
| Rare | Blue | 1.5× budget + 1 extra stat |
| **Epic** | Purple | A single strong item with its own effect. **Only 1 Epic worn.** From level 40. Can be traded. |
| **Relic** | Gold | The strongest items. **Only 1 Relic worn.** Level 50. Bound to the player (can't be traded). |

**Rare tier-30 set: +1 AP or +1 MP (Mauro's rule).** A full Rare tier-30
class set (all 5 parts Rare) gives the player's choice of **+1 AP or +1 MP,
never both**; switching the choice at the Smith costs Crypto Coins. Regular
tier-30 parts give only the normal bonuses.

**Epics** (Proposed, after the 4.14 review):

| Epic | Slot | Level | Effect |
|---|---|---|---|
| Gale Signet | Ring | 40 | +1 MP, + Swift |
| Abbess's Rosary | Amulet | 40 | +8% healing done, + Resist |
| Ember Crown | Helmet | 45 | +1 range on spells with range 2 or more (range bonuses never stack, 4.14) |
| Stormheart Gauntlet | Weapon | 45 | Your first hit each turn also deals 4 Air damage to one enemy next to the target |
| Prism Striders | Boots | 50 | +1 MP. **The first 3 push attempts on you in a fight work normally; after that you can't be pushed for the rest of the fight** (Mauro's change; a blocked push still counts; counted per fight, approved) |

Sources: a very rare drop from ★4–★5 runs of the level 40–50 dungeons, or
crafted from those dungeons' unique materials plus Crypto Coins.

**Relics** (Proposed, after the 4.14 review):

| Relic | Slot | Effect |
|---|---|---|
| Heart of the Elder | Amulet | +1 AP, −10% max HP |
| Crown of Crosshaven | Helmet | +1 AP and +1 MP for your first 2 turns of each fight |
| Blightroot Ring | Ring | No AP. Your hits poison: 3 damage at the start of the target's turn for 2 turns, stacking up to 3 |

Sources: only Heart of the Blight ★5 (very rare) or the end of the Last
Watcher's level-50 mission chain.

### 4.14 Balance review of sets, Epics and Relics (fixes **approved** by Mauro 3 Oct 2026)

Mauro, 3 Oct 2026: "make sure everything is balanced." This is an analytical
pass with the real PC kit numbers (`data/kits.gd`: 6 AP, 3 MP, 80 HP; Mark
Shot 2 AP / 8, Detonate 3 AP / 6 + 6 per mark, Strike 3 AP / 16, Crush 4 AP
/ 24, Cut 3 AP / 13, Ambush and Nightfold 4 AP / 22, Bash 3 AP / 11, Mend 3
AP / 16, Pulse Tap 2 AP / 10). It assumes every hit lands and every condition
is met, so it shows **where the risks are**; the final proof is the WP15
simulator with the real CombatSim.

**Finding 1: extra AP is uneven between classes.** Spells cost 2–4 AP, so one
extra AP helps some classes a lot and others not at all:

| Best damage (healing) per turn | 6 AP | 7 AP | 8 AP | 9 AP |
|---|---|---|---|---|
| Kestrel | 36 | 36 (+0%) | 44 (+22%) | 54 (+50%) |
| Ironjaw | 32 | 40 (+25%) | 40 (+25%) | 48 (+50%) |
| Gloam | 26 | 35 (+35%) | 44 (**+69%**) | 44 (+69%) |
| Bastion | 22 | 22 (+0%) | 22 (+0%) | 33 (+50%) |
| Mender (healing) | 32 | 36 (+12%) | 42 (+31%) | 48 (+50%) |

Fixes:

- **AP cap 8, MP cap 5** in the open world and dungeons (not 9 / 5). AP
  sources are +1 at level 30 (4.11), the Rare tier-30 set (AP or MP), and the
  Heart of the Elder or Crown of Crosshaven Relic, so a player picks which of
  them to use; the third goes to MP or is wasted.
- **Gloam gains most from AP** (+69% at 8). Gloam's tier 30–50 class sets lean
  **Swift and Resist** instead of Mastery, and its signature effect is sized
  smaller, until WP15 shows all classes within ±10% at 6, 7 and 8 AP.
- **Kestrel and Bastion gain nothing from a 7th AP.** At tier 30 they should
  take +1 MP from the Rare set; their tier 30+ signature effects carry more of
  their power. Bastion is judged on damage taken, not damage dealt.
- **Monsters at 30+ are tuned for players at 7 AP, and at 40+ for 8 AP.**

**Finding 2: bonuses that stack get out of hand.** Fixes:

- **Range bonuses never stack:** at most +1 range from all items (Skyfeather
  and Ember Crown together still give +1).
- **Healing bonuses from items cap at +20% total** (Tidewell + Abbess's
  Rosary).
- **One AP source per item category** is already enforced by "one Epic, one
  Relic".

**Finding 3: some effects were too small or too big.**

- **Tidewell (Mender) was too small**: "Mend +10%" is only +1.6 HP. Now Mend
  +2 and Pulse Tap +1 (about +12%).
- **Prism Striders were too strong** (never pushed): now immune only after 3
  push attempts per fight (Mauro).
- **All three Relics gave +1 AP**, so every build would pick the same thing.
  Now Blightroot Ring gives poison instead of AP, so Relics are a real choice.
- Gale Signet (+1 MP) and Prism Striders (+1 MP) can't stack: only one Epic.

**Finding 4: slots change an item's real value.** An Epic or Relic in a set
slot (helmet, amulet, boots) breaks that set's 5-part bonus; one in a ring or
weapon slot does not. So **ring and weapon Epics / Relics get a smaller budget
(about 1.5 parts)** and set-slot ones a larger one (about 2.5 parts).

**Finding 5: PvP stays safe.** Set stats, effects, Epics and Relics are all off
in Koliseo PvP (4.11), so the Locked kit balance there does not change.

**WP15 checks** (added to its acceptance): every class at 6, 7 and 8 AP; every
class with each tier's class set, dungeon sets and the Epic / Relic choices;
the stacking caps; fail if a class leaves the ±10% band or an item adds more
than 15% (sets) or 20% (Epics / Relics).

### 4.15 Character and inventory window (Mauro's reference + our own version)

Mauro, 3 Oct 2026, with a screenshot of the Dofus character / inventory window
(`docs/pc/look_target/inventory_reference_dofus.jpg`): **"I want an inventory
like this, but our own version."** Same idea and layout logic, our own look
(`docs/pc/LOOK_TARGET.md`: bold, rounded, readable, Waven-style polish, not a
Dofus copy), filled with Stasium XII's systems. Layout and details are
**Proposed**.

One window with three panels side by side (each can also open alone):

**1. Character panel (left; key C)**

- Portrait, name, class, level.
- Bars: **HP**, **XP to next level** (and, if Mauro wants it later, an energy
  bar: Open).
- Combat numbers: **AP, MP, Initiative, Range bonus**, with the caps shown
  (AP 8, MP 5, 4.14).
- **The four stats with + buttons:** Mastery, Vitality, Swift, Resist, and the
  free points left (4.11). A **Respec** button (free once, then Crypto Coins).
- A second tab, "Details": resistances, healing bonus, set and item effects in
  play, titles.

**2. Equipment panel (middle)**

- The player's fighter in the centre (the existing class sprite, turnable;
  player fighter art stays parked).
- **8 slots around it** (4.13): left column head, amulet, ring, ring; right
  column cape, belt, boots, weapon. Empty slots show a faint outline of the
  item type.
- **Epic and Relic markers:** a purple and a gold badge under the fighter
  showing which Epic and which Relic are worn (only one of each, 4.13).
- **Set bonus strip:** the sets being worn, with 2 / 3 / 5-part bonuses lit
  when active (and the Rare tier-30 AP / MP choice).
- **Item card** (bottom of the panel, for the selected or hovered item): name
  in its rarity colour, tier level, upgrade level (+1 to +5), stats, its set
  and set bonuses, conditions (level, class), and tabs **Effects /
  Conditions / Set**. Buttons: **Equip / Unequip**, **Upgrade** (only at the
  Smith), **Sell** (to an NPC trader) or **List** (marketplace, later),
  **Destroy** (asks to confirm).

**3. Inventory panel (right; key I)**

- **Category tabs:** Equipment, Consumables (food, potions), Materials,
  Recipes, Decorations, Mystery Boxes / special. Plus a **filter** (by
  rarity, tier, set, class) and a **search** box.
- **Grid** of items with **rarity borders** (white, blue, purple, gold) and
  **stack counts**; hover shows the item card; drag onto a slot to equip;
  right-click for actions (use, open box, equip, sell).
- **Crypto Coins** shown at the bottom (coins on hand).
- **Bank button:** only lit when standing at the Crypto Bank (one bank, in the
  main city); it opens the bank panel next to the inventory so items and
  coins move between them by drag or a button.
- **Capacity: both a slot limit and a weight limit** (Mauro, Q14: "yes to
  both"). Numbers **Proposed**:
  - **Slots:** 60 to start; more slots bought with Crypto Coins (bags).
    Stackable items (materials, food, potions) share one slot per stack.
  - **Weight:** every item has a weight; a **weight bar** sits under the grid
    (like Dofus "pods", our own look). Proposed weights: recipes 0, materials
    1, food and potions 1, set parts / rings / weapons 10, Epics and Relics
    15, decorations 20–50. Crypto Coins weigh nothing.
  - **Carry limit:** 1,000 + 5 per level (1,245 at level 50; 1,495 at 100,
    cap rule 4.3), plus bags bought with coins.
  - **When full** (slots or weight): you can't gather, buy or pick up more;
    fight, dungeon and mission rewards that don't fit go **straight to the
    Crypto Bank** with a message, so nothing is lost and you never get stuck
    unable to walk.
  - The bank has its own slot limit (20 to start, 4.12) and **no weight
    limit**.

Rules: the window never changes a number itself: stats come from
`pc_progress.gd`, items from `pc_rewards.gd`, coins from the wallet and bank.
It opens in the open world and in towns, not during a fight (Proposed).

### 4.17 Pets and mounts (Mauro's rules + Proposed details)

Mauro, 3 Oct 2026: **"pets can be obtained from every dungeon as a mini
version of the boss, and every pet should benefit each class in some way;
mounts should give speed and other bonuses, and also can be reproduced and
create new mounts; you have to be premium to use mounts and pets."**

Mauro's rules (build them as given):

- **Every dungeon drops a pet: a mini version of its boss.**
- **Every pet benefits every class** in some way.
- **Mounts give speed and other bonuses.**
- **Mounts can be bred** (reproduced), and breeding **creates new mounts**.
- **Using pets and mounts needs premium** (what premium is: Q15).

Two new slots (Proposed): **Pet** and **Mount**, outside the 8 gear slots
and outside the one-Epic / one-Relic rule. Like all gear, pet and mount
combat bonuses are off in Koliseo PvP.

#### Pets (Proposed details)

- **Drop:** the boss of each dungeon drops its mini pet, rarely (Proposed:
  1% at ★1 up to 5% at ★5). Pets can be traded on the marketplace later.
- **Each pet has two parts:**
  1. **A class bonus** that works for every class, sized to the pet's
     dungeon tier: Kestrel + damage %, Ironjaw + damage % on Earth hits,
     Mender + healing %, Gloam + damage % on hits out of Invisible, Bastion
     − damage taken %. Size: 2% (tier 1) rising to 6% (tier 50), Proposed;
     a pet is worth well under one gear part, so it never decides a fight.
  2. **A unique perk** outside combat, different for every pet, so each pet
     is worth collecting.
- Pets follow the player in the world and live in the player's house (4.16).
  Feeding, pet levels and pets fighting are **not** in v1 (Open).

| Pet (Proposed) | Mini of | Dungeon | Tier | Class bonus | Unique perk |
|---|---|---|---|---|---|
| Ratling | the Ratking | Old Granary Cellar | 1 | 2% | +5% carry weight |
| Cogling | The Millwright | Millrace Vaults | 8 | 2% | −3% crafting coin cost |
| Sproutwarden | Orchard Warden | Rotting Orchard Barrow | 10 | 3% | +10% garden yield in your house |
| Little Archivist | The Pale Archivist | Frostspire Archive | 15 | 3% | Shows the next step of your active missions on the map |
| Saltmaw Pup | Old Saltmaw | Saltmaw Grotto | 20 | 4% | +5% Crypto Coins from fights |
| Emberkin | The Ember Smith | Cinderforge Depths | 25 | 4% | −5% part upgrade cost |
| Hagling | Millwheel Hag | Sunken Mill | 25 | 4% | +10% potion crafting speed |
| Abbess Wisp | Mire Abbess | Drowned Abbey | 30 | 5% | Food heals 10% more out of combat |
| Sparkengine | The Storm Engine | Thunderwell Core | 35 | 5% | +5% gathering speed |
| Prismlet | Ashen Prism | Shard Hollow | 40 | 6% | +3% chance of a Rare part from fights |
| Elderling | the Rotting Elder | Heart of the Blight | 50 | 6% | +5% XP from world fights |

#### Mounts (Proposed details)

- **Speed:** a mount raises **walking speed in the open world** (not in
  combat): +20% to +60% by breed and generation (cap +60%, Proposed).
- **Other bonuses** (one or two per mount, by breed): extra carry weight,
  faster gathering, a small stat (Mastery, Vitality, Swift or Resist, worth
  about half a gear part; PvE only), or a little more XP or coins.
- **First mount:** a level 20 mission from a Stable keeper at the Crossroads
  (Proposed), then more from breeding and the marketplace (later).
- **Base breeds, one per region** (Proposed names): Plains Strider
  (Crosshaven), Meadow Hare (Rowanvale), Frost Ram (Windmere), Reef Ray
  (Brinewake), Cinder Lizard (Slagcrown), Fen Heron (Fen Edge), Bog Toad
  (Gloomfen), Storm Gecko (Stormspire), Shard Beetle (Ashen Shardfields),
  Blight Stag (Blightwood).

**Breeding (Mauro: "can be reproduced and create new mounts"):**

- At a **Stable** (one at the Crossroads; Manor houses get a paddock,
  Proposed), pair two mounts. After a real-time wait (Proposed 24 h) and a
  coin fee, a foal is born.
- **The foal inherits** breed, speed, bonuses and colour from its parents,
  with a small random spread, and a **generation** number one higher than
  its parents.
- **New mounts:** crossing two different breeds can create a **hybrid
  breed** (for example Plains Strider × Frost Ram → Gale Strider). Hybrids
  are new mounts with their own look and bonus mix; deeper generations unlock
  rarer hybrids (Proposed: 10 hybrid breeds in phase 1, listed by the team
  for Mauro).
- **Limits so breeding stays balanced:** each mount can breed a few times
  (Proposed 4); speed and bonuses never pass their caps however many
  generations; the simulator checks a long breeding run never beats the caps.

Art (Scenario, unpaused for monsters, bosses and NPCs): 11 pet sprites (mini
bosses), 10 base breeds + hybrids for mounts. **Riding a mount shows the
player fighter on it**, and player fighter art is still parked, so mounted
art and animation need Mauro's go on fighter art; until then a mount can walk
next to the player or the player sprite sits on the mount as a stand-in.

### 4.18 Premium (Mauro's rule + Proposed details)

Mauro, 3 Oct 2026: **"premium will require a real money payment."**

- **Premium is a paid membership with real money.** Today it is needed to rent
  a house (4.16) and to use pets and mounts (4.17).
- **Not pay-to-win in PvP:** pet and mount combat bonuses are already off in
  Koliseo PvP, so premium never changes a PvP fight.
- **Real money buys premium only** (Mauro, 3 Oct 2026): never Crypto Coins,
  items or Mystery Boxes, and coins can never be cashed out.
- **What premium gives** (Mauro, 3 Oct 2026: "premium is going to add bonuses
  for XP, coins, drop and fast travel, and also travel to premium cities in
  the future"):

  | Premium perk | Proposed size |
  |---|---|
  | Rent a house (4.16) | Mauro's rule |
  | Use pets and mounts (4.17) | Mauro's rule |
  | **XP bonus** | +25% XP from all sources |
  | **Crypto Coins bonus** | +15% coins from fights, dungeons and missions |
  | **Drop bonus** | +10% (relative) chance on set parts, Rare parts and Mystery Boxes; **not** on Epics, Relics or pets, so the rarest items stay equal for everyone |
  | **Fast travel** | Free and unlimited between region hubs (free players walk, or pay Crypto Coins at the hub travel posts, 4.12) |
  | **Premium cities** (future phase) | Travel to premium-only cities, designed with the next maps |

- **Balance with premium** (Proposed, WP15 checks): a free player still
  reaches level 50 in about 150 hours; a premium player in about 120 hours
  (+25% XP) (option B). The coin bonus is counted in the economy target (players spend
  70–90% of income), so prices stay fair for free players.
- **Free players** keep the whole map, all levels, missions, dungeons, sets,
  Epics, Relics, crafting and the Crypto Bank; they can collect pets and
  mounts (and trade them later) but not use them without premium.

**What a real-money membership needs (Proposed; outside the build team's
current scope):**

1. **Online accounts and a server** that knows who is premium. Online servers
   wait until the map is finished (Q9), so premium is built after that.
2. **A payment provider and the store's rules.** On Steam, in-game purchases
   must go through Steam's own payment system; other stores have their own
   rules. Mauro picks the store(s).
3. **Business and legal setup:** prices, billing period (monthly, Proposed),
   taxes, refunds, terms of service and consumer law in each country where it
   is sold. This needs Mauro (and likely professional advice), not the build
   team.
4. **Code rule from now on:** every premium check goes through one function
   (`pc_premium.is_premium()`, Proposed) that returns true for everyone in
   offline testing, so houses, pets and mounts can be built and tested before
   payments exist, and switched on later in one place.

### 4.16 Houses: rented homes (Mauro's rules + Proposed details)

Mauro, 3 Oct 2026: **"a few spots per map where a player can rent a house,
where he will be able to farm his own plants and trees, have his pets, cook,
create potions, decorate his house; every week he will be required to pay X
amount of Crypto Coins, and he will need to have premium."**

Mauro's rules (build them as given):

- **A few house spots per map.**
- Houses are **rented**: **every week the player pays X Crypto Coins.**
- Renting needs **premium**.
- Inside a house the player can **farm his own plants and trees, keep his
  pets, cook, make potions, and decorate**.

Proposed details:

- **Spots:** 3–4 per region map, in the hub chunk or near it; Crosshaven gets
  4 (one at the Crossroads, three spread over the towns). Each spot is a door
  on the world map that leads into the house interior (its own small scene).
- **House sizes and weekly rent** (Proposed, checked by WP15 so rent is about
  2 / 5 / 12 hours of normal play income a week at the level shown):

  | Size | From level | Garden | Weekly rent |
  |---|---|---|---|
  | Cottage | 10 | 4 plots + 1 tree | 3,000 Crypto Coins |
  | House | 25 | 8 plots + 2 trees | 8,000 |
  | Manor | 40 | 12 plots + 4 trees | 20,000 |

- **Paying rent:** paid automatically from the Crypto Bank each week. If the
  bank can't cover it, a **7-day grace period** starts; after that the house
  is locked and the spot freed, but **nothing is lost**: items, decorations
  and pets move to bank storage.
- **Farming:** plant seeds and saplings bought or gathered in the world;
  they grow over real time and are harvested for crafting materials. Yields are
  capped so a garden helps but never beats gathering in the world (Proposed:
  a full Manor garden ≈ 30% of an hour of world gathering per day).
- **Pets:** live in the house. **The pet system itself is not designed yet**
  (Open): what pets do, how you get them, whether they come to fights.
- **Cooking and potions:** a kitchen and an alchemy table inside, using the
  crafting rules in 4.12 (recipes + materials + coins).
- **Decorating:** place decorations on a grid in the house; layouts are saved.
  Decorations come from shops, crafting and dungeons (each dungeon has its own,
  4.9).
- **Storage chest:** extra storage inside the house (Proposed 20 slots).
- **Spots are limited**, so they are shared between all players: renting one
  needs the online server, which waits until the map is finished (Q9). Until
  then (offline phase 1), a house can be built and tested as a private copy
  for the single player.

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
| **Houses (rented)** | A few house spots on each map | Rent weekly with Crypto Coins (premium players only); farm, keep pets, cook, brew, decorate (4.16) |
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
- **Houses** are **rented**, not bought (Mauro, 3 Oct 2026): see 4.16.
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
3. **Next:** rented houses (4.16), more professions and recipes.

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
  the **character panel** of the window in 4.15
  (`scenes/world/ui/character_window.gd` / `.tscn`, character tab; **C** key),
  `tests/run_pc_progress_tests.gd`.
- **Accept:** `max_level - 1` increasing entries; level never exceeds
  `max_level`; XP past the cap is kept but does not level; points = 2 ×
  (level − 1) minus spent; +1 AP flag from level 30; respec returns every
  point; **a test re-runs with a 100-level curve** and passes with no code
  change (the cap rule); save/load round-trips; the phone level code is not
  imported or changed.
- **Media:** none.

#### WP4: Multi-region map and walk-across joins (Code)

- **Goal:** the world loads every region as one open world; the player walks
  from Crosshaven into every region across chunk edges, with the same
  no-snap camera and fade as chunk exits.
- **Add:** `data/world/world_index.json` + schema (with grid slots),
  `data/world/joins.json` + schema, `data/world/gates.json` + schema (ferry
  and fast travel only), `backend/world_atlas.gd` (preload; loads every region
  index through the existing `WorldMap.load_index`, applies joins, resolves
  gates, `validate()`), `tests/run_world_atlas_tests.gd`.
- **Change:** `crosshaven_world.gd`: load through `world_atlas.gd`; joins
  behave as normal exits (gold arrows on the edge); the level sign and the
  "Entering …" toast; gates walk there and then `enter_zone`.
- **Accept:** every chunk has a grid slot, no two share one, and every exit
  and join links grid neighbours on opposite edges; every join's spans are 4
  cells and its corridor cells are walkable; the region-to-region joins in 4.4
  all exist; no gate joins two places a join could (ferry and fast travel
  only); a test walks **cell by cell, exits and joins only, no `enter_zone`
  jumps** from the Crossroads to every chunk and back, and from each town to
  the next (Crossroads → Stoneford → Rowanvale hub, → Northgate → Windmere
  hub, → Eastmarch → Brinewake hub, → Southbridge → Slagcrown hub); every
  chunk in every region index is in exactly one level zone (66 chunks once
  WP5b is done); the Crosshaven tests still pass with zero changes to the 11
  chunk files.
- **Data note:** the formats do not change for the larger regions.
  `world_index.json` still lists 9 new regions; each region's `index.json`
  simply lists more chunks.
- **Media:** one uncut clip walking Crossroads → Stoneford → across the ford →
  Rowanvale hub → back, and a world-map still showing the whole grid.

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
    border chunk; every built chunk is reachable from every border chunk; each
    region has one border chunk per join (4.4) and exactly one door chunk.
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

- **Goal:** 53 NPCs standing in the world, clickable, with a dialogue panel.
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
  the **equipment and inventory panels** of the window in 4.15
  (`scenes/world/ui/character_window.gd` / `.tscn`; **I** key): 8 slots, Epic /
  Relic badges, set bonus strip, item card, category tabs, filters, rarity
  borders, stacks, coins, Bank button, **slot count and weight bar**
  (4.15; overflow rewards go to the bank); a "reward" pop-up after fights,
  dungeons and missions; `tests/run_pc_rewards_tests.gd`.
- **Accept:** every drop table sums to ≤ 100%; seeded rolls give fixed results;
  a Mystery Box always gives exactly one thing; the 10th mission always gives a
  box; part stats and 2 / 3-part set bonuses apply through `pc_progress.gd` (stats only; 5-part effects wait on Mauro's yes); the set tier gates who can wear a part; save / load keeps coins and items.
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
- **Premium:** also run every profile as premium (+25% XP, +15% coins, +10%
  drops) and report both; free players stay at the 130–170 h target and
  premium players near 120 h.
- **Accept:** normal mix (free) reaches 50 in 130–170 h, with the level 10 / 20
  / 30 / 40 milestones near 4.8's; no level band is short of content; dungeon XP per minute is
  1.3–1.8× open world; no source above 50% of total XP; world-only still
  reaches 50; a printed table goes in the PR for Mauro.
- **Sets:** also simulate each class at every tier with no set, the shared
  sets and its class set; fail when a 4.9 balance rule (1–7) is broken; print
  the per-class, per-tier table for Mauro.
- **AP, Epics, Relics:** run every class at 6, 7 and 8 AP and with each Epic
  and Relic choice; check the caps in 4.14 (AP 8, MP 5, +1 range, +20%
  healing); fail when a 4.14 rule is broken.
- **Media:** none (the printed table).

#### WP10a: Region dressing (Scenario Art + Technical Artist + world agent)

Luca, 3 Oct 2026: the WP5a / WP6 stills have no decorations (no trees, no dead
trees) and every region looks the same except for its colour. **WP10a runs
before WP14's art-dependent parts and before WP5b**, region by region. It is
the first slice of WP10.

**Order and grouping** (follows the player's path; one PR per pair):

1. Rowanvale + Windmere
2. Brinewake + Slagcrown
3. Eastmarch Fen Edge + Gloomfen Mire
4. Stormspire + Ashen Shardfields
5. Blightwood Hollow on its own (end-game, 8 chunks, richest set)

**Who does what:** Scenario Art paints, the Technical Artist checks the import
and the atlas, and the world agent wires the dressing into the chunks. The
placer (step 0 below) is built first, so each art pair can be wired as soon as
it lands.

**WP14 runs in parallel.** The world agent builds the placer first, then
works on WP14 while the art is painted. When a region pair's art lands, wiring
that pair takes priority over WP14 (a short interrupt: data and stills only).

**Step 0 (world agent, first): the dressing placer.**
- `data/world/<region>/dressing.json` (format `stasium.region_dressing` v1):
  the region's ground-tile mix, a weighted prop list, cluster settings and a
  fixed seed.
- `build_region_standins.py` (or a new `dress_region.py`) places props into
  the chunk JSON deterministically from that file. The zone format does not
  change: props stay in `props`, and the non-blocking small dressing goes in
  `decor`.
- Tests (in `run_wp5a_tests.gd` or a new `run_region_dressing_tests.gd`):
  every placement rule below holds, and the WP5a connectivity tests still
  pass after dressing.
- Until a region's art lands, the placer uses existing Crosshaven prop ids as
  stand-ins, so the rules are proved before the paint arrives.

**Placement rules (all regions):**
- **Walk lanes stay clear:** no prop on a path cell or on the cells directly
  beside a path (path plus 1 cell each side).
- **No prop within 2 cells** of an NPC, a gate cell, a dungeon door, the spawn
  or a chunk exit.
- **Sparse, clustered, not uniform:** blocking props cover at most 8% of the
  chunk's non-path cells. They are placed in clusters of 3–5 (Poisson-disk,
  minimum spacing 2 cells) with open glades between, never on a regular grid.
  Non-blocking decor (grass tufts, flowers, pebbles, puddles) covers up to 25%.
- **Edges framed:** on every chunk edge that is not an exit, a 1–2 cell border
  band of the region's border prop (forest, rock, reeds…), like Crosshaven's
  `border_forest_*`.
- **One hero landmark per region**, replacing the stand-in tavern, placed in
  the hub chunk (or the entry chunk where there is no hub), visible from the
  entry, and never on the critical path.
- **Connectivity unchanged:** door reachable from entry, every built chunk
  reachable, every gate and NPC cell passable.

**Sizes and anchors** (the Crosshaven kit rules: 2:1 diamond, 2x masters at 8x
supersampling, straight alpha, linear filter, no mipmaps, top-left warm key
light, no baked cast shadows):

| Kind | Footprint | 1x canvas | 2x master | Anchor |
|---|---|---|---|---|
| Ground tile | 1 cell | 64×32 | 128×64 | bottom-centre on the cell's south tip |
| Small prop (rock, bush, stump, decor) | 1×1 | 64×64 | 128×128 | bottom-centre on the south tip of the footprint's south-most cell |
| Tree or tall prop | 1×1 | 64×112 | 128×224 | same |
| Wide prop (boat, log, wall run) | 2×1 | 96×80 | 192×160 | same |
| Landmark | 2×2 | 128×192 | 256×384 | same |
| Hero landmark | 3×3 (or 2×2 tall) | 192×256 | 384×512 | same |

Every asset gets an entry in `art/world/<region>/atlas_meta.json` (id, file,
size, anchor, footprint, `blocks`, `walkable`), using the same schema as
Crosshaven's. Trees, reeds and banners also get sway masks
(`<prop>_sway`, `<prop>_shadow_sway`). Animated pieces (lava, bubbles, arcs,
beacons) use 12-frame strips.

**Per-region set** (6–10 props, plus ground tiles and a hero landmark):

| Region | Ground tiles | Props | Border band | Hero landmark |
|---|---|---|---|---|
| Rowanvale (10–15) | meadow ×3, orchard soil ×2, tilled rows ×2 | apple tree ×2 (one fruiting), pear tree, stump, wooden fence (nwse / nesw), hay bale, scarecrow, beehive box, low stone wall, flower bush | orchard hedge | **Old Windmill** (2×2, 12-frame sail strip) |
| Windmere (15–20) | snow grass ×3, white flagstone ×2, glossy ice ×2 | snowy pine ×2, frozen blue pine, ice boulder, snow drift, white pillar ruin, ice crystal cluster, warm lantern post, frozen shrub | snowy pine wall | **Frost Spire** (2×2 tall, faint ice glow) |
| Brinewake (20–25) | sand ×3, wet sand ×2, tide pool (decal) | palm ×2, beached boat (2×1), dock posts, net-drying rack, crab pots and barrels, driftwood, shell rock, sea grass, old anchor | dune grass and rocks | **Lighthouse** (2×2 tall, 12-frame beacon) |
| Slagcrown (25–30) | basalt ×3, ash ×2, lava crack (12-frame glow) | basalt columns ×2, charred tree ×2, lava vent (12 f), ember rock, obsidian shard, slag heap, iron chain post, cooled lava boulder | basalt cliff | **Magma Gate** (2×2, glowing cracks) |
| Eastmarch Fen Edge (25–30) | fen grass ×3, mud ×2 | willow ×2, reed clump ×2, cattails, broken fence, mossy log (2×1), rotting cart, mud puddle (decal) | willows and reeds | **Leaning Watchtower** (2×2, old timber) |
| Gloomfen Mire (30–38) | bog ×3, peat ×2, murk water | drowned stump ×2, dead tree with hanging moss ×2, reed bed ×2, lily pads (decal), lantern buoy (glow), fallen log (2×1), bog bubbles (12 f) | dead-tree thicket | **Sunken Bell Tower** (2×2, half-drowned spire) |
| Stormspire (35–40) | slate ×3, wind grass ×2, rain-wet stone | wind-bent tree ×2, jagged slate rock ×2, copper conduit pipe, glowing rune stone, cracked boulder, broken pylon, storm grass | jagged rock ridge | **Lightning Pylon** (2×2 tall, 12-frame arcs; matches Thunderwell) |
| Ashen Shardfields (38–45) | ash dune ×3, glass sand ×2 | crystal shard cluster ×3 (violet / cyan / pink), petrified tree, giant ribcage (2×2), cracked obelisk, ash rock ×2, dune ripple (decal) | crystal ridge | **Great Crystal Shard** (3×3, soft violet glow) |
| Blightwood Hollow (45–50) | blight soil ×3, withered grass ×2, rot pool | twisted dead tree ×3, thorn bramble ×2, glowing blight fungus, gravestone, broken lantern post, bone pile, hanging cage, black rock | twisted-tree wall | **The Hollow Heart Tree** (3×3, giant dead tree, violet glow) |

**Accept, per PR:**
- Technical Artist asset check passes: sizes, anchors, alpha, atlas entries.
- The placement rules and connectivity tests pass, and all suites are green.
- **Media:** before/after stills of the entry, hub and door chunks of each
  region, shown **beside the painted Crosshaven Crossroads** at the same zoom
  as the quality bar.
- Frame time on the region's densest chunk is no more than 15% above the
  Crossroads.
- Painted fantasy, never 3D. Nothing copied from another game.

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

Set part icons (Scenario): one painted inventory icon per part: 43 sets × 5
parts = **215 icons** (30 class sets, 11 dungeon sets, 2 shared), plus a Rare
border. Also an icon for each unique extra (11 recipes, 11 materials, 11
decorations).
**128×128 px** at 2x, transparent background, the class's colours, the tier
shown by material (cloth / leather at 1–10, metal at 20–30, glowing
materials at 40–50). Path `art/items/sets/<set_id>/<slot>.png`.

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

#### WP20: Rented houses (Code + Scenario), **after the map; shared spots need the server**

Mauro's rules in 4.16: a few spots per map, weekly rent in Crypto Coins,
premium only; farm plants and trees, keep pets, cook, make potions, decorate.

- **Add (when started):** `data/world/houses.json` + schema (spots per map,
  sizes, rent, garden plots); `backend/pc_houses.gd` (rent, grace, lock,
  move-to-bank; garden growth by real time; pure logic for the server later);
  `scenes/world/house/house_interior.gd` / `.tscn` (garden, kitchen, alchemy
  table, pet corner, decoration grid, storage chest); house spot doors on the
  world map; `tests/run_pc_houses_tests.gd`.
- **Art (Scenario):** a cottage, house and manor exterior per region style
  (2×2 / 3×3 / 4×4), interiors, garden plots with growth stages, kitchen and
  alchemy props.
- **Accept:** rent is taken weekly from the bank; grace then lock; nothing is
  lost on lock; only premium players can rent (Q15); garden yields stay under
  the cap; spots per map hold.
- **Order:** after the map is finished; the shared spots need the online
  server (Q9). A private single-player version can be prototyped earlier only
  if Mauro asks.

#### WP21: Pets (Code + Scenario)

- **Goal:** each dungeon boss drops its mini pet; a Pet slot; every pet gives
  every class its class bonus plus its own perk (4.17). Premium only (Q15).
- **Add:** `data/world/pets.json` + schema; `backend/pc_pets.gd` (pure logic);
  a Pet slot in the equipment panel (4.15); the pet following the walker in
  the world; `tests/run_pc_pets_tests.gd`.
- **Accept:** all 11 dungeons have a pet; every pet has a bonus for all 5
  classes; bonuses stay within 2–6% and are off in PvP; each perk works; a
  non-premium player can collect pets but not use them.

#### WP22: Mounts and breeding (Code + Scenario)

- **Goal:** mounts give world speed and bonuses; breeding at the Stable makes
  foals and new hybrid breeds (4.17). Premium only (Q15).
- **Add:** `data/world/mounts.json` + schema (breeds, hybrids, caps);
  `backend/pc_mounts.gd` (speed, bonuses, breeding, inheritance, generation,
  breeding limits; pure logic); a Mount slot; a Stable panel;
  `tests/run_pc_mounts_tests.gd`.
- **Accept:** speed only out of combat and never above +60%; bonuses never
  above their caps after any number of generations (simulated); each mount
  breeds at most its limit; hybrids appear only from the right parents;
  premium rule holds.

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
7. ~~**Crosshaven walker facing fix**~~ **Handled by the other team** (Mauro,
   3 Oct 2026). The build team does not touch the walker or its facing.
8. ~~**Where Eastmarch Fen Edge sits**~~ **Answered 3 Oct 2026 (Mauro):
   option 1, off the east road.** Its entry branches off
   `crosshaven_road_east`, before Eastmarch town; Eastmarch town stays the way
   to Brinewake. Fen Edge leads on to Gloomfen Mire.

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
12. ~~**Stat name clash**~~ **Answered 3 Oct 2026 (Mauro): yes.** The PC stat
    is **Resist** (more resistance), so it no longer clashes with Mender's
    spell "Ward" (a shield). The four stats are Mastery, Vitality, Swift,
    Resist.
13. ~~**Epics and Relics after the balance review**~~ **Answered 3 Oct 2026
    (Mauro): yes** to the 8 slots, the rarities, the 5 Epics and 3 Relics in
    4.13, the AP cap 8 / MP cap 5, and Prism Striders' push rule counted per
    fight (a blocked push counts). The fixes in 4.14 are approved; the
    numbers stay tuned by WP15.
14. ~~**Inventory capacity**~~ **Answered 3 Oct 2026 (Mauro): "yes to both"**:
    a slot limit and a weight limit (4.15, numbers Proposed).
15. ~~**Premium**~~ **Answered 3 Oct 2026 (Mauro): premium requires a real
    money payment** (4.18). Built after the online server; every premium
    check goes through one function so it can be switched on later.
16. **Premium details (4.18):** ~~real money buys premium only?~~ **Answered
    3 Oct 2026 (Mauro): yes.** Perks answered: XP, coins, drops, fast travel,
    premium cities later (sizes Proposed). **Still Open:** which store(s)
    (Steam, own website, other), the price, and the billing period.
17. ~~**Swift in Koliseo PvP (4.11).**~~ **Answered 3 Oct 2026 (Mauro):
    option C, keep Swift as it is.** "The point is to have initiative to have
    any type of advantage over the other player, that's why the player decides
    if he wants to go first over damage." Going first is a chosen edge: all
    Swift beats all Mastery about 63% and is even against Vitality (50%) and
    Resist (49%), so Swift counters damage builds and tanky builds answer it.
    No first-turn rule. The 45–55% band in 4.11 does **not** apply to
    "all Swift vs all Mastery" (allowed up to 65%); every other pair keeps it.
    Resist cap 33% is **Soft Lock**. (An earlier option-A note from the same
    day is withdrawn.)
    **Swift keeps its damage** (Mauro, 3 Oct 2026, final: "without that small
    damage a Swift build loses about 90% of its fights, which would trap
    players who choose it. You are correct, leave as it is"). A short-lived
    "Initiative only" change the same day is withdrawn.
    **No cap on Swift** (Mauro, 3 Oct 2026: "that's something the player
    decides… give the player the decision to build their own build, but at
    the same time keep it as balanced as we can"). Every point can go
    anywhere, 0 to 98. Swift's +0.35% damage per point is the trade: each
    Swift point gives about 70% of a Mastery point's damage plus Initiative,
    so going first always costs some damage. Without it, an all-Swift build
    loses about 90% of fights.
