# WP15 balance report

Cap read from `level_curve.json`: 50.
Stats: Mastery, Vitality, Swift, Resist.

## Profiles

| Profile | Result |
|---|---|
| World only, free | 172.23 hours to the cap |
| World only, premium | 137.78 hours to the cap |
| Normal mix, free (world 50% / dungeons 30% / missions 20%) | Open |
| Normal mix, premium | Open |
| Free target (accept 130-170) | 150 hours |
| Premium target | 120 hours |
| Dungeon heavy | Open |
| Party of 4 | XP share 0.7 each. Time is Open. |

Dungeon XP per minute is 1.543 times open-world XP per minute at the normal star.

## Coins and drops per hour at the cap, fighting at that level

| Source | Coins / hour | Regular parts / hour | Rare parts / hour | Boxes / hour |
|---|---|---|---|---|
| Open world, free | 1560.0 | 0.60 | 0.00 | 0.00 |
| Open world, premium | 1794.0 | 0.66 | 0.00 | 0.00 |
| Dungeon, normal star, free | 2496.0 | 4.00 | 0.00 | 0.00 |
| Dungeon, normal star, premium | 2870.4 | 4.40 | 0.00 | 0.00 |

Mission coin amounts are a range in the spec. A single number inside each tier is Open.

## Zone bands

| Zone | Level min | Level max |
|---|---|---|
| crosshaven_heart | 1 | 5 |
| crosshaven_towns | 5 | 10 |
| rowanvale | 10 | 15 |
| windmere | 15 | 20 |
| brinewake | 20 | 25 |
| slagcrown | 25 | 30 |
| eastmarch_fen_edge | 25 | 30 |
| gloomfen_mire | 30 | 38 |
| stormspire | 35 | 40 |
| ashen_shardfields | 38 | 45 |
| blightwood_hollow | 45 | 50 |

## Findings

| Check | Status | Detail |
|---|---|---|
| star_1.0 | pass | Dungeon vs world XP per minute is 1.543. |
| star_1.2 | outside | Dungeon vs world XP per minute is 1.851. |
| star_1.45 | outside | Dungeon vs world XP per minute is 2.237. |
| star_1.7 | outside | Dungeon vs world XP per minute is 2.623. |
| star_2.0 | outside | Dungeon vs world XP per minute is 3.086. |
| tier_10 | outside | Point budget is 180% above the previous tier. The 25–35% step is the spec's other reading. |
| tier_20 | outside | Point budget is 71% above the previous tier. The 25–35% step is the spec's other reading. |
| tier_30 | outside | Point budget is 42% above the previous tier. The 25–35% step is the spec's other reading. |
| tier_40 | pass | Point budget is 29% above the previous tier. The 25–35% step is the spec's other reading. |
| tier_50 | outside | Point budget is 23% above the previous tier. The 25–35% step is the spec's other reading. |
| ap_6_kestrel | outside | Raw kit output is 12% from the damage-class median. Set tuning that would pull this inside the band is Open. |
| ap_6_gloam | outside | Raw kit output is -19% from the damage-class median. Set tuning that would pull this inside the band is Open. |
| ap_7_ironjaw | outside | Raw kit output is 11% from the damage-class median. Set tuning that would pull this inside the band is Open. |
| mission_minutes | open | Mission duration is Open, so normal-mix hours, XP shares, and the world-only slowdown are Open. |
| normal_mix_band | open | Free normal-mix target 150 h (accept 130-170) and premium target 120 h are not scored. Mission minutes are Open. Pace is pace_start 1.6000 and pace_ratio 0.9532 from the curve. World-only free is 172.23 h and premium world-only is 137.78 h. |
| dungeon_heavy | open | The dungeon-heavy mix is Open. The spec names the profile and does not give its time split. |
| per_point_values | open | Per-point Mastery, Vitality, Swift and Resist values are Open, so set rules 3, 4 and 5 are not scored. |
| zones | pass | Every zone band ends at or below the curve cap. |

Decidable checks passed. Open items are not treated as a pass or a fail.

