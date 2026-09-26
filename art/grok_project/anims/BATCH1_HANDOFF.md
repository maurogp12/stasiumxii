# STASIUM XII — Batch-1 Animation Handoff (Kestrel + Ironjaw)

> **UPDATE 2026-09-25 ~18:49 EDT — Batch-1c shipped.**  
> See **`BATCH1C_SHIPPED.md`** for Godot paths / `cast` + `cast_mark` / hit / death / Gloam / louder Ironjaw attack.  
> **Kestrel+Ironjaw walk and Kestrel attack remain Batch-1 v3** (this document). Ironjaw attack live files are now Batch-1c.


**Date:** 2026-09-25 ~15:37 EDT (America/New_York)  
**Status:** **Batch-1 v3 walk (+ Kestrel attack) still live** · Batch-1c adds cast/cast_mark/hit/death + louder Ironjaw attack + Gloam — see BATCH1C_SHIPPED.md  
**Audience:** Godot Engineer (mobile branch) + Mauro

---

## Status summary

| Version | Method | Result |
|---|---|---|
| amplify v1/v2 | Whole-sprite PIL bob/squash | Rejected — “DEAD / no animation” at phone scale |
| **REDRAW v3** | Cut L/R legs + arms from Locked masters, affine-transform, composite | **Shipped replace-in-place** — visible stride / arm swing / attack arcs |

### GenerateImage

`GenerateImage` / CallDynamicTool (**namespace cursor**) was **not available** in this agent session (only MCP server: `cursor-github`). Tried discovery via GetMcpTools — no image-gen tool.

**Fallback used:** `make_batch1_v3_limbs.py` — hard cut-paste limb puppet from Locked game masters, exaggerated for Dofus SoT / ~56px phone pawns.

Solid-grey turnaround refs prepared for a future GenerateImage pass:
`art/grok_project/anims/refs_solid/{kestrel,ironjaw}_{se,ne}_grey.png`

### What changed vs amplify-v2

- Independent **left/right leg** rotations + translations (contact / squash / high-pass)
- Independent **arm** swings opposite to legs
- Attack: bow draw→release / hammer wind-up→overhead→impact smash
- Body bob + lean kept, but limbs break silhouette (not just squash of static pose)
- Impact frame **4** (1-based) = Godot index **3** — **unchanged**
- Same filenames / same export paths — **replace-in-place**

### Style / drift notes

- Colours + costume from Locked `game/*_{e,n}.png` masters (exact pixels cut)
- Cut seams / mild mush at joints possible (procedural, not hand-redrawn)
- Not true Grok-drawn limb art — if still soft at phone, next pass = GenerateImage when tool returns
- Cast Batch-1b (**kestrel_cast**) **not done** (walk+attack prioritized)

### Phone-read notes

- Walk bob peak ~18–24 px master on pass frames; stride ~26–32 px; foot lift ~32–40 px
- Attack extremes: Kestrel draw arms ±35–55°; Ironjaw hammer arc ±60–78° + impact squash ~0.76
- Preview GIFs (~50×56 NEAREST): `batch1_v3_phone_{kestrel,ironjaw}_{walk,attack}_e.gif`
- At 0.5 node scale export cells read ~56–80 screen px depending on device; limb travel should finally register vs v2 dead bob

---

## Facings

| Grok label | View | Code facing | Godot suffix | Source |
|---|---|---|---|---|
| SE | front 3/4 | E | `_e` | limb-puppet from game `*_e.png` |
| SW | front 3/4 mirrored | S | `_s` | baked flip of SE |
| NE | back 3/4 | N | `_n` | limb-puppet from game `*_n.png` |
| NW | back 3/4 mirrored | W | `_w` | baked flip of NE |

Mirrors are **baked into files**. Do **not** use `flip_h` at runtime.

---

## Canvas / pivot

| Stage | Cell size | Foot pivot |
|---|---|---|
| Master strips (`grok_project/anims/`) | **288×320** per cell | **(144, 304)** |
| Export strips (`export_2x/.../anims/`) | **144×160** per cell | **(72, 152)** |

Horizontal strips, left→right = frames 1..6. Master **1728×320**, export **864×160**. RGBA transparent, no shadow / floor / VFX.

---

## Timing (ANIMATION_FRAMES_SPEC §2.2)

| anim | class | frames | fps | loop | impact (1-based) | impact (0-based Godot) |
|---|---|---:|---:|---|---:|---:|
| `walk` | Kestrel, Ironjaw | 6 | **12** | yes | — | — |
| `attack` | Kestrel (bow) | 6 | 12 | no | **4** (release) | **3** |
| `attack` | Ironjaw (hammer) | 6 | 12 | no | **4** (contact) | **3** |

---

## Master strip paths

```
/workspace/art/grok_project/anims/
  kestrel_walk_{se,ne,sw,nw}.png
  kestrel_attack_{se,ne,sw,nw}.png
  ironjaw_walk_{se,ne,sw,nw}.png
  ironjaw_attack_{se,ne,sw,nw}.png
  frames_v3/          # 48 × 288×320 cells
  batch1_contact_sheet.png
  batch1_redraw_contact_sheet.png
  make_batch1_v3_limbs.py
  make_batch1.py      # prior amplify-v2 (superseded)
  BATCH1_HANDOFF.md
```

---

## Export_2x paths (CODE facings — use these in Godot)

```
/workspace/art/export_2x/characters/kestrel/anims/
  kestrel_walk_{e,s,n,w}.png
  kestrel_attack_{e,s,n,w}.png

/workspace/art/export_2x/characters/ironjaw/anims/
  ironjaw_walk_{e,s,n,w}.png
  ironjaw_attack_{e,s,n,w}.png
```

Map: **SE→e, SW→s, NE→n, NW→w**.

**16/16 walk+attack export PNGs overwritten.**

---

## Godot AnimatedSprite2D recipe (mobile)

Unchanged from amplify handoff:

- `centered = true`, `offset = Vector2(0, -72)`, `scale = Vector2(0.5, 0.5)`
- Anim names: `walk_e/s/n/w`, `attack_e/s/n/w`
- Walk: 6 @ 12 fps loop; Attack: 6 @ 12 fps one-shot; **impact frame index 3**
- Re-copy / re-sync `export_2x/.../anims/*.png` into `mobile`; no `.tres` rename required if already wired

---

## Contact sheet

- `/workspace/art/grok_project/anims/batch1_contact_sheet.png`
- `/workspace/art/grok_project/anims/batch1_redraw_contact_sheet.png`

---

## Out of scope (this batch)

- No Godot repo edits
- No combat rule invent
- No Gloam / Mender / Bastion / hit / death
- **No kestrel_cast (Batch-1b skipped — time / GenerateImage N/A)**
- No VFX in frames
- No runtime `flip_h`

---

## Next upgrade path

1. When `GenerateImage` is available: prompt with `refs_solid/*_grey.png` + pose lists from ANIMATION_FRAMES_SPEC §2.4; replace masters in place; re-mirror/export.
2. Or Mauro drops hand-drawn SE/NE strips into `grok_project/anims/` same filenames.
