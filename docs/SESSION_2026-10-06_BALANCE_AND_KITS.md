# STASIUM XII — 6–7 Oct 2026 session: what changed, why, and what is next

This document is for the next team (people or agents). It explains **every
gameplay change made in the 6–7 Oct 2026 Claude session**, **why** each one
was made (with Mauro's own words), **where it lives in the code**, **how it
is tested**, and **what is still open**. Versions 0.1.133 → 0.1.137.

The short version of the change log is in `docs/CHANGE_LOG_CLAUDE.md` (one
row per version). The table of approved systems is in
`docs/AGENT_HANDOFF.md`. This file is the long explanation behind both.

Rules that still apply to everyone (from `CLAUDE.md`):

- Change nothing unless Mauro approves or commands it. Propose first.
- Record every change in `docs/CHANGE_LOG_CLAUDE.md` in the same push.
- Run all 24 `tests/run_*_tests.gd` suites (Godot 4.7.2 headless) before
  pushing.
- The phone APK ships from `mobile`. Test builds go to `apk/<version>`.

---

## 0. The design goals Mauro set in this session

These goals drove almost every change below. Read them first.

1. **A tactical game.** "That's the point, a tactical game." A matchup is
   decided by positioning, timing and reading the enemy, not by class pick.
2. **Every class has a counter, and a way to beat its counter.**
   "Remember matches have to be balanced each class should have a counter
   but also a way to win." Example he gave: "bastion should counter gloam
   but gloam with strike [skill] make it possible to win."
3. **Counter strength: about 55–60%.** Mauro asked whether 60% was too high.
   Agreed target: the counter wins **55–60%** of its matchup, never more
   than 65%. Everything else is near 50%; each class total 45–55%.
4. **The counter wheel (1v1):**

   | Class | Countered by | Its way to win against the counter |
   |---|---|---|
   | Ironjaw | Kestrel (kites him) | close with Advance, build Impact, Crush stun |
   | Kestrel | Gloam (dives invisible) | Flare reveals him, Vault away, Snare Trap, Marks + Detonate burst |
   | Gloam | Bastion (Thorns) | strike in bursts, backstabs ×1.35, Shade angles |
   | Bastion | Ironjaw (shield breaker, Crush stun) | Snap Wall / Plant to block, outlast with HP |

5. **Mender is a 2v2 / 3v3 full support only.** "Lets be honest mender will
   never pvp 1vs1 so dont count him." "Mender should be focus in 2vs2 and
   3vs3 as full support." Mender is **left out of 1v1 balance**.
6. **Bastion is the tank / support class.** "The idea is that bastion should
   focus in health and shield not focusing in direct damage." "The whole
   point of shield is to shield his team mates like mender." But also: "he
   should have the ability to take over gloam in 1vs1."
7. **Fights must not drag.** "Matches should be max of 10 minutes", "At 3vs3
   im willing to do 15 mins max", "Longer fights just gets boring."
8. **Elements exist to give the countered side a chance.** "The whole point
   of element is to make the counter have a possibility to win."
9. **Every spell explained so a 5-year-old understands.** Cost and effect
   on the hold card of every spell.

---

## 1. Changes, one by one

Each entry: **what**, **why** (Mauro's words), **where** (code), **tests**.

### 1.1 Ambush lands in front when the back tile is blocked (0.1.133)

- **What:** Gloam's Ambush still teleports behind the enemy. If that back
  tile is blocked (rock, crate, wall, body, void, water, lava), Gloam now
  lands on the tile **in front** of the enemy and still hits. Only if the
  front tile is also blocked does Ambush refuse and refund.
- **Why:** Mauro (video): "ambush should work even if there is an obstacle
  just would place him infront of enemy instead of jumping him".
- **Where:** `backend/combat_sim.gd` `_ambush_landing_from` (fallback to
  `target - step`), event field `front_landing`.
- **Tests:** combat `_test_ambush_front_landing` (wall, void, adjacent).
  Older "blocked back = reject" fixtures now also void the front tile.

### 1.2 Drift-Pin only Pins when the push hits something (0.1.133)

- **What:** the Air + Earth Blend still pushes 1 tile. It only **Pins**
  (no walking next turn) if the push **hits** a wall, the board edge or a
  body (the 8-damage case). A free slide does not Pin.
- **Why:** Mauro saw a Pin with no obstacle: "The pin should only works when
  he hits something". (Cause found: the push follows the caster→target
  sign on both axes, so off-axis shots push diagonally, e.g. into a
  Stormspire obelisk.)
- **Where:** `CombatSim._blend_drift_pin` (`hit_something`).
- **Tests:** combat Drift-Pin block (slide = no Pin; edge = 8 + Pin; body =
  Pin; never twice running).

### 1.3 Snap Wall on your own wall knocks it down (0.1.134)

- **What:** Bastion casts Snap Wall on one of **his own** walls → the wall
  disappears, costs 1 AP, needs no Aegis, and gives back the 2 Aegis (cap
  4). Other walls (enemy, map) cannot be knocked down. Not an attack.
- **Why:** Mauro: "in order to destroy that wall you could use snap a wall on
  top of the wall already create to destroy it and generate aegis point
  back". Approved with "Yesss".
- **Where:** `CombatSim._resolve_snap_wall_break`, `_own_snap_walls`,
  `_remove_snap_wall`; `legal_intents` offers own walls even at 0 Aegis;
  `board_view._snap_wall_break_cell` lets the tap through on the wall.
- **Tests:** combat `_test_snap_wall_knock_down`.
- **Note:** Mauro asked earlier why Bastion "couldn't place walls": the gold
  diamonds with an X are **Plant** flags, not walls. Plant does not build a
  wall. Bastion had 0 Aegis (Snap Wall needs 2).

### 1.4 Every spell explained in plain words (0.1.134)

- **What:** holding a spell button shows, before the old technical lines:
  cost in AP/MP dots, reach, what it does, the class power dots (Impact /
  Pulse / Aegis / Umbral), can it miss + chance now, back-hit bonus,
  element. Old numbers stay under "— Details —".
- **Why:** Mauro: "put all the info on every single spell ... its cost and
  what they do ... explained that even a 5 year old can understand".
- **Where:** `data/spell_tooltip.gd` `simple_lines` (numbers read from
  `SpellKits.SPELLS`, so balance changes update the text). Card grows to fit:
  `CombatHUD._fit_tooltip_card`.
- **Tests:** combat `_test_every_spell_explained`.
- **When a spell rule changes, update its text in `simple_lines`.**

### 1.5 Attack from the top bar + enemy stats on hold (0.1.134)

- **What:** with a spell armed, tapping a fighter's portrait (top bar) or
  side card casts on that fighter **only if the cast is legal** (range +
  line of sight); otherwise a toast. Holding a portrait/card shows a stats
  card: HP, AP/MP now and per turn, shield, Mastery (damage), Resist,
  elements, stacks, effects, spells with damage/heal and element.
- **Why:** Mauro: "un enemigo puede ser atacado desde la barra de menu siempre
  y cuando tenga vision el atacante, tambien cuando dejas seleccionado al
  enemigo te deberia de decir cuanta vida tiene, cuantos pa, mp que
  elementos usa que resistencias y daños tiene."
- **Where:** `CombatHUD.unit_card_tapped`, `_make_unit_pressable`,
  `unit_info_text`; `board_view._on_unit_card_tapped`.
- **Tests:** combat `_test_enemy_card_tap_and_hold`.
- **Not done:** holding a fighter on the **board** (the board touch is used
  for aiming / camera).

### 1.6 Kestrel aims better the farther she shoots (0.1.135)

- **What:** Mark Shot and Detonate hit **70 / 75 / 80 / 85 / 90%** at 1 / 2 /
  3 / 4 / 5 tiles (were 90 / 80 / 80 / 75 / 75). Every other spell keeps the
  shared table (`backend/hit_bands.gd`).
- **Why:** Mauro: "krestel misses shot too much" → "the farther away she
  should aim better she is a ranged character making her missing shots
  because she is away makes no sense". Table approved ("Yes do it").
- **Where:** `SpellKits.KESTREL_HIT_BY_DISTANCE` (`hit_by_distance` on both
  spells), `CombatSim._spell_hit_chance` (resolve, preview, aim chrome).
- **Tests:** combat `_test_kestrel_aims_better_far`; old Kestrel hit-%
  fixtures moved to the new numbers.

### 1.7 Bastion becomes the shield class (0.1.136)

- **What:** **Ward moved from Mender to Bastion; Aegis Break left Bastion's
  kit.** Bastion: Bash, Plant, Hold Line, Snap Wall, Ward.
  Ward = 3 AP + **1 Aegis**, **once per turn**, never misses, **+20 shield
  on every ally within 3 tiles including Bastion**, stacks to **40** (2
  casts), **no timer** (lasts until hits break it).
  *First version (0.1.136): 3 Aegis, stack 60. Changed in 0.1.137 (7 Oct
  2026, Mauro picked option A): at 3 Aegis Bastion could only Ward about
  every 3 turns (he earns ~1 Aegis per attacking turn), so his support job
  rarely happened; at 1 Aegis he can Ward every turn, and the cap drops to
  40 so no team sits on 60 shield. Ironjaw still shatters it.*
- **Why:** Mauro: "bastions feels useless at team fights ... take out ward
  from mender and give it to bastion and delete his aegis break and ward now
  will give all allies 20 shield can be stack 3 times and requires 3 aegis
  plus 3 pa"; "every allies includes himself 3 tiles is fine"; "shield will
  last until is taken away".
- **Where:** `SpellKits.WARD` (kit data), `CombatSim._resolve_team_ward`.
  Aegis Break data still exists in `SpellKits.SPELLS` but is in no kit.
  AI: `HeroAI._team_ward` (AI Bastions Ward when an enemy is within 3 tiles).
- **Tests:** `_test_bastion_team_ward_and_thorns`; old Mender Ward / Aegis
  Break tests replaced.

### 1.8 Thorns (Bastion's 1v1 tool) — how it evolved and where it is now

- **Now:** **always on, 20% of every melee hit** on Bastion is reflected to
  the attacker (adjacent attackers only; no resist; can kill).
- **Why / history (important for tuning):**
  1. Mauro chose Thorns as Bastion's 1v1 boost ("2 thorns").
  2. Flat 6 while shielded → negligible at level 15–30 (hits are 30–80).
  3. Simulator (level 15, Rare sets, no Stills) showed the counter wheel
     **upside down**: Bastion beat Ironjaw 8–0 and lost to Gloam 0–6.
  4. 30% while shielded → still Gloam 7–0 (Gloam's first hit breaks the
     shield, so only 1 hit in 3 was reflected).
  5. Mauro: Bastion "should have the ability to take over gloam in 1vs1" →
     Thorns became **always on**. 25% → Bastion 9–3 vs Gloam (75%, too
     high). **20% → Bastion 5–5 (50%)**.
  6. **Next value to test: 22%** (interpolation → ~55–60%).
- **Where:** `CombatSim.THORNS_REFLECT` (0.2), `thorns_amount`,
  `_bastion_thorns` (called from `_mitigate_hit`). `thorns_pct` is a
  balance knob the simulator sets from env `THORNS_PCT` (game default 0 =
  use `THORNS_REFLECT`).
- **Tests:** Thorns asserts in `_test_bastion_team_ward_and_thorns`.

### 1.9 Ironjaw is the shield breaker (0.1.136)

- **What:** any Ironjaw hit that deals damage **shatters the target's whole
  shield** first (Bastion's or a teammate's); the shield soaks nothing.
  (Replaced an earlier try: Crush ×2 on shielded targets.)
- **Why:** Ironjaw must counter Bastion. Thorns also hurts Ironjaw (he is
  melee), so he needed a direct answer to Bastion's team shields. Mauro:
  "The whole point of shield is to shield his team mates" → so the breaker
  works on anyone, not only Bastion. Approved ("Yes").
- **Where:** `CombatSim._mitigate_hit` (`shield_shattered` event flag).
- **Tests:** `_test_crush_breaks_shields`; generic shield-soak tests now use
  Gloam's Cut instead of Ironjaw's Strike.
- **Not yet measured:** Ironjaw vs Bastion win rate with the breaker (target
  Ironjaw 55–60%). If Bastion still wins, next idea: Ironjaw ignores Thorns.

### 1.10 Mender: full support + Last Stand (0.1.136)

- **What:** Pulse Tap and Heartstop **heal allies only** (their enemy
  damage from 5 Oct option B is gone; Ward went to Bastion). **Last Stand:**
  when Mender is the **last fighter of her team alive and cannot Rekindle
  anyone** (Rekindle used, or nobody to revive — always in a 1v1), Pulse Tap
  hits an enemy for 10 and Heartstop for 22 + no walking next turn. A
  revived teammate turns it off. HUD tag "LAST STAND".
- **Why:** Mauro: "Mender is such a strong class in 2vs2 and 3vs3"; "her main
  role should be support and only have damage if she find herself at the
  very end of the match being the last alive and no way to revive her team
  mates she would take the match trying to get a win". "I trust you blindly
  do her as you think the best balances way".
- **Where:** `SpellKits.spell_for` + `LAST_STAND_DAMAGE`,
  `CombatSim._refresh_last_stand` (reset, turn start, death, revive).
- **Tests:** `_test_mender_last_stand`; 1v1 Mender tests expect Last Stand hits.

### 1.11 Element package — elements give the countered side a chance (0.1.136)

- **Flare (Air + Fire):** fills the last empty pair. Reveals Invisible enemies
  within 2 tiles of the target and adds a Burn stack. Kestrel's answer to a
  diving Gloam. (`CombatSim._blend_flare`)
- **Spark counters Mender:** a **Sparked healer heals 40% less** (on top of
  the 40% cut on a Sparked target), and **Cleanse cannot remove Sparked**.
  (`_support_heal_amount`, `CLEANSE_OTHER`)
- **Counter tips** on the Elements screen, one per counter matchup, and the
  Blend guide lists 6 Blends. (`ElementsScreen.COUNTER_TIPS`)
- **Change elements before the fight:** an **Elements** button during
  deployment opens the Elements screen; same price (a new pair costs 2
  trophies, moving spells between your two elements is free). On close the
  fighter wears the new pick (`set_seat_gear`; online clients resend with
  `NetSession.resend_local_gear`). (`board_view._on_elements_requested`)
- **Why:** Mauro: "find what are we missing in the element set up ... the
  whole point of element is to make the counter have a possibility to win";
  "I dont think free its an option but with thropies you can do that";
  "Just do the best option and try it right now".
- **Tests:** combat Air + Fire = Flare, `_test_spark_counters_mender`,
  `_test_prefight_elements_button`.
- **Useful fact:** Fire Burn ticks skip shields and do not trigger Thorns —
  that is Gloam's element tool against Bastion (written in the counter tips).

### 1.12 Match clock + sudden death (0.1.136)

- **What:** Koliseo matches last **10 min** (3v3: **15 min**). The clock runs
  with the turn timer (not in deployment, not in Stasis). The **last 3
  minutes are sudden death:** at each fighter's turn start it loses 5% of
  its max HP, then 10%, 15% … (shields do not block). At **0:00** the team
  with the larger share of its HP left wins (exact tie = draw). Top bar:
  "Match 9:41" / "SUDDEN DEATH 2:50".
- **Why:** Mauro: "Matches should be max of 10 minutes", "At 3vs3 im willing
  to do 15 mins max", "Longer fights just gets boring". The simulator also
  showed real stalls (30 rounds, 0 damage). Approved ("Yes").
- **Where:** `CombatSim.MATCH_SECONDS`, `MATCH_SECONDS_3V3`,
  `SUDDEN_DEATH_SEC`, `_sudden_death_tick`, `_time_up`, snapshot
  `match_time_left` / `sudden_death`; `CombatHUD.match_clock_text`.
- **Tests:** `_test_sudden_death_clock`.
- **Note:** the clock is real time on the host / hot-seat; the balance
  simulators do not tick it.

### 1.13 Kestrel gets Vault and Snare Trap (0.1.136)

- **Vault:** 2 AP, never misses, jump exactly 2 tiles straight (N/S/E/W),
  **only while an enemy is next to her**, once per turn, cannot jump rocks /
  crates / walls / steam (Advance rules). AI Kestrels use it to escape.
- **Snare Trap:** 2 AP, hidden trap on an empty tile 1–3 away, 1 at a time,
  lasts 3 of her turns. The first enemy whose walk crosses it **stops there,
  takes 6 and is Pinned next turn**. Only the owner's side sees the green
  marker.
- **Why:** Mauro: "Also maybe krestel need another spell?" → "Yes". She had
  2 spells (others 4–5) and no way to escape a diver (her counter is Gloam).
- **Where:** `SpellKits.VAULT`, `SpellKits.SNARE_TRAP`;
  `CombatSim._validate_vault`, `_resolve_vault`, `_trigger_trap`,
  `_tick_traps`, `_hostile_trap_at`; `board_view._own_traps`; VFX
  `trap` token; `HeroAI` Vault escape.
- **Tests:** `_test_kestrel_vault_and_snare`.
- **Art:** both use generic effects for now (no painted VFX yet).

---

## 2. Balance tools (how the numbers were measured)

- `tests/sim_duels.gd` — AI vs AI 1v1 on the real CombatSim.
  `godot --headless --path . -s res://tests/sim_duels.gd -- <games_per_side> <base|lvl30|lvl15rare> <class|all> <seed>`
  - `lvl15rare` (added): level 15, 28 points (the level-30 split scaled),
    full 5-piece **Rare** set at +0 (Ironveil on Bastion / Mender, Stillcut
    on the others), no Stills.
  - Env: `DUEL_VS=gloam,ironjaw` (only those opponents), `DUEL_SKIP=mender`,
    `DUEL_VERBOSE=1` (one line per duel), `THORNS_PCT=20`.
- `tests/sim_teams.gd` — 2v2 / 3v3.
- **AI scoring fix:** both simulators now count a shield like HP (shields
  have no timer) and a shielded/unshielded Bastion facing a melee class
  counts one expected Thorns hit. Before this, the AI **never cast Ward**,
  so early Thorns results were meaningless.
- **Speed warning:** a level-15/30 duel takes 3–6 minutes of CPU. Run 4
  processes in parallel with different seeds; ~16 duels take ~30 min.

Results recorded this session (level 15, Rare, no Stills):

| Setup | Bastion vs Ironjaw | Bastion vs Gloam |
|---|---|---|
| Thorns 4% of HP, AI not using Ward | Bastion 5–0 | not finished |
| Thorns 4%, AI uses Ward | Bastion 8–0 | Gloam 6–0 |
| Thorns 30% while shielded, Crush ×2 | Bastion 7–0 (+1 stall) | Gloam 7–0 (+1 stall) |
| Thorns 25% always on | — | Bastion 9–3 (+4 stalls) |
| **Thorns 20% always on (current)** | **not measured yet** | **Bastion 5–5 (+3 stalls)** |

---

## 3. Open items / next steps (in priority order)

1. **Bastion vs Gloam with the 0.1.137 Ward** (1 Aegis, once per turn, cap
   40) and Thorns 20%. The cheaper Ward may lift Bastion to 55–60% on its
   own; only if not, try **Thorns 22%**.
2. **Ironjaw vs Bastion** with the shield breaker (target Ironjaw 55–60%).
   If Bastion still wins: Ironjaw ignores Thorns.
3. **2v2 team simulator** with the new Mender / Bastion (target Mender teams
   ~50%, max 55%). If Mender is too weak: no-damage Heartstop "peel" on an
   enemy (they cannot walk next turn) was the agreed fallback idea.
4. Full counter-wheel check at level 15 + Rare for Kestrel ↔ Gloam and
   Ironjaw ↔ Kestrel with Vault / Snare Trap / Flare.
5. Mender heal elements (proposal E: Earth = Grounded, Air = +1 MP, Fire =
   next hit Burns, as a **trade** for Water's +4, not an addition) — not
   approved, parked.
6. Bastion's Earth anti-stun (proposal C) — parked; in teams Mender's
   Cleanse covers it.
7. Painted VFX for Flare, Vault and Snare Trap.
8. Hold a fighter on the **board** to see the stats card.

---

## 4. Operations notes

- **Online server** `68.201.184.207:7777` (Tailscale `100.81.105.11`, user
  `keru`) must run the same build as the phones. Claude cloud sessions
  cannot reach it (private network, no SSH). Update on the server:
  `git pull origin mobile`, then restart `godot --path . -- --dedicated 7777`.
- **APK publishing:** `build_tools/publish_apk_branch.sh <version> "<notes>"`
  after exporting `builds/android/stasiumxii-mobile-debug.apk`.
  **Always run `apksigner verify --print-certs` first.** On 6 Oct a full
  disk produced an **unsigned** 0.1.135 APK that phones refused; it was
  rebuilt and re-published. Cert SHA-256 must be
  `3725b12ee58cf1d911c373bc5ef0b6be3c47afb41421777f2b505bb4aa6063e2`.
- **Disk:** the scratchpad held 13 GB of old video frames, and also the
  Godot binary and the Android SDK symlinks (`/usr/local/bin/godot` points
  into the scratchpad). If you clean the scratchpad, re-download Godot
  4.7.2 and recreate `android-sdk/` (platform-tools/adb, build-tools/35.0.1
  apksigner + zipalign symlinks to `/usr/bin`).
- **Godot import noise:** after any headless run, revert
  `art/tilesets/original/pending/brinewake/brine_elevation_punch.png.import`
  and `stasium-ref/maps/brinewake/elevation_punch.png.import`.
- **No PC builds** unless Mauro asks.
