# WP6b task mix

Repeatable tasks pay `xp_percent` of `xp_to_next(level)` times `pace(level)`, and coins at the world-fight rate. Pace stays `pace_start` 1.6 and `pace_ratio` 0.9532 from `level_curve.json`. The pay level is the level stored when the reach step became ready.

In this build a task is offered only at levels 1–10, and only to a Crosshaven landmark: the Crossroads, the five road chunks, and the five towns. Crosshaven Heart is levels 1–5 and Crosshaven Towns is levels 5–10. Outer-region landmarks are still pending and stay out of the offer pool until those regions reopen. Where two bands share a level, the later band is used. Level 10 is also Rowanvale, so the offer stops there.

WP15 re-scores the free-play hours once WP5b fills the regions. The hours in `docs/pc/media/wp15/balance_report.md` are the unchanged simulator. They do not measure the tasks offered here.

A reach task pays 6% of the step times pace, at the ready level. Coins are `3 + 1.5 × level` times `(task minutes / 3)`. Reach tasks are 5 minutes. At the level cap the XP is 0 and the coins stay. The rows below are that formula. They are not tasks the game offers past Crosshaven.

| Level | Reach XP | Reach coins |
|---|---|---|
| 1 | 10 | 8 |
| 25 | 524 | 68 |
| 49 | 487 | 128 |
| Cap | 0 | 130 |
