"""WP5a text map for windmere. Lines marked built are written now. The other lines wait for WP5b."""

TEXT_MAP = """region windmere
windmere_entry entry built south=windmere_hub east=windmere_outer_3
windmere_hub hub built north=windmere_entry south=windmere_door west=windmere_outer_1 east=windmere_outer_2
windmere_outer_1 middle east=windmere_hub
windmere_outer_2 middle west=windmere_hub
windmere_outer_3 middle built west=windmere_entry
windmere_door door built north=windmere_hub
"""

if __name__ == "__main__":
    import runpy
    from pathlib import Path
    script = Path(__file__).resolve().parents[1] / "build_region_standins.py"
    runpy.run_path(str(script))["write_region"]("windmere")
