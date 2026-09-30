# STASIUM XII — handoff for other agents

Written for any Claude / agent session that touches this repo. **Mauro owns
every rule, number and look below. Do not change, "clean up", rename, retune or
revert any of it unless Mauro commands it in that session.** Propose first;
wait for a clear yes (see `CLAUDE.md`). Every change goes in
`docs/CHANGE_LOG_CLAUDE.md` in the same push.

The goal Mauro set: **the game must look and play like Dofus / Waven / Wakfu** —
2D isometric, painted, readable on a phone. **Never move the game to 3D**
(Mauro rejected the 3D preview: "Dont put the game in 3d leave it as we had it").

Version history, reasons and Mauro's exact words are in
`docs/CHANGE_LOG_CLAUDE.md`. This file is the map of *what exists and where*.

## Hard rules

- Only Mauro merges into `mobile` / `main`. PRs only when he asks.
- `CombatSim` (autoload, `backend/combat_sim.gd`) is authoritative. The view
  (`board_view.gd`, `units/`, `vfx/`, `ui/`) never decides rules. `board_view.gd`
  must not contain the text `hp` (a test enforces it).
- Rules and kit numbers come from the GDD Blueprint, `README.md` and Mauro's
  sheets. Never invent an Open item. Open items stay labelled Open.
- Run every `tests/run_*_tests.gd` (Godot 4.7.2 headless) before pushing:
  `for f in tests/run_*_tests.gd; do godot --headless --path . -s res://$f; done`
- New GDScript helpers in `backend/` are loaded with `preload` (no new
  `class_name`: the headless class cache is not rebuilt without an editor import).
- New PNGs need `godot --headless --path . --import` before tests can load them.
  After any import / export, restore the two known-broken imports:
  `git checkout -- art/tilesets/original/pending/brinewake/brine_elevation_punch.png.import stasium-ref/maps/brinewake/elevation_punch.png.import`
- Phone builds: stamp `backend/apk_version_stamp.gd` + `export_presets.cfg`,
  export `builds/android/stasiumxii-mobile-debug.apk`, publish with
  `build_tools/publish_apk_branch.sh <ver> "<notes>"` (branch `apk/<ver>` →
  release `mobile-<ver>-debug`, which the in-game Actualizar button installs).

## Combat rules added from Mauro's sheets (do not retune)

| System | Where | Source |
|---|---|---|
| **Line of sight**: targeted spells need a clear line; solid props, tall drawn props, Snap Walls, tiles raised above both ends, and (for spells aimed at a fighter) visible fighters block it. Tile placements (Drop Shade, Snap Wall, Plant) ignore bodies. Out-of-sight tiles paint grey. | `CombatSim.has_line_of_sight / sight_blocker / spell_needs_sight`, `board_view.gd` (grey) | Mauro 30 Sep 2026 (video) |
| **Ambush ray** uses the same walls; an armed Shade on a clear side still arms it. | `_ambush_ray_walled` | Mauro 30 Sep |
| **Tall props block walking and sight** (ruins, bushes/"rubble", hay, crystals, ice shards, Windmere sparks, Stormspire's 4 drawn conduits, volcano / tower centrepieces). | `CellTagMap.SIGHT_PROPS / SIGHT_PROP_KEEP / SIGHT_CENTERPIECE`, must match `board/arena_look.gd` `prop_keep` / `centerpiece` (test) | Mauro 30 Sep |
| **Map push stacks** (push onto a hazard stacks 1–3 while live): mud Slow −1/−2/−3 MP; water Breathless (1 spell silenced 1/2/3 turns, same slot); lava Burn enter 10/10/15 + 4×2 / 5×3 / 5×4; Windmere ice (its water) Frozen no-melee 1/2 then Paralyzed; Stormspire charge (its water) Electrocuted −1/−2/−3 AP. Cleanse clears Stun + ONE family (highest stack; ties Slow > Breathless > Burn > Frozen > Electrocuted). | `CombatSim` `HAZARD_MAX_STACKS…`, `hazard_family_at`, `_apply_*`, `cleanse_pick` | "Map push stacks + Cleanse" PDF, 29 Sep |
| **Koliseo deploy zones** random every match, all tiles standable, both zones connected on foot. | `MatchFlow.sample_zone_pair(…, cell_ok, pair_ok)`, `CombatSim._zone_cell_ok / _zones_meet` | Mauro 30 Sep |
| **Stasis star difficulty** ★1–5 (`STAR_SCALE` hp/dmg multipliers are PROVISIONAL). Loot: ★1–2 Normal, ★3–4 + Rare, ★5 + Legendary. | `StasisCatalog.STAR_SCALE`, `GearBag.FAMILIES.min_star` | Mauro 29 Sep |
| **Fade / Invisible lasts 1 turn.** | `CombatSim.INVISIBLE_TURNS` | Mauro 29 Sep |

## Stasis monsters (kits, packs, planner)

- **Monster spells are data**: `backend/foe_kits.gd` (`SPELLS`, `BOSS_KITS`,
  `ROLE_KITS`, shapes, AP, cooldowns). Sheet numbers are the ★1 base and scale
  with `StasisCatalog.dmg_mult()`. HP / EV are Open (provisional).
- Bosses (1×1 tile for now; 2×2 is a later ticket — do not start it unasked):
  Sheaf Sovereign (all melee), Tide-Lord Brineclaw (melee + range spells),
  Slagheart (Caldera Crown) (melee + melee spells), Serra White-Spire Regent
  (range), High Coilspire (range). AP 7 (★5 = 8), MP 3. AOE cooldown = use,
  skip one turn, use again. White Fan = line 1–5. Hook = pull 1 toward the boss
  (water landing = Breathless 1). Grid Pulse = Charged pads + ground next to one.
- Room 1: ★1–2 = 2 brutes + skirmisher + 1 caster; ★3+ = 3 melee + 2 casters.
  Caster HP = 70% of the brute. Casters bolt at 3–7 with sight and never walk
  into 0–1 when they can shoot. Extra spawns: `StasisCatalog.extra_spawns`.
- Names are the sheet's (`StasisCatalog.DOORS`). Caster art is a **stand-in**
  (recoloured melee paintings, `build_tools/art/foes_hd/make_casters.py` →
  `art/stasis/foes/caster_*.png`). Real caster art is Open.
- Resolution: `CombatSim._foe_casts` (offers) / `_submit_foe_cast` (resolve).
  Planner: `StasisAi.plan` (AOE first when it connects, then the hardest hit,
  ranged band keeping, Retreat / Coil Step, Sheaf Wall with spare AP).
- VFX: `vfx/vfx_router.gd` `_foe_choreography` — bolts follow the Caster Bolt
  VFX sheet (cast flash 0.12 s, 18 tiles/s, capped 0.40 s, miss skips past);
  AOE flashes every covered tile + boss sigil flare (`units/boss_aura.gd flare()`).

## Maps

- Stasis rooms: `art/maps/stasis_v1/<biome>_room_<a|b>_15x15_tags.json`.
  `build_tools/fix_stasis_paths.py` keeps every tile reachable and opens fords
  where one wet tile forces a > 6 MP detour (Stasis test guards both).
  `build_tools/stasis_room_a_cover.py` = Mauro's option C cover on Room A.
- Koliseo maps: `art/maps/arena_colosseum_v2/tiled/*_15x15_tags.json` plus the
  painted looks in `board/arena_look.gd` / `art/maps/arena_look/` (from
  Mauro's pictures — do not repaint without his OK). In Crosshaven the green
  grass stamps ARE the mud tiles (a proposal to repaint them is waiting on Mauro).

## Look and feel (view only)

- Figures: `units/figure_read.gdshader` (real colours via the `v_modulate`
  varying — never multiply the texel by `COLOR` again; board light, breath,
  sway, foe lean / squash / mirror). `units/pawn.gd` owns idle, walk, attack,
  hit and the foe bodies (`FOE_BODY`, `FOE_KIND`).
- Bosses: 1.5× body, `units/boss_aura.gd` sigil (turn surge + AOE flare).
- Stasis foe art: `art/stasis/foes/*.png` (HD 288×320, `build_tools/art/foes_hd/`).
- Gear icons: `art/items/gear/` from the Blueprint set sheets
  (`build_tools/art/gear_icons/`, Sheaf pieces cut with BiRefNet masks).
- Ironjaw is the Berserker art Mauro picked (`build_tools/art/ironjaw_berserker/`).
- Stasis fight chrome: one-line ribbon during a fight (`StasisCatalog.room_ribbon`,
  `scenes/stasis_fight.gd _layout_overlay`), no walk / range tiles on monster
  turns (`BoardView._shows_turn_chrome`), monster turn-strip portraits framed on
  the creature (`CombatHUD._foe_crop`).
- **Bastion art is not touched unless Mauro asks.**

## Open / waiting on Mauro (do not decide these yourself)

See the "Open / waiting on Mauro" list at the end of
`docs/CHANGE_LOG_CLAUDE.md`. Notably: Stasis HP/EV numbers, real caster art,
2×2 bosses, Crosshaven grass repaint, Call Board −20% loot (PC only).
