# STASIUM XII — Locked SELECT_CLASS kit cards (workbook v0.6 stamps, 23 Sep 2026)
Source: GDD v0.2 as-written + Mauro SELECT_CLASS_Lock stamps. Numeric workbook wins.
Roster: kestrel | ironjaw | mender | gloam | bastion

## mender | Mender
- element: Water/Water
- resource: Pulse 0–6
- hp: 80 | mastery: 0 | resist: 0
- passive: Triage ×1.25 heals if target HP <40% (pre-heal); ally Heartstop yes, enemy no
- spells:
  - Mend: 3AP/0MP | r0–4 | +1 Pulse | 16H FLEX ally | miss/crit OK | no facing
  - Pulse Tap: 2AP/0MP | r0–3 | spend 1 Pulse | 10H FLEX ally | miss/crit OK
  - Ward: 3AP/0MP | r0–3 | spend 2 Pulse | 20HP shield 2 turns FLEX | miss OK | no crit
  - Cleanse: 2AP/0MP | r0–4 | +1 Pulse | LOCK Neutral | remove 1 CC | no roll
  - Heartstop: 5AP/0MP | r0–3 | spend 4 Pulse | FLEX | Ally: 32H + immunity 1 hit | Enemy: base_dmg=10 + skip next MP

## gloam | Gloam
- element: Air/Neutral
- resource: Umbral 0–4 | Shades max 2
- hp: 80 | mastery: 0 | resist: 0
- passive: Backstab ×1.35 replaces back ×1.20
- spells:
  - Cut: 3AP/0MP | r1 | +1 Umbral | 13D FLEX weapon | Backstab applies
  - Drop Shade: 1AP/0MP | r1–3 | +1 Shade (max 2) | LOCK Neutral | Shade 3 turns | no roll
  - Ambush: 4AP/0MP | range 1–2 cardinal | origin=self if Invisible else live Shade; Shade arms only after the opponent completes ≥1 full turn since that Drop (Fade/Invisible self-origin has no delay) | Manhattan {1, 2} N/E/S/W, no diagonals | dest = empty standable tile one step past the enemy on that axis; spend Shade only if origin Shade | FLEX jump then 22D | occupied/illegal back → illegal_back + refund | MISS: no teleport, Shade kept, Invisible kept, 4AP spent | button arms only when Ambush ∈ legal_intents
  - Fade: 2AP/1MP | self | +1 Umbral | LOCK Neutral | Invisible | no roll
  - Nightfold: 4AP/0MP | r0–6 | Shade + Umbral 2+ | clear Umbral | FLEX blink to Shade | 22D each adjacent | Shade commit-on-cast (can-wait vs global miss refund)

## bastion | Bastion
- element: Earth/Earth
- resource: Aegis 0–4
- hp: 80 | mastery: 0 | resist: 0
- passive: Intercept — once/Bastion turn cycle, 40% adjacent ally post-resist hit → Bastion; excl miss, Magma ticks, self-dmg
- spells:
  - Bash: 3AP/0MP | r1 | +1 Aegis | 11D FLEX melee
  - Plant: 2AP/0MP | r1–2 | +1 Aegis | LOCK Neutral | ward tile 3 turns | allies resist next push | no roll
  - Hold Line: 3AP/0MP | r1 | +1 Aegis | 7D/body FLEX front cone 3 | +1MP exit tax 1 turn on connect
  - Snap Wall: 1AP/0MP | r1–2 | spend 2 Aegis | LOCK Neutral | 1-tile blocked 2 turns | blocks walk/Gust | ships with Bastion (2-class board stays wall-less)
  - Aegis Break: 4AP/0MP | r1–2 | gate Aegis 3+ | HIT: 26D/body + push1 + clear ALL Aegis | MISS: spend 0

## Stamps (closed)
Heartstop enemy 10; Ambush 22 @ Manhattan 1–2 cardinal (Shade arms after the opponent completes a turn; Fade self-origin does not wait) miss rules above; Aegis Break 26 clear-all on HIT spend 0 on MISS; Umbral 0–4; Snap Wall ships; proto 80/0/0.

## Open / can-wait (do not invent)
Nightfold miss/Shade vs global refund; Intercept reset/multi-guard/pipeline; Neutral Primary scope; AoE vs Invisible; Heartstop immunity clock / CC priority / heal overflow / shield stack; Water Ward rider 24 vs Ward base 20; cone/ward masks.
