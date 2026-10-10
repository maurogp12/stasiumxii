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

| id | size (1x) | footprint | room | glow |
|---|---|---|---|---|
| `pew` | 62x65 | 1x1 | A |  |
| `broken_pillar` | 56x67 | 1x1 | A+B |  |
| `fallen_statue` | 62x52 | 1x1 | A |  |
| `candle_cluster` | 50x62 | 1x1 | A+B | `candle_cluster_glow` |
| `coffin` | 60x49 | 1x1 | A+B |  |
| `gravestone` | 46x68 | 1x1 | A |  |
| `gnarled_roots` | 58x63 | 1x1 | A+B |  |
| `altar` | 62x63 | 1x1 | B | `altar_glow` |
| `candle_stand` | 40x83 | 1x1 | B | `candle_stand_glow` |
| `floating_coffin` | 60x48 | 1x1 | B |  |
| `saint_statue` | 36x93 | 1x1 | B |  |
| `fallen_bell` | 124x131 | 2x2 | B |  |

- `fallen_bell` is **2x2**: its bottom-centre sits on the south tip of origin+(1,1) and all four cells block. In the room tags, name it on its south cell (as the Granary's `bone_throne`).
- `floating_coffin` is painted cut off at the waterline with a ring of ripples and lily pads; it still blocks. `saint_statue` and `candle_stand` are the tall props.

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

## 3. Monsters: `monsters/<id>/<action>/<action>_<S|E>_fNN.png`

| id | cell | pivot | actions (frames) |
|---|---|---|---|
| `bog_dead` | 512x360 | (256,329) | idle 12, walk 12, attack 12, hit 8, death 13 |
| `mire_leech` | 512x360 | (256,329) | idle 12, walk 12, attack 12 (**release f07**), hit 8, death 13 |
| `mire_abbess` | **768x540** | **(384,494)** | idle 12, walk 12, attack 12, hit 8, death 13, **summon 14** "Rite of Rising" (+ `summon_*_glow`) |

**Format** (as the Granary, Frostspire and Saltmaw):
- 17.144 fps. Idle and walk loop; the other actions play once, and death holds its last frame.
- S is the front facing screen down-right; E is the back facing screen up-right. The other two facings are game-side `flip_h` mirrors.
- Each monster's `meta.json` repeats the cell, pivot, fps, frame counts and QA numbers.
- Melee attacks (the Bog Dead's rake, the Abbess's Censer Lash) connect on **attack f06**.
- The boss is placed like the Ratking: her (384,494) lands where a hero's (256,329) lands. For a centred Sprite2D that is the hero offset minus (0,75) before scale.

**Bog Dead (room A melee shambler):**
- A drowned monk in a rotten hooded robe dripping bog weed and moss, a rope belt with a wooden cross, a grey-green skull face with glowing yellow-green eyes, long bony claws.
- **Walk:** a dragging shamble, a lurch to each side with the head lolling behind and the arms swinging loose. **Attack:** a double claw rake: both arms rise high (f02–f04), he lunges and rakes down on **f06**.
- **Rising:** when the Abbess's Rite of Rising raises a fallen Bog Dead, play its death strip in reverse (f12 → f00) on the corpse cell, then idle. No extra art.

**Mire Leech (room A ranged), for Mauro's ranged-room-A rule:**
- A giant slimy bog worm: segmented olive-green and brown hide with rows of glowing yellow-green pustules, draped in bog weed and roots, a round lamprey maw ringed with fangs. Its tail coils on the ground and the body rears up in an S.
- **A worm reads fine as ranged:** it rears back with its throat swelling, then snaps forward and spits; at pawn scale the maw is the brightest thing on it, so the shot reads.
- **Walk:** a slither, the coil pulses (stretch and squash twice per loop) and the neck sways.
- **Attack:** it rears back, trembling, its throat swelling (f01–f06), then snaps the head forward and spits on **f07, the release frame**, follows through and settles.
- **Projectile spawn:** `meta.json > release.point_px` gives the maw at release per facing, in cell pixels (S (334.1,208.1), E (380.5,181.0)). Mirror its x for the mirrored facings.
- **Projectiles** (`board/projectiles/`, centred):
  - `bile_spit` (44x23, + `_glow`): a glob of yellow-green acid bile pointing along +x with a dripping tail. Rotate it to the flight direction and fly it on a lobbed arc, no spin.
  - `bile_impact` (54x52): an acid splash with droplets and a little fizzing steam. Play it as a scale-up and fade of about 0.3 s at the hit point.
- **Death:** it rears and shudders, then the neck and head flop over onto the coil.

**The Mire Abbess (boss):**
- A tall drowned abbess in long tattered black and cream robes draped in bog weed and rosaries, a porcelain death mask under a dark veil, a halo crown of rusted iron crosses, a bronze censer on chains trailing green smoke, three lit candles floating around her.
- **Idle and walk:** she floats, bobbing slowly; the censer swings like a pendulum and the three candles bob out of phase.
- **Attack, "Censer Lash" (range 1–2):** she draws the censer back (f02–f04) and whips it out on its chains at the target on **f06**.
- **Death:** she topples; the floating candles go out of the air and drop to the floor.

**Mire Abbess signature, `summon` "Rite of Rising"** (the systems agent's proposal; the strip name stays `summon`). She raises a fallen Bog Dead on its death cell:
- f00–f02 she lowers the censer; f03–f06 she swings it up over her head while the floating candles rise and flare.
- On **f07** the green smoke bursts and the rite fires. `meta.json > rite_point.point_px` is the censer on f07 per facing (S (542.6,66.9), E (535.0,45.5) in the 768x540 cell).
- f07–f09 she holds the censer high; f10–f13 she settles back to idle.
- `summon/summon_{S,E}_fNN_glow.png` is the additive green rite glow (censer smoke and candle flames) for this action only. It builds f03–f06, bursts on f07, holds to f09 and fades by f12. Draw it like a ★5 glow.
- `board/projectiles/rite_glow` (+ `_glow`, 100x44) is the green ritual smoke streak along +x, bright end at +x. On f07 stretch it from `rite_point` to the corpse cell (bright end on the corpse) and fade it out over f07–f10, with an add blend. Then play the Bog Dead's death strip reversed on that cell.
- It plays differently from Saltmaw's pull (a single lure flare toward the hero) and the Ratking's summon (a crook slam with new rats around him): the Abbess swings the censer overhead and the effect travels away from her to a corpse.
- The key frames are in `meta.json > signature` (`lower [0,2]`, `swing [3,6]`, `burst 7`, `hold [7,9]`, `settle [10,13]`).

**Turnarounds and contact sheets:** `_mock/<id>_turnaround.png` shows the S and E paintings each rig is cut from. `_mock/<id>_contact.png` shows every frame of every action. `_mock/monsters_clip.mp4` plays every action in all four facings.

## 4. Star 5: The Gravebound Abbess (`star5/`), **rigs pending Mauro's approval**

At ★5 the boss is **The Gravebound Abbess**, the Mire Abbess risen from a sealed grave. The S painting `asset_8hH8iMsYz6gSqnT9eSZcLKPU` was sent to Mauro for approval (side-by-side `build_tools/dungeons/abbey_src/_star5_gate_gravebound_abbess.jpg`, runners-up `asset_PytbLYLvgz4SKK6mDZo8UCvN`, `asset_jQtJww3BxXk8sTPVwsDYGEYd`). **Until he answers, the ★5 monster rigs are not built** and the manifest lists them as `"status": "pending"` with their planned cells and frame counts. Her look:
- grave-black and ash-grey robes bound in rusted bog-iron grave chains and padlocks;
- glowing pale-jade soulfire in her cracked mask and eyes, the black-iron cross halo and the grave runes on the chains and hem;
- a black-iron skull censer pouring pale-jade ghost smoke, ghost-flame candles, and drowned skeletal hands clutching the hem.

| id | cell | pivot | actions |
|---|---|---|---|
| `star5/monsters/gravebound_abbess` | 768x540 | (384,494) | as `mire_abbess`, summon 14 (same rig, timing, signature frames and rite_point) |
| `star5/monsters/gravebound_bog_dead` | 512x360 | (256,329) | as `bog_dead` (chained grave-black robe, jade soulfire face, runes) |
| `star5/monsters/gravebound_mire_leech` | 512x360 | (256,329) | as `mire_leech`, release f07 (chained grave-black hide, jade pustules and maw) |

- The S and E paintings for all three are already in `abbey_src/` (`gravebound_*`). They are edits of the base paintings with mask overlap 0.94–0.98, so they reuse the base rigs: `python3 abbey_monsters.py gravebound_abbess gravebound_bog_dead gravebound_mire_leech`, then rebuild the manifest and run `mock_rooms.py drowned_abbey --star5`, `mock_turnarounds.py --dungeon drowned_abbey` and `mock_monsters.py --dungeon drowned_abbey --clip5 ...`.
- **Glow maps:** every ★5 frame will get a same-size additive `<frame>_glow.png` (the pale-jade paint bloomed, `jade_glow`). Draw it on top of the frame with the same offset, scale and flip, using an add blend.

**Other ★5 pieces (built):**
- `star5/board/grasping_mire.png` is the ★5 hazard "Grasping Mire": a 1-cell, 64x32 pool of black bog water with drowned skeletal hands and roots reaching up, with a 128x64 `_2x/` master and `grasping_mire_glow.png` (96x56, additive). It is centred on the cell, on the ground layer. Only the visual is here; the rule is CombatSim's.
- `star5/board/projectiles/gravebound_bile.png` (+ `_glow`) is the pale-jade soul bile of the Gravebound Mire Leech.

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

## Known issues / what I'd change

- **No painted lying-down keys** (same as the other three dungeons): every death is the standing painting rotated about 80° and lifted in the cell (the leech's neck and head flop over onto its coil instead). Painting a lying key per monster and facing would read better.
- **Weapon swings are rigid rotations:** the Bog Dead's claws and the Abbess's censer arm swing as one painted piece each. The censer itself rotates as a rigid piece about the hand, so its chains stay straight instead of swinging loose.
- **Bog Dead:** the robe's long hanging weed is cut with the arms and legs, so on the deepest wind-up and lunge frames a strand or two of weed separates from the body (a small loose clump near the left foot on attack f03–f05). The back-fill behind the arms repeats nearby robe texture.
- **Mire Leech:**
  - The rig is three pieces (coil, neck, head); the coil itself does not bend, it only pulses (stretch and squash) during the walk, so the slither is a sway rather than a true wave.
  - A few drool drips hanging under the maw are cut with the head and float free of it on the flop-over death frames.
  - `release.point_px` is the maw centre at release; the bile leaves from slightly inside the maw rim.
- **The Mire Abbess:**
  - Her translucent green censer smoke keyed out pinkish grey over the magenta key (the soft smoke's alpha is over-estimated), so the rig recolours the bright pinkish pixels of the censer and candle layers onto a green ramp (`smoke_fix`). The smoke is flatter than painted smoke.
  - The overhead swing of the Rite of Rising is lower than first planned (the censer reaches about head height, not straight up) so she stays inside the 768x540 cell without a keep-in shift. `rite_point` is therefore at the top right of the cell (S (542.6,66.9), E (535.0,45.5)).
  - The three floating candles are separate parts that bob out of phase; in the death they drop below her and come to rest on the floor beside the body, not in a painted puddle of wax.
  - The robe hem is part of the body cut, so the glide is a bob and sway of the whole figure; the hem does not trail.
- **Rune circle:** 5x5 as the systems layout asks. Measured on the design, the ring is a little bigger (a top-down circle of about 6 cells). It is a round painting on a 5x5 diamond, so its corners are empty floor, and the glyphs do not animate (pulse `rune_circle_glow`).
- **Backdrops are 1x only**, as for the other dungeons. Fit residuals: room A 17.6 px (15x15) / 14.0 px (12x12), room B 21.6 / 17.3 px. Room B was repainted (the first shell had the altar steps cutting into the floor, a 64 px residual).
- **Town door:** the footprint (3x3, cell 290 px in the painting) was measured by eye from the foundation diamond; the foundation's front-right corner overhangs the SE edge by a few px. The door painting is an edit with the pier shortened so the pier ends on the door cell (1,3); the original long pier ran two cells past the footprint.
- **Floors:** the 3-variant floors show the tile grid, because each flagstone is painted with dark grout on all four edges (by design, as for the other kits).
- **Glows:** the candle-flame glows (`candle_cluster`, `altar`, `candle_stand`) are masks on the near-white flame cores, so they are small spots at 1x; the prop paintings themselves are already bright. `lily_pads` has no glow.
- **rite_glow** was painted as a grey-green smoke streak next to the magenta key and recoloured onto a green ramp by luminance, so it is flatter than a painted streak (as Saltmaw's `lure_line`).
- **Hero stand-ins in the mocks** are the painted idle strips scaled 0.9 by eye, not the game's pawn scale.

## Scenario source assets (project "stasium")

Each piece was painted with the approved Abbey images as references (door `asset_3bnqDTvUKjdMRFh1EFhQhwoJ`, room `asset_tSezcNcX2vqpHMhgJhENAfnD`, boss room `asset_2vYkm5hjXTc9UXnwSL2yaNoq`, monsters `asset_vwinBLmpLNkAZJDrc337NBeZ`), using the Granary prompt patterns. E facings and ★5 forms are edits of the chosen S (or base) painting.

| piece | asset (chosen) | local copy in `build_tools/dungeons/abbey_src/` |
|---|---|---|
| ruined chapel entrance | `asset_FHsUnXgZD7EkdBiC4Bdmmy3U` (edit of `asset_nKYFNm3ZmzReir4Ai6fZoyeF`, pier shortened) | `town_abbey.jpg` |
| nave floor a/b/c | `asset_PHibyXE6RzMTxe6iK9x4Nuro`, `asset_uogNBkn5MQsY9qQZxhDG8Vbz`, `asset_6pZ5AA5vet6G9JThSZ9XPxn1` | `floor_a_{1,2,3}.jpg` |
| sanctum floor a/b/c | `asset_JpCfYjgg2xKz6fLvZAVkchME`, `asset_LhiEwUQd7kAocz4PeS62ZSAF`, `asset_reZDgdEAKiPc8x17ijKjnnJe` | `floor_b_{1,2,3}.jpg` |
| candle pad | `asset_q36DianDfaNQc581ogZLPzgK` | `candle_pad.jpg` |
| pew, broken pillar, fallen statue, candle cluster, coffin, gravestone, gnarled roots | `asset_pFrhiXpUk45DmTs5h4gDReDi`, `asset_rKR7fCRRvD8RwJ6CANk4iiFG`, `asset_Xek1DXYXTnYzmctLZ6WisyJr`, `asset_3D5tAiFDanz4Ph5J74F9qqho`, `asset_YG3BDodNb6oSt7nXfS9kr7dU`, `asset_vUDgUNSfSUU2F6RxbKkmyoC1`, `asset_n21v88vA6UGSpAkRP2mibxDv` | `pew.jpg`, `broken_pillar.jpg`, `fallen_statue.jpg`, `candle_cluster.jpg`, `coffin.jpg`, `gravestone.jpg`, `gnarled_roots.jpg` |
| altar, candle stand, floating coffin, saint statue, fallen bell | `asset_UX9bSosmViLZsDFW4mzZByZL`, `asset_CoLrkfZAVS2w9BGYK43utmYV`, `asset_1TB7FAyH8jMXZmSP8Qt4h33d`, `asset_Uw1ewzyjqKE4pKXhG2b76WoY`, `asset_UMvYktL3bJbY1JjHdxxpuY8N` | `altar.jpg`, `candle_stand.jpg`, `floating_coffin.jpg`, `saint_statue.jpg`, `fallen_bell.jpg` |
| rune circle, lily pads | `asset_bMzxoKKsj2rUxNSvHDTM1Gdt`, `asset_4ft76zZAtBwDZijcRAyr2HMC` | `rune_circle.jpg`, `lily_pads.jpg` |
| room A shell, room B shell | `asset_PA2Ct3JGGm6hssLuWSofqGJS`, `asset_jeeZ86zuaKRj8yTQM9Ti32c1` (repaint of `asset_kgDpaWKYpW6a8HzqRWxvdfVx` with a clean floor rhombus) | `shell_room_a.jpg`, `shell_room_b.jpg` |
| Bog Dead S / E | `asset_doHurwgYn3x7sKYb5CuRbSUm` / `asset_hqYge75yANsQSAQYSfa24mGA` | `bog_dead_S.jpg` / `bog_dead_E.jpg` |
| Mire Leech S / E | `asset_FpQ7gFsgRoCE8ZbFCpVTSqsF` / `asset_m7w2RScNML4mhHWZuqpfZ9td` | `leech_S.jpg` / `leech_E.jpg` |
| The Mire Abbess S / E | `asset_KvRzQM4mLtexm3jNP5k3UTJb` / `asset_eKz2ypc1g8EX8uiAWBciP7nr` | `abbess_S.jpg` / `abbess_E.jpg` |
| bile spit, bile impact, gravebound bile, rite glow | `asset_zojQduVhqsVoLMtPADDytnM3` | `bile_projectiles.jpg` |
| ★5 Gravebound Abbess S / E | `asset_8hH8iMsYz6gSqnT9eSZcLKPU` (runners-up `asset_PytbLYLvgz4SKK6mDZo8UCvN`, `asset_jQtJww3BxXk8sTPVwsDYGEYd`) / `asset_itmsxYtkSWnbdF6foFe3mMm2` | `gravebound_abbess_S.jpg` / `gravebound_abbess_E.jpg` |
| ★5 Gravebound Bog Dead S / E | `asset_TygYHrEHHYcLCxRPFJnCksxy` / `asset_N5hyKC81t9j6sneFbeba3tES` | `gravebound_bog_dead_S.jpg` / `gravebound_bog_dead_E.jpg` |
| ★5 Gravebound Mire Leech S / E | `asset_dy6KXeGz89YmuQmNUYf6y27n` / `asset_MJMVgX5LnQCbZ3PfKGCHQhsA` | `gravebound_leech_S.jpg` / `gravebound_leech_E.jpg` |
| ★5 grasping mire | `asset_97Jtwjq738d4AHt466633ykf` | `grasping_mire.jpg` |
