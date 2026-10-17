# Crosshaven walled city: Mauro's look target (16 Oct 2026)

**GOAL:** `mauro_target_crosshaven.jpg` (Mauro, 16 Oct: "esto sería nuestro goal").. Mauro: "esto es como me gustaría que se viera". This is how the city should look.

**PROTOTYPE** (Mauro: "supongamos que este es nuestro prototipo"): the box-only `cx_built` build by Luca's team, which uses the same layout idea with flat tile-kit art. It goes up in the `docs/pc-map-handoff` PR. Mauro: "la foto que te mandé es donde nos quedamos".

What the target has that the current build does not:

**Walls and gate**
- Thick stone walls with round towers and red conical roofs.
- A gatehouse on the river side.

**Landmarks**
- A castle on the north wall, blue slate roofs.
- A gothic cathedral at the centre.
- A domed civic hall or bank.
- A blue-roofed manor or guild hall.

**Districts**
- An industrial and forge quarter in the west, with chimneys and smoke, warehouses and timber.
- A garden quarter in the east: canals, small bridges, round flower beds, a gazebo, a fountain, blossom trees.
- Dense residential blocks of red-roof timber houses, each with its own garden plot.

**Streets, water and surroundings**
- Organic cobbled streets that radiate from the cathedral.
- A river with rapids, rocks and a boat outside the walls.
- Canals inside the walls.
- Thick forest around the walls and snowy hills in the north-east, which link to Northgate and Windmere.

**Overall look**
- Painted, saturated and detailed, with soft shadows: everything is hand-painted, with no visible tile grid.

## Luca's rules for Crosshaven (via Scenario Art, #252, 16 Oct 2026)

Where the target image breaks these rules, the rule wins:

- **No yards (a):** no gardens, fences, hedged plots or dirt yards. Houses stand on grass with plants. The target's south houses with fenced plots break this rule.
- **No bare earth or street props (b):** no bare earth, and no carts, crates or timber in the middle of the street. The target's forge quarter yards and lane props break this rule.
- **Plazas off the streets (c):** plazas sit inside the wall in open space, never on a street junction. The target's cathedral plaza and fountain circle break this rule.
- **Allowed:** the east garden-quarter park, and houses on grass with plants.
- **Not allowed:** farms and farm animals.
- **Also applies:** day and night NPC life, and see-through fade on every obstacle.

## What `cx_built` is

- `cx_built` is **one painted plate** (5120×2880) from the Rosebud prototype. It has no cell grid and no chunks.
- **Files:**
  - `ground.jpg`, `plate.jpg`;
  - `layers.json` (400 sprite layers with x, y, sort_y and fade) and `layers/`;
  - `walkmask.png`, `heightmap.png`, `river.png`, `bridge_h_*.png`;
  - `zones*.json`, `route*.json`, `bridge_joins.json`, `build_info.json`;
  - `housing_tiers/`.
- **It is not in Godot yet.** Building Crosshaven means bringing this into the game's iso cell world: walkable cells, y-sorted sprites and fades.
- **Open (Luca):** whether it replaces the Crossroads plaza, and where the 5 towns and the dungeon doors go.

## Player houses (Mauro, 16 Oct 2026)

- Player houses come in rarity tiers: **Normal, Rare and Legendary** ("van de normales, raras a legendarias").
- Rooms follow **Luca's rule** (Mauro confirmed, 16 Oct): Normal = bedroom only; Rare = bedroom, living room and kitchen; Legendary = all 5 (adding the cellar, which is the crafting workshop, and the garden). Upgrades happen in place by paying the difference. Each room has its decorations. Gardens are not allowed inside Crosshaven.
- Crafting workshops by tier (Luca, 16 Oct): Normal = 1 workshop; Rare = 2 workshops; Legendary = all workshops (corrected by Luca, 16 Oct).
- Exterior tiers are swapped in place on the same plot anchor, with clearance 200 / 260 / 350 px.
- The tier art and plots come from Luca's `housing_tiers/` and the 5 plot houses in `cx_built`, requested on #252.
- The city layout must leave room for the plot houses.

### The 5 player plots in the prototype (`player_plots_p1_p5.jpg`, from Mauro, 16 Oct)

The plots sit in the south-east of `cx_built`, along the south wall, between the east road and the river.

**Key:** red box = footprint; yellow ellipse = base and clearance; magenta dot = anchor and entrance (bottom centre).

| Plot | House tier | Garden tier |
|---|---|---|
| P1 | Rare | Rare |
| P2 | Legendary (walled manor) | Legendary |
| P3 | Rare | Normal |
| P4 | Normal | Rare |
| P5 | Normal | Normal |

**MUST FIX in the build** (Mauro: "hay que arreglar todo eso"):
- P3, P4 and P5 sit tight against the wall, and P3's anchor touches a tower. The game needs walkable entrance cells in front of every anchor, plus room for a house to grow to Legendary (350 px clearance) without hitting the wall.
- "Garden" here is a tier label only. Per Luca's rule there are no garden beds inside Crosshaven.
- **Acceptance for the plots:**
  - every anchor has at least 2 walkable cells in front, reachable from a street;
  - a Legendary footprint (350 px clearance) fits on every plot without touching the wall, a tower, a street or another plot;
  - there are no garden beds;
  - P3 is moved off the tower.
  - A test checks all of this.

## Mauro's change list for the city base (16–17 Oct 2026)

Reviewed on the base without buildings (`cxbase/base_walls.jpg`).

1. **Gates where roads cross the wall** ("nos falta puerta ahí"). The west road and the east road pass straight through the wall with no gate; only the south gate exists. Every road that leaves the city gets a proper gatehouse matching the south gate, with its walkable passage.
2. **A north gate** in the north wall (Mauro: "otra puerta"), where the northern streets end short of the wall. Extend the street to it, with a road out toward Northgate and the snowy north. It matches the other gates.
3. **Another gate on a diagonal wall** (Mauro: "otra puerta"). The road meets a diagonal wall section with no gate. This is most likely the long road from the south gate running east, which ends at the south-east wall. **General rule:** every place where a street or road touches the wall gets a gate, or the street is pulled back. Find all of them programmatically and list them.
4. **Remove the wall stubs sticking out at the towers** (Mauro: "hay que eliminar este muro saliendo"). That is the short wall piece that juts out from the base of a tower, outside the wall line. Remove it at every tower where it appears, and close the wall cleanly into the tower.
5. **Beautification pass, after the structural fixes** (Mauro: "después de ahí, puro embellecimiento de cómo se ve el zacate y el camino, los muros, los árboles"). Match the GOAL:
   - **Grass:** painted, varied lawn with tufts, colour patches, small flowers and soft shading; no flat repeating fill.
   - **Streets:** sand-coloured cobblestone with worn edges and a soft border into the grass.
   - **Walls:** thick stone with a walkway on top, real crenellations, a stone footing with a contact shadow, tonal variation, moss and buttresses. Towers and gates match.
   - **Trees:** a varied painted set (oaks, cypresses, blossom trees), clustered naturally.
   - **Tools:** Meshy for the wall segment, tower and gate (3D, then iso render, then a Scenario paint-over), and Scenario for the tiling grass and cobble textures and the trees.
6. **Bushes and flowers** (Mauro: "agrega arbustos, flores"). Scatter painted bushes and flower clumps over the grass, along street edges, around plazas and at the foot of the walls, as in the GOAL. They are loose plants on grass, which Luca's rules allow; no fenced beds. They are y-sorted props, small ones walkable-through, bigger bushes blocking.
7. **Fewer trees, bigger city** (Mauro: "siento que hay muchos árboles y no tendremos suficiente espacio para los edificios; quizá debemos agrandar el mapa más"):
   - Cut the prototype's 95 trees down to a few clusters: the park, the wall feet and a few street trees.
   - Enlarge the walled city about 1.5× (plate about 7680×4320): the wall ring moves outward, the streets and river lengthen, and there is room for all the buildings, the districts and the 5 player plots.
   - Placeholder pieces are re-laid on the bigger plate before the beautification goes on.
8. **Character to building scale** (Mauro, 17 Oct: "me gustaría que al menos la dimensión de los personajes se vea algo así"). The reference is `mauro_scale_reference.mp4` (🖼️ a Rosebud prototype tour, not the game). The characters are small next to the city:
   - a normal house is about **3×** the hero's height;
   - a gate tower is about **4–5×**;
   - a market stall is about **1.5–2×**;
   - a street is about **3–4 hero-heights** wide.

   The city plate, sprites and buildings must be scaled so the game's hero (about 156 px at 1080p at the default zoom) keeps these ratios. This works together with item 7 (enlarge the city): the city is bigger in world space, so it takes longer to walk across.
9. **Water motion approved as a target** (Mauro: "me gusta cómo se mueve el agua"). The reference is `mauro_water_reference.mp4` (🖼️ a Rosebud prototype). It shows the river flowing along its course, with soft moving ripples, and white foam churning where the river passes under the wall arch (the water gate). Rebuild it in Godot from the package's `rosebud/water/` (`water_base.png`, `water_ripple_tile.png`, `foam_zone.png`, `water.json`) as a canvas shader:
   - the ripples scroll along the flow direction;
   - the foam animates in the foam zones;
   - Performance mode uses a slower or static fallback.
10. **Castle = Grok Bot's palace** (Mauro: "me gusta más el castillo de Grok"). Keep the `cx_built` palace sprite (`000_cx_palace.png`) as the city's castle, in the prototype's north position. The Meshy castle is dropped, along with its paint-over.
11. **House = Grok Bot's house** (Mauro: "la casa me gusta más de Grok"). Keep the `cx_built` house sprites; the Meshy house is dropped. Rule from items 10 and 11: **Grok Bot's painted sprites are preferred.** Meshy is used only where nothing painted exists, or as an angle and proportion guide for Grok Bot.
