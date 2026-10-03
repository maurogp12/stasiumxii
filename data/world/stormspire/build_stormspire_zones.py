"""WP5a text map for stormspire. Lines marked built are written now. The other lines wait for WP5b."""

TEXT_MAP = """region stormspire
stormspire_entry entry built south=stormspire_door east=stormspire_plateau_1
stormspire_plateau_1 middle west=stormspire_entry east=stormspire_plateau_2
stormspire_plateau_2 middle west=stormspire_plateau_1 east=stormspire_plateau_3
stormspire_plateau_3 middle west=stormspire_plateau_2
stormspire_door door built north=stormspire_entry
"""

if __name__ == "__main__":
    import runpy
    from pathlib import Path
    script = Path(__file__).resolve().parents[1] / "build_region_standins.py"
    runpy.run_path(str(script))["write_region"]("stormspire")
