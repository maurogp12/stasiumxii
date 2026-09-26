# Ship log

Durable record of feel passes on the mobile track. Kit numbers in here are reminders of what stayed Locked. They are not a second source of truth. The legal sentences live in `docs/STASIUM_XII_GDD_handoff.md`.

## 2026-09-26 — Mobile hub menu

Look target is Luca's hub mock: dark navy ground, gold serif chrome, a thin gold frame with corner brackets and four-pointed stars, a Koliseo hero banner, and a RAID row of five stasis portraits. Mobile branch only. This hub is not ported to PC `main`.

### Player-visible

- F5 no longer opens a vertical stack of plain buttons.
- **STASIUM XII** sits top-left in Cinzel, with a star and a gold rule.
- The Koliseo banner (Kestrel, Ironjaw, Mender, Gloam, Bastion, and the gold **KOLISEO** label) opens `scenes/class_select.tscn`.
- **RAID** heads one row of five tiles. The plates read CROSSHAVEN STASIS, BRINEWAKE STASIS, SLAGCROWN STASIS, WINDMERE STASIS, and STORMSPIRE STASIS. Each tile still sets `MobileHub.pending_biome_id` and opens `scenes/stasis_run.tscn`.
- Button text stays `Koliseo` and `Crosshaven Stasis` (Title Case). That is what `door_text` and the hub tests read. The uppercase words are painted on the art.
- At 960×720 each tile is about 178×250, above the 72px floor. A taller viewport keeps that poster and moves the footer star to the bottom edge.

### Files

- `scenes/mobile_hub.gd` — layout, frame, and the same Koliseo / Stasis handlers
- `art/ui/hub/` — banner, five raid crops from the mock, Cinzel Semibold, OFL
- `tests/run_mobile_hub_tests.gd` — art files exist, and the tile signals still set the biome
- `docs/mobile_hub.md`

### Intentionally not changed

- Locked kit numbers, AP/MP, ranges, and damage.
- Ambush and Shade. No Ambush that does not come from a Shade (or from Gloam while Invisible).
- No cosmetics.
- Stasis stays on `mobile`. It was not ported to `main`.
- No APK version bump and no APK cut.
- Biome ids stay `crosshaven`, `brinewake`, `slagcrown`, `windmere`, `stormspire`. Door names Threshgate, Tidehold, Ashmarch, Galevault, and Coilgate stay on the run screen.
- `--dedicated`, `--class`, `--queue`, `--join`, and `--host` still skip the hub.

### Tests (headless Godot 4.7.2, 0 failed)

| Suite | Passed |
| --- | ---: |
| Mobile hub | 178 |

`godot --headless --path . --quit-after 2` loads the hub and exits 0. Combat, VFX, and motion suites were not re-run. This pass does not touch them.

## 2026-09-26 — Rosebud feel / chrome pass

Compared the current `mobile` tip (Batch-1c feel, Stasis unpark, Ambush teleport, Shade tile, APK 0.1.17) with the Rosebud Gloam combat reference. The hypothesis held: tile spawn and the Ambush teleport destination were already in place. This pass is chrome readability and aim feedback.

### Player-visible

- Selecting a legal **Ambush** draws a dashed red arc from the Shade to the enemy, and a predicted damage float over that enemy (a backstab sample reads `-30`). While Gloam is Invisible the same arc starts on Gloam. A Shade that is not yet a legal origin draws neither.
- The Ambush **back tile** highlight is blue, so the legal landing is distinct from the gold range cells. The range is still measured from the Shade.
- Other armed spells draw the same arc from the caster to the hovered in-range cell. A hovered body shows the predicted connect float (`-8` on a front Mark Shot, `+` heals, `+` shield).
- An Ambush **miss** whiff leaves the Shade (or Gloam, while Invisible) and the float stays `MISS`. The body does not streak across the board.

Already on the tip, and left as they were: Drop Shade's marker lands on the clicked tile with the Shade plate and token; the Shades count follows live tokens; the Ambush button stays soft-grey until `legal_intents` contains the cast; a legal Shade wears the loud Ambush plate; a hit snaps to the back tile, faces the prey, plays the purple slash, and removes that Shade in the same beat.

### Files

- `backend/combat_sim.gd` — `aim_feel` presentation helper
- `backend/net_session.gd` — forwards `aim_feel` while online
- `board/aim_line.gd` — dashed arc and float
- `board_view.gd` — paints the line from the armed spell
- `board/tile.gd` — legal landing blue
- `vfx/vfx_router.gd` — Ambush miss whiff origin
- `tests/run_combat_tests.gd`, `tests/run_vfx_tests.gd`

### Intentionally not changed

- Ambush-without-Shade stays parked in `docs/things_to_review.md`.
- Locked kit numbers and origin rules stay: Drop Shade 1 AP / 0 MP, Chebyshev 1–3, empty tile, LOCK Neutral, +1 Shade (max 2), duration 3, geometry marker. Ambush legal iff origin is the caster while Invisible, otherwise a live Shade that has seen the opponent complete at least one turn; cardinal row/col; Manhattan 1 or 2; empty back tile; AP at least 4. Cost 4 AP / 0 MP. Resolve teleports, then hits 22 FLEX. A Shade is spent only on a Shade-origin hit. A miss does not teleport and keeps Shade and Invisible.
- No Open kit defaults, no Ambush 3 AP retune, no cosmetics.
- Stasis stays mobile-only. It was not ported to `main`.
- No APK version bump and no APK cut. A follow-up ships 0.1.18 after this merges.

### Tests (headless Godot 4.7.2, 0 failed)

| Suite | Passed |
| --- | ---: |
| Combat | 4509 |
| VFX | 438 |
| Motion | 1828 |
| Event hooks | 329 |
| Net session | 280 |
| Elevation chrome | 189 |
| Touch adapter | 403 |

### Pull request

https://github.com/maurogp12/stasiumxii/pull/135 into `mobile`. Not merged.

### 2026-09-26 follow-up — Rosebud beat check

A second pass against the reference beats. Locked destination stays the enemy back tile. Batch-1c walk cycles stay.

- Drop Shade no longer travels. The token pops on the tapped tile with a floating "Shade" label and a purple outline.
- While Ambush is legal and selected, the Manhattan 1–2 cardinal cells paint blue from the Shade (from Gloam only while Invisible). The back tile stays the landing.
- The action line under the board is larger (`Selected: Ambush · 4 AP / 0 MP · range …`) and still adds "Ambush from Shade" only when the cast is in `legal_intents`.
- A backstab float is the large bouncing number (`BACKSTAB` at 1.55). The coach line stays the smaller clinical log. The button stays soft-grey until AP and Shade geometry are legal. Consume, snap, face, and slash stay on the same beat.

Headless recount after this follow-up, 0 failed: combat 4510, VFX 439, motion 1828, touch adapter 403.

## 2026-09-26 — Stasis-1 two-room boards and package foes

Luca’s phone repro showed Ironjaw-looking foes and a four-step trash chain (1/3, 2/3, 3/3, boss). The Stasis-1 package sheet locks the grammar at two rooms. This pass is mobile-only. It does not port Stasis to `main`, and it does not bump or cut an APK.

### Player-visible

- Each door is **Room A, then Room B**. Room A is one combat. Scarecrow Drudge, Grain Hound, and Threshling (and the other doors’ three trash) stand on the board together. Each living trash takes a turn after the player. Clearing that fight offers **Enter Room B**. Room B is the boss alone. The 1/3 counter is gone.
- Foe portraits are crops of the package concept sheets in `art/stasis/foes/`. Warden of the Sheaves is the scarecrow at Ironjaw height in the 144×160 canvas. Trash are shorter. The pawn does not play the Ironjaw strips. Strike still resolves on Ironjaw’s Locked card, because Strike is not on the other four kits. That class id is the card owner, not the drawing.
- Boards are `art/maps/stasis_v1/{biome}_room_{a|b}_15x15_tags.json`, approximated from the schematic JPEGs in the package (mud furrows and a water trough, a mud ring, tidal channels, a lava spoke and lava ring, meltwater, a water/mud cross, hay / reef / dais / throne elevation, paint-only sparks and the other props). Koliseo still loads `arena_colosseum_v2`.

### Choice

CombatSim grew a Stasis-only pack: extra hostile seats, casts against each of them, and the match ends when the player falls or the last hostile falls. Koliseo never passes `stasis_roster` with more than one hostile, so its 1v1 path is unchanged. Trash HP stays **22** and attack base **6** (boss **56 / 10**). Those stay provisional Open. Three full turns are hotter than the old sequential duels; Balance has not retuned them.

Coilspire’s sprite is the Coilgate door-sheet crop (spider body, tesla coils), used with the evolution sheet as a silhouette check. The 4★/5★ forms are not a separate fight.

### Files

- `backend/stasis_catalog.gd`, `backend/stasis_ai.gd`, `scenes/stasis_run.gd`, `scenes/stasis_fight.gd`
- `backend/combat_sim.gd` — pack seats, gated on the Stasis roster
- `backend/cell_tag_map.gd` — optional `map_id` on a tags file so a room keeps its biome dress
- `units/pawn.gd`, `ui/hud.gd` — package portrait, hostile seat tint
- `art/stasis/foes/`, `art/maps/stasis_v1/`
- `docs/mobile_stasis.md`, `tests/run_stasis_tests.gd`

### Intentionally not changed

- No Ambush or Shade Locked edits. No cosmetics. No `data/kits.gd` writes.
- No APK version bump and no APK cut.
- Stasis stays off PC `main`.

### Tests (headless Godot 4.7.2, 0 failed)

| Suite | Passed |
| --- | ---: |
| Stasis | 346 |
| Mobile hub | 168 |
| Combat | 4510 |

### Pull request

https://github.com/maurogp12/stasiumxii/pull/137 into `mobile`. Not merged. No APK.

### 2026-09-26 follow-up — one creature per foe portrait

The last `art/stasis/foes/` cuts still mixed neighbors. Warden of the Sheaves held a scythe scrap plus two beasts. Captain Brineclaw held dock and a teal bird. Scarecrow Drudge held two figures side by side. Each file is cut again from that door’s concept sheet, around the labeled illustration only. One creature, transparent field, 144×160. Tall drawings (Warden, Captain Brineclaw) stand near Ironjaw height. Wide bosses (Slagheart, Serra with the glaive, Tyrant Coilspire) stay full-body and therefore shorter. Trash stay shorter. Filenames and catalog wiring are unchanged. No APK.

## 2026-09-26 — Koliseo boards feel alive

Look target is Dofus Koliseo: an isometric tactical arena that reads as a place, with a wind-up before the cast and a hit you can see. This pass is paint, weather, and motion chrome on the five Locked arenas. Original STASIUM sheets only. No Dofus art.

### Player-visible

- Crosshaven, Brinewake, Slagcrown, Windmere, and Stormspire keep their existing diamonds and get a jewel grade: emerald, sapphire, amber, ice, and amethyst, with a north-lit falloff and a slow sheen. Water and lava shimmer harder than stone. A higher tile is a little brighter than the one under it. A dark grid line and a pale gleam outline every diamond, and the outer edge of the board glows.
- Each arena drifts its own weather over the board, under the Shade plate and the aim line. Crosshaven lifts grass motes. Brinewake blows a sea breeze. Slagcrown sends ash up off the lava. Windmere drops ice dust. Stormspire flickers violet sparks. A soft additive light wanders the middle of the diamond.
- Walk still turns into the step before the body moves, and the walk cycle stays at rest scale. The step bounce is 6px, the top of the 4–6px band, so the plant has more weight. A missing walk strip squashes and stretches a little harder.
- Casts dip further, rise higher, and point farther toward the effect. The wind-up squash is wider and shorter. Hits knock 6px, shake harder, and squash the body (including the hit strip). Death collapses by the middle of the beat and holds the last cell; the authored collapse plays faster so that hold has time inside the 0.6s lock.
- Skill VFX is the same recipes. Sparks burst hotter and farther with a white core. Shots carry a glow under a brighter head. Impact rings pop out and back. Heals rise faster. Ranges, costs, and damage are the same numbers.

### Files

- `board/koliseo_ground.gdshader` — contrast, north light, sheen, pulse
- `board/koliseo_life.gd` — per-arena grade and weather
- `board/tile.gd` — grade on ship sheets, depth rim
- `board_view.gd` — applies the grade and owns the weather layer
- `units/view_motion.gd`, `units/pawn.gd` — step weight, cast coil, flinch, death hold
- `vfx/vfx_spark.gd`, `vfx/vfx_projectile.gd`, `vfx/vfx_ring.gd`, `vfx/vfx_puff.gd`, `vfx/vfx_motes.gd` — punchier playback of the existing recipes
- `tests/run_koliseo_maps_tests.gd`, `tests/run_motion_tests.gd`

### Intentionally not changed

- Locked kit numbers, AP/MP costs, ranges, and damage.
- Ambush legality. Ambush-without-Shade stays parked. No Ambush that does not come from a Shade (or from Gloam while Invisible).
- No line-of-sight or fog rules. Those stay Open.
- No cosmetics, no gender, no recolor of the fighters.
- Stasis stays on `mobile`. It was not ported to `main`.
- No APK version bump and no APK cut.
- Proto boards and unknown map ids are not dressed as a biome. They keep the flat fill.

### Tests (headless Godot 4.7.2, 0 failed)

| Suite | Passed |
| --- | ---: |
| Combat | 4510 |
| VFX | 439 |
| Motion | 1846 |
| Koliseo maps | 278 |
| Event hooks | 329 |
| Net session | 280 |
| Elevation chrome | 189 |
| Touch adapter | 403 |
| Stasis | 187 |
| Sprite | 234 |

### Pull request

https://github.com/maurogp12/stasiumxii/pull/136 into `mobile`. Not merged.

### 2026-09-26 follow-up — Rosie jewel grid

The Rosebud arena pass asked for jewel tiles, a readable grid, a glowing board edge, a landing on the walk, a hand on the action, and brighter skill flashes. Same five arenas, same original sheets, same Locked numbers.

- Tile grades push further into emerald, sapphire, amber, ice, and amethyst. Windmere stays cool and still reads as a 15×15 grid with Kestrel and Ironjaw on it.
- Each diamond draws a dark ink line and a pale gleam on a child, so the grade shader does not wash the grid out.
- The outer diamond of the board glows in that arena's light and breathes.
- A walk still faces the step and bounces 6px at rest scale. When the path ends, the body squashes into the tile and releases. Feet stay planted.
- Casts and lunges reach a small hand along the aim. It hides at rest. It is the same mark on every fighter.
- Sparks and impact rings are brighter. Recipes, ranges, costs, and damage stay the numbers they were.

Headless recount, 0 failed: Koliseo maps 278, motion 1846, combat 4510, VFX 439, elevation chrome 189, sprite 234, stasis 187, touch adapter 403.

### 2026-09-26 follow-up — Rosebud energy

The Windmere capture after the Rosebud pass is a glacier field: cyan, teal, ice, lavender, and a rare gold, a dark grid, and a cyan-white rim on the board and the active fighter. The five Locked arenas take that energy in their own colors. Original sheets only. Combat numbers unchanged.

- Each diamond stains toward its own jewel and keeps the sheet's cracks. Windmere is cyan, teal, ice, and lavender, with a gold cell on a rare step. Crosshaven, Brinewake, Slagcrown, and Stormspire use their own four stains plus that same rare gold.
- Grid ink is thicker and nearer black, with a cool gleam, still drawn on a child so the grade does not wash it out.
- The board edge is a brighter arena-colored halo with a white core. The active fighter gets the same cyan-white bloom. Sprites keep their colors. A dark foot shadow keeps them readable on the bright tiles.
- A procedural sky and ridge sit behind the diamonds. An unknown map stays bare.
- Skill sparks and rings are brighter and still use the spell tint. Walk gait, landing squash, and the shared hand mark are the ones already shipped. No kit change, no Ambush change, no APK bump.

Headless recount, 0 failed: Koliseo maps 285, motion 1846, combat 4510, VFX 439, elevation chrome 189, sprite 234, stasis 187, touch adapter 403.

### 2026-09-26 follow-up — Dofus readability, Rosebud board discarded

The icy jewel board (cyan, lavender, gold stains, glowing rim, active-unit bloom) is not the look. The target is a readable Koliseo: warm painted biomes, a clear ink grid, unit sprites with walk and cast juice, and spell flashes that read on a busy board. Original STASIUM sheets only.

- Tile grades only lift contrast on the existing grass, sea, ash, snow, and storm sheets. They do not replace a cell with a flat stain.
- The grid is a warm ink stroke with a parchment gleam. The outer edge is the same ink. There is no colored rim.
- Weather motes and a dim sun stay subtle. The active fighter is marked with a small warm ring at the feet.
- Walk landing, the shared cast hand, and the brighter spell-tinted sparks and rings stay. Kit numbers, Ambush, and the APK do not.

Headless recount, 0 failed: Koliseo maps 283, motion 1846, combat 4510, VFX 439, elevation chrome 189, sprite 234, stasis 187, touch adapter 403.
