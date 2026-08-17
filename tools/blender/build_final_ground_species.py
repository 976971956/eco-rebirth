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


MANIFEST = {
    "turtle": dict(description="adult land tortoise", reference="Turtle / Poly by Google / Poly Pizza / CC-BY-3.0", config={"width": 0.86, "height": 0.54, "length": 1.18, "leg": 0.48, "paw": 0.28, "head": 0.36, "muzzle": 0.30, "neck": 0.54, "tail": 0.16, "ear": 0.0}, anatomy={"rib": 1.10, "waist": 1.06, "pelvis": 1.10, "belly": 0.64, "skull_width": 0.88, "skull_height": 0.70, "muzzle_width": 0.78, "muzzle_height": 0.58, "muzzle_length": 0.80, "eye_scale": 0.044, "muscle": 0.72, "foot_width": 1.20}, tint=(0.34, 0.39, 0.25)),
    "cheetah": dict(description="adult cheetah", reference="Cheetah / Poly by Google / Poly Pizza / CC-BY-3.0", config={"width": 0.47, "height": 0.52, "length": 1.62, "leg": 0.92, "paw": 0.20, "head": 0.38, "muzzle": 0.30, "neck": 0.44, "tail": 1.72, "ear": 0.18}, anatomy={"rib": 0.84, "waist": 0.54, "pelvis": 0.88, "belly": 0.68, "skull_width": 0.84, "skull_height": 0.80, "muzzle_width": 0.72, "muzzle_height": 0.54, "muzzle_length": 0.80, "eye_scale": 0.056, "ear_width": 0.44, "muscle": 0.70, "foot_width": 0.82}, tint=(0.66, 0.48, 0.25)),
    "rhino": dict(description="adult rhinoceros", reference="Rhinoceros / Poly by Google / Poly Pizza / CC-BY-3.0", config={"width": 1.08, "height": 0.98, "length": 1.84, "leg": 0.78, "paw": 0.34, "head": 0.68, "muzzle": 0.74, "neck": 0.44, "tail": 0.44, "ear": 0.20}, anatomy={"rib": 1.12, "waist": 0.98, "pelvis": 1.06, "belly": 1.04, "skull_width": 0.96, "skull_height": 0.80, "muzzle_width": 1.02, "muzzle_height": 0.80, "muzzle_length": 1.26, "eye_scale": 0.030, "ear_width": 0.42, "muscle": 1.04, "foot_width": 1.12}, tint=(0.46, 0.45, 0.41)),
    "gorilla": dict(description="adult silverback gorilla", reference="Gorilla / Poly by Google / Poly Pizza / CC-BY-3.0", config={"width": 1.00, "height": 1.02, "length": 1.10, "leg": 0.76, "paw": 0.34, "head": 0.58, "muzzle": 0.42, "neck": 0.28, "tail": 0.0, "ear": 0.16}, anatomy={"rib": 1.22, "waist": 0.76, "pelvis": 0.90, "belly": 0.92, "skull_width": 1.14, "skull_height": 1.06, "skull_length": 0.76, "muzzle_width": 1.04, "muzzle_height": 0.80, "muzzle_length": 0.70, "eye_scale": 0.040, "ear_width": 0.46, "muscle": 1.18, "foot_width": 1.24}, tint=(0.10, 0.11, 0.12)),
    "hippo": dict(description="adult hippopotamus", reference="Hippopotamus / Poly by Google / Poly Pizza / CC-BY-3.0", config={"width": 1.22, "height": 0.94, "length": 1.78, "leg": 0.54, "paw": 0.35, "head": 0.80, "muzzle": 0.82, "neck": 0.28, "tail": 0.24, "ear": 0.15}, anatomy={"rib": 1.14, "waist": 1.04, "pelvis": 1.12, "belly": 1.12, "skull_width": 1.20, "skull_height": 0.84, "muzzle_width": 1.26, "muzzle_height": 0.84, "muzzle_length": 1.12, "eye_scale": 0.032, "ear_width": 0.42, "muscle": 1.04, "foot_width": 1.20}, tint=(0.43, 0.39, 0.40)),
    "hyena": dict(description="adult spotted hyena", reference="Spotted hyena / Poly by Google / Poly Pizza / CC-BY-3.0", config={"width": 0.64, "height": 0.72, "length": 1.46, "leg": 0.80, "paw": 0.24, "head": 0.52, "muzzle": 0.48, "neck": 0.48, "tail": 0.68, "ear": 0.34}, anatomy={"rib": 1.10, "waist": 0.68, "pelvis": 0.78, "belly": 0.78, "skull_width": 1.02, "skull_height": 0.90, "muzzle_width": 0.84, "muzzle_height": 0.68, "muzzle_length": 1.08, "eye_scale": 0.048, "ear_width": 0.48, "muscle": 0.88, "foot_width": 0.90}, tint=(0.52, 0.38, 0.22)),
    "lion": dict(description="adult male lion", reference="Lion / Poly by Google / Poly Pizza / CC-BY-3.0", config={"width": 0.78, "height": 0.78, "length": 1.72, "leg": 0.88, "paw": 0.28, "head": 0.58, "muzzle": 0.42, "neck": 0.46, "tail": 1.52, "ear": 0.17}, anatomy={"rib": 1.10, "waist": 0.70, "pelvis": 1.00, "belly": 0.86, "skull_width": 1.14, "skull_height": 1.02, "muzzle_width": 0.90, "muzzle_height": 0.74, "muzzle_length": 0.84, "eye_scale": 0.050, "ear_width": 0.44, "muscle": 1.04, "foot_width": 1.04}, tint=(0.58, 0.40, 0.20)),
}


def run(species: str, source_files: dict[str, str]) -> None:
    cfg = MANIFEST[species]
    GROUND.run_species(
        species=species,
        description=f"Build the authored cinematic {cfg['description']}",
        source_files=source_files,
        source_reference=cfg["reference"],
        config_overrides=cfg["config"],
        anatomy_overrides=cfg["anatomy"],
        tint=cfg["tint"],
    )
