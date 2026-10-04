# Northgate snow town: look target (Mauro, 4 Oct 2026)

> "As the snow town this is what I'm looking for. Ignore the cars, this is just an example, and it does not need to be dark."

**References**
- `northgate_snow_reference.mp4`: the reference video.
- `northgate_snow_reference_frame.jpg`: a frame from it.
- `northgate_snow_reference_still.jpg`: a close crop.

This replaces "the only one with light snow" for Northgate. Northgate is now a proper snow town. It is **still the only snowy town**; Stoneford, Eastmarch, Southbridge and Westwatch get no snow.

## Take from the reference

- **Ground:**
  - Snow-covered everywhere off the paths, soft and bright, with gentle drifts against walls, fences and tree bases.
  - Paths are swept cobblestone with snow along the edges and in the joints, so the walkable route reads clearly.
- **Houses:**
  - Stone-and-timber cottages with thick, rounded snow caps on every roof, and icicles on some eaves.
  - Chimneys with snow on top, and warm lit windows in amber-orange that read from a distance.
  - Small porches and steps with snow on them.
- **Landmark:** a stone church or chapel with a tall snow-capped spire and a warm doorway. It's the town's tallest building and should be visible from the Crossroads road.
- **Trees:** dense snowy pines (dark green under white-loaded boughs) ringing the town and in small clusters between houses.
- **Props:** lamp posts with a warm glow, wooden fences with snow on the rails, crates and barrels with snow tops, a well or stone shrine, and a covered cart.
- **Edge:** where Northgate meets the cliffs or the sea, a snow-crusted edge with stone showing under it. No bare grass rim. **The north shore is snow, not sand** (Mauro, 4 Oct: "Make the north shore snow instead of sand"): a one-cell snow lip with soft foam and a thin ice rim on the water, thinning into sand where the coast leaves Northgate.
- **Weather:** light falling snow over the town, as a screen-space particle layer that doesn't hide fighters or clickable cells.
- **Light:** **daytime**, not night. Cool blue-white snow with soft lilac-blue shadows, warm windows and lamps as accents, a slightly brighter and cooler grade than the rest of Crosshaven. No dark night sky; the reference's night is only the example.

## Don't take

- The cars, and anything modern.
- The night-time darkness.
- The reference's pixel-art rendering style. Keep the Crosshaven painted kit look and the Wakfu-style camera; match the *content and mood*, not the pixels.

## Where it applies

- **Area:** the `crosshaven_northgate` town square plus about 6 cells of the town edge.
- **Blend:** a 2–3 cell frost blend into the 10–20 band chunks around it, so the snow thins out on the roads and doesn't stop in a straight line.
- **Art:** Scenario Art paints a Northgate snow kit in the v7 kit style (2x masters):
  - snow ground ×3, swept cobble path ×3 with snow edges;
  - snow-capped cottages ×3 with lit windows and chimney emit masks;
  - the chapel landmark (2×2);
  - snowy pine ×3, snowy fence set, lamp post with glow mask, crates and barrels with snow, a cart;
  - a snow cliff edge set.
- **Code:** world zones team.
  - Swap the Northgate kit and add the falling-snow particle layer (view only, capped like the leaf sway).
  - Light the windows and lamps with emit masks.
  - Media for Mauro: before/after at zoom 1.0 and 1.6, and a short walk through the square.
