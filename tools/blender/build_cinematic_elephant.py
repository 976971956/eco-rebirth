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
        species="elephant",
        description="Build the authored cinematic adult African elephant",
        source_files={
            "LICENSE.txt": "c1082932b5041bba69acbea70a35fb11eef7741808d029a81bb779bee492f8f3",
            "SOURCE.md": "e5ebad17ef75d19820892647bfbb135bd84d916de9dfd5c7eded989b4edaa4d8",
        },
        source_reference="Elephant / Poly by Google / Poly Pizza / CC-BY-3.0",
        config_overrides={
            "width": 1.18, "height": 1.14, "length": 1.82, "leg": 1.06,
            "paw": 0.36, "head": 0.80, "muzzle": 0.22, "neck": 0.24,
            "tail": 0.78, "ear": 0.88,
        },
        anatomy_overrides={
            "rib": 1.14, "waist": 1.00, "pelvis": 1.08, "belly": 1.14,
            "skull_width": 1.12, "skull_height": 1.04, "skull_length": 0.90,
            "muzzle_width": 0.84, "muzzle_height": 0.72, "muzzle_length": 0.76,
            "eye_scale": 0.030, "ear_width": 0.0, "muscle": 0.94, "foot_width": 1.18,
        },
        tint=(0.43, 0.45, 0.43),
    )


if __name__ == "__main__":
    main()
