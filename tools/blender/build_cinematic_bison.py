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
        species="bison",
        description="Build the authored cinematic adult American bison",
        source_files={
            "LICENSE.txt": "52c03b54cfa230c40f406ce61fc151ce6fe843d3cc1b73553f581b370f5abfe8",
            "SOURCE.md": "e74cd095ddebb2c84241a9824125b3c14626f1836c1ced5ebde2fee45eb77b74",
        },
        source_reference="Bison / Poly by Google / Poly Pizza / CC-BY-3.0",
        config_overrides={
            "width": 1.02, "height": 1.02, "length": 1.64, "leg": 0.72,
            "paw": 0.23, "head": 0.66, "muzzle": 0.56, "neck": 0.24,
            "tail": 0.60, "ear": 0.17,
        },
        anatomy_overrides={
            "rib": 1.28, "waist": 0.78, "pelvis": 0.82, "belly": 0.98,
            "skull_width": 1.14, "skull_height": 0.94, "skull_length": 0.94,
            "muzzle_width": 1.02, "muzzle_height": 0.78, "muzzle_length": 0.96,
            "eye_scale": 0.036, "ear_width": 0.40, "muscle": 1.08, "foot_width": 0.74,
        },
        tint=(0.25, 0.18, 0.13),
    )


if __name__ == "__main__":
    main()
