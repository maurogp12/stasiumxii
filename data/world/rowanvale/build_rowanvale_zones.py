"""WP5a text map for rowanvale. Lines marked built are written now. The other lines wait for WP5b."""

TEXT_MAP = """region rowanvale
rowanvale_entry entry built south=rowanvale_hub east=rowanvale_farmland_3
rowanvale_hub hub built north=rowanvale_entry south=rowanvale_door west=rowanvale_farmland_1 east=rowanvale_farmland_2
rowanvale_farmland_1 middle east=rowanvale_hub
rowanvale_farmland_2 middle west=rowanvale_hub
rowanvale_farmland_3 middle built west=rowanvale_entry
rowanvale_door door built north=rowanvale_hub
"""

if __name__ == "__main__":
    import runpy
    from pathlib import Path
    script = Path(__file__).resolve().parents[1] / "build_region_standins.py"
    runpy.run_path(str(script))["write_region"]("rowanvale")
