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
        species="zebra",
        description="Build the authored cinematic adult plains zebra",
        source_files={
            "LICENSE.txt": "e076c2d1408854978818a7a463b0b2de4776f9a7b29cb3b48dd067a6290ef855",
            "SOURCE.md": "94d89e7f43ced0f51d0bbde144ad18fb4c99fa85ee38bb0c17b993f1ded65abf",
        },
        source_reference="Zebra / Poly by Google / Poly Pizza / CC-BY-3.0",
        config_overrides={
            "width": 0.60, "height": 0.70, "length": 1.62, "leg": 1.06,
            "paw": 0.14, "head": 0.47, "muzzle": 0.54, "neck": 0.72,
            "tail": 0.72, "ear": 0.32,
        },
        anatomy_overrides={
            "rib": 0.98, "waist": 0.68, "pelvis": 0.88, "belly": 0.80,
            "skull_width": 0.78, "skull_height": 0.82, "skull_length": 1.08,
            "muzzle_width": 0.70, "muzzle_height": 0.58, "muzzle_length": 1.18,
            "eye_scale": 0.046, "ear_width": 0.40, "muscle": 0.74, "foot_width": 0.58,
        },
        tint=(0.88, 0.88, 0.84),
    )


if __name__ == "__main__":
    main()
