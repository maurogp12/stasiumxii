# WP3b Koliseo duel table

Media: none. This package does not change the world picture. The table is the check.

Both fighters are the same class and both have the full point budget from the shipped curve (`points_per_level` × (`max_level` − 1)). The check is spread against spread. Points against no points is not a PvP case and is not in this table.

The race is exponential. Mastery raises damage done. Vitality raises max HP. Resist lowers damage taken, and reduction stops at the 25% cap. Swift adds Initiative, counted as extra actions. The reference action count is `1 / Mastery damage rate`, so one Swift point matches one Mastery point. That reference is only for this race. The character sheet still leaves Initiative Open. Healing uses the same Mastery rate and is not a second multiplier in the race.

Shipped rates are the proposed rates: Mastery +0.5% damage and healing, Vitality +0.5% of base max HP, Resist +0.4% less damage taken (cap 25%), Swift +1 Initiative. No rate was changed. Class HP per level and title names stay Open.

The mix is half the budget in Mastery and half in Vitality. On the shipped curve that is 49 and 49. Every pair below is inside 45–55%.

| Pair | Left spend (M / V / R / S) | Right spend | Left win rate |
|---|---|---|---|
| All Mastery vs all Vitality | budget / 0 / 0 / 0 | 0 / budget / 0 / 0 | 50.00% |
| All Mastery vs all Resist | budget / 0 / 0 / 0 | 0 / 0 / budget / 0 | 52.77% |
| All Vitality vs all Resist | 0 / budget / 0 / 0 | 0 / 0 / budget / 0 | 52.77% |
| Mix vs all Mastery | half / half / 0 / 0 | budget / 0 / 0 / 0 | 50.99% |
| Mix vs all Vitality | half / half / 0 / 0 | 0 / budget / 0 / 0 | 50.99% |
| Mix vs all Resist | half / half / 0 / 0 | 0 / 0 / budget / 0 | 53.76% |
| Mix vs all Swift | half / half / 0 / 0 | 0 / 0 / 0 / budget | 50.99% |
| All Swift vs all Mastery | 0 / 0 / 0 / budget | budget / 0 / 0 / 0 | 50.00% |
| All Swift vs all Vitality | 0 / 0 / 0 / budget | 0 / budget / 0 / 0 | 50.00% |
| All Swift vs all Resist | 0 / 0 / 0 / budget | 0 / 0 / budget / 0 | 52.77% |

**Resist flag.** The 25% cap is reached at 0.25 / 0.004 = 62.5 points (the spec's ~63). A full Resist spend of the curve budget wastes about 35.5 points. Full Resist is the weaker side (its best listed result is 46.24%, against the 49/49 mix). It stays inside 45–55%, so the per-point numbers are unchanged.

Respec: first free, then 100 × level Crypto Coins. +1 AP at level 30 stays a data milestone.
