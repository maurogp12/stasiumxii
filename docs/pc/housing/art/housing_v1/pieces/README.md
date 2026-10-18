# Housing pieces v1 (Proposed), 2026-10-13
- furniture/: 94 transparent PNG cutouts + index.json. Each entry has name, room, tier, size_px, footprint_tiles (a guess), source, source_bbox, low_res, needs_paintover.
  - Method: SAM vit_b box+point prompts (onnx), hole fill, 1px erode + 0.8px feather.
  - Rugs: occluded parts are filled with TELEA inpaint.
  - Sala normal/rare items are cut from the 312px thumbnails in sala_tiers_1280x720_p1.png, upscaled 4.1x, so they are low_res.
- shells/: only sala_normal_empty.png is clean (a copy of rooms/room_living_L.png).
  - The other 14 shells failed the auto-fill (python plane-shift / exemplar inpaint): repeated walls, ghost furniture. They are kept only in _wip_autofill_FAILED/.
  - _masks/<room>_<tier>_furniture_mask.png = the furniture area (white) to inpaint. Use it with a reference-image edit (GenerateImage) or a paint-over.
  - The sala_rare mask is in thumbnail-upscaled coordinates (1280x615).
- exteriors/: Normal (stage4 copy), Rara 1.4x, Legendaria 2.0x width vs stage4, plus _half versions.
- PIECES_SHEET_1920x1080.png: contact sheet.
Scripts: /workspace/scratch/cut/ (cfg.py boxes, run.py SAM masks, export.py).
