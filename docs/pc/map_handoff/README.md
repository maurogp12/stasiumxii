# START HERE (confirmed by Luca 2026-10-16 6:50 PM ET)
The map state we stopped at is the **built Crosshaven** in `/workspace/cx_built/` (rosebud/plate.jpg 5120x2880, ground.jpg, walkmask.png, heightmap.png, river.png, bridge_h_*.png, route.json, zones_core.json, bridge_joins.json, housing_tiers/, crosshaven_rosebud_web.zip; last edit 2026-10-15 7:41 PM ET). Preview: `previews/crosshaven_current_plate_preview.jpg` (package path: `crosshaven/`). Continue from this build.

# Stasium XII — World MAP handoff (for Claude on Luca's PC)

Written Fri 16 Oct 2026, 6:50 PM ET by Grok Bot (Scenario Art). Scope: world map / board art only.
Ironjaw, combat VFX and character walks are out of scope. Repo: github.com/maurogp12/stasiumxii.
Note: most art below lives on the Scenario Art box (`/workspace/stasium-pc-look/...`), not in GitHub yet.
Ask Luca (or Grok Bot) for a pack of any folder you need. Where status says "unknown", this note does not guess.

## START HERE (2): the swamp (West Southbridge / Fen Edge / Gloomfen)
- Folder: `swamp/`. It has the latest map (`map_v8/`, from box `ship/west_southbridge_v1/`), `mocks/`, `pieces/` + `pieces.json`, `qa/`, plus the latest v15 renders: `swamp_v15b_tour.mp4`, `swamp_plate_v15.jpg`, `swamp_walkmask_v15.png` and `swamp_v15_tour_f*.jpg`.
- **Approval status: unknown.** Get Luca's sign-off before wiring. Swamp rules: mostly mud with mossy trails, boardwalks only over real water, the central hamlet is safe.
- Preview: `previews/swamp_plate_v15_preview.jpg`.

## Package layout (this folder)
`crosshaven/` built Crosshaven (START HERE 1: rosebud/, json, housing_tiers, build scripts, latest plate/full/tour v7) ·
`swamp/` · `rowanvale/` (WP10a ship + MANIFEST) · `windmere/` (WP10a ship incl. Frost Spire) · `zone_joins/` (raws only) ·
`l9_board/` (ship v1.3 + raw v1 & v1_1 + wiring draft + decor v2) · `farm_kit/` · `dark_forest/` (blightwood_kit_v3) ·
`coast_dock/` (outskirts_themes) · `lakes/` (lakes_v1) · `gate_reports/` · `previews/`.
Borders/seamless work is already on GitHub in open PR #375 (`pc/world-seamless`), so no copy here.

## Skipped (still on the Scenario Art box; ask for a pack)
- `/workspace/cx_built/frames*/`: render frames, about 6 GB.
- `/workspace/cx_built/test*/` and `/workspace/cx_built/crops/`: scratch.
- `/workspace/cx_built/objects.pkl`: 27 MB pickle.
- `/workspace/cx_built/crosshaven_rosebud.zip`, `crosshaven_rosebud_web.zip` and `rosebud_web/`: duplicates of `rosebud/`.
- `/workspace/cx_built/crosshaven_built_tour{,_v4,_v5,_v6}.mp4` and `crosshaven_built_full{,_v4,_v5}.jpg`: older versions.
- `/workspace/stasium-pc-look/ship/west_southbridge_v1/map_v1..map_v7b/`, `cutouts/`, `raw/`, `src/`, `/workspace/swamp_v15_raw.mp4` and `swamp_v15_tour.mp4`: older swamp versions.
- `/workspace/stasium-pc-look/raw/l9_outdoor_board/v1_4/`: not a confirmed version.
- `blightwood_kit` v1 and v2.

## 1. Done / approved
- **L7 light, rim, cast glow**: PR #239, merged 2026-10-03.
- **L9 Crosshaven outdoor board redo** (option A: sandstone slabs + wet-earth edge, picked by Luca): PR #242, merged 2026-10-04.
  Kit `ship/l9_outdoor_board/` is at v1.3 (TA review fixes). The world gate (`--package world`) PASSES (blocks row PASS, 45 placements agree with `crosshaven_15x15_tags.json`).
- **L9b Crosshaven v1 decoration** (leaf frame, clearing, sky): PR #254, merged 2026-10-04. Decor v2 (`ship/l9_v1_decor_v2/`) approved by Luca, handed to Stasium Bot.
- **Crosshaven open world**: #210, #212 (kit v6), #214 (v7 dense squares), #223 (atlas + gates), #238, #240 (WP12 seamless plane), #246 (landed on main): all merged 2026-10-03.
- **Outskirts**: island coast, Eastmarch beach kit, Northgate snow: PR #241, merged 2026-10-04. (Note: #241 is the outskirts/coast PR, not the swamp.)
  Repo water regraded to Eastmarch blue: #251, merged.
- **Town NPCs, stand-in sprites on the coast**: #253, merged 2026-10-04. WP6/WP6b NPCs + missions: #227, #230, #232, merged.
- **Northgate Crags design B**: #295, merged 2026-10-10. **Drowned Abbey dungeon** (Southbridge 30–40): #349, merged 2026-10-11.
- **Farm kit** (`ship/farm_kit/`): world gate 0 FAIL / 79 PASS / 19 WARN. Kit handed to Stasium Bot; in-map mock shown to Luca.

## 2. In progress
- **WP10a Rowanvale + Windmere**: PARKED 2026-10-03 (plan changed to Crosshaven only; parked, not rejected).
  - `ship/wp10a_rowanvale/`: 45 tiles, 16 props incl. animated `old_windmill` (12-frame sails). World gate PASS (75 files).
  - `ship/wp10a_windmere/`: snow tiles, pines (tree_conifer), Frost Spire. World gate PASS (70 files).
  - Left to do, from the READMEs:
    - Rowanvale: a build step that writes the meta straight from the measured PNGs; rebuild orchard_soil_a/b from orchard_soil_v2; visual sign-off on the hedge trim and beehive recolour; regenerate the previews.
    - Windmere: rebuild snow_grass_a/b/c; add walkable ice_crust tiles; set glossy_ice to walkable:false; brightness match; regenerate the previews. The v2 swatches are 1280x720, not 1024x576.
  - "Restore WP10a full widths/heights for the world checker": an executor was working on this. I didn't find a separate output, so check the READMEs' "Last check" lines before trusting it.
- **Zone joins (WP10a)**: only the raws exist so far, in `raw/wp10a_joins/`. They cover:
  - `stone_ford.png`: Stoneford→Rowanvale causeway.
  - `cliff_pass_steps.png`: Northgate→Windmere steps.
  - `sign_rowanvale.png` and `sign_windmere.png`.

  There is **no `ship/wp10a_joins/` folder yet**. Blend strips, road crossings, border end caps and mocks are not built. Brinewake, Slagcrown and Fen Edge joins have not been started.
- **L9 board props gate**: `check_report_props_l9_outdoor_board.md` still shows FAIL ("dimensions must be divisible by 4 for BC7"). The same FAIL is in `check_report_props_l9_v1_decor.md` and `check_report_props_farm_kit.md`. This is the "gate 0 FAIL" item.
  - The v1.1 polish raws are in `raw/l9_outdoor_board/v1_1/`, and a `v1_4/` folder also exists.
  - The wiring note `ship/l9_outdoor_board_WIRING_NOTE.md` is a DRAFT and was never sent. Its dependency, L7 #239, is now merged, so that wait is over.
- **Swamp (West Southbridge / Fen Edge, Gloomfen)**: `ship/west_southbridge_v1/` has map_v1 to map_v8, plus mocks, pieces and qa. The latest box renders are `swamp_v15_tour.mp4`, `swamp_v15b_tour.mp4`, `swamp_plate_v15.jpg` and `swamp_walkmask_v15.png`. Approval status is unknown.
- **Dark forest (Blightwood Hollow)**: kits `ship/blightwood_kit` v1 to v3. **Open PR #378** `pc/world-blightwood`.
- **Seamless borders + painted snow pines**: **open PR #375** `pc/world-seamless`.
- **Crosshaven world scene** (click-to-walk, exits, weather): **open PR #211**.
- **NPC map population**: NPC sprites/concepts are in `ship/npc_sprites`, `ship/npc_concepts` and the `check_report_npc_*.md` files (19 NPCs). Posting the keys and builds is still open.

## 3. Open decisions waiting on Luca
- Farm kit placement: Crosshaven or Rowanvale.
- The L9 v1 vs v1.1 comparison: not shown to him yet.
- Whether to unpark WP10a (Rowanvale/Windmere) and the joins.
- The `mock_l9_board_2x_v13.png` board (128x64 cells at 2x) as the reference board: not confirmed.
- Swamp v15 sign-off.

## 4. Next steps
1. Fix the BC7 /4 dimension FAILs in the props gate for l9_outdoor_board, l9_v1_decor and farm_kit, then rerun `tools/check_assets.py` (props + world).
2. Once the gate is 0 FAIL / 0 WARN on `blocks` and Luca has ruled, send the L9 wiring note to Stasium Bot.
3. Only if Luca unparks WP10a:
   - finish the README fix lists;
   - build `ship/wp10a_joins/` (blend strips, road crossings, border caps, mocks);
   - then do Brinewake, Slagcrown and Fen Edge.
4. Review and land PRs #375 and #378, plus #211 if it's still wanted.
5. Get Luca's sign-off on swamp v15, then wire it.
6. NPC population: post the keys and builds for the remaining NPCs.
   - Every NPC and animal moves and has day/night behaviour.

## 5. Luca's standing map rules
- Plazas go inside the wall, in open space, never on streets.
- Crosshaven houses sit on grass with plants. No gardens, fences or dirt patches. No farm animals in the city.
- Swamp: mostly mud with mossy trails. Boardwalks only over real water. The central hamlet is safe.
- Every obstacle gets a see-through fade when the player is behind it.
- Every NPC and animal moves (none stand frozen) and has day/night behaviour.
- Art style: HD painted, never pixel art and never 3D. 2:1 diamond. Key light #fff0c8 from the top-left, shade #5a6fa0, no baked cast shadows. Linear filter, no mipmaps, straight alpha.
- Never invent kit or gameplay numbers.

## 6. File / PR index
| What | Where |
|---|---|
| WP10a manifest | `/workspace/stasium-pc-look/raw/wp10a/MANIFEST.md` (+ manifest.json); spec `docs/pc/ZONES_BUILD_SPEC.md` §WP10a @ a4f667e (branch `claude/pc-zones-spec`) |
| WP10a scripts | `/workspace/scratch/wp10a/` (rv_*.py, wp10a_atlas.py, patches/) |
| WP10a kits | `ship/wp10a_rowanvale/`, `ship/wp10a_windmere/`, `ship/wp10a_file_list.txt`, raws `raw/wp10a_rowanvale|windmere/` |
| Joins raws | `raw/wp10a_joins/` (README.txt) |
| L9 board | `raw/l9_outdoor_board/` (v1_1, v1_4), `ship/l9_outdoor_board/` v1.3, `ship/l9_outdoor_board_WIRING_NOTE.md`, packs `/workspace/l9_outdoor_board_v1*.tar.gz` |
| L9 decor | `ship/l9_v1_decor/`, `ship/l9_v1_decor_v2/` |
| Farm kit | `ship/farm_kit/`, mocks `previews/farm_kit/` |
| Swamp | `ship/west_southbridge_v1/`, `/workspace/swamp_v15*`, `swamp_walkmask_v15.png` |
| Dark forest | `ship/blightwood_kit*`, PR #378 |
| Crosshaven | `ship/crosshaven_*`, `ship/housing_v1`, `ship/districts_v1`, `ship/map_polish*`, PR #211 |
| Gate reports | `ship/check_report_world_*.md`, `ship/check_report_props_*.md` |
| Merged PRs | #210 #212 #214 #217 #223 #224 #227 #230 #232 #238 #239 #240 #241 #242 #246 #251 #253 #254 #295 #349 |
| Open map PRs | #211, #375, #378 |
(`ship/`, `raw/` and `previews/` are under `/workspace/stasium-pc-look/`.)
- `lakes_v1/_archive_v1/`: older lakes version.
