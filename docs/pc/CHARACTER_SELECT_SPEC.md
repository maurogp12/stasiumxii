# PC character select / creation screen: spec

*Requested by Luca (via Stasium Bot, PR #252, 11 Oct 2026). Approved for writing by Mauro: "Si usa scenario pero creo que grok se encargara de eso" (Scenario for the 2D art).*

> **12 Oct 2026, Luca's decision: no 3D.** The screen uses **2D cut-out puppets (Ankama style)** of the painted class art. The earlier 3D exception is withdrawn, so the whole game stays 2D painted. §0, §5, §7, §8 and §9 below are rewritten for the 2D route; §12 records the decision and what happens to the 3D PRs.

**Status:** Proposed. Build packages follow §9, and each one needs Mauro's OK before it merges into `pc/world-zones`. **PC only.** Nothing goes to `main` or `mobile`.

**References:** Luca's two Dofus screen recordings (character list; class screen).

---

## 0. Rules for this screen

- **No 3D anywhere** (Luca, 12 Oct 2026). The character on the pedestal is a **2D cut-out puppet** (§5). The earlier 3D exception is withdrawn.
- **Everything else on the screen is 2D too:**
  - the backdrops;
  - the big class illustrations;
  - the UI panels;
  - the icons;
  - the island and pedestal sprites.
- **Performance mode** (Esc > Visual Settings) must still work here; see §5.5.
- **Renderer:** the screen must look right on Godot's **Compatibility** renderer as well as Forward+. Our captures, and weak PCs, run OpenGL 3. That means:
  - `canvas_item` shaders only, Compatibility-safe GLSL;
  - no screen-space effects.

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
| Backdrop | painted **Koliseo arena at dusk** (§13; was a stormy sea) | full screen |
| Weather overlay | rain streaks (GPU particles in 2D) and **lightning**: a full-screen white flash of 0.08 s, plus a painted bolt sprite at a random x, every 6–14 s | full screen |
| Left panel | dark parchment or iron frame, title "Characters" | x 48–560, y 120–960 |
| List rows | portrait 72×72 (class bust, §6), name (bold), "Lv 23" and class icon 32×32. The selected row has a gold edge. Hover lifts the row by 2 px | 96 px tall, up to 5 rows |
| Create button | orange, "+ Create a character", at the bottom of the left panel. Hidden when the 5 slots are full | 464×64 |
| Right stage | a painted **floating island** sprite, with the selected character's **2D puppet idling on it** (§5). The island bobs ±6 px on a 4 s sine | island 760×420, centred at x 1300, y 640 |
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
| Centre | stone **pedestal** sprite, with the **2D puppet** on it (§5) | pedestal 420×160 at y 860; character about 520 px tall |
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
- Changes show **live** on the puppet (§5.4). A **Reset** link restores the class defaults.

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

## 5. The 2D puppet on the pedestal (and on the island)

The Ankama way (Dofus, Wakfu): the painted character is **cut into parts** and animated with keyframes and tweens. Ours uses the **same part split as the world walker and the visible-gear plan**, so gear pieces are separate painted layers here too, and what you wear in the world is what you see on the pedestal.

### 5.1 Parts and layers
- **Parts** (one painted image each, per facing): `head`, `hair`, `eyes`, `torso`, `upper_arm_l/r`, `lower_arm_l/r`, `hand_l/r`, `thigh_l/r`, `shin_l/r`, `foot_l/r`, `weapon`, plus `cape` or `robe_skirt` where the class has one (Mender, Gloam).
- **Gear layers follow the visible-gear rule** (`art/characters/painted/ironjaw_gear/README.md`): a worn piece **replaces** the base parts in its zone and never sits on top of the base clothing.
  - head → `hair`;
  - chest → `torso`, both arms and the hem;
  - legs → thighs and shins;
  - boots → feet;
  - weapon → `weapon`.
  - An empty slot shows the base part.
  - The roster's equipped gear (§2) picks the layers.
- **Face types:** 3 to 5 `head` variants per class and gender (`head_f1` … `head_f5`), with the same pivot and size. The hairstyle can travel with the face if Luca wants.
- **Godot build:** one `Node2D` per part in a parent chain (the hip, then the torso, upper arm, lower arm and hand, and so on), each holding a `Sprite2D`. That is plain cut-out animation, with no `Skeleton2D` or mesh deformation. Binary alpha, and z-order per part from the rig file.
- **Joints overlap so no holes show.** Each child part is painted about 6 px (at master size) past its joint, under its parent. The cross-section test (§9) checks for gaps at every joint in every frame. This is the neck lesson from the visible gear.

### 5.2 Facings ("drag to turn" is replaced)
- **Revised 12 Oct 2026.** The puppet uses the two approved visible-gear paintings and makes no new views:
  - **S** is the front three-quarter view, looking down a little like the game camera;
  - **B** is the back view: the approved `base_E.jpg` and every `<family>_E_<slot>.jpg` are back views, and they stay that way;
  - **S mirrored** gives the other front three-quarter view.
  - A true side view is **not** painted. Repaints of new angles drifted, so this avoids the risk.
- **Turn:** arrows under the pedestal, or a horizontal drag of 60 px or more, step S → S-mirrored → B → S. Each step is a 0.18 s cross-fade (squash 0.96 on x at the midpoint), which reads like a turntable without 3D.
- The idle starts on **S**. After 4 s without input it goes back to S.

### 5.3 Animation
- Keyframes are data in `rig.json` (§8): position, rotation and scale per part, with a curve per key. They are built into an `Animation` for an `AnimationPlayer` at load time, so the art team can tune them without touching code.
- **`idle`:** a loop of 3 to 4 s. Breathing (torso scale y ±1.5 %), a head bob, a slight arm swing and weapon sway, and hair or cape secondary motion (a lagged copy of the torso rotation).
- **`select`:** one shot of 1.5 to 2.5 s, a class flourish (for example, Ironjaw raises the axe and slams it down, with a dust puff sprite). It plays when the class, gender or face changes, or when Create is pressed, then returns to idle.
- **Frame rate:** the animation is tweened, so it runs at the screen rate (60 fps). It is not locked to the world's 17.144 fps.
- On the **list screen**, the same puppet stands on the island at 0.8 scale, idle only.

### 5.4 Live recolour (body only, per §11)
- One `canvas_item` **ShaderMaterial** shared by all parts, with uniforms `skin`, `hair`, `eyes`, plus a per-part `mask_tex`.
- `mask_tex` is painted with each part:
  - **R** = skin;
  - **G** = hair (and eyebrows);
  - **B** = eyes (iris);
  - black = untouched (clothes, armour, weapon).
- **Shading is kept:** the same luminance-times-tint maths as before, `lum = dot(c.rgb, vec3(0.299, 0.587, 0.114)); tinted = lum * 2.0 * tint;` mixed by the mask channel, in R, G, B order. Port it from #355's `recolour.gdshader`, the one piece of that PR worth keeping.
- **Armour dye later:** a separate `dye_mask` per gear layer, for the premium-shop dye (§11). It is not part of this screen's first build.
- The chosen colours and face are saved in the roster. The world and combat sprites use the same R/G/B masks (P5, §9), so the body colours show everywhere.

### 5.5 Performance mode on this screen
- No rain particles. Lightning becomes a flash only, at most every 14 s.
- The puppet uses the half-size parts (§8), and idle secondary motion is off.

### 5.6 Fallback (so the screen can ship before every puppet exists)
If a class has no puppet yet, the pedestal shows its **locked painted idle sprite** (`units/painted_looks.gd`, `idle` S, scaled to about 520 px tall), with the appearance UI disabled ("Coming soon"). The screen must be fully playable with **zero** puppets.

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

## 7. No 3D (tested)
1. **Folders:**
   - puppet scenes and scripts in `scenes/pc/character_select/`;
   - puppet art in `art/pc/character_select/puppets/<class>_<m|f>/`.
2. **No-3D test** (in `tests/run_character_select_tests.gd`). It fails if:
   - any `.tscn` in the project contains a `Node3D`, `Camera3D`, `MeshInstance3D`, `Light3D`, `WorldEnvironment` or a `SubViewport` with `own_world_3d`;
   - any `.glb`, `.gltf` or `.blend` file is under `art/` or `scenes/`.
3. **Memory:** only the selected class and gender's parts are loaded. Switching class frees the previous puppet. Leaving the screen frees it too, and a test checks that no puppet nodes remain after entering the world.

## 8. Puppet brief: files, sizes, who does what

**Sizes and masters (revised 12 Oct 2026, after drift check try 2 on #366):**
- **The masters ARE the approved paintings.** Cut the puppet straight from `art/characters/painted/ironjaw_gear/source/`:
  - `base_S.jpg` and `base_E.jpg`, the back view;
  - each set's `<family>_{S,E}_<slot>.jpg`.
  - Each 1024×576 painting is cropped to a **640×720 canvas per facing**, with the figure about **520 px** tall. That is the pedestal size at 1080p, so the master is drawn 1:1. **No upscaling and no repaint of the figure.** That gives zero drift.
  - Why: try 2 repaints were slimmer, and S had a third axe and a different face. Mauro approved these exact paintings.
- **Scenario paints only:**
  - the hidden areas under each joint, about **6 px** of overlap at master size, matched to the painting;
  - the 3–5 face variants on the S head, and the back of the head for B where hair differs;
  - the R/G/B masks.
- **Half-size copies:** the build script makes them (320×360) for Performance mode and the list-screen island.
- **Display:** the master shows at 1.0 on the pedestal. At 1440p and above the screen scale can enlarge it; light softness there is accepted.
- **Later classes:** the visible-gear base and set paintings for each class become that class's masters too, so the paintings are made once, for the world and the select screen.

**File layout per class and gender:**

```
art/pc/character_select/puppets/ironjaw_m/
  rig.json                     # parts, parent, pivot, z, rest pose per facing; idle and select keys
  S/base/<part>.png            # master (figure ~520 px, cut from the approved painting), binary alpha
  S/base/<part>_mask.png       # R skin / G hair / B eyes, same size
  S/base/head_f1..f5.png (+ _mask)
  S/<family>_<slot>/<part>.png # gear layers, e.g. S/cragmaw_chest/torso.png
  B/...                        # the same for the back view (cut from the *_E paintings)
  _half/...                    # generated half-size copies, do not edit
  source/                      # full-figure paintings, Scenario ids (.gdignore)
```

**Who does what:**

| Who | Does |
|---|---|
| **Scenario Art** (Luca's team) | Cuts the parts from the **approved visible-gear paintings** (no new full figures). Paints only the hidden areas under the joints, the face variants and the R/G/B masks. The part split follows the world walker's parts |
| **Build agents** (Luca's team) | `build_tools/pc_charselect/cut_puppet.py`: cuts or arranges parts from the sheets, writes the half-size copies and checks alpha and pivots. Then `rig.json` (pivots and parent chain), the idle and select keys, the puppet scene, the shader, the turn control, the roster hook and the tests |

**First puppet: Ironjaw, male**, with the base plus Cragmaw, Tyrantjaw and Pitmaw, the three sets already approved for the world. It is the default hero, its look is the most seen, and its sets exist.

**Then:**
- Ironjaw female;
- Kestrel → Bastion → Gloam → Mender, m and f. Gloam and Mender come last because of the cloak and robe.

The female puppets wait on the female world bases (§11) so that both match.

## 9. Build packages (each: own branch, green suites, before/after clip, a CHANGE_LOG_PC.md row, no merge to main or mobile)
| # | Branch | Content | Depends on |
|---|---|---|---|
| P1 | `pc/charselect-flow` | Roster save and migration (§2), both screens with **placeholder art** and the **painted-sprite fallback** (§5.6), the create/name/delete flow, keys, Performance mode hooks, and the containment test skeleton | none |
| P2 | `pc/charselect-art` | All §6 2D art (Scenario) plus the manifest. The screens switch to it | P1 |
| P3 | `pc/charselect-puppet-stage` | The puppet scene: part loader from `rig.json`, the `AnimationPlayer` built from data, the S → S-mirrored → B turn, the body recolour shader (ported from #355), and gear layers switching by slot. Uses a **test puppet** cut from the approved Ironjaw visible-gear paintings | P1 |
| P4 | `pc/charselect-puppet-ironjaw` | Ironjaw `m` at master size: base, 3 face types, masks, the Cragmaw / Tyrantjaw / Pitmaw layers, idle and select, and a clip. Then one package per class and gender | P3 |
| P5 | later | Female world sprites and world-sprite recolour masks (see open questions) | Mauro's decision |

**Tests to add** (in `run_character_select_tests.gd`, which takes the suite count up by 1):
- the roster: create, rename, delete, the 5-slot cap, name rules, migration from the old save;
- the launch routing (empty goes to the Class Screen; otherwise to the List);
- the class switch updating art, radar, tabs and the puppet;
- the skin, hair and eye uniforms set from swatches and saved, and the face type saved;
- Create → ✓ entering the world as that class at Crossroads;
- X cancelling;
- Performance mode using the half-size parts;
- no 3D (§7);
- no holes at any joint in any idle or select frame, in S and B, for the base and every gear layer;
- each gear layer replacing its base parts, so no base pixels show in that zone;
- the turn control stepping S → S-mirrored → B;
- the screen working with zero puppets.

## 10. Open questions for Mauro and Luca
1. **Female characters:** the locked world and combat looks are one gender per class. Should the female option be:
   - (a) select screen only for now;
   - (b) hidden until female painted sheets exist;
   - (c) a new art job for all five classes' world and combat sheets? That is about the size of the whole locked-looks work again.
2. **Colours in the world:** is it OK that colours show only on this screen until P5 (mask sheets for the painted world sprites)?
3. **Slots:** 5 characters?
4. **Radar axes and values** in §4.1: OK as a start?
5. **Mobile:** this screen is PC only. The phone keeps its own class select.

## 11. Mauro's answers to §10 (11 Oct 2026) — these override the sections above where they differ
1. **Female characters: YES** ("Hacer versión femenina"). Every class gets a female version: the pedestal puppet (m and f), the class art (`class_art_<class>_f`), the busts, AND the in-world / combat painted looks (a female no-armour base per class, with every gear set fitting it). The Male / Female toggle stays in the Appearance tab.
2. **Colours:** "Se podra modificar los colores de las armaduras con un tinte especial que se compra en la tienda premium y solo podran elegir como pintar el mono, su pelo, sus ojos, su piel, quiza añadir varios tipos de cara."
   - At creation the player picks only the **body**: **skin tone, hair colour, eye colour, and a face type** (several faces; a hairstyle choice can come with it). These must show **in the world and in combat too**, not only on this screen.
   - **No armour colours at creation.** Armour colour changes only with a **special dye bought in the premium shop** (later package; `backend/pc_premium.gd` exists on PC).
   - So §4's Appearance tab becomes: Male / Female, Face type (3–5 options), Skin (8 tones), Hair (8 colours + custom), Eyes (8 colours + custom). The §5.4 mask channels become **R = skin, G = hair, B = eyes** on the base body (the armour gets its own dye mask later).
3. **Slots: 5** characters (as proposed).
4. **Radar values in §4.1: approved** as they are.
5. **Who makes the 3D models (12 Oct 2026):** Luca's team, with their own scripted Blender pipeline (trial on `pc/charselect-3d-ironjaw`). Mauro: "opcion b, estoy trabajando con ellos". The earlier "Grok" note is dropped. **Superseded by §12: no 3D.**

## 12. Luca's decision: 2D puppets, no 3D (12 Oct 2026)
- **Decision** (Luca, via Stasium Bot on #252, 11 Oct 2026 9:34 PM): the select and creation screen uses **2D cut-out puppets (Ankama style)**, not 3D. The whole game stays 2D painted. This matches how Ankama builds Dofus and Wakfu: painted puppets cut into parts and animated with tweens.
- **Why it's the right call:**
  - The Blender trial (#358) did not reach the painted look.
  - A puppet uses the same paintings, so it matches the game.
  - It reuses the visible-gear layers.
  - It runs on the Compatibility renderer with no special cases.
- **The open 3D PRs:**
  - **#358 (Ironjaw 3D trial):** close it without merging. Round 2 is stopped.
  - **#355 (3D stage):** close it without merging. Carry two pieces into P3 on the new branch:
    - the recolour maths from `recolour.gdshader`, rewritten as a `canvas_item` shader;
    - the capture script idea (`tests/pc/capture_charselect_stage.gd`), for the before/after clip.
    - The GLB, `build_test_model.gd` and the SubViewport stage are dropped.
  - Any roster or flow work from P1 stays as it is.
- **Approval:** P3 and P4 follow the same gate as the UI packages (UI_SPEC_PC.md §9). Claude reviews and approves on Mauro's behalf. Mauro sees the first Ironjaw puppet clip before the other classes start.

## 13. Mauro's look target for the class screen (12 Oct 2026) — overrides §4, §5.2, §6 and §8 where they differ
Mauro picked the **light** UI style and said of this image: "Clara, pero debería ser esta". The image is `docs/pc/look_target/character_select/mauro_target_ironjaw_arena.png`.

- **Backdrop: the Koliseo arena at dusk** replaces the stormy sea.
  - Stone tiers full of crowd, torches, two red banners, a cloudy blue-grey sky, and a sand floor.
  - It is one painting, `backdrop_koliseo_arena` (1920×1080 / 3840×2160).
  - The crimson regrade between screens is dropped, because a red sea no longer fits. The Class Screen instead uses a gentle warm torch-light grade and a slight blur (depth of field) on the backdrop, so the hero reads.
  - **Animated touches**, done in 2D: torch flicker, banners swaying, a slow crowd shimmer, and drifting dust or embers.
- **Pedestal:** the same carved rune pedestal, now lit by the arena (a cool top light with warm torch bounce). It stands centred on the sand, with a soft contact shadow.
- **Hero: eye-level, front three-quarter, standing tall.**
  - The view is a slightly-low eye-level camera, not the world's high top-down angle.
  - The pose: feet apart, chest open, one axe in each hand with the blades out to the sides, so both heads read clearly.
  - The figure is about **640 px tall** at 1080p, feet on the pedestal top.
- **Ironjaw's base look:**
  - the linen shirt laced at the neck with sleeves rolled, a leather sash belt, torn hem;
  - brown wool trousers, tall wrapped leather boots, leather bracers;
  - long dark hair and a full beard;
  - two double-bladed axes.
  - This painting is the target **for this screen**.
- **Masters for the puppet (replaces §8 "the masters ARE the approved visible-gear paintings"):**
  - Scenario Art paints the select-screen figures at this eye-level angle, with **this image as the reference and the drift check**.
  - **S:** the figure from this image, cut out of its backdrop.
  - **S mirrored:** generated by flipping S.
  - **B:** a new back view at the same eye-level angle, painted from S as the reference.
  - **Gear layers:** each set's chest, legs, boots, head and weapon are repainted at this angle. The approved designs (sets PDF and the visible-gear paintings) are the design reference, and this figure is the pose and size reference.
  - Each new painting is checked side by side against this image before it is cut.
- **UI style: light** (the parchment and light-stone variant from U0 v2) on this screen as everywhere else.
- **Hair:** this image has longer hair than the world base. The hair colour and style in this image are the class default for the select screen. Matching the world sprite's hair to it is a Mauro question (open).

