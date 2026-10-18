# Stasium XII: 3D slice (Crosshaven first)

Branch `claude/pc-3d-slice` (from `claude/pc-crosshaven-city`). Work in progress.

**Mauro's gate:** finish **Crosshaven in 3D** first. The 5 class heroes are also allowed. Nothing else moves until he approves it: no other cities and no other content.

**Mauro's rule:** everything from the current Stasium game carries over unchanged. Only the look becomes 3D:
- the classes, spells and rules;
- gear, dungeons and monsters;
- the Koliseo PvP and its maps;
- player housing.

The combat engine (`backend/combat_sim.gd`) and its tests are untouched. 3D is a presentation layer.

---

## 1. How to run

- **Walk Crosshaven:** `godot --path . res://slice3d/city3d.tscn`
  - Options: `-- --hour=19 --class=ironjaw`.
- **Controls:**
  - left click: walk; Shift: run;
  - right-drag or Q/E: orbit; wheel: zoom;
  - middle-drag or WASD: pan; Space: follow the hero again;
  - T: +1 hour; N: day, dusk or night.
- **Tests:** `godot --headless --path . -s res://tests/run_slice3d_tests.gd`
- **Media:** see `tests/pc/capture_city3d.gd`. Sets: `stills`, `keyart`, `clip`, `gate`, `hero`, `classes`, `ironjaw`, `lineup`.

## 2. What is built

### 2.1 Generic city builder (`slice3d/city/`)

City layout data goes in, a 3D scene comes out. Only Crosshaven is built for now, but nothing in the builder is specific to it.

| File | Job |
|---|---|
| `city_plan.gd` | Reads `data/world/city3d/<city>.json`. Crosshaven's source is the approved modular layout `data/world/crosshaven_city/tilemap.json` (built from `streetplan.json`), read through the existing `TileCity`, so 2D and 3D agree on every cell. It also traces the ring's centre line, finds the bridges, and blocks the gatehouse pillars on the walk grid. |
| `city_builder.gd` | Builds the scene: terrain mesh with splat colours, water, ring walls, towers, gatehouses with opening doors, water tunnels, bridges, landmarks, houses, player plots, workshops, the mill wheel, props, lamps, window glow, chimney smoke, and woods around the walls. Repeated pieces are batched into MultiMeshes. |
| `mesh_kit.gd` | Placeholder primitives, palette materials, the roof prism, and batching of models. |
| `model_loader.gd` | Loads `.glb` files at run time (GLTFDocument), so new models need no editor import. `art/3d/` has a `.gdignore`. Kit materials are drawn double-sided and dielectric (see §6). |
| `nav_grid.gd` | The walk grid from the layout (the same `passable` rule as 2D), A*, then line-of-sight smoothing, so walks glide in straight legs. |
| `foliage_wind.gdshader` | Wind for kit plants. It reads the vertex colours (R sway, G phase, B flutter) and uses alpha scissor for the leaf cards. It is used only on meshes that carry the colours, which are never used as tint. |
| `city_env.gd` | Sun, sky, fog, tone and colour grade, and the day/night clock from the city file's keyframes. Lamps and windows light at night. SSAO and SSIL are on for Forward+. |
| `city_life3d.gd` | The city's NPCs at their role posts, keeping the 2D city's day (home, work, plaza at noon, evening, home), with "!" over mission givers. Townsfolk stroll the streets by day. |
| `hero3d.gd` | Click-to-walk hero; class switch; model, clips and weapons from data. |
| `camera_rig.gd` | High-angle 3/4 camera with orbit, zoom and pan. It pulls in so it never sits inside a house while following the hero. The same camera will serve combat. |
| `humanoid_retarget.gd` | Meshy rig to `SkeletonProfileHumanoid` bone names, on the skeleton and the clips; clips play in place. |
| `ui/city_hud.gd` | Place card and clock, class picker, hotbar with the class's real spells (AP, range, element, damage tooltip), AP/MP, End Turn (combat only), round portrait with HP, minimap. Dark panels, thin gold borders, serif type. |

### 2.2 Data (`data/world/city3d/`), all Proposed

| File | Content |
|---|---|
| `crosshaven.json` | Source, cell size, water, terrain palette, materials, day/night keys, grade, outskirts, and the **kit** block: wall, tower, gatehouse, tunnel, bridge, landmarks, houses, workshops, props. Each entry is a `.glb` path plus fit rules. A missing file falls back to the placeholder. |
| `scale_table.json` | Placeholder sizes in metres per piece kind. |
| `classes3d.json` | Which character each class uses (first model that exists). |
| `clip_map.json` | The 18-clip standard and the Meshy library action used for each clip. |

### 2.3 Crosshaven checklist

| Item | Status |
|---|---|
| Ring with 12 towers (slate cone roofs) | Done (art kit) |
| 4 land gates with opening doors | Done. The art kit gatehouse is scaled 1.3. Our timber doors swing inward when the hero is within 14 m. The pillars block the walk grid; the passage stays walkable. |
| 2 water tunnels | Done (art kit) |
| River and 4 stone bridges | Done (art kit). The hero walks the arched deck. |
| Castle (N), cathedral (centre), town hall, bank | Done (art kit, at modelled size) |
| W crafts quarter and the mill | Done (art kit workshops). Our wheel turns until the art team's wheel and mill-race arrive. |
| About 60 NPC houses | Done (art kit a–i, facing their doors) |
| 10 player plots in 3 tiers | Done (art kit houses with tier-coloured edges and labels) |
| Gardens, gazebo, fountain, well, stalls, lamps, trees, bushes | Art kit. Trees (oak, birch, pine, cypress, a–c) use the foliage wind shader. The fountain water uses our water shader. Lamppost glass glows at night, plus a light. Hedges, flowerbeds and small flowers are still placeholders. |
| Player plot fences | Art kit fence modules round each plot, with the gate on the door side |
| Woods round the walls | Art kit tree impostors (2 crossed quads) |
| Ground | Art kit terrain v2 (8 PBR sets, resized to 1024; heights 512). One material per layout cell, height-blended per pixel in `terrain_pbr.gdshader` (weight = max(0, h + splat − max + 0.15)). Rules in `crosshaven.json` `terrain_pbr`: cobbles on streets, flagstones on the plaza and landmark forecourts, dirt paths, pebbles on the river and its banks, gravel at the wall foot, mud at the gate approaches and the mill, short and lush grass mixed by noise. A second cobble variant can be added as a new material id. |
| Day/night, lamps, city life | Done. City NPCs and role NPCs wear the art kit's 12 NPC bodies (data: `npcs3d.json`): story NPCs at their city posts, the blacksmith at the smithy, the merchant at the stalls, the priest at the cathedral, and a guard at each gate. Each NPC walks a work loop; the route text in its JSON becomes waypoints round its post, with its work idles in between, and it never stands still more than about 10 s. They keep the 2D day (plaza at noon, home at night). Townsfolk (peasants, child, elder, noble, merchant) stroll the streets. The guard's spear waits for its attach offsets. |
| Walkable in 3D | Done: the hero reaches every gate, NPC, plot door and bridge (tests) |

**Scale:** 1 layout cell = **1.5 m**, so the approved street plan's 3×3-cell houses fit the house kit's 3–5 m footprints and streets come out 3–6 m wide. The hero is 1.8 m. Heights follow `docs/pc/skills/3D_ART_SKILL.md` §3.

## 3. Character standard (ours and the art team's)

- **Rig:** the Meshy humanoid rig, retargeted to Godot's **SkeletonProfileHumanoid** bone names.
  - Meshy's spine runs Hips > Spine02 > Spine01 > Spine, which maps to Spine, Chest and UpperChest.
  - Rigs already on humanoid names are left as they are.
- **Clips:** lowercase snake_case, 30 fps, in place (no root motion):
  `idle, walk, run, turn_l, turn_r, attack_melee_1, attack_melee_2, attack_ranged, cast, hit, block, push, dodge, downed, death, interact, sit, victory`.
  - Our files: `art/3d/characters/<name>/<name>_<clip>.glb` (animation only), next to `<name>_rigged.glb`.
  - A model with its clips inside (Ironjaw) is used as delivered.
- **Facing:** the model's front is +Z. The hero code turns +Z toward the walking direction, so no extra 180° turn is needed in our setup.
- **Weapons:** `BoneAttachment3D`. The offsets are read from the rig JSON (`weapons.attach`, `weapons.holster`, per-clip `axe_mode` and `holster_offset`), never hard-coded.
- **Classes:** the hero can be any of the 5 classes, with its real spell bar from `data/kits.gd`. The models:

| Class | Model | Made by |
|---|---|---|
| kestrel | kestrel_male | us (Meshy) |
| ironjaw | ironjaw_male (25 clips, grip v3) | art team |
| mender | mender_male | us (Meshy) |
| gloam | gloam_male | us (Meshy) |
| bastion | bastion_male | us (Meshy) |

`hero_male` is the stand-in for any class whose model is missing.

## 4. Combat in 3D (next, after Crosshaven is approved)

- **The plan:** render the existing engine, without new rules.
  - The 3D board maps each tile to world metres. The tile size and height per level are data.
  - The same camera as exploration, with a seamless switch.
  - Units are the class heroes and monsters from the existing dungeon data.
  - The view consumes CombatSim events (`move`, `hit`, `miss`, `push_*`, `dead`, `turn_start`...) as animation steps.
- **UI (Luca's reference):**
  - initiative portraits at the top centre;
  - hotbar with AP/MP and End Turn at the far right (already built);
  - portrait with HP at the bottom left (built);
  - minimap (built);
  - move preview: path line, ghost of the hero, MP cost, reachable tiles;
  - targeting: hit/crit chance at the cursor, predicted HP loss on the enemy bar, spell tooltip.

## 5. MMO groundwork

- **The rules are already server-authoritative.** CombatSim takes intents in, returns events and snapshots, uses seeded rolls, and keeps an intent log. `backend/net_session.gd` and `host_validate.gd` already validate and replay. The 3D client only submits intents and plays events.
- **Multiplayer path:**
  - one rules instance per fight (dungeon room, open-world encounter, arena match) on the server;
  - clients get events and snapshots;
  - Koliseo PvP runs the same way, with the turn clock owned by the host;
  - territory war comes later, as scheduled instances per region.
- **City:** the walk grid and the layout are deterministic data, so a server can validate moves on the same grid.

## 6. Notes for the art team (relay)

- **Houses and landmarks read as ruins.**
  - The LOD1 meshes of the houses (a–i), cathedral, castle, town hall and bank have many holes.
  - Their albedo is dark grey-brown. There are no plaster walls and no red tile roofs, as there are in the key art.
  - Faces are drawn double-sided as a stop-gap.
- **All kit materials ship with metallic = 1** and a metal map. We render them with metallic 0, because stone and timber looked black.
- **Ironjaw grip v3** looks right in our test:
  - idle and walk: axes in the fists;
  - attack: both axes swing;
  - sit: crossed on the back with the `holster_offset`.
  - No offset corrections from us yet.
- **WebP textures:** kept as WebP when we resize them (EXT_texture_webp), because Godot reads them natively.
- **NPC story cells:** Guide 24,18, Banker 20,20 and Herald 17,19 are Crossroads cells in `npcs.json`. Inside the walled city these NPCs keep their `city.json` posts.
- **Bridges:** we arch the walk height in data (`kit.bridge.deck_peak`) until the ramp collider is used.

## 7. Proposed for later (needs Mauro's approval; not in the rules)

These ideas from the first brief were dropped when Mauro kept the existing rules. They are not in any code:
- d20 rolls with advantage and disadvantage;
- Action, Bonus action and Valor turns;
- a high-ground hit bonus;
- shoving units off ledges;
- oil and fire surfaces;
- attacks of opportunity;
- lasting injuries;
- a boss shielded by totems;
- Wakfu-style optional challenges for bonus loot;
- an open-world bandit fight.

## 8. Meshy log

| Job | What | Credits |
|---|---|---|
| multi-image 01a14bb3 | hero_male (front, side, back crops of Grok's turnaround), textured PBR, 20k tris | 30 |
| rigging 01a14bb8 | hero_male rig, with free walk and run | 5 |
| animations | hero_male idle + 15 standard clips | 48 |
| multi-image 01a14bdd + rig 01a14be2 + 16 clips | bastion_male | 83 |
| multi-image 01a14be5 + rig + 16 clips | kestrel_male | 83 |
| multi-image 01a14be9 + rig + 16 clips | mender_male | 83 |
| multi-image 01a14bef + rig + 16 clips | gloam_male | 83 |
| **Total (ours)** | | **415** |

- Balance went from 2188 to 1633. The other 140 credits are the art team's Ironjaw (their `credits_log.csv`).
- No Ironjaw job was run by us.
- Textures are re-encoded to 1024 px. Clips are kept as animation-only files.

## 9. Tests

- `tests/run_slice3d_tests.gd` covers:
  - the layout (houses, 12 towers, 10 plots, landmarks, tunnels, gates);
  - the scale table;
  - the ring tracing;
  - gate passages through the gatehouse pillars;
  - reach from the spawn to every gate, NPC and plot door;
  - bridges;
  - path smoothing;
  - a repeatable build, and doors opening only near the hero;
  - day/night;
  - the hero walking without stepping on a blocked cell;
  - the humanoid retarget and the clip standard.
- The existing suites are unchanged: this branch only adds files.
