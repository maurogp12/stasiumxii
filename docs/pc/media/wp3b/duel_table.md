# WP3b Koliseo duel table

Media: none. This package does not change the world picture. The table is the check.

Both fighters are the same class and both have the full point budget from the shipped curve (`points_per_level` × (`max_level` − 1) = 98). The check is spread against spread. Each pair is 200 seeded fights in the real PC `CombatSim` for every class (Kestrel, Ironjaw, Mender, Gloam, Bastion), 1,000 fights in all. The win rate is the left spread's wins across those fights. A draw would count as half a win; this sample had none. The analytic race is not used.

The board is the flat CombatSim test board. Fighters start on (2, 2) and (4, 2), facing each other. Both sides use the same policy: Kestrel shoots and steps back out of melee, Ironjaw strikes, Gloam cuts, Bastion bashes until Aegis Break, Mender banks Pulse with Cleanse and spends it on Heartstop. Higher Initiative acts first. Equal Initiative alternates with the seed, so seat 0 is not a permanent first strike.

The mix is half the budget in Mastery and half in Vitality (49 / 49). Mastery stays +0.5% damage and healing. Vitality stays +0.5% of base max HP. Resist stays +0.4% less damage taken. Class HP per level and title names stay Open. Respec, +1 AP at level 30, the character panel, Resist naming, and the 100-level re-run are unchanged.

There is no follow-up turn. Swift does not steal a turn.

## Before

Swift is +1 Initiative and nothing else. Initiative only picks who acts first. Resist cap is the proposed 25% (62.5 points; a full spend wastes 35.5).

All-Swift loses to every other full spend, so Swift is a dead stat. Full Resist also falls out of the 45–55 band against Vitality and against the mix. That is the real-combat table forcing two number changes, reported below rather than left as they were.

| Pair | Left spend (M / V / R / S) | Right spend | Left win rate |
|---|---|---|---|
| All Mastery vs all Vitality | 98 / 0 / 0 / 0 | 0 / 98 / 0 / 0 | 52.00% |
| All Mastery vs all Resist | 98 / 0 / 0 / 0 | 0 / 0 / 98 / 0 | 61.20% |
| All Vitality vs all Resist | 0 / 98 / 0 / 0 | 0 / 0 / 98 / 0 | 79.80% |
| Mix vs all Mastery | 49 / 49 / 0 / 0 | 98 / 0 / 0 / 0 | 54.40% |
| Mix vs all Vitality | 49 / 49 / 0 / 0 | 0 / 98 / 0 / 0 | 52.80% |
| Mix vs all Resist | 49 / 49 / 0 / 0 | 0 / 0 / 98 / 0 | 77.80% |
| Mix vs all Swift | 49 / 49 / 0 / 0 | 0 / 0 / 0 / 98 | 94.80% |
| All Swift vs all Mastery | 0 / 0 / 0 / 98 | 98 / 0 / 0 / 0 | 9.80% |
| All Swift vs all Vitality | 0 / 0 / 0 / 98 | 0 / 98 / 0 / 0 | 6.70% |
| All Swift vs all Resist | 0 / 0 / 0 / 98 | 0 / 0 / 98 / 0 | 20.00% |

## After

Two number changes, and no new effect:

- **Resist cap 25% → 33%.** The per-point rate stays 0.4%. The cap is reached at 0.33 / 0.004 = 82.5 points. A full spend still wastes 15.5 points. Full Resist is still the weaker side. Its best listed result is 45.80% (the mix against all Resist), which stays inside the band. Mastery and Vitality stay 0.5%.
- **Swift keeps +1 Initiative** (turn order only) and uses the existing `bonus_damage` effect at **+0.35% damage per point**. At 98 Swift that is +34.3% damage. It is not HP and it is not Resist. The follow-up turn from the previous head is gone.

| Pair | Left spend (M / V / R / S) | Right spend | Left win rate |
|---|---|---|---|
| All Mastery vs all Vitality | 98 / 0 / 0 / 0 | 0 / 98 / 0 / 0 | 52.00% |
| All Mastery vs all Resist | 98 / 0 / 0 / 0 | 0 / 0 / 98 / 0 | 52.00% |
| All Vitality vs all Resist | 0 / 98 / 0 / 0 | 0 / 0 / 98 / 0 | 52.40% |
| Mix vs all Mastery | 49 / 49 / 0 / 0 | 98 / 0 / 0 / 0 | 54.40% |
| Mix vs all Vitality | 49 / 49 / 0 / 0 | 0 / 98 / 0 / 0 | 52.80% |
| Mix vs all Resist | 49 / 49 / 0 / 0 | 0 / 0 / 98 / 0 | 54.20% |
| Mix vs all Swift | 49 / 49 / 0 / 0 | 0 / 0 / 0 / 98 | 52.10% |
| All Swift vs all Mastery | 0 / 0 / 0 / 98 | 98 / 0 / 0 / 0 | 63.30% |
| All Swift vs all Vitality | 0 / 0 / 0 / 98 | 0 / 98 / 0 / 0 | 50.00% |
| All Swift vs all Resist | 0 / 0 / 0 / 98 | 0 / 0 / 98 / 0 | 49.20% |

Nine pairs are inside 45–55%. All Swift vs all Mastery is 63.30%, above 55%. Swift is not a dead stat: the three all-Swift rows are 63.30%, 50.00%, and 49.20%.

### Sanity

Same 200 seeds. Each full spend against a fighter with no points, plus the all-Mastery mirror.

| Check | Left win rate |
|---|---|
| All Mastery vs no points | 94.90% |
| All Vitality vs no points | 96.60% |
| All Resist vs no points | 95.80% |
| All Swift vs no points | 97.40% |
| All Mastery mirror | 52.20% |

Each full spend is above 80%. The mirror is inside 45–55%.

### Why all Mastery vs all Vitality matches all Mastery vs all Resist

This is not a bug. The two rows are the same fight.

A full Vitality spend is `round(80 × (1 + 0.005 × 98))` = 119 HP, and that fighter deals unbuffed damage. A full Resist spend caps at 33% less damage taken, so incoming hits are multiplied by 0.67, and that fighter also deals unbuffed damage. Effective HP is 80 / 0.67 ≈ 119.4, the same pocket as 119.

For every spell these bots actually cast, integer rounding makes the hit count to kill the same on both spreads. Both opponents deal the same unbuffed damage, the seed is the same, and the policy is the same, so the winner matches. The class rows match for that reason. All Vitality vs all Resist does not match them, because those two spreads are then fighting each other.

### Why 0.35% does not put every pooled pair inside 45–55%

The allowed range is about 0.35–0.45% per point, numbers only, on the existing damage bonus. No value in that range puts all ten pooled pairs inside 45–55%.

All Swift vs all Mastery is a short fight. Swift acts first, and +0.35% damage removes a hit on the short kits. That pair sits at 63.30%. Lowering the rate until that pair is at or under 55% drops all Swift vs all Vitality and all Swift vs all Resist below 45%. Raising the rate toward 0.45% makes all Swift vs all Mastery worse, because the same first strike hits harder. 0.35% is the floor of the range and the least-bad pooled result: the other nine pairs stay inside the band, and this one is reported.

### Class guard

The guard is 35–65% for every class in every pair. One shared damage bonus cannot meet it. The failing rows are below. There is no per-class rate, and this table does not publish a per-class win-rate grid.

Two rows fail with Swift at zero. They do not depend on the damage bonus:

| Class | Pair | Why |
|---|---|---|
| Gloam | All Vitality vs all Resist | Cut is 13. Nine Cuts leave 119 HP standing, so Vitality dies on the tenth. Capped Resist takes 9 per Cut, and nine of those kill 80 HP. Vitality wins the hit count. |
| Gloam | Mix vs all Mastery | The mix's Cut rounds to 16 and kills 80 HP in five hits. All-Mastery's Cut rounds to 19, and five of those leave the mix's 100 HP standing. The mix wins the breakpoint. |

The rest fail because Swift is one rate for every class. Short kits (Strike, Cut, Bash) plus first strike run hot. Heartstop is base 10 and stays a hit behind a full Mastery, Vitality, or capped Resist spend at 0.35%. The rate that would let Heartstop catch up is about 0.46% per point, above the 0.45% ceiling, and that same increase pushes the short kits further out.

| Class | Pair | Why |
|---|---|---|
| Ironjaw | Mix vs all Swift | Strike into Crush is a short fight. Swift acts first with the damage bonus, and the row leaves the guard on Swift's side. |
| Mender | Mix vs all Swift | Heartstop at +0.35% rounds to 13. The mix's Heartstop rounds to 12 and kills 80 HP in seven hits. Swift needs eight hits to kill the mix's 100 HP. First strike does not close that gap. |
| Bastion | Mix vs all Swift | Bash until Aegis Break. The mix's damage wins the row. Swift's first strike does not pull it back inside the guard. |
| Ironjaw | All Swift vs all Mastery | Short kit, and Swift acts first. |
| Gloam | All Swift vs all Mastery | Both Cuts kill in five hits. Swift acts first. |
| Bastion | All Swift vs all Mastery | Bash until Aegis Break, and Swift acts first. |
| Mender | All Swift vs all Mastery | Mastery's Heartstop is 15 and kills in six hits. Swift's Heartstop is 13 and kills in seven. Swift's first strike does not make up the missing hit. |
| Ironjaw | All Swift vs all Vitality | Short kit and Swift acts first, just past the guard. |
| Gloam | All Swift vs all Vitality | Both Cuts kill in seven hits. Swift's Cut is 17 into 119 HP. Swift acts first. |
| Mender | All Swift vs all Vitality | Vitality's Heartstop kills 80 HP in eight hits. Swift's Heartstop into 119 HP needs ten. |
| Kestrel | All Swift vs all Resist | +34.3% damage does not offset a 33% reduction (1.343 × 0.67 is still under 1). Mark Shot and Detonate stay small, so Resist wins the trade. |
| Ironjaw | All Swift vs all Resist | The kit is short enough that first strike still leaves the guard on Swift's side after the cap. |
| Gloam | All Swift vs all Resist | Both Cuts kill in seven hits. Swift's Cut into the cap is 12. Swift acts first. |
| Mender | All Swift vs all Resist | Swift's Heartstop into the cap is 9 and needs nine hits. Resist's Heartstop into 80 HP needs eight. |
