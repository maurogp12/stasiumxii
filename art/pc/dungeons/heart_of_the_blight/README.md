# Heart of the Blight: game art (Westwatch dungeon, levels 40–50, the blighted dark side, danger zone)

Game-ready art for the fifth and last PC dungeon, repainted piece by piece from the approved look targets in `docs/pc/look_target/dungeons/heart_of_the_blight/` (branch `claude/pc-zones-spec`). It is built exactly like the Granary, the Frostspire Archive, the Saltmaw Grotto and the Drowned Abbey, with the same shared scripts. **`manifest.json` lists every file with its kind, size, pivot or anchor, footprint or cell, frame counts and fps.** Load from the manifest; this README only explains it. The manifest uses the same format and keys as the other four (`stasium.dungeon_art` v1).

Every PNG has binary alpha (0/255) with RGB 0 under alpha 0. Files named `*_glow` are additive light maps: draw them with an add blend. `_2x/` files are 2x masters: draw them at scale 0.5 in the same place as the 1x file. `_mock/` is review material only (it has a `.gdignore`).

**Key colour.** Every keyed piece was painted on flat **green** (#00FF00). The blight is violet and magenta, the opposite hue to green, so violet keys cleanly on it, while the Abbey's magenta key would eat exactly the colour that matters here. The olive moss on the monsters keys cleanly too (checked on every cut). The Abbey's lesson (translucent haze keying out pinkish) was handled at the source and per piece: the paintings were asked for crisp edges and no glow haze (the glows are made afterwards as `_glow` maps), and the two effects that still have soft violet haze (`spore_impact`, `crystal_shard_impact`) put every grey keyed pixel back on a violet ramp (`violet_fix` in `build_blight_fx.py`); the crystal bloom burst clamps any left-over green spill.

## 1. Town door: `town/`

| file | what |
|---|---|
| `blight_door.png` (260x200), `_2x/` (518x400) | The Heart of the Blight entrance on the blighted side of Westwatch: a huge hollow dead tree stump with a tangle of twisted roots, bark veined with glowing violet cracks, red thorn vines and horned skulls on stakes, and a cave mouth at its foot glowing deep violet. On its left a sharpened Westwatch palisade with a lantern post (violet lantern) and a dark banner with the white sun-wheel; broken stakes on the right. A trodden dirt path runs out of the cave to the south. There is no Door Keeper in the sprite: use the existing `door_keeper` NPC. |
| `blight_door_glow.png`, `_2x/` | Additive violet glow in the cave mouth and the lantern, on the same canvas. Fade it in on hover. |

- **Footprint: 4x4 cells, all blocking.** Measured on the painting: the blighted earth patch's side tips are at x 9 and x 1014, so the base is ~1005 px wide and one cell is 251 px. The painted earth is rounder and deeper than a 2:1 diamond (the path runs down to y ~955), so the footprint's south tip is put at (511, 860), near the path's end: the sprite is cut flat at the south tip (the kit rule), and there the cut only crosses the narrow path.
- **Anchor:** the Crosshaven kit rule. The image's bottom-centre sits on the south tip of cell origin+(3,3), which is `(0, +112)` px from the NW cell's centre at 1x.
- **Door cell: origin+(3,4).** The path runs out of the cave straight south, over the SW edge of the corner cell (3,3). On `crosshaven_westwatch` the building is on (2..5, 9..12) (origin (2,9)), the door cell is (5,13) and the Door Keeper stands at (6,13) = origin+(4,4) (agreed with the systems agent).
- **Overhang:** the earth's rounded front corners and the stakes on the right overhang the footprint's south edges by a few px at 1x; its back reaches a little past the back edges. Both are part of the sprite.
- **Mocks:** `_mock/town_door_mock.png` (drawn in Westwatch coordinates, centred on (5,11), with a `watchtower_2x2` for scale) and `_mock/town_door_hover_mock.png` (glow on).

## 2. Combat-board kit: `board/`

The board uses the same `board_view.gd` math as the other dungeons: `cell_to_local(x,y) = ((x-y)*32, (x+y)*16)`, the diamond centre.

**Floor tiles** (`tiles/`, 64x32, with 128x64 `_2x/` masters):
- Room A (the blighted crypt): `crypt_floor_a/b/c`, dark purple-brown crypt flagstones with hairline cracks, thin roots and violet crystal grit.
- Room B (the Rotting Elder's heart chamber): `heart_floor_a/b/c`, old mauve-brown slabs with thick dark roots veined in violet and crystal dust, graded darker so the circle and the units read.
- Same rules as the Granary: centred on the cell, cut on the painted grout line, a 0.5 px bleed on the diagonals. Pick the variant with `h(x,y,3)`.

**Violet pulse pads:**
- `blight_pad` is the glowing violet sigil pad (a glowing square frame around a three-leaf sprout sigil). It replaces the floor tile on a pad cell, in both rooms.
- `blight_pad_glow` (96x56, additive) adds the light spill. Draw it at `cell_to_local - (48, 32)`. Pulse its modulate.

**Obstacle props** (`props/`):
- Each prop's image bottom-centre sits on the south tip of its south-most cell. Props y-sort with the units. All are 1x1 blockers except `root_mound` (2x2).
- The props marked glow carry their own additive `_glow` (the violet crystal faces, caps and veins) on the same canvas; draw it on top of the prop.

| id | size (1x) | footprint | room | glow |
|---|---|---|---|---|
| `violet_crystals` | 54x55 | 1x1 | A+B | `violet_crystals_glow` |
| `crystal_spire` | 40x65 | 1x1 | B | `crystal_spire_glow` |
| `root_knot` | 58x49 | 1x1 | A+B |  |
| `bone_pile` | 60x37 | 1x1 | A+B |  |
| `broken_masonry` | 56x57 | 1x1 | B |  |
| `fungus_clump` | 54x50 | 1x1 | A | `fungus_clump_glow` |
| `chained_cocoon` | 42x74 | 1x1 | B | `chained_cocoon_glow` |
| `blight_eggs` | 58x46 | 1x1 | B | `blight_eggs_glow` |
| `root_mound` | 124x97 | 2x2 | A |  |

- `root_mound` is **2x2**: its bottom-centre sits on the south tip of origin+(1,1) and all four cells block. In the room tags, name it on its south cell.
- `crystal_spire` and `chained_cocoon` are the tall props.

**Root Wall (the Rotting Elder's signature), `props/root_wall.png` + `props/root_wall/`:** a 1x1 **summoned blocker** (58x95 at 1x), in `board.props` with three strips under the keys the systems code reads:
- `rise`: 6 frames, the roots burst up out of the floor (squashed and clipped at the ground line on f00–f03, overshoot on f03–f04);
- `idle`: 1 still frame (pulse its `_glow`);
- `wither`: 6 frames, the roots darken and sink back into the floor.
Every frame has a same-canvas `_glow`. All strip frames share one canvas; its bottom-centre is the cell's south tip + (0,-3) at 1x.

**Floor decals:**
- `root_rune_circle` (320x160) is the big violet root-rune circle of room B. **It is 5x5.** Measured on the approved boss-room design: the ring is ~230 px across against floor tiles ~60 px wide, ~3.8 tile widths, which as a top-down circle is ~5.4 cells. The painting was cropped to the ring so it fills the 5x5 diamond (the ring is ~4.8 cells across), with its bottom-centre on the south tip of origin+(4,4); the rings and glyph band run through the 16 border cells and the starburst sits on the centre cell.
  - It is walkable and goes on the ground layer, after the tiles.
  - `root_rune_circle_glow` is its additive violet light; pulse it slowly.
  - The inner 3x3 are the room's pads in the systems layout: draw the plain heart floor there (not `blight_pad`) and add `blight_pad_glow` on those 9 cells.
- `root_veins` (64x32) is a walkable 1-cell ground decal (no glow): thin roots with violet cracks and crystal grit. Scatter it on any cell.

**Effects** (`projectiles/`, centred):
- `spore_bolt` (+ `_glow`): the Blight Horror's violet spore glob along +x with a spore tail. Rotate it to the flight direction, fly it on a shallow arc, no spin.
- `spore_impact`: a burst of violet spores and fibres; scale-up and fade over ~0.3 s at the hit point.
- `root_crack` (+ `_glow`): a violet glowing crack along +x. On the Root Wall's fire frame draw one from the staff foot (`staff_point`) to each new wall cell, on the ground layer, fading out over f07–f12.

**Backdrops** (`backdrops/`, 1x only):
- `room_a_crypt_{15x15,12x12}`: crumbling dark brick walls overgrown with thick roots veined in violet light, small dark arches, violet crystals and glowing mushrooms at the wall bases, bones and skulls; a low dark stone lip on the front edges.
- `room_b_heart_{15x15,12x12}`: sandstone-brown brick walls with pillars, hanging lanterns, wall torches and red banners, big arched doorways in the side walls, and **the pulsing heart of the blight in the back corner**: a giant glowing violet crystal heart wrapped in roots, with eggs and bones at its foot.
- Made with the Granary method: the painted room shell with a flat **green** floor diamond, fitted affinely onto the board diamond, with the diamond cut out. The floor outside the board is painted with the room's tiles, darkened.
- Draw the backdrop behind the tiles so that pixel `cell00_centre_px` lands on `cell_to_local(0,0)`. The dark surround is alpha 0; clear to near-black.
- Violet on green: the shells' violet light sits on the walls, never on the floor key, so the floor cut is clean.

**Mock:** `_mock/rooms_mock.png` (`room_a_mock.png`, `room_b_mock.png`) shows both rooms assembled at game camera scale (1 board px = 1 screen px), with the monsters at pawn scale 0.5 and two root walls in room B. The painted hero idle frames stand in for the heroes. `_mock/rooms_mock_star5.png` is the same with the ★5 forms, crystal walls and crystal blooms.

## 3. Monsters: `monsters/<id>/<action>/<action>_<S|E>_fNN.png`

| id | cell | pivot | actions (frames) |
|---|---|---|---|
| `blight_hound` | 512x360 | (256,329) | idle 12, walk 12, attack 12, hit 8, death 13 |
| `blight_horror` | 512x360 | (256,329) | idle 12, walk 12, attack 12 (**release f07**), hit 8, death 13 |
| `rotting_elder` | **768x540** | **(384,494)** | idle 12, walk 12, attack 12, hit 8, death 13, **summon 14** "Root Wall" (+ `summon_*_glow`) |

**Format** (as the other dungeons):
- 17.144 fps. Idle and walk loop; the other actions play once, and death holds its last frame.
- S is the front facing screen down-right; E is the back facing screen up-right. The other two facings are game-side `flip_h` mirrors.
- Each monster's `meta.json` repeats the cell, pivot, fps, frame counts and QA numbers.
- Melee attacks (the Hound's bite, the Elder's Root Claw) connect on **attack f06**.
- The boss is placed like the Ratking: his (384,494) lands where a hero's (256,329) lands. For a centred Sprite2D that is the hero offset minus (0,75) before scale. **He fits the cell:** the Elder is very large on the design, but at 1.5x the hero height he is ~450 px tall and ~415 px wide inside the 768x540 cell, with room for the staff and the swings (no frame leaves the cell, no keep-in shift).

**Blight Hound (room A fast melee):** a low, wide blighted wolf of bark plates, matted moss and thorn ridges, shelf fungi on its back, violet cracks and eyes.
- **Walk:** a fast loping trot, diagonal leg pairs together, the spine bouncing twice a loop, the tail streaming.
- **Attack:** crouch and gather (f02–f04), then a pounce-bite that lands on **f06**.
- **Death:** a yelp, then the legs give way and it slumps flat (a squash, so it stays a low body on the floor).

**Blight Horror (room A ranged), for Mauro's ranged-room-A rule:** the gaunt root figure with spores: twig crown, glowing violet hollow face, a root ribcage around a violet crystal core, mushrooms and spore pods on its shoulders, long wooden claws.
- **Attack "Spore Bolt":** it rears back with its arms spreading and its face swelling, trembling (f01–f06), then snaps forward and spits a spore bolt from its face on **f07, the release frame**, follows through and settles.
- **Projectile spawn:** `meta.json > release.point_px` gives the face at release per facing, in cell pixels (S (293.5,111.5), E (307.9,86.1)). Mirror its x for the mirrored facings. Projectiles: `board/projectiles/spore_bolt`, `spore_impact`.

**The Rotting Elder (boss):** a huge hunched treant of rotting bark and grey-olive moss, a crown of antler-branches, a dark hollow face with violet eyes, violet crystals on the shoulders, the crystal heart in his split chest, skulls on cords, a massive root-claw arm and a tall crystal-topped staff.
- **Idle / walk:** a slow breathing sway; the walk is a ponderous lumber, the root legs dragging forward in turn and the trunk rolling side to side, the staff kept upright.
- **Attack "Root Claw" (range 1):** the root-claw arm draws up and back (f02–f04) and rakes down and across, connecting on **f06**.
- **Death:** he topples sideways (~58°), the staff still in his fist.

**Rotting Elder signature, `summon` "Root Wall"** (the systems agent's proposal; the strip name stays `summon`). He raises root walls that reshape the board:
- f00–f02 he lifts the staff, the crystal heart dims;
- f03–f06 the staff is held high, the heart flares violet and the roots writhe at his feet;
- **f07 he drives the staff into the floor: the wall fires.** `meta.json > staff_point.point_px` is the staff foot on f07 per facing (S (531.7,532.1), E (538.6,534.0) in the 768x540 cell). Spawn `root_wall` (play `rise`) on each wall cell and draw a `root_crack` from there to each wall cell;
- f08–f10 a shockwave ripples through him; f11–f13 he settles.
- `summon/summon_{S,E}_fNN_glow.png` is the additive violet heart glow for this action only: it dims f00–f02, flares f03–f06, bursts on f07, ripples f08–f10 and fades by f13.
- It plays differently from the Ratking's summon (a crook slam with new rats around him), Saltmaw's pull (a lure flare toward the hero) and the Abbess's raise (a censer swung overhead at a corpse): here nothing is summoned or pulled; the staff is driven *down*, cracks run out across the floor and the board itself changes as walls burst up.

**Turnarounds and contact sheets:** `_mock/<id>_turnaround.png` shows the S and E paintings each rig is cut from. `_mock/<id>_contact.png` shows every frame of every action. `_mock/monsters_clip.mp4` plays every action in all four facings.

## 4. Star 5: The Crystal Colossus (`star5/`)

At ★5 the boss is **The Crystal Colossus**, the Rotting Elder consumed by the blight crystal. Following the Abbey lesson, Mauro was sent one comparison sheet from the start (`build_tools/dungeons/blight_src/_star5_options.jpg`): the base on the left, then three new silhouettes and one recolour, each keyed on dark inside the 768x540 cell:
- A **Corazón Desatado** `asset_VbKYgFRh1NB94vvGWsMbqpfW`: the trunk split open, the heart floating free, a body of root tentacles;
- **B Coloso de Cristal `asset_EAJjWPHCM1WtmsNskPvFoWHh` (picked, "B", 11 Oct 2026)**: a hulking crystal giant;
- C **Anciano Araña** `asset_JLt37HfkZcdn53enijxkzcAJ`: the Elder's torso on eight root legs;
- D **Anciano Carmesí** `asset_8dsJvTvKTbNvuY9e5FZR8vpJ`: the strong recolour (black bark, crimson crystals).

His look: most of his body is angular faceted glowing violet crystal growing through and replacing the bark, with dark bark and moss left at the joints, a jagged crown of crystal antlers, the crystal heart blazing in a crystal chest, skulls on cords, one arm ending in a huge crystal fist and the other holding a long crystal-tipped spear-staff (the Elder's staff fused into a spear). The Crystal Hound and Crystal Horror follow the theme: sharp violet crystal spikes for thorns, crystal plates and claws, brighter violet cracks.

| id | cell | pivot | actions |
|---|---|---|---|
| `star5/monsters/crystal_colossus` | 768x540 | (384,494) | idle 12, walk 12, attack 12, hit 8, death 13, summon 14 "Root Wall" (**his own rig**) |
| `star5/monsters/crystal_hound` | 512x360 | (256,329) | as `blight_hound` (edit of the base painting, base rig) |
| `star5/monsters/crystal_horror` | 512x360 | (256,329) | as `blight_horror`, release f07 (edit of the base painting, base rig) |

**The Crystal Colossus's rig** (a new silhouette, so a new part cut: body, crown, the spear arm, the spear-staff on its fist, the crystal-fist arm, two legs):
- Same cell and pivot as `rotting_elder`; the pivot is between his feet.
- **Idle:** a slow heavy breath. **Walk:** a heavy stomp, each crystal leg lifting and slamming, the trunk lurching over the planted leg.
- **Attack "Crystal Lance" (range 1–2):** he draws the spear-staff back and up (f02–f04), then thrusts the crystal blade forward and down with a lunge, connecting on **f06**.
- **Death:** he topples (~54°), the spear-staff falling from his grip.
- **Summon "Root Wall":** the base timing (lift f00–f02, charge f03–f06, **fire f07**, shockwave f08–f10, settle f11–f13). He drives the spear-staff's foot into the floor. `meta.json > staff_point.point_px` is the spear foot on f07 per facing (S (225.9,515.1), E (233.0,485.0)). His wall is `star5/board/props/crystal_wall` (same strips as `root_wall`, in `star5.board.props`).
- **Glow maps:** every frame has an additive `<frame>_glow.png` (the violet crystal faces bloomed, kept low because much of him is crystal, plus a faint aura). There is no separate signature ramp; the f07 fire is sold by the cracks and the walls.

**Other ★5 pieces:**
- `star5/board/projectiles/crystal_shard` (+ `_glow`) and `crystal_shard_impact` (+ `_glow`): the Crystal Horror's bolt (fly it straight) and its burst of fragments.
- `star5/board/props/crystal_wall` (+ `_glow`, + `crystal_wall/{rise,idle,wither}` strips): the Colossus's Root Wall, tall violet crystal spikes out of heaved floor stones.
- `star5/board/crystal_bloom.png` (64x32, + `_2x/`, + `crystal_bloom_glow.png` 96x56 additive) and `star5/board/crystal_bloom/swell_f00..07` (+ `_glow`): the ★5 hazard decal, a crystal pod in a nest of crystal-crusted roots, with an 8-frame swell loop (it breathes and its light pulses). Centred on the cell, ground layer; the rule is CombatSim's.
- `star5/board/crystal_bloom_burst/burst_f00..07` (192x96 = the 3x3 diamond around the pod, + `_glow`, + `_2x/`): the pod bursting over its cell and its 8 neighbours; it grows out of the pod f00–f03 (full on f03, the damage frame) and shatters apart f04–f07. Draw it over the units, centred on the pod cell.

**Review images:** `_mock/crystal_colossus_turnaround.png` (base S next to the Colossus S and E), `_mock/star5_<id>_contact.png` (glow baked in, on dark), `_mock/rooms_mock_star5.png`, `_mock/monsters_clip_star5.mp4`.

## Pipeline (`build_tools/dungeons/`)

The Blight adds only its piece lists and numbers; all the cutting is the shared kit. The Granary, Frostspire, Saltmaw and Abbey outputs are unchanged: `check_granary_repro.py` and `check_frostspire_repro.py` rebuild those kits in full (monsters included) into a scratch folder and check that they are byte-identical to the committed files; `check_saltmaw_repro.py` and `check_abbey_repro.py` (new, sharing `check_kit_repro.py`) do the same for Saltmaw's and the Abbey's town, board, fx and manifest (their committed monster frames are copied in, not re-rendered).

| script | does |
|---|---|
| `build_blight_town.py`, `build_blight_board.py`, `build_blight_fx.py` | The door, the board kit, and the spore bolt/impact, root crack, root and crystal wall strips, crystal shard/impact, crystal bloom and its burst. |
| `blight_monsters.py` (+ `mrig.py`, `monster_kit.py`) | Monster rigs and actions; `python3 blight_monsters.py <id>` builds one. |
| `build_blight_manifest.py` | Writes `manifest.json`. It fails if any PNG is not listed. |
| `mock_rooms.py heart_of_the_blight [--star5]`, `mock_town.py heart_of_the_blight`, `mock_turnarounds.py --dungeon heart_of_the_blight`, `mock_monsters.py --dungeon heart_of_the_blight --clip a.mp4 --clip5 b.mp4` | The review mocks, contact sheets and clips. |

Shared-kit changes (none of which changes the older outputs; the four repro checks pass):
- `gkit.DUNGEONS` gains `heart_of_the_blight` → `blight_src`;
- `build_abbey_board.ground_cell_decal` takes an optional `key` (default the Abbey's magenta), so the Blight's `root_veins` reuses it with the green key;
- `mock_town` reads the footprint size from the manifest and takes an optional origin, centre and canvas per dungeon; `mock_rooms` gains the Blight layouts, swaps props too in the ★5 mock (`root_wall` → `crystal_wall`), draws ★5 decals listed per room, and centres a decal glow of a different size; `mock_turnarounds` gains the Blight entries.

**Sources:** `blight_src/` holds the chosen paintings. `_star5_options.jpg` is the comparison sent to Mauro, and `formA..D_*_S.jpg` are the four ★5 options (B is the picked form; `colossus_S.jpg` is the same painting). `heart_bloom.jpg` and `bloom_burst.jpg` are the first, fleshy-pod versions of the ★5 hazard made before Mauro's pick; they were replaced by the crystal versions and are kept for the record only. `rune_circle_raw.jpg` is the uncropped circle painting.

## Known issues / what I'd change

- **No painted lying-down keys** (same as the other four dungeons): the Horror's and the Elder's deaths are the standing painting rotated (about 80° and 58°) and lifted in the cell; the Hound's and the Colossus's deaths are a squash-and-sink collapse in place instead (the Hound stays a low body; the Colossus only tilts ~21°, because rotating his very wide spear-and-fist silhouette further leaves the 768x540 cell). Painting a lying key per monster and facing would read better.
- **Limb swings are rigid rotations:** the Hound's legs, the Horror's long arms, the Elder's claw arm and staff and the Colossus's spear and fist each swing as one painted piece. The Horror's and the Hound's hanging moss is cut with the limbs, so on the widest frames a strand or two of moss separates a little from the body; the back-fill behind the limbs repeats nearby bark and moss texture.
- **Blight Hound:** the walk is a trot of four rigid legs about the hip/shoulder (no bending knees); the tail is one piece. The S and E paintings show the far legs only partly, so the far legs are small cuts.
- **Blight Horror:** `release.point_px` is the glowing face at release; the spore leaves from the face, not from a mouth (it has none).
- **The Rotting Elder:**
  - The staff is counter-rotated against his arm so it stays upright; it is still a rigid piece, and on f07 it is pushed straight down 10 px "into" the floor (the staff foot sits ~38 px below the pivot line, so `staff_point` is at the floor, slightly in front of his feet).
  - The Root Wall lift raises the staff to the top of the cell: the summon needed a small keep-in shift (25 px S, 19 px E) over f04–f08, so the whole figure dips a little while the staff is high.
  - The heart flare is the additive `summon_*_glow` on the painted heart and crystals; the painted heart itself does not change.
  - The roots "writhing at his feet" are a small out-of-phase sway of the two root legs, not new roots.
- **Root Wall / crystal wall strips** are made from one painting each: the rise is the painting squashed up out of the floor line, the wither the same painting sinking and darkening. They read as growth at board scale but are not a painted growth sequence.
- **root_crack** is one painted crack stretched to length; long cracks (5+ cells) look stretched.
- **The heart in room B's backdrop** is painted into the shell, not a separate layer: "pulsing" needs a game-side violet glow sprite over it (the manifest says so).
- **Backdrops are 1x only**, as for the other dungeons. Fit residuals: room A 5.9 px (15x15) / 4.7 px (12x12), room B 24.2 / 19.3 px (the heart chamber's painted floor is not an exact parallelogram; the darkened floor apron hides it).
- **Floors:** room B's slabs have roots that cross the tile edges, so the roots break at the grout lines; each slab also shows its grout on all four edges (by design, as for the other kits). Room B's floor was graded darker than painted.
- **Town door:** the footprint (4x4, cell 251 px in the painting) was measured by eye on the earth patch, which is rounder than a 2:1 diamond; the sprite is cut flat at the south tip, so the very end of the trodden path is clipped by a few px. The door cell, origin+(3,4), was chosen where the path leaves the footprint.
- **★5 Crystal Colossus:** a fresh rig on a new silhouette. In the E painting the spear is still on the screen-left (as in S), so the E facing is a back view whose weapon side matches S rather than a true turnaround of the hands. His constant glow is kept low (much of him is crystal); raise its modulate if he reads too dull. There is no separate signature glow ramp.
- **★5 Crystal Hound and Horror:** edits of the base paintings (outline match 0.89–0.90), so they reuse the base cuts; a few crystal spikes outside the base outline ride on the body piece.
- **★5 effects:** `crystal_bloom_burst` is one top-down painting scaled up from the pod and broken apart with a dither (f04–f07), not a painted sequence; its glow is strong at f01–f03. The first, fleshy ★5 hazard (`heart_bloom` / `bloom_burst`) was replaced after Mauro's pick and is not in the kit.
- **Turnarounds** use the raw key; contact sheets of the ★5 forms have the glow baked in for review only.
- **Hero stand-ins in the mocks** are the painted idle strips scaled 0.9 by eye, not the game's pawn scale.

## Scenario source assets (project "stasium")

Each piece was painted with the approved Blight images as references (door `asset_ytHpKyCFtkbWLjYTTTFnvNp7`, room `asset_wvnYdeFQRkAeZp5inWRAKBbM`, boss room `asset_FGV7azjoJmUgPmYuYkRg5b9i`, monsters `asset_mqo1jKKPekD2Dh5EaL1sLKBd`), using the Granary prompt patterns. E facings and ★5 forms are edits of the chosen S (or base) painting.

| piece | asset (chosen) | local copy in `build_tools/dungeons/blight_src/` |
|---|---|---|
| hollow stump entrance | `asset_xT2NTzzD6pfLumMd12YcYsd5` | `town_blight.jpg` |
| crypt floor a/b/c | `asset_WcKSEaNLXhe5av4iUw7a2WhC`, `asset_F3MLWmSkFsSQviuKjBZdnuwa`, `asset_umzGebrcPNonbcwF3oTzkM7H` | `floor_a_{1,2,3}.jpg` |
| heart floor a/b/c | `asset_KXGtw1uuGHhg2WLUpgXPmma4`, `asset_xtbByfHDbDCvAM5ZgWW7AbkL`, `asset_yKaU6tsHQaTYA3sTSwes2R4E` | `floor_b_{1,2,3}.jpg` |
| violet sigil pad | `asset_aS1WYbbL8Bm4968baQaG6Tev` | `blight_pad.jpg` |
| violet crystals, crystal spire, root knot, root mound, bone pile | `asset_gB6cg2joc5hbxcH3D4degZKR`, `asset_u8Pkn8zSZurE18HjeXFUmx1i`, `asset_Y3F4XvJjmFpkzpCB13WVyEWM`, `asset_AMb8V68CNFYjkaDgWrLWzJWT`, `asset_uWSMnXSdDRJhf1ZvMxNiREeY` | `violet_crystals.jpg`, `crystal_spire.jpg`, `root_knot.jpg`, `root_mound.jpg`, `bone_pile.jpg` |
| broken masonry, fungus clump, chained cocoon, blight eggs | `asset_cVhFUMdPNox2sBJXRa4j7bhZ`, `asset_AbYPRASuXBFAc6tkzUrZnhMo`, `asset_L6nc6b2hw59ezAGJukvFytqs` (repaint standing on the floor), `asset_uyr1Gm1JesLUMsCctkeCTotA` | `broken_masonry.jpg`, `fungus_clump.jpg`, `chained_cocoon.jpg`, `blight_eggs.jpg` |
| root wall | `asset_sg873YiWL1h3NeT2SjHy9zm1` | `root_wall.jpg` |
| root-rune circle, root veins | `asset_ABBYqTYURHHxebL9PmiDdE3d`, `asset_edZS8C8kLNp6PK7AJTvXM9Az` | `rune_circle.jpg` (cropped from `rune_circle_raw.jpg`), `root_veins.jpg` |
| room A shell, room B shell | `asset_fpSVrHAVDGJSFiafEmWYpZGH`, `asset_wgh3gjxbcj6jrxaZBrzG2tqU` (repaint of `asset_yHtRXcHp2LhkQZaAoseSBKLH` with the whole heart in frame and a cleaner floor) | `shell_room_a.jpg`, `shell_room_b.jpg` |
| Blight Hound S / E | `asset_WsgY5UNN5gVkYktDrGqRZJFi` / `asset_d2pVYoNp4YovWYm89nBmqd2r` | `hound_S.jpg` / `hound_E.jpg` |
| Blight Horror S / E | `asset_KRkceHWn96JtgQDCFLdqGD3K` / `asset_EQXBnczfJwMF9oet5tyR9LmZ` | `horror_S.jpg` / `horror_E.jpg` |
| The Rotting Elder S / E | `asset_Df27AQFHvYPk7UsciFKbL9iF` / `asset_gsqCXjbsmBkZtjYeqHG8U5r4` | `elder_S.jpg` / `elder_E.jpg` |
| spore bolt, spore impact, root crack | `asset_6WbA1vQjwEocHg6BTPfeM2tu` | `spore_projectiles.jpg` |
| ★5 Crystal Colossus S / E | `asset_EAJjWPHCM1WtmsNskPvFoWHh` (picked by Mauro) / `asset_LrwJJP83NW2r5LvLj9KSt5Yx` | `colossus_S.jpg` / `colossus_E.jpg` |
| ★5 Crystal Hound S / E | `asset_koBZVLxcy6zp3xK5RfCvC3YC` / `asset_jZLriYA8UKtxheB7a2WHehX6` | `crystal_hound_S.jpg` / `crystal_hound_E.jpg` |
| ★5 Crystal Horror S / E | `asset_enXbY3i4UH2pKbwynuzQjssi` / `asset_8NSFiqz6nzv1bnPeqE3ozTiC` | `crystal_horror_S.jpg` / `crystal_horror_E.jpg` |
| ★5 crystal shard, shard impact, crystal wall | `asset_Q5kbpuuR7HjgiajSsoeW92b9` | `crystal_projectiles.jpg` |
| ★5 crystal bloom, bloom burst | `asset_GVd3bGvVJdQCzju6e7LKTmZD`, `asset_GcBstfp5z9ad76UeUfaaJuKx` | `crystal_bloom.jpg`, `crystal_bloom_burst.jpg` |
| ★5 options A–D | as listed in section 4 | `formA_heart_unbound_S.jpg`, `formB_crystal_colossus_S.jpg`, `formC_root_spider_S.jpg`, `formD_heartrot_S.jpg` |
| first ★5 hazard (replaced) | `asset_AYUnvSx8VHxC88xTTVQfSm5R`, `asset_9NaZR24z5mrouYowMk9bwsDB` | `heart_bloom.jpg`, `bloom_burst.jpg` |
