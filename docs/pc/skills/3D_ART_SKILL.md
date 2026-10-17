# Skill: 3D art for Stasium XII (for every Grok / Scenario Art bot)

Read this before making anything 3D. It covers how to make art that becomes a good game-ready 3D model in the **Baldur's Gate 3 + Wartales look**, for a **3D MMO in Godot 4**. All art is original: never copy Larian, Shiro Games or Ankama assets, characters or designs.

---

## 1. The look (style rules)

- **Mood:** gritty, grounded medieval fantasy. Lived-in, worn and believable. No cartoon, no chibi, no neon.
- **Proportions:** realistic human proportions, about 7.5 heads tall. No oversized heads or hands.
- **Palette:** earthy and muted, with ochre, umber, moss green, slate grey, oxblood and iron. Saturated colour only as accents: banners, magic, heraldry.
- **Materials read clearly:** worn leather, dented steel, rough wool, weathered timber, mossy stone. Everything shows wear: scratches, dirt at the bottom, faded paint.
- **Light:** warm key light from the upper left, cool fill, soft ambient occlusion. Dusk scenes use warm torch pools against cool blue shadows.
- **Shapes:** strong, readable silhouettes from a 3/4 top-down tactical camera. Detail goes in the material, not in tiny geometry.

## 2. Concept art that converts well to 3D (image-to-3D input)

Image-to-3D (Meshy) works only if the input is clean. Every concept for conversion must have:

1. **One object per image**, centred, filling about 80% of the frame.
2. **A plain, flat, light-grey background** (#d0d0d0): no scene, no ground, no shadows cast on a floor.
3. **Even, neutral lighting** with no dramatic shadows or rim light. Baked shadows become wrong texture.
4. **3/4 view** for props and buildings. For characters, use an **A-pose turnaround**:
   - front, side and back views on one sheet;
   - the same scale in each view, feet on the same line;
   - arms 30–45° away from the body;
   - fingers slightly apart;
   - mouth closed and a neutral face.
5. **No text, logos, UI, watermarks or frames** in the image.
6. **Readable materials:** paint the texture you want on the model, such as stone blocks, wood grain and cloth weave.
7. **Closed, solid shapes.** Avoid thin floating parts (chains, ropes, loose hair strands, open lattices); they break in 3D. Paint them as solid masses or leave them for modelling later.
8. **Weapons and shields separate.** For characters, deliver the weapon and shield as their own images too, so they can become swappable items.
9. **Resolution:** at least 2048 px on the long side. PNG or high-quality JPG.

## 3. Game-ready model rules (what the build team needs from each model)

| Item | Rule |
|---|---|
| **Units** | 1 unit = 1 metre. Hero 1.8 m. |
| **Heights** (to the highest tip) | NPC house 5–6 m (below the wall) · wall 6 m (8 m module, 2.5 m thick) · gatehouse 8 m (arch ≥ 4 m) · tower 11 m to the crenellation (14.7 m to the roof tip) · Normal player house 5.5 m · Rare 6.5 m · Legendary 8 m · bank 8.5 m · townhall 9 m (clock tower 12 m) · cathedral nave 12 m (spire 18 m, ~14×26 m) · castle keep 20 m (tallest, ~28×22 m) |
| **Pivot** | At the **foot centre on the ground** (y = 0). Buildings: centre of the footprint. |
| **Facing** | The front faces **+Z**. Doors are on the front. |
| **Triangle budget (MMO)** | Hero 15–25k · enemy 10–20k · NPC 8–12k · house 5–15k · landmark 20–60k · prop 0.5–3k · tree 3–8k |
| **LOD** | LOD0 full, LOD1 ~50%, LOD2 ~20%. For buildings, also an impostor billboard for very far views. |
| **Textures** | PBR metal/rough: albedo, normal, ORM (occlusion/roughness/metal). 2048² for hero and landmarks, 1024² for houses and enemies, 512² for props. Shared **trim sheets** and tiling materials for walls and roofs where possible. |
| **Texel density** | About 512 px per metre on buildings, so neighbours look equally sharp. |
| **Collision** | A simple convex or box collider per piece (`-col` suffix), never the render mesh. |
| **Format** | **glTF 2.0 binary (.glb)**, Y-up, with materials embedded or referenced. |
| **Naming** | `<category>_<name>_<variant>_LOD<n>.glb`, for example `bld_house_halftimber_a_LOD0.glb`, `chr_hero_male_LOD0.glb`, `prp_barrel_oil_LOD0.glb`. |
| **Modular kit** | Walls, gates and towers snap on a **1 m grid**. A wall segment is exactly 4 m or 8 m long, and its ends meet the next segment with no gap or overlap. |

## 4. Characters

- **Skeleton:** use one humanoid skeleton for every human (hero, NPCs, bandits) so animations are shared. Deliver the T-pose bind plus the rig.
- **Equipment:** gear is split into slots (head, chest, hands, legs, feet, cloak, main hand, off hand) so it can be swapped. Body parts under gear are hidden or removed to avoid clipping.
- **Core animations:** idle, walk, run, turn, attack (1H, 2H, ranged, spell), hit, shove, block, dodge, downed, death, interact, sit. Each loops cleanly where needed, at 30 fps.
- **Faces:** neutral expression. Story cinematics come later.

## 5. Environment and terrain

- **Ground:** tiling PBR materials for grass, cobble, dirt, mud and stone, blended by paint masks in Godot. Deliver seamless 2048² textures.
- **Water:** use the engine shader; just provide the bank and edge stones as props.
- **Nature:** trees and bushes as meshes with alpha-cutout leaves and a wind vertex colour (red = sway). 3 variants per species.
- **Dressing props:** barrels, crates, carts, stalls, fences, lamps and torches (with the emissive part as a separate material for night).

## 6. Using Meshy (image-to-3D, text-to-3D) without wasting credits

- **Credits are limited.** Test the cheapest preview first, and only refine models you would actually use.
- **Prefer image-to-3D from a clean concept** (section 2) over text-to-3D. It's more controllable and matches the look.
- **Generate once, check, then refine.** Never batch-generate many variations "to see".
- **After generation:** fix the scale and pivot, decimate to the budget, check the normals, rebake textures if they're muddy, and add a collider.
- **Log every job** (id, input, cost, result) in the delivery note.

## 6b. Using Scenario (the Grok bots have it)

Scenario is the main tool for **concepts and consistency**, and it can also generate 3D.

1. **Train a style model first.**
   - Once Claude approves the first slice concepts, train a **custom Scenario style model** on 15–30 approved, original images in the BG3/Wartales look.
   - Generate every later concept with that model, so the whole game has one consistent style.
   - Train separate models for **characters** and for **environment/props**.
2. **Keep it consistent:**
   - reuse the same style model, prompt template, negative prompt and aspect ratio;
   - save good seeds;
   - use **reference images** (image-to-image or style reference) from approved pieces.
3. **Prompt template for conversion concepts:**

   > "<object>, gritty grounded medieval fantasy, realistic proportions, worn materials, earthy palette, single object centred, 3/4 view, plain flat light-grey background, even neutral lighting, no shadows on floor, no text"

   Negative prompt: "cartoon, chibi, neon, text, watermark, frame, busy background, dramatic rim light, floating parts".
4. **Character turnarounds:** generate front, side and back on one sheet ("character sheet, A-pose, front side back views, same scale"), then check that the 3 views match.
5. **Variants:** create house and prop variants with image-to-image from one approved base, so they stay in the same family.
6. **3D in Scenario:**
   - Scenario offers image-to-3D generators. Check its model list for the 3D models available and use the best one.
   - Use them for **props and buildings**. For **characters that need a rig and animation**, use Meshy, or whichever tool gives a rigged result.
   - In both cases, apply sections 3–5 (scale, pivot, budget, LOD, collider).
7. **Upscale:** upscale final concepts to at least 2048 px before conversion. Don't upscale small images 4×+ and call them HD.
8. **Credits:** don't batch dozens "to see". Make 1–4 targeted generations, pick the best and refine it. Log what you used.

## 7. Delivery

- **Folder:** `docs/pc/look_target/crosshaven_city/work/3d/<category>/`. Concepts go in `work/3d_slice/concepts/`.
- **For each piece:**
  - the `.glb` (all LODs);
  - the textures;
  - a **turntable preview** (8 angles, one sheet) next to a 1.8 m human silhouette;
  - a JSON with `height_m`, `footprint_m`, `pivot`, `tris` per LOD, `collider`, and `slot` (for gear).
- **Labels:** 🖼️ IMAGEN / CONCEPTO for concepts; models are tested 🎮 EN EL JUEGO by the build team.
- **Self-review before posting** (section 8). Claude approves before anything reaches Mauro.

## 8. Self-review checklist (do it every time)

- [ ] It matches the look in section 1: gritty, realistic, earthy, worn.
- [ ] Its height in metres matches the scale table, and it stands next to a 1.8 m human.
- [ ] The pivot is at the foot centre and the front faces +Z.
- [ ] It's within the triangle budget, with LODs present.
- [ ] Textures are PBR, sharp at the target texel density, with no baked dramatic shadows.
- [ ] No floating, broken or inside-out parts, and no gaps where kit pieces meet.
- [ ] It's original: nothing copied from another game.
