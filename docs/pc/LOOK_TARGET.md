# STASIUM XII (PC): look target

Mauro, 3 Oct 2026, sending three fight clips: **"use this as what I want"**,
**"THIS IS what I want, it can be better looking"**. Earlier the same day:
**"MAIN GOAL A HIGH GRAPHICS GREAT VISUALS"**, **"DOFUS / WAKFU / WAVEN
COMBINED"**.

**PC is a different game from the mobile one** (Mauro, 3 Oct 2026). PC has
its own look, maps and rules track; nothing here changes the mobile game or the
`mobile` branch.

This page is the look every PC package aims at, then beats. It is a target for
the look, not a design to copy: our classes, kits, rules and maps stay Locked.
Painted 2D isometric only. **Never 3D.**

Reference board: `docs/pc/look_target/look_target_refs.jpg`. Today vs target:
`docs/pc/look_target/target_vs_now.jpg`. Answer pictures:
`docs/pc/look_target/move_range_options.jpg` (Q2) and
`docs/pc/look_target/grid_options.jpg` (Q3). The clips themselves are Mauro's
screen recordings (not in the repo).

> **Characters: unparked** (Mauro, 3 Oct 2026). The earlier "not now:
> characters" note no longer applies. L5 (fighter readability) merged as #234.
> The NPC bodies follow the approved 19-role sheet and the Farmer reference
> (ZONES 4.5a). The new player characters are L10. Monsters come with WP9.
> Walk lean and gait feel (WP13) stay parked.

## The three references

| | Clip | What it sets the bar for |
|---|---|---|
| **A** | Wakfu outdoor fight (YouTube 2S_DDtfYd7s, about 6:58–7:15; Mauro's capture of 3 Oct) | The open world, and the outdoor Koliseo maps |
| **B** | Wakfu dungeon fight (Mauro's screen recording, 28 Sep) | Dungeon arenas |
| **C** | Waven fight (Mauro's screen recording, 2 Oct) | UI, lighting, readability of fighters and turns |

## A. Wakfu outdoor: the world and the outdoor arenas

1. **The board is a place, not a floating diamond.** Lush jungle fills every
   screen edge: giant painted leaves in front of and behind the board, with
   soft leaf shadows falling across it.
2. **Chunky terraces:** raised grass blocks and sunken sand paths, 2–3 height
   levels, deep cliff sides.
3. **Thick grass that overhangs every block edge,** with tufts, small yellow
   flowers and lilac bushes along the cliffs.
4. **Two clear ground materials:** bright saturated grass and warm carved
   sandstone slabs.
5. **No grid on the ground at rest.** Cells appear only when they matter.
6. **Move range is solid bright-blue tiles** that follow the terrain, with a
   thin light rim and a small gap between cells.
7. **Spell zones and marks are painted glyphs on the tiles** (eyes, crosses, a
   dark grate), purple and translucent.
8. **Bright, warm, saturated light**, soft contact shadows only; light shafts
   and floor glows on casts; big red damage numbers.

## B. Wakfu dungeon: the dungeon arenas

1. **Each dungeon has a themed floor that glows:** in the clip a green circuit
   board with glowing blue and red pads. Our 11 dungeons each get their own
   (Stormspire's dungeon, Thunderwell Core, fits this clip almost exactly).
2. **Pillars of light** rise from key cells and from fighters (cyan beams).
3. **The room around the board is dark and quiet** (walls fading to black), so
   the lit floor and the fighters pop.
4. **Special cells are props that glow** (pads, vents, skull plates on the
   rim), not flat colours.
5. Monsters glow in the room's colour; HP bars over every head.

## C. Waven: UI, lighting and readability

1. **Cinematic lighting:** a dark, moody room lit by candles and the fight
   itself; strong rim light on fighters.
2. **Move area as one merged shape** (a purple region with a faint emblem),
   not a cell-by-cell grid.
3. **Hexagon ring under every fighter:** blue for your team, red for enemies.
   Numbers (HP, armour) float over the head.
4. Spell bar (Waven uses cards; **we use one action bar instead**, Mauro 3 Oct):
   big painted icons with the cost on each, and a big **End Turn** button.
5. **Portraits:** your hero top-left with HP; the boss / chapter top-right; turn
   order as hexagon portraits on the left.
6. **Turn banner** ("YOUR TURN") and short speech bubbles from characters.
7. Bold, chunky characters that read at a glance on a small screen.

## D. The open-world map: the Crosshaven plate

Brief: [`look_target/CROSSHAVEN_OPEN_WORLD_BRIEF.md`](look_target/CROSSHAVEN_OPEN_WORLD_BRIEF.md)
Plate: [`look_target/crosshaven_plate.jpg`](look_target/crosshaven_plate.jpg)
(Mauro, 3 Oct 2026; Proposed art direction, not a combat or level lock). Look
target: the painted Crosshaven plate. It is a cliff island or peninsula with
pale roads running out from an open centre to five towns. Each town has
red-brown roofs and its own tower. Hay-gold fields lie between the towns,
with a clear blue sea, white breakers and a timber dock.

- **Where it applies:** the world-map plate and any whole-island art, plus
  the palette and landmarks of the Crosshaven chunks and the 4.4 joins (bridges
  and passes where roads leave the coast and cliffs). The in-game chunks keep
  the Wakfu-outdoor camera from section A; the brief's "not iso tiles" rule is
  for the map plate only.
- **Open-world test:** trace a walk from Westwatch to Eastmarch without leaving
  a road or field. A void, a UI circle or a floating slab fails. This is the
  art side of the WP4 cell-by-cell walk test.
- **Snow:** Northgate is the only Crosshaven town with snow, and only a
  little: a light dusting on roofs, walls and the north cliffs, with a few
  patches on the ground. Stoneford, Westwatch, Southbridge, Eastmarch and the
  Crossroads have none (Mauro, 3 Oct 2026).
- **Outer regions** leave Crosshaven by the same roads and coast and in the
  same paint, then shift material (ash, fen, dock, stone). They never become a
  second art style.
- **Do not copy the v6 chunk-board sheet:** dark navy field, dashed rings,
  floating iso slabs, or level numbers. No labels or giant title on in-game
  ground.
- Every art bot task pastes the brief and attaches the Crosshaven painting.

## What "better looking" means for us

- Higher-resolution paint (2x masters, 8x supersampled, like the Crosshaven v7
  kit) than the 2012-era Wakfu tiles.
- Waven's cinematic light and rim light on Wakfu's painted 2D world.
- A living board: leaves sway, light flickers through the canopy, critters and
  pollen drift, dungeon floors pulse.
- The smooth glide walk (combat glide on `claude/stasium-xii-pc`) and a camera
  that drifts with the active fighter.

## Today vs target (PC `main`, Crosshaven arena)

| Target | Today |
|---|---|
| Board inside a world (A) or a dark lit room (B, C) | Beige diamond floating on flat grey |
| Terraces with grass overhang and cliffs | Mostly flat tiles, hard edges |
| Grid hidden at rest; solid blue range, or one merged area | Cell lines always visible; pale blue tint |
| Painted glyphs and glowing pads | Thin outline circles |
| HP bar over heads, team hex ring | Name tags, small ring |
| One clear action bar of spells and actions, bold End Turn, turn banner | Plain buttons |
| Warm saturated light, light shafts, big numbers | Flat light, small effects |
| Close camera, the board fills the screen | Zoomed out, lots of empty background |

## Work for the build team (Proposed)

| Package | Who | What |
|---|---|---|
| L1: Terrace tile kit (A), **height levels kept** | Scenario + TA | Grass top ×4, grass overhang edges and corners, cliff side strips at 1–3 steps, sandstone slabs ×4, lilac bushes, flower tufts. 64×32 at 1x, 128×64 at 2x, the Crosshaven kit light rules. |
| L2: Backdrops (A, B) | Scenario + Code | A painted surround per map: jungle leaves in front and behind with leaf shadows (outdoor); a dark room with lit edges (dungeons). New backdrop layer behind and in front of the board in `board_view.gd`; the grid itself does not change. |
| L3: Range, zones and glyphs (A, C) | Code + Scenario | **Grid hidden at rest** (Mauro, 3 Oct: Wakfu way, our own and better): cells fade in on Walk / spell pick and out after the action, soft hover outline on the cell under the mouse, hold Alt (Proposed) for the full grid; move range **one tile per reachable cell, Wakfu style in our own look** (Mauro, 3 Oct): our own colour, a soft glow and a gentle pulse, a thin light rim, small gaps between cells, following the terrain heights; painted glyph decals for zones, marks and deploy cells. |
| L4: Dungeon floors (B) | Scenario + TA | One glowing floor kit per dungeon theme, glowing pads, light pillars, starting with Thunderwell Core (Stormspire; called "Coilgate" before PC got its own dungeons). |
| L5: Fighter readability (A, C), **parked: not now (characters)** | Code + TA | Team hex ring under the feet (blue / red); **name and HP bar over every head** (Mauro, 3 Oct), in its own script, view only, CombatSim stays authoritative; chibi scale check. |
| L6: Combat UI (C) | Code + Scenario | **One action bar, no cards** (Mauro, 3 Oct: "just a bar that shows spells, actions"): the class's few spells as large, clear slots with a painted icon each, the AP cost on the slot, and the actions (Walk, Face, End Turn) in the same bar. Since there are only a few spells, the slots are big and easy to read. A usable slot is lit; one that can't be used dims and says why on hover (no AP, out of range, needs Impact). Hover shows the attack tooltip with the Locked hit %; the picked slot stays highlighted and lights the board cells. AP and MP shown next to the bar; End Turn stands out. Plus hero and opponent portraits with HP, turn order, a "YOUR TURN" banner. Numbers come from CombatSim / `data/spell_tooltip.gd` only. |
| L7: Light and VFX (A, B, C) | TA + Feel | Warm saturated grade outdoors, cinematic grade in dungeons; rim light; light shafts and floor glows on casts; bigger damage numbers. **Thunderwell board stays as it was** (Mauro, 3 Oct: "the second map go back as it was"): no grade, vignette, shafts or floor glow there; the fighter rim and the bigger numbers stay. |
| L9: Outdoor board redo (A) — **next after L7** | Scenario + TA + Code | Mauro, 3 Oct, on the L7 clip: "the first one tiles need to be upgraded and decorations need to be replaced, just redo the whole map". Redo the outdoor (jungle / Crosshaven) combat board from scratch: a new painted tile set at 2x (grass, sand, stone, water, mud at the L1 terrace heights, Wakfu-outdoor quality), and new decorations that replace every current board prop (towers, pillars, crates, stumps, coins). The props are placed to read cover and line of sight, not scattered. The grid, cell sizes and the CombatSim map data do not change. Light: the L7 outdoor grade is chosen by Mauro on the **new** board. Media: before/after at 1280 and 1920, plus a 15 s cast clip. |
| L10: New player characters (A, C) | Code + TA | Mauro, 3 Oct: "Another bot is presenting the new characters in the PC game, use them." When that bot's character set lands, it replaces today's fighter sprites everywhere on PC: the world walker, the combat pawns, the action-bar portraits and the class picker. It replaces L5's "characters parked" note. Wire them through the existing sprite and animation paths with no change to CombatSim or class data. Keep the locked N/E/S/W facing rule, give them the NPC world light (4.5a), and follow the L7 rim. Media: each character idle, walk and cast, in the world and on both boards, at 1280 and 1920. Mobile does not change. |
| L8: Camera (all) | Feel | Closer default zoom that fills the screen; drift with the active fighter; whole board reachable by pan. |

Every package ends with a before/after pair: the same arena and camera, next to
the matching reference frame.

## Questions for Mauro (all answered 3 Oct 2026)

1. ~~**Terraces** (2–3 height levels) on every outdoor map?~~ **Answered 3 Oct
   2026 (Mauro): keep the height levels.** PC is a different game from mobile,
   so the PC maps keep and show their height levels as Wakfu-style terraces.
   PC map changes are made only in PC files; the mobile maps are not touched.
2. ~~**Move range:** solid blue tiles (Wakfu, A) or one merged area (Waven, C)?~~
   **Answered 3 Oct 2026 (Mauro): "wakfu style, just do it our own way".**
   One tile per reachable cell, so players can count cells, drawn in Stasium
   XII's own style (our colour, glow and motion), not a copy of Wakfu's tiles.
3. ~~**Hide the grid at rest?**~~ **Answered 3 Oct 2026 (Mauro): "yes, follow
   wakfu but do our own way and better".** No cell lines at rest: the ground
   reads as a real place. Cells fade in when the player picks Walk or a spell
   (move tiles, spell area marks) and fade out after the action. The cell
   under the mouse always gets a soft outline. Holding a key (Proposed: Alt)
   shows the full grid for counting. View only: no rule changes.
4. ~~**HP bars over heads** instead of name tags?~~ **Answered 3 Oct 2026
   (Mauro): "hp and name".** Both over every fighter's head: the name and an
   HP bar under it, in our own style (team colour, smooth drain on damage).
   Code note: `board_view.gd` must never contain the text `hp` (a test
   enforces it), so the plate lives in its own script (e.g.
   `units/overhead_plate.gd`) and reads the CombatSim snapshot; it shows
   numbers, it never decides them.
5. ~~**Card-style spell bar** (Waven) for the PC combat UI?~~ **Answered 3 Oct
   2026 (Mauro): no cards. "just a bar that shows spells, actions".** One
   action bar with the class's spells and the actions (Walk, Face, End Turn),
   looking clean and good (see L6). This replaces his earlier "yes, make it
   look cool" to cards.

6. ~~Start with the **Crosshaven jungle backdrop** (A) and the **Coilgate
   dungeon floor** (B)?~~ **Answered 3 Oct 2026 (Mauro): yes.** These two are
   the first look packages: the Crosshaven jungle backdrop (L2) and the
   Stormspire dungeon floor (L4), now Thunderwell Core.

## Start here (build team)

> **Priority:** this look track comes **after** the world track in
> `docs/pc/ZONES_BUILD_SPEC.md` (Mauro, 3 Oct 2026: "focus on map zones lvl
> dungs and npc with missions"). Characters stay parked.

PC combat is on `main`'s line. The look packages go on their own integration
branch, **`pc/combat-look`**, created from **`claude/stasium-xii-pc`** (which is
`main` plus the combat glide walk), one branch per package. Never push to
`main` or `mobile`; only Mauro merges.

First two packages (Mauro, 3 Oct: Q6 yes):

1. **L2, Crosshaven jungle backdrop**: painted jungle around the Crosshaven
   arena (leaves in front and behind, leaf shadows across the board, sway),
   a new backdrop layer in `board_view.gd`, grid and rules unchanged.
2. **L4, Thunderwell Core dungeon floor** (Stormspire's PC dungeon; Mauro's
   "Coilgate floor" yes carries over): the first glowing dungeon floor kit
   (reference B).

Then L3 (grid hidden at rest + Wakfu-style range our own way), L6 (action
bar), L1 (terrace kit, height levels kept), L7, L8. L5 (name and HP over heads)
waits: characters are not the focus yet.
Every package: tests green (`for f in tests/run_*_tests.gd; do godot
--headless --path . -s res://$f; done`), a before/after pair next to the
matching reference frame, and a line in `docs/pc/CHANGE_LOG_PC.md`.

