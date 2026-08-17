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
        species="wolverine",
        description="Build the authored cinematic adult wolverine",
        source_files={
            "LICENSE.txt": "d2c2d1eeffd464d8277f67d76c6ecc76ac32c83e4dd97bc425f3494511261153",
            "SOURCE.md": "5d1e4a63fa020de3f7668aa57a0180ee3fb3cb80ef29d6332847e7e25876dd5e",
        },
        source_reference="Wolverine / all of life / Sketchfab / CC-BY-4.0",
        config_overrides={
            "width": 0.70, "height": 0.59, "length": 1.34, "leg": 0.50,
            "paw": 0.22, "head": 0.53, "muzzle": 0.36, "neck": 0.38,
            "tail": 0.64, "ear": 0.12,
        },
        anatomy_overrides={
            "rib": 1.13, "waist": 0.93, "pelvis": 1.06, "belly": 1.00,
            "skull_width": 1.14, "skull_height": 0.96, "skull_length": 0.93,
            "muzzle_width": 0.88, "muzzle_height": 0.72, "muzzle_length": 0.82,
            "eye_scale": 0.041, "ear_width": 0.48, "muscle": 1.06, "foot_width": 1.22,
        },
        tint=(0.23, 0.20, 0.18),
    )


if __name__ == "__main__":
    main()
