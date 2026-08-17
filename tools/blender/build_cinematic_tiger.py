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
        species="tiger",
        description="Build the authored cinematic adult tiger",
        source_files={
            "LICENSE.txt": "5e8edb49758b67e9609f18f1ccd452e2e46ab48d31caeb5ce253971c8502b3ce",
            "SOURCE.md": "7a8f154670caba44014f4acf4389263607ba6dbb4738884ec2ff415857fbc964",
        },
        source_reference="Tiger / Poly by Google / Poly Pizza / CC-BY-3.0",
        config_overrides={
            "width": 0.76, "height": 0.74, "length": 1.72, "leg": 0.78,
            "paw": 0.25, "head": 0.64, "muzzle": 0.34, "neck": 0.22,
            "tail": 1.50, "ear": 0.25,
        },
        anatomy_overrides={
            "rib": 1.08, "waist": 0.72, "pelvis": 1.08, "belly": 0.90,
            "skull_width": 1.16, "skull_height": 1.00, "skull_length": 0.86,
            "muzzle_width": 0.92, "muzzle_height": 0.72, "muzzle_length": 0.76,
            "eye_scale": 0.046, "ear_width": 0.42, "muscle": 1.10, "foot_width": 1.08,
        },
        tint=(0.62, 0.27, 0.09),
    )


if __name__ == "__main__":
    main()
