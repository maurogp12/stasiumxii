# STASIUM XII — Batch-1c Shipped (Godot one-pager)

**Date:** 2026-09-25 ~18:49 EDT  
**Status:** SHIPPED to live `export_2x/.../anims/` (non-walk for K/I; full set for Gloam)  
**Method:** Locked-identity limb-puppet (`make_batch1c_limbs.py`). GenerateImage not callable in this executor tool surface; `gen_raw/*_gen.png` NOT shipped (identity drift).  
**Audience:** Parent/TA → Godot Engineer (mobile). Do not message Godot from TA.

---

## Policy this cut

| Asset | Action |
|---|---|
| Kestrel / Ironjaw **walk** | **UNTOUCHED** — live Batch-1 v3 SoT (Godot wiring now) |
| Kestrel **attack** | **UNTOUCHED** — live v3 stays |
| Ironjaw **attack** | **REPLACED** — Batch-1c louder (mean Δ 26.6 > v3 23.9) |
| Kestrel cast / cast_mark / hit / death | **NEW** live files |
| Ironjaw hit / death | **NEW** live files |
| Gloam walk / attack / cast / hit / death | **NEW** live files (full set) |

Canvas: export cell **144×160**, pivot **(72,152)**; master **288×320**, pivot **(144,304)**. Mirrors baked (`_e←se`, `_s←sw`, `_n←ne`, `_w←nw`). No runtime `flip_h`.

---

## Godot SpriteFrames naming

Play `"{anim}_{facing}"` with facing in `e|s|n|w`.

| class | anim | frames | fps | loop | impact (0-based) | notes |
|---|---|---:|---:|---|---:|---|
| kestrel | `cast` | 6 | 10 | no | **3** | Detonate signal |
| kestrel | `cast_mark` | 6 | 12 | no | **3** | Mark Shot release (separate from `attack`) |
| kestrel | `hit` | 4 | 12 | no | **0** | |
| kestrel | `death` | 6 | 10 | no (hold last) | **4** | ground contact |
| kestrel | `walk` / `attack` | 6 | 12 | walk yes | attack **3** | **still Batch-1 v3** |
| ironjaw | `attack` | 6 | 12 | no | **3** | **Batch-1c louder slam** |
| ironjaw | `hit` | 4 | 12 | no | **0** | |
| ironjaw | `death` | 6 | 10 | no (hold last) | **4** | |
| ironjaw | `walk` | 6 | 12 | yes | — | **still Batch-1 v3** |
| gloam | `walk` | 6 | 12 | yes | — | new |
| gloam | `attack` | 5 | 12 | no | **2** | X-slash |
| gloam | `cast` | 4 | 10 | no | **2** | |
| gloam | `hit` | 4 | 12 | no | **0** | |
| gloam | `death` | 6 | 10 | no (hold last) | **4** | |

Strip widths @ export: 6f→864×160, 5f→720×160, 4f→576×160.

---

## Droppable export paths (live)

### Kestrel (new)
```
art/export_2x/characters/kestrel/anims/kestrel_cast_{e,s,n,w}.png
art/export_2x/characters/kestrel/anims/kestrel_cast_mark_{e,s,n,w}.png
art/export_2x/characters/kestrel/anims/kestrel_hit_{e,s,n,w}.png
art/export_2x/characters/kestrel/anims/kestrel_death_{e,s,n,w}.png
```
Unchanged: `kestrel_walk_*`, `kestrel_attack_*` (v3).

### Ironjaw
```
art/export_2x/characters/ironjaw/anims/ironjaw_attack_{e,s,n,w}.png   # REPLACED louder
art/export_2x/characters/ironjaw/anims/ironjaw_hit_{e,s,n,w}.png
art/export_2x/characters/ironjaw/anims/ironjaw_death_{e,s,n,w}.png
```
Unchanged: `ironjaw_walk_*` (v3).

### Gloam (all new)
```
art/export_2x/characters/gloam/anims/gloam_walk_{e,s,n,w}.png
art/export_2x/characters/gloam/anims/gloam_attack_{e,s,n,w}.png
art/export_2x/characters/gloam/anims/gloam_cast_{e,s,n,w}.png
art/export_2x/characters/gloam/anims/gloam_hit_{e,s,n,w}.png
art/export_2x/characters/gloam/anims/gloam_death_{e,s,n,w}.png
```

---

## Contact / phone preview

- Contact sheet: `art/grok_project/anims/batch1c_contact_sheet.png` (also under `batch1c_staging/`)
- Phone GIFs: `art/grok_project/anims/batch1c_staging/batch1c_phone_{class}_{anim}_e.gif`
- Staging mirror of exports: `art/export_2x/characters/{kestrel,ironjaw,gloam}/anims_batch1c/`
- Generator: `art/grok_project/anims/make_batch1c_limbs.py`

---

## QA notes

- Identity: Kestrel green cloak + gold accents present; Ironjaw red armor present; Gloam blue cloak present.
- Transparent RGBA, no floor/shadow/VFX.
- Ironjaw attack mean frame-delta **26.58** vs live v3 **23.91** → shipped louder rewrite.
- K/I walk mtimes remain 2026-09-25 15:37 EDT (v3).
- `gen_raw/*_gen.png` held (not Locked).

## Deferred / out of scope

- No louder Kestrel walk/attack this cut (leave v3 until a pass beats it).
- No GenerateImage strips this session (tool not on executor surface; limb path = Locked-id redesign per Gamedev greenlight).
- No gender/color trees touched.
- No Godot repo edits from TA.
