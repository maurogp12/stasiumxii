"""WP5a text map for slagcrown. Lines marked built are written now. The other lines wait for WP5b."""

TEXT_MAP = """region slagcrown
slagcrown_entry entry built south=slagcrown_hub east=slagcrown_volcanic_3
slagcrown_hub hub built north=slagcrown_entry south=slagcrown_door west=slagcrown_volcanic_1 east=slagcrown_volcanic_2
slagcrown_volcanic_1 middle east=slagcrown_hub
slagcrown_volcanic_2 middle west=slagcrown_hub
slagcrown_volcanic_3 middle built west=slagcrown_entry
slagcrown_door door built north=slagcrown_hub
"""

if __name__ == "__main__":
    import runpy
    from pathlib import Path
    script = Path(__file__).resolve().parents[1] / "build_region_standins.py"
    runpy.run_path(str(script))["write_region"]("slagcrown")
