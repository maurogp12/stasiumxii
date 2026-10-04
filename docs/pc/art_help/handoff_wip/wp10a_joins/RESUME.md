STATUS: parked 2026-10-03 (Crosshaven-first), incomplete

Zone-join blend kit (stoneford_rowanvale, northgate_windmere): scratch only, nothing written to ship/ or previews/.
- joins_tiles.py <out_root> [join,...]  -> blend tiles (done; out/ has 158 + 135 tiles + tiles_index.json)
- build_props.py <out_root>             -> ford/steps halves, signs (label_rect), end caps (squash method) (done, not yet visually reviewed: ford stitch, steps, signs)
- placer.py, testboard.py               -> reference placer + quick board renders
- cutraws.py                            -> src/*_cut.png from raw/wp10a_joins
- src/plate_samples.json                -> Crosshaven plate hex samples
Remaining: visual review of ford/steps/signs, seam scorer, atlas_meta.json + props.json, mocks, tile sheet, copy to ship,
READMEs, check_assets.py (world package), final grep. End caps must be rerun after region kit rebuilds.
