# U0 v2 HUD mockups (direction A, charcoal & teal)

Real HUD drawn with Pillow + Nunito, composited on REAL game frames. Nothing is painted or upscaled:
the 1280x720 renders are drawn natively at 2/3 scale (all dimensions x 2/3; text at 1280 is rendered
4x and averaged down because hinted <9px variable-font text has bad spacing). Nothing here is committed or pushed.

## Re-run
```
cd /workspace/stasium-pc-look/ui_u0/v2
PY=/workspace/.venv/bin/python
$PY build_hud.py --all            # every frames/*.jpg|png x {dark,light} x {1920,1280}, kit, kit.json, contact, details, metrics.json
$PY build_hud.py --kit            # only out/kit/*.png + kit.json
# one frame, one variant (any frame dropped in frames/ works):
$PY build_hud.py --frame frames/X.jpg --variant dark  --out out/mockup_X_dark_1920x1080.png
$PY build_hud.py --frame frames/X.jpg --variant light --size 1280 --out out/mockup_X_light_1280x720.png
# minimap content is picked from the file name: *crossroads* -> plaza map, *granary*/*dungeon*/*fight* -> room map, else farm map.
# override with --minimap farm|crossroads|dungeon
```
Fetch new frames (public repo, no auth) once the other agent pushes them:
`curl -s "https://api.github.com/repos/maurogp12/stasiumxii/contents/docs/pc/look_target/ui_u0/real_frames?ref=pc/ui-frames"` then download each `download_url` into `frames/`.

## Outputs (out/)
- `mockup_<frame>_<dark|light>_{1920x1080,1280x720}.png`
- `hud_overlay_<frame>_<variant>_1920x1080.png` transparent HUD-only layer (no shadows)
- `kit/*_{dark,light}.png` + `kit/kit.json` (also `out/kit.json`): panel_9slice (96x96, margins 12), bar, orb, slot, slot_rarity_{normal,rare,legendary,ultra},
  minimap_frame (200x200, hole in the centre), button_green/orange/dark (+ button_dark_active gold trim; 96x32, margins 8), title_bar (96x24), xp_bar_track/fill,
  checkbox(_checked), pill, banner_accent. The mockup is assembled from these same pieces (9-slice stretched).
- `contact.png` dark|light per frame; `detail_bar*.png`, `detail_minimap*.png` are 2x NEAREST crops of the 1920 render; `metrics.json` has HUD area and every element rect.

## Notes
- `assets/items/*.png` file names are scrambled by `slice_assets.py` (herbs.png shows a rope, pickaxe.png a bandage, rope.png a quest scroll, scroll.png a pickaxe). build_hud.py maps by what each file shows (ITEM_FILE).
- Crimson/colours/sizes: HUD design numbers live in `render()` (layout) and `THEMES` (palette).

## Menu windows (opened state) - `build_panels.py`
Each of the menu windows drawn natively at 1920x1080 (Pillow + Nunito, no scaling) from the same kit as the HUD (panel 9-slice, title_bar, slot,
buttons, checkbox, xp bar, pill, THEMES palette, draw_text), composited with a soft drop shadow on a real frame together with the normal HUD,
the window's menu button shown active (gold trim) and 3 chat lines bottom-left. Windows are floating panels placed left of centre so the hero at
screen centre stays visible (Map is centred). Nothing is committed or pushed.
```
cd /workspace/stasium-pc-look/ui_u0/v2
PY=/workspace/.venv/bin/python
$PY build_panels.py --panel all                         # 9 windows x {dark,light}, win_*.png, contact_panels.png (~20 s)
$PY build_panels.py --panel inventory_equipment --variant dark
$PY build_panels.py --panel map --variant light --frame frames/real_crosshaven_frame.jpg
```
Windows: `inventory_equipment` (I; ONE combined 900x640 window: Character/Equipment paper doll + detail on the left, Inventory on the right),
`character_stats` (O; same window, left side on the Stats tab), `spells` (P), `quests` (L), `map` (M), `dungeons`, `koliseo`, `shop`, `settings` (Esc).
Output in `out/panels/`: `panel_<name>_<dark|light>_1920x1080.png` (frames other than real_crosshaven_frame get a `_<frame>` suffix),
`win_<name>_<dark|light>.png` (window alone, transparent, no shadow), `contact_panels.png` (3x3 of the 9 dark mockups at 640x360).
- `build_hud.render()` got two optional args: `active` (menu button name(s) with gold trim, default `inventory`, so old output is byte-identical) and
  `spells_key` (hotkey label on Spells; panels pass "P").
- Item icons: painted `assets/items` (+ hue-shifted variants) and simple ImageDraw items (gems, swords, axes, shields, armour pieces, ore, leaves, keys,
  rings, amulets) in `build_panels.py` (`item_img`); spell glyphs are ImageDraw too. All are placeholders for real icon art.
- Paper doll uses `charselect/ship/class_art_ironjaw_m.png` (cropped, scaled to 300 px high).
- Inventory grid is 8 cols x 8 rows of 44 px slots (`GRID_COLS/GRID_ROWS/PITCH` at the top of the inventory section): 6 columns left the 460 px column half empty.
- Settings is one page with Display / Audio / Controls sections (the tab strip is shown with Video active) so every requested control is visible in one mockup.
