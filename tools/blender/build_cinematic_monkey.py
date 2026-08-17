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
        species="monkey",
        description="Build the authored cinematic adult macaque",
        source_files={
            "LICENSE.txt": "2b06bbb8666cb743d1e1ec616befb7c023073bf1b1ca9ea55b782f384240dd79",
            "SOURCE.md": "ba90314be4b93f5c39a8877c28944037daed9cf6f2dfea0bdef82cf57e58e980",
        },
        source_reference="monkey / Poly by Google / Poly Pizza / CC-BY-3.0",
        config_overrides={
            "width": 0.54, "height": 0.66, "length": 0.90, "leg": 0.70,
            "paw": 0.25, "head": 0.47, "muzzle": 0.28, "neck": 0.24,
            "tail": 1.48, "ear": 0.18,
            "accent": "#a87358",
        },
        anatomy_overrides={
            "rib": 0.96, "waist": 0.72, "pelvis": 0.94, "belly": 0.84,
            "skull_width": 1.08, "skull_height": 1.12, "skull_length": 0.74,
            "muzzle_width": 0.86, "muzzle_height": 0.64, "muzzle_length": 0.62,
            "eye_scale": 0.050, "ear_width": 0.50, "muscle": 0.78, "foot_width": 1.18,
        },
        tint=(0.36, 0.24, 0.17),
    )


if __name__ == "__main__":
    main()
