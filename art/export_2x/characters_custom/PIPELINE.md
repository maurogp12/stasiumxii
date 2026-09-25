# STASIUM XII — Gender + Color Customization Pipeline (slice 0.1.10+)

**Status:** Mauro Locked via Gamedeveloper — first art slice shipped (prebaked)  
**Platforms:** **PC main AND mobile** — shared `characters_custom` tree (no phone-only variants)  
**Date:** 2026-09-25 (America/New_York)

## Goals

1. Player chooses **gender** (`default` | `alt`) and a **named palette**
2. Combat identity / kits unchanged (Kestrel bow archer + gold-wing; Ironjaw stone maul)
3. Modular pipeline: gender = separate base strips; color = named LUT / region remap
4. Ship **baked PNG sets** now (mobile-safe) + `palettes.json` for future Godot shader remap

## Classes in this slice

| Class | Genders | Palettes |
|---|---|---|
| Kestrel | `default`, `alt` | `locked`, `storm`, `ember` |
| Ironjaw | `default`, `alt` (shared silhouette ≈ default) | `locked`, `slate`, `moss` |

Gender ids are **`default` / `alt`** — not m/f.

## Folder tree (NEW — do not overwrite live Batch-1 v3)

```
art/export_2x/characters_custom/
  kestrel/
    default/{locked,storm,ember}/anims/kestrel_{walk,attack}_{e,s,n,w}.png
    alt/{locked,storm,ember}/anims/...
  ironjaw/
    default/{locked,slate,moss}/anims/...
    alt/{locked,slate,moss}/anims/...   # copies of default this slice
  palettes.json
  PIPELINE.md
  CONTACT_SHEET.png
```

Each anim strip = **864×160** (6×144×160), same contract as live `export_2x/characters/*/anims/`.

Live Batch-1 v3 paths remain SoT for revert and are **READ ONLY**:

```
art/export_2x/characters/kestrel/anims/
art/export_2x/characters/ironjaw/anims/
```

## Godot wire contract

### Load path pattern

```
res://art/export_2x/characters_custom/{class}/{gender}/{palette}/anims/{class}_{anim}_{facing}.png
```

Examples:

```
res://art/export_2x/characters_custom/kestrel/default/storm/anims/kestrel_walk_e.png
res://art/export_2x/characters_custom/kestrel/alt/ember/anims/kestrel_attack_n.png
res://art/export_2x/characters_custom/ironjaw/default/moss/anims/ironjaw_walk_s.png
```

### IDs

| Slot | Allowed values |
|---|---|
| `class` | `kestrel`, `ironjaw` |
| `gender` | `default`, `alt` |
| `palette` | Kestrel: `locked` | `storm` | `ember` — Ironjaw: `locked` | `slate` | `moss` |
| `anim` | `walk`, `attack` |
| `facing` | `e`, `s`, `n`, `w` (SE/SW/NE/NW baked; no runtime `flip_h`) |

### Prebaked-first

- v0.1.10+: load the prebaked PNG for `{gender,palette}` directly (no shader required).
- Later: optional shader/LUT remap using hex maps in `palettes.json` against a single gender base.
- UI clickable gender/palette pickers are Godot-side; art delivers path contract only.

### Revert / fallback

If custom path missing or feature flagged off:

```
res://art/export_2x/characters/{class}/anims/{class}_{anim}_{facing}.png
```

That is the live Batch-1 v3 Locked default presentation.

### Timing (unchanged)

| anim | frames | fps | loop | impact (0-based) |
|---|---:|---:|---|---:|
| walk | 6 | 12 | yes | — |
| attack | 6 | 12 | no | 3 |

## Art method (this slice)

1. **default / locked** — copy of live Batch-1 v3 strips into `characters_custom/.../locked/`
2. **default / named palettes** — HSV region remap script (`art/tools/gender_color/bake_gender_color.py`)
   - Kestrel: olive cloth → storm slate / ember brick; gold wings → silver / copper; skin + bow wood held stable
   - Ironjaw: rusty plate → slate / moss; helmet bone + weapon stone + skin held stable
3. **Kestrel alt** — GenerateImage **unavailable** this session; fallback = Locked strips + readable dark ponytail overlay (phone-scale). Masters also under `art/characters/kestrel_alt/game/`. Same kit (bow, green cloak language, gold wings).
4. **Ironjaw alt** — byte copies of default strips (shared bulky silhouette per Locked mock)
5. `palettes.json` — proposed hex maps for Godot future remap

## Open items

- GenerateImage pass for true redrawn Kestrel alt turnaround (ponytail overlay is interim)
- Optional tiny Ironjaw alt helmet/silhouette tweak (mocks ≈ identical; skipped)
- Shader remap path in Godot (consume `palettes.json`) once prebaked validated on device
- Cast strips / other classes (Gloam/Mender/Bastion) out of scope
- Cosmetics shop free-vs-paid slots not decided

## Non-goals

- Do not overwrite `export_2x/characters/{kestrel,ironjaw}/anims/`
- Do not invent new palette names
- Do not change combat rules / kits
