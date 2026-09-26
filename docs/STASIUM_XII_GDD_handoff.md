# STASIUM XII — GDD handoff (share with another AI)

**Date:** 2026-09-25 (America/New_York) · updated 2026-09-25 evening  
**Owner:** Mauro Garza  
**Purpose:** Single source dump of Locked design + what shipped, so another AI can continue without inventing silent defaults.  
**Labels used everywhere:** **Locked** (do not change without Mauro) · **Proposed** (ideas, not law) · **Open** (do not invent defaults) · **Parked** (explicitly deferred).

---

## 1. Product vision

- **STASIUM XII** = tactical isometric MMORPG.
- Business: PC/Steam F2P, cosmetics-only monetization (no P2W).
- Combat goal: another person wants to keep playing a duel for ~20 minutes.
- Prefer **clickable in-game UI** over typed/CLI workflows (Mauro finds command-line clunky).

## 2. Tech & repo

| Item | Value |
| --- | --- |
| Engine | Godot **4.3+** (mobile track also builds Android debug APKs) |
| Repo | `https://github.com/maurogp12/stasiumxii` |
| PC branch | `main` |
| Mobile branch | `mobile` |
| Kit SoT in repo | `data/kits.gd`, `data/select_class_lock_kits_v0.6.md` / `.json` |
| Mobile docs | `docs/mobile_hub.md`, `docs/mobile_touch.md`, `docs/mobile_android_export.md` |
| Pending review | `docs/things_to_review.md` |

### Merge lock (Locked 2026-09-25)

Everything that ships on the **mobile** track **merges up to PC `main`**, **except dungeons** (dungeons stay **mobile-only**. Luca unparked them for the phone APK overnight 2026-09-25. That does not put them on PC `main`).

### Android debug APKs

- Notify Mauro **only** when a build is **playable on device** (install/sideload path). Do not ping for intermediate PRs.
- Shared debug keystore pin (#115). Cert SHA-256 must be:  
  `3725b12ee58cf1d911c373bc5ef0b6be3c47afb41421777f2b505bb4aa6063e2`  
  Drift = hard stop before publish.
- Latest playable Ambush cut: **mobile-0.1.13-debug**  
  Install: https://github.com/maurogp12/stasiumxii/releases/download/mobile-0.1.13-debug/stasiumxii-mobile-debug.apk  
  APK SHA-256: `b953b2c80380377c77db2ac7070379db7e73970e448a10b205ef387502b69b02`  
  Cert matches pin; same cert as 0.1.12 → upgrade in place.

## 3. Core combat (Locked baseline)

- Turn-based, isometric board.
- Unit baseline: **80 HP**, turn refill **6 AP / 3 MP** (unless a Locked effect changes it).
- Facing: N / E / S / W matters for some kits (backstab, cones).
- Hit model: FLEX rolls where kit says `rolls: true`; LOCK Neutral for no-roll utility.
- Skill info on mobile: **hold** to show tooltip card; **tap** arms skill without card.
- Ambush / skill buttons: arm **only** if the skill is in `legal_intents` (soft-grey otherwise).

### Phase A origin (historical)

Phase A started as local hot-seat **8×8** duel (Kestrel vs Ironjaw). Current playable builds use **five-class select** and **15×15 Koliseo arenas** (see Maps).

## 4. Roster (Locked SELECT_CLASS)

Allowlist only: `kestrel` | `ironjaw` | `mender` | `gloam` | `bastion`.

| Class | Element | Resource | Passive |
| --- | --- | --- | --- |
| **Kestrel** | Air | Marks 0–5 (on target) | Ranged carry |
| **Ironjaw** | Earth | Impact 0–4 | Melee bruiser |
| **Mender** | Water/Water | Pulse 0–6 | Triage ×1.25 heals if target HP &lt;40% (pre-heal); ally Heartstop yes, enemy no |
| **Gloam** | Air/Neutral | Umbral 0–4, Shades max 2 | Backstab ×1.35 (replaces back ×1.20) |
| **Bastion** | Earth/Earth | Aegis 0–4 | Intercept: once/Bastion turn cycle, 40% adjacent ally post-resist hit → Bastion (excl miss, Magma ticks, self-dmg) |

Mastery/resist proto: **0/0** for all.

## 5. Locked kits (numeric cards win)

### 5.1 Kestrel

| Spell | Cost | Range | Effect |
| --- | --- | --- | --- |
| **Mark Shot** | 2 AP / 0 MP | Chebyshev 2–7 | 8 Air FLEX; applies **Mark** on connect |
| **Detonate** | 3 AP / 0 MP | Chebyshev 1–4 | Requires ≥1 Mark on target; 6 + 6×Marks Air FLEX; **consumes** Marks |

### 5.2 Ironjaw

| Spell | Cost | Range | Effect |
| --- | --- | --- | --- |
| **Advance** | 3 AP / 0 MP | **Exactly 2 cardinal** (N/S/E/W Manhattan 2 only; no Manhattan 1, no diagonals) | Teleport to empty tile; **Impact if ending adjacent** to enemy |
| **Strike** | 3 AP / 0 MP | Chebyshev 1 | 16 Earth FLEX + Impact |
| **Shoulder** | 2 AP / 0 MP | Chebyshev 1 | 6 Earth FLEX + push 1 (+ Impact rules: +1 after clean push, or +2 on bounce — not both) |
| **Crush** | 4 AP / 0 MP | Chebyshev 1 | Needs/spends **2 Impact** on connect; 24 Earth FLEX; miss keeps Impact; **Stun 1** if Impact was **4** before spend (blocks move + cast + face) |

### 5.3 Mender

| Spell | Cost | Range | Effect |
| --- | --- | --- | --- |
| **Mend** | 3 AP / 0 MP | 0–4 | +1 Pulse; 16H FLEX ally; miss/crit OK; no facing |
| **Pulse Tap** | 2 AP / 0 MP | 0–3 | Spend 1 Pulse; 10H FLEX ally |
| **Ward** | 3 AP / 0 MP | 0–3 | Spend 2 Pulse; 20 HP shield, 2 turns FLEX; miss OK; no crit |
| **Cleanse** | 2 AP / 0 MP | 0–4 | +1 Pulse; LOCK Neutral remove 1 CC; no roll |
| **Heartstop** | 5 AP / 0 MP | 0–3 | Spend 4 Pulse; **Ally:** 32H + immunity 1 hit; **Enemy:** base_dmg **10** + skip next MP |

### 5.4 Gloam

| Spell | Cost | Range | Effect |
| --- | --- | --- | --- |
| **Cut** | 3 AP / 0 MP | 1 | +1 Umbral; 13 Air FLEX weapon; Backstab applies |
| **Drop Shade** | 1 AP / 0 MP | Chebyshev **1–3** | +1 Shade (max 2); LOCK Neutral; Shade lasts 3 turns; **place-only** (not a teleport); no roll |
| **Ambush** | 4 AP / 0 MP | see legal sentence below | Jump then 22 Air FLEX |
| **Fade** | 2 AP / 1 MP | self | +1 Umbral; LOCK Neutral Invisible; no roll |
| **Nightfold** | 4 AP / 0 MP | 0–6 | Shade + Umbral 2+; clear Umbral; blink to Shade; 22D each adjacent — **gated / open_can_wait** on miss-refund |

#### Ambush — exact Locked legal sentence (Rules Keeper re-stamp 2026-09-25)

> Ambush is legal iff: (1) origin = caster if Invisible else a live Shade; (2) if origin is a Shade, the opponent has completed ≥1 turn since that Shade was created/Dropped (Shade arming — illegal until then; Fade self-origin unaffected); (3) enemy shares origin’s row or column (cardinal N/E/S/W; no diagonals); (4) Manhattan(origin, enemy) ∈ {1, 2}; (5) enemy’s back tile along that axis is empty and standable; (6) AP≥4. On resolve: teleport to that back tile then hit 22 (FLEX); spend Shade only if origin was Shade; MISS = no teleport, keep Shade + Invisible, 4AP spent. illegal_back = reject + refund. Ambush button arms only if ≥1 such intent ∈ legal_intents (soft-grey otherwise). Cost 4AP/0MP.

**Playtest note (Mauro):** Shade lined up N/E/S/W with enemy at **≤2** tiles (e.g. Shade–empty–Kestrel) is legal **after opponent has acted once** since Drop Shade. Gloam body can be anywhere.

**Chrome (Locked feel, no kit number change):** loud Neutral Shade as Ambush origin highlight when legal; soft-grey Ambush when not in `legal_intents`.

### 5.5 Bastion

| Spell | Cost | Range | Effect |
| --- | --- | --- | --- |
| **Bash** | 3 AP / 0 MP | 1 | +1 Aegis; 11 Earth FLEX melee |
| **Plant** | 2 AP / 0 MP | 1–2 | +1 Aegis; LOCK Neutral ward tile 3 turns; allies resist next push |
| **Hold Line** | 3 AP / 0 MP | 1 | +1 Aegis; 7D/body FLEX front cone 3; +1 MP exit tax 1 turn on connect |
| **Snap Wall** | 1 AP / 0 MP | 1–2 | Spend 2 Aegis; LOCK Neutral 1-tile blocked **2 Bastion turn-starts** (Burn tick family); blocks walk/Gust |
| **Aegis Break** | 4 AP / 0 MP | 1–2 | Gate Aegis 3+; **HIT:** 26D/body + push 1 + **clear ALL Aegis**; **MISS:** spend **0** Aegis |

## 6. Maps & modes

### Koliseo (PvP hot-seat / online)

Five **15×15** arenas (random hot-seat pick; no map picker):

- `crosshaven`, `brinewake`, `slagcrown`, `windmere`, `stormspire`  
  Boards: `art/maps/arena_colosseum_v2/tiled/{id}_15x15.*`  
  Online queue still defaults Crosshaven.

### Mobile hub (`mobile` branch)

F5 → `scenes/mobile_hub.tscn`: fat buttons for Koliseo + five **Stasis** doors. Luca Garza (overnight, 2026-09-25) unparked the phone doors: each opens a solo Room A trash chain, then a Room B boss, on that biome’s 15×15 board. Foe HP/damage are **provisional Open** (see [`docs/mobile_stasis.md`](mobile_stasis.md)). **Not for PC `main`.**

### Art direction (Locked preferences)

- Distinct board look per map family (grassland court / slate dungeon / timber arena planned).
- Character art: **Batch-1 REDRAW v3** Locked identity (limb redesign on Locked costume). Paths like `art/export_2x/characters/{kestrel,ironjaw}/anims/*_{walk,attack}_{e,s,n,w}.png`.
- **Do not ship** `art/grok_project/anims/gen_raw/*_gen.png` (identity drift).
- **Gender + color cosmetics:** **Parked** (Studio backlog). Mobile Stasis is unparked for the phone APK only (Luca, overnight 2026-09-25) and still does not merge to PC `main`.
- Batch-1c (in flight for feel APK): louder walk/attack, `cast_mark` / `cast` / `hit` / `death` for Kestrel/Ironjaw; full Gloam strips.

## 7. What has shipped (status as of this handoff)

### Playable

- Five-class select hot-seat.
- Combat sim + kits for all five classes (Nightfold gated).
- Mobile Android debug sideload loop with pinned keystore.
- Drop Shade Chebyshev 1–3.
- Ambush Manhattan 1–2 cardinal + opponent-turn Shade arming (**#118** → `mobile` tip `618944f`, APK **0.1.13**).
- Random Koliseo map selection; mobile hub shell + Stasis stubs.
- Shared debug cert pin (#115).

### In flight / next

- **URGENT (Mauro clip 2026-09-25):** walk/action feel — face into move, real walk cycle or weighted hop (no sideways/backwards slide), cast/strike anticipation (Mark Shot from weapon not feet, melee lunge, Detonate cast pose), hit flinch/flash, death/DOWN pose; then damage floats + targeting line polish.
- Wire Batch-1c anims into feel APK after Ambush cut.
- Version bump PR #119 for 0.1.13 stamp (draft as of tip).

## Things to review (pending — not Locked changes yet)

Living list of design / feel questions Luca or Mauro want to revisit later. **Do not ship code that changes Locked Ambush/Shade law from these items** until Mauro stamps. English only.

Canonical living table: [`docs/things_to_review.md`](things_to_review.md).

| # | Topic | Status | Notes | Opened |
| --- | --- | --- | --- | --- |
| 1 | **Ambush without a Shade** | Pending review | Luca (2026-09-25): playtest on mobile-0.1.16 — Ambush button stays grey unless a live Shade is on the board; he flagged that as something to revisit. **Current Locked:** Ambush origin = caster if Invisible (Fade), else a live Shade (+ Shade arming). Without Fade, Shade is required by Locked rules — this is design revisit, not a silent code fix. Options when reopened: keep Locked / Mauro stamp Ambush from body without Shade / verify Fade→Invisible self-origin path. | 2026-09-25 |
| 2 | **Stasis foe HP / damage** | Provisional Open | Luca overnight 2026-09-25 unparked mobile Stasis. Trash 22 HP / attack base 6, boss 56 HP / attack base 10, before Locked facing. Not Locked and not Soft Lock. Mobile only. | 2026-09-26 |

When an item is stamped Locked or rejected, move it out of this table into the matching Locked / Parked / Open section and leave a one-line disposition here.

## 8. Parked (do not start unless Mauro unparks)

- **Dungeons / Stasis rooms** — **unparked for the mobile APK only** by Luca Garza overnight 2026-09-25 (override of the Shade + walk gate for this phone ship). Still **not for PC `main`**. No loot or keys in this slice. Foe HP/damage stay provisional Open. Gender/color stays parked.
- **Gender select + color customization.**
- **Shade trap rider** (Proposed).
- **Ambush 3 AP retune** (Proposed).
- `gen_raw` character anims.

## 9. Open / can-wait (NO silent defaults)

From kit SoT — do not invent answers:

- Nightfold miss / Shade vs global refund
- Intercept reset / multi-guard / pipeline
- Neutral Primary scope
- AoE vs Invisible
- Heartstop immunity clock / CC priority / heal overflow / shield stack
- Water Ward rider 24 vs Ward base 20
- Cone / ward masks
- Other Invisible end conditions (beyond Ambush MISS keeping Invisible)

## 10. Studio roles (for context)

| Role | Owns |
| --- | --- |
| Gamedeveloper | Scope lock, GDD fidelity, shipping combat worth playing |
| Rules Keeper | Locked SoT stamps / legal sentences |
| Godot Engineer | Godot implementation, mobile APKs, PRs on `mobile`/`main` |
| Technical Artist | All visual art → Godot |
| Class Architect | Kit cards Phase A |
| Balance Lead | Hit-band / feel balance |
| Board Feedback | Board readability |
| Backend Engineer | Server, auth, matchmaking (full game) |

## 11. How another AI should behave

1. Separate every answer: **Locked / Proposed / Open / Parked**.
2. Never invent silent defaults for Open items — ask Mauro or leave Open.
3. Prefer clickable UI over console flags for player-facing flows.
4. Mobile → PC merge except dungeons.
5. Notify Mauro only for **playable** sideload APKs (install URL + uninstall note if cert changed).
6. Ambush / Drop Shade / Advance numbers above are Locked — change only with explicit Mauro + Rules stamp.
7. Current priority stack: (1) walk + action feel + Batch-1c, (2) spell chrome readability, (3) mobile Stasis playtest (provisional foe numbers; still not on PC `main`), (4) cosmetics later.
8. Items under **Things to review** are pending. They are not a stamp to change Locked Ambush/Shade law.

## 12. Quick Spanish summary for Mauro’s next AI

STASIUM XII es un táctico isométrico en Godot. Hay 5 clases Locked. Combate 80 HP, 6 AP / 3 MP. En móvil ya salió APK 0.1.13 con Ambush a ≤2 casillas en línea cardinal y solo después de que el rival jugó un turno desde el Drop Shade. Drop Shade es rango 1–3. Advance de Ironjaw es exactamente 2 cardinales. Cosméticos de género/color siguen aparcados. Luca (noche del 2026-09-25) desaparcó Stasis solo en el APK móvil: cada puerta entra a una mazmorra (sala A de trash, luego jefe en sala B). La vida y el daño de esos enemigos son provisionales (Open), no Locked. Todo lo de móvil sube a PC excepto dungeons.

---

*Generated for handoff. Prefer repo files `data/select_class_lock_kits_v0.6.*` and Rules Keeper stamps if anything conflicts with this snapshot. Pending questions live in `docs/things_to_review.md`.*
