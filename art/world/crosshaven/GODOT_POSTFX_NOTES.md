# Godot post-processing notes for Crosshaven (v4, SUGGESTIONS ONLY)

These notes describe how to get the golden-hour look of the v4 mock renders (`mock/v4_*`) at runtime. They are not wired anywhere and nothing in the project was changed. The values are the ones the mock renderer (`v2/tools/cw_alive_v4.py`, `grade()`) uses, so the two should match by eye.

## 1. WorldEnvironment glow (bloom on highlights)
Requires the Forward+ or Mobile renderer. 2D glow needs `Environment.background_mode = BG_CANVAS`.
```
WorldEnvironment
  environment = Environment
    background_mode = Canvas            # needed for 2D glow
    glow_enabled = true
    glow_normalized = false
    glow_levels/1 = 0.0, /2 = 1.0, /3 = 1.0, /4 = 0.6, /5 = 0.0   # soft, mid-radius bloom (mock: blur sigma ~5 px at quarter res)
    glow_intensity = 0.6
    glow_strength = 1.0
    glow_bloom = 0.0
    glow_blend_mode = Softlight         # or Additive at ~0.3 intensity; Softlight keeps the painted look
    glow_hdr_threshold = 0.85           # only lamp/fire/sun-lit plaster and water glints bloom (mock threshold: luminance > 0.74 in sRGB)
    glow_hdr_scale = 2.0
```
* To make fire, embers, forge mouths and lamp glows bloom harder than plaster, give them a `CanvasItemMaterial` with `blend_mode = Add`, or set their `modulate` above 1.0 (e.g. `Color(1.4,1.2,1.0)`), which pushes them over the HDR threshold. This needs `rendering/viewport/hdr_2d = true` (Godot 4.2+).
* Keep `glow_intensity` low. In the mock, bloom contributes about 30% of the over-threshold colour, not a haze over everything.

## 2. Colour grading (LUT)
Use `Environment.adjustment_enabled = true` with `adjustment_color_correction = <3D LUT texture>` (Godot 4.x accepts a `Texture3D` or a 2D strip LUT imported as 3D).
* Bake the LUT from the mock grade so engine and mock match. Run the identity LUT strip (e.g. 32 or 64 cubed) through `grade()` without the bloom, haze and vignette steps. The curve is:
  * warm white balance: R x1.05, G x1.00, B x0.90
  * saturation +12%
  * golden highlights: + (0.055, 0.035, 0) x smoothstep over luminance 0.55 to 0.95
  * cool shadows: + (-0.012, 0, 0.03) below luminance about 0.45
  * gentle contrast: 0.5 + (c - 0.5) x 1.05
* If you'd rather avoid a LUT asset: `adjustment_brightness = 1.0`, `adjustment_contrast = 1.05`, `adjustment_saturation = 1.12`, plus a `CanvasModulate` of about `Color(1.0, 0.97, 0.90)` for the warm cast. That's close, but highlights and shadows won't split warm and cool.
* Day/night: lerp `CanvasModulate` toward `Color(0.55,0.62,0.85)` at dusk, and fade in `lamp_glow`, `firefly` and window light. The LUT can stay.

## 3. Canvas vignette + far-edge depth haze
A full-screen `ColorRect` on a top `CanvasLayer` (layer 100, `mouse_filter = Ignore`) with this shader:
```glsl
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float vignette = 0.24;          // mock: 24% darkening at the corners
uniform float vig_start = 0.62;
uniform float haze = 0.17;              // mock: 17% at the very top, fading out by 42% of the screen height
uniform vec3 haze_col = vec3(0.95, 0.90, 0.80);
void fragment() {
  vec3 c = texture(screen_tex, SCREEN_UV).rgb;
  float t = pow(clamp(1.0 - SCREEN_UV.y / 0.42, 0.0, 1.0), 1.6);   // iso: top of screen = far
  c = mix(c, haze_col, haze * t);
  vec2 p = SCREEN_UV * 2.0 - 1.0;
  float r = sqrt(p.x * p.x * 0.8 + p.y * p.y);
  c *= 1.0 - vignette * pow(clamp((r - vig_start) / 0.6, 0.0, 1.0), 1.5);
  COLOR = vec4(c, 1.0);
}
```
* The haze is screen-space, so it always sits on the far (top) edge, which is what iso needs. For true world-depth haze, drive `t` from the world y of a camera-relative gradient instead.
* Keep the UI on a CanvasLayer above this one so menus aren't vignetted.

## 4. Cast shadows (top-left key light)
The mock bakes a cool, sheared drop shadow per prop (`shear x = 0.62 * height, squash y = 0.30 * height`, colour `#1a223c`, alpha about 0.30, blur 2 px at 1x). Runtime options:
* Cheapest: a child `Sprite2D` with the same texture, `modulate = Color(0.10,0.13,0.24,0.30)`, `skew` about -0.55 rad, `scale.y` about -0.30 (flipped and squashed), `z_index` below the prop, and its offset pivoted at the footprint centre.
* Nicer: a shared shadow `SubViewport` pass that draws every prop silhouette into one buffer (so overlapping shadows don't double-darken), blurs it, then multiplies it over the ground layer.
* Avoid real `LightOccluder2D` shadows for this style. They are hard-edged and cost per light.

## 5. Cloud shadows
A world-space parallax `Sprite2D` with `animated/cloud_shadow_a.png` and `_b.png` (repeat enabled, `region` larger than the screen), `texture_filter = linear`, and the UV scrolled in a shader (`UV + TIME * vec2(0.010, -0.0035)`). Use multiply-like blending: the texture is already a dark cool colour at 30% alpha or less, so normal blend works. Layer a at scale 3.2, layer b at 2.2 and slower.

## 6. Order of passes (matches the mock)
ground tiles -> ground decals -> shadows -> y-sorted props + critters -> overlays (sails, wheel, fountain) -> fx (fire, embers, smoke, leaves, butterflies, birds) -> cloud shadows -> WorldEnvironment glow + LUT -> haze + vignette CanvasLayer -> UI.

## v7 note (painterly repaint)
The v7 textures already carry the top-left warm key light and cool shade, so keep the runtime grade gentle: the section 2 LUT and
section 1 glow still apply, but drop saturation to about +6% (v7 grass is already Wakfu-saturated) and keep glow_hdr_threshold >= 0.85 so
only the v7 window glow, lamp heads, fire and water sparkles bloom. Optional: draw `decal_v7_lamp_glow` with `CanvasItemMaterial.blend_mode
= Add` under lamps / lit windows at dusk and night, and `decal_v7_shade_pool_*` (mix) on the bottom-right side of big trees and buildings.
