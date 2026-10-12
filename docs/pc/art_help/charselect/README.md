# Character select art (P2), the P1 screens, and the P3 puppet

PC only. The painted pieces live in `art/pc/character_select/`. P1 (`pc/charselect-flow`) wires the Character List and the Class Screen to those files.

Spec: `docs/pc/CHARACTER_SELECT_SPEC.md` on branch `claude/pc-zones-spec` (section 6). That file is not on this branch.

## P3 soft test puppet (Ironjaw male)

The class pedestal and the list island draw a 2D cut-out for Ironjaw male. Every other class, and Ironjaw female, stay on the locked idle sprite and show "Coming soon" on the appearance controls. Gender stays enabled. The screen still plays with no puppet at all.

This cut is soft on purpose. It is not the 2× 1024×1280 paint (that is P4). `build_tools/pc_charselect/cut_puppet.py` cuts the approved 1024×576 paintings at 1:1, with no upscale. The figure is about 520 px. Each child keeps about 6 px of its parent's real edge colours under the joint. Re-run it from the repo root:

`python3 build_tools/pc_charselect/cut_puppet.py`

```
art/pc/character_select/puppets/ironjaw_m/
  rig.json                          parts, pivots, idle and select keys
  S/base/<part>.png and _mask.png   base body, R skin / G hair / B eyes
  S/base/head_f1.png … head_f4.png  broad, narrow, soft, sharp
  S/<family>_<slot>/<part>.png      Cragmaw, Tyrantjaw, Pitmaw
  B/...                             the back view, cut from the *_E.jpg paintings
  _half/...                         generated half-size copies
  source/                           the 1024×576 paintings (.gdignore)
```

Sm is not a third paint. The scene mirrors S. B is the back view. The source files stay `base_E.jpg` and `<family>_E_<slot>.jpg`.

The rig is a Node2D parent chain. Each part holds a Sprite2D. The weapon hangs off the right hand. There is no bone rig. Idle and select are data in `rig.json`, built into an AnimationPlayer at 60 fps when the puppet loads. Arrows under the pedestal, or a horizontal drag of 60 px, step S → S mirrored → B. Each step is a 0.18 s cross-fade, with a squash to 0.96 on x at the midpoint. Idle starts on S and returns to S after 4 s with no input. The master is drawn at 1:1, and the feet stand on the top ellipse of the pedestal.

`scenes/pc/character_select/recolour.gdshader` is a canvas_item shader shared by the parts. R tints skin, G tints hair, B tints eyes, and black leaves the texel as painted. The tint is the luminance maths from the closed 3D stage: `lum * 2.0 * tint`. There is no spatial shader, no armour dye, and no 3D node.

Performance mode loads the `_half` parts and turns the hair and weapon lag off. The list uses the same puppet at 0.8 scale, idle only.

Source is on the box at `/workspace/stasium-pc-look/charselect/`. The copy in the repo is `art/pc/character_select/` (`manifest.json`, set `pc_character_select_p2_safe_pieces`, version v1, 11 Oct 2026). Reference mocks for the two screens are in this folder.

## Delivered

| File | Pixels | Bytes | Status |
|---|---|---|---|
| `art/pc/character_select/backdrop_storm_sea.png` | 1920×1080 | 2,037,351 | Delivered. Matches the spec 1920×1080. |
| `art/pc/character_select/backdrop_storm_sea_2x.png` | 3840×2160 | 5,291,322 | Delivered at the spec 2× pixel size. Upscaled from a 1024-wide paint, so it may look soft. |
| `art/pc/character_select/lightning_bolt_1.png` | 256×768 | 125,471 | Delivered. Matches the spec 256×768. Draw additive. |
| `art/pc/character_select/lightning_bolt_2.png` | 256×768 | 101,868 | Delivered. Matches the spec 256×768. Draw additive. |
| `art/pc/character_select/lightning_bolt_3.png` | 256×768 | 88,686 | Delivered. Matches the spec 256×768. Draw additive. |
| `art/pc/character_select/floating_island.png` | 760×644 | 701,056 | Delivered. Taller than the spec 760×420. Includes the cliff underside. |
| `art/pc/character_select/floating_island_2x.png` | 1520×1288 | 2,062,467 | Delivered. 2× of the taller 1× island (spec 2× of 760×420 would be 1520×840). |
| `art/pc/character_select/pedestal.png` | 420×245 | 226,684 | Delivered. Taller than the spec 420×160. The platform ellipse is the top face. |
| `art/pc/character_select/pedestal_2x.png` | 840×490 | 765,869 | Delivered. 2× of the taller 1× pedestal (spec 2× of 420×160 would be 840×320). |
| `art/pc/character_select/ui_panel.png` | 374×513 | 325,636 | Delivered. UI 9-slice source. |
| `art/pc/character_select/ui_btn_orange.png` | 413×133 | 109,389 | Delivered. UI 9-slice source (orange Create). |
| `art/pc/character_select/ui_btn_green.png` | 408×133 | 96,845 | Delivered. UI 9-slice source (green Play). |
| `art/pc/character_select/ui_btn_red.png` | 158×157 | 49,206 | Delivered. UI 9-slice source (red X). |
| `art/pc/character_select/ui_btn_ok.png` | 156×158 | 45,890 | Delivered. UI 9-slice source (green check). |
| `art/pc/character_select/ui_tab_dim.png` | 195×125 | 42,234 | Delivered. UI 9-slice source. |
| `art/pc/character_select/ui_tab_lit.png` | 195×123 | 46,215 | Delivered. UI 9-slice source. |
| `art/pc/character_select/manifest.json` | — | 1,170 | Delivered. Names the pieces, the holds, and the placement notes below. |
| `docs/pc/art_help/charselect/mock_list_1080.png` | 1920×1080 | 2,195,540 | Reference mock of the list screen. The P1 clip sits beside it. |
| `docs/pc/art_help/charselect/mock_class_1080.png` | 1920×1080 | 1,786,084 | Reference mock of the class screen. The P1 clip sits beside it. |

16 PNGs plus `manifest.json` under `art/pc/character_select/`. The two mocks live here.

## Held

These are in the spec and named in the manifest, and they are not in this drop.

| Piece | Spec size | Status |
|---|---|---|
| `class_art_<class>_<m/f>` | 1100×1100 / 2200×2200 | Not in this package. |
| `class_bust_*` | 150×150 and 72×72 (`class_bust_<class>_<m/f>`) | Not in this package. The grid and the list use the locked idle instead. |
| `class_icon_*` | 32×32 (`class_icon_<class>`) | Not in this package. |

Mauro answered on 11 Oct 2026 (spec section 11): female versions, yes, for every class. That is ten class paintings (five classes × two) plus the matching busts. This package does not paint them. The Male/Female toggle works and both genders are saved on the roster. Until those sheets exist, the pedestal and the island draw the locked idle (art letter S) for either gender. The Appearance tab customises the body only: face, skin, hair, eyes. Those choices are saved for the world and for combat later. Armour dye is a later premium shop, not part of creation. The class-screen radar uses the approved section 4.1 values.

## Size notes

- **Island.** `floating_island.png` is 760×644. The spec is 760×420 for the visible top. The extra height is the cliff underside. Place it so the platform centre sits at x1300, y640, per the manifest.
- **Pedestal.** `pedestal.png` is 420×245. The spec is 420×160. The platform ellipse is the top face.
- **2× backdrop.** `backdrop_storm_sea_2x.png` is 3840×2160, upscaled from a 1024-wide paint, so it may look soft. The manifest says to repaint it at true 2× if that softness shows.
