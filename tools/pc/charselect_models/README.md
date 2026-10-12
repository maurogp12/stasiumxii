# Character-select models

PC only. These scripts build the 3D figures for the character-select pedestal. Nothing else in the game loads them.

## Ironjaw male (P4 trial)

```
blender --background --python tools/pc/charselect_models/build_ironjaw_m.py
```

Tested with Blender 4.2.23 LTS. The script is deterministic. It writes:

```
art/pc/characters_3d/ironjaw/ironjaw_m.glb
art/pc/characters_3d/ironjaw/albedo.png
art/pc/characters_3d/ironjaw/mask.png
art/pc/characters_3d/ironjaw/dye_mask.png
art/pc/characters_3d/ironjaw/gear/cragmaw_<slot>.glb
```

`IRONJAW_RENDER=off` skips stills. `preview` writes the two front frames. `final` writes front, three-quarter, and back for the base clothes and for Cragmaw, under `docs/pc/media/charselect/ironjaw_raw/`. `IRONJAW_SAMPLES` sets the Cycles sample count.

Authoring space is Blender Z-up, facing −Y. The glTF export is Y-up, facing +Z, origin at the feet. Limits: 15,000 triangles, 60 bones, height 1.75–1.95. Mask channels are R skin, G hair, B eyes. Cloth and metal stay black. `dye_mask.png` is white only on Cragmaw and the stage leaves dye off.

Not built in this script (listed in `manifest.json`): the female figure, the other four classes, Tyrantjaw, Pitmaw, and extra hairstyles. Four face meshes (`face_0` … `face_3`) are the face-type hook.

Turnaround beside the painted sheet:

```
python3 tools/pc/charselect_models/compose_turnaround.py \
  --ref /path/to/ironjaw_base_and_sets.png \
  --v7 /path/to/ironjaw_walk_S_f00.png
```
