# Ship log

Durable record of feel passes on the mobile track. Kit numbers in here are reminders of what stayed Locked. They are not a second source of truth. The legal sentences live in `docs/STASIUM_XII_GDD_handoff.md`.

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
