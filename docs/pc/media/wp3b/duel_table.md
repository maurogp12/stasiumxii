# WP3b Koliseo duel table

Media: none. This package does not change the world picture. The table is the check.

Both fighters are the same class and both have the full point budget from the shipped curve (`points_per_level` × (`max_level` − 1) = 98). The check is spread against spread. Each pair is 200 seeded fights in the real PC `CombatSim` for every class (Kestrel, Ironjaw, Mender, Gloam, Bastion), 1,000 fights in all. The win rate is the left spread's wins across those fights. A draw would count as half a win; this sample had none. The analytic race is not used.

The board is the flat CombatSim test board. Fighters start on (2, 2) and (4, 2), facing each other. Both sides use the same policy: Kestrel shoots and steps back out of melee, Ironjaw strikes, Gloam cuts, Bastion bashes until Aegis Break, Mender banks Pulse with Cleanse and spends it on Heartstop. Higher Initiative acts first. Equal Initiative alternates with the seed, so seat 0 is not a permanent first strike.

The mix is half the budget in Mastery and half in Vitality (49 / 49). Mastery stays +0.5% damage and healing. Vitality stays +0.5% of base max HP. Resist stays +0.4% less damage taken. Class HP per level and title names stay Open. Respec, +1 AP at level 30, the character panel, Resist naming, and the 100-level re-run are unchanged.

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

Two number changes, and no others:

- **Resist cap 25% → 33%.** The per-point rate stays 0.4%. The cap is reached at 0.33 / 0.004 = 82.5 points. A full spend still wastes 15.5 points, and full Resist is still the weaker side (lowest listed result 45.80%, inside the band). Mastery and Vitality stay 0.5%.
- **Swift keeps +1 Initiative** (turn order only) and gains a side bonus: **+0.11% damage per point** (`bonus_damage` 0.0011) and a **0.25% chance per point of one follow-up turn** (`follow_up` 0.0025). The follow-up does not chain. It is not HP and it is not Resist. At 98 Swift that is +10.78% damage and a 24.5% chance to act again once.

| Pair | Left spend (M / V / R / S) | Right spend | Left win rate |
|---|---|---|---|
| All Mastery vs all Vitality | 98 / 0 / 0 / 0 | 0 / 98 / 0 / 0 | 52.00% |
| All Mastery vs all Resist | 98 / 0 / 0 / 0 | 0 / 0 / 98 / 0 | 52.00% |
| All Vitality vs all Resist | 0 / 98 / 0 / 0 | 0 / 0 / 98 / 0 | 52.40% |
| Mix vs all Mastery | 49 / 49 / 0 / 0 | 98 / 0 / 0 / 0 | 54.40% |
| Mix vs all Vitality | 49 / 49 / 0 / 0 | 0 / 98 / 0 / 0 | 52.80% |
| Mix vs all Resist | 49 / 49 / 0 / 0 | 0 / 0 / 98 / 0 | 54.20% |
| Mix vs all Swift | 49 / 49 / 0 / 0 | 0 / 0 / 0 / 98 | 52.40% |
| All Swift vs all Mastery | 0 / 0 / 0 / 98 | 98 / 0 / 0 / 0 | 54.60% |
| All Swift vs all Vitality | 0 / 0 / 0 / 98 | 0 / 98 / 0 / 0 | 48.50% |
| All Swift vs all Resist | 0 / 0 / 0 / 98 | 0 / 0 / 98 / 0 | 47.80% |

Every pair is inside 45–55%. The widest is all Swift vs all Mastery at 54.60%.

Per class, the same 200 seeds. The band is the pooled pair. Classes still split, because spell bases round differently: Gloam's all-Swift beats all-Mastery 82% of the time, and Mender's all-Swift beats all-Resist 4% of the time. Those class splits are inside the pooled rates above.

| Pair | Kestrel | Ironjaw | Mender | Gloam | Bastion |
|---|---|---|---|---|---|
| All Mastery vs all Vitality | 54.5% | 49.5% | 52.5% | 54.0% | 49.5% |
| All Mastery vs all Resist | 54.5% | 49.5% | 52.5% | 54.0% | 49.5% |
| All Vitality vs all Resist | 36.5% | 54.5% | 50.0% | 71.0% | 50.0% |
| Mix vs all Mastery | 47.5% | 51.5% | 51.5% | 68.5% | 53.0% |
| Mix vs all Vitality | 56.0% | 53.0% | 50.5% | 52.5% | 52.0% |
| Mix vs all Resist | 63.0% | 53.0% | 50.5% | 52.5% | 52.0% |
| Mix vs all Swift | 48.5% | 22.5% | 84.0% | 60.0% | 47.0% |
| All Swift vs all Mastery | 54.5% | 54.0% | 35.5% | 82.0% | 47.0% |
| All Swift vs all Vitality | 48.5% | 65.0% | 26.0% | 63.0% | 40.0% |
| All Swift vs all Resist | 48.5% | 64.0% | 4.0% | 82.5% | 40.0% |
