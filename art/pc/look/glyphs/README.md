# Deploy glyph decals

Painted v2 marks for reference A.7. Purple and translucent, with a thin dark-violet rim (`#3A1F55` at about 0.48) so they read on sand and grass. Keep the file names, the canvas sizes, and the straight-alpha import.

On a zone cell the board draws `glyph_deploy` at modulate alpha 0.20. At 0.55 the overlap on a plain Thunderwell plate still peaks near 0.45, above the move fill at 0.417. Occupied cells draw the ring at full strength.

The board draws `glyph_zone` and `glyph_deploy` together on a `zone_p1` or `zone_p2` cell, and `glyph_occupied` alone on an occupied cell. `@2x` is drawn at half scale, centered on the diamond.

| File | Canvas | What to paint |
|---|---|---|
| `glyph_zone@2x.png` | 64×40 | Zone mark. A painted diagonal X, soft arms about 6px thick, not a 1px stroke. |
| `glyph_zone.png` | 32×20 | The same mark at 1x, a real paint, not a blur of the master. |
| `glyph_deploy@2x.png` | 64×40 | Deploy cell. A painted rounded square outline with a center dot. |
| `glyph_deploy.png` | 32×20 | The same mark at 1x. |
| `glyph_occupied@2x.png` | 64×40 | Occupied ring. A painted ring with a clear hole, not a vector arc. |
| `glyph_occupied.png` | 32×20 | The same ring at 1x. |

Palette, straight alpha:

- Core ink about `#B070E0` (176, 112, 224).
- Soft highlight about `#DCC0F5` (220, 192, 245).
- Peak alpha about 0.62 (zone), 0.58 (deploy outline), 0.70 (deploy dot), 0.62 (ring).
- Edges fade to 0. Transparent texels store RGB 0.

Import: lossless, no mipmaps, no premultiplied alpha. The sprite samples with a linear filter.
