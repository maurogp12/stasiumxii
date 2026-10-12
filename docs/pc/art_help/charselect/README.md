# Character-select 3D stage (P3)

PC only. This is the one 3D view in the game: the pedestal and the island on the character-select screen. World, combat, and dungeons stay 2D. P1 drops `scenes/pc/character_select/character_stage.tscn` into the pedestal slot. This package does not build the roster, the swatches, or the shop.

§11 overrides the earlier colour and gender notes. At creation the player colours **skin, hair, and eyes**, and picks a **face type**. There are no armour colours here. A later premium dye package tints gear with its own mask.

## Drop-in

Instance the scene and call:

| Call | What it does |
|---|---|
| `show_model(class_id, gender)` | Loads one GLB. `gender` is `m` or `f`. Returns false when that class has no file, and unloads any previous model. |
| `set_body_colors(skin, hair, eyes)` | Tints the three body channels. |
| `set_face(index)` | Shows that face and sets the `face_index` uniform. Index is 0-based. |
| `set_slot(slot, equipped)` | `weapon`, `head`, `chest`, `legs`, `boots`. |
| `set_list_mode(true)` | Island: scale 0.8, idle only, no select flourish. |
| `set_performance(true)` | Viewport 384×512, MSAA off, animation speed 0.5. |
| `play_select()` / `play_idle()` | Flourish, then the idle loop. List mode stays on idle. |
| `turn_by_pixels(dx)` | 0.4° per pixel around Y. After 2 s still, it eases back to −20°. |
| `set_gear_dye_mask(texture)` | Stores the mask and forces `dye_enabled` to 0. |
| `release()` | Frees the viewport and the model. Call it when the screen closes. |

Only one GLB instance is loaded. Switching class or gender unloads the previous one.

## Files

```
art/pc/characters_3d/<class>/<class>_m.glb
art/pc/characters_3d/<class>/<class>_f.glb
art/pc/characters_3d/<class>/albedo.png
art/pc/characters_3d/<class>/mask.png
art/pc/characters_3d/<class>/dye_mask.png   # authored, not applied
```

The stage loads `<class>_<gender>.glb` when that file exists. Otherwise it loads `<class>/placeholder.glb` from the same folder. If neither exists, `show_model` returns false and P1 keeps the painted sprite. There is no fallback to another class.

Class `test` ships one capsule, `placeholder.glb`, and it serves both `m` and `f`. Real classes do not use that capsule.

## Model

- Origin at the feet (lowest vertex y = 0), facing +Z, height about 1.75–1.95.
- At most 15,000 triangles and 60 bones.
- Delivery textures are 2048×2048. The test capsule is 512×512 so the repo stays small.
- Animations on an `AnimationPlayer`: `idle` looping, 3–5 s; `select` one-shot, 1.5–2.5 s, then back to idle.
- The test capsule: 10 bones, 3,680 triangles, height 1.93, four faces (`face_0` … `face_3`).

## Mask

`mask.png`, nearest filter, one luminance taken from the albedo and reused:

```
lum = dot(albedo.rgb, vec3(0.299, 0.587, 0.114))
tinted = lum * 2.0 * tint
```

Channels, in order, mix that tint over the albedo:

| Channel | Colour |
|---|---|
| R | skin |
| G | hair |
| B | eyes |
| black | painted as-is (tunic, trousers, boots, weapon, gear) |

Uniforms are `skin`, `hair`, and `eyes`. Do not add primary / secondary / accent.

## Faces

Three to five face types, switchable on the model. Name a node `face_<n>` or `face_<n>_<part>` (`face_2_eyes`). The stage shows every node of the chosen index and hides the rest. Head armour hides `base_head` (the hair), not the face. `face_index` on the shader is the same index, for a later texture atlas. It does not shift colour.

## Gear

Separate meshes. An equipped slot hides `base_<slot>` and shows `gear_<slot>`.

| Slot | Base zone it replaces |
|---|---|
| chest | tunic, sleeves, hem |
| legs | trousers |
| boots | shoes and shins |
| head | hair |
| weapon | the base weapon |

`base_body` (skin, hands, neck) stays visible. Cloth, leather, and metal stay mask-black so body colours do not tint them.

## Dye hook

Armour recolour is a later premium package. Do not tint gear in this shader from the body colours.

Leave `dye_mask` (R = cloth to tint), `dye_tint`, and `dye_enabled` (default 0). `dye_mask.png` may sit beside the GLB, white only on the gear UV, but the stage does not load it. `set_gear_dye_mask` stores a texture and keeps dye off. Creation never enables it.

## Stage look

The portrait is a `SubViewport` with its own 3D world and a transparent background, drawn into the slot by a texture rect. Full size 768×1024, MSAA 2×. Performance mode is 384×512, MSAA off, and the same rect upscales it.

- Camera: perspective, FOV 28°, at (0, 1.25, 4.2), looking at (0, 0.95, 0).
- Key: warm directional light, rotation (−35°, 35°), energy 1.2, shadows off.
- Rim: omni behind and above, energy 2, range 4, shadows off, colour from the class.
- Fill: ambient energy 0.35, no sky. No SDFGI, SSR, SSAO, glow, or volumetric fog.
- Contact shadow: a 2D blob under the feet, not a real shadow.

The viewport updates while the stage is on screen and the window is focused, and it stops when the stage is hidden or the window loses focus. `release()` frees it. The shader is spatial only, so it can run on the Compatibility renderer. The rest of the game is unchanged.

## Ironjaw male (P4 trial)

The first real figure is the Ironjaw male, built by `tools/pc/charselect_models/build_ironjaw_m.py` (Blender 4.2.23 LTS, headless). It is the only class GLB. The female file is not generated, and a missing class still does not fall back to the test capsule.

| | |
|---|---|
| File | `art/pc/characters_3d/ironjaw/ironjaw_m.glb` |
| Clothes | Oatmeal linen tunic, brown wool trousers, soft leather shoes, leather wrist wraps, plain iron sword |
| Gear | Cragmaw, one mesh per slot, also exported as `gear/cragmaw_<slot>.glb` |
| Rig | 19 bones, idle 4 s loop, select 2 s one-shot |
| Size | Under 15k triangles, height inside 1.75–1.95, origin at the feet, facing +Z |
| Textures | 2048 albedo, mask, and dye mask. Mask is R skin, G hair, B eyes |
| Faces | `face_0` … `face_3` (spacing, brow, nose, mouth) |

Regenerate with Blender:

```
blender --background --python tools/pc/charselect_models/build_ironjaw_m.py
```

`IRONJAW_RENDER=final` writes the raw albedo turnaround under `docs/pc/media/charselect/ironjaw_raw/` (no recolour; skin stays the neutral grey the mask tints). The comparison still is `docs/pc/media/charselect/ironjaw_turnaround.png`: the painted base and the v7 walk frame beside the Godot stage (creation colours, front, three-quarter, back). `ironjaw_stage_checks.png` is the same stage with a warm skin and a green skin, and two idle poses.

This trial does **not** reach the painted Ironjaw sheet or the v7 dark-steel walk frames. The body is a low-poly loft with a disc face, and the cloth and steel are procedural tiles (thread, grain, a highlight band), not brushwork. Cragmaw reads as bulky plates, a dome helm, a red sash, and a wider jagged sword. It does not have the painted visor, mail, or cloth drape. The silhouette is a heavy man, and the slot contract works: equipping a piece hides that base zone.

Left for later, and named in `art/pc/characters_3d/ironjaw/manifest.json`:

- `ironjaw_f.glb` — same slot names, narrower shoulders, wider hips, a little shorter
- More face types, or a real atlas on the `face_index` uniform (four meshes ship now)
- Hairstyles beyond the single `base_head` mesh
- Kestrel, Bastion, Gloam, Mender
- Tyrantjaw and Pitmaw
