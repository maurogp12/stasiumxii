# STASIUM XII — instructions for Claude sessions

- **Do not change anything unless Mauro approves it or commands it.** Propose
  first; wait for a clear yes. This includes code, art, rules, tests and maps.
- **Record every change** in `docs/CHANGE_LOG_CLAUDE.md` (what, why, who
  asked, commit, version) in the same push as the change.
- Only Mauro merges into `mobile` / `main`. Work on your assigned branch and
  open PRs only when he asks.
- Rules and kit numbers come from the GDD Blueprint and `README.md`. Never
  invent an Open item. Bastion art is not touched unless Mauro asks.
- The phone APK ships from `mobile`. Test builds go to an `apk/<version>`
  branch, which publishes the `mobile-<version>-debug` release that the
  in-game Actualizar button installs.
- Run all `tests/run_*_tests.gd` suites (Godot 4.7.2 headless) before pushing.
- Read `docs/AGENT_HANDOFF.md` first: it maps every system Mauro has approved
  (line of sight, push stacks, Stasis kits, maps, looks). Do not change any of
  it unless Mauro commands it. The game stays 2D (Dofus / Waven / Wakfu look).
