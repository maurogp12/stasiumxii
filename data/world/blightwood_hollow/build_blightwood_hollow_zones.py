"""WP5a text map for blightwood_hollow. Lines marked built are written now. The other lines wait for WP5b."""

TEXT_MAP = """region blightwood_hollow
blightwood_hollow_entry entry built south=blightwood_hollow_door east=blightwood_hollow_middle_1
blightwood_hollow_middle_1 middle west=blightwood_hollow_entry east=blightwood_hollow_middle_2
blightwood_hollow_middle_2 middle west=blightwood_hollow_middle_1 east=blightwood_hollow_middle_3
blightwood_hollow_middle_3 middle west=blightwood_hollow_middle_2 east=blightwood_hollow_middle_4
blightwood_hollow_middle_4 middle west=blightwood_hollow_middle_3 east=blightwood_hollow_middle_5
blightwood_hollow_middle_5 middle west=blightwood_hollow_middle_4 east=blightwood_hollow_middle_6
blightwood_hollow_middle_6 middle west=blightwood_hollow_middle_5
blightwood_hollow_door door built north=blightwood_hollow_entry
"""

if __name__ == "__main__":
    import runpy
    from pathlib import Path
    script = Path(__file__).resolve().parents[1] / "build_region_standins.py"
    runpy.run_path(str(script))["write_region"]("blightwood_hollow")
