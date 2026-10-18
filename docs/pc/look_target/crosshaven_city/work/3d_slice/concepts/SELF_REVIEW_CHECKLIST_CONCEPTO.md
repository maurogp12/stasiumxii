# 🖼️ IMAGEN / CONCEPTO, TODAVÍA HAY QUE CONSTRUIRLO
STASIUM XII 3D vertical slice: concepts only (3D_ART_SKILL.md §8). No models built.
Tool: Scenario `model_xai-grok-imagine-image-2-0`, 2k, 1 output each, using the fixed §6b template and negative prompt. 13 jobs × 16 CU = **208 CU**; the log is in ../raw/generation_log.jsonl. This model exposes no seed. No style model was trained. No Meshy, no image-to-3D.

| Check (§8) | Status |
|---|---|
| Look: gritty, realistic, earthy, worn | PASS (all 13) |
| Height in metres + 1.8 m human | Target heights are in the JSONs. scale_sheet_CONCEPTO.jpg shows them against a 1.8 m bar, with heights forced to the targets rather than measured |
| Pivot at foot centre, front +Z | Specified in the JSONs. Applies when the models are built |
| Tri budget + LODs | Specified in the JSONs. N/A until build |
| PBR, no baked dramatic shadows | Flat lighting OK. Props show light AO and a faint contact shade |
| No floating or broken parts, no kit gaps | Mostly OK. Cloak hems and the stall awning hem are slightly ragged. The barricade's lashing is solid |
| Original, nothing copied | PASS, all original prompts with no IP names |

Known weaknesses: the A-pose arms are about 25–35°, and the chars were upscaled 1584→2048 px (1.29×). Gear layers read visually but are painted, not separated. The wall walkway sits on the front face; it should be confirmed as the inner side. The env pieces are mood keys, not the streetplan.json layout.
