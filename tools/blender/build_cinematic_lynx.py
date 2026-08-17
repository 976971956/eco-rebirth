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
        species="lynx",
        description="Build the authored cinematic adult Eurasian lynx",
        source_files={
            "LICENSE.txt": "bc9794e25a80d7ddc4ba85297d0fa832864d69183bbb7fc30e559a700a73ee7d",
            "SOURCE.md": "11e503c5c54c51de8ed65ed59e8900c2587f2c1b7bd148577f31a72db46c75dd",
        },
        source_reference="Bobcat / Poly by Google / Poly Pizza / CC-BY-3.0",
        config_overrides={
            "width": 0.60, "height": 0.61, "length": 1.30, "leg": 0.76,
            "paw": 0.20, "head": 0.48, "muzzle": 0.30, "neck": 0.36,
            "tail": 0.30, "ear": 0.25,
        },
        anatomy_overrides={
            "rib": 0.98, "waist": 0.70, "pelvis": 1.04, "belly": 0.88,
            "skull_width": 1.13, "skull_height": 1.02, "skull_length": 0.88,
            "muzzle_width": 0.82, "muzzle_height": 0.66, "muzzle_length": 0.68,
            "eye_scale": 0.052, "ear_width": 0.48, "muscle": 0.90, "foot_width": 1.18,
        },
        tint=(0.50, 0.40, 0.30),
    )


if __name__ == "__main__":
    main()
