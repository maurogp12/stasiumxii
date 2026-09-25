# Walk / attack strips (export_2x)

Godot on `mobile` plays these the moment the files exist. Until then the pawn keeps today's hop and the static `art/characters/<class>/<class>_<n|e|s|w>.png` facing.

Kestrel and Ironjaw Batch-1 strips in this folder are **interim** PIL deformations of the locked turnarounds (silhouette and colours; limbs are approximate). Mauro can drop redrawn strips on the same paths. Animation names stay `walk_<e|s|n|w>` and `attack_<e|s|n|w>`.

Loader: `units/strip_library.gd`. Missing paths use `ResourceLoader.exists` and return null. They do not error.

## Prefer these paths

Per-facing PNG (this is the drop Godot stubs now):

`art/export_2x/characters/<class>/anims/<class>_<anim>_<n|e|s|w>.png`

SpriteFrames bank (authored slices; this is what playback uses when the file exists):

`art/export_2x/characters/<class>/<class>_frames.tres`

Animation names inside the `.tres`: `walk_e`, `walk_s`, `walk_n`, `walk_w`, `attack_e`, `attack_s`, `attack_n`, `attack_w`. Walk loops at 12 fps. Attack is one-shot. Impact frame index is **3** (0-based) for both kits.

The `.tres` wins when that clip is present. A per-facing PNG fills a letter the `.tres` left empty. Playback bakes those cells off `CompressedTexture2D` so Android does not keep a runtime `AtlasTexture` slice.

`<class>` is `kestrel` or `ironjaw` for Batch 1. The same folders work later for `gloam`, `mender`, and `bastion`.

`<anim>` is `walk` or `attack`. A `cast_<n|e|s|w>.png` in the same folder is optional and not part of Batch 1.

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

Optional bank next to those folders:

- `art/export_2x/characters/kestrel/kestrel_frames.tres`
- `art/export_2x/characters/ironjaw/ironjaw_frames.tres`

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

- **Walk strip for this facing, and the clip is playing:** loop at authored fps for the whole path. No hop arc. Position still tweens about 0.25s per tile.
- **Walk missing, or `play()` does not start:** hop plus the static facing. The hop is not dropped just because the files exist.
- **Attack strip:** one-shot plus the ~6px lunge, at 12 fps when the 0.6s lock has room. Ambush keeps the longer reach. A cast with no cast strip (Kestrel's bow) plays this attack cycle too.
- **Attack missing:** lunge plus the static facing. A cast strip, when present, still uses the rise.
