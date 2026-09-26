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

`<class>` is `kestrel`, `ironjaw`, or `gloam` for the strips on disk. The same folders work later for `mender` and `bastion`.

`<anim>` is `walk` or `attack` for the v3 files, plus Batch-1c `cast_mark`, `cast`, `hit`, and `death`. Gloam ships the full set (`walk`, `attack`, `cast`, `hit`, `death`). `*_gen.png` is ignored.

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

## Batch-1c files

Timing is `art/grok_project/anims/BATCH1C_SHIPPED.md`. Kestrel and Ironjaw walk stay v3. Ironjaw attack is the louder strip on the same path.

- `art/export_2x/characters/kestrel/anims/kestrel_cast_{e,s,n,w}.png` — 6 frames, 10 fps, impact 3
- `art/export_2x/characters/kestrel/anims/kestrel_cast_mark_{e,s,n,w}.png` — 6 frames, 12 fps, impact 3
- `art/export_2x/characters/kestrel/anims/kestrel_hit_{e,s,n,w}.png` — 4 frames, 12 fps, impact 0
- `art/export_2x/characters/kestrel/anims/kestrel_death_{e,s,n,w}.png` — 6 frames, 10 fps, hold last
- `art/export_2x/characters/ironjaw/anims/ironjaw_hit_{e,s,n,w}.png` — 4 frames, 12 fps, impact 0
- `art/export_2x/characters/ironjaw/anims/ironjaw_death_{e,s,n,w}.png` — 6 frames, 10 fps, hold last
- `art/export_2x/characters/gloam/anims/gloam_walk_{e,s,n,w}.png` — 6 frames, 12 fps, loop
- `art/export_2x/characters/gloam/anims/gloam_attack_{e,s,n,w}.png` — 5 frames, 12 fps, impact 2
- `art/export_2x/characters/gloam/anims/gloam_cast_{e,s,n,w}.png` — 4 frames, 10 fps, impact 2
- `art/export_2x/characters/gloam/anims/gloam_hit_{e,s,n,w}.png` — 4 frames, 12 fps, impact 0
- `art/export_2x/characters/gloam/anims/gloam_death_{e,s,n,w}.png` — 6 frames, 10 fps, hold last

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

- **Walk strip for this facing, and the clip is playing:** loop at authored fps for the whole path. The pawn faces the hop and the cycle is already playing before the body slides through cell centers (about 0.22s each). A facing change holds two planted frames of that cycle, then moves. It does not pop the idle portrait and it does not slide sideways or backwards. The snapshot facing is applied after the land. The sprite root bounces 4–6px. No tile-tall hop. Scale stays at rest while the cycle plays. A corner keeps the gait frame.
- **Walk missing, or `play()` does not start:** the same facing-before-move slide and the same bounce, plus squash on launch/land and stretch at the crest (weighted hop). Mender and Bastion stay here until their strips exist.
- **Attack strip:** one-shot plus a lunge to the tile edge (~18px). Impact frame holds inside the 0.6s lock. Ambush keeps the longer reach. Ironjaw Strike / Shoulder / Crush use the louder `attack_*`.
- **Mark Shot:** `cast_mark_<facing>` (6 frames, 12 fps, impact 3) with the cast point, not a melee lunge. If that clip is missing it plays v3 `attack_*`. The bolt leaves weapon height along the facing at the release frame.
- **Detonate:** `cast_<facing>` (6 frames, 10 fps, impact 3) with the cast pose. It does not borrow `attack_*`. The line waits for that impact.
- **Hit:** `hit_*` flinch plus a white flash. A missing clip keeps the flash and the knockback.
- **Death:** `death_*` plays and holds the last frame opaque. A missing clip collapses and dissolves. Do not invent those frames.
- **`*_gen.png`:** never loaded.
