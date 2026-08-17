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
        species="goat",
        description="Build the authored cinematic adult mountain goat",
        source_files={
            "LICENSE.txt": "5fdb237de7183cac784f8db7c4fb505089c88a4e97ffdc796439d1a3232cbe3c",
            "SOURCE.md": "8c3318aaf24ea4929e2e5e9f6b09b0429578ba6e453cc6c11059b89dd269cd22",
        },
        source_reference="Goat / Poly by Google / Poly Pizza / CC-BY-3.0",
        config_overrides={
            "width": 0.61, "height": 0.66, "length": 1.30, "leg": 0.74,
            "paw": 0.17, "head": 0.49, "muzzle": 0.42, "neck": 0.47,
            "tail": 0.25, "ear": 0.20,
        },
        anatomy_overrides={
            "rib": 0.96, "waist": 0.72, "pelvis": 0.88, "belly": 0.84,
            "skull_width": 0.82, "skull_height": 0.84, "skull_length": 1.02,
            "muzzle_width": 0.72, "muzzle_height": 0.62, "muzzle_length": 1.12,
            "eye_scale": 0.046, "ear_width": 0.38, "muscle": 0.78, "foot_width": 0.64,
        },
        tint=(0.58, 0.54, 0.47),
    )


if __name__ == "__main__":
    main()
