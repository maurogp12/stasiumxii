# WP15 balance report

Cap read from `level_curve.json`: 50.
Stats: Mastery, Vitality, Swift, Resist.

## Profiles

| Profile | Result |
|---|---|
| World only, free | 172.23 hours to the cap |
| World only, premium | 137.78 hours to the cap |
| Normal mix, free (world 50% / dungeons 30% / missions 20%) | 143.53 hours to the cap |
| Normal mix, premium | 114.82 hours to the cap |
| Free target (accept 130-170) | 150 hours |
| Premium target | 120 hours |
| Dungeon heavy | Open |
| Party of 4 | XP share 0.7 each. Time is Open. |

Dungeon XP per minute is 1.543 times open-world XP per minute at the normal star.
XP share by play time: world 41.7%, dungeons 38.6%, missions 19.8%.
World-only takes 1.20 times as long as the normal mix. It is not scored against the free accept band.

## Normal-mix milestones, free

| Level | Hours |
|---|---|
| 10 | 8.17 |
| 20 | 22.52 |
| 30 | 45.69 |
| 40 | 83.10 |
| cap | 143.53 |

Last level step: 7.43 hours.

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
| mission_minutes | pass | Talk 3 min, reach 5 min, defeat is fights times minutes per fight, clear 20 min. Missions split the mission share evenly. |
| normal_mix_band | pass | Free normal mix 143.53 h (accept 130-170). Premium normal mix 114.82 h (target 120, scaled band 104-136). Pace 1.6000 and 0.9532. World-only 172.23 h is not scored against that band. |
| xp_shares | pass | XP by play time: world 41.7%, dungeons 38.6%, missions 19.8%. |
| world_only_slower | pass | World-only is 1.20 times the normal mix. The corrected band is 1.15-1.20. The pace factor is not retuned. |
| dungeon_heavy | open | The dungeon-heavy mix is Open. The spec names the profile and does not give its time split. |
| per_point_values | open | Per-point Mastery, Vitality, Swift and Resist values are Open, so set rules 3, 4 and 5 are not scored. |
| zones | pass | Every zone band ends at or below the curve cap. |

Decidable checks passed. Open items are not treated as a pass or a fail.
