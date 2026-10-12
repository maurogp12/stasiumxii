# Blightwood Hollow kit v2

Painted fantasy, no neon. Pivot bottom-centre unless noted. No cast shadows painted. Iso ground = 64x32 diamonds (+_2x). fx/* are alpha sprites meant for additive (moon, shafts, glows, eyes) or normal (fog) blend.

| file | size | pivot | use |
|---|---|---|---|
| trees/dead_tree_tall_a.png | 236x380 | (118,379) bottom-centre | scenery; tall trees scale 1.0-1.6 for framing |
| trees/dead_tree_tall_a_2x.png | 472x760 | x2 of above | 2x copy |
| trees/dead_tree_tall_b.png | 158x368 | (79,367) bottom-centre | scenery; tall trees scale 1.0-1.6 for framing |
| trees/dead_tree_tall_b_2x.png | 316x736 | x2 of above | 2x copy |
| trees/dead_tree_tall_c.png | 181x367 | (90,366) bottom-centre | scenery; tall trees scale 1.0-1.6 for framing |
| trees/dead_tree_tall_c_2x.png | 362x734 | x2 of above | 2x copy |
| trees/dead_tree_mid_a.png | 174x251 | (87,250) bottom-centre | scenery; tall trees scale 1.0-1.6 for framing |
| trees/dead_tree_mid_a_2x.png | 348x502 | x2 of above | 2x copy |
| trees/dead_tree_mid_b.png | 135x268 | (67,267) bottom-centre | scenery; tall trees scale 1.0-1.6 for framing |
| trees/dead_tree_mid_b_2x.png | 270x536 | x2 of above | 2x copy |
| trees/thorn_bush_a.png | 203x210 | (101,209) bottom-centre | dead bush |
| trees/thorn_bush_a_2x.png | 406x420 | x2 of above | 2x copy |
| trees/thorn_bush_b.png | 199x202 | (99,201) bottom-centre | dead bush |
| trees/thorn_bush_b_2x.png | 398x404 | x2 of above | 2x copy |
| props/gravestone_cross.png | 191x262 | (95,261) bottom-centre | prop |
| props/gravestone_cross_2x.png | 382x524 | x2 of above | 2x copy |
| props/gravestone_split.png | 151x236 | (75,235) bottom-centre | prop |
| props/gravestone_split_2x.png | 302x472 | x2 of above | 2x copy |
| props/gravestone_cracked.png | 189x269 | (94,268) bottom-centre | prop |
| props/gravestone_cracked_2x.png | 378x538 | x2 of above | 2x copy |
| props/crow_perched.png | 191x155 | (95,154) bottom-centre | prop |
| props/crow_perched_2x.png | 382x310 | x2 of above | 2x copy |
| props/fence_a.png | 238x220 | (119,219) bottom-centre | prop |
| props/fence_a_2x.png | 476x440 | x2 of above | 2x copy |
| props/hanging_cage.png | 138x238 | (69,0) top-centre (chain hook) | hang from branch |
| props/hanging_cage_2x.png | 276x476 | x2 of above | 2x copy |
| props/fence_broken.png | 198x203 | (99,202) bottom-centre | prop |
| props/fence_broken_2x.png | 396x406 | x2 of above | 2x copy |
| props/lantern.png | 108x176 | (54,175) bottom-centre | prop |
| props/lantern_2x.png | 216x352 | x2 of above | 2x copy |
| props/eyes_head.png | 99x156 | (49,155) bottom-centre | portrait/rare lurker; use fx/eyes_blink for dark gaps |
| props/eyes_head_2x.png | 198x312 | x2 of above | 2x copy |
| props/crow_walking.png | 207x159 | (103,158) bottom-centre | prop |
| props/crow_walking_2x.png | 414x318 | x2 of above | 2x copy |
| props/bones_skull.png | 229x159 | (114,158) bottom-centre | prop |
| props/bones_skull_2x.png | 458x318 | x2 of above | 2x copy |
| props/cobweb.png | 247x185 | (123,184) bottom-centre | decal between trunks/fences |
| props/cobweb_2x.png | 494x370 | x2 of above | 2x copy |
| props/wisp.png | 98x156 | (49,155) bottom-centre | floating fx sprite, add wisp_glow under |
| props/wisp_2x.png | 196x312 | x2 of above | 2x copy |
| ground/leaf_litter_tex256.png | 256x256 | n/a (tiling) | seamless texture for shader/blend |
| ground/leaf_litter_iso.png | 64x32 | (32,16) diamond centre | 64x32 iso ground tile |
| ground/leaf_litter_iso_2x.png | 128x64 | (64,32) diamond centre | 2x copy |
| ground/root_soil_tex256.png | 256x256 | n/a (tiling) | seamless texture for shader/blend |
| ground/root_soil_iso.png | 64x32 | (32,16) diamond centre | 64x32 iso ground tile |
| ground/root_soil_iso_2x.png | 128x64 | (64,32) diamond centre | 2x copy |
| ground/trodden_path_tex256.png | 256x256 | n/a (tiling) | seamless texture for shader/blend |
| ground/trodden_path_iso.png | 64x32 | (32,16) diamond centre | 64x32 iso ground tile |
| ground/trodden_path_iso_2x.png | 128x64 | (64,32) diamond centre | 2x copy |
| ground/moss_mushroom_tex256.png | 256x256 | n/a (tiling) | seamless texture for shader/blend |
| ground/moss_mushroom_iso.png | 64x32 | (32,16) diamond centre | 64x32 iso ground tile |
| ground/moss_mushroom_iso_2x.png | 128x64 | (64,32) diamond centre | 2x copy |
| fx/fog_layer_far.png | 1024x256 | (512,128) centre; tiles horizontally | fog depth 1: far=densest, draw far→near, slow parallax |
| fx/fog_layer_mid.png | 1024x256 | (512,128) centre; tiles horizontally | fog depth 2: far=densest, draw far→near, slow parallax |
| fx/fog_layer_near.png | 1024x256 | (512,128) centre; tiles horizontally | fog depth 3: far=densest, draw far→near, slow parallax |
| fx/light_shaft.png | 256x512 | (128,511) bottom-centre | additive light shafts through canopy |
| fx/light_shaft_2x.png | 512x1024 | x2 of above | 2x copy |
| fx/moonlight_pool.png | 256x128 | (128,64) centre | additive decal on ground, cold moon |
| fx/moonlight_pool_2x.png | 512x256 | x2 of above | 2x copy |
| fx/eyes_blink_f0.png | 32x16 | (16,8) centre | amber eyes blink frame 0 (open,half,closed,half); hold f0 2-5s, then f1-f3 at 12fps |
| fx/eyes_blink_f0_2x.png | 64x32 | x2 of above | 2x copy |
| fx/eyes_blink_f1.png | 32x16 | (16,8) centre | amber eyes blink frame 1 (open,half,closed,half); hold f0 2-5s, then f1-f3 at 12fps |
| fx/eyes_blink_f1_2x.png | 64x32 | x2 of above | 2x copy |
| fx/eyes_blink_f2.png | 32x16 | (16,8) centre | amber eyes blink frame 2 (open,half,closed,half); hold f0 2-5s, then f1-f3 at 12fps |
| fx/eyes_blink_f2_2x.png | 64x32 | x2 of above | 2x copy |
| fx/eyes_blink_f3.png | 32x16 | (16,8) centre | amber eyes blink frame 3 (open,half,closed,half); hold f0 2-5s, then f1-f3 at 12fps |
| fx/eyes_blink_f3_2x.png | 64x32 | x2 of above | 2x copy |
| fx/wisp_glow.png | 128x128 | (64,64) centre | additive glow under wisp/lantern-cold |
| fx/wisp_glow_2x.png | 256x256 | x2 of above | 2x copy |
| fx/heart_glow.png | 512x256 | (256,128) centre on Heart base | additive warm glow at Heart of the Blight |
| fx/heart_glow_2x.png | 1024x512 | x2 of above | 2x copy |
| fx/lantern_glow.png | 96x96 | (48,48) centre on lantern flame | additive warm lantern glow |
| fx/lantern_glow_2x.png | 192x192 | x2 of above | 2x copy |

## Mocks (Proposed, not in-game)
| file | size | use |
|---|---|---|
| mock_ingame_1280.png | 1280x720 | zone.png layout repainted with kit v2 |
| mock_heart_1280.png | 1280x720 | heart.png + heart_glow, lanterns, fog, eyes |
| before_after_zone.png | 1280x760 | before/after + 1:1 crops |

Source scripts: /workspace/stasium-pc-look/blightwood/v2/kit.py, mock.py
