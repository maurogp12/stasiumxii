# Ship log

Durable record of feel passes on the mobile track. Kit numbers in here are reminders of what stayed Locked. They are not a second source of truth. The legal sentences live in `docs/STASIUM_XII_GDD_handoff.md`.

## 2026-09-27 — Detonate burst punch v3b

Presentation only. No APK. Kit numbers, Detonate legality, and Locked timings are unchanged. Soft Lock pending Rosie rematch.

`detonate_burst.png` is the v3b transparent strip: 1280×720, six beats (ignition, burst, shock, shards, fade, settle). The full-height divider columns from v3 (x=212–213, 426, 639–640, 852–853, 1066) are clear. Playback crops stay off those columns, so a ghost bar is not a frame. The burst still opens on the cast resolve and still uses the spell-overlay life (0.24s, inside 0.2–0.4s). The stamp plays this one strip.

## 2026-09-27 — Ambush slash strip v5

Presentation only. No APK. Kit numbers, Ambush legality, Invisible Soft Lock, the 22, and AP costs are unchanged. Soft Lock pending Rosie rematch.

`ambush_slash.png` is the v5 transparent strip: 1280×720, five cells (anticipate, wind, SNAP peak, settle trails, fade). Magenta/cyan. Scenario `asset_zCcVxFNBWSMQ1vzsgA2Dfp5S`. The gray cell frame and the black field are not played. Holds are 80+120+90+50+40 ms (380ms, inside 0.2–0.4s). The SNAP cell opens on the contact. The strip is anchored on the planted Gloam at the back tile and faces the struck body. The v4 peak plate stays unwired. The stamp plays this one strip.

## 2026-09-27 — Mark Shot cast bow v4

Presentation only. No APK. Kit numbers and ranges are unchanged.

`mark_shot_cast.png` is the v4 transparent strip: 1280×320, four equal 320×320 cells (draw, snap burst, reticle peak, arrow-tip release). Cyan/gold, from the bow. Scenario `asset_bXoujAQYZwDDQJQNGL2ouD7M`. The cast is 70+80+80+70 ms. It is not stretched out to the contact. The snap cell stays dense. The plate is 44px and is not dropped, so the rays stay on the hands and the reticle and the arrow tip still read. The bolt flight is 0.24s, so the existing contact stack (flash, compact burst, float, flinch) lands inside 0.2–0.4s after the arrow leaves. Impact stays the punch-v2 floor strip.

## 2026-09-27 — Bastion east walk v6b (Ironjaw v6b held)

Presentation only. No APK. Locked kit numbers, map geometry, and Ambush are unchanged. Gloam, Mender, Kestrel, and Ironjaw walks stay wakfu-ship-v5. Godot hop timing is unchanged: Bastion and Ironjaw crest stays 2.5px, tile time 0.30s, one stride per tile, plant hold the last 18%.

Bastion east is the wakfu-ship-v6b strip, in place: `art/export_2x/characters/bastion/anims/bastion_walk_e.png`, 864×160, six 144×160 cells. The same bytes are `art/export_2x/walk_src/bastion_walk_e.pngbin`. West is the per-cell horizontal mirror of that east sheet, same frame order, written to `walk_w` and its pngbin. Not a runtime `flip_h`. Bastion north and south stay the current v5 three-quarter strips.

The Ironjaw v6b east wire is discarded. On a phone it read as an incomplete pixel blob, not Berserker A + helm A2. Ironjaw east, west, and the matching pngbin files match `mobile` again. Hold Ironjaw until a complete east v6c (full plate, grill, and dual axes, no crop cutoff).

Known Bastion sheet notes, not blockers: flood-key holes and two near-duplicate frames. Judge stutter and flicker on the phone bake. Bastion hop is unchanged.

## 2026-09-27 — Soft Lock map presentation

Presentation only. Locked geometry, tags, walkability, and kit numbers are unchanged. No APK. Windmere ice punch is untouched. Brinewake stays the coast punch (wet sand, pier wood, water).

Crosshaven is the grassland sheet again, byte-matched to `ef474cd` (mobile parent of the earth punch). Punch-only `ground_v5`–`v7` and the extra cliff variants are gone so the picker cannot mix dirt back in. `slice_crosshaven_punch.py` refuses to run.

Slagcrown and Stormspire go further back than the #184 restore parents (`79eda27`, `fc2030d`). Those parents are the original-sheet / electric-contact look Luca rejected. The live dress is `171f5b5` (Raise Koliseo graphics): readable half-diamonds, with that commit's props copied onto `slag_prop_*` and `storm_prop_*`. Punch-only variants are deleted. `slice_lava_punch.py` and `slice_storm_punch.py` refuse to run. Scenario mood plates are not sliced.

## 2026-09-27 — Brinewake elevation v2, upper-corner deck gone

Soft Lock agua + costa. Presentation only. Locked Brinewake geometry, tags, walkability, and kit numbers are unchanged. No APK. `version/name` and `version/code` stay put.

The live elevation sheet is the regenerated punch without the upper-corner wooden deck. The earlier sheet that still had that deck is not the source. `slice_brine_punch.py` writes `brine_ground_e1.png`, `brine_mud_e1.png`, and `brine_ground_e2.png` from the remaining stairs. The cap is the upper deck. The stair hangs under it and stops on the lower deck in the same sprite. The high wall stays taller than the low wall.

Props from `art/tilesets/original/pending/brinewake/brine_props_punch.png` stay wired and about one tile tall. Ground, mud, and water stay the coast punch. `stasium-ref/maps/brinewake/elevation_punch.png` mirrors the regenerated sheet. The mood plate is not sliced.

## 2026-09-26 — Slagcrown lava punch redo

Soft Lock fuego + lava. Presentation only. Locked Slagcrown geometry, tags, walkability, and kit numbers are unchanged. No grass, moss, or bushes on the dress.

`slice_lava_punch.py` reads the new punch sheets and overwrites only `slag_*` and `slag_prop_*`. The earlier lava punch Luca rejected is replaced.

| Punch sheet | Live slices |
| --- | --- |
| `art/tilesets/original/pending/lava/ground_punch.png` | `slag_ground.png` and `slag_ground_v1`–`v4`, `slag_mud.png`, `slag_water.png`, `slag_lava.png` and `slag_lava_v1`–`v7` |
| `art/tilesets/original/pending/lava/elevation_punch.png` | `slag_ground_e1.png`, `slag_ground_e1_v1.png`, `slag_mud_e1.png`, `slag_ground_e2.png` |
| `art/tilesets/original/pending/lava/props_punch.png` | `slag_prop_basalt_pillar.png`, `slag_prop_rock_pillar.png`, `slag_prop_ash_rock.png`, `slag_prop_rubble.png`, `slag_prop_steam_vent.png` |

`slag_prop_floor_seal.png` is a small ash mark from the ground punch, not a full diamond. Flat tiles are hard 64×32 diamonds so the seam stays readable. Elevation keeps that cap and hangs the wall; the high wall is taller, and the stair meets the cap. Blocks cut off by the sheet edge are not used. The wide strip on the prop sheet is not sliced. `board_mood_punch.png` and `stasium-ref/maps/lava/luca_preview_slagcrown.png` are reference plates and are not sliced.

## 2026-09-27 — Combat pawn read (Bastion, Ironjaw)

Presentation only. No APK. Locked kit numbers and map geometry are unchanged. Wakfu-ship-v5 walks stay the motion sheets. `*_gen.png` is still not loaded.

The cyan jagged fringe is not in the v5 PNGs (no cyan pixels on E/S/N/W). `figure_read.gdshader` was sampling two and three texels out and painting a rim from neighbor alpha. Over Windmere ice that rim reads as a jagged cyan halo. Visible modulate is white, so Invisible was not tinting a shown body, and idle was not a stuck hit sheet.

Ironjaw's locked combat scale stays **1.0**, the same body scale as Kestrel and Gloam (`SPRITE_SCALE` 0.5). An open 1.25, and a one-class 1.20, do not ship.

Bastion and Ironjaw deploy/idle use the soft plants in `art/export_2x/characters/<class>/idle/<class>_idle_plant_<face>_v1.png` (144×160). Alpha under 20 is gone. The 20–254 band stays, so the silhouette is not a binary cut. The wakfu-ship-v5 walk strip still plays the stride. Kestrel, Gloam, and Mender still rest on walk frame 0. `_broken_harden_pass/` is not loaded.

## 2026-09-26 — Combat VFX punch v3

Presentation only. No APK. Post-0.1.26. Walk sheets on this tip are wakfu-ship-v5 (#177). This pack does not replace them.

The transparent punch-v3 pack lives under `art/vfx/scenario/`:

| Sheet | Path |
| --- | --- |
| Hit flash | `hit_flash.png` |
| Damage float | `damage_float.png` |
| Ambush slash | `ambush_slash.png` |
| Detonate | `detonate_burst.png` |
| Melee windup | `melee_windup.png` |
| Footstep dust | `footstep_dust.png` |
| Mark Shot bow | `mark_shot_cast.png` (same bytes as the attached bow; #175 timing stays 70+80+80+70) |

Mark Shot impact stays the punch-v2 floor strip. The bow windup stays 70+80+80+70 (bolt on frame 4); the draw is not stretched to the contact. Ambush still plants on the back tile, then slashes, then the same contact stack. Standing melee plays the windup on the caster and it ends as the contact starts. Dust puffs only on a facing change and the final plant, at the instant hop Y returns to 0 — not on every tile, not at takeoff, and not mid-air. On contact the flash, the compact spark, the float, and the flinch share the resolve on the target tile, and each one finishes inside 0.2–0.4s. A miss does not flinch. The hit flash keeps its cyan and gold. Locked kit numbers and map geometry are unchanged.

## 2026-09-26 — Wakfu walk strips v5

Presentation only. The next APK after 0.1.26 plays wakfu-ship-v5 walks. This note does not cut an APK and does not bump `version/code`.

The twenty strips replace the v4 sheets in place. Same names, same 864×160 layout, six 144×160 cells, same `.import` files, same `*_frames.tres` atlas slices (`x = 0, 144, 288, 432, 576, 720`). Device playback reads the same bytes from `art/export_2x/walk_src/*.pngbin`.

- One stride per tile, about 0.30s. The pawn faces into each segment. Arrival plants frame 0.
- Feet sit on about y=148–150. Ironjaw east and west put a 2px sole tip at y=148. That tip stays frame 0. A real lift still retargets.
- Godot hop stays about 3px: Bastion and Ironjaw 2.5, Mender 3, Kestrel and Gloam 3.5, none over 4. The strip's stride is the pose. The hop is the only crest, so it does not stack a second bounce on a lifted foot.
- Dust still puffs only on a facing change and the final plant. Straight tiles stay quiet.
- Locked identities stay Gloam B, Mender D2, Bastion 2C, Ironjaw Berserker A + helm A2, and Kestrel F+A.

Locked kit numbers, map geometry, Soft Lock Invisible/Ambush, and the combat camera are unchanged.

## 2026-09-26 — Mobile debug APK 0.1.26

Sideload cut of the `mobile` tip for Luca. Stamp: `version/name` `0.1.26-mobile`, `version/code` `27`. Those numbers were already on the tip from the Windmere stamp. The note that used to sit here recorded an unpublished APK whose bytes predated the Slagcrown lava punch (#167). This entry replaces that note. The APK below is a fresh export of tip `00f6a9a` (#170). Package `com.maurogp12.stasiumxii.mobile`. Godot `4.7.2.stable.official.ed1daf0bf`, official templates, arm64-v8a debug APK.

Signed with the pinned shared debug keystore. Certificate SHA-256 `3725b12ee58cf1d911c373bc5ef0b6be3c47afb41421777f2b505bb4aa6063e2` matches the pin and matches `mobile-0.1.25-debug`, so a phone on that cert upgrades in place with `adb install -r`. Hub **Actualizar** still works. Same package and the same cert, so this cut is an in-place upgrade. Size 71536358 bytes. SHA-256 `b271edaac3aa1a56617e9e6403d7f1f5a8b91c655120ec4a5495145170315cc0`.

### Player-visible since 0.1.25

- Phone combat zoom further out (#161). A 20:9 phone opens at 1.55. Zoom out rests at 1.40. Zoom in stops at 2.25. Desktop stays 0.64.
- Hot-seat and Online class cards use the Locked Wakfu select plates (#162).
- Walks stay on the wakfu-ship strips. One stride per tile, short hop, v4 sheets (#163). Plant contact, squash, and a readable stop (#173).
- Combat VFX punch v2 (#171). Ambush slash, hit flash, footstep dust, and Mark Shot impact are the transparent punch-v2 strips. Ambush still slashes after the back-tile plant.
- Hit-flinch strips play on damage resolve (#172). The facing clip starts when the hit lands. A miss does not flinch.
- Map punch dress. Slagcrown lava is zero-green (#164/#167). Ironjaw reads bigger from the art-fill at scale 1.0 (#165). Stormspire paints the algo-así punch (#166). Crosshaven is dirt and stone (#168). Windmere is the ice punch (#169). Brinewake is the coast punch (#170). Geometry and tags are unchanged.

### Intentionally not changed

- Locked kit numbers, AP/MP, ranges, and damage.
- Map geometry, tags, and room shapes.
- Package id stays `com.maurogp12.stasiumxii.mobile`. The debug keystore is unchanged. Permissions stay `INTERNET` and `REQUEST_INSTALL_PACKAGES`.

Headless on this stamp (Godot 4.7.2, 0 failed): hub 212, APK update 101, stasis 361, Koliseo maps 385, combat 5182, motion 3131, VFX 670, touch adapter 492, sprite 261, elevation chrome 187.

Tag `mobile-0.1.26-debug`. Install: https://github.com/maurogp12/stasiumxii/releases/download/mobile-0.1.26-debug/stasiumxii-mobile-debug.apk

## 2026-09-26 — Brinewake coast punch

Soft Lock agua + costa. Presentation only. Locked geometry and tags are unchanged.

Brinewake now paints the coast punch: wet sand, pier wood, and tide scorch, with deep water for agua. Foam sits on the diamond seams. Tide crust is a few dark marks on the sand. The green carpet on the punch sheet is not painted onto the diamonds, and the rock pillar stays stone. Coast props the arena already paints (`driftwood`, `rock_cluster`, `rock_pillar`, `rubble`, `ruins`, `fence`, `waterfall`, `floor_seal`) read from `brine_prop_*`. Other arenas keep their sheets. The board draws these sheets in the match.

## 2026-09-26 — Windmere ice punch

Soft lock: hielo, agua, sparse crystals. Presentation only. Locked Windmere geometry, tags, and cell layout are unchanged. Other families stay on their sheets.

`slice_windmere_punch.py` reads the punch contact sheets and overwrites only the Windmere slices. Koliseo and Galevault both paint those slices: the board dress is `wind_` whenever the match map id is Windmere.

| Punch sheet | Live slices |
| --- | --- |
| `art/tilesets/original/pending/ice/punch/wind_ground_punch.png` | `wind_ground.png`, `wind_ground_v1.png`, `wind_ground_v2.png`, `wind_ground_v3.png`, `wind_mud.png`, `wind_mud_v1.png`, `wind_mud_v2.png`, `wind_water.png`, `wind_water_v1.png`, `wind_water_v2.png` |
| `art/tilesets/original/pending/ice/punch/wind_elevation_punch.png` | `wind_ground_e1.png`, `wind_ground_e1_v1.png`, `wind_mud_e1.png`, `wind_ground_e2.png` |
| `art/tilesets/original/pending/ice/punch/wind_props_punch.png` | `wind_prop_crystal.png`, `wind_prop_ice_shard.png`, `wind_prop_spark.png`, `wind_prop_rock_pillar.png`, `wind_prop_rubble.png` |

`wind_prop_ice_sheet.png` and `wind_prop_floor_seal.png` are flat diamonds from the ground punch. Flat ice and water keep a hard 64×32 diamond so the freeze/water seam stays readable. Slice output lives in `art/maps/arena_colosseum_v2/tiled/tiles/`. The earlier ice contact sheet `stasium_tileset_ice.png` stays in `pending/ice/` and is no longer the live paint.

## 2026-09-26 — Walk plant, squash, and stop (after #163)

Presentation only. #163 stays: 0.30s tile, one 6-frame stride at about 20 fps, cubic ease, 3px shared hop, 50ms settle on the first tile and on a turn, plant hold on the last 18%, dust on a facing change and the final plant, v4 walks. Ambush still plants, then slashes. Kit numbers and map geometry are unchanged.

### What changed since #163

- The foot-down cell is the plant. It shows when the hop is on Y=0 and through the 18% hold. The open part of the tile no longer keeps that cell on screen while the foot is moving. If frame 0 is not the planted row, the sampler uses the planted index. Tile time is not stretched. On the shipped v4 sheets frame 0 is still that cell.
- The sprite squashes on the plant only: scale Y about 0.96 back to 1 across that same hold (about 54ms). Nothing squashes mid-hop. The pawn, the foot, the name, the aim mark, and the shade do not take the hop or the squash.
- A 180 finishes the plant, sets the opposite facing, settles 50ms, then steps. It does not travel through a side facing.
- Straight tiles do not settle and do not hide the walk strip between cells. The cubic continues. Dust still does not puff on those tiles.
- The path holds the landed contact for a short readable idle (100ms) before the face pad unlocks. The stop is not a passing frame.
- Bastion and Ironjaw hop about 2.5px. Kestrel and Gloam hop about 3.5px. Mender stays at the shared 3px. Every crest stays at or under 4px. Tile time stays 0.30s. Ironjaw art-fill stays scale 1.0.

## 2026-09-26 — Slagcrown lava punch sheets

Slagcrown paints the Scenario lava punches in `art/tilesets/original/pending/lava/`. Floors are lava and scorched dirt. Pools are dark ash. Cliffs are volcanic ledges. Center-tile props are lava rock and shards. The board has no grass, moss, or bushes. Crosshaven stays on the earth punch. Brinewake stays on the original coast sheet. Tags, geometry, and combat numbers are unchanged. `board_mood_punch.png` is a preview and is not a tile.

## 2026-09-26 — Crosshaven earth punch

Soft lock: tierra + naturaleza. Crosshaven ground and cliffs are the dirt and stone punch, on the unprefixed dress (`ground.png`, `ground_e1.png`, `ground_e2.png`). The board paints those files in game. Moss is only on the ruin walls. The field, the cliffs, and the floor seal stay bare, so there is no lawn. The arena grade is warm earth. Ruins, the well, hay, the fence, rubble, and the rock pillar on those same paths come from the props punch. Water and the lighter mud stay the original sheet so those tags still read.

Phone tap diamonds, zoom, and planted walks are unchanged. Tags, geometry, and Locked kit numbers are unchanged. Ambush stays 4 AP / 0 MP / 22 FLEX.

Headless Godot 4.7.2, 0 failed: Koliseo maps 346, combat 5182.

| Arena | Pack | Atlas |
| --- | --- | --- |
| Crosshaven | earth | `ground.png` and the earth-punch cliffs |
| Brinewake | coast | `brine_*` |
| Slagcrown | lava | `slag_*` |
| Windmere | ice | `wind_*` |
| Stormspire | electric | `storm_*` |

## 2026-09-26 — Stormspire algo-así punch

Soft lock: electric and wind. Presentation only. Locked Stormspire geometry, tags, and cell layout are unchanged. Other families stay on their sheets.

`slice_storm_punch.py` reads the punch contact sheets and overwrites only the Stormspire slices.

| Punch sheet | Live slices |
| --- | --- |
| `art/tilesets/original/pending/electric/storm_ground_punch.png` | `storm_ground.png`, `storm_ground_v1.png`, `storm_ground_v2.png`, `storm_ground_v3.png`, `storm_mud.png`, `storm_mud_v1.png`, `storm_mud_v2.png`, `storm_water.png`, `storm_water_v1.png` |
| `art/tilesets/original/pending/electric/storm_elevation_punch.png` | `storm_ground_e1.png`, `storm_ground_e1_v1.png`, `storm_mud_e1.png`, `storm_ground_e2.png` |
| `art/tilesets/original/pending/electric/storm_props_punch.png` | `storm_prop_rock_pillar.png`, `storm_prop_conduit.png`, `storm_prop_crystal_bolt.png`, `storm_prop_arc.png`, `storm_prop_rubble.png`, `storm_prop_spark.png` |

`storm_prop_floor_seal.png` is a flat violet diamond from the ground punch. Slice output lives in `art/maps/arena_colosseum_v2/tiled/tiles/`. The earlier electric contact sheet `stasium_tileset_electric.png` stays in `pending/electric/` and is no longer the live paint. `slice_ice_electric.py` calls the Windmere punch slicer and does not write `storm_*`.

## 2026-09-26 — Koliseo overview zoom

Luca's 0.1.25 playtest. No APK stamp. Map geometry and tags are unchanged. Desktop zoom stays 0.64.

The 0.1.25 rest was zoom 2.0 (64px diamonds). On a 20:9 phone that crop showed about 62% of the diamond height and 83% of the width, so the fighters filled the glass. Zoom − stopped at 1.7, still a close crop. Zoom + stopped at 2.5. The postage-stamp contain on that window is zoom 1.24 (~40px diamonds, ~205px black wings).

A 20:9 phone now opens at 1.55 (~50px diamonds). The full width fits with about a 56px side gutter, and about 80% of the height stays on screen. Zoom − rests at 1.40 (diamond tips, ~128px wings, still above the contain). Zoom + stops at 2.25.

## 2026-09-26 — Mobile debug APK 0.1.25

Sideload cut of the `mobile` tip for Luca. Stamp only: `version/name` `0.1.25-mobile`, `version/code` `26`. Package `com.maurogp12.stasiumxii.mobile`. Godot `4.7.2.stable.official.ed1daf0bf`, official templates, arm64-v8a debug APK.

Signed with the pinned shared debug keystore. Certificate SHA-256 `3725b12ee58cf1d911c373bc5ef0b6be3c47afb41421777f2b505bb4aa6063e2` matches the pin and matches `mobile-0.1.24-debug`, so a phone on that cert upgrades in place with `adb install -r`. Hub **Actualizar** still works. Same package and the same cert, so this cut is an in-place upgrade.

### Player-visible since 0.1.24

- Walks ship wakfu-ship-v3 (#159). East and west are the punch strips. North and south are the front and rear three-quarter strips. Device playback reads those same bytes from `art/export_2x/walk_src`.
- A step shows the facing walk strip, then eases that tile (#159). Arrival plants walk frame 0 on the last segment’s facing. The idle body no longer slides across the cell.
- Ambush plants before the slash (#159). A hit snaps to the back tile and faces the prey, plays origin dust, holds, then slashes for 22. A miss does not teleport. Drop Shade keeps Invisible. An attack still clears Invisible on a hit or a miss.
- Koliseo zoom (#159). A 20:9 phone opens at 2.0, so a diamond is 64px. Zoom out rests at 1.7. Zoom in stops at 2.5.
- Scenario-feel VFX (#159). Ambush slash, hit flash, and footstep dust are the transparent punch plates, each one hero frame. Mark Shot and Detonate stay single plates. The Ambush slash still waits until the body is planted.

### Intentionally not changed

- Locked kit numbers, AP/MP, ranges, and damage. Ambush stays 4 AP / 0 MP / 22 FLEX.
- Map geometry, tags, and room shapes.
- Stasis stays on `mobile`. It was not ported to `main`.
- Package id stays `com.maurogp12.stasiumxii.mobile`. The debug keystore is unchanged. Permissions stay `INTERNET` and `REQUEST_INSTALL_PACKAGES`.

Headless on this stamp (Godot 4.7.2, 0 failed): hub 212, APK update 101, stasis 361, Koliseo maps 314, combat 5182, motion 2361, VFX 576, touch adapter 487, sprite 234, elevation chrome 187.

Tag `mobile-0.1.25-debug`. Install: https://github.com/maurogp12/stasiumxii/releases/download/mobile-0.1.25-debug/stasiumxii-mobile-debug.apk

## 2026-09-26 — Mobile debug APK 0.1.24

Sideload cut of the `mobile` tip for Luca. Stamp only: `version/name` `0.1.24-mobile`, `version/code` `25`. Package `com.maurogp12.stasiumxii.mobile`. Godot `4.7.2.stable.official.ed1daf0bf`, official templates, arm64-v8a debug APK.

Signed with the pinned shared debug keystore. Certificate SHA-256 `3725b12ee58cf1d911c373bc5ef0b6be3c47afb41421777f2b505bb4aa6063e2` matches the pin and matches `mobile-0.1.23-debug`, so a phone on that cert upgrades in place with `adb install -r`. Hub **Actualizar** still works. Same package and the same cert, so this cut is an in-place upgrade.

### Player-visible since 0.1.23

- Ambush plants before the slash for a visible Shade and for Invisible (#156). The snap and the facing happen first. The slash waits until the body is on the back tile.
- Drop Shade and Fade keep Invisible (#156). Ambush, Cut, and the other attack resolves clear Invisible on a hit or a miss. An Ambush miss still does not teleport. Visible Ambush still requires a Shade.
- Walk steps keep the facing strip (#156). The cycle stays on the facing walk strip across a refresh, with feet pinned to the idle contact.
- Scenario redo VFX (#157). Hit flash and footstep dust play as 3x3 sheets. Ambush slash, Mark Shot, and Detonate stay single hero flashes. The Ambush slash still waits until the body is planted.

### Intentionally not changed

- Locked kit numbers, AP/MP, ranges, and damage. Ambush stays 4 AP / 0 MP / 22 FLEX.
- Map geometry, tags, and room shapes.
- Stasis stays on `mobile`. It was not ported to `main`.
- Package id stays `com.maurogp12.stasiumxii.mobile`. The debug keystore is unchanged. Permissions stay `INTERNET` and `REQUEST_INSTALL_PACKAGES`.

Headless on this stamp (Godot 4.7.2, 0 failed): hub 212, APK update 101, stasis 361, Koliseo maps 314, combat 5176, motion 2322, VFX 579, touch adapter 485, sprite 234, elevation chrome 187.

Tag `mobile-0.1.24-debug`. Install: https://github.com/maurogp12/stasiumxii/releases/download/mobile-0.1.24-debug/stasiumxii-mobile-debug.apk

## 2026-09-26 — Mobile debug APK 0.1.23

Sideload cut of the `mobile` tip for Luca. Stamp only: `version/name` `0.1.23-mobile`, `version/code` `24`. Package `com.maurogp12.stasiumxii.mobile`. Godot `4.7.2.stable.official.ed1daf0bf`, official templates, arm64-v8a debug APK.

Signed with the pinned shared debug keystore. Certificate SHA-256 `3725b12ee58cf1d911c373bc5ef0b6be3c47afb41421777f2b505bb4aa6063e2` matches the pin and matches `mobile-0.1.22-debug`, so a phone on that cert upgrades in place with `adb install -r`. Hub **Actualizar** still works. Same package and the same cert, so this cut is an in-place upgrade.

### Player-visible since 0.1.22

- Ambush Invisible plants before the slash (#153). The snap and the facing happen first. Coach, side HP, toast, and the damage float wait until the body is on the back tile.
- Wakfu walk without the knight pop (#153). Idle, the step, and the plant stay on walk frame 0, so a stride does not flash the static turnaround.
- Invisible stays hidden while walking (#153).
- Rocks, fences, and arches block walk (#153). The path and the blue highlight go around those props.
- Actualizar reads the installed version again (#152). If PackageManager cannot, it uses the baked stamp, and it still downloads the newest public debug APK if both fail.
- Hub RAID bosses sit in their frames (#154). Each portrait has headroom above a clear name, and the row keeps a gap above the footer.

### Intentionally not changed

- Locked kit numbers, AP/MP, ranges, and damage. Ambush stays 4 AP / 0 MP / 22 FLEX.
- Map geometry, tags, and room shapes.
- Stasis stays on `mobile`. It was not ported to `main`.
- Package id stays `com.maurogp12.stasiumxii.mobile`. The debug keystore is unchanged. Permissions stay `INTERNET` and `REQUEST_INSTALL_PACKAGES`.

Headless on this stamp (Godot 4.7.2, 0 failed): hub 212, APK update 101, stasis 361, Koliseo maps 314, combat 5119, motion 2311, VFX 542, touch adapter 485, sprite 234, elevation chrome 187.

Tag `mobile-0.1.23-debug`. Install: https://github.com/maurogp12/stasiumxii/releases/download/mobile-0.1.23-debug/stasiumxii-mobile-debug.apk

## 2026-09-26 — Mobile debug APK 0.1.22

Sideload cut of the `mobile` tip for Luca. Stamp only: `version/name` `0.1.22-mobile`, `version/code` `23`. Package `com.maurogp12.stasiumxii.mobile`. Godot `4.7.2.stable.official.ed1daf0bf`, official templates, arm64-v8a debug APK.

Signed with the pinned shared debug keystore. Certificate SHA-256 `3725b12ee58cf1d911c373bc5ef0b6be3c47afb41421777f2b505bb4aa6063e2` matches the pin and matches `mobile-0.1.21-debug`, so a phone on that cert upgrades in place with `adb install -r`. Hub **Actualizar** still works. Same package and the same cert, so this cut is an in-place upgrade.

### Player-visible since 0.1.21

- Landscape hub (#150). The activity is sensor landscape, so the 960×720 poster fills the glass instead of sitting in a letterboxed strip. Title, Koliseo banner, RAID, and the five Stasis tiles stay in one row. Actualizar stays on the title row.
- Combat zoom dialed back (#150). A 20:9 phone opens near zoom 1.48, so most of the 15×15 diamond stays on screen. **Zoom +** and **Zoom −** step the camera. Zoom out reaches the whole diamond. Zoom in stops at 2.25, under the 0.1.21 cover zoom. The choice lasts for the session.
- Foot-planted walk (#150). About 0.30s per tile. The foot is held on the diamond through the press and the landing, and the facing walk cycle is sampled from the foot. The body leads about 10px along the facing during the stride, then returns. Arrival is the idle facing on the cell.
- Locked Wakfu walks for all five classes (#150). Kestrel F+A, Ironjaw A+A2, Gloam proposal B, Mender D2, and Bastion 2C. Twenty 864×160 walk strips, six 144×160 cells. No `*_gen.png`.
- Koliseo banner (#150). The hub plate uses the approved lineup and keeps that art's aspect, so the five heroes and the KOLISEO label stay in frame. RAID tiles are unchanged.
- Hub **Actualizar** still checks public GitHub releases for the newest `mobile-*-debug` APK and hands it to the system installer. Same package `com.maurogp12.stasiumxii.mobile` and the pinned debug cert.

### Intentionally not changed

- Locked kit numbers, AP/MP, ranges, and damage. Ambush stays 4 AP / 0 MP / 22 FLEX.
- Map geometry, tags, and room shapes.
- Stasis stays on `mobile`. It was not ported to `main`.
- Package id stays `com.maurogp12.stasiumxii.mobile`. The debug keystore is unchanged. Permissions stay `INTERNET` and `REQUEST_INSTALL_PACKAGES`.

Headless on this stamp (Godot 4.7.2, 0 failed): hub 206, APK update 84, stasis 361, Koliseo maps 314, combat 4647, motion 2095, VFX 528, touch adapter 485, sprite 234, elevation chrome 189.

Tag `mobile-0.1.22-debug`. Install: https://github.com/maurogp12/stasiumxii/releases/download/mobile-0.1.22-debug/stasiumxii-mobile-debug.apk

## 2026-09-26 — Wakfu walks and Koliseo banner landed

The locked sheets are in the tree. Twenty walk PNGs, 864×160 RGBA, six 144×160 cells, replaced or added in place:

- `art/export_2x/characters/kestrel/anims/kestrel_walk_{e,s,n,w}.png` — Kestrel F+A
- `art/export_2x/characters/ironjaw/anims/ironjaw_walk_{e,s,n,w}.png` — Ironjaw A+A2
- `art/export_2x/characters/gloam/anims/gloam_walk_{e,s,n,w}.png` — Gloam proposal B (amber grin). The dual-knives redesign is not the file.
- `art/export_2x/characters/mender/anims/mender_walk_{e,s,n,w}.png` — Mender D2
- `art/export_2x/characters/bastion/anims/bastion_walk_{e,s,n,w}.png` — Bastion 2C

`*_frames.tres` still slices kestrel, ironjaw, and gloam at those paths. Mender and Bastion load from the PNGs and have no attack, cast, hit, or death sheet. No `*_gen.png`. The hub Koliseo hero is `art/ui/hub/koliseo_banner.png` (the approved lineup). The plate keeps that art's aspect, so the five heroes and the KOLISEO label stay in frame. RAID tiles are unchanged. Zoom, landscape hub, and the stride code stay.

Headless Godot 4.7.2, 0 failed: motion 2095, combat 4647, touch adapter 485, hub 206.

## 2026-09-26 — Walk sheet drop slot

Luca approved Wakfu walk sheets. The drop is a replace of the existing walk PNGs, 864×160 RGBA, six 144×160 cells. `*_frames.tres` already slices those paths. No `*_gen.png`. No second folder. Attack, cast, hit, and death stay.

Looks locked for that drop: Kestrel (prior Wakfu), Ironjaw A2 (Berserker A body, fierce helm with iron-jaw grill, spikes, and crest, dual double-bit axes, crimson battle-worn plate — this replaces any earlier Ironjaw Wakfu walk), Gloam proposal B (amber/yellow glowing eyes, wide chilling grin, dual curved silver daggers with gold hilts, purple cloak with gold trim — not the white-eyes sheet), Mender proposal D2 (cream/gold hooded robe, green lantern staff, face clearly visible in a more open hood), Bastion proposal 2C (charcoal-grey/gold armor, spiked mace, oversized tower shield). Paths are listed at the top of `art/export_2x/characters/README.md`.

The stride code stays: face the segment, sample the cycle from the foot, about 0.30s per tile, plant on arrival, ground marks on the Foot child.

Headless Godot 4.7.2, 0 failed: motion 2031.

## 2026-09-26 — Walk stride on the existing strips

Luca, after the landscape pass. No APK cut. No new walk sheets. Locked kit numbers unchanged. The Batch-1 / Batch-1c files under `art/export_2x/characters/{class}/anims/*_walk_{e,s,n,w}.png` are the clips that play. `*_gen.png` stays unloaded.

### What a step does now

- The foot eases from cell to cell in about 0.30s. The press and the landing hold the foot on the diamond. The open part is a smooth step, not a raw lerp and not a tile-long hop.
- Facing snaps to that segment before the foot leaves, including a corner. A cardinal uses the letter. Any other step uses the screen direction, so the body does not travel sideways or backwards and then spin at the end.
- The facing walk cycle is sampled from the foot. Contact frames show only on the plant. Passing frames show only while the foot is between cells, so the idle pose is not what slides.
- While the foot is moving, the body leads about 10px along the facing and rises a few pixels, then both return. Arrival is the idle facing on the cell, not a mid-stride freeze. The ground mark and the aim ring stay on the Foot child.

Headless Godot 4.7.2, 0 failed: motion 1972. Map geometry, tags, and Locked kit numbers are unchanged.

## 2026-09-26 — Phone combat overview and landscape hub

Luca's 0.1.21 playtest. No APK cut. Locked kit numbers unchanged. Map geometry, tags, Ambush snap, tilesets, Scenario VFX, and the planted walk stay.

### What was hard

0.1.21 locked the activity to portrait while the UI stayed the landscape 960×720 poster. On the phone that poster sat in a short strip with black bars above and below, which read as “nothing is visible.” The cover zoom made it worse: on a 960×1400 window it was 3.0, so a few giant cells filled whatever glass was left.

### What a phone does now

- Orientation is sensor landscape, applied from the project setting and again when the hub or the board opens. Stretch stays `canvas_items` / `expand`, so the landscape window is full-bleed instead of a letterboxed 960×720 strip. The poster is still title, Koliseo banner, RAID, and the five Stasis tiles in one row. Actualizar stays on the title row.
- Combat zoom shows most of the 15×15 diamond. A 20:9 canvas (about 1600×720) is zoom 1.48, so a diamond is about 47px tall and the board width still fits. The turn plaque and the thumb cluster overlay the edges. The corner outside the diamond uses the hub navy. Desktop 960×720 fit stays zoom 0.64.
- **Zoom +** and **Zoom −** on the combat HUD step that camera. Zoom out reaches the whole diamond. Zoom in stops at 2.25. The choice lasts for the session, including the next fight.

Headless Godot 4.7.2, 0 failed: hub 206, touch adapter 485.

### Intentionally not changed

- Locked kit numbers, AP/MP, ranges, and damage. Ambush stays 4 AP / 0 MP / 22 FLEX.
- Map layouts, board geometry, tags, and room shapes.
- Ambush snap, original tilesets, and Scenario VFX. The walk presentation is the stride entry above. The strips themselves are unchanged.

## 2026-09-26 — Mobile debug APK 0.1.21

Sideload cut of the `mobile` tip for Luca. Stamp only: `version/name` `0.1.21-mobile`, `version/code` `22`. Package `com.maurogp12.stasiumxii.mobile`. Godot `4.7.2.stable.official.ed1daf0bf`, official templates, arm64-v8a debug APK.

Signed with the pinned shared debug keystore. Certificate SHA-256 `3725b12ee58cf1d911c373bc5ef0b6be3c47afb41421777f2b505bb4aa6063e2` matches the pin and matches `mobile-0.1.20-debug`, so a phone on that cert upgrades in place with `adb install -r`. Hub **Actualizar** still works. Same package and the same cert, so this cut is an in-place upgrade.

### Player-visible since 0.1.20

- Invisible Ambush snaps to the back tile, then slashes (#147). The body collapses, snaps, faces the prey, and only then deals the 22. A miss does not move and keeps Invisible.
- Phone board zoom-in and a Dofus planted walk, about 0.30s per tile (#145). Portrait framing covers the diamond. The body faces the segment and plays the walk strip while the foot eases to the next tile.
- Scenario combat VFX wired (#146). Keyed ambush, mark-shot, detonate, hit, and footstep plates play on the existing presentation beats.
- Original isometric tileset boards (#148). Crosshaven, Brinewake, and Slagcrown use the original sheet. Windmere paints ice. Stormspire paints electric.
- Hub **Actualizar** still checks public GitHub releases for the newest `mobile-*-debug` APK and hands it to the system installer. Same package `com.maurogp12.stasiumxii.mobile` and the pinned debug cert.

### Intentionally not changed

- Locked kit numbers, AP/MP, ranges, and damage. Ambush stays 4 AP / 0 MP / 22 FLEX.
- Map geometry, tags, and room shapes.
- Stasis stays on `mobile`. It was not ported to `main`.
- Package id stays `com.maurogp12.stasiumxii.mobile`. The debug keystore is unchanged. Permissions stay `INTERNET` and `REQUEST_INSTALL_PACKAGES`.

Headless on this stamp (Godot 4.7.2, 0 failed): hub 186, APK update 84, stasis 361, Koliseo maps 314, combat 4647, motion 1957, VFX 528, touch adapter 460, sprite 234, elevation chrome 189.

Tag `mobile-0.1.21-debug`. Install: https://github.com/maurogp12/stasiumxii/releases/download/mobile-0.1.21-debug/stasiumxii-mobile-debug.apk

## 2026-09-26 — Windmere ice and Stormspire electric sheets

The scenario sheets are sliced onto the same 64×32 grid as the other packs. Windmere paints snow, bare ice, ice water, and ice cliffs from `art/tilesets/original/pending/ice/stasium_tileset_ice.png`. Stormspire paints dark stone, purple energy tiles, and electric cliffs from `pending/electric/stasium_tileset_electric.png`. Shared prop names use `wind_prop_*` and `storm_prop_*` so Crosshaven, Brinewake, and Slagcrown stay on the original sheet.

Phone tap diamonds, zoom, planted walks, and Scenario VFX are unchanged. Tags, geometry, and Locked kit numbers are unchanged. Ambush stays 4 AP / 0 MP / 22 FLEX.

Headless Godot 4.7.2, 0 failed: Koliseo maps 314, combat 4647, elevation chrome 189.

| Arena | Pack | Atlas |
| --- | --- | --- |
| Crosshaven | grassland | `ground.png` and the original-sheet cliffs |
| Brinewake | coast | `brine_*` |
| Slagcrown | lava | `slag_*` |
| Windmere | ice | `wind_*` |
| Stormspire | electric | `storm_*` |

## 2026-09-26 — Invisible Ambush strikes from the back tile

Luca's 0.1.20 clip. Shade-origin Ambush already blinks to the back tile and hits. Fade self-origin was the miss: the body could still be on the cast cell while the hit was presented, and a distant Invisible Gloam must not borrow an armed Shade to deal that hit. No APK cut. Locked kit numbers unchanged. Ambush without a Shade and without Invisible stays parked.

### Root cause

`_resolve_ambush` already wrote the axis back tile before HP for both origins. The view could still toast and float the damage when the plant had not stuck, so Invisible Ambush read as a slash from the cast cell with the back-tile facing. Shade-origin looked right because the long blink was obvious. A Fade on a distant tile with an armed Shade in range is not that hit: origin is Gloam, and the cast is out of range.

Instant Invisible Ambush now deals damage only after the body is on the back tile. The shared arrival is collapse, snap, face the prey, slash, then the 22. A miss still does not move and keeps Invisible. Illegal Drop Shade cells are grey before confirm and do not flash REJECT. Range stays Chebyshev 1–3.

### Intentionally not changed

- Locked kit numbers, AP/MP, ranges, and damage. Ambush stays 4 AP / 0 MP / 22 FLEX.
- Ambush without a Shade (and without Invisible) stays parked.
- Stasis stays on `mobile`.
- Advance still submits an illegal click so the refund coach can fire.

Headless Godot 4.7.2, 0 failed: combat 4644, motion 1898, VFX 479.

## 2026-09-26 — Invisible Ambush stands on the back tile

Luca's 0.1.20 clip. Gloam Fade, then Ambush. No APK cut. Locked kit numbers unchanged. Ambush without a Shade and without Invisible stays parked.

### Root cause

Resolve already moved Invisible Gloam onto the axis back tile before the 22. The view then faded the body out on the cast cell and started the contact slash in the same beat as the snap. The painted fighter never rested behind the target, so the hit read as a slash from the current tile. A collapse sample could also keep the arrival at alpha 0, which hides that plant.

The body now fades on the cast cell, snaps, and holds on the back tile before the slash and before the damage number. A late collapse sample cannot hide that hold. A miss still does not plant, and it keeps Invisible. Shade is still spent only for a Shade-origin hit.

### Intentionally not changed

- Locked kit numbers, AP/MP, ranges, and damage. Ambush stays 4 AP / 0 MP / 22 FLEX.
- Ambush without a Shade (and without Invisible) stays parked.
- Stasis stays on `mobile`.

Headless Godot 4.7.2, 0 failed: combat 4608, motion 1891, VFX 472.

## 2026-09-26 — Original isometric tileset on the Koliseo boards

The five Locked arenas paint slices of `art/tilesets/original/original-tileset-b.jpg`. Phone tap diamonds, zoom, and planted walks are unchanged. Tags, geometry, and combat numbers are unchanged.

| Arena | Pack | Atlas |
| --- | --- | --- |
| Crosshaven | grassland | `ground.png`, `mud.png`, `water.png`, grass cliffs |
| Brinewake | coast | `brine_*` cobble, deep water, stone cliffs |
| Slagcrown | lava | `slag_*` cracked earth, `slag_lava.png`, dark rock |
| Windmere | ice | `wind_*` from `pending/ice/stasium_tileset_ice.png` |
| Stormspire | electric | `storm_*` from `pending/electric/stasium_tileset_electric.png` |

The first slice of this pass left Windmere and Stormspire on pale stone and dark rock. The follow-up above promotes the scenario sheets. See `art/tilesets/original/THEMES.md`.

## 2026-09-26 — Phone combat framing and planted walks

Luca's 0.1.20 Gloam ambush clip. No APK cut. Locked kit numbers unchanged. Map layouts, tags, and room shapes unchanged.

### What was hard

On a phone the 15×15 diamond sat in the middle of the clear band with a dark gutter around it. Portrait fit was about zoom 0.97, and a short window was 0.64, so a diamond was roughly 20–31px tall and a finger covered several cells. Walks still translated the foot in a straight line for 0.30s. The Batch-1 strip could be mid-cycle when the tile started, so the pose read as a slide, including sideways when the body had not turned into the segment.

### What a phone does now

- Handheld orientation is portrait, so the tall viewport is the one the camera fits.
- Phone zoom covers the clear play rectangle with the iso diamond (zoom in). On a 960×1400 window a 15×15 board is zoom 3.0, so a diamond is about 96px tall and the dark margin around the board is gone. The navy/gold cards and the turn strip stay their design size above and below that band. Desktop 960×720 fit stays zoom 0.64.
- The camera frames the active fighter. A walk-mode finger drag past 48px pans inside the board, and stops at the edge so the gutter does not come back. A short tap still selects the cell. A spell drag still aims. Mouse pick stays 22px.
- A walk holds the foot on the diamond through the press, eases along the segment for about 0.30s, and settles on the next contact. The body faces that segment first (cardinal letter, otherwise the screen direction) and the matching Batch-1 / Batch-1c strip (`walk_n/e/s/w`) plays that half-cycle. The pose is taken from the step, so a clock that stays on frame 0 cannot idle-slide. Arrival holds the contact frame, then the idle facing. The contact shadow stays on the foot.

### Intentionally not changed

- Locked kit numbers, AP/MP, ranges, and damage.
- Map layouts, board geometry, tags, and room shapes.
- Desktop mouse pick and the 960×720 camera fit.
- No new cosmetics. No APK cut.

Headless Godot 4.7.2, 0 failed: touch adapter 460, motion 1936, combat 4574, sprite 234.

## 2026-09-26 — Mobile debug APK 0.1.20

Sideload cut of the `mobile` tip for Luca. Stamp only: `version/name` `0.1.20-mobile`, `version/code` `21`. Package `com.maurogp12.stasiumxii.mobile`. Godot `4.7.2.stable.official.ed1daf0bf`, official templates, arm64-v8a debug APK.

Signed with the pinned shared debug keystore. Certificate SHA-256 `3725b12ee58cf1d911c373bc5ef0b6be3c47afb41421777f2b505bb4aa6063e2` matches the pin and matches `mobile-0.1.19-debug`, so a phone on that cert upgrades in place with `adb install -r`.

### Player-visible since 0.1.19

- Hub **Actualizar** (#143). It checks public GitHub releases for the newest `mobile-*-debug` APK (`stasiumxii-mobile-debug.apk`), compares Android `versionCode` / `versionName` with the running build, and hands a newer file to the system installer. Same package and the pinned debug cert. No token.
- The first **Actualizar** on Android 8+ opens **Install unknown apps** for STASIUM XII. After that switch is on, the download continues and the installer does an in-place update. Later cuts are one tap.
- Still includes the 0.1.19 combat and graphics stack: void pathing, Ambush snap, easier target taps and the aim ring, walks about 0.30s per tile, richer paint on the same Koliseo and Stasis layouts, navy and gold combat HUD, and the turn portrait strip.

### Intentionally not changed

- Locked kit numbers, AP/MP, ranges, and damage.
- No new cosmetics.
- Stasis stays on `mobile`. It was not ported to `main`.
- Package id stays `com.maurogp12.stasiumxii.mobile`. The debug keystore is unchanged.

Headless on this stamp (Godot 4.7.2, 0 failed): hub 186, APK update 84, stasis 361, Koliseo maps 284, combat 4574, motion 1877, VFX 459, touch adapter 441, sprite 234.

Tag `mobile-0.1.20-debug`. Install: https://github.com/maurogp12/stasiumxii/releases/download/mobile-0.1.20-debug/stasiumxii-mobile-debug.apk

## 2026-09-26 — In-app APK update

The mobile hub has an **Actualizar** control. It checks public GitHub releases for the newest `mobile-*-debug` APK (`stasiumxii-mobile-debug.apk`), compares Android `versionCode` / `versionName` with the running build, and hands a newer file to the system installer. Same package `com.maurogp12.stasiumxii.mobile` and the pinned debug cert. No token.

The first install of the APK that contains this control is still manual. On Android 8+, the first **Actualizar** opens **Install unknown apps** for STASIUM XII. After that switch is on, the download continues and the installer does an in-place update. Later cuts are one tap. Offline, rate limit, and a missing release show a short hub line.

Headless: `tests/run_mobile_hub_tests.gd` (186 passed) and `tests/run_apk_update_tests.gd` (84 passed). The install Intent is not run headless.

## 2026-09-26 — Mobile debug APK 0.1.19

Sideload cut of the `mobile` tip for Luca. Stamp only: `version/name` `0.1.19-mobile`, `version/code` `20`. Package `com.maurogp12.stasiumxii.mobile`. Godot `4.7.2.stable.official.ed1daf0bf`, official templates, arm64-v8a debug APK.

Signed with the pinned shared debug keystore. Certificate SHA-256 `3725b12ee58cf1d911c373bc5ef0b6be3c47afb41421777f2b505bb4aa6063e2` matches the pin and matches `mobile-0.1.18-debug`, so a phone on that cert upgrades in place with `adb install -r`.

### Player-visible since 0.1.18

- Void pathing and dress placement (#141). Terrain sheets keep the diamond in the left half, so a walk stays on the painted tile and does not cross the dark gaps. Void is impassable. Maps were not retagged.
- Ambush (#141). On a hit the body collapses on the origin tile, snaps to the legal back tile, then slashes there. Invisible and Shade both take that path. A miss stays put and does not deal damage.
- Easier mobile target taps and an aim ring (#141). A finger uses the painted diamond and a wider sprite capsule. The selected fighter pulses a ring while a unit spell is armed. Desktop mouse pick is unchanged.
- A walk takes about 0.30s per tile (#140). Batch-1 / Batch-1c strips play one authored plant per tile.
- Richer paint on the same Koliseo and Stasis layouts (#140). Board geometry, tags, and room shapes stay.
- Navy and gold combat HUD, and a Dofus-style turn portrait strip on the center plaque (#140). The acting fighter is the gold-lit chip.

### Intentionally not changed

- Locked kit numbers, AP/MP, ranges, and damage.
- No new cosmetics.
- Stasis stays on `mobile`. It was not ported to `main`.

Headless on this stamp (Godot 4.7.2, 0 failed): hub 178, stasis 361, Koliseo maps 284, combat 4574, motion 1877, VFX 459, touch adapter 441, sprite 234.

Tag `mobile-0.1.19-debug`. Install: https://github.com/maurogp12/stasiumxii/releases/download/mobile-0.1.19-debug/stasiumxii-mobile-debug.apk

## 2026-09-26 — Turn timeline

The center plaque leads with a portrait strip in the existing seat order (seat 0, then the rest). The acting fighter is the gold-lit chip. Missing foe art is a short name tile. The turn line and the timer stay on that plaque. No new initiative rule.

## 2026-09-26 — Combat HUD chrome

The top fighter cards and the turn plaque use the hub navy and gold. ACTIVE is the lit frame; waiting stays dim. HP, AP, MP, facing, turn, and class meters stay on the cards. Raw spell-id lines are off the cards because those spells already sit on the bottom bar. Locked numbers are unchanged.

## 2026-09-26 — Graphics lift on the same boards

Same Koliseo and Stasis layouts, tags, and room shapes. The paint, the board read, and the contact flashes got louder. Rosie’s preview stays a palette reference. `*_gen.png` stays unloaded.

### Player-visible

- Tile sheets are richer and sharper. Each diamond keeps its silhouette and picks up a north facet plus a warm lip. Biome grades stay the shipped colors. No glass wash.
- Heroes, Batch-1 / Batch-1c strips, and the Stasis package crops keep their subjects and the `(0, -72)` foot. A darker rim and a warmer light make them readable at phone scale. Hub and class portraits use those same files.
- A hit flash, the ground crack, and the shot trail read larger. Shake stays 4px. A miss is still MISS and still breaks before contact.

### Intentionally not changed

- Locked kit numbers, AP/MP, ranges, and damage.
- Map layouts, board geometry, tags, and room shapes.
- Ambush teleport resolve, Void pathing, and mobile target hit-area sizing.
- No new class kits. No APK cut.

### Tests (headless Godot 4.7.2, 0 failed)

`tests/run_koliseo_maps_tests.gd` — 284 passed. `tests/run_motion_tests.gd` — 1853 passed. `tests/run_vfx_tests.gd` — 439 passed. `tests/run_sprite_tests.gd` — 234 passed.

## 2026-09-26 — Ambush snap feel

Rosie (Rosebud). Presentation only. Hit stays 22 FLEX. Cost, legality, and the existing facing resolution stay. There is no extra backstab multiplier.

On a hit the body collapses on the origin tile, snaps to the legal back tile, slashes there, and the damage number follows that contact. The number is still the sim's facing result (backstab when the landing is the back, otherwise the front/side factor). A miss plays a whiff on the cast cell. It does not relocate and it does not deal damage.

Headless Godot 4.7.2, 0 failed: combat 4571, motion 1870, VFX 459.

## 2026-09-26 — Easier mobile target taps

Luca could not reliably tap an enemy on the phone. Locked ranges, AP, and kit numbers are unchanged. Desktop mouse pick is unchanged.

### What was hard

The fighter is drawn about 72px above the feet. A unit cast already treated the sprite as that cell, but the capsule was 34px, and after the 0.64 board zoom a finger beside the chest missed it and hit an empty diamond. The 22px nearest-tile circle also does not cover the side of the painted diamond, so those taps selected the neighbor. On a portrait phone the viewport grows taller than 720, and the camera still fitted the board into the 320px design band, so tiles stayed small.

### What a finger does now

- A touch, or an Android / iOS export, uses a 52px sprite capsule. A tap beside the chest selects that living unit when the armed spell targets a unit. The east-neighbor diamond stays a tile. Walks still use the tile, not the body.
- The same finger uses the painted 64×32 diamond, so the side of a highlighted cell selects that cell. A tap just off the board uses a 36px pad. A mouse stays at 22px.
- Portrait framing gives the extra viewport height to the board and keeps the 260px bottom reserve. The 960×720 fit stays zoom 0.64.
- The selected fighter pulses a ring while a unit spell is armed. The selected tile outline is thicker. Neither changes a legal cell.

CombatSim still rejects an out-of-range cell after the fatter pick, and refunds the AP.

Headless Godot 4.7.2, 0 failed: touch adapter 441, combat 4568.

### Intentionally not changed

- Locked kit numbers, AP/MP, ranges, and damage.
- Desktop 22px diamond and 34px body.
- No new skills. No APK cut.

## 2026-09-26 — Koliseo art and movement feel

Rosie Sunmeadow pass on `mobile`. Presentation only. The preview is a palette and feel reference. Koliseo and Stasis keep their layouts, tags, and room shapes.

### Player-visible

- A walk takes about 0.30s per tile. `grid_position` stays the tactical cell and updates when the foot commits. The pawn origin is the visual foot. Facing still turns per cardinal segment, then the body follows. Batch-1 / Batch-1c walk strips (`art/export_2x/characters/...`) play one authored plant per tile. `*_gen.png` stays unloaded.
- The step is a press, a push-off, a rise of at most 6px, and a landing settle. The contact shadow is a Foot child and stays on the ground.
- Heroes and Stasis foes share a dark rim and a north light so the silhouette reads at board scale. Feet stay on the shipped (0, -72) pivot.
- The existing tile sheets are sharper and more saturated. The same diamonds, the same biome grades, and the same props stay where they are. The glass color wash is off the grade shader. The ink grid stays a separate overlay. No new scenery and no new room shape.
- A hit holds the knock for a short hit-stop, then a small recoil. The contact flash is compact. A miss drifts sideways, wears a slash through MISS, and the shot breaks before it connects. Camera shake stays 4px and slows down.

### Intentionally not changed

- Locked kit numbers, AP/MP, ranges, and damage.
- Ambush teleport resolve, Void pathing, and mobile target hit-area sizing.
- No new class kits. No APK cut.
- Map layouts, board geometry, tags, and room shapes.

### Tests (headless Godot 4.7.2, 0 failed)

`tests/run_koliseo_maps_tests.gd` — 284 passed. `tests/run_motion_tests.gd` — 1853 passed. `tests/run_vfx_tests.gd` — 439 passed.

## 2026-09-26 — Void gaps and Ambush blink

Luca's 0.1.18 clips. No APK cut. Locked kit numbers unchanged. Ambush without a Shade stays parked.

### Root cause — illegal void pathing

Threshgate and the Koliseo boards do not tag void cells. The dark gaps in the clips are unpainted quarters of the dress sheets. Each terrain PNG keeps the diamond in the left half (64×32 source height 16, 64×40 height 23, 64×48 height 29). `terrain_placement` measured that half with `Texture.get_image()`. On the APK that image is null, so the tile centered the whole sheet. Only the top-left quarter is opaque, and a walk from cell center to cell center reads as a path across voids.

`TerrainDef.parse` also stored the string `void` as Ground, so a real void tag would have been standable. Void is now its own impassable terrain (not a Locked MP cost). Walk, Advance, and Ambush already refuse a tile that is not standable. Maps were not retagged. Mud and water stay walkable.

### Root cause — Ambush missing teleport

Resolve already planted a hit on the axis back tile and set `teleported` for both origins (caster if Invisible, otherwise the live Shade), then dealt 22 FLEX. A miss returned first and did not move. The slash is a local pose on the sprite, not a board dash. The pawn snap ran only when the event cell parsed, and it did not plant again after that pose. An Invisible or Shade hit whose destination did not parse, or a body already standing on the back tile, played the slash in place. Adjacent is not an exception: the back tile is one step past the foe on the origin axis, including when that is not the tile Gloam already occupies.

The hit still assigns that cell before damage. The board plants the pawn there before the slash and again when the pose ends. A miss does not plant. Shade is still spent only for a Shade-origin hit, in that same beat.

### Intentionally not changed

- Locked kit numbers, AP/MP, ranges, and damage. Ambush stays 4 AP / 0 MP / 22 FLEX.
- Ambush without a Shade (and without Invisible) stays parked.
- No map redraw, no icy jewel boards, no walk-cycle pass.
- Stasis stays on `mobile`.

### Tests (headless Godot 4.7.2, 0 failed)

| Suite | Passed |
| --- | ---: |
| Combat | 4568 |
| Motion | 1861 |
| VFX | 454 |
| Koliseo maps | 283 |


## 2026-09-26 — Mobile debug APK 0.1.18

Sideload cut of the `mobile` tip for Luca. Stamp only: `version/name` `0.1.18-mobile`, `version/code` `19`. Package `com.maurogp12.stasiumxii.mobile`. Godot `4.7.2.stable.official.ed1daf0bf`, official templates, arm64-v8a debug APK.

Signed with the pinned shared debug keystore. Certificate SHA-256 `3725b12ee58cf1d911c373bc5ef0b6be3c47afb41421777f2b505bb4aa6063e2` matches the pin and matches `mobile-0.1.17-debug`, so a phone on that cert upgrades in place with `adb install -r`.

### Player-visible since 0.1.17

- Koliseo boards feel alive, Dofus look: warm painted biomes, ink grid, walk and cast juice, spell flashes. Original sheets. #136
- Hub opens Koliseo from the banner and RAID from the row of five stasis portraits. #138
- Stasis is exactly two rooms: one trash pack, then the boss. Foe portraits are the package crops. No Ironjaw stand-ins. #137

### Intentionally not changed

- Locked kit numbers, AP/MP, ranges, and damage.
- Ambush and Shade. No cosmetics.
- Stasis stays on `mobile`. It was not ported to `main`.

Headless on this stamp (Godot 4.7.2, 0 failed): hub 178, stasis 346, Koliseo maps 283, combat 4510, motion 1846, VFX 439.

Tag `mobile-0.1.18-debug`. Install: https://github.com/maurogp12/stasiumxii/releases/download/mobile-0.1.18-debug/stasiumxii-mobile-debug.apk

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
