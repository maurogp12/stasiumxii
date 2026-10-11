# PC character select / creation screen: spec

*Requested by Luca (via Stasium Bot, PR #252, 11 Oct 2026). Approved for writing by Mauro: "Si usa scenario pero creo que grok se encargara de eso" (Scenario for the 2D art; Grok is expected to make the 3D models).*

**Status:** Proposed. Build packages follow §9, and each one needs Mauro's OK before it merges into `pc/world-zones`. **PC only.** Nothing goes to `main` or `mobile`.

**References:** Luca's two Dofus screen recordings (character list; class screen).

---

## 0. Rules for this screen

- **The 3D exception is this screen only.**
  - Luca (11 Oct 2026): this screen may show 3D characters.
  - Everything else stays 2D painted: world, combat, dungeons, NPCs, maps, Koliseo.
  - §7 says how the exception is kept contained and tested.
- **The rest of the screen is 2D:**
  - the backdrops;
  - the big class illustrations;
  - the UI panels;
  - the icons;
  - the island and pedestal sprites.
- **Performance mode** (Esc > Visual Settings) must still work here; see §5.5.
- **Renderer:** the screen must look right on Godot's **Compatibility** renderer as well as Forward+. Our captures, and weak PCs, run OpenGL 3. That means:
  - no SDFGI, volumetric fog or screen-space effects;
  - Standard or simple shader materials only.

## 1. Where it sits in the flow

```
Launch ──► Character List ──(Play)────────────────► World (the character's last cell; new: Crossroads spawn)
             │  ▲
   (+ Create)│  │(Back / X)
             ▼  │
          Class Screen ──(✓ name ok)──► World (Crossroads spawn, level 1)
```

- **Launch:**
  - no characters saved: open the **Class Screen** directly, with a Back button that is hidden;
  - otherwise: open the **Character List**, with the last-played character selected.
- **The current PC class picker:** the PC uses `progress.hero_class` and has no real creation screen; `scenes/class_select.gd` is the Koliseo hot-seat picker. This new screen **replaces how the PC hero is chosen**. The Koliseo picker stays as it is.

## 2. Data: a character roster (new)

Today there is one save, `user://pc_progress.json`, holding a single `hero_class`. Add a roster:

| Item | Proposal |
|---|---|
| File | `user://pc_characters.json`: `{ "version": 1, "last": "<id>", "characters": [ ... ] }` |
| Per character | `id`, `name`, `class_id`, `gender` (`"m"`/`"f"`), `colors` (`{primary, secondary, accent}` as hex), `created`, `level` (mirrored from that character's progress for the list) |
| Progress | one progress file per character: `user://pc_progress_<id>.json` |
| Migration | an existing `pc_progress.json` becomes character #1. Name it "Hero" and let the player rename it; class = `hero_class`, or Ironjaw if empty |
| Slots | 5 characters (Proposed) |
| Names | 3–16 characters: letters, space, `'` and `-`; unique (not case-sensitive); trimmed |
| Delete | on the list, with a confirm dialog that asks the player to type the name |

`pc_progress.gd` gains a `character_id`. Its save and load paths come from the roster. All existing tests keep the old single-file path as a default when no roster exists.

## 3. Screen A: Character List

Reference layout at 1920×1080. The game stretches with `canvas_items` / `expand`, so anchor everything to the edges and corners instead of fixed pixels.

| Area | Content | Size (at 1080p) |
|---|---|---|
| Backdrop | painted **stormy sea**, cool blue-grey (§6) | full screen |
| Weather overlay | rain streaks (GPU particles in 2D) and **lightning**: a full-screen white flash of 0.08 s, plus a painted bolt sprite at a random x, every 6–14 s | full screen |
| Left panel | dark parchment or iron frame, title "Characters" | x 48–560, y 120–960 |
| List rows | portrait 72×72 (class bust, §6), name (bold), "Lv 23" and class icon 32×32. The selected row has a gold edge. Hover lifts the row by 2 px | 96 px tall, up to 5 rows |
| Create button | orange, "+ Create a character", at the bottom of the left panel. Hidden when the 5 slots are full | 464×64 |
| Right stage | a painted **floating island** sprite, with the selected character **idling on it in 3D** (§5). The island bobs ±6 px on a 4 s sine | island 760×420, centred at x 1300, y 640 |
| Bottom right | **Play** button (big, green-gold), and a small **Delete** link | Play 320×72 |
| Top right | Settings (opens the Visual Settings panel), Quit | icons 48×48 |

**States:**
- `empty`: this screen is skipped; see §1.
- `list`
- `confirm_delete`

**Keys:**
- Up/Down change the selection.
- Enter = Play.
- Delete = the delete flow.
- Esc = Quit confirm.

## 4. Screen B: Class Screen (creation)

**Transition from the list (0.6 s):**
- the backdrop **regrades from cool blue to crimson**, through a colour-grade shader uniform on the backdrop (tween 0 → 1);
- the list slides out to the left;
- the class UI fades in.

Back reverses all of it.

| Area | Content | Size (at 1080p) |
|---|---|---|
| Backdrop | the same stormy sea with the **crimson grade**: a red sky, dimmer lightning | full screen |
| Class illustration | the big **painted 2D class art** behind the pedestal (§6). Fades in 0.35 s when the class changes. Swaps with the gender | about 1100×1100 visible, centred at x 960, y 470, behind the pedestal |
| Left: class grid | 5 class tiles in 2 columns plus 1 (Kestrel, Ironjaw, Mender, Gloam, Bastion), each a painted bust and the class name. The selected tile glows | tiles 150×150 |
| Left: radar | a **pentagon stat radar** with 5 axes (§4.1). It animates 0.25 s between classes | 300×300 |
| Centre | stone **pedestal** sprite, with the **3D character** on it (§5) | pedestal 420×160 at y 860; character about 520 px tall |
| Below the pedestal | the **name field** (hidden until Create), see the flow below | 420×56 |
| Right panel | tabs **Gameplay** and **Appearance** | x 1380–1872, y 120–960 |
| Bottom | **Back** (left), **Create** (centre, orange) | |

**Gameplay tab:**
- difficulty, 1–3 stars;
- the role line (from `ROLE_LINES`);
- lore, 2–3 sentences;
- the class's spells as icons 56×56, with tooltips from `data/kits.gd`;
- one line on the element.

**Appearance tab:**
- a **Male / Female** toggle (§8, open question);
- **3 colour channels**: Primary (cloth or armour), Secondary (trim or leather), Accent (glow or metal). Each channel has **8 preset swatches** plus **one custom swatch** that opens a picker (HSV wheel, Godot `ColorPicker` with presets turned off).
- Changes show **live** on the 3D model (§5.4). A **Reset** link restores the class defaults.

**Create flow (the button morphs):**
1. **Create** turns into the **name field** (focused), with a **red X** (cancel) and a **green ✓** (confirm). This is a 0.2 s morph.
2. **✓:**
   - validate the name (§2);
   - if it's valid: write the roster entry and its progress file, then enter the world at the Crossroads spawn;
   - if not: the field shakes, with a one-line reason under it.
3. **X:** back to the Create button. The class and colours are kept.
4. Enter = ✓, Esc = X.

### 4.1 Radar axes and values (Proposed, editable in data)
Axes: **Damage, Range, Survival, Support, Mobility**, each 1–5.

| Class | Damage | Range | Survival | Support | Mobility |
|---|---|---|---|---|---|
| Kestrel | 4 | 5 | 2 | 1 | 3 |
| Ironjaw | 5 | 1 | 4 | 1 | 3 |
| Mender | 2 | 3 | 3 | 5 | 2 |
| Gloam | 5 | 2 | 2 | 1 | 5 |
| Bastion | 2 | 1 | 5 | 4 | 2 |

Put the data in `data/pc/class_screen.json`, together with the lore, difficulty and default colours.

## 5. The 3D character on the pedestal (and on the island)

### 5.1 How it's drawn
- A **`SubViewport`** with **`own_world_3d = true`** and `transparent_bg = true`, shown through a `SubViewportContainer` (stretch) or a `TextureRect`, in the 2D UI between the class art and the panels.
- **Viewport size:** 768×1024 (portrait). It sits at 0.5 scale in Performance mode; see §5.5.
- `render_target_update_mode`:
  - `WHEN_VISIBLE` on the active screen;
  - `DISABLED` when the screen is hidden or the game is minimised.
- Everything 3D lives inside this viewport: `Camera3D`, lights, `WorldEnvironment` and the model. **No 3D node exists outside it.**

### 5.2 Camera and lighting
- **Camera:** perspective, FOV 28°, at about (0, 1.25, 4.2) m, looking at (0, 0.95, 0). That is a slight top-down angle, matching the iso feel of the game.
- **Key light:** a warm `DirectionalLight3D`, rotation (−35°, 35°), energy 1.2, shadows **off** (Compatibility-safe).
- **Rim light:** an `OmniLight3D` behind and above the model, coloured per class, energy 2.0, range 4.
- **Fill:** ambient colour from a local `WorldEnvironment` (no sky), at 0.35.
- **Contact shadow:** a soft blob decal sprite drawn in 2D on the pedestal under the feet, not a real shadow.

### 5.3 Animation and interaction
- `AnimationPlayer` from the GLB:
  - **`idle`** (loop) always;
  - **`select`** (one-shot, 1.5–2.5 s, a class flourish) when the class or gender changes, or Create is pressed, then back to idle.
- **Turntable:** click-drag on the character rotates it around Y (0.4°/px). It eases back to −20° facing after 2 s idle.
- On the **list screen**, the same model is shown on the island at 0.8 scale, idle only.

### 5.4 Live recolour
- One **`ShaderMaterial`** on the model, with uniforms `albedo_tex`, `mask_tex`, `primary`, `secondary`, `accent`.
- `mask_tex` is a **3-channel mask** painted with the model: R = primary, G = secondary, B = accent, black = untouched (skin, eyes, glowing runes).
- **Shading is kept:**
  ```
  float lum = dot(albedo.rgb, vec3(0.299, 0.587, 0.114));
  vec3 tinted = lum * 2.0 * tint;          // tint per channel
  albedo.rgb = mix(albedo.rgb, tinted, mask_channel);
  ```
  It is applied per channel in R, G, B order. It uses Compatibility-safe GLSL only.
- The swatch click sets the uniform directly (no tween needed). The chosen colours are saved in the roster.
- **In the 2D world, phase 2:** the painted world sprites don't recolour yet. Doing that needs matching mask sheets per painted strip (§9, P5). Until then the colours show on this screen, and on the list, only. **The screen must say this:** a small note under the swatches.

### 5.5 Performance mode on this screen
- The SubViewport renders at 0.5 scale (384×512, upscaled) with MSAA off.
- No rain particles. Lightning becomes a flash only, at most every 14 s.
- The model plays idle at 0.5× update rate (via `process_mode`/animation speed).

### 5.6 Fallback (so the screen can ship before every model exists)
If a class has no GLB yet, the pedestal shows its **locked painted idle sprite** (`units/painted_looks.gd`, `idle` S, scaled to about 520 px tall), with the colour UI disabled ("Colours coming soon"). The screen must be fully playable with **zero** GLBs.

## 6. 2D art list (Scenario, same kit rules as the dungeons)
All pieces are painted in Scenario, team "Maurogarza06's Organization", project "stasium". They use binary alpha where they are cut out, 1x plus `_2x` masters, and a `manifest.json` under `art/pc/character_select/`.

| Piece | Size (1x / 2x) | Notes |
|---|---|---|
| `backdrop_storm_sea` | 1920×1080 / 3840×2160 | a stormy sea and sky, cool. One painting; the crimson regrade is a shader, not a second painting |
| `lightning_bolts` ×3 | 256×768 | additive |
| `floating_island` | 760×644 (accepted 11 Oct: includes the cliff underside; platform centre at x1300, y640) | cut out, with a small waterfall |
| `pedestal` | 420×245 (accepted 11 Oct; the top ellipse is the stand surface) | carved stone, front-lit; regrade or rim-tint it on the crimson screen |
| `class_art_<class>_<m/f>` | 1100×1100 / 2200×2200 | **the big painted class illustration**, dramatic, matching the locked look of each class (the dark-steel v7 Ironjaw etc.). Transparent edges that fade into the backdrop. 10 total (5 classes × 2 genders) |
| `class_bust_<class>_<m/f>` | 150×150 and 72×72 | tiles and list portraits |
| `class_icon_<class>` | 32×32 | list rows |
| UI frame kit | 9-slice | panel, tab, buttons (orange Create, green Play, red X, green ✓) |

## 7. Keeping 3D contained (tested)
1. **Folders:**
   - all 3D scenes and scripts in `scenes/pc/character_select/`;
   - GLBs and 3D textures in `art/pc/characters_3d/<class>/`.
2. **Containment test** (new `tests/run_character_select_tests.gd`), which fails if:
   - any `.tscn` outside `scenes/pc/character_select/` contains a `Node3D`, `Camera3D`, `MeshInstance3D`, `Light3D`, `WorldEnvironment` or `SubViewport` with `own_world_3d`. The scanner walks every `.tscn` under `scenes/`, `ui/`, `board/` and `units/`;
   - any script outside that folder `preload`s or `load`s from `art/pc/characters_3d/`;
   - the world and dungeon scenes have a 3D node count above 0 after loading.
3. **Leaving the screen** frees the SubViewport and model (`queue_free`). A test checks no 3D nodes remain in the tree after entering the world.
4. **Memory:** only the selected class's GLB is loaded; switching class unloads the previous one.

## 8. 3D model brief (for Grok, or Scenario 3D if used)
| Item | Requirement |
|---|---|
| Format | **glTF binary (.glb)**, one file per class and gender: `<class>_<m/f>.glb` |
| Scale / pivot | 1 unit = 1 m, height 1.75–1.95 m (Bastion and Ironjaw taller), origin at the feet, facing +Z |
| Geometry | **≤ 15k triangles**, one skinned mesh (a separate weapon mesh is OK), **≤ 60 bones** |
| Textures | `albedo` 2048² sRGB; `mask` 2048² linear (R/G/B channels as in §5.4); optional `emission` 1024² for glowing runes. No normal map required (Compatibility-friendly) |
| Animations | `idle` (loop, 3–5 s), `select` (one-shot, 1.5–2.5 s). Optional: `walk` (for later) |
| Look | **must match the locked painted look** of each class: the turnarounds in `docs/pc/art_help/class_walk_looks/*/` and the locked action sheets (Ironjaw = dark-steel v7). Give the modeller the S and E paintings and the turnaround |
| Delivery | GLB plus a front/side/back render on grey and a short idle clip, on its own `pc/charselect-3d-<class>` branch |

**First class to ship: Ironjaw.** Reasons:
- it is the default hero;
- its look is the most-seen (dark-steel v7);
- Mauro asked about its look specifically.

Then **Kestrel → Bastion → Gloam → Mender**. Mender and Gloam come last because the robe and cloak are the hardest to rig.

## 9. Build packages (each: own branch, green suites, before/after clip, a CHANGE_LOG_PC.md row, no merge to main or mobile)
| # | Branch | Content | Depends on |
|---|---|---|---|
| P1 | `pc/charselect-flow` | Roster save and migration (§2), both screens with **placeholder art** and the **painted-sprite fallback** (§5.6), the create/name/delete flow, keys, Performance mode hooks, and the containment test skeleton | none |
| P2 | `pc/charselect-art` | All §6 2D art (Scenario) plus the manifest. The screens switch to it | P1 |
| P3 | `pc/charselect-3d-stage` | SubViewport stage, camera, lights, turntable, recolour shader, and a **test GLB** (a simple capsule with a mask) to prove the pipeline in the Compatibility renderer | P1 |
| P4 | `pc/charselect-3d-ironjaw` | Ironjaw `m` GLB (Grok), its recolour defaults, a clip. Then one package per class | P3 |
| P5 | later | Female world sprites and world-sprite recolour masks (see open questions) | Mauro's decision |

**Tests to add** (in `run_character_select_tests.gd`, which takes the suite count up by 1):
- the roster: create, rename, delete, the 5-slot cap, name rules, migration from the old save;
- the launch routing (empty goes to the Class Screen; otherwise to the List);
- the class switch updating art, radar, tabs and the model;
- recolour uniforms set from swatches and saved;
- Create → ✓ entering the world as that class at Crossroads;
- X cancelling;
- Performance mode scaling the viewport;
- containment (§7);
- the screen working with zero GLBs.

## 10. Open questions for Mauro and Luca
1. **Female characters:** the locked world and combat looks are one gender per class. Should the female option be:
   - (a) select screen only for now;
   - (b) hidden until female painted sheets exist;
   - (c) a new art job for all five classes' world and combat sheets? That is about the size of the whole locked-looks work again.
2. **Colours in the world:** is it OK that colours show only on this screen until P5 (mask sheets for the painted world sprites)?
3. **Slots:** 5 characters?
4. **Radar axes and values** in §4.1: OK as a start?
5. **Mobile:** this screen is PC only. The phone keeps its own class select.
