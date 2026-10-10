# Frostspire Archive: game art (Northgate dungeon, levels 10–20)

Game-ready art for the second PC dungeon, repainted piece by piece from the approved look targets in `docs/pc/look_target/dungeons/frostspire_archive/` (branch `claude/pc-zones-spec`). It is built exactly like the Old Granary Cellar, with the same shared scripts. **`manifest.json` lists every file with its kind, size, pivot or anchor, footprint or cell, frame counts and fps.** Load from the manifest; this README only explains it. The manifest uses the same format and keys as the Granary's (`stasium.dungeon_art` v1).

Every PNG has binary alpha (0/255) with RGB 0 under alpha 0. Files named `*_glow` are additive light maps: draw them with an add blend. `_2x/` files are 2x masters: draw them at scale 0.5 in the same place as the 1x file. `_mock/` is review material only (it has a `.gdignore`).

Every keyed piece was painted on flat **magenta** (#FF00FF), not green, because the dungeon is ice-blue and cyan throughout.

## 1. Town door: `town/`

| file | what |
|---|---|
| `frostspire_door.png` (218x312), `_2x/` (438x623) | The archive tower in the Northgate snow kit style: snowy slate spires, icicles, a snowflake rose window, amber gothic windows, and open iron-banded doors onto an ice-blue glow, with frosted steps, a book-and-snowflake banner, a lantern and book crates. There is no Door Keeper in the sprite: use the existing `door_keeper` NPC. |
| `frostspire_door_glow.png`, `_2x/` | Additive ice-blue glow over the open doorway and the steps, on the same canvas. Fade it in on hover. |

- **Footprint:** 3x3 cells, all blocking. I measured it on the painting: the footprint's south tip is at (515, 996) and one cell is 200 px wide. `_mock/town_door_mock.png` shows the result.
- **Anchor:** the Crosshaven kit rule. The image's bottom-centre sits on the south tip of cell origin+(2,2), which is `(0, +80)` px from the NW cell's centre at 1x.
- **Depth sort:** sort by the south cell, as `crosshaven_prop.gd` does.
- **Door cell: origin+(2,3)** (the Granary's is (1,3)). The doorway is on the SW (+y) face, and its steps come down into cell (2,2), next to the south tip. The door cell is passable and lies just outside the footprint, in front of the steps. Put the Door Keeper on a neighbouring cell, origin+(1,3) or origin+(3,3).
- **Overhang:** the book crates at the left corner overhang the west edge of the footprint by a few px. They are part of the sprite.
- **Scale:** next to a `cottage_slate_snow` 2x2 it reads as a tall town landmark. See `_mock/town_door_mock.png`, and `_mock/town_door_hover_mock.png` for the hover glow.

## 2. Combat-board kit: `board/`

The board uses the same `board_view.gd` math as the Granary: `cell_to_local(x,y) = ((x-y)*32, (x+y)*16)`, the diamond centre.

**Floor tiles** (`tiles/`, 64x32, with 128x64 `_2x/` masters):
- Room A (the archive stacks): `archive_floor_a/b/c`, cold blue-grey slate with frost.
- Room B (the Pale Archivist's reading hall): `hall_floor_a/b/c`, pale ice-blue marble with glowing frost cracks.
- Same rules as the Granary: centred on the cell, cut on the painted grout line, a 0.5 px bleed on the diagonals. Pick the variant with `h(x,y,3)`.

**Rune pads:**
- `rune_pad` is the glowing ice-blue snowflake rune pad. It replaces the floor tile on a pad cell, in both rooms.
- `rune_pad_glow` (96x56, additive) adds the light spill. Draw it at `cell_to_local - (48, 32)`. Pulsing it is optional.

**Obstacle props** (`props/`):
- Each prop's image bottom-centre sits on the south tip of its south-most cell.
- Props y-sort with the units.
- Two props carry their own additive `_glow` on the same canvas; draw it on top of the prop.

| id | size (1x) | footprint | room | glow |
|---|---|---|---|---|
| `frozen_bookshelf` | 60x80 | 1x1 | A+B | |
| `book_pile` | 62x54 | 1x1 | A+B | |
| `reading_desk` | 60x69 | 1x1 | A | |
| `ice_crystals` | 50x76 | 1x1 | A+B | `ice_crystals_glow` |
| `frozen_chest` | 56x72 | 1x1 | A+B | |
| `frost_brazier` | 44x88 | 1x1 | B | `frost_brazier_glow` (flicker it) |
| `ice_throne` | 142x194 | 2x2 | B | (against the back wall) |

The ice throne is the Archivist's crystal throne behind a lectern with the chained grimoire, on a stone plinth.

**Floor decal:**
- `rune_circle` (192x96) is the big glowing rune circle of room B. It fills the full 3x3 footprint diamond, with its bottom-centre on the south tip of origin+(2,2), the same as the Granary's `drain_grate`.
- It is walkable and goes on the ground layer, after the tiles.
- `rune_circle_glow` is its additive cyan light.

**Backdrops** (`backdrops/`, 1x only):
- `room_a_archive_{15x15,12x12}`: dark stone and timber walls lined with frozen bookshelves, icicles, candles, arched alcoves, a ladder and the corner stair.
- `room_b_hall_{15x15,12x12}`: frosted gothic walls with snowy windows, chained pillars, snowflake banners, chandeliers, chained books, and the raised dais with the crystal throne and the reading desk.
- They are made with the Granary method: the painted room shell with a flat **magenta** floor diamond, fitted affinely onto the board diamond, with the diamond cut out.
- The floor outside the board is painted with the room's tiles, darkened.
- Draw the backdrop behind the tiles so that pixel `cell00_centre_px` lands on `cell_to_local(0,0)`.
- The dark surround is alpha 0; clear to near-black. Fit the camera to the backdrop's bounds to show the back walls.

**Mock:** `_mock/rooms_mock.png` (`room_a_mock.png`, `room_b_mock.png`) shows both rooms assembled at game camera scale (1 board px = 1 screen px), with the monsters at pawn scale 0.5. The painted hero idle frames stand in for the heroes. `_mock/rooms_mock_star5.png` is the same with the ★5 forms.

## 3. Monsters: `monsters/<id>/<action>/<action>_<S|E>_fNN.png`

| id | cell | pivot | actions (frames) |
|---|---|---|---|
| `ice_construct` | 512x360 | (256,329) | idle 12, walk 12, attack 12, hit 8, death 13 |
| `book_wraith` | 512x360 | (256,329) | idle 12, walk 12, attack 12 (**release f07**), hit 8, death 13 |
| `the_pale_archivist` | **768x540** | **(384,494)** | idle 12, walk 12, attack 12, hit 8, death 13, **summon 14** (+ `summon_*_glow`) |

**Format** (all as the Granary):
- 17.144 fps. Idle and walk loop; the other actions play once, and death holds its last frame.
- S is the front facing screen down-right; E is the back facing screen up-right. The other two facings are game-side `flip_h` mirrors.
- Each monster's `meta.json` repeats the cell, pivot, fps, frame counts and QA numbers.
- The boss is placed like the Ratking: his (384,494) lands where a hero's (256,329) lands. For a centred Sprite2D that is the hero offset minus (0,75) before scale.

**Ice Construct (room A heavy melee tank):**
- A hulking golem of frozen books and shelves, bound in chains, with a glowing chest rune.
- About 280 px tall in the hero cell, slightly taller than a hero.
- **Attack:** a two-fist ground pound. The fists heave up (f03–f04) and slam down in front on **f06, the hit frame**.
- **Walk:** a heavy stomp.
- **Death:** the knees buckle and the body topples onto its side.

**Book Wraith (room A ranged caster):**
- A floating wraith of shrouds and pages with an open book for a head and glowing eyes.
- It floats, so its walk is a glide with a bob. It has no feet; the pivot is the shadow point under the ragged tail.
- **Attack:** it draws the frost back, trembling (f01–f06), and hurls it on **f07, the release frame**. f08–f11 follow through.
- **Projectile spawn:** `meta.json > release.point_px` gives the casting hand's position at release, per facing, in cell pixels. Mirror its x for the mirrored facings.
- **Projectiles** (`board/projectiles/`, centred):
  - `frost_bolt` (with `frost_bolt_glow`): an ice shard pointing along +x. Rotate it to the flight direction and fly it straight.
  - `paper_bolt`: a frost-edged paper dart, an alternative look.
  - `frost_bolt_impact`: a frost burst. Play it as a scale-up and fade of about 0.25 s at the hit point.

**The Pale Archivist signature, `summon` "Unbound Pages":**
- He lifts the chained grimoire high above his head, with his claw raised, by f03.
- He holds it there straining and trembling, the tome glowing brighter, through f03–f09.
- On **f09** the pages burst out: **spawn the summoned Book Wraiths on f09.**
- f10–f13 the arms lower back to idle.
- The key frames are in `meta.json > signature` (`raise_start 3`, `glow_hold [3,9]`, `spawn 9`, `lower [10,13]`).
- `summon/summon_{S,E}_fNN_glow.png` is the tome's additive glow for this action only. It ramps up f01–f03, peaks on f09 and fades by f12. Draw it like a ★5 glow.

**Turnarounds and contact sheets:** `_mock/<id>_turnaround.png` shows the S and E paintings each rig is cut from. `_mock/<id>_contact.png` shows every frame of every action.

## 4. Star 5: The Frozen Archivist (`star5/`)

At ★5 the boss is **The Frozen Archivist**, the Pale Archivist mutated into a blizzard-bound frozen lich. **Mauro approved this look as is** (asset `asset_ewgK6MuSgYkjcvKYEaGxeAHx`, "Approve it", 10 Oct 2026), and the ★5 Construct and Wraith follow the same black-ice and cyan-rune theme. His look:
- cracked pale-blue ice skin and blazing cyan eyes;
- a crown of black-ice shards with glowing cyan cores;
- a beard and hair frozen to rime;
- midnight-blue frost robes with glowing cyan rune glyphs, and black-ice crystal growths on the shoulders and hem;
- the grimoire encased in black ice.

| id | cell | pivot | actions |
|---|---|---|---|
| `star5/monsters/the_frozen_archivist` | 768x540 | (384,494) | idle 12, walk 12, attack 12, hit 8, death 13, summon 14 (same rig, timing and signature frames as `the_pale_archivist`) |
| `star5/monsters/frozen_ice_construct` | 512x360 | (256,329) | as `ice_construct` (black ice, cyan cracks, a blazing rune) |
| `star5/monsters/frozen_book_wraith` | 512x360 | (256,329) | as `book_wraith`, release f07 (midnight shrouds, frozen glowing rune pages); his ★5 summons |

**Glow maps:**
- Every ★5 frame has a same-size additive light map, `<frame>_glow.png`. It is the cyan emissive paint (runes, eyes, crystal cores) bloomed, plus a faint ice-blue aura.
- Draw it on top of the frame with the same offset, scale and flip, using an add blend.

**Other ★5 pieces:**
- `star5/board/frost_patch.png` is a 1-cell, 64x32 black-ice rime patch with glowing cyan cracks, with a 128x64 `_2x/` master and `frost_patch_glow.png` (96x56, additive). It is centred on the cell, on the ground layer.
- The Frozen Archivist leaves these patches as his ★5 special, "Rime Patches". Only the visual is here; the effect is up to CombatSim.
- `star5/board/projectiles/frost_bolt_frozen.png` is the black-ice bolt of the Frozen Book Wraith, with a `_glow`.

**Review images:**
- `_mock/the_frozen_archivist_turnaround.png` shows the base S next to the frozen S and E paintings.
- `_mock/star5_<id>_contact.png` shows every frame with the glow baked in, on dark.

## Pipeline (`build_tools/dungeons/`)

The Granary scripts were generalised into shared modules. Each dungeon script is now only its piece list and numbers. The Granary's output is unchanged: `check_granary_repro.py` rebuilds the whole Granary kit into a scratch folder and checks that it is byte-identical to the committed files.

| script | does |
|---|---|
| `gkit.py` | Chroma key (green or magenta), binary-alpha cut, iso projection. `gkit.use(<dungeon>)` points every builder at one dungeon's sources and output. `despill_magenta` removes the pink cast from the frost monsters. |
| `board_kit.py`, `town_kit.py`, `fx_kit.py`, `monster_kit.py`, `manifest_kit.py` | The shared builders: tiles, pads, props (with optional glows), n x n decals and backdrops; the town door and its glow; cell decals and projectile sheets; the monster renderer with keep-in, release point and glows; and manifest listing and checking. |
| `build_frostspire_town.py`, `build_frostspire_board.py`, `build_frostspire_fx.py` | The door, the board kit, and the projectiles plus the ★5 frost patch. |
| `frostspire_monsters.py` (+ `mrig.py`) | Monster rigs and actions; `python3 frostspire_monsters.py <id>` builds one. |
| `build_frostspire_manifest.py` | Writes `manifest.json`. It fails if any PNG is not listed. |
| `mock_rooms.py frostspire_archive [--star5]`, `mock_town.py frostspire_archive`, `mock_turnarounds.py --dungeon frostspire_archive`, `mock_monsters.py --dungeon frostspire_archive --clip a.mp4 --clip5 b.mp4` | The review mocks, contact sheets and clips. |
| `check_granary_repro.py [--skip-monsters]` | The Granary byte-identity check. |

**Sources:** `frostspire_src/` holds the chosen paintings (`_star5_gate_frozen_archivist.jpg` is the comparison sent to Mauro, not a source).

## Known issues / what I'd change

KNOWN_ISSUES

## Scenario source assets (project "stasium")

Each piece was painted with the approved Frostspire images as references (door `asset_GLwpNouG2xFCuZVy6yq6HQkE`, room `asset_MS9xcNUb5ptmey33cQxjGkVJ`, boss room `asset_harbtJDyQXeHW6jJtVRPkHEJ`, monsters `asset_2jFCfHX4asMQhqVv5cfjkjYo`, Northgate snow style `asset_KAamhEK1FDAcir7fULWgNYyh`), using the Granary prompt patterns.

| piece | asset (chosen) | local copy in `build_tools/dungeons/frostspire_src/` |
|---|---|---|
| archive entrance building | `asset_5cQZwTSVeG9hKyej6R82WQni` | `town_frostspire.jpg` |
| archive floor a/b/c | `asset_5r8ue5b6xTd8R1XbPtkwZMQj`, `asset_u9kbZRpbzV7RwGV9yX6s4xcA`, `asset_rJYSp82n3khersPvxdesaonY` | `floor_a_{1,2,3}.jpg` |
| hall floor a/b/c | `asset_p1Px94aRRGfnQmUQ7DvZYAko`, `asset_ZVUcxWHsBwYx6BE9ME2mTF7i`, `asset_EWJkBL6sS8KFbqLDY5disqyG` | `floor_b_{1,2,3}.jpg` |
| rune pad | `asset_3qNce2YLEKgvWFGh3VEShyq2` | `rune_pad.jpg` |
| frozen bookshelf, book pile, reading desk, ice crystals, frozen chest | `asset_HxQYEUKXQRNYYZDpHpfgQ6Vc`, `asset_V2DsQmGPLKfPB4iVordgM5N9`, `asset_ongZUkSpQg1bkTZsovcoMudD`, `asset_Gtn6XS3mQXFHYfU4aT3Sn2Nu`, `asset_VmqgVFvhbA21GhZiCpUfAnY7` | `frozen_bookshelf.jpg`, `book_pile.jpg`, `reading_desk.jpg`, `ice_crystals.jpg`, `frozen_chest.jpg` |
| frost brazier | `asset_6zkLxhY222Ceu9QtkgEfcvG5` | `frost_brazier.jpg` |
| ice throne and lectern | `asset_C7YkkA1jz6pWXknXwJevVtEH` | `ice_throne.jpg` |
| rune circle | `asset_YNNF9CqYiC7M8MVgiyQmbCFR` | `rune_circle.jpg` |
| room A shell, room B shell | `asset_nY28gnEoJMxdWHFVw8uNmv8j`, `asset_nif6xzW1s8Hnvq9y1xF3UYzT` | `shell_room_a.jpg`, `shell_room_b.jpg` |
| Ice Construct S / E | `asset_V3S4h9ExMN9yDFcfx1xaf6Pc` / `asset_nc7P6fvpEkeXuAoBL7p8Yu1A` | `construct_S.jpg` / `construct_E.jpg` |
| Book Wraith S / E | `asset_L8b1cW8eVuYtqJz9oP31wqZp` / `asset_tJVBBhbndDHY1Wp75bhWheog` | `wraith_S.jpg` / `wraith_E.jpg` |
| The Pale Archivist S / E | `asset_nnqvpqnCRFASaGXR3Neihj7Z` / `asset_3XBzo9heKUFiZZ7m5WYkkWvz` | `archivist_S.jpg` / `archivist_E.jpg` |
| frost bolt, paper bolt, frost impact, black-ice bolt | `asset_dcMsqbWruFYcrxemqJjccTFc` | `frost_projectiles.jpg` |
| ★5 The Frozen Archivist S / E | `asset_ewgK6MuSgYkjcvKYEaGxeAHx` (approved by Mauro) / `asset_WJKhCnSuHBBG5Bk3pVYCvD9K` | `frozen_archivist_S.jpg` / `frozen_archivist_E.jpg` |
| ★5 Frozen Ice Construct S / E | `asset_peArEE5LRazVhmb2qHBzMLdr` / `asset_FSeFStrfRVifSKDVu1cu5nk4` | `frozen_construct_S.jpg` / `frozen_construct_E.jpg` |
| ★5 Frozen Book Wraith S / E | `asset_AoqKvpBcRrcvJcc1yiVy7Jf8` / `asset_t4zU5m8SRJCzESRkahgvu7Vj` | `frozen_wraith_S.jpg` / `frozen_wraith_E.jpg` |
| ★5 frost patch | `asset_5N4AgGCKbfGsSSfqw7pDUgUG` | `frost_patch.jpg` |
