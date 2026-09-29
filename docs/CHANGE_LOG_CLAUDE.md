# STASIUM XII — Change log (Claude sessions)

Every change a Claude session makes is recorded here, newest last, so the
other agents (Cursor, Grok) and Mauro can see what happened and why.

## Rules for every agent (Mauro, 29 Sep 2026)

1. **Do not change anything unless Mauro approves it or commands it.** No
   "while I was there" fixes, no unrequested redesigns, no rule changes.
   Suggest in chat or in `docs/things_to_review.md`; wait for his yes.
2. **Record every change here** (what, why, who asked, commit, version).
3. Bastion art is not touched unless Mauro asks.
4. Only Mauro merges into `mobile` / `main`. Agents open PRs.
5. Kit numbers and rules follow the GDD Blueprint. Do not invent Open items.

Work branch for these sessions: `claude/stasium-xii-development-6ni8g2`.
Sideload builds: `apk/<version>` branches → GitHub prerelease
`mobile-<version>-debug` (published by `.github/workflows/publish-apk-release.yml`
on those branches) → the in-game **Actualizar** button.

---

## 0.1.34 — merged to `mobile` (PR #204, `8fe3424`)

| Change | Asked by | Commit |
| --- | --- | --- |
| Rolled `mobile` back to 0.1.32 content: reverted #202 (unapproved face-true walks for Ironjaw, Kestrel, Gloam) | Mauro: "go back to the apk before" | `6ad52fa` |
| Board #14 (Locked): Gloam Ambush cannot pass a Snap Wall on its shot ray (`wall_on_ray`, grey, 0 AP). Range stays Manhattan 1–2 (Mauro confirmed) | Daily problem board #14 | `4d6142e` |
| Version stamp 0.1.34-mobile (code 35) | Mauro: build the APK | `97f530e` |

## 0.1.35 → 0.1.41 — on the work branch, NOT yet merged to `mobile`

| Ver | Change | Asked by | Commit |
| --- | --- | --- | --- |
| 0.1.35 | Rebuilt Kestrel, Gloam, Ironjaw, Mender strips as one body per fighter (holes filled, costume no longer swaps in attack/cast/death). Ironjaw = Blueprint §6 red-plate SIDE walk. Bastion untouched. Scripts: `build_tools/art/rebuild_character_strips.py`, `extract_blueprint_refs.py` | Mauro: "make visuals much better, Dofus/Wakfu" | `c93725d` |
| 0.1.35 | Dofus-style arena: sky backdrop, floating-island slab, brighter board, blue P1 / red P2 team rings and zones, green walk range | same | `903ac5e` |
| 0.1.36 | Five arenas painted from Mauro's look pictures (lava, dock, electric, ice, city plaza): floor stamps + props cut from `art/maps/arena_look/refs/`. Scripts: `build_tools/art/arena_look.py`, `arena_props.py`. View only, tags unchanged | Mauro sent the 4 pictures + blueprint city | `46594f8` |
| 0.1.37 | Animated lava rivers + glowing cracks (Slagcrown), crackling rune cells + lightning bolts (Stormspire), water caustics, shaded raised cells | Mauro: "lava and electric look bad" | `b870524` |
| 0.1.38 | Living fighters: idle breath/sway, camera shake on hits | Mauro: steps 1,2,3 | `4ac5d33` |
| 0.1.38 | Wakfu-style per-class spell flourish particles (`vfx/spell_flourish.gd`) | same | `e3a4403` |
| 0.1.38 | Dofus HUD: blue AP gems, green MP gems, team-framed turn portraits, bouncing damage numbers | same | `39cb27a` |
| 0.1.39 | Slagcrown: 3 edge volcanoes removed, one volcano in the map centre (7,7). Decoration only | Mauro screenshot | `ee7c3b0` |
| 0.1.40 | Menus off the map: Zoom − fits the whole board between the menus, Zoom + to 3×, pinch zoom, New Match moved to the left column, Walk/End Turn beside the Face pad. Zoom tests updated to the new range | Mauro: "menus interfere with gameplay" | `9675ad5` |
| 0.1.40 | Body sizes: Bastion and Ironjaw 1.18×, Kestrel/Gloam/Mender 0.88×. Size tests updated | Mauro: "Bastion and Ironjaw the biggest" | `9675ad5` |
| 0.1.41 | **Rule change:** Gloam Invisible (Fade) lasts 2 of Gloam's turns, then wears off (`CombatSim.INVISIBLE_TURNS = 2`, expire event, status card "Invisible N"). Attack still reveals at once. Test `_test_invisible_wears_off` | Mauro: "invisible only last 2 turns" | `442a1cf` |
| 0.1.41 | Bastion Snap Wall drawn as a stone rampart with gold trim and a glowing shield rune; slam effect on cast; smoke puff when Invisible wears off | Mauro: "the wall from Bastion looks so lame" | `c8e204f` |
| 0.1.41 | Actualizar now works for these builds: release workflow on `apk/<version>` branches publishes `mobile-<version>-debug`. First release: `mobile-0.1.41-debug` | Mauro: "make Actualizar work" | branch `apk/0.1.41` |

| 0.1.42 | Stormspire: floor tiles sampled from Mauro's second Stormspire picture (blue-grey cracked slabs); decoration thinned to 4 obelisks + 4 corner crystals; one tall obelisk tower in the centre (7,7). Lighting unchanged. The 8 blocking props (4 rock pillars, 4 arcs) are unchanged — removing them would change gameplay, not approved yet | Mauro: "too many obstacles … tiles like the pictures, do not change the lighting" | see 0.1.42 commits |

| 0.1.43 | **Kit change:** Kestrel Mark Shot range Chebyshev 2–7 → **2–5** (`data/kits.gd`). Range tests, README and the GDD handoff updated. Hit bands, damage and Marks unchanged. The Blueprint docx and Spells xlsx (outside git) still say 2–7 — Mauro/other agents should patch those | Mauro: "Kestrel has way too much range, Mark Shot 2 less spaces" | see 0.1.43 commits |

| 0.1.44 | **New system (Blueprint §9 + §15):** Koliseo wallet. Coins: first 2 human wins per UTC day pay 1 each, win 3+ / loss / dummy pay 0, wallet max 120. Trophies: 1 per human win, no daily cap, wallet 300. Hub shows "Coins N · Trophies N" and a **Shop** button: trophy shop (the 6 Blueprint SKUs, cosmetics/pet owned once, food repeatable) and Duskbrand stall (60 coins per +0 part, 5 slots, duplicates allowed for fuse). Saved in `user://koliseo_wallet.json`. "Human win" = an **online** match the local seat wins; hot-seat, dedicated server and Stasis pay nothing (question for Mauro). Bought items are stored only — wearing gear, set bonuses, AP/MP clamp and showing cosmetics are not built yet. Files: `backend/koliseo_wallet.gd`, `scenes/koliseo_shop.gd`, hook in `backend/net_session.gd` (`_note_koliseo_result`), hub row in `scenes/mobile_hub.gd`. New suite `tests/run_koliseo_wallet_tests.gd` | Mauro: "keep working on whatever you haven't worked on" (Blueprint video) | see 0.1.44 commits |
| 0.1.45 | Windmere (winter arena): falling snow — ~300 flakes drifting with sway and gusts, settling on the ice and melting, a few big soft flakes near the camera (`board/snow_fall.gd`, `ArenaSky` "snowfall"). View only | Mauro: "the map of winter I would like to have snow falling" | see 0.1.45 commits |
| 0.1.45 | Spell effects: turning rune circle under the caster on every cast; projectiles with trails for ranged casts (Kestrel arrow streak, Mender arcing orb, Gloam wobbling shadow bolt) — the hit lands when the projectile arrives; heavy finisher (white flash, double shockwave, light column, extra sparks) on Detonate, Crush, Heartstop, Nightfold, Aegis Break, Ambush. View only (`vfx/spell_flourish.gd`). Test `_test_weather_and_spell_extras` | Mauro: "work on the visual of the spells, keep improving graphics and animation" | see 0.1.45 commits |
| — | **Decision (Mauro, 29 Sep 2026): "Only online win pays."** Koliseo coins and trophies come from online wins only; hot-seat, dedicated and Stasis pay nothing. Confirms the 0.1.44 behaviour — no code change, comment in `backend/koliseo_wallet.gd` updated | Mauro | see decision commit |
| 0.1.46 | **New system (Blueprint §10):** gear bag (`backend/gear_bag.gd`, save `user://gear_bag.json`). Six families only (Sheaf, Undertow, Ironveil, Stillcut, Brightedge, Duskbrand), 5 slots, wear/take off, **Fuse** (same item_id + same plus → +1, cap +5; 32 × +0 = +5), **Attune** at 2 worn pieces (Air/Earth/Fire/Water; kept but resting under 2), set bonuses 2/4/5pc from the Blueprint table (tiers stack), rare plus gate (Ironveil/Stillcut), AP/MP after gear clamped **8/5**. Hub **Gear** button → `scenes/gear_screen.gd`. Duskbrand stall parts now land in the gear bag. **Bonuses are shown only — CombatSim does not read gear yet** (needs Mauro: which fights use gear, and the per-item stat numbers from Mobile_Sets.xlsx, which is not in git) | Mauro: "gears and dungs rewards work on it" | see 0.1.46 commits |
| 0.1.46 | **Dungeon rewards (§9 Soft Lock):** clearing a Stasis door (Room B boss) opens a chest: 1 random +0 piece from the ★1 families (Sheaf or Undertow). 5 loot clears per UTC day shared by all doors; clear 6+ allowed, chest empty. Chest size 1 is **provisional** (Blueprint gives no number). `StasisCatalog.STAR = 1` | same | see 0.1.46 commits |
| 0.1.46 | **Dofus-style end-of-fight window** (`ui/combat_result.gd`) from Mauro's two screenshots: title, Victory/Defeat, duration mm:ss + turns, Winners / Losers blocks with portrait, name, HP left, loot icons, green CLOSE. Koliseo: opens ~1 s after the match ends; the online winner's loot shows the coin + trophy paid (notes for daily limit / hot-seat). Stasis: opens on the door clear (chest pieces as loot, all beaten foes listed) or on a wipe. No level / XP / kamas columns — the game has none | Mauro sent the Dofus "Resultado del combate" and "Combate terminado" pictures | see 0.1.46 commits |
| 0.1.46 | New suite `tests/run_gear_tests.gd` (20 suites total). Wallet tests updated for stall → gear bag | — | see 0.1.46 commits |

Each version bump is its own `Stamp Android sideload …` commit. All
headless suites (19 from 0.1.44) pass on every build listed above.

## Open / waiting on Mauro

- Merge the 0.1.35–0.1.46 work into `mobile` (PR not opened yet — waiting for his OK).
- Ironjaw front/back art (only a side view exists in the Blueprint).
- Map layouts matching the look pictures (volcano/shipwreck/tower positions) would change map tags — needs approval.
- Gear in fights: which fights read gear (Stasis only, or Koliseo too)? Per-item stats (weapon Mastery, head HP, …) live in Mobile_Sets.xlsx — not in git; needed before gear can touch CombatSim. Rare .ap/.mp affix drop rates also unknown.
- Stasis chest size (1 piece now, provisional).
- Still not built: cosmetic/pet visuals, hub food use (needs an out-of-fight HP system).
