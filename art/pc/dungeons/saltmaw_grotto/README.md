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

PROPS_TABLE

**Floor decal:**
- `whirlpool` (192x96) is the big swirling teal whirlpool of room B, ringed by a low stone kerb. In the design the swirling water spans about 3.2 board cells inside the ring of standing rocks, so it is a 3x3 decal like `rune_circle`. It fills the full 3x3 footprint diamond, with its bottom-centre on the south tip of origin+(2,2).
- It is walkable and goes on the ground layer, after the tiles.
- `whirlpool_glow` is its additive teal light.
- Ring it with blocking `rock_spire` props on the cells around the 3x3, as the design does, and leave gaps so it stays reachable.

**Backdrops** (`backdrops/`, 1x only):
- `room_a_grotto_{15x15,12x12}`: dark barnacled cave rock with dripping stalactites and seaweed, hanging lanterns, fishing nets, glowing teal coral and pools at the wall bases, and the broken ship hull and torn sail on the right back wall.
- `room_b_lair_{15x15,12x12}`: blue-green cave walls with seaweed and teal light shafts, the giant whale skeleton along the back wall, the mermaid and seahorse figureheads in the corners, a giant clam, barrels and heaps of gold along the wall bases.
- They are made with the Granary method: the painted room shell with a flat **magenta** floor diamond, fitted affinely onto the board diamond, with the diamond cut out.
- The floor outside the board is painted with the room's tiles, darkened.
- Draw the backdrop behind the tiles so that pixel `cell00_centre_px` lands on `cell_to_local(0,0)`.
- The dark surround is alpha 0; clear to near-black. Fit the camera to the backdrop's bounds to show the back walls.

**Mock:** `_mock/rooms_mock.png` (`room_a_mock.png`, `room_b_mock.png`) shows both rooms assembled at game camera scale (1 board px = 1 screen px), with the monsters at pawn scale 0.5. The painted hero idle frames stand in for the heroes. `_mock/rooms_mock_star5.png` is the same with the ★5 forms.

MONSTERS_SECTION

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
