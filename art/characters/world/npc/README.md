# PC world NPC bodies (painted, final)

Copied unchanged from `art/ironjaw-walk-help` at `8763e147`,
`docs/pc/art_help/npc_sprites_wip/npc_sprites/<role>/`. Scenario Art confirmed
the set is final; Mauro approved the import. The asset checker reports in that
commit (`check_report_npc_<role>.md`) are PASS for all 19 roles.

One folder per role: archivist, banker, coil_engineer, door_keeper, elder,
farmer, fen_guide, ferry_captain, fisher, forge_master, guide, herald, hermit,
last_watcher, shard_seer, smith, trader, warden, woodcutter.

- `<role>.json`: `frame_size_2x` 256×256, `pivot_px_2x` [128, 240], `mirror`
  (W = S flipped, E = N flipped, the locked facing rule), and `anims`
  (idle, walk with `stride_px` at 2x, talk one-shot, and `work`; the Warden
  ships `patrol_look` in place of `work`).
- `<anim>_s.png`, `<anim>_n.png`: 1x strips (128×128 frames). The game plays these.
- `_2x/<anim>_{s,n}.png`: 2x masters (256×256 frames), kept for rebakes and media.
- A few roles carry the art team's `README.md` (sources and known weak points).

Import: lossless (`compress/mode=0`), no mipmaps, linear filter on the sprite,
the same as the other world characters.

## How the game uses them

`scenes/world/npc/npc_sprites.gd` loads a role by its `npcs.json` `role`
(`seer` uses `shard_seer`). S is the front view down-right (+x on the grid),
N the back view up-left (-x); W and E come from the json mirror block. The 1x
frame draws at scale 0.84 with the pivot on the cell centre, so an NPC is
about 54 px tall at zoom 1.0, a little under the default hero. Plates sit on
the role's highest idle row. A role without a folder keeps the old tinted
class stand-in.
