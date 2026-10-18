# Rooms: 3 tiers x 5 rooms

Source: `ROOM_TIERS.md`, `PROGRESS_2026-10-13.md`, `pieces/README.md`. No room has a walk grid or walk mask encoded anywhere (walkable cells: **none encoded** for every room). The only per-room masks are the furniture inpaint masks in `pieces/shells/_masks/`, which are not walk masks. Nothing is in game.

**Confirmed:** Normal = bedroom only, Rare = bedroom + living + kitchen, Legendary = all 5, including the cellar workshop and the garden. This is Luca's rule, and Mauro confirmed it in PR #252, comment 6226722023: his "5 rooms" meant the Legendary set.

**DECIDED by Luca (2026-10-16):** crafting workshops (talleres) per house tier: Normal = 1, Rare = 2, Legendary = all. This supersedes the 2026-10-13 'sótano workshop in every tier' note. **OPEN:** which workshop Normal gets and which 2 Rare gets (not recorded), and where they sit, since Normal and Rare have no sótano.

## Normal house (opens: bedroom)

### Recámara (bedroom), Normal
- Status: open in this house tier.
- Art: `art/housing_v1/rooms/bedroom_normal.jpg` (1280x720), CONCEPT.
- Empty shell: `pieces/shells/bedroom_normal_empty.jpg` 1280x720 (CONCEPT (empty shell; check visually))
- Layout notes: none recorded beyond the concept image
- Walkable cells/mask: none encoded.

### Cocina (kitchen), Normal
- Status: **not in this house tier under Luca's rule**.
- Art: `art/housing_v1/rooms/kitchen_normal.jpg` (1280x720), CONCEPT.
- Empty shell: `pieces/shells/kitchen_normal_empty.jpg` 1280x720 (CONCEPT (empty shell; check visually))
- Layout notes: Kitchen A, stone, no fireplace.
- Walkable cells/mask: none encoded.

### Sala (sala), Normal
- Status: **not in this house tier under Luca's rule**.
- Art: `art/housing_v1/rooms/sala_tiers_1280x720_p1.png (per-tier sheet cell)` (1280x720), CONCEPT.
- Empty shell: `pieces/shells/sala_normal_empty.png` 1280x720 (IN-GAME-READY (clean))
- Layout notes: none recorded beyond the concept image
- Walkable cells/mask: none encoded.

### Sótano (cellar), Normal
- Status: **not in this house tier under Luca's rule**.
- Art: `art/housing_v1/rooms/cellar_normal.jpg` (1280x720), CONCEPT.
- Empty shell: `pieces/shells/cellar_normal_empty.jpg` 1280x720 (CONCEPT (empty shell; check visually))
- Layout notes: Carpentry bench, small forge + anvil, tanning table.
- Walkable cells/mask: none encoded.

### Jardín (garden), Normal
- Status: **not in this house tier under Luca's rule**.
- Art: `art/housing_v1/rooms/garden_normal.jpg` (1280x720), CONCEPT.
- Empty shell: `pieces/shells/garden_normal_empty.jpg` 1280x720 (CONCEPT (empty shell; check visually))
- Layout notes: none recorded beyond the concept image
- Walkable cells/mask: none encoded.

## Rare house (opens: bedroom, kitchen, sala)

### Recámara (bedroom), Rare
- Status: open in this house tier.
- Art: `art/housing_v1/rooms/bedroom_rare.jpg` (1280x720), CONCEPT.
- Empty shell: `pieces/shells/bedroom_rare_empty.jpg` 1280x720 (CONCEPT (empty shell; check visually))
- Layout notes: none recorded beyond the concept image
- Walkable cells/mask: none encoded.

### Cocina (kitchen), Rare
- Status: open in this house tier.
- Art: `art/housing_v1/rooms/kitchen_rare.jpg` (1280x720), CONCEPT.
- Empty shell: `pieces/shells/kitchen_rare_empty.jpg` 1280x720 (CONCEPT (empty shell; check visually))
- Layout notes: Kitchen B, wood, no fireplace.
- Walkable cells/mask: none encoded.

### Sala (sala), Rare
- Status: open in this house tier.
- Art: `art/housing_v1/rooms/sala_tiers_1280x720_p1.png (per-tier sheet cell)` (1280x720), CONCEPT.
- Empty shell: `pieces/shells/sala_rare_empty.jpg` 1280x720 (CONCEPT (empty shell; check visually))
- Layout notes: none recorded beyond the concept image
- Walkable cells/mask: none encoded.

### Sótano (cellar), Rare
- Status: **not in this house tier under Luca's rule**.
- Art: `art/housing_v1/rooms/cellar_rare.jpg` (1280x720), CONCEPT.
- Empty shell: `pieces/shells/cellar_rare_empty.jpg` 1280x720 (CONCEPT (empty shell; check visually))
- Layout notes: Forge with bellows, alchemy, loom, jewelry, carpentry.
- Walkable cells/mask: none encoded.

### Jardín (garden), Rare
- Status: **not in this house tier under Luca's rule**.
- Art: `art/housing_v1/rooms/garden_rare.jpg` (1280x720), CONCEPT.
- Empty shell: `pieces/shells/garden_rare_empty.jpg` 1280x720 (CONCEPT (empty shell; check visually))
- Layout notes: none recorded beyond the concept image
- Walkable cells/mask: none encoded.

## Legendary house (opens: bedroom, kitchen, sala, cellar, garden)

### Recámara (bedroom), Legendary
- Status: open in this house tier.
- Art: `art/housing_v1/rooms/bedroom_legendary.jpg` (1280x720), CONCEPT.
- Empty shell: `pieces/shells/bedroom_legendary_empty.jpg` 1280x720 (CONCEPT (empty shell; check visually))
- Layout notes: Chest removed; 3 armor mannequins in arched wall niches (Luca-approved).
- Walkable cells/mask: none encoded.

### Cocina (kitchen), Legendary
- Status: open in this house tier.
- Art: `art/housing_v1/rooms/kitchen_legendary.jpg` (1280x720), CONCEPT.
- Empty shell: `pieces/shells/kitchen_legendary_empty.jpg` 1280x720 (CONCEPT (empty shell; check visually))
- Layout notes: Kitchen C, brick, no fireplace.
- Walkable cells/mask: none encoded.

### Sala (sala), Legendary
- Status: open in this house tier.
- Art: `art/housing_v1/rooms/sala_tiers_1280x720_p1.png (per-tier sheet cell)` (1280x720), CONCEPT.
- Empty shell: `pieces/shells/sala_legendary_empty.jpg` 1280x720 (CONCEPT (empty shell; check visually))
- Layout notes: Low knight/guardian statues below the walls (Luca-approved); keeps the fireplace, no ladder.
- Walkable cells/mask: none encoded.

### Sótano (cellar), Legendary
- Status: open in this house tier.
- Art: `art/housing_v1/rooms/cellar_legendary.jpg` (1280x720), CONCEPT.
- Empty shell: `pieces/shells/cellar_legendary_empty.jpg` 1280x720 (CONCEPT (empty shell; check visually))
- Layout notes: Master forge, enchanting table, copper still, gold benches.
- Walkable cells/mask: none encoded.

### Jardín (garden), Legendary
- Status: open in this house tier.
- Art: `art/housing_v1/rooms/garden_legendary.jpg` (1280x720), CONCEPT.
- Empty shell: `pieces/shells/garden_legendary_empty.jpg` 1280x720 (CONCEPT (empty shell; check visually))
- Layout notes: none recorded beyond the concept image
- Walkable cells/mask: none encoded.

Older single-tier mocks: `rooms/room_*_L.png`, `rooms/rooms_sheet_1280x720.png`; overview `ROOMS_ALL_TIERS_1920x1080.png` (sala cells cropped from `sala_tiers_p1`). The Sala exists per tier only as sheet cells (`sala_tiers_1280x720_p1/_p2.png`), plus `sala_legendaria_estatuas.png`.
