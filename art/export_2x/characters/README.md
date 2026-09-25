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

`<anim>` is `walk` or `attack` for the v3 files on disk. Optional Batch-1c names in the same folder, loaded when the file exists: `cast_mark`, `cast`, `hit`, `death`. Gloam uses the same pattern. `*_gen.png` is ignored.

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

- **Walk strip for this facing, and the clip is playing:** loop at authored fps for the whole path. The pawn faces the step (two turn frames when facing changes) before it slides through cell centers (about 0.22s each). The snapshot facing snaps after the land. The sprite root bounces 4–6px. No tile-tall hop. Scale stays at rest while the cycle plays.
- **Walk missing, or `play()` does not start:** the same slide, the same bounce, plus squash on launch/land and stretch at the crest. Gloam stays here until `gloam_walk_*` is on disk.
- **Attack strip:** one-shot plus a lunge to the tile edge (~18px). Impact frame holds inside the 0.6s lock. Ambush keeps the longer reach. Ironjaw Strike / Shoulder / Crush use `attack_*`.
- **Mark Shot:** `cast_mark_<facing>` when that PNG exists (6 frames, 12 fps, impact 3). Until then it plays v3 `attack_*`. The bolt leaves hand height at the release frame.
- **Detonate:** `cast_<facing>` when that PNG exists (6 frames, 10 fps, impact 3). Until then a point pose. It does not borrow `attack_*`.
- **Hit / death:** `hit_*` and `death_*` when present. Otherwise a white flash plus flinch, and a dissolve. Do not invent those frames.
- **`*_gen.png`:** never loaded.
