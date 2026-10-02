# STASIUM XII — PC version handoff (for the PC team and its Claude chat)

Mauro, 2 Oct 2026: "Another team of grok bots is going to continue working in
the pc version, create another chat for them." Read this, then `CLAUDE.md`,
`docs/AGENT_HANDOFF.md`, `docs/CHANGE_LOG_CLAUDE.md`, `docs/ART_HANDOFF.md`.

## Where the PC version is

| Branch | What it is | State (2 Oct 2026) |
|---|---|---|
| `main` | **PC version** (desktop Godot run, `main.tscn` / class select) | last update 25 Sep 2026 (#134, "mobile combat, feel and art into main without dungeons"); **238 commits behind `mobile`** |
| `mobile` | phone build | 0.1.85 (#215) |
| `claude/stasium-xii-development-6ni8g2` | mobile work branch (phone team) | 0.1.87: bosses with legs; APK `mobile-0.1.87-debug` |

Everything from 0.1.36 to 0.1.87 (line of sight, push stacks, Stasis kits,
Koliseo 2v2 / 3v3, balance rounds, party dungeons + finder, glide walk, boss
rework) lives on `mobile` / the work branch, **not on `main`**. Mauro decided
on 25 Sep that `main` gets mobile's combat, feel and art **without dungeons**.
Whether dungeons now go to PC is **his call — ask**.

## Rules (same as the phone team, from `CLAUDE.md`)

- Change nothing Mauro did not approve or command; propose first.
- Only Mauro merges into `main` / `mobile`. Work on your own branch, e.g.
  `pc/<topic>`; open PRs only when he asks.
- Log every change in `docs/CHANGE_LOG_CLAUDE.md` in the same push.
- Run all `tests/run_*_tests.gd` suites (Godot 4.7.2 headless) before pushing.
- The game stays 2D (Dofus / Waven / Wakfu look). Never invent an Open rule.
- Bastion art is not touched unless Mauro asks.
- Rules and numbers come from the GDD Blueprint and `README.md`; the balance
  numbers in the change log are the current ones.

## Do not collide with the phone team

- Do not push to `claude/stasium-xii-development-6ni8g2`, `mobile` or `apk/*`.
- Shared files (`backend/combat_sim.gd`, `data/kits.gd`, `units/pawn.gd`,
  `board_view.gd`, art folders) change on both sides: when you port from
  `mobile`, merge (never rebase someone else's branch) and keep both teams'
  changes.
- Art in progress on the phone side (Technical Artist): painted hero walk
  (approved by Claude, held), Ironjaw attack / hit / death (round 1), other
  heroes next, bosses Serra and Coilspire waiting for Mauro. Reuse those files
  when they land instead of painting a second set.

## Open questions for Mauro (PC)

1. What should the PC version get from `mobile` first (combat rules, balance,
   2v2 / 3v3, art, walk, bosses, dungeons)?
2. Keyboard / mouse controls and window size for PC.
3. Online server for PC: same `68.201.184.207:7777` and same build as phone?
