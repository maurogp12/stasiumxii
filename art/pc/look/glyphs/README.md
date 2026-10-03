# Deploy glyph decals (placeholders)

Code-painted stand-ins for reference A.7. Purple and translucent. Scenario Art replaces the pixels. Keep the file names, the canvas sizes, and the straight-alpha import.

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
