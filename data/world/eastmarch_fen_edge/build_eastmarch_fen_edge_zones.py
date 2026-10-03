"""WP5a text map for eastmarch_fen_edge. Lines marked built are written now. The other lines wait for WP5b."""

TEXT_MAP = """region eastmarch_fen_edge
eastmarch_fen_edge_entry entry built south=eastmarch_fen_edge_door east=eastmarch_fen_edge_middle
eastmarch_fen_edge_middle middle west=eastmarch_fen_edge_entry
eastmarch_fen_edge_door door built north=eastmarch_fen_edge_entry
"""

if __name__ == "__main__":
    import runpy
    from pathlib import Path
    script = Path(__file__).resolve().parents[1] / "build_region_standins.py"
    runpy.run_path(str(script))["write_region"]("eastmarch_fen_edge")
