from __future__ import annotations

import argparse
import hashlib
import importlib.util
import sys
from pathlib import Path

import bpy


def load_pipeline():
    path = Path(__file__).resolve().with_name("build_remaining_species.py")
    spec = importlib.util.spec_from_file_location("eco_remaining_species", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load shared flight builder: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


PIPELINE = load_pipeline()


def parse_args(description: str) -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=description)
    parser.add_argument("--source-dir", required=True)
    parser.add_argument("--output-root", required=True)
    return parser.parse_args(argv)


def verify_source(source_dir: Path, source_files: dict[str, str], species: str) -> None:
    for basename, expected in source_files.items():
        source = source_dir / basename
        if not source.is_file():
            raise RuntimeError(f"missing {species} reference record: {source}")
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        if digest != expected:
            raise RuntimeError(f"{species} reference checksum mismatch for {basename}: {digest}")


def replace_materials(parts, species: str) -> None:
    if species == "owl":
        coat = PIPELINE.pbr_material("owl_authored_snow_feather_pbr", "#d8d9d1", 0.92)
        accent = PIPELINE.pbr_material("owl_authored_accent_pbr", "#f0eee3", 0.96)
        detail = PIPELINE.pbr_material("owl_authored_detail_pbr", "#666b70", 0.82)
        keratin = PIPELINE.pbr_material("owl_authored_keratin_pbr", "#343331", 0.58)
        eye = PIPELINE.pbr_material("owl_authored_eye_pbr", "#e4bd38", 0.10)
    else:
        coat = PIPELINE.pbr_material("eagle_authored_brown_feather_pbr", "#493729", 0.88)
        accent = PIPELINE.pbr_material("eagle_authored_accent_pbr", "#b88a42", 0.84)
        detail = PIPELINE.pbr_material("eagle_authored_detail_pbr", "#211c18", 0.78)
        keratin = PIPELINE.pbr_material("eagle_authored_keratin_pbr", "#c39a48", 0.54)
        eye = PIPELINE.pbr_material("eagle_authored_eye_pbr", "#d9a929", 0.10)
    for obj in parts:
        for index, material in enumerate(obj.data.materials):
            name = material.name.lower()
            if "_feather_pbr" in name:
                obj.data.materials[index] = detail if "detail" in obj.name.lower() and "organicbody" not in obj.name.lower() else coat
            elif "_accent_pbr" in name:
                obj.data.materials[index] = accent
            elif "_detail_pbr" in name:
                obj.data.materials[index] = detail
            elif "_keratin_pbr" in name:
                obj.data.materials[index] = keratin
            elif "_eye_pbr" in name:
                obj.data.materials[index] = eye


def optimize_mobile_body(parts) -> None:
    body = next(obj for obj in parts if "OrganicBodyV2" in obj.name)
    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    modifier = body.modifiers.new("MobileFlightSilhouetteDecimate", "DECIMATE")
    modifier.decimate_type = "COLLAPSE"
    modifier.ratio = 0.54
    modifier.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    body.select_set(False)
    body["eco_mobile_lod"] = "flight_silhouette_decimate_0_54"


def triangle_count(parts) -> tuple[int, int]:
    triangles = 0
    vertices = 0
    for obj in parts:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
        vertices += len(obj.data.vertices)
    return triangles, vertices


def export_species(
    species: str,
    source_dir: Path,
    output_root: Path,
    source_files: dict[str, str],
    source_reference: str,
    hero: bool,
) -> tuple[int, int, int]:
    verify_source(source_dir, source_files, species)
    PIPELINE.reset_scene()
    rig, parts = PIPELINE.build_bird(species, hero)
    replace_materials(parts, species)
    if not hero:
        optimize_mobile_body(parts)
    PIPELINE.validate_continuous_flesh(species, parts)
    rig.data.name = f"{species.title()}AuthoredCinematicFlightRig"
    rig["rig_version"] = 6
    rig["skin_mode"] = "project_authored_weighted_cinematic_flight"
    rig["source_reference"] = source_reference
    rig["anatomy_profile"] = f"adult_{species}_species_specific_raptor_v1"
    rig["locomotion_profile"] = f"authored_{species}_three_stage_flap_glide_dive_land"
    rig["surface_profile"] = f"authored_{species}_flush_feather_regions"
    profile = "hero" if hero else "mobile"
    output = output_root / species / f"{species}_{profile}.glb"
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(
        filepath=str(output), export_format="GLB", use_selection=True,
        export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
        export_yup=True, export_apply=True,
    )
    triangles, vertices = triangle_count(parts)
    if not output.is_file() or output.stat().st_size < 4096:
        raise RuntimeError(f"failed to export {output}")
    return triangles, vertices, len(rig.data.bones)


def run_species(
    species: str,
    description: str,
    source_files: dict[str, str],
    source_reference: str,
) -> None:
    args = parse_args(description)
    source_dir = Path(args.source_dir).resolve()
    output_root = Path(args.output_root).resolve()
    for hero in (True, False):
        triangles, vertices, bones = export_species(
            species, source_dir, output_root, source_files, source_reference, hero,
        )
        profile = "hero" if hero else "mobile"
        print(f"AUTHORED_{species.upper()}_OK: {profile} / {triangles} triangles / {vertices} vertices / {bones} bones")
