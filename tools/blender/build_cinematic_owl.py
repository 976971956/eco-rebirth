from __future__ import annotations

import importlib.util
from pathlib import Path


def load_shared():
    path = Path(__file__).resolve().with_name("build_authored_flight_species.py")
    spec = importlib.util.spec_from_file_location("eco_authored_flight", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load authored flight builder: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


FLIGHT = load_shared()


def main() -> None:
    FLIGHT.run_species(
        species="owl",
        description="Build the authored cinematic adult snowy owl",
        source_files={
            "LICENSE.txt": "255610b035d7a1300cc18196231b82d96b7ca2dd4507fa91757b061ea21e6fe1",
            "SOURCE.md": "6bfb6ef4bf488afcbc0549e56f7a4955ead52e9f7dda50f9e5b480706f3d2ad7",
        },
        source_reference="Owl / Poly by Google / Poly Pizza / CC-BY-3.0",
    )


if __name__ == "__main__":
    main()
