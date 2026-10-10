# Drowned Abbey: game art (Southbridge dungeon, levels 30–40, swamp danger zone)

Game-ready art for the fourth PC dungeon, repainted piece by piece from the approved look targets in `docs/pc/look_target/dungeons/drowned_abbey/` (branch `claude/pc-zones-spec`). It is built exactly like the Granary, the Frostspire Archive and the Saltmaw Grotto, with the same shared scripts. **`manifest.json` lists every file with its kind, size, pivot or anchor, footprint or cell, frame counts and fps.** Load from the manifest; this README only explains it. The manifest uses the same format and keys as the other three (`stasium.dungeon_art` v1).

Every PNG has binary alpha (0/255) with RGB 0 under alpha 0. Files named `*_glow` are additive light maps: draw them with an add blend. `_2x/` files are 2x masters: draw them at scale 0.5 in the same place as the 1x file. `_mock/` is review material only (it has a `.gdignore`).

Every keyed piece was painted on flat **magenta** (#FF00FF), not green: the abbey is green moss, green flood water and green rune light throughout, which a green key would eat.

## 1. Town door: `town/`

| file | what |
|---|---|
| `abbey_door.png` (194x199), `_2x/` (388x398) | The Drowned Abbey entrance in the Southbridge swamp-and-bridge style: a ruined grey-stone Gothic chapel front on a broken mossy foundation, a pointed arch with a rose window and a hooded saint in a niche, a half-open wooden double door glowing eerie green inside, candle clusters either side, the broken bell tower with its bronze bell and iron cross on the right, a short wrought-iron fence and a ruined arch stub. A short plank pier with two posts runs out of the door to the lower left. There is no Door Keeper in the sprite: use the existing `door_keeper` NPC. |
| `abbey_door_glow.png`, `_2x/` | Additive green glow in the open door and on the wet threshold, on the same canvas. Fade it in on hover. |

- **Footprint: 3x3 cells, all blocking.** Measured on the painting: the foundation's side tips are at x 140 and x 1009, so the base diamond is about 870 px wide; one cell is 290 px and the footprint's south tip is at (575, 917). `_mock/town_door_mock.png` shows the result.
- **Anchor:** the Crosshaven kit rule. The image's bottom-centre sits on the south tip of cell origin+(2,2), which is `(0, +80)` px from the NW cell's centre at 1x.
- **Depth sort:** sort by the south cell, as `crosshaven_prop.gd` does.
- **Door cell: origin+(1,3)**, as for Saltmaw. The door opens on the SW (+y) face and the pier ends at the SW edge of cell (1,2). The door cell is passable and lies just outside the footprint, at the pier end. With the systems layout (chapel on `crosshaven_southbridge` (23..25, 23..25)) that is (24,26), and the Door Keeper stands on origin+(0,3) = (23,26).
- **Overhang:** the foundation is a little deeper on its front-right than a square 3x3, so its front corner overhangs the SE edge by about 7 px at 1x; the pier posts overhang the SW edge by a few px. Both are part of the sprite.
- **Scale:** next to a `fishing_hut_2x2` it reads as a ruined landmark a little taller than a cottage. See `_mock/town_door_mock.png`, and `_mock/town_door_hover_mock.png` for the hover glow.

## 2. Combat-board kit: `board/`

The board uses the same `board_view.gd` math as the Granary: `cell_to_local(x,y) = ((x-y)*32, (x+y)*16)`, the diamond centre.

**Floor tiles** (`tiles/`, 64x32, with 128x64 `_2x/` masters):
- Room A (the flooded nave): `nave_floor_a/b/c`, worn grey-green abbey flagstones under a film of murky water, with moss, duckweed and warm candle reflections.
- Room B (the Mire Abbess's sanctum): `sanctum_floor_a/b/c`, dark slate-green flagstones under still green water with teal-green caustics.
- Same rules as the Granary: centred on the cell, cut on the painted grout line, a 0.5 px bleed on the diagonals. Pick the variant with `h(x,y,3)`.

**Candle-rune pads:**
- `candle_pad` is the glowing green candle-rune pad (a glowing rune frame around a three-candle sigil). It replaces the floor tile on a pad cell, in both rooms.
- `candle_pad_glow` (96x56, additive) adds the light spill. Draw it at `cell_to_local - (48, 32)`. Pulsing it is optional.

**Obstacle props** (`props/`):
- Each prop's image bottom-centre sits on the south tip of its south-most cell.
- Props y-sort with the units. All of them are 1x1 blockers except `fallen_bell` (2x2).
- `candle_cluster`, `altar` and `candle_stand` carry their own additive `_glow` (the candle flames) on the same canvas; draw it on top of the prop.

PROP_TABLE

**Floor decals:**
- `rune_circle` (320x160) is the big glowing green rune circle of room B. **It is 5x5**, as the room layout asks. I measured it on the approved boss-room design: the ring with its outer spikes is about 4.2 tile widths across, which as a top-down circle is about 6 cells, so a 5x5 decal is a little smaller than the design but clearly not a 3x3 (Saltmaw's whirlpool came out 5x5 the same way). It fills the full 5x5 footprint diamond, with its bottom-centre on the south tip of origin+(4,4); the outer ring and the glyph band run through the 16 border cells and the cross sits on the centre cell.
  - It is walkable and goes on the ground layer, after the tiles.
  - `rune_circle_glow` is its additive green light; pulse it slowly.
  - The inner 3x3 are the room's pads in the systems layout: draw the plain sanctum floor there (not `candle_pad`; the circle is the pad art) and add `candle_pad_glow` on those 9 cells.
- `lily_pads` (64x32) is a walkable 1-cell ground decal (no glow): a few floating lily pads and a water lily. Scatter it on wet cells in either room. It is not a blocker.

**Backdrops** (`backdrops/`, 1x only):
- `room_a_nave_{15x15,12x12}`: the flooded nave walls, dark mossy stone with square pillars, glowing green-yellow stained-glass windows, hooded saint statues in niches, candle clusters on the ledges, gnarled roots growing down the walls and small arched openings.
- `room_b_sanctum_{15x15,12x12}`: the sanctum, the great glowing green rose window in the back corner over the altar with its green-sun cloth and candles, two hooded saint statues, tattered green-sun banners, roots over the walls, tall candle stands, and big arched doorways in the side walls.
- They are made with the Granary method: the painted room shell with a flat **magenta** floor diamond, fitted affinely onto the board diamond, with the diamond cut out.
- The floor outside the board is painted with the room's tiles, darkened.
- Draw the backdrop behind the tiles so that pixel `cell00_centre_px` lands on `cell_to_local(0,0)`.
- The dark surround is alpha 0; clear to near-black. Fit the camera to the backdrop's bounds to show the back walls.

**Mock:** `_mock/rooms_mock.png` (`room_a_mock.png`, `room_b_mock.png`) shows both rooms assembled at game camera scale (1 board px = 1 screen px), with the monsters at pawn scale 0.5. The painted hero idle frames stand in for the heroes. `_mock/rooms_mock_star5.png` is the same with the ★5 forms.

MONSTERS_SECTION

## Pipeline (`build_tools/dungeons/`)

The Abbey adds only its piece lists and numbers; all the cutting is the shared kit. The Granary, Frostspire and Saltmaw outputs are unchanged: `check_granary_repro.py` and `check_frostspire_repro.py` rebuild those kits into a scratch folder and check that they are byte-identical to the committed files.

| script | does |
|---|---|
| `build_abbey_town.py`, `build_abbey_board.py`, `build_abbey_fx.py` | The door, the board kit, and the bile spit, bile impact, rite glow, ★5 gravebound bile and ★5 grasping mire. |
| `abbey_monsters.py` (+ `mrig.py`, `monster_kit.py`) | Monster rigs and actions; `python3 abbey_monsters.py <id>` builds one. |
| `build_abbey_manifest.py` | Writes `manifest.json`. It fails if any PNG is not listed. |
| `mock_rooms.py drowned_abbey [--star5]`, `mock_town.py drowned_abbey`, `mock_turnarounds.py --dungeon drowned_abbey`, `mock_monsters.py --dungeon drowned_abbey --clip a.mp4 --clip5 b.mp4` | The review mocks, contact sheets and clips. |

Shared-kit changes (none of which changes the older outputs):
- `gkit.DUNGEONS` gains `drowned_abbey` → `abbey_src`;
- `mock_rooms` skips a decal glow that does not exist (`lily_pads` has none), and gains the Abbey room layouts and ★5 swap list; `mock_town` and `mock_turnarounds` gain the Abbey entries.

**Sources:** `abbey_src/` holds the chosen paintings (`_star5_gate_gravebound_abbess.jpg` is the comparison sent to Mauro, not a source).

KNOWN_ISSUES

SOURCES
