# Housing package (PC only, docs only, for Claude)

Put together Fri 16 Oct 2026, 7:40 PM ET, from box files. **Nothing is wired in Godot and nothing is committed to any branch.** Every number is a Proposed placeholder.

Files in this package:
- `INDEX.md`: every art file, with pixel size, naming and tag (CONCEPT or IN-GAME-READY cutout, not wired).
- `ROOMS.md`: 3 tiers x 5 rooms.
- `DECOR.md`: furniture and decor catalogue, plus the placement rules.
- `plots.json` + `plots_preview.jpg`: the 5 Crosshaven plot houses.
- `art/housing_tiers/`: from `/workspace/cx_built/housing_tiers`.
- `art/housing_v1/`: from `/workspace/stasium-pc-look/ship/housing_v1`. The failed `_wip_autofill_FAILED` shells were left out.
- `cx_build_info_ref.json`, `cx_zones_ref.json`: references from the build.

## Rules and status
Status labels: **Luca-approved**, **Luca liked**, **Confirmed (Luca + Mauro)**, **Proposed**, **TBD/Open**.

**House tiers (Confirmed, Luca + Mauro)**
- Normal = bedroom only. Rare = bedroom + living + kitchen. Legendary = all 5 (bedroom, kitchen, living, sótano workshop, garden).
- Source: Luca's rule of 2026-10-13. Mauro confirmed it in PR #252, comment 6226722023, saying his "5 rooms" meant the Legendary set.

**Upgrades (Luca rule, 2026-10-13)**
- The house and each room upgrade in place, in order (Normal → Rare → Legendary), paying only the resource difference.
- The house and each room have separate costs (COSTS.md, Luca 13 Oct).
- New rooms open empty at Normal room tier. Room tiers are independent of the house tier.
- Placed furniture stays where it is, and chests keep their contents.

**Room utilities (Luca rule: every room has gameplay utility)**
- Bedroom: rest, plus displaying legendary sets.
- Kitchen: cooking.
- Sótano: crafting workshop (Luca liked it, 2026-10-13). Workshops per tier DECIDED by Luca 2026-10-16: Normal 1, Rare 2 (which ones OPEN), Legendary all.
- Garden: pets, plants and trees (Luca liked it).
- Living (Sala): utility **TBD by Luca**.

**Garden caps (Luca, 2026-10-13)**
| Tier | Pets | Farm animals |
|---|---|---|
| Normal | 1 | 1 |
| Rare | 2 | 3 |
| Legendary | all | all, with a bigger garden and a mini farm |

**Animals**
- Farm animals are bought one at a time and produce: cow → milk, sheep → wool, pig → food, hen → eggs.
- Pets give a bonus and have animations. The exact bonuses, prices and production times are Open.

**Life rule:** every NPC and animal moves. Nothing is baked in as a static image.

**Crosshaven city rule (Luca)**
- Houses sit on grass with plants only: no gardens, no fences, no dirt yards.
- No farm animals in the city. Dogs, cats and birds are OK.
- `housing_tiers/tiers.json` follows this: "No lots, fences, dirt or garden beds. Swap house_normal/rare/legendary in place at the plot point; plants are separate props on grass."

## Every approval or rejection found in the docs
| Date | Who | What | Source |
|---|---|---|---|
| 2026-10-13 | Luca | Approved: legendary bedroom without the chest, 3 armor mannequins in wall niches | PROGRESS_2026-10-13.md |
| 2026-10-13 | Luca | Approved: low knight statues in the legendary living room | PROGRESS_2026-10-13.md |
| 2026-10-13 | Luca | Liked: sótano as a crafting workshop | PROGRESS_2026-10-13.md |
| 2026-10-16 | Luca | Decided: workshops Normal 1, Rare 2, Legendary all (supersedes every-tier) | via Stasium Bot |
| 2026-10-13 | Luca | Liked: garden with pets, plants and trees | PROGRESS_2026-10-13.md |
| 2026-10-13 | Luca | Rule: house tiers 1/3/5 rooms | ROOM_TIERS.md, RECIPES.md |
| 2026-10-13 | Luca | Rule: in-place upgrades paying the difference ("Sí", open question Q7 closed) | ROOM_TIERS.md |
| 2026-10-13 | Luca | Rule: separate costs for the house and for each room | costs/COSTS.md |
| 2026-10-13 | Luca | Approved: mixed resources in recipes (v2) | costs/COSTS.md, RECIPES.md |
| 2026-10-13 | Luca | Rule: regional materials plus dungeon and world-boss drops per tier | ROOM_TIERS.md v2 |
| 2026-10-13 | Luca | Garden pet and farm-animal caps per tier (marked Proposed in the doc) | ROOM_TIERS.md |
| (date not recorded) | Mauro | Confirmed the house-tier rule | PR #252, comment 6226722023 |

I found no rejections in these docs.

## CONFLICT (unresolved, Luca's call)
- **The housing design wants gardens.** It gives garden caps per tier (1 pet + 1 farm animal / 2 + 3 / all), and the Legendary house gets a bigger garden with a mini farm (cow, sheep, pig, hen).
- **The Crosshaven city rule forbids them.** It says no gardens, fences or dirt yards, and no farm animals in the city. `tiers.json` and the 5 built plots follow it.
- **Mauro's look target also clashes with the city rule.** `docs/pc/look_target/crosshaven_city/mauro_target_crosshaven.jpg` shows each house with its own garden plot.
- **Not decided.** Possible ways out include an interior garden room (the `garden_*` art shows a separate room, not a yard) or keeping farm animals outside the walls. Those are only options, and the choice is Luca's.

## Missing art
- No stage-1 empty-plot art exists.
- Build stages 2–4 exist only for Normal (`stages/stage2_foundation`, `stage3_frame`, `stage4_house`). Rare and Legendary have only exterior concepts and cutouts.
- The Sala exists per tier only as sheet cells (`rooms/sala_tiers_1280x720_p1/_p2.png`). Its utility is TBD.
- Of the 15 room shells, only `sala_normal_empty.png` is clean. The other 14 failed the auto-fill and were left out of this package.

## OPEN (not decided anywhere; I didn't make anything up)
- How a player gets a house. RECIPES.md has a Proposed "plot bought from the city, 5,000", but nothing is confirmed.
- Visiting other players' houses.
- Storage beyond the Proposed chest tiers, including the T4 chest shared with the account bank.
- Limits per account and per character (how many houses or plots).
- **Sótano tier (resolved 2026-10-16):** Luca: workshops Normal 1, Rare 2, Legendary all; supersedes 'every tier'. OPEN: which 1 for Normal and 2 for Rare, and where they go (no sótano below Legendary).
- Pet bonuses, farm prices and production times, boss names, and star ratings (see the ROOM_TIERS.md open questions).

## The 5 plot houses in cx_built (5120x2880 plate px)
Sources: `build.py` (`PLOTS`, `place_plot`) and `build_info.json` (`plots`, `plot_houses`). The house layers are 031, 035, 041, 048 and 053 in `rosebud/layers.json`.
- The anchor is the bottom-centre of the house sprite at the plot point.
- The blocking footprint is an ellipse 0.85 × sprite width by 0.33 × sprite height, sitting on the anchor.
- Plants are scattered around each house (4, 6 or 9 by tier).
- Door/entrance point: **not encoded (unknown)**.
- `build.py` lists 6 plots. It drops one (normal, ref x 555) because it touches pavement or the wall, so 5 were built.

| Plot | House tier | 2nd tier field* | Plate x,y | Sprite w×h | Footprint w×h |
|---|---|---|---|---|---|
| P1 | rare | rare | 3340, 2099 | 238×185 | 202×61 |
| P2 | legendary | legendary | 3760, 2022 | 330×233 | 280×77 |
| P3 | rare | normal | 2650, 2526 | 238×185 | 202×61 |
| P4 | normal | rare | 3060, 2451 | 170×194 | 144×64 |
| P5 | normal | normal | 3500, 2360 | 170×194 | 144×64 |

\*`place_plot(p, tier, gtier)`: `gtier` is passed in but never used in the code, so what it means is unknown.

In the preview, red = sprite box, yellow = blocking footprint, magenta = anchor. All 5 plots sit in the south-east, inside the wall, near the south wall.
