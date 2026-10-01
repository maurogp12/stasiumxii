# Crosshaven animated assets (v4, PROPOSED)

Art suggestion only: nothing here is wired in-engine or in zone data. All files are additive; v1 ids, sizes and anchors are unchanged.

* Layout: every animation is a **horizontal sprite strip** (frames left to right, equal width). 1x files sit here; 2x masters (exactly 2x) are in `_2x/`.
* Machine-readable: `anim_meta.json` has file, frame size, frame count, fps, loop, anchor, blend and the static prop it pairs with.
* Loops are seamless: frame N-1 flows into frame 0.
* Preview: `/workspace/art/pc/crosshaven_world/mock/v4_crossroads_alive.mp4` and `v4_eastmarch_alive.mp4` (+ `.gif`).

## v4.1 changes (motion readability)
* **Sway:** amplitude 2.5x, 16 frames at 8 fps. The canopy now bends (top lags, the far side dips, tops drop while leaning) and has leaf flutter. The mock adds per-instance speed (0.3, 0.5 or 0.7 Hz) and phase, plus a travelling gust band. `flowers_a` to `_d` sway too.
* **Windmill sails:** one full turn every ~4.4 s. **Watermill wheel:** one turn every ~4.4 s.
* **Fountain:** top jet, a thicker spilling curtain, splash crowns and stronger basin rings.
* **Smoke:** thick, lit puffs. **Fire:** bigger flicker with height jumps, detached licks and heat glow. **Embers:** bigger and brighter. **Leaves:** real tumbling leaf blades (spin and flip) instead of dots.
* **Water:** ripple contrast about 2x, 8 glints instead of 4, and pulsing shore foam that washes in and out.
* **Cloud shadows:** darker (alpha up to 0.46) and drifting one tile per 10 s loop.
* The mock video loops seamlessly every 10 s. Rates are chosen so the 0, 2.5 and 5 s sample frames always differ.

## Sheets

| file (1x) | frame (1x) | frames | fps | blend | pairs with | anchor |
|---|---|---|---|---|---|---|
| `animated/bird.png` | 22x18 | 6 | 12 | mix | - | centre; faces +x (flip_h for -x) |
| `animated/bird_shadow.png` | 18x8 | 1 | 1 | mix | - | centre |
| `animated/bush_a_sway.png` | 52x36 | 16 | 8 | mix | bush_a | bottom-centre (same anchor as props/bush_a.png; frame is 6px (1x) wider on each side so the canopy never clips) |
| `animated/bush_autumn_sway.png` | 52x33 | 16 | 8 | mix | bush_autumn | bottom-centre (same anchor as props/bush_autumn.png; frame is 6px (1x) wider on each side so the canopy never clips) |
| `animated/bush_b_sway.png` | 52x34 | 16 | 8 | mix | bush_b | bottom-centre (same anchor as props/bush_b.png; frame is 6px (1x) wider on each side so the canopy never clips) |
| `animated/bush_flower_sway.png` | 52x35 | 16 | 8 | mix | bush_flower | bottom-centre (same anchor as props/bush_flower.png; frame is 6px (1x) wider on each side so the canopy never clips) |
| `animated/bush_small_a_sway.png` | 52x30 | 16 | 8 | mix | bush_small_a | bottom-centre (same anchor as props/bush_small_a.png; frame is 6px (1x) wider on each side so the canopy never clips) |
| `animated/bush_small_b_sway.png` | 52x29 | 16 | 8 | mix | bush_small_b | bottom-centre (same anchor as props/bush_small_b.png; frame is 6px (1x) wider on each side so the canopy never clips) |
| `animated/butterfly_blue.png` | 14x12 | 4 | 16 | mix | - | centre (insect; draw a 2px soft shadow ~10px below at 1x) |
| `animated/butterfly_pink.png` | 14x12 | 4 | 16 | mix | - | centre (insect; draw a 2px soft shadow ~10px below at 1x) |
| `animated/butterfly_yellow.png` | 14x12 | 4 | 16 | mix | - | centre (insect; draw a 2px soft shadow ~10px below at 1x) |
| `animated/cat_idle.png` | 34x26 | 6 | 6 | mix | - | bottom-centre = feet; faces +x |
| `animated/cat_walk.png` | 34x26 | 6 | 12 | mix | - | bottom-centre = feet; faces +x |
| `animated/chicken_peck.png` | 26x24 | 6 | 6 | mix | - | bottom-centre = feet; faces +x |
| `animated/chicken_walk.png` | 26x24 | 6 | 12 | mix | - | bottom-centre = feet; faces +x (flip_h for -x) |
| `animated/cloud_shadow_a.png` | 256x256 | 1 | 0 | mix (multiply-like: dark cool colour, alpha <= 0.46) | - | tileable texture |
| `animated/cloud_shadow_b.png` | 256x256 | 1 | 0 | mix (multiply-like: dark cool colour, alpha <= 0.46) | - | tileable texture |
| `animated/ember.png` | 12x12 | 6 | 12 | add | - | centre |
| `animated/fire_small.png` | 30x44 | 8 | 15.2 | mix | - | bottom-centre = fire base |
| `animated/firefly.png` | 16x16 | 4 | 6 | add | - | centre |
| `animated/flowers_a_sway.png` | 32x31 | 16 | 8 | mix | flowers_a | bottom-centre (same anchor as props/flowers_a.png; frame is 6px (1x) wider on each side so the canopy never clips) |
| `animated/flowers_b_sway.png` | 32x31 | 16 | 8 | mix | flowers_b | bottom-centre (same anchor as props/flowers_b.png; frame is 6px (1x) wider on each side so the canopy never clips) |
| `animated/flowers_c_sway.png` | 38x31 | 16 | 8 | mix | flowers_c | bottom-centre (same anchor as props/flowers_c.png; frame is 6px (1x) wider on each side so the canopy never clips) |
| `animated/flowers_d_sway.png` | 38x32 | 16 | 8 | mix | flowers_d | bottom-centre (same anchor as props/flowers_d.png; frame is 6px (1x) wider on each side so the canopy never clips) |
| `animated/fountain_water.png` | 108x82 | 12 | 10.8 | mix | fountain_2x2 | identical canvas + anchor to props/fountain_2x2.png (child at offset 0,0, draw above) |
| `animated/grass_tuft_a_sway.png` | 50x29 | 16 | 8 | mix | grass_tuft_a | bottom-centre (same anchor as props/grass_tuft_a.png; frame is 6px (1x) wider on each side so the canopy never clips) |
| `animated/grass_tuft_b_sway.png` | 46x30 | 16 | 8 | mix | grass_tuft_b | bottom-centre (same anchor as props/grass_tuft_b.png; frame is 6px (1x) wider on each side so the canopy never clips) |
| `animated/grass_tuft_tall_a_sway.png` | 54x37 | 16 | 8 | mix | grass_tuft_tall_a | bottom-centre (same anchor as props/grass_tuft_tall_a.png; frame is 9px (1x) wider on each side so the canopy never clips) |
| `animated/leaf_fall_gold.png` | 16x16 | 12 | 12 | mix | - | centre |
| `animated/leaf_fall_green.png` | 16x16 | 12 | 12 | mix | - | centre |
| `animated/leaf_fall_red.png` | 16x16 | 12 | 12 | mix | - | centre |
| `animated/reeds_a_sway.png` | 62x40 | 16 | 8 | mix | reeds_a | bottom-centre (same anchor as props/reeds_a.png; frame is 11px (1x) wider on each side so the canopy never clips) |
| `animated/reeds_b_sway.png` | 52x39 | 16 | 8 | mix | reeds_b | bottom-centre (same anchor as props/reeds_b.png; frame is 11px (1x) wider on each side so the canopy never clips) |
| `animated/smoke_puff.png` | 44x44 | 12 | 3.6 | mix | - | centre |
| `animated/tree_apple_sway.png` | 68x62 | 16 | 8 | mix | tree_apple | bottom-centre (same anchor as props/tree_apple.png; frame is 10px (1x) wider on each side so the canopy never clips) |
| `animated/tree_autumn_a_sway.png` | 78x80 | 16 | 8 | mix | tree_autumn_a | bottom-centre (same anchor as props/tree_autumn_a.png; frame is 10px (1x) wider on each side so the canopy never clips) |
| `animated/tree_autumn_b_sway.png` | 78x72 | 16 | 8 | mix | tree_autumn_b | bottom-centre (same anchor as props/tree_autumn_b.png; frame is 10px (1x) wider on each side so the canopy never clips) |
| `animated/tree_birch_sway.png` | 66x92 | 16 | 8 | mix | tree_birch | bottom-centre (same anchor as props/tree_birch.png; frame is 10px (1x) wider on each side so the canopy never clips) |
| `animated/tree_chestnut_sway.png` | 88x101 | 16 | 8 | mix | tree_chestnut | bottom-centre (same anchor as props/tree_chestnut.png; frame is 10px (1x) wider on each side so the canopy never clips) |
| `animated/tree_cluster_2x2_a_sway.png` | 138x114 | 16 | 8 | mix | tree_cluster_2x2_a | bottom-centre (same anchor as props/tree_cluster_2x2_a.png; frame is 8px (1x) wider on each side so the canopy never clips) |
| `animated/tree_cluster_2x2_b_sway.png` | 130x129 | 16 | 8 | mix | tree_cluster_2x2_b | bottom-centre (same anchor as props/tree_cluster_2x2_b.png; frame is 8px (1x) wider on each side so the canopy never clips) |
| `animated/tree_cluster_2x2_c_sway.png` | 128x133 | 16 | 8 | mix | tree_cluster_2x2_c | bottom-centre (same anchor as props/tree_cluster_2x2_c.png; frame is 8px (1x) wider on each side so the canopy never clips) |
| `animated/tree_cluster_2x2_d_sway.png` | 140x108 | 16 | 8 | mix | tree_cluster_2x2_d | bottom-centre (same anchor as props/tree_cluster_2x2_d.png; frame is 8px (1x) wider on each side so the canopy never clips) |
| `animated/tree_golden_oak_sway.png` | 96x76 | 16 | 8 | mix | tree_golden_oak | bottom-centre (same anchor as props/tree_golden_oak.png; frame is 10px (1x) wider on each side so the canopy never clips) |
| `animated/tree_golden_oak_v2_sway.png` | 92x70 | 16 | 8 | mix | tree_golden_oak_v2 | bottom-centre (same anchor as props/tree_golden_oak_v2.png; frame is 10px (1x) wider on each side so the canopy never clips) |
| `animated/tree_great_oak_sway.png` | 126x147 | 16 | 8 | mix | tree_great_oak | bottom-centre (same anchor as props/tree_great_oak.png; frame is 10px (1x) wider on each side so the canopy never clips) |
| `animated/tree_oak_a_sway.png` | 74x80 | 16 | 8 | mix | tree_oak_a | bottom-centre (same anchor as props/tree_oak_a.png; frame is 10px (1x) wider on each side so the canopy never clips) |
| `animated/tree_oak_b_sway.png` | 86x73 | 16 | 8 | mix | tree_oak_b | bottom-centre (same anchor as props/tree_oak_b.png; frame is 10px (1x) wider on each side so the canopy never clips) |
| `animated/tree_pine_sway.png` | 74x89 | 16 | 8 | mix | tree_pine | bottom-centre (same anchor as props/tree_pine.png; frame is 10px (1x) wider on each side so the canopy never clips) |
| `animated/tree_poplar_sway.png` | 58x108 | 16 | 8 | mix | tree_poplar | bottom-centre (same anchor as props/tree_poplar.png; frame is 10px (1x) wider on each side so the canopy never clips) |
| `animated/tree_poplar_v2_sway.png` | 58x96 | 16 | 8 | mix | tree_poplar_v2 | bottom-centre (same anchor as props/tree_poplar_v2.png; frame is 10px (1x) wider on each side so the canopy never clips) |
| `animated/tree_sway.png` | 74x80 | 16 | 8 | mix | tree | bottom-centre (same anchor as props/tree.png; frame is 10px (1x) wider on each side so the canopy never clips) |
| `animated/tree_willow_sway.png` | 104x81 | 16 | 8 | mix | tree_willow | bottom-centre (same anchor as props/tree_willow.png; frame is 12px (1x) wider on each side so the canopy never clips) |
| `animated/tuft_a_sway.png` | 40x28 | 16 | 8 | mix | tuft_a | bottom-centre (same anchor as props/tuft_a.png; frame is 6px (1x) wider on each side so the canopy never clips) |
| `animated/tuft_b_sway.png` | 32x28 | 16 | 8 | mix | tuft_b | bottom-centre (same anchor as props/tuft_b.png; frame is 6px (1x) wider on each side so the canopy never clips) |
| `animated/watermill_wheel.png` | 136x111 | 8 | 21.6 | mix | watermill_2x2_body | identical canvas + bottom-centre anchor to props/watermill_2x2_body.png: place as a child at offset (0,0) and draw above it |
| `animated/windmill_sails.png` | 140x140 | 16 | 14.4 | mix | windmill_2x2_body | frame centre = sail hub; place the frame centre at (0,-104) px (1x) from the windmill_2x2_body bottom-centre anchor ((0,-208) at 2x), draw above the body |

### Water ripple flipbooks (44 sheets)
`water/<tile id>_ripple.png`: one per shipped water tile (water_a..., water_deep_*, shore/bank/edge/corner pieces). Each one is 8 frames at 64x32, 7.2 fps, anchored like the floor tile.
The ripple field is periodic on the iso lattice, so neighbouring tiles stay seamless **as long as all water tiles share one clock**: frame = int(time * 8) % 8. Only the water-coloured pixels move; foam, sand and bank pixels stay static.

### Sway masks
`sway_masks/<prop>_swaymask.png` (+ `_2x/`): 8-bit greyscale, same canvas as the matching `*_sway` frames (the static sprite padded by the sway margin on the left and right). 0 = pinned (trunk, base), 255 = full swing (canopy top). Use these with a shader on the **static** sprite instead of the flipbook if you'd rather not ship frames.

## Godot wiring (suggestions)

* **Sway (trees, bushes, reeds, tall grass)**: swap the static `Sprite2D` for an `AnimatedSprite2D` with a `SpriteFrames` built from the `_sway` strip (Atlas regions, 8 fps, loop). The frame is wider by the sway pad but has the same bottom-centre anchor, so `offset`/`centered` stay the same. Randomise `frame` and `speed_scale` (0.85 to 1.15) per instance so a forest never moves in lockstep.
  Shader option (static sprite plus mask, no frames):
  ```glsl
  shader_type canvas_item;
  uniform sampler2D sway_mask;
  uniform float amp_px = 4.0;      // canopy bend at 1x (v4.1: trees 4, willow 5, bushes 2, tall grass/reeds 3.5-4.5)
  uniform float speed = 1.3;       // rad/s
  uniform float phase = 0.0;       // set a random value per instance
  uniform float gust_speed = 0.3;
  uniform float global_x = 0.0;  // travelling gust: brighten amplitude in a band that sweeps across the screen
  void fragment() {
    float w = texture(sway_mask, UV).r;
    float ph = TIME * speed + phase;
    float gust = 0.7 + pow(max(0.0, sin(6.2832 * (TIME * gust_speed - global_x / 1500.0))), 2.0); // global_x: pass the node's screen x as a uniform
    float dx = sin(ph - 1.1 * w) * amp_px * gust * pow(w, 1.15);
    vec2 uv = UV - vec2(dx * TEXTURE_PIXEL_SIZE.x, (0.18 * abs(dx) * w) * TEXTURE_PIXEL_SIZE.y);
    COLOR = texture(TEXTURE, uv);
  }
  ```
  (the sprite needs the padded canvas, so use the frame-0 size of the `_sway` strip for the static texture when going this route)
* **Water**: on the floor `TileMap`/`TileMapLayer`, use the TileSet's tile animation (columns = 8, `animation_speed` = 7.2 fps (any rate works in-game; 7.2 just makes the 10 s preview loop), `animation_mode` = default, **not** random start) for every water tile, so all tiles share a clock. Alternatively, keep the static tiles and drive a small UV-scroll shader. The flipbooks were made so the TileSet route needs no code.
* **Windmill**: place `windmill_2x2_body` as the static sprite, then add a child `AnimatedSprite2D` (`windmill_sails`, 14.4 fps = one full turn every ~4.4 s) whose centre sits at **(0, -104) px at 1x** from the body's bottom-centre anchor (that's the hub). Draw it above the body (`z_index` +1 or child order).
* **Watermill / fountain**: `watermill_wheel` and `fountain_water` use the **same canvas and anchor** as `watermill_2x2_body` and `fountain_2x2`. Add them as a child `AnimatedSprite2D` at offset (0,0), drawn above the body.
* **Fire**: put `fire_small` (12 fps) on braziers, with its base at (0,-49) px at 1x from the brazier anchor. For the smithy forge mouth, use (21,-24) px at about 0.55 scale. Add a `PointLight2D` or the existing additive `lamp_glow` with a 0.9 to 1.1 flicker on `energy`.
* **Embers / smoke / leaves / fireflies**: use `GPUParticles2D` (or CPUParticles2D) with the strip as the texture and a `CanvasItemMaterial` with `particles_animation = true`, `h_frames` = frame count. Smoke (v4.1, thick): emit every 0.67 s, lifetime 3.3 s (5 alive per chimney), rise about 17 px/s at 1x, +x drift about 6 px/s, sideways wobble 2-3 px, scale 1.0 to 1.35 on top of the strip's own growth. Chimney emitter offsets are in the README section below. Embers: additive material, 8 alive per fire, lifetime about 1.4 s, rise 25 to 35 px/s at 1x with sideways wobble, fade with age. Flames: `fire_small` at about 0.72 scale on braziers, plus a radial glow whose alpha flickers 0.22 to 0.46. Leaves: one tumbling leaf per canopy every ~3.3 s, falling from about 70% of the tree height to the ground in ~2.7 s with a ±10 px sinusoidal swing, then resting and fading for ~0.7 s.
* **Critters**: `AnimatedSprite2D` plus a tiny `PathFollow2D` or a wander script. Chickens: walk about 0.9 cell in 3 s, peck 2 s, walk back, peck. Cats: stroll 2 cells in 4 s, sit 1 s, return. Butterflies: draw at about 1.5x, wander about ±30 px at 1x, 13 px above the ground with a faint shadow. Birds: straight passes from off-screen to off-screen (spawn and despawn outside the viewport so nothing pops), about 130 px/s at 1x, drawn at 1.6x, high `z_index`, with `bird_shadow` on the ground layer offset about (+45,+115) px at 1x. Y-sort ground critters with props (put them in the same `y_sort_enabled` parent). Their origin is the bottom-centre feet point.
* **Cloud shadows**: a full-screen `ColorRect` or a world-space `Sprite2D` with `cloud_shadow_a/b` set to repeat. Scroll the UV in a shader at about 50 to 80 px/s at 1x (v4.1: clearly drifting), multiply over the world (alpha at most 0.3 already baked), with two layers at different scales and speeds.

## Emitter offsets (1x px from the prop bottom-centre anchor; double them at 2x)

| prop | chimney / flue |
|---|---|
| red_roof_cottage, cottage_* | (21,-98) |
| red_roof_cottage_b | (19,-104) |
| cottage_*_b | (19,-102) |
| farmhouse_2x2 | (16,-90) |
| red_roof_cottage_3x2 | (-22,-131) |
| red_roof_cottage_3x3 | (32,-152) |
| tavern_3x2 | (-29,-150) |
| bakery_2x2 | (21,-100) |
| smithy_2x2 | chimney (14,-108), forge hood flue (29,-74), forge mouth fire (21,-24) |
| brazier | fire base (0,-49) |
| windmill_2x2_body | sail hub (0,-104) |

## v5 additions (PROPOSED)

### Shadows that sway with the trees
`animated/shadows/<prop>_shadow_sway.png` (+ `_2x/`), one strip per `<prop>_sway` (25 trees and bushes). Frame *i* is the cast shadow of sway frame *i*, using the same light as the baked shadows (shear 0.62, squash 0.30, 2.2 px soft, colour `#1a223c`). Each strip has the same frame count and fps as its sway strip. **Play both from the same clock and frame index.** Draw the strip on the ground/shadow layer instead of the static baked shadow.
- **Shader route (no strip):** offset the static shadow sprite UVs with the canopy displacement used for the sway mask. Multiply by the shadow shear (x += 0.62·dy) and squash the displacement by 0.30.

### Windmill
- **Strip option:** `windmill_sails_v5` has 48 frames over 90° (the 4 sails are symmetric) at 43.2 fps, which gives one turn every 4.44 s.
- **Smooth option:** `windmill_sails_flat` is one sprite at 0°. In a canvas_item shader:
  `uv -= 0.5; uv.y /= 0.9; uv = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * uv; uv.y *= 0.9; uv += 0.5;` with `a = TAU*TIME/4.44`.
- The hub sits at (0,-104) px at 1x from the `windmill_2x2_body` anchor.

### Watermill
- **Layer order:** `watermill_2x2_body`, then `watermill_wheel_v5` (16 frames / 30°, 27.2 fps), then `watermill_splash` (12 frames, 13.2 fps). All three share one canvas and anchor.
- **Placement:** the wheel hangs over the +x neighbour cell. Place the mill so cells (ax+1, ay) and (ax+1, ay-1) are water.

### Butterflies
`butterfly_{yellow,pink,blue,orange}_lg`: 30x24 frames, 6-frame flap at 18 fps. Draw at 1.0-1.2x. The mocks use 18 in Southbridge and 12 in other zones.

### Farm crop families (visual variants of golden_plains)
- **Families:** `farm_carrot`, `farm_sunflower`, `farm_lavender`, `farm_plowed`, `farm_fallow`.
- **Autotile rule:** same as the v2 farm families.
  - `_a`/`_b` interior fill, alternating by (x+y)%2.
  - `_edge_<sides>` names the open (non-farm) sides with the iso tokens `nw`, `ne`, `se`, `sw` joined by `_` in that order (e.g. `farm_carrot_edge_nw_ne`; 15 pieces).
  - `_corner_<c>` covers inner diagonal-only gaps.
- **Height:** add `sunflowers_tall` / `_b` props on about 30% of sunflower cells.
- **Orchards:** `tree_apple` grid on golden_plains plus `crate_apples`.
- **Fences:** `farm_fence_corner_{n,e,s,w}` / `fence_wood_corner_{n,e,s,w}` close L-corners. Arm directions: n = +x,+y; e = -x,+y; s = -x,-y; w = +x,-y.

### Paving
- **`dirt_road_flagstone_m{i}{j}`:** a 3x3 macro pattern. Use i = x%3 and j = y%3, so stones run across cell borders and the repeat is 3 cells. `_moss` variants are picked by low-frequency noise.
- **`grass_lip_<sides>` / `grass_lip_corner_<c>`:** alpha decals drawn over paving at grass borders.
- **`grass_lip_diag_<n|e|s|w>`:** fills the half-cell notch on 45-degree stepped edges so they read straight. This is visual only; zone cells stay as they are.

### Surface textures (baked into the building sprites)
Roofs, walls, timber, docks, fences, carts and stone faces carry the Scenario textures in `art/pc/crosshaven_world/scenario/` (box only), projected per face. No runtime work is needed; file names, sizes and anchors are unchanged.

## v6 additions (PROPOSED)

- **`watermill_wheel_v6`** (16 frames, 27.2 fps) and **`watermill_splash_v6`** (12 frames, 13.2 fps)
  - Same 136x111 canvas and bottom-centre anchor as `props/watermill_2x2_body.png`. Add both as children at offset (0,0), in the order body, wheel_v6, splash_v6.
  - The wheel has a double rim, bucket paddles and an iron hub. It also carries the plank trough on its A-frame trestle.
  - The splash has crisp, discrete bubbles, downstream streaks, a thin ripple, the trough water sheet and the pour onto the wheel.
  - They replace `watermill_wheel_v5` / `watermill_splash`; those older strips are still in the package.
- **v6 decals** (`decal_road_ruts_*`, `decal_puddle_*`, `decal_road_stones`, `decal_road_grass`) go on the non-blocking ground decor layer. `decal_water_deep` and `canal_*` sit over water cells, under the water ripples.
- **Retextured props** (`v6_textured` in `atlas_meta.json`): the files are re-rendered with the same ids, sizes and anchors, so no rewiring is needed.
- **Out-of-bounds haze:** see `v2/HANDOFF_v6.md` section 5.
