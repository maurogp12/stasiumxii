"""WP5a text map for ashen_shardfields. Lines marked built are written now. The other lines wait for WP5b."""

TEXT_MAP = """region ashen_shardfields
ashen_shardfields_entry entry built south=ashen_shardfields_door east=ashen_shardfields_dune_1
ashen_shardfields_dune_1 middle west=ashen_shardfields_entry east=ashen_shardfields_dune_2
ashen_shardfields_dune_2 middle west=ashen_shardfields_dune_1 east=ashen_shardfields_dune_3
ashen_shardfields_dune_3 middle west=ashen_shardfields_dune_2 east=ashen_shardfields_dune_4
ashen_shardfields_dune_4 middle west=ashen_shardfields_dune_3 east=ashen_shardfields_dune_5
ashen_shardfields_dune_5 middle west=ashen_shardfields_dune_4
ashen_shardfields_door door built north=ashen_shardfields_entry
"""

if __name__ == "__main__":
    import runpy
    from pathlib import Path
    script = Path(__file__).resolve().parents[1] / "build_region_standins.py"
    runpy.run_path(str(script))["write_region"]("ashen_shardfields")
