# STASIUM XII — Balance + Elements plan (handoff for the next agent)

Written 30 Sep 2026 at Mauro's request ("give me all the instructions to give
the Grok bot this task completely"). Game version when written: **0.1.82**
(branch `claude/stasium-xii-development-6ni8g2`, last commit before this file
`7a92c4b`). Mauro approved the plan below in chat ("What would u do to have the
best version?" → this plan). **Work one step at a time and show Mauro the
results before the next step.**

---

## 0. House rules (read first, do not skip)

1. Read `CLAUDE.md` and `docs/AGENT_HANDOFF.md` before touching anything.
   Everything listed there is approved by Mauro; do not change it unless this
   plan or Mauro says so.
2. Do **only** what this plan says. Anything not listed → ask Mauro first.
3. Every change gets a row in `docs/CHANGE_LOG_CLAUDE.md` (what, why, who
   asked, commit, version) **in the same push**.
4. Update `README.md` kit text and `docs/AGENT_HANDOFF.md` when a rule or number
   changes.
5. Run **all** suites before every push (Godot 4.7.2 headless):
   `for f in tests/run_*_tests.gd; do godot --headless --path . -s res://$f; done`
   All must say `0 failed`. When a test asserts an old number that Mauro changed,
   update the test to the new number (never delete or skip a test).
6. Work and push only on the assigned work branch. Never merge into `mobile` /
   `main`. No PRs unless Mauro asks.
7. Phone test build (only after Mauro has seen the simulator results):
   - stamp `backend/apk_version_stamp.gd` (VERSION_NAME / VERSION_CODE) and
     `export_presets.cfg` (`version/name`, `version/code`) to the next number;
   - `godot --headless --path . --export-debug "Android" builds/android/stasiumxii-mobile-debug.apk`
   - `git checkout -- art/tilesets/original/pending/brinewake/brine_elevation_punch.png.import stasium-ref/maps/brinewake/elevation_punch.png.import`
   - `git fetch origin 'refs/heads/apk/*:refs/remotes/origin/apk/*'`
   - `build_tools/publish_apk_branch.sh <version> "<short notes>"`
     (publishes release `mobile-<version>-debug`; the in-game Actualizar installs it).
8. The game stays **2D** (Dofus / Waven / Wakfu look). Bastion art is not touched.
9. The TEMPORARY balance-test kit (`backend/test_loadout.gd`, `ACTIVE = true`:
   all gear +5, all Stills, every class level 30 with 58 free points) stays ON
   until Mauro says the balance is good.

---

## 1. Goal: class roles + counter wheel (approved)

| Class | Role | Damage rank | HP rank |
|---|---|---|---|
| Gloam | assassin | 1st (most) | 5th (least) |
| Ironjaw | bruiser | 2nd | 2nd |
| Kestrel | ranged, safe at range | 3rd | 4th |
| Bastion | tank | 4th | 1st |
| Mender | support | 5th | 3rd |

**Counter wheel** — every class has a counter, and every class keeps a real way
to beat its counter:

| Class | Countered by | Its way to win vs the counter |
|---|---|---|
| Ironjaw | Kestrel (kites) | close with walk + Advance (3 AP, max 2 per turn), build 5 Impact (cap 5 since Mauro 5 Oct 2026), Crush stun |
| Kestrel | Gloam (dives while invisible) | blind shots reveal him on damage; Marks + Detonate burst his low HP |
| Gloam | Bastion (Aegis Break hits invisible, big HP) | backstabs ×1.35 and Shade angles |
| Bastion | Ironjaw (Crush stun, Shoulder push) | Snap Wall / Plant to block his path, outlast |
| Mender | Gloam / Kestrel (out-damage her heals) | Cleanse removes stun/debuffs, heals outlast slow fighters, Heartstop finisher |

**Target numbers:** each counter wins about 60–65% of its matchup; other
matchups near 50%; every class total 45–55%.

**Do NOT change Advance to 4 AP.** At 6 AP (levels 1–19) Advance + Strike must
fit in one turn, or Kestrel becomes a hard counter.

---

## 2. STEP 1 — class numbers (approved; numbers only, no new rules)

**Applied.** Mauro's picks match the table below (no difference). That table is the approved Step 1 plan. A same-day follow-up then set Strike to 14, Ironjaw Mastery growth to +1, and Heartstop enemy damage to 24, then Heartstop to 20 and class base HP (Bastion 100, Ironjaw 90, Mender 85, Kestrel 75, Gloam 70). The phone kit's `SPEND_DUEL_BUILDS` flag (temporary, default true) spends the 58 points like `tests/sim_duels.gd` `BUILDS` (Ward 0); set it false to leave them free. No APK.

| What | File | Now | New |
|---|---|---|---|
| Gloam Cut damage | `data/kits.gd` `CUT.base_damage` (≈ line 273) | 13 | **16** |
| Gloam HP per level | `backend/hero_progress.gd` `GROWTH["gloam"][1]` | 3 | **2** |
| Ironjaw Strike damage | `data/kits.gd` `STRIKE.base_damage` (≈ line 96) | 16 | **12** |
| Ironjaw HP per level | `backend/hero_progress.gd` `GROWTH["ironjaw"][1]` | 6 | **5** |
| Bastion Bash damage | `data/kits.gd` `BASH.base_damage` (≈ line 349) | 11 | **13** |
| Mender Heartstop Pulse | `data/kits.gd` `HEARTSTOP.requires_pulse` and `spend_pulse` (≈ line 256) | 4 | **2** |
| Mender Heartstop damage | `data/kits.gd` `HEARTSTOP.base_damage` | 10 | **18** |

Unchanged: Kestrel, Advance (3 AP, exactly 2 cardinal, max 2 uses per turn),
Crush 24 + stun at 4 Impact, Ambush 22, Mark Shot 2–5.

Also:
- `GROWTH` is `[Mastery, HP, Init, Ward]` per level above 1.
- Check the workbook `data/select_class_lock_kits_v0.6.json` and the README kit
  text; update the numbers there too and note "Mauro 30 Sep 2026 balance" next to them.
- Tests that assert the old numbers live in `tests/run_combat_tests.gd`,
  `run_event_hooks_tests.gd`, `run_matchmaking_tests.gd`, `run_sprite_tests.gd`,
  `run_stasis_tests.gd`, `run_vfx_tests.gd` (grep for `13`, `16`, `11`, `Heartstop`,
  expected HP like `50` from `22 × 1.35`, etc.). Update them to the new numbers.

### Check with the duel simulator
`tests/sim_duels.gd` (dev tool, not a suite) plays AI vs AI on the real
CombatSim, every class pair, both seat orders, the five Koliseo maps.

```
# level 30, 58 points spent per class (builds in the file), no gear:
godot --headless --path . -s res://tests/sim_duels.gd -- 2 lvl30 > duel_lvl30.txt
# level 1 base kits:
godot --headless --path . -s res://tests/sim_duels.gd -- 2 base > duel_base.txt
# only one class's matchups (faster):  ... -- 2 lvl30 ironjaw
# per-game lines: set env DUEL_VERBOSE=1
```
It is slow (Mender games go 30 rounds): about 30–60 min per mode with 2 games
per side. Run both modes in the background at the same time. The report prints
a win-% table (row vs column), total %, average damage and rounds, and spell use.

Before-numbers (0.1.82, partial run): level 1 → Ironjaw 75%, Kestrel 72%,
Gloam 50%, Mender 28%, Bastion 17%. Level 30 → Ironjaw 83%, Bastion 69%,
Kestrel 42%, Gloam 40%, Mender 25%. Mender dealt ~0 damage in duels.

**Show Mauro the new table.** If one matchup is outside the target, propose ONE
small tweak (for example Crush 24 → 20 before ever touching Advance) and wait
for his yes. Then build + publish a test APK so he can play it.

---

## 3. STEP 2 — elements, MONO only (riders + Residue, no Blends yet)

Source of truth: Mauro's PDF "STASIUM XII — Elements, riders, Residue, Blends"
(Locked chassis, 30 Sep 2026). The other agents' deck "Elements & Blends ·
Class options + balance" was written on 0.1.61 and is out of date (line of
sight exists since 0.1.70, so Steam now works; Ambush no longer needs Invisible
since 0.1.81; Advance max 2 per turn since 0.1.81).

Home elements (mono default): Kestrel Air, Ironjaw Earth, Mender Water,
Gloam Air (Neutral is not a second FLEX), Bastion Earth. Geometry spells stay
Neutral: Advance, Drop Shade, Fade, Cleanse, Plant, Snap Wall.

Riders on every connecting FLEX hit, with the approved fixes:

| Element | Rider (approved version) |
|---|---|
| Air | +1 max range only if the spell's max is already ≥ 3 → **Detonate 1–4 → 1–5; Mark Shot stays 2–5** (excluded on purpose). On a **melee** spell (Gloam Cut / Ambush): **+1 MP this turn after it connects** (hit and run). Crosswind needs wind (does not exist) → leave Open. |
| Earth | Caster Grounded until their next turn. **Bastion only (option C):** his Grounded blocks every push, not only Gust. Other Earth casters (Ironjaw): Grounded = Gust only (Gust does not exist yet → no effect). Push spells: **+8 collision vs a wall, at most once per target per turn, and it REPLACES the stagger 4** (does not stack). "Wall" = Snap Wall, blocked cell, board edge (same as the push-bounce rule). |
| Fire | Burn 4 at the target's next turn start, no stack, refresh. **Use the existing lava Burn family** (push-stack rules, Cleanse can remove it). Inferno needs a crit roll → Open. |
| Water | Heals +4 (Mend 20, Pulse Tap 14, ally Heartstop 36). Damage: **target −1 MP at the start of its next turn, max once per target turn** (clamp at 0). |
| Neutral | No rider, never boosted. |

Residue: FLEX damage writes the element on the target for **2 of the target's
own turns**. One Residue per body; same element refreshes; a new element
overwrites; death clears it; Cleanse does NOT strip it. Heals to allies write
no Residue; enemy Heartstop does.

Implementation notes:
- Rules live only in `backend/combat_sim.gd` (authoritative). The view
  (`board_view.gd`, `units/`, `vfx/`, `ui/`) only shows them. `board_view.gd` must
  not contain the text `hp` (a test enforces it).
- New backend helper scripts: use `preload`, not a new `class_name`.
- Show Residue as a small element badge on the unit and in the HUD status notes
  (like the push-stack notes in `ui/hud.gd push_stack_notes`).
- Online: `backend/net_session.gd` must carry the new unit fields.
- Add tests for each rider, the Residue clock, the Mark Shot exclusion, and the
  Bastion-only Grounded push block.
- Rerun the simulator, show Mauro, then a test APK.

---

## 4. STEP 3 — Blends (IN THE GAME since 0.1.105; Mauro 5 Oct 2026: every player picks 2 elements, no home element, 2 trophies per change, see docs/CHANGE_LOG_CLAUDE.md)

Only after the loadout screen can pick a real Secondary. Approved guard-rails:
- **Pin (Drift-Pin) blocks walking (MP) off the tile only — never Advance or
  Ambush.** A target Pinned on its last turn cannot be Pinned on its next.
- A body that took a Blend cannot take another until its own next turn ends.
- Spark chip 6 → **4**. Sleet at most once per target turn (max −1 MP). *Mauro 5 Oct 2026: Sleet now pushes 2 tiles back instead of −1 MP; later the same day 1 tile ("make that sleet only pushes 1 space").*
- Steam works as written (line of sight exists).
- Two mono teammates never share a Blend. Mender stays mono Water. Gloam stays
  Air / Neutral.

---

## 5. Open — do NOT decide these yourself (ask Mauro)

Stasis monster HP / EV numbers (provisional), real caster art, 2×2 bosses,
Crosshaven grass repaint, when to remove the TEMPORARY test kit, Crosswind /
Gust / crit roll (systems that do not exist), and anything else labelled Open
in `docs/CHANGE_LOG_CLAUDE.md`.
