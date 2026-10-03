"""WP5a text map for brinewake. Lines marked built are written now. The other lines wait for WP5b."""

TEXT_MAP = """region brinewake
brinewake_entry entry built south=brinewake_hub
brinewake_hub hub built north=brinewake_entry south=brinewake_door west=brinewake_coast_1 east=brinewake_coast_2
brinewake_coast_1 middle east=brinewake_hub
brinewake_coast_2 middle west=brinewake_hub
brinewake_island middle north=brinewake_door
brinewake_door door built north=brinewake_hub south=brinewake_island
"""

if __name__ == "__main__":
    import runpy
    from pathlib import Path
    script = Path(__file__).resolve().parents[1] / "build_region_standins.py"
    runpy.run_path(str(script))["write_region"]("brinewake")
