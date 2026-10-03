# WP6b task mix

Repeatable tasks use the same paced shares as the normal mix in `docs/pc/media/wp15/balance_report.md`. Story and side missions stay one-time and are not a farm. Pace stays `pace_start` 1.6 and `pace_ratio` 0.9532 from `level_curve.json`.

Play time in the normal mix is world 50% / dungeons 30% / missions 20%. The mission fifth is split evenly across talk, reach, defeat, and clear. With pace applied to task XP, free play lands at 143.53 hours, inside 130–170. No source is above half of the XP.

| Source | Play time | XP share |
|---|---|---|
| Open world | 50% | 41.7% |
| Dungeons | 30% | 38.6% |
| Missions and tasks | 20% | 19.8% |
| Free hours to the cap | | 143.53 |
| Accept band | | 130–170 hours |

A reach task pays `xp_percent` (6) of `xp_to_next(level)` times `pace(level)`. Coins are the world-fight payout at that level, `3 + 1.5 × level`, times `(task minutes / 3)`. Reach tasks are 5 minutes, so they pay about one world fight plus the extra two minutes. At the level cap the XP is 0 and the coins stay.

| Level | Reach XP | Reach coins | World coins / min | Task coins / min |
|---|---|---|---|---|
| 1 | 10 | 8 | 1.5 | 1.6 |
| 25 | 524 | 68 | 13.5 | 13.6 |
| 49 | 487 | 128 | 25.5 | 25.6 |
| Cap | 0 | 130 | 26.0 | 26.0 |

The old flat 6% with the tier-floor coins was about 2× world XP per minute at level 25 and about 6× at level 49, and about 120 coins per minute against about 26 from fights at the cap. The paced share and the fight-rate coins remove that gap. Rounding the coin payout to a whole number leaves at most a tenth of a coin per minute.
