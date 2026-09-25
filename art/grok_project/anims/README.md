# Walk / attack / cast strips

Godot on `mobile` plays these the moment the files exist. Until then the pawn keeps today's hop and the static `art/characters/<class>/<class>_<n|e|s|w>.png` facing. Do not commit placeholder strips.

Loader: `units/strip_library.gd`. Missing paths use `ResourceLoader.exists` and return null. They do not error.

## Where to drop files

Per clip, first hit wins:

1. `art/grok_project/anims/export_2x/<class>_<kind>_<facing>.tres` — TA SpriteFrames
2. `art/grok_project/anims/<class>_<kind>_<facing>.tres`
3. `art/grok_project/anims/export_2x/<class>_<kind>_<facing>.png`
4. `art/grok_project/anims/<class>_<kind>_<facing>.png` — Mauro sheet

`<class>` is `kestrel` or `ironjaw` for Batch 1. The same pattern is already wired for `gloam`, `mender`, and `bastion` (Batch 2) — no extra code when those sheets land.

`<kind>` is `walk`, `attack`, or `cast`.

`<facing>` is `se` or `ne`. Baked mirrors use `sw` and `nw`. Cardinal files `n` / `e` / `s` / `w` are accepted too. Godot does not set `flip_h`. Mirrors stay in the files.

Optional combined SpriteFrames (only fills animation names the files above left empty):

- `art/grok_project/anims/export_2x/<class>_strips.tres`
- `art/grok_project/anims/<class>_strips.tres`

Optional last resort: `art/grok_project/anims/<class>_walk.png` (or `.tres`) becomes the generic `walk` clip.

## Batch-1 filenames

Copy these in (PNG or the `export_2x` `.tres` equivalent):

- `kestrel_walk_se.png` / `kestrel_walk_ne.png`
- `kestrel_attack_se.png` / `kestrel_attack_ne.png`
- `ironjaw_walk_se.png` / `ironjaw_walk_ne.png`
- `ironjaw_attack_se.png` / `ironjaw_attack_ne.png`
- optional cast: `kestrel_cast_se.png` / `kestrel_cast_ne.png`

When the mirror pipeline emits them, also drop `*_sw` and `*_nw` for the same class and kind. Those win over the aliases below.

## PNG layout

Horizontal strip, equal cells, full height of the image.

- **walk:** 6 frames, 12 fps, loop. Width must divide by 6. A width that does not divide is kept as one frame.
- **attack / cast:** 6 frames, 12 fps, one-shot, unless a `.tres` says otherwise.

A `.tres` SpriteFrames resource is used as authored (frame count, fps, loop). Prefer that for TA `export_2x`.

## Facing names the pawn already resolves

Pawn facings stay `n` / `e` / `s` / `w`. For a kind, the resolver tries:

1. `walk_se` or `walk_ne` (east → `se`, north → `ne`, south → `sw`, west → `nw`)
2. `walk_<n|e|s|w>`
3. `walk`

Same order for `attack` and `cast`.

The SE sheet is stored as `*_se` and, when those names are still empty, copied to `*_s` and `*_e`. The NE sheet is stored as `*_ne` and, when empty, copied to `*_n` and `*_w`. South and west therefore light up from the drawn sheets until `*_sw` / `*_nw` files exist. Those baked files are tried first, so they replace the alias without a code change.

## What the game does once a strip resolves

- **Walk, this facing:** looping walk at the clip's fps for the whole multi-tile path. No hop arc and no squash. The pawn still tweens about 0.25s per tile. Facing still snaps each step.
- **Walk missing:** hop plus the static facing (today).
- **Attack present:** one-shot strip plus the ~6px lunge. Ambush keeps the longer reach.
- **Attack missing:** lunge plus the static facing.
- **Cast present:** one-shot strip plus the existing cast rise. **Cast missing:** cast tween plus the static facing.
