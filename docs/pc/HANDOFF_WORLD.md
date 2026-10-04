# PC world handoff

PC only. Never merge into `main` or `mobile`. Do not push `cursor/water-regrade-a156`. Claude owns #251.

Usage was about to run out (Mauro, 4 Oct, [comment on #251](https://github.com/maurogp12/stasiumxii/pull/251#issuecomment-5981320229)). This file is the world-bot handoff. There is no uncommitted world code to rescue. L10, painted NPC wiring, the Northgate snow town, and WP7–WP9 were not started.

## Merged context

| Item | Branch | Last commit | State |
|---|---|---|---|
| #249 Drop Millrace | `pc/world-zones` | approved `ccb7c56`, merge `1cf6d46` | merged. Crossroads has no dungeon |
| #253 Town NPC stand-ins | `cursor/town-npcs-a156` | `4dc3b7d`, merge `ef3bcc9` | merged. Tint stand-ins only. Millrace rewards moved onto Old Granary Cellar |
| #250 Town NPC stand-ins (stacked on #249) | `cursor/town-npc-standins-a156` | `808d3d8` | closed as superseded by #253 |
| #251 Water regrade | `cursor/water-regrade-a156` | `e96cb73` (note), feature `d7b30f5` | open. Claude owns it. Do not push |

`pc/world-zones` tip at this handoff: `ef3bcc9`.

## #251 Water regrade (do not touch)

| Field | What |
|---|---|
| Item | Regrade repo water to the Eastmarch blue, shore, map edge |
| Branch | `cursor/water-regrade-a156` |
| Last commit | `e96cb73` (note). Feature `d7b30f5`. Prior visual feature `fc4371a`, note `2c874d1` |
| State | in progress, owned by Claude |
| Where you stopped | World bot pushed `d7b30f5` and `e96cb73` after a hands-off ack. Claude ordered no more pushes ([5980143569](https://github.com/maurogp12/stasiumxii/pull/251#issuecomment-5980143569)) and is taking the fix from `2c874d1`, merging those two commits in. Next step is Claude's, not this bot's |
| How to run | Godot 4.7.2: `/home/ubuntu/.local/bin/godot --headless --path . -s res://tests/run_outskirts_kit_tests.gd` then `run_outskirts_tests`, `run_crosshaven_zone_tests`, `run_crosshaven_world_tests`. Stills: `crosshaven_world.tscn -- --movie water_stills` (not headless). On `d7b30f5` those four suites were 18 / 214 / 24368 / 542, 0 failed |
| Files | `scenes/world/crosshaven/crosshaven_ground.gd`, `crosshaven_world.gd`, `docs/pc/media/water/`, `docs/pc/media/outskirts/eastmarch_beach.png` |
| Open problems | Claude has not approved `e96cb73`. `d7b30f5` put a sand lip on Northgate. Mauro's decision is a snow lip ([5979852925](https://github.com/maurogp12/stasiumxii/pull/251#issuecomment-5979852925)). The branch conflicts with `pc/world-zones` at `ef3bcc9`. Do not merge the base until Claude says the take-over is done |
| Decisions not yet in CHANGE_LOG_PC.md | Northgate shore is snow, not sand: one-cell packed snow with a little grey stone, soft foam plus a thin ice rim, 2–3 cell frost blend into neighbours, other towns keep sand. Until the painted kit lands, build that lip from the #241 frost and roof-cap whites |

## Not started

No local branch and no unpushed files for these. Do not invent them.

### L10 world walker

| Field | What |
|---|---|
| Item | L10 world walker and new characters |
| Branch | none |
| Last commit | none |
| State | not started |
| Where you stopped | Luca put new characters on hold before any walker wiring. Do not start until that hold lifts |
| How to run | n/a |
| Files | none |
| Open problems | Hold is still on |
| Decisions not yet in CHANGE_LOG_PC.md | Walker stays off. Do not wire Ironjaw or Kestrel |

### Painted NPC role sprites

| Field | What |
|---|---|
| Item | 19 painted NPC role sheets |
| Branch | none. Stand-ins shipped in #253 |
| Last commit | none for painted art |
| State | not started |
| Where you stopped | Data and placement are merged. Bodies are tinted class sprites. No `art/characters/world/npc/` folder was pushed |
| How to run | After a tarball lands, `tests/run_world_npc_tests.gd` and `tests/run_pc_missions_tests.gd` |
| Files | would be `art/characters/world/npc/`. Do not add them from an old tarball |
| Open problems | Wait for Luca's fresh tarball. Scenario Art was rewriting all 19 |
| Decisions not yet in CHANGE_LOG_PC.md | Do not push role sprites until that tarball arrives |

### Northgate snow town

| Field | What |
|---|---|
| Item | Northgate snow town kit swap |
| Branch | none. Brief is `docs/pc/look_target/northgate_snow/README.md` on `claude/pc-zones-spec`, plus Mauro's reference video |
| Last commit | none |
| State | not started. Parked until #251 is done and Scenario Art paints the kit |
| Where you stopped | Not begun. Next step, after the kit exists: kit swap, falling snow, emit-lit windows. Full daylight. The only snowy town. Snow ground, swept cobble, thick roof caps, warm windows and lamps, snow-capped chapel spire, snowy pines, snow-crusted edge |
| How to run | n/a until the kit is in the tree |
| Files | none in this repo yet |
| Open problems | Depends on #251 and on the painted kit |
| Decisions not yet in CHANGE_LOG_PC.md | Agent does the swap and particles. Scenario Art paints the kit |

### WP7 dungeon doors

| Field | What |
|---|---|
| Item | WP7 doors |
| Branch | none |
| Last commit | none |
| State | not started |
| Where you stopped | Queue after the snow town: doors, then Old Granary, then monsters. Do not start aggro early |
| How to run | n/a |
| Files | none |
| Open problems | Blocked on the queue above |
| Decisions not yet in CHANGE_LOG_PC.md | none beyond the queue order |

### WP8 Old Granary / dungeon runs

| Field | What |
|---|---|
| Item | WP8 Old Granary runs |
| Branch | none |
| Last commit | none |
| State | not started |
| Where you stopped | Same queue. Granary keeper already stands in Stoneford at (15, 12) via #253. The door is not built. Clear-dungeon steps stay coming soon |
| How to run | n/a |
| Files | none for the run |
| Open problems | Door and the run are not built |
| Decisions not yet in CHANGE_LOG_PC.md | none |

### WP9 world monsters

| Field | What |
|---|---|
| Item | WP9 monsters and aggro |
| Branch | none |
| Last commit | none |
| State | not started |
| Where you stopped | Do not start aggro before WP9, and do not start WP9 before WP7 and WP8 |
| How to run | n/a |
| Files | none |
| Open problems | Not begun |
| Decisions not yet in CHANGE_LOG_PC.md | Aggro stays off |

## How the world suites run

Godot 4.7.2 at `/home/ubuntu/.local/bin/godot`. From a clean worktree, `godot --headless --path . --import --quit` once, then do not commit `*.import` or `*.uid`. Then `godot --headless --path . -s res://tests/run_<name>_tests.gd`. There are 34 `tests/run_*_tests.gd` scripts. Do not run two Godot processes on the same project path. Suites that write `user://pc_progress.json` must not run in parallel. Stills are not `--headless`. Delete `override.cfg` if a capture writes one, and do not commit it.
