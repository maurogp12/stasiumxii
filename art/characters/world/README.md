# PC world characters

## Hero

The world hero walks on the locked painted looks (4 Oct 2026), the same sheets the
dungeon pawn uses: `art/characters/painted/<class>/<class>_<kind>_<S|E>.png`.
`build_tools/pc_characters/build_pc_characters.py` builds them from the locked frames
(read from git at the lock commits) and writes the numbers to
`units/pc_character_specs.gd`. The old per-class strips, the `locked_s/` east walks,
`ironjaw_tall` and `bake_world_strips.py` are retired.

- Class: `progress.hero_class` (Ironjaw before a class is picked). The world sets it
  on the walker before it loads, so only that class's sheets are in memory.
- Ironjaw is the dark-steel HD walk v7 (cleaned like the locked actions).
- Gaits: `walk` is the painted walk, `run` is the same sheet played faster with a
  longer stride, `idle` loops the painted idle at the authored 17.144 fps.
- Facings: e (down-right) is the art S sheet, n (up-right) the art E sheet; s and w
  draw those mirrored. Every gait has all four.
- Height: Ironjaw stands 62.7 px above the ground at zoom 1 (the old `ironjaw_tall`
  hero). The other classes keep their pawn proportions (`WORLD.<class>.height`).
- Pace: the #271 hero speeds stay (55.10 px/s walking, 109.59 px/s running). The shown
  walk stride is the painted foot's travel per cycle, so the foot does not skate,
  unless that needs the legs faster than 1.6x the authored fps; then the leg rate is
  capped and the stride grows a little (natural leg speed, as on mobile). The run
  caps its leg rate at 2.0x.

See `scenes/world/crosshaven/world_strips.gd` and `units/painted_looks.gd`.

## NPCs

`npc/<role>/` holds the painted NPC roles (see `scenes/world/npc/npc_sprites.gd`).
