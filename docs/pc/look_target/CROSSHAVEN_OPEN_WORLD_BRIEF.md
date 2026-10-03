# STASIUM XII — Bot brief: open-world map, Crosshaven look

Status: Proposed art direction. Not a combat lock. Not a level lock.
Look target: the painted Crosshaven plate (island, districts, cliffs, red roofs, pale roads).
Do not copy the dark isometric region-diorama sheet unless the ask says "region chunk."
Names and levels on the v6 concept overview are not final. Match the paint. Do not invent levels.

Paste this whole file above the task. Attach the Crosshaven painting every time.

---

## 1. What "open world" means here

One continuous landmass the player can walk. Not nine separate postcards.

- Crosshaven is the safe core: a cliff island, or a cliff-edged peninsula if the shot cannot show the whole coast.
- Districts connect by the same pale dirt-and-stone road net. No loading-card gaps. No black voids between towns.
- Sea is around the cliffs. Docks and boats sit on the water. Water is a real edge, not a texture under the town.
- Fields sit between districts. Orchards, pasture, low walls, a mill, a bridge. Empty paint is still walkable land.
- Outer wilds, if asked, continue off the same coast and the same roads. They get dimmer and rougher. They do not become a second art style.
- Camera stays the Crosshaven camera for the whole map: high painted oblique, storybook atlas, soft daylight. Not tactical iso tiles. Not a satellite photo. Not a dark UI diagram.

Party on the map is 1–4. Do not draw an army. Do not draw a HUD.

---

## 2. Look lock — match the Crosshaven plate

Study the painting before generating. If a choice fights the plate, the plate wins.

Shape

- Cliff coast: pale rock faces, green caps, sea cutting in at coves.
- Towns are clusters, not a megacity. Red-brown tile roofs, stone walls, one tower or spire per district.
- Roads are pale, branching, worn into the grass. They meet at gates and bridges.
- Center of the island is open ground and roads, not a downtown.
- Decorative title may appear only on an atlas plate. In-game open world has no giant "CROSSHAVEN" letters on the land.

Color

- Grass: yellow-green and hay gold. Bright. Not mud-brown. Not neon.
- Roofs: terracotta and dull red.
- Stone: warm gray, cliff white, dark roof-slate on towers.
- Sea: clear blue, white breakers on the rocks, a few small sails.
- Light: soft painted day. One broken-hour fact only: a banner mid-fold, a wave that has not fallen, dust held over a road. No glitch. No fog-as-night unless the ask is the outer wilds.

Material

- Painted gouache / storybook map. Visible brush, soft edges, readable roofs.
- Not pixel art. Not photoreal. Not PBR. Not the tiny iso sprites from the v6 chunk sheet.
- No neon, no hologram streets, no guns, no megacity, no metal grating.

District read, from the plate (labels are look anchors, not a lock that they are the only names)

- Northgate — north cluster, spire, roads in from the top cliffs.
- Stoneford — west, tower over a smaller roof cluster.
- Westwatch — southwest, tower and a walled yard.
- Southbridge — south, spire where roads cross toward the bottom coast.
- Eastmarch — east, tower above roofs, roads to the east cliffs.
- Larger roof mass on the southeast is a town, not a castle-tech fortress. Stone, tile, timber.

If the director has not locked these names, paint the places and leave labels off the in-game ground.

---

## 3. How to build it so bots do not flatten it

Order:

1. Coast silhouette. Black cliff blob, sea around it. If the blob is a square, redo.
2. Road net. Five pale branches from an open center to five districts. One road reaches a dock.
3. District masses. Each mass is roofs plus one vertical tower. Towers must not match.
4. Fields in the gaps. Different greens. A bridge only where a road crosses a cut.
5. Sea traffic. Two or three small boats. White water on rocks.
6. Then paint. Then one broken-hour detail.

Open-world test: trace a walk from Westwatch to Eastmarch without leaving a road or a field. If the path hits a void, a UI circle, or a separate diorama, fail.

Scale test: roofs read as roofs when the island is shrunk. Towers still break the outline.

---

## 4. What not to copy from the other image

The v6 "Crosshaven and surrounding regions" sheet is a chunk board on a dark UI field.

Do not use from that sheet unless asked:

- Dark navy background, dashed rings, legend bars, "CONCEPT" captions.
- Separate floating isometric slabs.
- X-shaped town as the only Crosshaven plan. The plate's plan is a cliff island with a road net.
- Pixel-iso trees, blue crystal roofs, lava channels, as the Crosshaven core.
- Level numbers. The sheet says they are not final.

Outer regions may be requested later. They still leave Crosshaven through roads and coast, in this same paint style, then shift material: ash, fen, dock, stone. They do not replace the core look.

---

## 5. Paste-ready prompt

Use this. Attach the Crosshaven painting as the image reference.

Open-world map plate of Crosshaven, same camera and paint as the reference. One continuous cliff island, yellow-green and hay-gold fields, pale dirt roads linking five small towns, red-brown tile roofs, warm gray stone, one different tower per town, southeast town a little larger, open center, coves and white breakers, clear blue sea, two small sailboats, a timber dock, soft daylight, storybook gouache, readable from above, walkable land between towns, one frozen banner over the west road. No labels on the ground, no HUD, no neon, no megacity, no pixel-art diorama, no dark diagram background, no separate floating tiles.

Negative: cyberpunk, hologram, guns, mud filter, photoreal, isometric game-sprite sheet, UI circles, level text, lava in the core, loading gaps, giant title on the terrain.

---

## 6. Return schema

ASK:
LOOK TARGET: Crosshaven plate, not the chunk sheet
WALK PATH: district to district, continuous? yes/no
COAST: cliff blob reads? yes/no
ROOFS / TOWERS: five masses, towers differ? yes/no
PALETTE: hay gold, terracotta, cliff white, sea blue, slate
BANNED CUES AVOIDED:
PROMPT:
DO NOT:
CRITIQUE: 5 lines

Fail if it looks like the dark region diagram. Fail if towns are disconnected slabs. Fail if it is a generic medieval mud village with no cliffs and no road net.
