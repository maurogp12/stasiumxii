# Walk / attack strips (export_2x)

## Wakfu walk drop

Replace these files in place. Same names. 864×160 RGBA, six frames of 144×160. No `*_gen.png`. No second folder. The `*_frames.tres` walk clips are AtlasTexture slices of these PNGs (cells at x = 0, 144, 288, 432, 576, 720). A new sheet of that size shows up on the next import. Attack, cast, hit, and death sheets stay put.

- `art/export_2x/characters/kestrel/anims/kestrel_walk_{e,s,n,w}.png` — approved Wakfu Kestrel
- `art/export_2x/characters/ironjaw/anims/ironjaw_walk_{e,s,n,w}.png` — Ironjaw A2 art-fill. Same 864×160, six 144×160 cells. East is the wakfu-ship-v6g strip: full plate, grill, and dual axes, plant foot about y=149. East frame 0 fills about 0.82 of the cell. West is the per-cell horizontal mirror of that east sheet, same frame order. North and south are that same east sheet, held until a matching three-quarter strip ships. Identity stays Berserker A + helm A2: iron-jaw grill, dual double-bit axes, dark cape. East, north, and south bytes match `art/export_2x/walk_src/ironjaw_walk_e.pngbin`. West bytes match `art/export_2x/walk_src/ironjaw_walk_w.pngbin`. The v6b blob and the rejected v6c and v6f east strips are not the live east sheet. The v5 north and south strips are not wired.
- `art/export_2x/characters/gloam/anims/gloam_walk_{e,s,n,w}.png` — Gloam proposal B, not the white-eyes sheet: amber/yellow glowing eyes, wide chilling grin, dual curved silver daggers with gold hilts, purple cloak with gold trim
- `art/export_2x/characters/mender/anims/mender_walk_{e,s,n,w}.png` — Mender proposal D2: cream/gold hooded robe, green lantern staff, face clearly visible (more open hood). 864×160.
- `art/export_2x/characters/bastion/anims/bastion_walk_{e,s,n,w}.png` — Bastion proposal 2C: charcoal-grey/gold armor, spiked mace, oversized tower shield. 864×160. East is the wakfu-ship-v6d strip (brighter charcoal, gold punch, transparent background). West is the per-cell horizontal mirror of that east sheet, same frame order. North and south are that same east sheet, held until a matching three-quarter strip ships. East, north, and south bytes match `art/export_2x/walk_src/bastion_walk_e.pngbin`. West bytes match `art/export_2x/walk_src/bastion_walk_w.pngbin`. The v5 north and south strips are not wired.

Kestrel, Gloam, and Mender walks stay the wakfu-ship-v5 strips. Bastion east is wakfu-ship-v6d. Ironjaw east is wakfu-ship-v6g. For those two classes, west is the baked mirror of that east sheet, and north and south are the east sheet itself until Scenario ships matching facings. Every walk PNG is 864×160, six 144×160 cells, foot-anchored around y=148–151. Replacing a sheet in place does not regenerate identity. Locked SoTs stay Gloam B, Mender D2, Bastion 2C, Ironjaw A+A2, and Kestrel F+A. East is the punch sheet. West is the mirror of east, baked per cell in the same frame order. There is no runtime `flip_h`. Kestrel, Gloam, and Mender north and south are the front and rear three-quarter strips. Device playback reads the same bytes from `art/export_2x/walk_src/*.pngbin`. Mender and Bastion still have no attack, cast, or death sheet. Their hit flinch is the scenario strip below.

Godot on `mobile` plays these the moment the files exist. Until then the pawn keeps today's hop and the static `art/characters/<class>/<class>_<n|e|s|w>.png` facing.

Walk sheets in this folder are wakfu-ship-v5, except Bastion and Ironjaw. Bastion east is wakfu-ship-v6d and Ironjaw east is wakfu-ship-v6g. For those two, west is the baked mirror of east, and north and south are the east sheet. Attack and the other action sheets stay the prior drops. Animation names stay `walk_<e|s|n|w>` and `attack_<e|s|n|w>`.

Loader: `units/strip_library.gd`. Missing paths use `ResourceLoader.exists` and return null. They do not error.

## Prefer these paths

Per-facing PNG (this is the drop Godot stubs now):

`art/export_2x/characters/<class>/anims/<class>_<anim>_<n|e|s|w>.png`

SpriteFrames bank (authored slices; this is what playback uses when the file exists):

`art/export_2x/characters/<class>/<class>_frames.tres`

Animation names inside the `.tres`: `walk_e`, `walk_s`, `walk_n`, `walk_w`, `attack_e`, `attack_s`, `attack_n`, `attack_w`. Walk loops at 12 fps. Attack is one-shot. Impact frame index is **3** (0-based) for both kits.

Walk clips in the `.tres` are slices of the walk PNGs above, so replacing that PNG is the walk update. A per-facing PNG still fills a letter the `.tres` left empty. Playback bakes those cells off `CompressedTexture2D` so Android does not keep a runtime `AtlasTexture` slice.

`<class>` is `kestrel`, `ironjaw`, `gloam`, `mender`, or `bastion`. Every class ships a walk and a hit flinch. Mender and Bastion have no attack, cast, or death sheet.

`<anim>` is `walk` or `attack` for the v3 files, plus Batch-1c `cast_mark`, `cast`, `hit`, and `death`. Gloam ships the full set. `*_gen.png` is ignored.

## Facing (locked)

Sheet direction maps onto the pawn letter. No `flip_h`. Mirrors are already in the files.

| Drawn | File suffix | Pawn facing |
|---|---|---|
| SE | `_e` | E |
| SW | `_s` | S |
| NE | `_n` | N |
| NW | `_w` | W |

The pawn tries `walk_e` (and `attack_e`) before a drawn-master name like `walk_se`.

## Batch-1 files

- `art/export_2x/characters/kestrel/anims/kestrel_walk_{e,s,n,w}.png`
- `art/export_2x/characters/kestrel/anims/kestrel_attack_{e,s,n,w}.png`
- `art/export_2x/characters/ironjaw/anims/ironjaw_walk_{e,s,n,w}.png`
- `art/export_2x/characters/ironjaw/anims/ironjaw_attack_{e,s,n,w}.png`

Batch-1c (same cell, pivot, and letter rule):

- `art/export_2x/characters/kestrel/anims/kestrel_cast_mark_{e,s,n,w}.png` — 6 frames, 12 fps, impact 3
- `art/export_2x/characters/kestrel/anims/kestrel_cast_{e,s,n,w}.png` — 6 frames, 10 fps, impact 3
- `art/export_2x/characters/kestrel/anims/kestrel_hit_{e,s,n,w}.png` — 4 frames, 12 fps, scenario flinch
- `art/export_2x/characters/kestrel/anims/kestrel_death_{e,s,n,w}.png` — 6 frames, 10 fps, hold last
- `art/export_2x/characters/ironjaw/anims/ironjaw_hit_{e,s,n,w}.png` — 4 frames, 12 fps, scenario flinch
- `art/export_2x/characters/ironjaw/anims/ironjaw_death_{e,s,n,w}.png` — 6 frames, 10 fps, hold last
- `art/export_2x/characters/gloam/anims/gloam_walk_{e,s,n,w}.png` — 6 frames, 12 fps, loop
- `art/export_2x/characters/gloam/anims/gloam_attack_{e,s,n,w}.png` — 5 frames, 12 fps, impact 2
- `art/export_2x/characters/gloam/anims/gloam_cast_{e,s,n,w}.png` — 4 frames, 10 fps, impact 2
- `art/export_2x/characters/gloam/anims/gloam_hit_{e,s,n,w}.png` — 4 frames, 12 fps, scenario flinch
- `art/export_2x/characters/gloam/anims/gloam_death_{e,s,n,w}.png` — 6 frames, 10 fps, hold last
- `art/export_2x/characters/mender/anims/mender_hit_{e,s,n,w}.png` — 4 frames, 12 fps, scenario flinch
- `art/export_2x/characters/bastion/anims/bastion_hit_{e,s,n,w}.png` — 4 frames, 12 fps, scenario flinch

Ironjaw `attack_*` in this folder is the louder Batch-1c slam. Kestrel walk is the v5 strip. Kestrel attack stays the prior sheet.

Optional bank next to those folders:

- `art/export_2x/characters/kestrel/kestrel_frames.tres`
- `art/export_2x/characters/ironjaw/ironjaw_frames.tres`
- `art/export_2x/characters/gloam/gloam_frames.tres`

## PNG layout

Horizontal strip, equal cells, full height.

- **walk:** 6 frames, 12 fps, loop. Width should divide by 6. A width that does not divide is kept as one frame.
- **attack:** 6 frames, 12 fps, one-shot. Frame 3 is the impact pose.

A `.tres` is used as authored (frame count, fps, loop). Author walk clips at 12 fps, looping.

## Optional drawn masters

Not required at runtime. Used only when the lettered export file for that facing is missing:

`art/grok_project/anims/<class>_<anim>_<se|ne|sw|nw>.png`

`_se` fills `*_e`, `_sw` fills `*_s`, `_ne` fills `*_n`, `_nw` fills `*_w`.

## Playback

- **Walk strip for this facing, and the clip is playing:** the pawn faces the step (`walk_n/e/s/w`) before the foot moves. One full cycle plays on the 0.30s tile (6 frames at about 20 fps). The foot-down cell shows when the hop is on the ground and through the last 18% plant hold. On these sheets that cell is frame 0; a 1–2px sole tip still counts as that row. The sampler retargets if a sheet's plant is another index, without stretching the tile. The sprite hops on the body only (Bastion about 2.5px, Ironjaw the shared 3px, Kestrel and Gloam about 3.5px, Mender the shared 3px) and squashes Y from about 0.96 back to 1 on the plant only. The foot, ground marks, aim, shade, and name stay on the pawn. The first tile and a direction change, including a 180, take a 50ms weight shift after the facing is set. A 180 does not spin through a side facing. Straight tiles do not settle. The path holds the planted idle briefly before the next cast. A clock stuck on the contact frame while the foot slides is not a walk. No tile-tall hop. Gloam uses `gloam_walk_*`.
- **Walk missing, or `play()` does not start:** the same hop, plus squash on launch/land and stretch at the crest. Mender and Bastion ship walk only.
- **Attack strip:** one-shot plus a lunge to the tile edge (~18px). Impact frame holds inside the 0.6s lock. Ambush keeps the longer reach. Ironjaw Strike / Shoulder / Crush use the louder `attack_*`. Gloam Cut uses `attack_*` and holds frame 2.
- **Mark Shot:** `cast_mark_<facing>` (6 frames, 12 fps, impact 3). If that sheet is missing it plays v3 `attack_*`. The bolt leaves hand height at the release frame, following the body if the bow has lunged.
- **Detonate:** `cast_<facing>` (6 frames, 10 fps, impact 3). It does not borrow `attack_*`. A missing sheet is a point pose. The signal waits for the cast impact cell.
- **Hit / death:** `hit_*` is the scenario flinch (576×160, four 144×160 cells, foot row about y=149–150, same pivot as the walk). It plays only when damage resolves, after contact, for the current facing. A miss or a self-cast does not play it. Frame 1 flashes. Frame 4 has settled. Feet stay on that baseline for all four frames. Playback is one-shot at 12 fps and does not add the no-strip knock or squash. A flinch that cuts a walk returns to the idle plant, not the passing stride frame. `death_*` plays and then holds the last cell, including after a snapshot rebuild. A missing hit sheet keeps the white flash plus the procedural flinch, and a missing death sheet dissolves.
- **`*_gen.png`:** never loaded.
