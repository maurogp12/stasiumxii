# Old Granary Cellar: game art (Stoneford dungeon, levels 1–10)

Game-ready art for the first PC dungeon, repainted piece by piece from the approved look targets in `docs/pc/look_target/dungeons/old_granary_cellar/` (branch `claude/pc-zones-spec`). **`manifest.json` lists every file with its kind, size, pivot or anchor, footprint or cell, frame counts and fps.** Load from the manifest; this README only explains it.

Every PNG has binary alpha (0/255) with RGB 0 under alpha 0. Files named `*_glow` are additive light maps: draw them with an add blend. `_2x/` files are 2x masters: draw them at scale 0.5 in the same place as the 1x file. `_mock/` is review material only (it has a `.gdignore`).

Build scripts: `build_tools/dungeons/` (see the end of this file).

## 1. Town door: `town/`

| file | what |
|---|---|
| `granary_door.png` (238x229), `_2x/` (478x459) | The granary with the open cellar hatch, stairs into the glow, rat sign and lantern. There is no Door Keeper in the sprite: use the existing `door_keeper` NPC. |
| `granary_door_hatch_glow.png`, `_2x/` | Additive warm glow over the stair pit and hatch, on the same canvas. Fade it in on hover. |

- **Footprint:** 3x3 cells, all blocking. The front row (y = 2) holds the hatch and the stair pit.
- **Anchor:** this follows the Crosshaven kit rule. The image's bottom-centre sits on the south tip of cell origin+(2,2), which is `(0, +80)` px from the NW cell's centre at 1x.
- **Depth sort:** sort by the south cell, as `crosshaven_prop.gd` does.
- **Door cell:** origin+(1,3). It is passable and lies just outside the footprint, in front of the stairs, which face SW (+y). Put the Door Keeper on a neighbouring cell, for example origin+(0,3) or origin+(3,3).
- **Scale:** next to a `cottage_thatch` 2x2 it reads about as large as in the design. See `_mock/town_door_mock.png`, and `_mock/town_door_hover_mock.png` for the hover glow.

## 2. Combat-board kit: `board/`

The board uses the `board_view.gd` math: `cell_to_local(x,y) = ((x-y)*32, (x+y)*16)`, the diamond centre.

**Floor tiles** (`tiles/`, 64x32, with 128x64 `_2x/` masters):
- `cellar_floor_a/b/c` (room A) and `lair_floor_a/b/c` (room B).
- Draw each tile centred on the cell centre, like the Koliseo full-bleed tiles.
- Each slab was cut on its painted grout line, so neighbouring tiles share one grout line and the floor tiles seamlessly. There is a 0.5 px bleed on the diagonal edges.
- Pick the variant with the kit hash `h(x,y,3)`.

**Wheat pads:**
- `wheat_pad` is the glowing amber wheat pad. It replaces the floor tile on a pad cell.
- `wheat_pad_glow` (96x56, additive) adds the light spill. Draw it at `cell_to_local - (48, 32)`. Pulsing it is optional.

**Obstacle props** (`props/`):
- Each prop's image bottom-centre sits on the south tip of its south-most cell (`tile.gd _paint_prop`).
- Props y-sort with the units.

| id | size (1x) | footprint |
|---|---|---|
| `crate_stack` | 66x82 | 1x1 |
| `grain_sacks` | 72x59 | 1x1 |
| `barrel_cluster` | 60x58 | 1x1 |
| `broken_crate` | 68x64 | 1x1 |
| `bone_throne` | 152x156 | 2x2 (room B, against the back wall) |

**Floor decal:**
- `drain_grate` (192x96) is the full 3x3 footprint diamond, with its bottom-centre on the south tip of origin+(2,2).
- It is walkable and goes on the ground layer, after the tiles.
- `drain_grate_glow` is the additive amber light from below.

**Backdrops** (`backdrops/`, 1x only):
- One per room, for a 15x15 board (the Koliseo ship size) and a 12x12 board.
- Each is the painted room shell, with dark stone and timber walls, lanterns or torches, farm tools and the lit front lip. The painted floor is fitted affinely onto the board diamond, and the diamond is cut out.
- Draw it behind the tiles so that pixel `cell00_centre_px` lands on `cell_to_local(0,0)`.
- The floor outside the board is painted with the same tiles, darkened, up to the walls.
- The dark surround is alpha 0, so clear the screen to near-black.
- The back walls rise above the board's top tip, so fit the camera to the backdrop's bounds if they should be visible.

**Mock:** `_mock/rooms_mock.png` shows room A and room B assembled at game camera scale (1 board px = 1 screen px), with the heroes and monsters at pawn scale 0.5.

## 3. Monsters: `monsters/<id>/<action>/<action>_<S|E>_fNN.png`

| id | cell | pivot | actions (frames) |
|---|---|---|---|
| `granary_rat` | 512x360 | (256,329) | idle 12, walk 12, attack 12, hit 8, death 13 |
| `sling_rat` | 512x360 | (256,329) | idle 12, walk 12, attack 12 (**release f07**), hit 8, death 13 |
| `scarecrow_drudge` | 512x360 | (256,329) | idle 12, walk 12, attack 12, hit 8, death 13 |
| `the_ratking` | **768x540** | **(384,494)** | idle 12, walk 12, attack 12, hit 8, death 13, **summon 14** |

**Format:**
- 17.144 fps. Idle and walk loop; the other actions play once, and death holds its last frame.
- S is the front facing screen down-right; E is the back facing screen up-right. The other two facings are game-side `flip_h` mirrors, as for the heroes.
- Each monster's `meta.json` repeats the cell, pivot, fps, frame counts and QA numbers.

**Sizes:**
- The rat and the scarecrow use the hero cell exactly. The scarecrow is hero height (about 255 px in the cell).
- The rat is a low quadruped, about 135 px tall and 200 px long.
- The Ratking is 1.5x the hero height (about 385 px) in a 1.5x cell. Place it like a hero cell, but so that its (384,494) lands where a hero's (256,329) lands. For a centred Sprite2D that is the hero offset minus (0,75) before scale.

**Ratking signature, `summon`:**
- He raises the crook high, holds it trembling and squeals, head thrown back (f03–f09), then slams it down (f10).
- Spawn the summoned rats around f09.
- The rats tied to his crook lift with it.

**Turnarounds:**
- `_mock/<id>_turnaround.png` shows the S and E paintings each rig is cut from.
- `_mock/<id>_contact.png` shows every frame of every action.

**Sling Rat (ranged, room A):**
- A Granary Rat on its hind legs, with a sack-scrap hood, a rope belt with a pouch of stones, and a leather sling. It is about 200 px tall in the cell.
- **Attack:** the arm raises (f01–f02), whirls the sling overhead (f03–f06), and whips forward on **f07, the release frame**. f08–f11 follow through and recover.
- **Projectile spawn:** `meta.json > release.point_px` gives the sling-pocket position at release, per facing, in cell pixels. Mirror its x for the mirrored facings.
- **Projectiles** (`board/projectiles/`, centred):
  - `sling_pebble`: 16x14 at 1x.
  - `sling_seed`: a grain-hard seed, an alternative ammo.
  - `sling_impact_puff`: a dust and husk burst. Play it as a scale-up and fade of about 0.25 s at the hit point.

## 4. Star 5: Radioactive Ratking (`star5/`)

At ★5 the boss is the **Radioactive Ratking**, the same Ratking mutated (mobile's equivalent is `boss_art_5`). His look:
- burned, patchy fur;
- toxic green glowing cracks, eyes and dripping sludge;
- a crown fused with green crystal shards;
- a crook topped by a cracked glowing canister;
- mutated rats with glowing eyes at his feet.

| id | cell | pivot | actions |
|---|---|---|---|
| `star5/monsters/radioactive_ratking` | 768x540 | (384,494) | idle 12, walk 12, attack 12, hit 8, death 13, summon 14 (same rig and timing as `the_ratking`) |
| `star5/monsters/radioactive_rat` | 512x360 | (256,329) | as `granary_rat`; his ★5 summons |
| `star5/monsters/radioactive_sling_rat` | 512x360 | (256,329) | as `sling_rat`, release f07 |

**Glow maps:**
- Every ★5 frame has a same-size additive light map, `<frame>_glow.png`. It is the green emissive paint bloomed, plus a faint green aura.
- Draw it on top of the frame with the same offset, scale and flip, using an add blend.

**Other ★5 pieces:**
- `star5/board/toxic_pool.png` is a 1-cell, 64x32 glowing green puddle decal, with a 128x64 `_2x/` master. It is centred on the cell, on the ground layer. `toxic_pool_glow.png` (96x56, additive) goes with it.
- The Radioactive Ratking leaves these pools as his ★5 special. Only the visual is here; the effect is up to CombatSim.
- `star5/board/projectiles/sling_pebble_radioactive.png` is the radioactive sling stone, with a `_glow`.

**Review images:**
- `_mock/radioactive_ratking_turnaround.png` shows the base Ratking S next to the radioactive S and E paintings.
- `_mock/star5_<id>_contact.png` shows every frame with the glow baked in, on dark.

## Pipeline (`build_tools/dungeons/`)

| script | does |
|---|---|
| `gkit.py` | Chroma key on green or magenta (magenta for the green-glowing ★5 pieces); alpha from the key-colour excess, colour un-mixed from the green, despill), binary-alpha cut, iso diamond projection. |
| `build_granary_town.py` | Builds the town door and the hatch glow. |
| `build_granary_board.py` | Builds the tiles, pad, props, decal, glows and backdrops. |
| `build_granary_star5.py` | Builds the toxic pool decal and the sling projectiles, including the radioactive pebble. |
| `mock_turnarounds.py` | Writes the keyed turnaround review images. |
| `granary_monsters.py` + `mrig.py` | Monster rigs and actions. |
| `build_granary_manifest.py` | Writes `manifest.json`. It checks that every PNG is listed. |
| `mock_granary_rooms.py`, `mock_monsters.py` | Room mock, contact sheets, and the review clip (`--clip out.mp4`). |

**Sources:** `granary_src/` holds the chosen paintings. Each was painted one piece per image on flat green, with the approved Granary images as references, then cut out here.

**How the monster rig works.** It is the painted-part idea of the hero action rigs, rebuilt in 2D with no blockout:
1. Parts (head, limbs, tail, crook, feet) are cut from the painting with polygons and pivot on painted joints.
2. What a part covered on the body is back-filled with the painting's own texture, using shifted patches. Holes enclosed by the body are filled too.
3. Each frame is posed by FK, rendered at 3x on the cell and area-downsampled, then cut to binary alpha with see-through specks filled.
4. Every frame is checked to lie inside the cell. When a pose would leave the cell (the deaths only), a smoothed lift eases it back in instead of popping.

## Known issues / what I'd change

- **No painted lying-down keys.**
  - The rat dies by rearing and rolling onto its back (rotated 180°).
  - The Scarecrow collapses into a heap.
  - The Ratking topples onto his side, rotated about 84°.
  - All three are the standing paintings rotated, so the Ratking's lying pose shows the flat cut where his feet were separated.
  - Painting a lying key per monster and facing would read better, the same issue the heroes have.
- **Death lift:**
  - The deaths lift by up to about 67 px (Ratking) so the lying body stays inside the cell. This is a smoothed lift, not a pop.
  - The lying bodies sit on the cell's bottom rows, below the pivot, as the hero deaths do.
- **Swings rotate rigid paintings.**
  - The Scarecrow's sickle swing and the Ratking's crook swing are rigid painted pieces rotated about the shoulder. The sickle is never reflected, so in the wind-up it points backward.
  - In the summon pose, the Ratking's raised hand floats a little above the cloak, because the forearm is under the cloak in the painting.
- **Back-fill repeats texture.** Back-filled texture is a repeat of nearby painting. It shows as a repeated wheat ear behind the rat's hind leg and in the Ratking's cloak when the claw lifts.
- **The Ratking's hands differ between facings.** He holds the crook in his left hand in S and in his right hand in E. Both turnarounds were painted that way, and the mirrors keep it consistent per facing pair.
- **Backdrops are 1x only.**
  - The source paintings are about 1024 px previews, so a 2x master would only be an upscale.
  - The room-B fit has a 15 px residual at the corners, because its painted floor is not an exact parallelogram. The extended floor apron hides it.
- **The grain props are brighter than the design.** The props are slightly graded down (×0.9, saturation 0.9) toward the darker cellar of the design. In-game lighting or tint should finish the match.
- **Scale assumptions:**
  - The building's 3x3 footprint and the cell scale were measured from the painting.
  - The rat's size (about half the Scarecrow's height) was chosen from the design sheet.

- **Sling whirl:** the whirl is a rigid painted arm and sling rotated overhead, not a painted spin. At release in S the arm crosses the chest.
- **★5 repaints:** the radioactive paintings are edits of the base turnarounds. They line up closely (mask IoU 0.92–0.95), so they reuse the same part cuts. Drips that hang outside a part's cut polygon stay on the body.
- **Radiation symbol:** the radioactive E canister shows a faint radiation symbol.

## Scenario source assets (project "stasium")

Each piece was painted with the approved Granary images as references (door `asset_gTxkfwikMr8Qi8b1CD69pd7P`, room `asset_dW98bSycfweqRnGojHuhqLvB`, boss room `asset_a7VYPepfZNsQjqap7cqRMwmU`, monsters `asset_GuoHFBAwqFM9FLKJW4bMrtuJ`, world style `asset_TQPWy66Pbfv9iRpz7w8NYud3`).

| piece | asset (chosen) | local copy in `build_tools/dungeons/granary_src/` |
|---|---|---|
| granary building | `asset_4h25qmdm4g4uEVGh7PPiSd88` | `town_granary.jpg` |
| cellar floor a/b/c | `asset_sUFu1N32VWgu5MDtJqmSH8vs`, `asset_HdhTguGebmnacS2DacDYqQCH`, `asset_GLj8HsBe6vpUyoHGPMjbP8Ya` | `floor_a_{1,2,3}.jpg` |
| lair floor a/b/c | `asset_BcF8qjW4yKhNCj4ysnnePvFN`, `asset_bvBz5PNhr6w897Uw5a6TnjXy`, `asset_tbcpLfPzKNNRNo2yTBazT4aV` | `floor_b_{1,2,3}.jpg` |
| wheat pad | `asset_REiUMnwySoyvok6VnGutas8P` | `wheat_pad.jpg` |
| crate stack, grain sacks, barrel cluster, broken crate | `asset_5asd5ZiHMtENNUTr9DYrXVM7`, `asset_nxbgvxUJ48Kat5ndcsyEMTHq`, `asset_YELyUBgqu7hQedopsEgh55KC`, `asset_C1MAna7H3VgcXK5Vn8xMnfpd` | `crate_stack.jpg`, `grain_sacks.jpg`, `barrel_cluster.jpg`, `broken_crate.jpg` |
| bone-and-sack throne | `asset_7rvTXtFatz9pDrAF2P57GrTL` | `bone_throne.jpg` |
| drain grate | `asset_EEm3GoivSNS4CPVBwKkzPvQr` | `drain_grate.jpg` |
| room A shell, room B shell | `asset_ggb5PLyHE4KJZUSW6wtwxbTB`, `asset_JRaURD6USb94Tgp5nXnCveWB` | `shell_room_a.jpg`, `shell_room_b.jpg` |
| Granary Rat S / E | `asset_6pEzMgdW8XgSBWzYMJWE3AiR` / `asset_Hq2GJbiB75bnk88ViCtNpKS5` | `rat_S.jpg` / `rat_E.jpg` |
| Scarecrow Drudge S / E | `asset_mKuJMfJfgGeAmKNT98w2DSBi` / `asset_KyiJGWXKYQuzwDDFSoqdERcm` | `scarecrow_S.jpg` / `scarecrow_E.jpg` |
| The Ratking S / E | `asset_oEpUuyitHmqWSnGNEGjRtX2Z` / `asset_d5yHN83CLZr2fQct9RUPnJZV` | `ratking_S.jpg` / `ratking_E.jpg` |
| Sling Rat S / E | `asset_Ar46LNqAs2hqkMeKJrqHZkbg` / `asset_bNxffG16p6sxw2KwS7KnzdfF` | `sling_rat_S.jpg` / `sling_rat_E.jpg` |
| sling pebble, seed, impact puff, radioactive pebble | `asset_iu6Y2BAYAnpJ9qnMP8Hkcx7Q` | `sling_projectiles.jpg` |
| ★5 Radioactive Ratking S / E | `asset_7DjoKDiCFRBh2QoGBZbqEUhv` / `asset_oHX2AJkHCEbGFRxv41oZWwWw` | `rad_ratking_S.jpg` / `rad_ratking_E.jpg` |
| ★5 Radioactive Rat S / E | `asset_7L2VkhWwdjAuQn2oKY9TNsBd` / `asset_bdDpAS3icrnP4rKyGAVJ91dT` | `rad_rat_S.jpg` / `rad_rat_E.jpg` |
| ★5 Radioactive Sling Rat S / E | `asset_DutqFtXyPykNfn52atgomA3p` / `asset_Hv5WmHwTjcJKCAq39aCPai6S` | `rad_sling_rat_S.jpg` / `rad_sling_rat_E.jpg` |
| ★5 toxic pool | `asset_6gQfwAdkAprXo8b1rwgM1U6L` | `toxic_pool.jpg` |
