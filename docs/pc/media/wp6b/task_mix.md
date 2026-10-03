# WP6b task mix

Repeatable tasks pay `xp_percent` of `xp_to_next(level)` times `pace(level)`, and coins at the world-fight rate. Pace stays `pace_start` 1.6 and `pace_ratio` 0.9532 from `level_curve.json`. The pay level is the level stored when the reach step became ready.

In this build a task is offered at levels 1–50, and only to a Crosshaven landmark inside the town band for that level. Section 00 gives each Crosshaven town a band, clockwise from the safe west to the dark south. Where two bands share a level, the later town is used.

| Town | Levels | Landmarks |
|---|---|---|
| Stoneford | 1–10 | West road, Stoneford square |
| Northgate | 10–20 | North road, Northgate square |
| Eastmarch | 20–30 | East road, Eastmarch square |
| Southbridge | 30–40 | South road, Southbridge square |
| Westwatch | 40–50 | Southwest road, Westwatch square |

The Crossroads is the level-1 hub. Its givers send you into the town band for your level. A task is kept only when the walking path is at least 40 cells. Outer-region givers offer nothing while `world.regions_enabled` is off, so their tasks are measured or not offered. Outer landmarks stay pending and out of the pool until those regions reopen.

WP15 re-scores the free-play hours once WP5b fills the regions. The hours in `docs/pc/media/wp15/balance_report.md` are the unchanged simulator. They do not measure the tasks offered here.

A reach task pays 6% of the step times pace, at the ready level. Coins are `3 + 1.5 × level` times `(task minutes / 3)`. Reach tasks are 5 minutes. At the level cap the XP is 0 and the coins stay. The rows below are that formula.

| Level | Reach XP | Reach coins |
|---|---|---|
| 1 | 10 | 8 |
| 25 | 524 | 68 |
| 49 | 487 | 128 |
| Cap | 0 | 130 |
