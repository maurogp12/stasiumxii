"""WP5a text map for gloomfen_mire. Lines marked built are written now. The other lines wait for WP5b."""

TEXT_MAP = """region gloomfen_mire
gloomfen_mire_entry entry built south=gloomfen_mire_door east=gloomfen_mire_boardwalk_6
gloomfen_mire_boardwalk_1 middle east=gloomfen_mire_boardwalk_2
gloomfen_mire_boardwalk_2 middle west=gloomfen_mire_boardwalk_1 east=gloomfen_mire_boardwalk_3
gloomfen_mire_boardwalk_3 middle west=gloomfen_mire_boardwalk_2 east=gloomfen_mire_boardwalk_4
gloomfen_mire_boardwalk_4 middle west=gloomfen_mire_boardwalk_3 east=gloomfen_mire_boardwalk_5
gloomfen_mire_boardwalk_5 middle west=gloomfen_mire_boardwalk_4 north=gloomfen_mire_door
gloomfen_mire_boardwalk_6 middle built west=gloomfen_mire_entry
gloomfen_mire_door door built north=gloomfen_mire_entry south=gloomfen_mire_boardwalk_5
"""

if __name__ == "__main__":
    import runpy
    from pathlib import Path
    script = Path(__file__).resolve().parents[1] / "build_region_standins.py"
    runpy.run_path(str(script))["write_region"]("gloomfen_mire")
