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
| **Line of sight**: targeted spells need a clear line; solid props, tall drawn props, Snap Walls, Steam tiles, Slagcrown's boiling (steaming) water (`CellTagMap.SIGHT_TERRAIN`, Mauro 5 Oct 2026), and (for spells aimed at a fighter) visible fighters block it. Tile placements (Drop Shade, Snap Wall, Plant) ignore bodies. Out-of-sight tiles paint grey. | `CombatSim.has_line_of_sight / sight_blocker / spell_needs_sight`, `board_view.gd` (grey) | Mauro 30 Sep 2026 (video); raised ground never blocks since Mauro 5 Oct 2026 |
| **Invisible**: hidden from the looking player (hot-seat = active seat, online = owner, Stasis = player sees own hero); never a named target; blind attacks on any open tile in reach while an enemy is hidden; damage reveals. | `CombatSim._append_blind_casts / _resolve_whiff / _reveal_if_hurt`, `BoardView._viewer_sees_seat`, `VfxDirector.set_seat_hidden`, `NetSession._redact_hidden_intent_cells` | Mauro 30 Sep (screenshot) |
| **Ambush ray** uses the same walls; an armed Shade on a clear side still arms it. | `_ambush_ray_walled` | Mauro 30 Sep |
| **Tall props block walking and sight** (ruins, bushes/"rubble", hay, crystals, ice shards, Windmere sparks, Stormspire's 4 drawn conduits, volcano / tower centrepieces). | `CellTagMap.SIGHT_PROPS / SIGHT_PROP_KEEP / SIGHT_CENTERPIECE`, must match `board/arena_look.gd` `prop_keep` / `centerpiece` (test) | Mauro 30 Sep |
| **Map push stacks** (push onto a hazard stacks 1–3 while live): mud Slow −1/−2/−3 MP; water Breathless (1 spell silenced 1/2/3 turns, same slot); lava Burn enter 10/10/15 + 4×2 / 8×3 / 12×4; Windmere ice (its water) Frozen no-melee 1/2 then Paralyzed; Stormspire charge (its water) Electrocuted −1/−2/−3 AP. Cleanse takes away ONE debuff per cast (Mauro 6 Oct 2026): Stun, then the highest stack (ties Slow > Breathless > Burn > Frozen > Electrocuted), then Sparked / Pinned / Mire / MP skip / Water slow / Magma / Residue. | `CombatSim` `HAZARD_MAX_STACKS…`, `hazard_family_at`, `_apply_*`, `cleanse_pick`, `cleanse_one` | "Map push stacks + Cleanse" PDF, 29 Sep |
| **Koliseo deploy zones** random every match, all tiles standable, both zones connected on foot. | `MatchFlow.sample_zone_pair(…, cell_ok, pair_ok)`, `CombatSim._zone_cell_ok / _zones_meet` | Mauro 30 Sep |
| **Stasis star difficulty** ★1–5 (`STAR_SCALE` hp/dmg multipliers are PROVISIONAL). Loot: ★1–2 Normal, ★3–4 + Rare, ★5 + Legendary. | `StasisCatalog.STAR_SCALE`, `GearBag.FAMILIES.min_star` | Mauro 29 Sep |
| **Fade / Invisible lasts 1 turn.** | `CombatSim.INVISIBLE_TURNS` | Mauro 29 Sep |
| **Bastion is the shield class**: Ward moved from Mender to Bastion and Aegis Break left the kit (Bastion: Bash, Plant, Hold Line, Snap Wall, Ward; Mender: Mend, Pulse Tap, Cleanse, Heartstop, Rekindle). Ward = 3 AP + 3 Aegis, no roll, +20 shield on every ally within 3 tiles including Bastion, stacks to 60, no clock (lasts until broken). Thorns: while Bastion has a shield, an adjacent enemy that hits him takes 6. | `SpellKits.WARD`, `CombatSim._resolve_team_ward`, `_bastion_thorns`, `HeroAI._team_ward` | Mauro 6 Oct 2026 |
| **Kestrel aims better far away**: Mark Shot and Detonate hit 70 / 75 / 80 / 85 / 90% at 1 / 2 / 3 / 4 / 5 tiles; every other spell keeps the shared HitBands. | `SpellKits.KESTREL_HIT_BY_DISTANCE`, `CombatSim._spell_hit_chance` | Mauro 6 Oct 2026 |
| **Top-bar targeting + stats card**: tap a portrait / side card with a spell armed = cast on that fighter if legal (range + sight); hold = stats card. | `CombatHUD.unit_card_tapped`, `unit_info_text`, `board_view._on_unit_card_tapped` | Mauro 6 Oct 2026 |
| **Plain-words spell cards**: the hold card of every spell starts with `SpellTooltip.simple_lines` (cost, reach, what it does, power dots, miss chance, back bonus, element), numbers from `SpellKits.SPELLS`; update its text when a spell rule changes. | `data/spell_tooltip.gd`, `CombatHUD._fit_tooltip_card` | Mauro 6 Oct 2026 |
| **Snap Wall knock-down**: Snap Wall on the caster's own wall removes it (1 AP, no Aegis gate) and refunds 2 Aegis (cap 4); event `snap_wall_break`. Not an attack. | `CombatSim._resolve_snap_wall_break`, `board_view._snap_wall_break_cell` | Mauro 6 Oct 2026 |
| **Drift-Pin Pins only on a hit**: the Air + Earth push Pins (no walking next turn) only when it hits a wall, the edge or a body (8 damage); a free slide does not Pin. | `CombatSim._blend_drift_pin` | Mauro 6 Oct 2026 |
| **Ambush front landing**: a blocked back tile does not cancel Ambush; Gloam lands on the front tile (one step before the enemy on the origin side) and still hits. Both blocked rejects `illegal_back`. | `CombatSim._ambush_landing_from` | Mauro 6 Oct 2026 |
| **Ambush without Invisible**: Gloam's own tile is always an Ambush origin (armed Shades add angles). | `CombatSim.AMBUSH_SELF_ALWAYS / _ambush_self_origin` | Mauro 30 Sep |
| **Advance max 2 uses per Ironjaw turn** (reject `advance_limit`). | `CombatSim.ADVANCE_USES_PER_TURN`, `advance_uses` reset in `_begin_unit_turn` | Mauro 30 Sep |
| **A turn without an attack drops stacks**: Marks and Residue a fighter left on an enemy it did not attack that turn, and the fighter's own Impact / Umbral / Aegis when it attacked no enemy at all (a miss counts as an attack); Mender's Pulse only drops on a turn with no spell cast at all (healing keeps it, Mauro 6 Oct 2026). | `CombatSim._note_attacks`, `_drop_unattended_marks`, `SELF_STACKS` | Mauro 5 Oct 2026 |
| **No trap on any Koliseo map**: every standable tile reaches every other, and no single fighter standing anywhere can cut anyone off. Keep it true when editing a map (the test fails otherwise). | `tests/run_koliseo_maps_tests.gd` `_test_every_map_has_a_way_out`, `build_tools/art/koliseo_no_traps.py` | Mauro 5 Oct 2026 |
| **Advance cannot jump over big obstacles**: the tile jumped over may be water, mud, lava or a fighter, but not a rock / crate / pillar / pit / centrepiece, wall, Snap Wall or Steam (reject `advance_blocked`). | `CombatSim._advance_jump_blocked` (sight blockers without bodies), called by `_advance_stand_reason` | Mauro 5 Oct 2026 |

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
  ranged band keeping, Retreat / Coil Step, Sheaf Wall with spare AP). Walks
  follow the real route (`CombatSim.walk_field`), never straight-line distance
  (packs got stuck behind walls). Dead monsters fade off the board
  (`Pawn._vanish_if_monster`); heroes keep their downed body. Monster walks use
  per-body gaits (`Pawn.foe_gait`); monster turns skip the big turn banner
  (`BoardView._quiet_handoff`).
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
- Walk: Wakfu-style glide (`ViewMotion.glide`, Mauro 2 Oct 2026): constant speed, continuous stride, two soft footfalls per tile, ease only at path ends, camera follows when zoomed. Do not bring back the per-tile plant hold.
- Regular Stasis monsters: 1.18× body (`Pawn.TRASH_SCALE`, Mauro's yes).
- Bosses: 1.5× body, `units/boss_aura.gd` sigil (turn surge + AOE flare).
- Stasis foe art: `art/stasis/foes/*.png` (HD 288×320, `build_tools/art/foes_hd/`).
- Gear icons: `art/items/gear/` from the Blueprint set sheets
  (`build_tools/art/gear_icons/`, Sheaf pieces cut with BiRefNet masks).
- Ironjaw is the Berserker art Mauro picked (`build_tools/art/ironjaw_berserker/`).
- Stasis fight chrome: one-line ribbon during a fight (`StasisCatalog.room_ribbon`,
  `scenes/stasis_fight.gd _layout_overlay`), no walk / range tiles on monster
  turns (`BoardView._shows_turn_chrome`), monster turn-strip portraits framed on
  the creature (`CombatHUD._foe_crop`).
- Tap picking (phone): the front painted diamond wins, elevation aware (`TouchAdapter.front_cell`); enemy-only spells never pick the caster's own body (`BoardView._living_pawns_for_pick(spell)`), so the tiles behind the caster stay tappable for blind attacks. Mauro 30 Sep.
- **Bastion art is not touched unless Mauro asks.**

## TEMPORARY: balance-test kit (ON since 0.1.79)

`backend/test_loadout.gd` `ACTIVE = true` gives the phone every set piece at
+5 fusion, 99 fragments of every Still, and every class at level 30 (real
progress backed up in `HeroProgress.test_backup`). `SPEND_DUEL_BUILDS`
(temporary, default true) spends those 58 points like `tests/sim_duels.gd`
`BUILDS`: Kestrel and Gloam 40 Mastery / 16 Vitality / 2 Swift, Ironjaw
34 / 22 / 2, Mender 24 / 32 / 2, Bastion 20 / 36 / 2, Ward 0. Set the flag
false to leave all 58 free again. Gear + levels go into hot-seat Koliseo. It is
**temporary by Mauro's order** — do not remove it until he says the balance is
good, and do not leave it in once he does. Revert = `ACTIVE = false` (the next
load takes back only the tagged pieces and granted fragments), then delete
the file and its hooks (listed in its header and in the 0.1.79 change-log row).

## Balance plan

Step 1 class numbers are in the game (Mauro 30 Sep 2026 balance): Gloam Cut 16 and HP growth +2, Ironjaw Strike 14, HP growth +5, and Mastery growth +1, Bastion Bash 13, Mender Heartstop spends 2 Pulse and deals 20. Mauro 1 Oct 2026 balance: Gloam Ambush 26 and Cut 17 (Mauro 5 Oct 2026 try: Cut 2 AP / 13), Kestrel Mark Shot 8 (round 2 undid 7), Bastion HP growth +7, Ironjaw Crush 20, then 12 on Mauro 5 Oct 2026 ("crush should do less damage because it stuns you") (a stunning Crush spends ALL Impact; Mauro 5 Oct 2026: Impact cap 5 and the stun needs the full 5, was 4), Sleet removed and Spark moved to Air + Water: 10 damage ignoring resist + 40% less healing until the end of the target's next turn; Air + Fire has no Blend; each Fire hit adds a Burn stack (cap 3, 4 HP per stack) (Mauro 6 Oct 2026), Mender Heartstop 22 (Mauro 5 Oct 2026 try: Heartstop 4 AP, and Pulse Tap can also hit an enemy for 10, 2 AP, 1 Pulse); class base HP Bastion 110, Ironjaw 90, Mender 85, Kestrel 75, Gloam 75 (`CombatSim.CLASS_BASE_HP`). Advance stays 3 AP (max 2 per turn). Koliseo 2v2 / 3v3 hot-seat exists (`team_size`, see the change log); online teams are not built yet. Step 2 (mono element riders + Residue) is in the game since 0.1.104 (Mauro 4 Oct 2026: "its time to continue on elements"); rules in `SpellKits.spell` (Air range, Water heal) and `CombatSim._flex_target` / `_flex_caster` (the rest), shown by `CombatHUD.element_notes` and the Residue gem on the team ring (`Pawn.RESIDUE_TINT`). Step 3 is in the game since 0.1.105 (Mauro 5 Oct 2026: "everyone will choose their own elements there is no primary", 2 trophies per change, "1 attack plus other attack = element"): picks in `HeroProgress.set_elements` (screen `scenes/elements_screen.gd`), fight map `unit.spell_elements` via `GearBag.clean_spell_elements` → `SpellKits.spell_for`, Blends in `CombatSim._try_blend` and the `_blend_*` / `_end_turn_elements` / `_start_turn_elements` helpers, Mender option A in `CombatSim._infuse`. Placeholders Mauro has not ruled on: Mire lasts the target's next turn; Spark / Drift-Pin push away from the caster; Magma paints the tile the target ends its next turn on; Steam and Magma end at the blender's next turn start; unpicked = Neutral. The counter wheel and targets are in `docs/BALANCE_PLAN_HANDOFF.md`.

## Dungeon party (in progress)

Plan and Mauro's answers: `docs/DUNGEON_PARTY_PLAN.md`. Engine, AI companions (`backend/hero_ai.gd`) and party difficulty (`StasisCatalog.PARTY_SCALE` / `STAR_SCALE`, tuned with `tests/sim_dungeons.gd`) are in; the finder screen and the online role queue are not built yet. AI fill is only a fallback when no player is found.

## Online server

Mauro's game server is `68.201.184.207` (`NetSession.DEFAULT_SERVER`, port 7777, ENet/UDP). It runs the dedicated host (`--dedicated 7777`) and must run the same build as the phones. Online play is 1v1; online 2v2 / 3v3 is not built yet.

## Open / waiting on Mauro (do not decide these yourself)

See the "Open / waiting on Mauro" list at the end of
`docs/CHANGE_LOG_CLAUDE.md`. Notably: Stasis HP/EV numbers, real caster art,
2×2 bosses, Crosshaven grass repaint, Call Board −20% loot (PC only).
