# Saltmaw Grotto: game art (Eastmarch dungeon, levels 20–30)

Game-ready art for the third PC dungeon, repainted piece by piece from the approved look targets in `docs/pc/look_target/dungeons/saltmaw_grotto/` (branch `claude/pc-zones-spec`). It is built exactly like the Old Granary Cellar and the Frostspire Archive, with the same shared scripts. **`manifest.json` lists every file with its kind, size, pivot or anchor, footprint or cell, frame counts and fps.** Load from the manifest; this README only explains it. The manifest uses the same format and keys as the other two (`stasium.dungeon_art` v1).

Every PNG has binary alpha (0/255) with RGB 0 under alpha 0. Files named `*_glow` are additive light maps: draw them with an add blend. `_2x/` files are 2x masters: draw them at scale 0.5 in the same place as the 1x file. `_mock/` is review material only (it has a `.gdignore`).

Every keyed piece was painted on flat **magenta** (#FF00FF), not green: the grotto is teal water, glowing teal coral and green seaweed throughout, which a green key would eat.

## 1. Town door: `town/`

| file | what |
|---|---|
| `saltmaw_door.png` (192x172), `_2x/` (384x344) | The sea-cave entrance in the Eastmarch docks kit style: a mossy grey sea-rock outcrop whose cave mouth is a gaping fish maw ringed with bone-white fangs, skulls and barnacles, glowing teal-green deep inside. A plank pier with rope railings runs out of the maw to the lower left, with a lantern post, a fishing net and buoy, a barnacled barrel and two crates. There is no Door Keeper in the sprite: use the existing `door_keeper` NPC. |
| `saltmaw_door_glow.png`, `_2x/` | Additive teal-green glow deep inside the maw, on the same canvas. Fade it in on hover. |

- **Footprint:** 3x3 cells, all blocking. I measured it on the painting: the rock base's side tips are at x 25 and x 1002, so the base diamond is about 977 px wide. One cell is 330 px and the footprint's south tip is at (513, 962). `_mock/town_door_mock.png` shows the result.
- **Anchor:** the Crosshaven kit rule. The image's bottom-centre sits on the south tip of cell origin+(2,2), which is `(0, +80)` px from the NW cell's centre at 1x.
- **Depth sort:** sort by the south cell, as `crosshaven_prop.gd` does.
- **Door cell: origin+(1,3)**, as for the Granary (Frostspire's is (2,3)). The maw opens on the SW (+y) face and the pier ends at the SW edge of cell (1,2). The door cell is passable and lies just outside the footprint, at the pier end. Put the Door Keeper on a neighbouring cell, origin+(0,3) or origin+(2,3).
- **Overhang:** the small rock at the front tip and the pier posts overhang the south edge of the footprint by a few px. They are part of the sprite.
- **Scale:** next to a `fishing_hut_2x2` it reads as a squat rock landmark rather than a tall tower. See `_mock/town_door_mock.png`, and `_mock/town_door_hover_mock.png` for the hover glow.

## 2. Combat-board kit: `board/`

The board uses the same `board_view.gd` math as the Granary: `cell_to_local(x,y) = ((x-y)*32, (x+y)*16)`, the diamond centre.

**Floor tiles** (`tiles/`, 64x32, with 128x64 `_2x/` masters):
- Room A (the sea cave): `grotto_floor_a/b/c`, wet dark slate with sand, shells and a pool of shallow teal water in one corner.
- Room B (Old Saltmaw's treasure lair): `lair_floor_a/b/c`, blue-green sea stone with glowing teal caustics and a few gold coins.
- Same rules as the Granary: centred on the cell, cut on the painted grout line, a 0.5 px bleed on the diagonals. Pick the variant with `h(x,y,3)`.

**Coral pads:**
- `coral_pad` is the glowing teal sea-fan coral pad. It replaces the floor tile on a pad cell, in both rooms.
- `coral_pad_glow` (96x56, additive) adds the light spill. Draw it at `cell_to_local - (48, 32)`. Pulsing it is optional.

**Obstacle props** (`props/`):
- Each prop's image bottom-centre sits on the south tip of its south-most cell.
- Props y-sort with the units. All of them are 1x1 blockers.
- `coral_cluster` carries its own additive `_glow` on the same canvas; draw it on top of the prop.

| id | size (1x) | footprint | room | glow |
|---|---|---|---|---|
| `sunken_crate` | 60x71 | 1x1 | A+B |  |
| `barrel` | 60x61 | 1x1 | A+B |  |
| `coral_cluster` | 56x65 | 1x1 | A | `coral_cluster_glow` |
| `anchor` | 60x68 | 1x1 | A |  |
| `barnacle_rock` | 58x54 | 1x1 | A+B |  |
| `giant_clam` | 60x67 | 1x1 | B |  |
| `treasure_chest` | 56x64 | 1x1 | B |  |
| `sunken_statue` | 48x80 | 1x1 | B |  |
| `rock_spire` | 42x75 | 1x1 | B |  |

**Floor decal:**
- `whirlpool` (320x160) is the big swirling teal whirlpool of room B, ringed by a low stone kerb. **It is 5x5, not 3x3.** I measured it on the approved boss-room design, where one tile diamond is about 80 px wide: the swirling water spans about 3.7 cells and the kerb with its standing rocks about 5.8 cells. A 3x3 decal like `rune_circle` was visibly too small in the mock. It fills the full 5x5 footprint diamond, with its bottom-centre on the south tip of origin+(4,4); the kerb runs along the 16 border cells and the water fills about the inner 3x3.
- It is walkable and goes on the ground layer, after the tiles.
- `whirlpool_glow` is its additive teal light.
- Stand blocking `rock_spire` props on some of the border cells of the 5x5 (the design shows 8 to 10 rocks on the kerb), leaving gaps so the water stays reachable. The mock uses 7 rocks.

**Backdrops** (`backdrops/`, 1x only):
- `room_a_grotto_{15x15,12x12}`: dark barnacled cave rock with dripping stalactites and seaweed, hanging lanterns, fishing nets, glowing teal coral and pools at the wall bases, and the broken ship hull and torn sail on the right back wall.
- `room_b_lair_{15x15,12x12}`: blue-green cave walls with seaweed and teal light shafts, the giant whale skeleton along the back wall, the mermaid and seahorse figureheads in the corners, a giant clam, barrels and heaps of gold along the wall bases.
- They are made with the Granary method: the painted room shell with a flat **magenta** floor diamond, fitted affinely onto the board diamond, with the diamond cut out.
- The floor outside the board is painted with the room's tiles, darkened.
- Draw the backdrop behind the tiles so that pixel `cell00_centre_px` lands on `cell_to_local(0,0)`.
- The dark surround is alpha 0; clear to near-black. Fit the camera to the backdrop's bounds to show the back walls.

**Mock:** `_mock/rooms_mock.png` (`room_a_mock.png`, `room_b_mock.png`) shows both rooms assembled at game camera scale (1 board px = 1 screen px), with the monsters at pawn scale 0.5. The painted hero idle frames stand in for the heroes. `_mock/rooms_mock_star5.png` is the same with the ★5 forms.

## 3. Monsters: `monsters/<id>/<action>/<action>_<S|E>_fNN.png`

| id | cell | pivot | actions (frames) |
|---|---|---|---|
| `reef_crab` | 512x360 | (256,329) | idle 12, walk 12, attack 12, hit 8, death 13 |
| `drowned_sailor` | 512x360 | (256,329) | idle 12, walk 12, attack 12, hit 8, death 13 |
| `drowned_harpooner` | 512x360 | (256,329) | idle 12, walk 12, attack 12 (**release f07**), hit 8, death 13 |
| `old_saltmaw` | **768x540** | **(384,494)** | idle 12, walk 12, attack 12, hit 8, death 13, **summon 14** "Lantern Lure" (+ `summon_*_glow`) |

**Format** (as the Granary and Frostspire):
- 17.144 fps. Idle and walk loop; the other actions play once, and death holds its last frame.
- S is the front facing screen down-right; E is the back facing screen up-right. The other two facings are game-side `flip_h` mirrors.
- Each monster's `meta.json` repeats the cell, pivot, fps, frame counts and QA numbers.
- Melee attacks (crab, sailor, the boss's bite) connect on **attack f06**.
- The boss is placed like the Ratking: his (384,494) lands where a hero's (256,329) lands. For a centred Sprite2D that is the hero offset minus (0,75) before scale.

**Reef Crab (room A melee tank):**
- A big low, wide crab with a barnacle-crusted rust-red and blue-grey shell, red coral on its back, glowing teal eyes and two huge pincers. Like the Granary rat it is low (about 225 px tall, 240 px wide in the cell).
- **Walk:** a quick scuttle, two leg beats per loop. **Attack:** both claws rear up (f02–f04), it lunges and snaps on **f06**.
- **Death:** it rears, flips onto its back and the legs curl and twitch.

**Drowned Sailor (room A melee):**
- A drowned pirate in a barnacled tricorn with a rusty cutlass and a glowing teal lantern.
- **Attack:** the cutlass rises high and back (f03–f04) and hacks down across on **f06**.

**Drowned Harpooner (room A ranged), my proposal for Mauro's ranged-room-A rule:**
- A drowned whaler in a knitted cap and a long oilskin coat, three spare harpoons strapped on his back, a rope coiled from the throwing hand.
- **Attack:** he cocks the harpoon back, trembling (f01–f06), and hurls it on **f07, the release frame**. The harpoon in his hand is hidden f07–f10 (the projectile takes over), and a fresh one is back in his hand on f11.
- **Projectile spawn:** `meta.json > release.point_px` gives the harpoon's position at release, per facing, in cell pixels (S (294,121), E (386,153)). Mirror its x for the mirrored facings.
- **Projectiles** (`board/projectiles/`, centred):
  - `harpoon` (48x17): a rusty barbed harpoon pointing along +x. Rotate it to the flight direction; a slight arc reads well.
  - `harpoon_impact` (50x49): a burst of sea foam and teal droplets with splinters. Play it as a scale-up and fade of about 0.25 s at the hit point.

**Old Saltmaw signature, `summon` "Lantern Lure"** (the systems agent's proposal; the strip name stays `summon`):
- f00–f02 he crouches; f03–f06 the lure lifts high as the jaw gapes.
- On **f07** the lure **flares**: the pull fires here. `meta.json > lure_point.point_px` is the lure tip on f07 per facing (S (491,116), E (484,114) in the 768x540 cell).
- f07–f10 he holds the blazing lure while the hero slides toward him; f10–f13 he settles back to idle.
- `summon/summon_{S,E}_fNN_glow.png` is the lure's additive teal glow for this action only. It builds f03–f06, peaks on f07, holds to f10 and fades by f12. Draw it like a ★5 glow.
- `board/projectiles/lure_line` (+ `_glow`, 100x22) is the optional teal light streak along +x, bright end at +x. On f07 stretch it from the hero to `lure_point` and fade it out over f07–f10, with an add blend.
- The key frames are in `meta.json > signature` (`crouch [0,2]`, `lift [3,6]`, `flare 7`, `pull [7,10]`, `settle [10,13]`).

**Turnarounds and contact sheets:** `_mock/<id>_turnaround.png` shows the S and E paintings each rig is cut from. `_mock/<id>_contact.png` shows every frame of every action. `_mock/monsters_clip.mp4` plays every action in all four facings.

## 4. Star 5: Abyssal Saltmaw (`star5/`)

At ★5 the boss is the **Abyssal Saltmaw**, Old Saltmaw risen from the deepest trench. **Mauro approved this look as is** (asset `asset_BprqPkz3sofoVCkkEocsbweL`, "Approve it", 10 Oct 2026). The ★5 crab, sailor and harpooner follow the same black-and-cyan theme. His look:
- abyssal navy-black skin with glowing bioluminescent cyan spots, stripes and veins;
- dark translucent fins with glowing cyan edges, and black barnacles with cyan cores;
- black-iron chains and anchor etched with cyan runes;
- blazing cyan eyes, a cyan glow deep in the maw, and a white-hot cyan lure.

| id | cell | pivot | actions |
|---|---|---|---|
| `star5/monsters/abyssal_saltmaw` | 768x540 | (384,494) | as `old_saltmaw`, summon 14 (same rig, timing, signature frames and lure_point) |
| `star5/monsters/abyssal_reef_crab` | 512x360 | (256,329) | as `reef_crab` (black shell with cyan cracks, black coral with glowing tips) |
| `star5/monsters/abyssal_drowned_sailor` | 512x360 | (256,329) | as `drowned_sailor` (blue-black skin, cyan rune cutlass, white-cyan lantern) |
| `star5/monsters/abyssal_drowned_harpooner` | 512x360 | (256,329) | as `drowned_harpooner`, release f07 (black-iron rune harpoons) |

**Glow maps:**
- Every ★5 frame has a same-size additive light map, `<frame>_glow.png`: the saturated cyan paint (spots, veins, runes, eyes, lure) bloomed, plus a faint cyan aura.
- Draw it on top of the frame with the same offset, scale and flip, using an add blend.

**Other ★5 pieces:**
- `star5/board/riptide.png` is the ★5 hazard "Riptide": a 1-cell, 64x32 patch of swirling abyssal water with glowing cyan currents, with a 128x64 `_2x/` master and `riptide_glow.png` (96x56, additive). It is centred on the cell, on the ground layer. Ending a turn on it deals damage and drags the hero 1 cell toward the boss; only the visual is here, the rule is CombatSim's.
- `star5/board/projectiles/abyssal_harpoon.png` is the black-iron rune harpoon of the Abyssal Drowned Harpooner, with a `_glow`.

**Review images:**
- `_mock/abyssal_saltmaw_turnaround.png` shows the base S next to the abyssal S and E paintings.
- `_mock/star5_<id>_contact.png` shows every frame with the glow baked in, on dark. `_mock/monsters_clip_star5.mp4` is the ★5 clip.


## Pipeline (`build_tools/dungeons/`)

Saltmaw adds only its piece lists and numbers; all the cutting is the shared kit. The Granary and Frostspire outputs are unchanged: `check_granary_repro.py` and the new `check_frostspire_repro.py` rebuild each kit into a scratch folder and check that it is byte-identical to the committed files.

| script | does |
|---|---|
| `build_saltmaw_town.py`, `build_saltmaw_board.py`, `build_saltmaw_fx.py` | The door, the board kit, and the projectiles, lure line, ★5 harpoon and ★5 riptide. |
| `saltmaw_monsters.py` (+ `mrig.py`, `monster_kit.py`) | Monster rigs and actions; `python3 saltmaw_monsters.py <id>` builds one. |
| `build_saltmaw_manifest.py` | Writes `manifest.json`. It fails if any PNG is not listed. |
| `mock_rooms.py saltmaw_grotto [--star5]`, `mock_town.py saltmaw_grotto`, `mock_turnarounds.py --dungeon saltmaw_grotto`, `mock_monsters.py --dungeon saltmaw_grotto --clip a.mp4 --clip5 b.mp4` | The review mocks, contact sheets and clips. |
| `check_granary_repro.py`, `check_frostspire_repro.py` `[--skip-monsters]` | The byte-identity checks. |

Small optional additions to the shared kit, none of which changes the older outputs:
- `fx_kit.projectile_sheet` takes an optional `box` (source px) per sprite, for paintings that cross the sheet's half-lines;
- `mrig` skips a part whose pose has `<part>.hide` set (the harpoon after release);
- `monster_kit` records optional named `points` like `release` (`lure_point`);
- `mock_town` takes a per-dungeon Door Keeper cell, `mock_rooms` a per-dungeon ★5 swap list.

**Sources:** `saltmaw_src/` holds the chosen paintings (`_star5_gate_abyssal_saltmaw.jpg` is the comparison sent to Mauro, not a source).

KNOWN_ISSUES

SOURCES_TABLE
