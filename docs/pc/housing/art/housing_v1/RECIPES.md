# STASIUM XII: Player housing recipes (PROPOSED DRAFT)
Status: **Proposed**. Every number here is a placeholder for Stasium Bot/design to balance. Nothing is wired.

## Resources and who makes them
| Resource | Made by | Art |
|---|---|---|
| log | Lumberjack | resources/res_log_* |
| planks | Carpenter | resources/res_planks_* |
| stone | Miner | resources/res_stone_* |
| bricks | Potter / Artisan | resources/res_bricks_* |
| thatch | Farmer | resources/res_thatch_* |
| rope | Tailor | resources/res_rope_* |
| nails | Blacksmith | resources/res_nails_* |

## Stages
> **v2 (13 oct 2026, Luca aprobó mezclar recursos): las recetas vigentes de casa y cuartos están en `costs/COSTS.md` (mismos totales por tier, mismos drops, composición mezclada con varias maderas/piedras/fibras; nuevos materiales iniciales Proposed: Crosshaven pine, Stoneford oak, Stoneford granite, flax fiber). Los números de abajo quedan como v1 histórico.**
**Stage 1: Empty plot.** Bought from the city (price Proposed: 5,000 kamas-equivalent). No resources. No art in this pack yet.

**Stage 2: Foundation** (stages/stage2_foundation.png). Proposed cost:
- stone x40 (Miner)
- log x10 (Lumberjack)
- planks x10 (Carpenter)
- nails x20 (Blacksmith)

**Stage 3: Timber frame** (stages/stage3_frame.png). Proposed cost:
- log x30 (Lumberjack)
- planks x40 (Carpenter)
- rope x15 (Tailor)
- nails x60 (Blacksmith)
- bricks x20 (Potter/Artisan; chimney)

**Stage 4: Finished house** (stages/stage4_house.png). Proposed cost:
- bricks x60 (Potter/Artisan)
- planks x50 (Carpenter)
- thatch x40 (Farmer; roof underlay/insulation)
- stone x20 (Miner)
- rope x10 (Tailor)
- nails x80 (Blacksmith)

All 7 resources are needed, so building a house takes trade between 7 professions. Totals (Proposed): log 40, planks 100, stone 60, bricks 80, thatch 40, rope 25, nails 160.

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
