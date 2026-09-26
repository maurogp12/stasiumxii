# STASIUM XII — Things to review

**Purpose:** Pending design / feel questions to revisit with Mauro & Luca. English.  
**Rule:** Items here are **not** Locked changes. Do not implement Locked-breaking Ambush/Shade changes from this list until Mauro stamps.  
**Labels:** Locked · Soft Lock · Proposed · Parked · Open (never invent Open defaults).  
**Share snapshot:** the same rows are copied into [`docs/STASIUM_XII_GDD_handoff.md`](STASIUM_XII_GDD_handoff.md) under **Things to review** (before Parked).

| # | Topic | Status | Notes | Opened |
| --- | --- | --- | --- | --- |
| 1 | Ambush without a Shade | Pending review | Luca playtest (mobile-0.1.16, 2026-09-25): Ambush stays grey unless a live Shade exists; marked for later review. **Current Locked:** origin = caster if Invisible (Fade), else live Shade (+ arming). Without Fade, Shade is required. Revisit options: keep Locked / stamp body-origin Ambush without Shade / verify Fade Invisible self-origin. | 2026-09-25 |
| 2 | Stasis foe HP / damage | Provisional Open | Luca overnight 2026-09-25 unparked mobile Stasis. Trash 22 HP / attack base 6, boss 56 HP / attack base 10, before Locked facing. Not a Locked or Soft Lock stamp. See [`docs/mobile_stasis.md`](mobile_stasis.md). Mobile only — not for PC `main`. | 2026-09-26 |

## How to use

1. Add new rows when Luca or Mauro park a question mid-playtest.
2. When Mauro stamps, update kit SoT / legal sentences and remove or mark **Resolved** with date + decision.
3. Cross-link from the GDD handoff snapshot when regenerating share packs.
