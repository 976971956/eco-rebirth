from __future__ import annotations

import importlib.util
from pathlib import Path


def load_shared():
    path = Path(__file__).resolve().with_name("build_authored_ground_species.py")
    spec = importlib.util.spec_from_file_location("eco_authored_ground", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load authored ground builder: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


GROUND = load_shared()


def main() -> None:
    GROUND.run_species(
        species="moose",
        description="Build the authored cinematic adult bull moose",
        source_files={
            "LICENSE.txt": "0023a9e0c77b4420cf66e84151c0cefeef2f332c46afa89ffcfbb65273171cdd",
            "SOURCE.md": "6a8331a8a4dd65d7048d5f22ea088e93f551171282dce0502806873ebe9c85b9",
        },
        source_reference="Elk / Poly by Google / Poly Pizza / CC-BY-3.0",
        config_overrides={
            "width": 0.80, "height": 0.88, "length": 1.72, "leg": 1.28,
            "paw": 0.25, "head": 0.54, "muzzle": 0.67, "neck": 0.86,
            "tail": 0.22, "ear": 0.38,
        },
        anatomy_overrides={
            "rib": 1.08, "waist": 0.68, "pelvis": 0.82, "belly": 0.90,
            "skull_width": 0.80, "skull_height": 0.84, "skull_length": 1.08,
            "muzzle_width": 0.84, "muzzle_height": 0.72, "muzzle_length": 1.34,
            "eye_scale": 0.042, "ear_width": 0.44, "muscle": 0.80, "foot_width": 0.64,
        },
        tint=(0.28, 0.20, 0.15),
    )


if __name__ == "__main__":
    main()
