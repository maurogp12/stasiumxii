# Handoff to the next Claude session (2 Oct 2026)

Mauro asked: "explain Claude what you did and lets see how he does". Read this
first, then `CLAUDE.md`, `docs/AGENT_HANDOFF.md` (map of every approved system)
and `docs/CHANGE_LOG_CLAUDE.md` (every change, why, Mauro's words).

## Where things are

| | |
|---|---|
| Repo | `maurogp12/stasiumxii` (Godot 4.7.2, 2D isometric, Dofus / Waven / Wakfu look — never 3D) |
| Work branch | `claude/stasium-xii-development-6ni8g2` (all work below is pushed) |
| `mobile` | has everything up to **0.1.85** (merged by Mauro's order, PR #215) |
| Not merged yet | **0.1.86** (glide walk + camera follow) — merge only when Mauro says |
| Latest APK | `mobile-0.1.86-debug` (in-game Actualizar installs it) |
| Game server | `68.201.184.207:7777` (ENet/UDP, `--dedicated 7777`); must run the same build; online is 1v1 only today |

House rules (from `CLAUDE.md`): change nothing Mauro didn't approve or command;
log every change in `docs/CHANGE_LOG_CLAUDE.md` in the same push; run all 22
`tests/run_*_tests.gd` suites before every push; only merge into `mobile` /
`main` when Mauro says so; Bastion art is not touched unless Mauro asks.
APK publish steps are in `docs/AGENT_HANDOFF.md` ("Phone builds").

## What was done in this session (0.1.69 → 0.1.86)

1. **Combat rules** (0.1.69–0.1.82): line of sight, tall props block sight and
   walking, fighters block shots, random Koliseo deploy zones, map push stacks
   + Cleanse, Stasis monster kits / packs / boss spells, invisible Gloam with
   blind attacks, Ambush without Invisible, Advance max 2 per turn, tap
   picking fixes. Visual passes on monsters (bodies, gaits, 18% bigger, fading
   corpses).
2. **Koliseo 2v2 / 3v3** (engine + hot-seat screens): `CombatSim.team_size`,
   seats 0,2,4 vs 1,3,5, turns alternate by Init, team deploy / Ready, team
   HUD and colours. Online 2v2 / 3v3 is NOT built.
3. **Class balance** (rounds 1–2 + stun fix): numbers are in the change log.
   Tools: `tests/sim_duels.gd` (1v1), `tests/sim_teams.gd` (2v2 / 3v3). They are
   slow; the cloud machine pauses when the session is idle, so keep a turn
   active (foreground waits) while they run. Plan + targets:
   `docs/BALANCE_PLAN_HANDOFF.md` (counter wheel, element riders for later).
4. **Dungeon party** (0.1.85): ★1 solo, ★2 two players, ★3–5 party of 4,
   much harder (`StasisCatalog.STAR_SCALE` / `PARTY_SCALE`, tuned with
   `tests/sim_dungeons.gd`); finder panel with role requests and "Fill with AI"
   (AI is only the fallback when no player is found); AI companions
   `backend/hero_ai.gd`. Plan: `docs/DUNGEON_PARTY_PLAN.md`.
5. **Walking** (0.1.86): Wakfu-style glide (`ViewMotion.glide`): constant
   speed, continuous stride, two soft footfalls per tile, ease only at path
   ends, camera follows when zoomed in. The old hop / plant walk stays as
   `glide = false` and its tests pin it. Clip: `docs/media/walk_glide_0.1.86.mp4`
   (recorded with `tests/shot_walk_video.gd`, run with `--fixed-fps 30`).
6. **Temporary balance-test kit** stays ON (`backend/test_loadout.gd`,
   `ACTIVE = true`: all sets +5, all Stills, level 30 with builds). Remove only
   when Mauro says the balance is good.

## Mauro's goal right now

Make the game look and *move* like his two Wakfu videos ("thats the goal or
even better"). His latest focus: **walking**. Watch the reference he sent
again ("Thats the goal"): `docs/media/reference/wakfu_goal_walk.mp4` and
`docs/media/reference/wakfu_goal_walk_frames.jpg` (notes in that folder's
README).

## Art job in progress

Hero walk redraw, then the five bosses, reviewed by Claude, then stop and
wait for Mauro: `docs/ART_HANDOFF.md` (rules, checklist, status).

## Waiting on Mauro (ask, don't decide)

- **Bastion's walk sheet** turns to face the camera mid-step (east / west).
  Proposed fix: keep only his side-view frames. Needs Mauro's OK (Bastion art
  rule).
- **Ironjaw's legs barely move** (his walk was built from one pose); Kestrel's
  bow flickers between frames. A code-side body / cape sway can help; real
  Wakfu quality needs new 8–12 frame walk art per class and direction. There
  is no image generator in this environment.
- **Merge 0.1.86 into `mobile`?**
- **Next big job**: online work (party board create / join, role search,
  online 2v2 / 3v3) vs more graphics first. Graphics plan proposed to Mauro:
  island underside + clouds, daylight sky, softer grid, living details,
  front props, character outlines.
- Mauro's playtest of 0.1.84+ (balance feel, counters, team fights,
  dungeon difficulty).

## Known gotchas

- Godot SceneTree test scripts must touch autoloads in `_process`, not
  `_initialize`. New backend scripts use `preload`, not `class_name`.
- After any export / import: `git checkout --
  art/tilesets/original/pending/brinewake/brine_elevation_punch.png.import
  stasium-ref/maps/brinewake/elevation_punch.png.import`.
- `pkill -f <pattern>` kills your own shell if the pattern is in the command;
  use `pkill -x godot`.
- Commit new `.uid` files Godot creates, or the stop hook complains.
