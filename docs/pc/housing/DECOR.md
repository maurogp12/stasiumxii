# Decor catalogue

Everything here is **Proposed** (from ROOM_TIERS.md and pieces/README.md). Nothing is wired.

## Placement and unlock rules, as recorded in the docs
- "All furniture is crafted by players and placed freely." (ROOM_TIERS.md, Proposed)
- "Furniture tier can differ from room tier (e.g. Legendario bed in a Normal room)." The proposed item limit per room is Normal 25, Raro 40, Legendario 60.
- Room tiers are independent of the house tier. New rooms open empty, at Normal room tier.
- On an upgrade, placed furniture stays where it is and chests keep their contents. Furniture does not change tier with the room; it is upgraded separately.
- Chest capacity is fixed by chest type, and tier only changes the look and the cost (Proposed; open question Q6).
- `footprint_tiles` in the cutout index is a guess.
- Everything else is **Open**: how items unlock, the placement grid, rotation, and per-account limits.

## A. Cutout and painted pieces (`art/housing_v1/pieces/furniture/index.json`, 143 entries)
| Name | File | Room | Tier | Pixels | Footprint (guess) | Notes |
|---|---|---|---|---|---|---|
| chest | `bedroom_normal_chest.png` | bedroom | normal | 167x149 | 1x1 | IN-GAME-READY cutout |
| nightstand | `bedroom_normal_nightstand.png` | bedroom | normal | 110x137 | 1x1 | IN-GAME-READY cutout |
| bed | `bedroom_normal_bed.png` | bedroom | normal | 420x347 | 2x3 | IN-GAME-READY cutout |
| rug | `bedroom_normal_rug.png` | bedroom | normal | 357x228 | 2x3 | IN-GAME-READY cutout |
| wall_lamp | `bedroom_rare_wall_lamp.png` | bedroom | rare | 55x106 | wall | IN-GAME-READY cutout |
| chest | `bedroom_rare_chest.png` | bedroom | rare | 173x162 | 1x1 | IN-GAME-READY cutout |
| nightstand_lamp | `bedroom_rare_nightstand_lamp.png` | bedroom | rare | 103x169 | 1x1 | IN-GAME-READY cutout |
| wardrobe | `bedroom_rare_wardrobe.png` | bedroom | rare | 172x299 | 1x2 | IN-GAME-READY cutout |
| bed_canopy | `bedroom_rare_bed_canopy.png` | bedroom | rare | 431x483 | 2x3 | IN-GAME-READY cutout |
| rug | `bedroom_rare_rug.png` | bedroom | rare | 384x245 | 2x3 | IN-GAME-READY cutout |
| wardrobe | `bedroom_legendary_wardrobe.png` | bedroom | legendary | 125x242 | 1x2 | IN-GAME-READY cutout |
| mannequin_gold | `bedroom_legendary_mannequin_gold.png` | bedroom | legendary | 72x215 | 1x1 | IN-GAME-READY cutout |
| mannequin_red | `bedroom_legendary_mannequin_red.png` | bedroom | legendary | 64x199 | 1x1 | IN-GAME-READY cutout |
| mannequin_green | `bedroom_legendary_mannequin_green.png` | bedroom | legendary | 74x190 | 1x1 | IN-GAME-READY cutout |
| vanity | `bedroom_legendary_vanity.png` | bedroom | legendary | 98x106 | 1x2 | IN-GAME-READY cutout |
| chandelier | `bedroom_legendary_chandelier.png` | bedroom | legendary | 104x163 | ceiling | IN-GAME-READY cutout |
| bed_canopy | `bedroom_legendary_bed_canopy.png` | bedroom | legendary | 349x426 | 2x3 | IN-GAME-READY cutout |
| nightstand | `bedroom_legendary_nightstand.png` | bedroom | legendary | 58x150 | 1x1 | IN-GAME-READY cutout |
| rug | `bedroom_legendary_rug.png` | bedroom | legendary | 507x309 | 3x3 | IN-GAME-READY cutout |
| table | `kitchen_normal_table.png` | kitchen | normal | 261x217 | 2x2 | IN-GAME-READY cutout |
| barrel | `kitchen_normal_barrel.png` | kitchen | normal | 50x63 | 1x1 | IN-GAME-READY cutout |
| broom | `kitchen_normal_broom.png` | kitchen | normal | 57x124 | wall | IN-GAME-READY cutout |
| firewood | `kitchen_rare_firewood.png` | kitchen | rare | 119x95 | 1x1 | IN-GAME-READY cutout |
| island | `kitchen_rare_island.png` | kitchen | rare | 238x254 | 2x3 | IN-GAME-READY cutout |
| stools | `kitchen_rare_stools.png` | kitchen | rare | 173x169 | 1x2 | IN-GAME-READY cutout |
| rug | `kitchen_rare_rug.png` | kitchen | rare | 298x179 | 2x2 | needs paintover |
| pot_rack | `kitchen_rare_pot_rack.png` | kitchen | rare | 164x155 | ceiling | IN-GAME-READY cutout |
| stove | `kitchen_rare_stove.png` | kitchen | rare | 121x143 | 1x1 | IN-GAME-READY cutout |
| fruit_basket | `kitchen_rare_fruit_basket.png` | kitchen | rare | 57x63 | small | IN-GAME-READY cutout |
| stove | `kitchen_legendary_stove.png` | kitchen | legendary | 79x115 | 1x1 | IN-GAME-READY cutout |
| table_stools | `kitchen_legendary_table_stools.png` | kitchen | legendary | 257x220 | 2x3 | IN-GAME-READY cutout |
| workbench | `cellar_normal_workbench.png` | cellar | normal | 271x146 | 1x2 | IN-GAME-READY cutout |
| anvil | `cellar_normal_anvil.png` | cellar | normal | 102x108 | 1x1 | IN-GAME-READY cutout |
| crate | `cellar_normal_crate.png` | cellar | normal | 129x134 | 1x1 | IN-GAME-READY cutout |
| tanning_table | `cellar_normal_tanning_table.png` | cellar | normal | 251x148 | 1x2 | IN-GAME-READY cutout |
| barrels | `cellar_normal_barrels.png` | cellar | normal | 149x181 | 1x2 | IN-GAME-READY cutout |
| lantern | `cellar_normal_lantern.png` | cellar | normal | 47x187 | ceiling | IN-GAME-READY cutout |
| wine_rack | `cellar_rare_wine_rack.png` | cellar | rare | 159x257 | 1x2 | IN-GAME-READY cutout |
| potion_shelf | `cellar_rare_potion_shelf.png` | cellar | rare | 277x129 | wall | needs paintover |
| workbench_tools | `cellar_rare_workbench_tools.png` | cellar | rare | 195x108 | 1x2 | IN-GAME-READY cutout |
| loom | `cellar_rare_loom.png` | cellar | rare | 319x286 | 2x2 | needs paintover |
| chest_left | `cellar_rare_chest_left.png` | cellar | rare | 135x147 | 1x1 | IN-GAME-READY cutout |
| anvil | `cellar_rare_anvil.png` | cellar | rare | 123x147 | 1x1 | IN-GAME-READY cutout |
| alchemy_table | `cellar_rare_alchemy_table.png` | cellar | rare | 305x269 | 2x2 | IN-GAME-READY cutout |
| crate | `cellar_rare_crate.png` | cellar | rare | 151x156 | 1x1 | IN-GAME-READY cutout |
| chest_right | `cellar_rare_chest_right.png` | cellar | rare | 125x138 | 1x1 | IN-GAME-READY cutout |
| rune_bench | `cellar_legendary_rune_bench.png` | cellar | legendary | 190x166 | 1x2 | IN-GAME-READY cutout |
| copper_still | `cellar_legendary_copper_still.png` | cellar | legendary | 124x189 | 1x1 | IN-GAME-READY cutout |
| weapon_rack | `cellar_legendary_weapon_rack.png` | cellar | legendary | 197x294 | 1x2 | IN-GAME-READY cutout |
| anvil_gold | `cellar_legendary_anvil_gold.png` | cellar | legendary | 120x120 | 1x1 | IN-GAME-READY cutout |
| chest_left | `cellar_legendary_chest_left.png` | cellar | legendary | 120x117 | 1x1 | IN-GAME-READY cutout |
| gold_bench | `cellar_legendary_gold_bench.png` | cellar | legendary | 236x218 | 1x2 | IN-GAME-READY cutout |
| chest_small | `cellar_legendary_chest_small.png` | cellar | legendary | 144x120 | 1x1 | IN-GAME-READY cutout |
| jewel_bench | `cellar_legendary_jewel_bench.png` | cellar | legendary | 280x250 | 1x2 | IN-GAME-READY cutout |
| brazier_left | `cellar_legendary_brazier_left.png` | cellar | legendary | 51x87 | 1x1 | IN-GAME-READY cutout |
| brazier_right | `cellar_legendary_brazier_right.png` | cellar | legendary | 64x134 | 1x1 | IN-GAME-READY cutout |
| tree | `garden_normal_tree.png` | garden | normal | 180x255 | 2x2 | IN-GAME-READY cutout |
| pet_bed_dog | `garden_normal_pet_bed_dog.png` | garden | normal | 240x179 | 1x2 | IN-GAME-READY cutout |
| shrub | `garden_normal_shrub.png` | garden | normal | 100x75 | 1x1 | IN-GAME-READY cutout |
| pot_big | `garden_normal_pot_big.png` | garden | normal | 103x154 | 1x1 | IN-GAME-READY cutout |
| watering_can | `garden_normal_watering_can.png` | garden | normal | 112x92 | small | IN-GAME-READY cutout |
| pot_herb | `garden_normal_pot_herb.png` | garden | normal | 81x100 | 1x1 | IN-GAME-READY cutout |
| pot_flower | `garden_normal_pot_flower.png` | garden | normal | 76x107 | 1x1 | IN-GAME-READY cutout |
| tree_maple | `garden_rare_tree_maple.png` | garden | rare | 547x300 | 3x3 | IN-GAME-READY cutout |
| bench | `garden_rare_bench.png` | garden | rare | 136x119 | 1x2 | IN-GAME-READY cutout |
| fountain | `garden_rare_fountain.png` | garden | rare | 135x178 | 2x2 | IN-GAME-READY cutout |
| cat_bed | `garden_rare_cat_bed.png` | garden | rare | 125x87 | 1x1 | IN-GAME-READY cutout |
| rabbit_hutch | `garden_rare_rabbit_hutch.png` | garden | rare | 174x165 | 1x2 | IN-GAME-READY cutout |
| tree_blossom | `garden_legendary_tree_blossom.png` | garden | legendary | 616x300 | 3x3 | IN-GAME-READY cutout |
| fountain_koi | `garden_legendary_fountain_koi.png` | garden | legendary | 228x240 | 3x3 | needs paintover |
| fox_cushion | `garden_legendary_fox_cushion.png` | garden | legendary | 150x105 | 1x1 | IN-GAME-READY cutout |
| statue | `garden_legendary_statue.png` | garden | legendary | 85x215 | 1x1 | IN-GAME-READY cutout |
| birdcage | `garden_legendary_birdcage.png` | garden | legendary | 84x123 | ceiling | IN-GAME-READY cutout |
| rose_bush | `garden_legendary_rose_bush.png` | garden | legendary | 190x249 | 1x1 | IN-GAME-READY cutout |
| lantern | `garden_legendary_lantern.png` | garden | legendary | 44x91 | small | IN-GAME-READY cutout |
| chandelier | `sala_legendary_chandelier.png` | sala | legendary | 185x174 | ceiling | IN-GAME-READY cutout |
| statue_left | `sala_legendary_statue_left.png` | sala | legendary | 85x224 | 1x1 | IN-GAME-READY cutout |
| statue_right | `sala_legendary_statue_right.png` | sala | legendary | 92x210 | 1x1 | IN-GAME-READY cutout |
| dragon_cabinet | `sala_legendary_dragon_cabinet.png` | sala | legendary | 103x181 | 1x1 | IN-GAME-READY cutout |
| sofa | `sala_legendary_sofa.png` | sala | legendary | 324x258 | 1x3 | IN-GAME-READY cutout |
| coffee_table | `sala_legendary_coffee_table.png` | sala | legendary | 254x188 | 2x2 | IN-GAME-READY cutout |
| treasure_chest | `sala_legendary_treasure_chest.png` | sala | legendary | 130x153 | 1x1 | IN-GAME-READY cutout |
| rug | `sala_legendary_rug.png` | sala | legendary | 658x312 | 4x4 | needs paintover |
| bookshelf | `sala_normal_bookshelf.png` | sala | normal | 136x141 | 1x1 | low_res; needs paintover |
| floor_lamp | `sala_normal_floor_lamp.png` | sala | normal | 51x125 | 1x1 | low_res; needs paintover |
| sofa | `sala_normal_sofa.png` | sala | normal | 310x258 | 1x3 | low_res; needs paintover |
| coffee_table | `sala_normal_coffee_table.png` | sala | normal | 216x180 | 2x2 | low_res; needs paintover |
| rug | `sala_normal_rug.png` | sala | normal | 553x260 | 3x3 | low_res; needs paintover |
| bookshelf | `sala_rare_bookshelf.png` | sala | rare | 150x240 | 1x2 | low_res; needs paintover |
| armchair_left | `sala_rare_armchair_left.png` | sala | rare | 148x166 | 1x1 | low_res; needs paintover |
| armchair_right | `sala_rare_armchair_right.png` | sala | rare | 161x165 | 1x1 | low_res; needs paintover |
| sofa | `sala_rare_sofa.png` | sala | rare | 234x194 | 1x3 | low_res; needs paintover |
| coffee_table | `sala_rare_coffee_table.png` | sala | rare | 196x155 | 2x2 | low_res; needs paintover |
| rug | `sala_rare_rug.png` | sala | rare | 388x154 | 4x4 | low_res; needs paintover |
| sofa | `painted/sofa_legendary.png` | sala | legendary | 806x689 | ? | painted variant, replaces earlier cropped sala sofa pieces (legendary) from rooms/*.jpg |
| sofa | `painted/sofa_rare.png` | sala | rare | 833x684 | ? | painted variant, replaces earlier cropped sala sofa pieces (rare) from rooms/*.jpg |
| sofa | `painted/sofa_normal.png` | sala | normal | 743x609 | ? | painted variant, replaces earlier cropped sala sofa pieces (normal) from rooms/*.jpg |
| table | `painted/table_legendary.png` | sala | legendary | 893x605 | ? | painted variant, replaces earlier cropped sala table pieces (legendary) from rooms/*.jpg |
| table | `painted/table_rare.png` | sala | rare | 796x645 | ? | painted variant, replaces earlier cropped sala table pieces (rare) from rooms/*.jpg |
| table | `painted/table_normal.png` | sala | normal | 852x597 | ? | painted variant, replaces earlier cropped sala table pieces (normal) from rooms/*.jpg |
| bed | `painted/bed_legendary.png` | bedroom | legendary | 688x701 | ? | painted variant, replaces earlier cropped bedroom bed pieces (legendary) from rooms/*.jpg |
| bed | `painted/bed_rare.png` | bedroom | rare | 800x712 | ? | painted variant, replaces earlier cropped bedroom bed pieces (rare) from rooms/*.jpg |
| bed | `painted/bed_normal.png` | bedroom | normal | 853x719 | ? | painted variant, replaces earlier cropped bedroom bed pieces (normal) from rooms/*.jpg |
| wardrobe | `painted/wardrobe_legendary.png` | bedroom | legendary | 500x720 | ? | painted variant, replaces earlier cropped bedroom wardrobe pieces (legendary) from rooms/*.jpg |
| wardrobe | `painted/wardrobe_rare.png` | bedroom | rare | 601x718 | ? | painted variant, replaces earlier cropped bedroom wardrobe pieces (rare) from rooms/*.jpg |
| wardrobe | `painted/wardrobe_normal.png` | bedroom | normal | 542x705 | ? | painted variant, replaces earlier cropped bedroom wardrobe pieces (normal) from rooms/*.jpg |
| chandelier | `painted/chandelier_legendary.png` | sala | legendary | 626x695 | ? | painted variant, replaces earlier cropped sala chandelier pieces (legendary) from rooms/*.jpg |
| chandelier | `painted/chandelier_rare.png` | sala | rare | 644x674 | ? | painted variant, replaces earlier cropped sala chandelier pieces (rare) from rooms/*.jpg |
| chandelier | `painted/chandelier_normal.png` | sala | normal | 646x651 | ? | painted variant, replaces earlier cropped sala chandelier pieces (normal) from rooms/*.jpg |
| rug | `painted/rug_legendary.png` | sala | legendary | 1204x711 | ? | painted variant, replaces earlier cropped sala rug pieces (legendary) from rooms/*.jpg |
| rug | `painted/rug_rare.png` | sala | rare | 1016x649 | ? | painted variant, replaces earlier cropped sala rug pieces (rare) from rooms/*.jpg |
| rug | `painted/rug_normal.png` | sala | normal | 898x563 | ? | painted variant, replaces earlier cropped sala rug pieces (normal) from rooms/*.jpg |
| mannequin | `painted/mannequin_legendary.png` | bedroom | legendary | 400x720 | ? | painted variant, replaces earlier cropped bedroom mannequin pieces (legendary) from rooms/*.jpg |
| mannequin | `painted/mannequin_rare.png` | bedroom | rare | 411x714 | ? | painted variant, replaces earlier cropped bedroom mannequin pieces (rare) from rooms/*.jpg |
| mannequin | `painted/mannequin_normal.png` | bedroom | normal | 463x671 | ? | painted variant, replaces earlier cropped bedroom mannequin pieces (normal) from rooms/*.jpg |
| statue_low | `painted/statue_low_legendary.png` | sala | legendary | 598x696 | ? | painted variant, replaces earlier cropped sala statue_low pieces (legendary) from rooms/*.jpg |
| stove | `painted/stove_normal.png` | kitchen | normal | 726x702 | ? | painted variant, replaces earlier cropped kitchen stove pieces (normal) from rooms/*.jpg |
| stove | `painted/stove_rare.png` | kitchen | rare | 530x716 | ? | painted variant, replaces earlier cropped kitchen stove pieces (rare) from rooms/*.jpg |
| stove | `painted/stove_legendary.png` | kitchen | legendary | 664x720 | ? | painted variant, replaces earlier cropped kitchen stove pieces (legendary) from rooms/*.jpg |
| worktable | `painted/worktable_normal.png` | kitchen | normal | 411x321 | ? | painted variant, replaces earlier cropped kitchen worktable pieces (normal) from rooms/*.jpg |
| worktable | `painted/worktable_rare.png` | kitchen | rare | 407x392 | ? | painted variant, replaces earlier cropped kitchen worktable pieces (rare) from rooms/*.jpg |
| worktable | `painted/worktable_legendary.png` | kitchen | legendary | 426x406 | ? | painted variant, replaces earlier cropped kitchen worktable pieces (legendary) from rooms/*.jpg |
| pantry | `painted/pantry_normal.png` | kitchen | normal | 332x548 | ? | painted variant, replaces earlier cropped kitchen pantry pieces (normal) from rooms/*.jpg |
| pantry | `painted/pantry_rare.png` | kitchen | rare | 342x570 | ? | painted variant, replaces earlier cropped kitchen pantry pieces (rare) from rooms/*.jpg |
| pantry | `painted/pantry_legendary.png` | kitchen | legendary | 422x696 | ? | painted variant, replaces earlier cropped kitchen pantry pieces (legendary) from rooms/*.jpg |
| barrels | `painted/barrels_normal.png` | kitchen | normal | 226x299 | ? | painted variant, replaces earlier cropped kitchen barrels pieces (normal) from rooms/*.jpg |
| barrels | `painted/barrels_rare.png` | kitchen | rare | 359x329 | ? | painted variant, replaces earlier cropped kitchen barrels pieces (rare) from rooms/*.jpg |
| barrels | `painted/barrels_legendary.png` | kitchen | legendary | 477x432 | ? | painted variant, replaces earlier cropped kitchen barrels pieces (legendary) from rooms/*.jpg |
| craftbench | `painted/craftbench_normal.png` | cellar | normal | 906x610 | ? | painted variant, replaces earlier cropped cellar craftbench pieces (normal) from rooms/*.jpg |
| craftbench | `painted/craftbench_rare.png` | cellar | rare | 360x461 | ? | painted variant, replaces earlier cropped cellar craftbench pieces (rare) from rooms/*.jpg |
| craftbench | `painted/craftbench_legendary.png` | cellar | legendary | 494x606 | ? | painted variant, replaces earlier cropped cellar craftbench pieces (legendary) from rooms/*.jpg |
| chest | `painted/chest_normal.png` | cellar | normal | 372x315 | ? | painted variant, replaces earlier cropped cellar chest pieces (normal) from rooms/*.jpg |
| chest | `painted/chest_rare.png` | cellar | rare | 380x331 | ? | painted variant, replaces earlier cropped cellar chest pieces (rare) from rooms/*.jpg |
| chest | `painted/chest_legendary.png` | cellar | legendary | 409x361 | ? | painted variant, replaces earlier cropped cellar chest pieces (legendary) from rooms/*.jpg |
| planter | `painted/planter_normal.png` | garden | normal | 370x351 | ? | painted variant, replaces earlier cropped garden pieces (normal) from rooms/*.jpg |
| planter | `painted/planter_rare.png` | garden | rare | 423x309 | ? | painted variant, replaces earlier cropped garden pieces (rare) from rooms/*.jpg |
| planter | `painted/planter_legendary.png` | garden | legendary | 438x467 | ? | painted variant, replaces earlier cropped garden pieces (legendary) from rooms/*.jpg |
| petbed | `painted/petbed_normal.png` | garden | normal | 344x257 | ? | painted variant, replaces earlier cropped garden pieces (normal) from rooms/*.jpg |
| petbed | `painted/petbed_rare.png` | garden | rare | 386x401 | ? | painted variant, replaces earlier cropped garden pieces (rare) from rooms/*.jpg |
| petbed | `painted/petbed_legendary.png` | garden | legendary | 444x541 | ? | painted variant, replaces earlier cropped garden pieces (legendary) from rooms/*.jpg |
| pottedtree | `painted/pottedtree_normal.png` | garden | normal | 216x443 | ? | painted variant, replaces earlier cropped garden pieces (normal) from rooms/*.jpg |
| pottedtree | `painted/pottedtree_rare.png` | garden | rare | 382x567 | ? | painted variant, replaces earlier cropped garden pieces (rare) from rooms/*.jpg |
| pottedtree | `painted/pottedtree_legendary.png` | garden | legendary | 428x563 | ? | painted variant, replaces earlier cropped garden pieces (legendary) from rooms/*.jpg |

## B. Animals (`pieces/animals/`)
| Name | Kind | File | Pixels | Produces | Bonus | Animations |
|---|---|---|---|---|---|---|
| pet_cat | pet | `pet_cat.png` | 234x294 | None | Open | Open |
| pet_dog | pet | `pet_dog.png` | 277x291 | None | Open | Open |
| pet_rabbit | pet | `pet_rabbit.png` | 203x301 | None | Open | Open |
| pet_dragon | pet | `pet_dragon.png` | 352x284 | None | Open | Open |
| farm_hen | farm | `farm_hen.png` | 235x307 | eggs | Open | Open |
| farm_pig | farm | `farm_pig.png` | 294x291 | food | Open | Open |
| farm_sheep | farm | `farm_sheep.png` | 288x295 | wool | Open | Open |
| farm_cow | farm | `farm_cow.png` | 367x341 | milk | Open | Open |

Art exists for `pet_dragon` and `pet_rabbit`, but neither appears in any approved list I found. Pet bonuses and animations are Open.

## C. Craftable decor from the cost tables (ROOM_TIERS.md, "Decoration costs per room")
Each item comes in Normal / Raro / Legendario unless noted. The Art column names the matching file(s) from table A, or says "no art". The match is by file name only.

| Room | Item | Art |
|---|---|---|
| Sala | Sofa | `painted/sofa_legendary.png`, `painted/sofa_normal.png`, `painted/sofa_rare.png`, `sala_legendary_sofa.png`, `sala_normal_sofa.png`, `sala_rare_sofa.png` |
| Sala | Armchair | `sala_rare_armchair_left.png`, `sala_rare_armchair_right.png` |
| Sala | Coffee table | `sala_legendary_coffee_table.png`, `sala_normal_coffee_table.png`, `sala_rare_coffee_table.png` |
| Sala | Bookshelf | `sala_normal_bookshelf.png`, `sala_rare_bookshelf.png` |
| Sala | Rug | `painted/rug_legendary.png`, `painted/rug_normal.png`, `painted/rug_rare.png`, `sala_legendary_rug.png`, `sala_normal_rug.png`, `sala_rare_rug.png` |
| Sala | Lamp / lantern | `sala_normal_floor_lamp.png` |
| Sala | Painting | no art |
| Sala | Chest (T1, 20 slots) | `sala_legendary_treasure_chest.png` |
| Sala | Fireplace upgrade | no art |
| Sala | Chandelier | `painted/chandelier_legendary.png`, `painted/chandelier_normal.png`, `painted/chandelier_rare.png`, `sala_legendary_chandelier.png` |
| Sala | Guardian statues x2, low (Legendario only) | `painted/statue_low_legendary.png`, `sala_legendary_statue_left.png`, `sala_legendary_statue_right.png` |
| Recámara | Bed | `bedroom_legendary_bed_canopy.png`, `bedroom_legendary_chandelier.png`, `bedroom_legendary_mannequin_gold.png`, `bedroom_legendary_mannequin_green.png`, `bedroom_legendary_mannequin_red.png`, `bedroom_legendary_nightstand.png`, `bedroom_legendary_rug.png`, `bedroom_legendary_vanity.png`, `bedroom_legendary_wardrobe.png`, `bedroom_normal_bed.png`, `bedroom_normal_chest.png`, `bedroom_normal_nightstand.png`, `bedroom_normal_rug.png`, `bedroom_rare_bed_canopy.png`, `bedroom_rare_chest.png`, `bedroom_rare_nightstand_lamp.png`, `bedroom_rare_rug.png`, `bedroom_rare_wall_lamp.png`, `bedroom_rare_wardrobe.png`, `painted/bed_legendary.png`, `painted/bed_normal.png`, `painted/bed_rare.png` |
| Recámara | Wardrobe | `bedroom_legendary_wardrobe.png`, `bedroom_rare_wardrobe.png`, `painted/wardrobe_legendary.png`, `painted/wardrobe_normal.png`, `painted/wardrobe_rare.png` |
| Recámara | Nightstand + candle | `bedroom_legendary_nightstand.png`, `bedroom_normal_nightstand.png`, `bedroom_rare_nightstand_lamp.png` |
| Recámara | Rug | `bedroom_legendary_rug.png`, `bedroom_normal_rug.png`, `bedroom_rare_rug.png` |
| Recámara | Mirror | no art |
| Recámara | Dresser | no art |
| Recámara | Chest (T1, 20 slots) | `bedroom_normal_chest.png`, `bedroom_rare_chest.png` |
| Recámara | Window curtains | no art |
| Cocina | Stove | `kitchen_legendary_stove.png`, `kitchen_rare_stove.png`, `painted/stove_legendary.png`, `painted/stove_normal.png`, `painted/stove_rare.png` |
| Cocina | Bread oven | no art |
| Cocina | Counter | no art |
| Cocina | Sink | no art |
| Cocina | Pantry | no art |
| Cocina | Table + chairs | `kitchen_legendary_table_stools.png`, `kitchen_normal_table.png`, `painted/worktable_legendary.png`, `painted/worktable_normal.png`, `painted/worktable_rare.png` |
| Cocina | Hanging pots | `kitchen_rare_pot_rack.png` |
| Cocina | Chest (T1, 20 slots) | no art |
| Sótano | Chest (T2, 50 slots) | `cellar_legendary_chest_left.png`, `cellar_legendary_chest_small.png`, `cellar_rare_chest_left.png`, `cellar_rare_chest_right.png`, `painted/chest_legendary.png`, `painted/chest_normal.png`, `painted/chest_rare.png` |
| Sótano | Treasure chest (T3, 100 slots) | `cellar_legendary_chest_left.png`, `cellar_legendary_chest_small.png`, `cellar_rare_chest_left.png`, `cellar_rare_chest_right.png`, `painted/chest_legendary.png`, `painted/chest_normal.png`, `painted/chest_rare.png` |
| Sótano | Shared chest (T4, 150, Legendario only) | no art |
| Sótano | Mini workshop (any profession) | `cellar_normal_workbench.png`, `cellar_rare_workbench_tools.png` |
| Sótano | Shelves | no art |
| Sótano | Barrels | `cellar_normal_barrels.png` |
| Sótano | Wall torch | no art |
| Sótano | Wine rack | `cellar_rare_wine_rack.png` |
| Jardín | Tree | `garden_legendary_tree_blossom.png`, `garden_normal_tree.png`, `garden_rare_tree_maple.png`, `painted/pottedtree_legendary.png`, `painted/pottedtree_normal.png`, `painted/pottedtree_rare.png` |
| Jardín | Flower bed / pots | `garden_normal_pot_big.png`, `garden_normal_pot_flower.png`, `garden_normal_pot_herb.png`, `painted/pottedtree_legendary.png`, `painted/pottedtree_normal.png`, `painted/pottedtree_rare.png` |
| Jardín | Pet house | `garden_normal_pet_bed_dog.png` |
| Jardín | Water trough | no art |
| Jardín | Fountain (Raro+) | `garden_legendary_fountain_koi.png`, `garden_rare_fountain.png` |
| Jardín | Small vegetable patch | no art |
| Jardín | Bench | `garden_rare_bench.png` |
| Jardín | Garden lantern | `garden_legendary_lantern.png` |

Costs per item and tier are in `art/housing_v1/ROOM_TIERS.md` and `art/housing_v1/costs/` (all Proposed).
