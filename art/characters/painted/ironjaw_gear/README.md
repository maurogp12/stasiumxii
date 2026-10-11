# Visible gear (paper doll): Ironjaw pilot

With nothing equipped, a hero shows an unarmoured base body. Every worn piece then appears on the body, like Wakfu, where a hat you put on shows on your character. Mauro's rules:

- The base is the same simple adventurer clothes for every class, and the class reads from its weapon. The base was approved ("Sí, aprobada").
- A piece REPLACES its whole body zone, so no base clothing shows under or around armour.
- The chest covers the torso, the full sleeves and the hem. The legs piece covers the trousers from hip to boot. The boots cover the shoes. The head covers the hair. The weapon replaces the base axes.
- An empty slot shows the base.
- Visible slots are the mobile ones: weapon, head, chest, legs and boots.

This pilot covers one class, Ironjaw, with his three approved sets:

- **Cragmaw** (Normal);
- **Tyrantjaw** (Legendary);
- **Pitmaw** (Ultra), with the repainted Jaw-Guard Helm.

PC only.

## Folders

| Folder | What |
|---|---|
| `source/` | The paintings (1024x576 JPG, upscaled x1.25 by the cut) and the Scenario asset ids (`scenario_assets.txt`). See the table under "source/ files". Godot ignores this folder (`.gdignore`). |
| `base/` | The whole base body in one sheet per kind and facing. It is drawn while nothing is worn, at the same cost as a locked look. |
| `base_<group>/` | The base split by slot group: `weapon`, `head`, `chest`, `legs`, `boots`, plus `skin` (the bare hands). These draw once anything is worn. |
| `<family>_<slot>/` | A look strip, for example `cragmaw_chest`. |

Strip files are named `ironjaw_<strip>_<kind>_<S|E>.png`. The kinds are walk, idle, attack, skill, hit and death. A strip `x_back` lives in folder `x`.

Every strip has the same layout as the body:

- one row of cells, with the cell size, pivot and frame count of the body for that kind (`units/pc_gear_specs.gd`, generated);
- 17.144 fps and binary alpha;
- 1x cells of at most 256 px, as on the locked sheets;
- W and N are mirrors made by the loaders.

A strip facing with no pixels in a kind is not written.

### `source/` files

| File | What |
|---|---|
| `base_{S,E}.jpg` | The no-armour base. It is an edit of the locked v7 turnaround targets and keeps the same axes. |
| `locked_target_{S,E}.jpg` | The locked v7 targets. The axe pixels are matched against them. |
| `<family>_{S,E}_<slot>.jpg` | The base with ONE piece painted on. |
| `legs_base.jpg` | The locked v7 leg pieces repainted as trousers and shoes. The layout is in `legsheet_layout.json`. |
| `<family>_legsheet_{legs,boots}.jpg` | The same leg sheet with that set's leg armour or boots. |
| `<family>_design.*` | The approved design panel, cropped from the sets PDF. |
| `pitmaw_*_head_v1.jpg` | The first Pitmaw helm, kept for reference. |

## Pipeline (`build_tools/pc_gear/`)

Re-run with:

```
python3 build_tools/pc_gear/build_ironjaw_gear.py --work /tmp/ironjaw_gear_work [--families cragmaw,tyrantjaw,pitmaw]
```

It takes about 10 to 15 minutes and 2 to 3 GB of RAM. It reads the locked rig from git (`claude/ironjaw-actions` 9d784a1 and `art/ironjaw-walk-help` 0f3eeb8), so neither branch needs to be checked out.

### 1. `gear_cut.py`: paintings to rig parts

The output is in the format the locked action rig `ijrig.py` reads: 1280x720 canvases per part, plus leg pieces.

**The base cut** uses hand-placed joints in `CFG`: shoulder, elbow, grip and the axe "eye" for each arm, plus neck and pelvis.

- `head`: hair, face and beard. It is its own part and its own strip, so a face type can be swapped later.
- `body`: the tunic. It is cut at the tunic hem.
- `pauld`: the shoulder caps.
- `uarm`: the upper arms. They grow under the shoulder cap from their own cross-section.
- `fore`: the forearm, hand and axe as one rigid piece. It splits three ways: the hand goes to the skin group, the axe to the weapon group, and the rest of the forearm to the chest group.
- Holes the arms leave in the tunic and the collar under the head are filled with real texture from the same painting (block quilting, no smear fill).
- The legs are the locked v7 leg pieces (thigh, shin and boot per leg), repainted on the leg sheet and graded to the painting's trousers.
- The axes are the pixels the base painting kept from the locked targets, so they sit exactly on the locked forearms.

**A look** is the pixels that changed between its one-piece painting and the base, inside the slot's region. Pixels that turned into background are dropped. Each pixel is assigned to the rig part the base drew there, grown outward for armour wider than the body:

- chest: body, pauldrons, upper arms and forearm sleeves;
- head: the head part;
- weapon: the forearm parts.

A chest panel that an arm covered in the painting is closed under the arm with its own texture. Legs and boots come from the leg sheets.

### 2. `gear_rig.py`: parts to frames through the locked rig

`ijrig.py` is imported unchanged. Each frame is posed once with the locked numbers, so the base moves exactly like the locked actions. The pose covers the torso, head, cape, the FK arms with their aimfix edge turns, and the IK legs. The walk is the same rig, driven by the TA walk joints, the joints the v7 walk was painted on.

Each frame is then drawn once per strip:

- **`base`**: everything, in the rig's draw order.
- **Group strips** (`base_<group>` and every look `<family>_<slot>`): only that group's parts.
  - `_back` holds what the rig draws before the legs, which is the far arm in S. It is drawn raw, and the game draws it behind everything.
  - The rest goes in the front strip. In it, a part of a group stacked LOWER in the game but drawn LATER by the rig erases the strip by its base silhouette. For example, the near leg covers the far boot, and the front sleeve covers the helm.

So every strip has the body's cells, pivot and frames, and the game only stacks them.

### 3. `build_ironjaw_gear.py`: frames to sheets

The frames are written as sheets at the locked Ironjaw scale (0.5547). Each kind gets one shared layout, the union of every strip, so all strips of a kind share one cell and pivot. The script also writes `units/pc_gear_specs.gd`, which holds SPECS, WORLD (gait numbers measured on the new walk) and STRIPS.

## Data: `data/pc/gear_looks.json`

| Key | What |
|---|---|
| `slots` | weapon, head, chest, legs, boots. |
| `stack` | Draw order per art facing, bottom to top: `legs, boots, chest, head, weapon, skin`. Every `_back` strip is drawn first, in the same order. |
| `classes.<class>` | `enabled`, the art root, the full-body strip and the `base_strips` per group. Only Ironjaw is enabled. Other classes keep their locked look. |
| `sets.<family>` | The set families of a class. |

A worn mobile part id `<family>.<slot>` (from `backend/gear_bag.gd` on `origin/mobile`, for example `cragmaw.chest`) draws the strip `<family>_<slot>`. A part with no strip draws nothing, and the base of that slot shows.

## Runtime

**`units/gear_looks.gd`**:

- `looks_for(class, worn)`: slot to strip.
- `stack_for(class, looks, art)`: the ordered strip list.
- On-demand sheet and cell loaders. Only the strips of the facing and kind on screen load.
- `worn_parts()`: the dev source until the PC gear bag drives it. It reads `-- --gear-parts=cragmaw.head,...` or `set_worn_parts`.

**`units/gear_stack.gd`** puts one child per strip on the body drawable. The strips take the body's position, scale and modulate and show the body's cell.

- With nothing worn it adds no node.
- With anything worn, the body hides (`self_modulate.a = 0`) and the strips draw.

The stack is used in three places:

- **World walker** (`crosshaven_walker.gd`): `set_gear_parts`. It syncs on every presented cell.
- **Dungeon pawn** (`pawn.gd`): `set_gear_parts`. It follows the idle Sprite or the playing strip each frame, through the painted cells' `painted_key` meta. The dungeon board sets it on the hero.
- **Character window portrait**: `refresh_gear`.

`units/painted_looks.gd` draws an enabled class's `base` sheets and specs instead of its locked ones. The v7 entries stay in `units/pc_character_specs.gd`.

## Adding another class or set

| Task | Steps |
|---|---|
| **New set** for a class that already has a base (about 1 to 2 hours) | 1. Paint 10 one-piece edits of `base_{S,E}` (weapon, head, chest, legs, boots), using the set's design panel as the second reference. The chest covers the torso, sleeves and hem; the legs cover hip to boot. 2. Paint 2 leg-sheet edits (legs and boots) on `legs_base.jpg`. 3. Add the family to `sets` in the data. 4. Re-run the build. |
| **New class** (about a day) | 1. Paint its base on its locked S/E targets. 2. Hand-place the joints in `gear_cut.CFG`. 3. Point the rig import at that class's locked rig (`claude/<class>-actions`, which has the same `act_blockout`/aimfix format). 4. Repaint its leg sheet. 5. Enable the class in the data. Then each set follows the new-set row. |

## Later: face types, skin, hair, eye colours, female bodies

These are not built yet.

- **Face types:** the head is its own part and strip, so a face type is another painted head on the same base, cut and rigged by the same code.
- **Skin, hair and eye colours:** these need a mask per base frame (R = skin, G = hair, B = eyes). It is cheap to add. Paint or segment a mask image of the base paintings, cut it with the same base masks into a `base_mask` part set, and render it through `gear_rig.py` like any group. The rig's pose is already shared. The game would then tint the `base_head` and `base_skin` strips with a shader that reads the mask.
- **Female bodies:** a female body is a new base painting per class. Each set's pieces are then painted on that base the same way.
