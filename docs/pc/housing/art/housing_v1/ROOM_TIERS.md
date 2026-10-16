# STASIUM XII: Room tiers & placeable furniture, v2 regional (PROPOSED)
Status: **Proposed**. Design doc only, nothing is wired or committed. All numbers, star ratings, boss names and drop names are placeholders for Stasium Bot/Mauro to balance.
v2 (13 Oct 2026, from Luca): materials now depend on the **region where they are gathered**. Rooms and furniture also need **dungeon boss drops (1–5★)** and **open-world boss drops**.

After stage 4 (RECIPES.md) the house has 5 room slots: **Recámara, Cocina, Sala, Sótano, Jardín**. Each one is built in one of 3 tiers. All furniture is crafted by players and placed freely.

## Tier rules (Proposed)
| Tier | Regional materials | Boss drops | Cost scale |
|---|---|---|---|
| Normal | Basic resources (log, planks, stone, bricks, thatch, rope, nails) from the **starter zones**: Crosshaven, Stoneford, Northgate | none | x1 |
| Raro | Rare materials from the **mid regions**: Rowanvale, Windmere, Brinewake, Slagcrown, Fen Edge | **1–3★ dungeon boss** drops | ~x3 |
| Legendario | Rare materials from the **far regions**: Gloomfen Mire, Stormspire, Ashen Shardfields, Blightwood Hollow | **4–5★ dungeon boss** drops + **1 open-world boss** drop | ~x8 |

## Zones used (from repo docs)
Level bands and dungeon names come from the existing WP docs/scripts in `/workspace/stasium-pc-look` (the zone-to-dungeon table).
| Zone | Level | Dungeon (repo) | Notes |
|---|---|---|---|
| Crosshaven | start (hub) | Old Granary Cellar | capital city |
| Stoneford | **assumed 1–5** | – | starter zone; level band not found in the docs |
| Northgate | 5–10 | – | starter; docs pair it with Windmere |
| Rowanvale | 10–15 | Rotting Orchard Barrow | |
| Windmere | 15–20 | Frostspire Archive | "Frost Spire" is its landmark/dungeon, not a separate zone (**assumption**) |
| Brinewake | 20–25 | Saltmaw Grotto | coast/beach |
| Slagcrown | 25–30 | Cinderforge Depths | volcanic/forge |
| Fen Edge (Eastmarch) | 25–30 | Sunken Mill | swamp edge |
| Gloomfen Mire | 30–38 | Drowned Abbey | deep swamp |
| Stormspire | 35–40 | Thunderwell Core | |
| Ashen Shardfields | 38–45 | Shard Hollow | in the docs, but not on Luca's list |
| Blightwood Hollow | 45–50 | Heart of the Blight | dark forest |

## Region resource table (Proposed)
Each region gives its own **wood, stone, fibre/hide** and **one special item**. Each material is made by one of the 16 professions: wood → Lumberjack, stone → Miner, fibre → Tailor, hide → Cobbler. Special items are made by the profession listed in the table.

| Region | Wood (Lumberjack) | Stone (Miner) | Fibre/Hide (Tailor / Cobbler) | Special (profession) | Tier use |
|---|---|---|---|---|---|
| Crosshaven / Stoneford / Northgate | oak log → planks (Carpenter); v2: + Crosshaven pine, Stoneford oak (Proposed) | grey fieldstone; v2: + Stoneford granite (Proposed) | hemp rope (Tailor); v2: + flax fiber, Northgate (Proposed) | clay bricks (Artisan), thatch (Farmer), nails (Blacksmith) | Normal |
| Rowanvale | walnut | river slate | sheep wool (Tailor) | orchard rich soil (Farmer) | Raro |
| Windmere | frost pine | ice marble | snow-hare fur (Cobbler) | frost-glass (Alchemist) | Raro |
| Brinewake | driftwood | coral stone | sailcloth (Tailor) | nacre shell (Fisherman) | Raro |
| Slagcrown | charred ironwood | obsidian | asbestos-wool felt (Tailor) | ember ore (Blacksmith) | Raro |
| Fen Edge | willow | mill sandstone | reed fibre (Tailor) | wild honey wax polish (Baker) | Raro |
| Gloomfen Mire | bog oak | black peat-stone | marsh-gator hide (Cobbler) | peat (Farmer) | Legendario |
| Stormspire | thunder-cedar | storm granite | storm-drake hide (Cobbler) | charged crystal (Jeweler) | Legendario |
| Ashen Shardfields | ash-white birch | shard-glass | ash-silk (Tailor) | shard dust pigment (Alchemist) | Legendario |
| Blightwood Hollow | Blight heartwood | rootstone | shadow-moth silk (Tailor) | cleansed spirit seed (Flower gatherer) | Legendario |

Processed rare goods that are not regional (the other professions' share): **lacquer** (Carpenter, from any rare wood + resin), **glazed tile** (Artisan), **wrought iron** (Blacksmith, ember ore + nails), **velvet** (Tailor, wool + dye), **stained glass** (Alchemist), **gold leaf** (Jeweler), **carved trim** (Carver/Bowyer), **flower garland** (Flower gatherer), **pet bedding** (Pet tamer), **spice crate** (Cook), **fire clay** (Baker). All 16 professions are used.

## Boss drop table (Proposed: star ratings, drop names; world bosses are placeholders)
The dungeon names are from the repo. The boss names are **not in the docs I found**, so each boss is called "<dungeon> boss" (**open question**). Star ratings are my proposal from each dungeon's level band.

| ★ | Dungeon (region) | Boss | Drop (Proposed) | Refined by | Used in |
|---|---|---|---|---|---|
| 1★ | Rotting Orchard Barrow (Rowanvale) | Barrow boss (TBD) | Barrow-root knot | Carver/Bowyer | Raro |
| 1★ | Frostspire Archive (Windmere) | Archive boss (TBD) | Rimebound tome-clasp | Jeweler | Raro |
| 2★ | Saltmaw Grotto (Brinewake) | Grotto boss (TBD) | Saltmaw pearl | Fisherman | Raro |
| 2★ | Sunken Mill (Fen Edge) | Mill boss (TBD) | Drowned millstone shard | Miner | Raro |
| 3★ | Cinderforge Depths (Slagcrown) | Cinderforge boss (TBD) | Cinder heart | Blacksmith | Raro |
| 4★ | Drowned Abbey (Gloomfen Mire) | Abbey boss (TBD) | Abbey bell-bronze | Blacksmith | Legendario |
| 4★ | Thunderwell Core (Stormspire) | Core boss (TBD) | Thunder core | Jeweler | Legendario |
| 4★ | Shard Hollow (Ashen Shardfields) | Hollow boss (TBD) | Prime shard | Alchemist | Legendario |
| 5★ | Heart of the Blight (Blightwood Hollow) | Blight boss (TBD) | Blight heart-gem | Jeweler | Legendario |
| – | Old Granary Cellar (Crosshaven) | tutorial | no housing drop | – | – |

| Open-world boss (**placeholder, Proposed**) | Roams | Drop | Refined by |
|---|---|---|---|
| WB-1 "Tidal Leviathan" | Brinewake coast | Leviathan scale | Fisherman |
| WB-2 "Magma Colossus" | Slagcrown | Colossus ember core | Blacksmith |
| WB-3 "Mire Matriarch" | Gloomfen Mire | Matriarch amber | Alchemist |
| WB-4 "Stormfeather Roc" | Stormspire | Stormfeather down | Tailor |
| WB-5 "Elder Blight Treant" | Blightwood Hollow | Elder bark | Lumberjack |

## Rooms × tiers (Proposed)
> **v2 (13 oct 2026, Luca aprobó mezclar recursos): las recetas vigentes de casa y cuartos están en `costs/COSTS.md` (mismos totales por tier, mismos drops, composición mezclada con varias maderas/piedras/fibras; nuevos materiales iniciales Proposed: Crosshaven pine, Stoneford oak, Stoneford granite, flax fiber). Los números de abajo quedan como v1 histórico.**
Cost = resources + drops. Normal ~100 units, Raro ~300, Legendario ~800.

### 1. Recámara
- **Normal**: oak timber walls, plank floor, small window. **Cost:** planks 40, log 15, nails 30, rope 10, thatch 5.
- **Raro**: walnut panelling, velvet curtains (Rowanvale wool), frost-pine beams. **Cost:** planks 80, nails 60, walnut 40, frost pine 20, velvet 20, wrought iron 15, carved trim 10 + **barrow-root knot ×3 (1★), Saltmaw pearl ×1 (2★)**.
- **Legendario**: Blight-heartwood canopy alcove, shadow-moth silk drapes, gold-leaf ceiling stars. **Cost:** planks 150, nails 120, Blight heartwood 60, thunder-cedar 40, shadow-moth silk 40, gold leaf 25 + **Blight heart-gem ×1 (5★), prime shard ×2 (4★), Stormfeather down ×1 (WB-4)**.

### 2. Cocina (no fireplace; stove/oven are furniture)
- **Normal (A, rustic stone)**: fieldstone walls, plank floor. **Cost:** stone 40, planks 25, bricks 20, nails 15.
- **Raro (B, warm wood)**: driftwood shelves, glazed tile, Slagcrown obsidian hearth slab. **Cost:** stone 60, planks 60, bricks 40, glazed tile 30, obsidian 20, driftwood 20, fire clay 15 + **cinder heart ×1 (3★), drowned millstone shard ×2 (2★)**.
- **Legendario (C, noble red brick)**: vaulted brick, storm-granite work floor, bell-bronze hood niche. **Cost:** bricks 150, stone 100, planks 80, storm granite 60, bog oak 40, glazed tile 80, gold leaf 15 + **abbey bell-bronze ×2 (4★), thunder core ×1 (4★), colossus ember core ×1 (WB-2)**.

### 3. Sala (keeps the fireplace; no staircase)
- **Normal**: brick fireplace, oak beams. **Cost:** planks 35, bricks 25, log 15, nails 25.
- **Raro**: ice-marble mantel, walnut beams, frost-glass windows. **Cost:** planks 70, bricks 50, nails 50, ice marble 25, walnut 30, frost-glass 10, carved trim 15 + **rimebound tome-clasp ×2 (1★), Saltmaw pearl ×1 (2★)**.
- **Legendario**: shard-glass and gold fireplace, painted ceiling, charged-crystal chandelier hook. **Cost:** planks 120, bricks 100, shard-glass 50, ash-white birch 60, charged crystal 10, gold leaf 25, ice marble 30 + **prime shard ×2 (4★), Blight heart-gem ×1 (5★), Leviathan scale ×1 (WB-1), abbey bell-bronze ×1 (4★)** (incluye estatuas de guardián, ver abajo).

### 4. Sótano
- **Normal**: fieldstone walls, oak posts. **Cost:** stone 60, log 20, planks 10, nails 10.
- **Raro**: sandstone vaults, obsidian-banded doors, willow wine racks. **Cost:** stone 140, mill sandstone 40, obsidian 20, willow 30, wrought iron 30, lacquer 15 + **drowned millstone shard ×3 (2★), cinder heart ×1 (3★)**.
- **Legendario**: black peat-stone crypt vault, rootstone pillars, soft-lit runes. **Cost:** stone 300, black peat-stone 80, rootstone 60, wrought iron 60, gold leaf 10 + **abbey bell-bronze ×2 (4★), Blight heart-gem ×1 (5★), Mire Matriarch amber ×1 (WB-3)**.

### 5. Jardín interior (pets, plants, trees)
- **Normal**: grass, stone path, wooden fence. **Cost:** stone 25, log 20, planks 20, rope 10, thatch 15, nails 10.
- **Raro**: Rowanvale rich soil beds, coral-stone pond, willow pergola with garlands. **Cost:** stone 60, planks 50, rich soil 30, coral stone 25, willow 20, flower garland 20, pet bedding 15 + **barrow-root knot ×2 (1★), Saltmaw pearl ×2 (2★)**.
- **Legendario**: shard-glass orangery, storm-granite fountain, cleansed spirit tree spot. **Cost:** stone 120, planks 100, shard-glass 60, storm granite 40, peat 60, cleansed spirit seed 5, gold leaf 15 + **Blight heart-gem ×1 (5★), thunder core ×1 (4★), Elder bark ×1 (WB-5)**.

## Starter placeable furniture (Proposed)
Format: item | Normal / Raro / Legendario look | cost range (Normal → Legendario, total units).

### Storage chests (all rooms)
| Chest | Capacity (Proposed) | Look N / R / L | Cost range |
|---|---|---|---|
| Cofre pequeño | **Tier 1: 20 slots** | plank box / walnut + iron bands / Blight heartwood + gold | 15 → 120 |
| Baúl | **Tier 2: 50 slots** | iron-bound / wrought iron + leather / storm-drake hide + shard gem lock | 40 → 320 |
| Arcón del tesoro (Sótano only) | **Tier 3: 100 slots** | stone-lid / marble / Ashen shard-glass + Blight heart-gem | 100 → 800 |
| Arcón compartido (Legendario only) | **Tier 4: shared with account bank, 150 slots** | n/a / n/a / gold + gem | 1,200 |
Rule: chest capacity is fixed by chest type; tier only changes look and cost (Proposed; see Q3).

### Recámara
cama (straw / velvet canopy / Blight heartwood + stormfeather down) 20→160 · ropero 20→160 · tapete 10→80 · mesita + lámpara 10→80 · espejo (Raro+) 30→120.
### Cocina
estufa/fogón (stone / iron range / cinder-forge stove (ember ore)) 30→240 · horno de pan (clay / fire clay / ember ore core) 30→240 · barra (planks / tiled / marble) 20→160 · fregadero (wood tub / glazed / marble+copper) 20→160 · alacena 15→120 · mesa + sillas 20→160. Cook/Baker stations here count as **small workshops**.
### Sala
sofá/banco 20→160 · mesa de centro 15→120 · estante de libros 20→160 · trofeos/cuadros 10→80 · candelabro 15→120.
### Sótano (small workshops)
mini taller de cada oficio (yunque, mesa de carpintero, telar, mesa de alquimia, banco de joyero, etc.; plain / reinforced / ornate) 50→400 each, Proposed small crafting bonus only at higher tiers · estantes 15→120 · barriles 10→80.
### Jardín
árbol (sapling / fruit tree / blight-cleansed spirit tree) 15→200 · macetas y flores 5→40 · cama/casita de mascota (straw / pet bedding / gold kennel) 20→160 · bebedero 10→80 · fuente (Raro+) 60→300 · huerto pequeño 20→160.

Furniture tier can differ from room tier (e.g. Legendario bed in a Normal room). Proposed limit per room by tier: Normal 25 items, Raro 40, Legendario 60.

Furniture follows the same rule as rooms: Raro variants use regional rare materials + 1–3★ drops, Legendario variants use far-region materials + 4–5★ drops (+ a world-boss drop on the big pieces: bed, stove, chest T3/T4, fountain, spirit tree).

## Decoration costs per room (Proposed)
Every number here is Proposed. Rules follow v2: Normal uses starter-zone basics, Raro uses mid-region materials plus 1–3★ drops, Legendario uses far-region materials plus 4–5★ drops. Big pieces (Sala fireplace and chandelier, bed, stove, oven, T3/T4 chests, workshop, fountain, tree) also need an open-world boss drop at Legendario. The Sala sheet is `rooms/sala_tiers_1280x720_p1.png` / `_p2.png`.

### Sala
| Item | Crafted by | Normal | Raro | Legendario |
|---|---|---|---|---|
| Sofa (Sofá) | Carpenter | planks 12, nails 10, rope 4, thatch 6 | walnut 10, velvet 6, nails 15, carved trim 2, barrow-root knot (1★) 1 | Blight heartwood 8, shadow-moth silk 6, gold leaf 2, nails 20, prime shard (4★) 1 |
| Armchair (Sillón) | Carpenter | planks 8, nails 6, thatch 4 | walnut 6, velvet 4, nails 10, carved trim 1 | Blight heartwood 5, shadow-moth silk 4, gold leaf 1, nails 12, prime shard (4★) 1 |
| Coffee table (Mesa de centro) | Carpenter | planks 8, nails 6 | walnut 6, ice marble 3, lacquer 2, nails 8 | ash-white birch 6, shard-glass 3, gold leaf 1, nails 10, abbey bell-bronze (4★) 1 |
| Bookshelf (Librero) | Carver/Bowyer | planks 15, log 4, nails 12 | walnut 12, carved trim 3, lacquer 2, nails 15, rimebound tome-clasp (1★) 1 | thunder-cedar 12, carved trim 6, gold leaf 2, nails 20, thunder core (4★) 1 |
| Rug (Tapete) | Tailor | rope 6, thatch 8 | wool 10, velvet 4, flower garland 1 | ash-silk 8, shadow-moth silk 4, shard dust 2, prime shard (4★) 1 |
| Lamp / lantern (Lámpara / farol) | Blacksmith | nails 6, planks 2, rope 1 | wrought iron 4, frost-glass 2, ember ore 1 | storm granite 2, charged crystal 1, gold leaf 1, thunder core (4★) 1 |
| Painting (Cuadro) | Artisan | planks 4, nails 2, rope 2 | walnut 3, carved trim 1, stained glass 1, Saltmaw pearl (2★) 1 | Blight heartwood 3, gold leaf 2, shard dust 2, Blight heart-gem (5★) 1 |
| Chest (T1, 20 slots) (Cofre (T1, 20 espacios)) | Carpenter | planks 10, nails 8, rope 2 | walnut 8, wrought iron 4, lacquer 1, drowned millstone shard (2★) 1 | Blight heartwood 8, gold leaf 2, storm-drake hide 2, abbey bell-bronze (4★) 1 |
| Fireplace upgrade (Mejora de chimenea) | Miner | bricks 20, stone 10, nails 4 | ice marble 12, bricks 20, carved trim 3, frost-glass 2, cinder heart (3★) 1 | shard-glass 10, storm granite 12, gold leaf 4, prime shard (4★) 1, Leviathan scale (WB-1) 1 |
| Chandelier (Candelabro) | Jeweler | planks 6, rope 4, nails 6 | wrought iron 8, frost-glass 4, ember ore 2, Saltmaw pearl (2★) 1 | charged crystal 4, gold leaf 4, shard-glass 4, Blight heart-gem (5★) 1, Leviathan scale (WB-1) 1 |
| Guardian statues ×2, low (Estatuas de guardián ×2, bajas) | Escultor (Carver/Bowyer) | — | — | ice marble 30, storm granite 10, gold leaf 2, abbey bell-bronze (4★) 1 |

### Recámara (bedroom)
| Item | Crafted by | Normal | Raro | Legendario |
|---|---|---|---|---|
| Bed (Cama) | Carpenter | planks 14, thatch 10, rope 4, nails 10 | walnut 12, velvet 6, wool 6, nails 15, barrow-root knot (1★) 1 | Blight heartwood 10, shadow-moth silk 8, gold leaf 2, Blight heart-gem (5★) 1, Stormfeather down (WB-4) 1 |
| Wardrobe (Ropero) | Carpenter | planks 14, nails 10 | walnut 12, carved trim 2, lacquer 2, nails 12 | thunder-cedar 12, carved trim 4, gold leaf 2, prime shard (4★) 1 |
| Nightstand + candle (Mesita + vela) | Carpenter | planks 5, nails 4, thatch 1 | frost pine 4, lacquer 1, honey wax 1 | ash-white birch 4, charged crystal 1, abbey bell-bronze (4★) 1 |
| Rug (Tapete) | Tailor | rope 6, thatch 8 | wool 10, snow-hare fur 3 | ash-silk 8, storm-drake hide 2, prime shard (4★) 1 |
| Mirror (Espejo) | Alchemist | planks 4, stone 2, nails 2 | frost-glass 4, walnut 3, carved trim 1, rimebound tome-clasp (1★) 1 | shard-glass 5, gold leaf 2, thunder core (4★) 1 |
| Dresser (Cómoda) | Carpenter | planks 10, nails 8 | walnut 8, lacquer 2, nails 10 | Blight heartwood 6, gold leaf 1, nails 12, abbey bell-bronze (4★) 1 |
| Chest (T1, 20 slots) (Cofre (T1, 20 espacios)) | Carpenter | planks 10, nails 8, rope 2 | walnut 8, wrought iron 4, lacquer 1, drowned millstone shard (2★) 1 | Blight heartwood 8, gold leaf 2, storm-drake hide 2, abbey bell-bronze (4★) 1 |
| Window curtains (Cortinas) | Tailor | rope 4, thatch 4 | velvet 6, rope 2 | shadow-moth silk 6, gold leaf 1, prime shard (4★) 1 |

### Cocina (kitchen)
| Item | Crafted by | Normal | Raro | Legendario |
|---|---|---|---|---|
| Stove (Estufa / fogón) | Blacksmith | stone 15, bricks 10, nails 6 | obsidian 8, wrought iron 6, fire clay 4, cinder heart (3★) 1 | storm granite 10, gold leaf 2, abbey bell-bronze (4★) 1, Colossus ember core (WB-2) 1 |
| Bread oven (Horno de pan) | Baker | bricks 20, stone 8 | fire clay 10, glazed tile 6, bricks 15, cinder heart (3★) 1 | glazed tile 12, bog oak 6, gold leaf 2, abbey bell-bronze (4★) 1, Colossus ember core (WB-2) 1 |
| Counter (Barra) | Carpenter | planks 10, stone 6, nails 6 | driftwood 8, glazed tile 6, nails 8 | bog oak 8, storm granite 8, gold leaf 1, thunder core (4★) 1 |
| Sink (Fregadero) | Miner | stone 10, planks 4 | coral stone 8, wrought iron 2, Saltmaw pearl (2★) 1 | storm granite 10, gold leaf 1, abbey bell-bronze (4★) 1 |
| Pantry (Alacena) | Carpenter | planks 10, nails 6 | driftwood 8, lacquer 1, spice crate 2 | bog oak 8, gold leaf 1, spice crate 4, prime shard (4★) 1 |
| Table + chairs (Mesa + sillas) | Carpenter | planks 16, nails 10 | walnut 12, lacquer 2, nails 12 | bog oak 12, gold leaf 2, nails 14, thunder core (4★) 1 |
| Hanging pots (Ollas colgantes) | Cook | nails 6, rope 2 | wrought iron 4, spice crate 1 | abbey bell-bronze (4★) 1, gold leaf 1, charged crystal 1 |
| Chest (T1, 20 slots) (Cofre (T1, 20 espacios)) | Carpenter | planks 10, nails 8, rope 2 | walnut 8, wrought iron 4, lacquer 1, drowned millstone shard (2★) 1 | Blight heartwood 8, gold leaf 2, storm-drake hide 2, abbey bell-bronze (4★) 1 |

### Sótano (cellar)
| Item | Crafted by | Normal | Raro | Legendario |
|---|---|---|---|---|
| Chest (T2, 50 slots) (Baúl (T2, 50 espacios)) | Blacksmith | planks 20, nails 20, rope 4 | willow 15, wrought iron 10, snow-hare fur 4, drowned millstone shard (2★) 2 | bog oak 15, storm-drake hide 6, charged crystal 2, abbey bell-bronze (4★) 2 |
| Treasure chest (T3, 100 slots) (Arcón del tesoro (T3, 100)) | Blacksmith | stone 40, planks 25, nails 30 | mill sandstone 30, obsidian 15, wrought iron 15, cinder heart (3★) 2 | black peat-stone 30, shard-glass 10, gold leaf 6, Blight heart-gem (5★) 1, Matriarch amber (WB-3) 1 |
| Shared chest (T4, 150, Legendario only) (Arcón compartido (T4, 150)) | Jeweler | — | — | rootstone 40, gold leaf 10, charged crystal 6, Blight heart-gem (5★) 2, Matriarch amber (WB-3) 1 |
| Mini workshop (any profession) (Mini taller (cualquier oficio)) | profession of the workshop | planks 20, stone 15, nails 15 | willow 15, wrought iron 10, mill sandstone 10, cinder heart (3★) 1 | bog oak 15, storm granite 15, gold leaf 4, thunder core (4★) 1, Matriarch amber (WB-3) 1 |
| Shelves (Estantes) | Carpenter | planks 10, nails 8 | willow 8, lacquer 1 | bog oak 8, gold leaf 1, abbey bell-bronze (4★) 1 |
| Barrels (Barriles) | Carpenter | planks 8, rope 2, nails 4 | willow 6, wrought iron 2 | bog oak 6, abbey bell-bronze (4★) 1 |
| Wall torch (Antorcha de pared) | Blacksmith | log 2, nails 2, thatch 1 | wrought iron 2, ember ore 1 | charged crystal 1, rootstone 2, prime shard (4★) 1 |
| Wine rack (Botellero) | Carver/Bowyer | planks 8, nails 6 | willow 8, carved trim 1 | bog oak 8, carved trim 3, thunder core (4★) 1 |

### Jardín (garden)
| Item | Crafted by | Normal | Raro | Legendario |
|---|---|---|---|---|
| Tree (Árbol) | Lumberjack | log 4, thatch 4, stone 2 | rich soil 6, walnut 2, barrow-root knot (1★) 1 | spirit seed 2, peat 8, Blight heart-gem (5★) 1, Elder bark (WB-5) 1 |
| Flower bed / pots (Flores / macetas) | Flower gatherer | stone 4, thatch 2 | rich soil 4, flower garland 2, coral stone 2 | peat 4, spirit seed 1, shard dust 1 |
| Pet house (Casita de mascota) | Pet tamer | planks 10, thatch 6, nails 6 | willow 8, pet bedding 4, snow-hare fur 2, Saltmaw pearl (2★) 1 | Blight heartwood 6, pet bedding 6, gold leaf 2, prime shard (4★) 1 |
| Water trough (Bebedero) | Miner | stone 8, planks 2 | coral stone 6, nacre shell 2 | storm granite 6, gold leaf 1, abbey bell-bronze (4★) 1 |
| Fountain (Raro+) (Fuente (Raro+)) | Miner | — | coral stone 20, nacre shell 6, ice marble 8, Saltmaw pearl (2★) 2 | storm granite 20, shard-glass 8, gold leaf 4, thunder core (4★) 1, Leviathan scale (WB-1) 1 |
| Small vegetable patch (Huerto pequeño) | Farmer | planks 6, stone 4, thatch 6 | rich soil 10, willow 4 | peat 10, spirit seed 1, bog oak 4, prime shard (4★) 1 |
| Bench (Banca) | Carpenter | planks 8, nails 6 | driftwood 8, lacquer 1 | ash-white birch 8, gold leaf 1, abbey bell-bronze (4★) 1 |
| Garden lantern (Farol de jardín) | Blacksmith | stone 4, nails 2, rope 1 | wrought iron 3, frost-glass 2 | charged crystal 1, storm granite 3, thunder core (4★) 1 |

## Tiers de casa (Proposed)
> **v2 (13 oct 2026, Luca aprobó mezclar recursos): las recetas vigentes de casa y cuartos están en `costs/COSTS.md` (mismos totales por tier, mismos drops, composición mezclada con varias maderas/piedras/fibras; nuevos materiales iniciales Proposed: Crosshaven pine, Stoneford oak, Stoneford granite, flax fiber). Los números de abajo quedan como v1 histórico.**
Estado: **Proposed** (regla de Luca, 13 oct 2026). Números placeholder para balance de Stasium Bot/Mauro.

| Casa | Cuartos | Costo total aprox. |
|---|---|---|
| **Normal** | 1: Recámara | etapas 1–4 de RECIPES.md (~505 unidades, x1) |
| **Rara** | 3: Recámara, Sala, Cocina | ~x3 (~1.360 unidades) |
| **Legendaria** | 5: + Sótano, Jardín | ~x8 (~3.970 unidades) |

**Regla**
- La casa se mejora **en el mismo lugar**, en orden y sin saltos: Normal → Rara → Legendaria. Se paga solo la **diferencia**.
- Al desbloquear un tier de casa, los cuartos nuevos se abren **vacíos y en tier Normal de cuarto**. Los tiers de cuarto son **independientes** (ver Remodelación / Upgrade).
- Los cuartos, muebles y cofres que ya existen no se tocan.

**Costos de upgrade (placeholder)**
- **Normal → Rara:** log 40, planks 150, stone 90, bricks 120, rope 25, nails 190, walnut 60, river slate 60, frost pine 40, wrought iron 40, glazed tile 40 + **Saltmaw pearl ×2 (2★), cinder heart ×1 (3★)**.
- **Rara → Legendaria:** planks 400, stone 300, bricks 400, nails 500, wrought iron 80, bog oak 120, storm granite 150, rootstone 100, shard-glass 60, gold leaf 40 + **abbey bell-bronze ×2 (4★), Blight heart-gem ×1 (5★), Elder bark ×1 (WB-5)**.

**Pendiente (arte)**
- El exterior actual `stages/stage4_house` es la **Casa Normal**.
- Pintar el exterior de la **Casa Rara** (más grande, 3 cuartos): pendiente.
- Pintar el exterior de la **Casa Legendaria** (5 cuartos, sótano y jardín visibles): pendiente.

## Remodelación / Upgrade de cuartos (Proposed)
> **v2 (13 oct 2026, Luca aprobó mezclar recursos): las recetas vigentes de casa y cuartos están en `costs/COSTS.md` (mismos totales por tier, mismos drops, composición mezclada con varias maderas/piedras/fibras; nuevos materiales iniciales Proposed: Crosshaven pine, Stoneford oak, Stoneford granite, flax fiber). Los números de abajo quedan como v1 histórico.**
Estado: **Proposed** (regla de Luca, 13 oct 2026). Números placeholder para balance de Stasium Bot/Mauro.

**Regla**
- Cada cuarto (recámara, cocina, sala, sótano, jardín) se puede **remodelar en el mismo lugar**: Normal → Raro → Legendario.
- **Sin reconstruir**: el jugador paga solo la **diferencia** de recursos entre el tier actual y el siguiente.
- **En orden**, sin saltos: para llegar a Legendario hay que pasar por Raro.
- Por recurso: costo nuevo − costo anterior (si es ≤ 0 no se paga). Los materiales regionales y los drops de jefe del nuevo tier que no estaban en el tier anterior se pagan **completos**.
- Los **muebles colocados se quedan en su lugar** y los **cofres conservan su contenido**. Los muebles no cambian de tier con el cuarto (se mejoran aparte).
- Total Normal→Raro→Legendario por upgrades = costo directo del Legendario + lo pagado en Normal/Raro que el Legendario no usa (no hay descuento extra).

| Cuarto | Normal → Raro | Raro → Legendario |
|---|---|---|
| Recámara | planks 40, nails 30, walnut 40, frost pine 20, velvet 20, wrought iron 15, carved trim 10 + **barrow-root knot ×3 (1★), Saltmaw pearl ×1 (2★)** | planks 70, nails 60, Blight heartwood 60, thunder-cedar 40, shadow-moth silk 40, gold leaf 25 + **Blight heart-gem ×1 (5★), prime shard ×2 (4★), Stormfeather down ×1 (WB-4)** |
| Cocina | stone 20, planks 35, bricks 20, glazed tile 30, obsidian 20, driftwood 20, fire clay 15 + **cinder heart ×1 (3★), drowned millstone shard ×2 (2★)** | bricks 110, stone 40, planks 20, storm granite 60, bog oak 40, glazed tile 50, gold leaf 15 + **abbey bell-bronze ×2 (4★), thunder core ×1 (4★), colossus ember core ×1 (WB-2)** |
| Sala | planks 35, bricks 25, nails 25, ice marble 25, walnut 30, frost-glass 10, carved trim 15 + **rimebound tome-clasp ×2 (1★), Saltmaw pearl ×1 (2★)** | planks 50, bricks 50, shard-glass 50, ash-white birch 60, charged crystal 10, gold leaf 25, ice marble 5 + **prime shard ×2 (4★), Blight heart-gem ×1 (5★), Leviathan scale ×1 (WB-1), abbey bell-bronze ×1 (4★)** |
| Sótano | stone 80, mill sandstone 40, obsidian 20, willow 30, wrought iron 30, lacquer 15 + **drowned millstone shard ×3 (2★), cinder heart ×1 (3★)** | stone 160, black peat-stone 80, rootstone 60, wrought iron 30, gold leaf 10 + **abbey bell-bronze ×2 (4★), Blight heart-gem ×1 (5★), Mire Matriarch amber ×1 (WB-3)** |
| Jardín | stone 35, planks 30, rich soil 30, coral stone 25, willow 20, flower garland 20, pet bedding 15 + **barrow-root knot ×2 (1★), Saltmaw pearl ×2 (2★)** | stone 60, planks 50, shard-glass 60, storm granite 40, peat 60, cleansed spirit seed 5, gold leaf 15 + **Blight heart-gem ×1 (5★), thunder core ×1 (4★), Elder bark ×1 (WB-5)** |

La Sala Legendaria incluye las estatuas de guardián (Escultor: ice marble + abbey bell-bronze 4★), colocadas bajas para no sobresalir de los muros.

## Open questions (Mauro & Luca)
1. **Boss names**: the docs list the dungeons but not their bosses. Who names them? Are the 5 world bosses OK as placeholders?
2. **Star ratings**: is it OK to rate by level band (Rowanvale/Windmere 1★ … Heart of the Blight 5★)?
3. **Stoneford** level band and the **Ashen Shardfields** zone: are they confirmed? Is "Frost Spire" only Windmere's landmark and dungeon?
4. Can boss drops be traded (an economy for non-raiders), or are they bound to the player?
5. Do higher room tiers give gameplay benefits or only looks?
6. Chest capacity: by chest type or also by tier?
7. ~~Can a room be upgraded in place by paying the difference?~~ **Sí (Luca, 13 oct): ver Remodelación / Upgrade.**
8. Is a minimum profession level needed for Raro/Legendario materials?
9. Should the 5,000 plot price change, given these costs?
10. Do bricks belong to the Artisan (to keep 16 professions)?

## Jardín: animales y mascotas (Luca 2026-10-13, Proposed)
| Tier | Mascotas | Animales de granja |
|---|---|---|
| Normal | 1 | 1 |
| Raro | 2 | 3 |
| Legendario | todas | todos (jardín más grande con mini granja) |

- Animales de granja: el jugador compra cada uno por separado y producen recursos: vaca → leche, oveja → lana, cerdo → comida, gallina → huevos.
- Mascotas: dan un bonus y tienen animaciones (idle/juego).
- Bonus exactos de mascotas y precios/tiempos de producción: Open (sin definir).
