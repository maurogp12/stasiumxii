# Walk / attack strips (export_2x)

## Wakfu walk drop

Replace these files in place. Same names. 864×160 RGBA, six frames of 144×160. No `*_gen.png`. No second folder. The `*_frames.tres` walk clips are AtlasTexture slices of these PNGs (cells at x = 0, 144, 288, 432, 576, 720). A new sheet of that size shows up on the next import. Attack, cast, hit, and death sheets stay put.

- `art/export_2x/characters/kestrel/anims/kestrel_walk_{e,s,n,w}.png` — approved Wakfu Kestrel
- `art/export_2x/characters/ironjaw/anims/ironjaw_walk_{e,s,n,w}.png` — Ironjaw A2, replacing any earlier Ironjaw Wakfu walk: Berserker A body, fierce helm (iron-jaw grill with spikes and crest), dual double-bit axes, crimson battle-worn plate
- `art/export_2x/characters/gloam/anims/gloam_walk_{e,s,n,w}.png` — Gloam proposal B, not the white-eyes sheet: amber/yellow glowing eyes, wide chilling grin, dual curved silver daggers with gold hilts, purple cloak with gold trim
- `art/export_2x/characters/mender/anims/mender_walk_{e,s,n,w}.png` — Mender proposal D2: cream/gold hooded robe, green lantern staff, face clearly visible (more open hood). 864×160.
- `art/export_2x/characters/bastion/anims/bastion_walk_{e,s,n,w}.png` — Bastion proposal 2C: charcoal-grey/gold armor, spiked mace, oversized tower shield. 864×160.

Until those PNGs land, playback keeps the sheets already in the kestrel, ironjaw, and gloam folders. Mender and Bastion have no walk strip yet. Kestrel stays on the prior Wakfu walk. Ironjaw's walk drop is A2 and replaces any earlier Ironjaw Wakfu strip. The Gloam file that lands must be proposal B. The Mender file that lands must be proposal D2. The Bastion file that lands must be proposal 2C.

Godot on `mobile` plays these the moment the files exist. Until then the pawn keeps today's hop and the static `art/characters/<class>/<class>_<n|e|s|w>.png` facing.

Kestrel and Ironjaw Batch-1 strips in this folder are **interim** PIL deformations of the locked turnarounds (silhouette and colours; limbs are approximate). Mauro can drop redrawn strips on the same paths. Animation names stay `walk_<e|s|n|w>` and `attack_<e|s|n|w>`.

Loader: `units/strip_library.gd`. Missing paths use `ResourceLoader.exists` and return null. They do not error.

## Prefer these paths

Per-facing PNG (this is the drop Godot stubs now):

`art/export_2x/characters/<class>/anims/<class>_<anim>_<n|e|s|w>.png`

SpriteFrames bank (authored slices; this is what playback uses when the file exists):

`art/export_2x/characters/<class>/<class>_frames.tres`

Animation names inside the `.tres`: `walk_e`, `walk_s`, `walk_n`, `walk_w`, `attack_e`, `attack_s`, `attack_n`, `attack_w`. Walk loops at 12 fps. Attack is one-shot. Impact frame index is **3** (0-based) for both kits.

Walk clips in the `.tres` are slices of the walk PNGs above, so replacing that PNG is the walk update. A per-facing PNG still fills a letter the `.tres` left empty. Playback bakes those cells off `CompressedTexture2D` so Android does not keep a runtime `AtlasTexture` slice.

`<class>` is `kestrel`, `ironjaw`, or `gloam` for the strips on disk. The same folders work later for `mender` and `bastion`.

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
- `art/export_2x/characters/kestrel/anims/kestrel_hit_{e,s,n,w}.png` — 4 frames, 12 fps
- `art/export_2x/characters/kestrel/anims/kestrel_death_{e,s,n,w}.png` — 6 frames, 10 fps, hold last
- `art/export_2x/characters/ironjaw/anims/ironjaw_hit_{e,s,n,w}.png` — 4 frames, 12 fps
- `art/export_2x/characters/ironjaw/anims/ironjaw_death_{e,s,n,w}.png` — 6 frames, 10 fps, hold last
- `art/export_2x/characters/gloam/anims/gloam_walk_{e,s,n,w}.png` — 6 frames, 12 fps, loop
- `art/export_2x/characters/gloam/anims/gloam_attack_{e,s,n,w}.png` — 5 frames, 12 fps, impact 2
- `art/export_2x/characters/gloam/anims/gloam_cast_{e,s,n,w}.png` — 4 frames, 10 fps, impact 2
- `art/export_2x/characters/gloam/anims/gloam_hit_{e,s,n,w}.png` — 4 frames, 12 fps
- `art/export_2x/characters/gloam/anims/gloam_death_{e,s,n,w}.png` — 6 frames, 10 fps, hold last

Ironjaw `attack_*` in this folder is the louder Batch-1c slam. Kestrel walk and attack stay v3.

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

- **Walk strip for this facing, and the clip is playing:** the pawn faces the step (`walk_n/e/s/w`) before the foot moves, and that half-cycle is sampled from the 0.30s tile. Contact frames show only on the plant. Passing frames show only while the foot is between cells. A clock stuck on frame 0 is not a walk. The foot stays on the diamond. During the stride the body leads along the facing and takes a 4–6px rise, then both return. No tile-tall hop. Gloam uses `gloam_walk_*`.
- **Walk missing, or `play()` does not start:** the same slide, the same bounce, plus squash on launch/land and stretch at the crest. Mender and Bastion stay here.
- **Attack strip:** one-shot plus a lunge to the tile edge (~18px). Impact frame holds inside the 0.6s lock. Ambush keeps the longer reach. Ironjaw Strike / Shoulder / Crush use the louder `attack_*`. Gloam Cut uses `attack_*` and holds frame 2.
- **Mark Shot:** `cast_mark_<facing>` (6 frames, 12 fps, impact 3). If that sheet is missing it plays v3 `attack_*`. The bolt leaves hand height at the release frame, following the body if the bow has lunged.
- **Detonate:** `cast_<facing>` (6 frames, 10 fps, impact 3). It does not borrow `attack_*`. A missing sheet is a point pose. The signal waits for the cast impact cell.
- **Hit / death:** `hit_*` flinches without an extra squash. `death_*` plays and then holds the last cell, including after a snapshot rebuild. Otherwise a white flash plus flinch, and a dissolve.
- **`*_gen.png`:** never loaded.
