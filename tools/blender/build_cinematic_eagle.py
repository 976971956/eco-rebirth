from __future__ import annotations
import importlib.util
from pathlib import Path

path = Path(__file__).resolve().with_name("build_authored_flight_species.py")
spec = importlib.util.spec_from_file_location("eco_authored_flight", path)
if spec is None or spec.loader is None:
    raise RuntimeError(f"cannot load authored flight builder: {path}")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
module.run_species(
    species="eagle",
    description="Build the authored cinematic adult golden eagle",
    source_files={"LICENSE.txt": "de99caf5658132cd3c40e049e10f44f97c701e8a8ab344d637ba179682f96366", "SOURCE.md": "51bc2ffb6362afa1fb9e4733b2c5e51f1f234e7c10fec0c97accaffc9cdc707c"},
    source_reference="Golden eagle / Poly by Google / Poly Pizza / CC-BY-3.0",
)
