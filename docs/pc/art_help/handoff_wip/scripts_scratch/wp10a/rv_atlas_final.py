"""Rebuild atlas_meta/anim_meta/props.json for both kits with the TA follow-up notes (3 Oct) and the grade note."""
import json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import rv_atlas

NOTES = {
 'rowanvale': [
  "3 Oct TA follow-up: world-kit gate (check_assets --package world) replaces the combat-prop width rule.",
  "tree_apple_orchard, tree_apple_orchard_fruiting, tree_pear: re-cut from the raw paintings onto the tree_broad canvas 112x128 (1x) / 224x256 (2x) at the full manifest art height (200 / 200 / 212 px at 2x), canopies unclipped; trunk contact 1.5 / 2.5 / 5 px (1x) left of the cell centre so the right-leaning canopies fit (base still inside the 1x1 footprint, anchor = footprint south tip).",
  "border_orchard_hedge_nwse/nesw: canvas 64x64 -> 96x128 (1x); scaled to the manifest art height 96 px (2x) instead of the 112 px target width, so segment ends overlap the neighbours.",
  "old_windmill_body + old_windmill: size_class landmark_wide, canvas 288x256 (1x) / 576x512 (2x) (was hero 192x256) for the larger sails (radius 96 px 1x, frame 200 px 1x); body raised 12 px (2x) so its base lies inside the 2x2 footprint diamond.",
  "old_windmill (static) is listed in props.json again.",
  "old_windmill_sails: 12 frames, frame 200x200 (1x) / 400x400 (2x) centred on the hub; frame size is independent of the landmark_wide body canvas (checker: frame-exact strip, hub at frame centre, hub matches the static).",
  "TA fix list (3 Oct, partial before parking): fruiting apple + pear canopy hue-shifted to the plain apple's green (median ~72; pears masked out, red apples untouched); hedges hue-shifted to ~70 at 0.86 saturation and their run ends trimmed to <= 8 px past the cell edge; beehive_box boxes repainted warm off-white (lid/legs honey-gold wood).",
  "trees +4 px, scarecrow +6 px (2x) lower so the lowest opaque row is within 24 px of the anchor.",
 ],
 'windmere': [
  "3 Oct TA follow-up: world-kit gate (check_assets --package world) replaces the combat-prop width rule.",
  "border_snowy_pine_wall(_b,_c): +-70 px (2x) width cap removed; art fills the manifest 96x128 (1x) canvas, about +-94 px at 2x = ~15 px (1x) neighbour overlap.",
  "tree_pine_snowy_a/_b, tree_pine_frozen_blue: tree_conifer canvas 96x128 (1x) / 192x256 (2x), art fits unclipped (<= +-79 px at 2x); full manifest art height. tree_pine_frozen_blue gets the same sway as the other pines.",
  "frost_spire: +-132 px width refit undone (full manifest height, art -137..130 px at 2x); emit window boxes re-measured.",
  "Root-level *_emit.png copies (props-checker index) removed; emit masks live in props/emit/ and props/emit/_2x/ only.",
  "pines +4 px, lantern_post_warm +6 px (2x) lower so the lowest opaque row is within 24 px of the anchor.",
 ],
}
GRADE_NOTE = {'rowanvale': "Recorded for reference only; not baked into the art.",
              'windmere': "Recorded for reference only. Sprites and tiles are painted in natural colour; the stand-in grade is NOT baked in and is left to the runtime zone grade."}

for r in ('rowanvale', 'windmere'):
    rv_atlas.run(r, NOTES[r])
    p = Path(f'/workspace/stasium-pc-look/ship/wp10a_{r}/atlas_meta.json'); m = json.loads(p.read_text())
    m['wp10a']['grade']['applied_in_art'] = False; m['wp10a']['grade']['note'] = GRADE_NOTE[r]
    p.write_text(json.dumps(m, indent=1, default=float))
