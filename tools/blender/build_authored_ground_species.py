from __future__ import annotations

import argparse
import hashlib
import importlib.util
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


LIMBS = ("LF", "RF", "LH", "RH")


def load_module(filename: str, name: str):
    module_path = Path(__file__).resolve().with_name(filename)
    spec = importlib.util.spec_from_file_location(name, module_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load shared species module: {module_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


PIPELINE = load_module("build_remaining_species.py", "eco_remaining_species")
BEAR = load_module("build_cinematic_bear.py", "eco_cinematic_bear")


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


def coat_material(project_root: Path, species: str, tint: tuple[float, float, float], hero: bool, roughness: float):
    shared = project_root / "assets/textures/animals/shared"
    albedo = BEAR.tinted_fur_image(shared / "quadruped_fur_atlas_albedo.png", f"{species}_dense_fur_albedo", tint, hero)
    normal = BEAR.packed_image(shared / "quadruped_fur_atlas_normal.png", f"{species}_dense_fur_normal", "Non-Color", hero)
    roughness_image = BEAR.packed_image(shared / "quadruped_fur_atlas_roughness.png", f"{species}_dense_fur_roughness", "Non-Color", hero)
    material = bpy.data.materials.new(f"{species}_cinematic_coat_pbr")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    principled = nodes.get("Principled BSDF")
    if principled is None:
        raise RuntimeError("missing Principled BSDF")
    principled.inputs["Roughness"].default_value = roughness
    albedo_node = nodes.new("ShaderNodeTexImage")
    albedo_node.image = albedo
    links.new(albedo_node.outputs["Color"], principled.inputs["Base Color"])
    normal_node = nodes.new("ShaderNodeTexImage")
    normal_node.image = normal
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = 0.34
    links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])
    roughness_node = nodes.new("ShaderNodeTexImage")
    roughness_node.image = roughness_image
    links.new(roughness_node.outputs["Color"], principled.inputs["Roughness"])
    material["eco_pbr_surface"] = f"authored_{species}_fur"
    return material


def replace_materials(parts, coat, accent, detail, eye) -> None:
    for obj in parts:
        for index, material in enumerate(obj.data.materials):
            name = material.name.lower()
            if "_coat_pbr" in name:
                obj.data.materials[index] = coat
            elif "_accent_pbr" in name:
                obj.data.materials[index] = accent
            elif "_detail_pbr" in name or "_keratin_pbr" in name:
                obj.data.materials[index] = detail
            elif "_eye_pbr" in name:
                obj.data.materials[index] = eye


def remove_named(parts, prefixes: tuple[str, ...]) -> None:
    for obj in list(parts):
        if obj.name.startswith(prefixes):
            parts.remove(obj)
            bpy.data.objects.remove(obj, do_unlink=True)


def connected_tail(
    name: str,
    hero: bool,
    rig,
    start: tuple[float, float, float],
    end: tuple[float, float, float],
    base_radius: float,
    tip_radius: float,
    material,
    flatten: float = 0.82,
):
    ring_count = 9 if hero else 6
    sides = 10 if hero else 7
    vertices = []
    faces = []
    tail_weights = []
    tip_weights = []
    start_v = Vector(start)
    end_v = Vector(end)
    for ring in range(ring_count):
        amount = ring / (ring_count - 1)
        centre = start_v.lerp(end_v, amount)
        radius = base_radius * (1.0 - amount) + tip_radius * amount
        for side in range(sides):
            angle = math.tau * side / sides
            vertices.append((centre.x + math.cos(angle) * radius, centre.y + math.sin(angle) * radius * flatten, centre.z))
            blend = max(0.0, min(1.0, (amount - 0.30) / 0.40))
            tail_weights.append(1.0 - blend)
            tip_weights.append(blend)
    for ring in range(ring_count - 1):
        for side in range(sides):
            next_side = (side + 1) % sides
            a = ring * sides + side
            b = ring * sides + next_side
            c = (ring + 1) * sides + next_side
            d = (ring + 1) * sides + side
            faces.append((a, b, c, d))
    faces.append(tuple(reversed(range(sides))))
    last = (ring_count - 1) * sides
    faces.append(tuple(last + side for side in range(sides)))
    result = PIPELINE.authored_mesh(name, vertices, faces, [material], [0] * len(faces))
    for polygon in result.data.polygons:
        polygon.use_smooth = True
    PIPELINE.add_armature_weights(result, rig, {"Tail": tail_weights, "TailTip": tip_weights})
    BEAR.smart_uv(result)
    return result


def customize_lynx(parts, hero: bool, rig, cfg: dict, layout: dict, coat, accent, detail) -> None:
    remove_named(parts, ("CheekRuffDetail", "V5TailBaseSilhouette", "V5TailTipSilhouette"))
    for side in (-1.0, 1.0):
        count = 3 if hero else 2
        for index in range(count):
            start = (side * cfg["head"] * (0.54 + index * 0.04), layout["head_y"] - 0.01, layout["head_z"] + cfg["head"] * (0.04 - index * 0.11))
            end = (side * cfg["head"] * (0.93 + index * 0.05), layout["head_y"] - cfg["head"] * (0.08 + index * 0.02), layout["head_z"] + cfg["head"] * (0.02 - index * 0.14))
            tuft = PIPELINE.ellipsoid_between(f"LynxCheekRuffDetail_{side:+.0f}_{index}", start, end, cfg["head"] * (0.105 - index * 0.012), accent if index == 0 else coat, hero, 0.56)
            PIPELINE.rigid_skin(tuft, rig, "Head")
            parts.append(tuft)
    tail_start = (0.0, layout["body_y"], cfg["length"] * 0.58)
    tail_end = (0.0, layout["body_y"] + 0.04, cfg["length"] * 0.58 + cfg["tail"] * 1.15)
    tail = connected_tail("LynxConnectedBobTailSilhouette", hero, rig, tail_start, tail_end, 0.14, 0.085, coat, 0.88)
    tail.data.materials.append(detail)
    for polygon in tail.data.polygons:
        if sum(tail.data.vertices[index].co.y for index in polygon.vertices) / len(polygon.vertices) > PIPELINE.g2b(tail_start)[1] + cfg["tail"] * 0.72:
            polygon.material_index = 1
    tail["eco_tail_contract"] = "single_connected_short_black_tipped_bobtail"
    parts.append(tail)
    for obj in parts:
        if obj.name.startswith("V5FootDetail"):
            obj.scale.x *= 1.22
            obj.scale.y *= 1.06
            obj["eco_paw_contract"] = "wide_furred_snowshoe_paw"


def customize_goat(parts, hero: bool, rig, cfg: dict, layout: dict, coat, accent, detail) -> None:
    remove_named(parts, ("HornDetail", "BeardDetail"))
    for side in (-1.0, 1.0):
        points = [
            (side * cfg["head"] * 0.34, layout["head_y"] + cfg["head"] * 0.38, layout["head_z"] + 0.04),
            (side * cfg["head"] * 0.58, layout["head_y"] + cfg["head"] * 0.76, layout["head_z"] + cfg["head"] * 0.12),
            (side * cfg["head"] * 0.66, layout["head_y"] + cfg["head"] * 1.02, layout["head_z"] + cfg["head"] * 0.34),
            (side * cfg["head"] * 0.56, layout["head_y"] + cfg["head"] * 1.08, layout["head_z"] + cfg["head"] * 0.62),
        ]
        for index in range(3):
            horn = PIPELINE.cone_between(
                f"GoatSweptHornDetail_{side:+.0f}_{index}", points[index], points[index + 1],
                cfg["head"] * (0.105 - index * 0.022), detail, hero,
            )
            PIPELINE.rigid_skin(horn, rig, "Head")
            parts.append(horn)
    beard_top = (0.0, layout["head_y"] - cfg["head"] * 0.40, layout["head_z"] - cfg["head"] * 0.12)
    beard_mid = (0.0, beard_top[1] - cfg["head"] * 0.28, beard_top[2] + cfg["head"] * 0.06)
    beard_tip = (0.0, beard_top[1] - cfg["head"] * 0.54, beard_top[2] + cfg["head"] * 0.13)
    for index, (start, end, radius) in enumerate(((beard_top, beard_mid, 0.105), (beard_mid, beard_tip, 0.070))):
        beard = PIPELINE.ellipsoid_between(f"GoatTaperedBeardDetail_{index}", start, end, cfg["head"] * radius, detail, hero, 0.62)
        PIPELINE.rigid_skin(beard, rig, "Head")
        parts.append(beard)


def customize_wolverine(parts, hero: bool, rig, cfg: dict, layout: dict, coat, accent, detail) -> None:
    """Replace generic canid details with a compact mustelid silhouette."""
    remove_named(parts, ("V5EarSilhouette", "V5TailBaseSilhouette", "V5TailTipSilhouette"))
    for suffix, side in (("L", -1.0), ("R", 1.0)):
        ear_position = (
            side * cfg["head"] * 0.48,
            layout["head_y"] + cfg["head"] * 0.44,
            layout["head_z"] + cfg["head"] * 0.10,
        )
        ear = PIPELINE.uv_sphere(
            f"WolverineRoundedEarSilhouette_{suffix}", ear_position,
            (cfg["head"] * 0.18, cfg["head"] * 0.20, cfg["head"] * 0.105),
            coat, hero,
        )
        PIPELINE.rigid_skin(ear, rig, f"Ear_{suffix}")
        parts.append(ear)
        if hero:
            inner = PIPELINE.uv_sphere(
                f"WolverineRoundedEarInnerDetail_{suffix}",
                (ear_position[0], ear_position[1] + cfg["head"] * 0.018, ear_position[2] - cfg["head"] * 0.070),
                (cfg["head"] * 0.105, cfg["head"] * 0.115, cfg["head"] * 0.035),
                accent, hero,
            )
            PIPELINE.rigid_skin(inner, rig, f"Ear_{suffix}")
            parts.append(inner)

    tail_start = (0.0, layout["body_y"] - 0.02, cfg["length"] * 0.60)
    tail_end = (0.0, max(0.20, layout["body_y"] - cfg["tail"] * 0.30), cfg["length"] * 0.60 + cfg["tail"] * 1.06)
    tail = connected_tail(
        "WolverineConnectedBrushTailSilhouette", hero, rig, tail_start, tail_end,
        cfg["paw"] * 1.12, cfg["paw"] * 0.54, coat, 0.86,
    )
    tail["eco_tail_contract"] = "single_connected_low_tapered_mustelid_tail"
    parts.append(tail)

    for obj in parts:
        if obj.name.startswith("V5FootDetail"):
            obj.scale.x *= 1.20
            obj.scale.y *= 0.68
            obj.scale.z *= 0.92
            obj["eco_paw_contract"] = "broad_five_toed_digging_paw"

    # Flush shoulder colouring is already painted on the torso. These two
    # short ruffs add the heavy neck/shoulder transition without floating fur.
    for side in (-1.0, 1.0):
        ruff = PIPELINE.ellipsoid_between(
            f"WolverineShoulderRuffDetail_{side:+.0f}",
            (side * cfg["width"] * 0.54, layout["shoulder_y"] + 0.05, layout["front_z"] + 0.12),
            (side * cfg["width"] * 0.60, layout["shoulder_y"] - 0.04, layout["front_z"] + 0.48),
            cfg["head"] * 0.13, accent, hero, 0.55,
        )
        PIPELINE.rigid_skin(ruff, rig, "Chest")
        parts.append(ruff)


def customize_actions(species: str, rig) -> None:
    if species not in ("lynx", "goat", "wolverine"):
        return
    rig.animation_data_create()

    def insert(action_name: str, bone_name: str, frame: int, xyz) -> None:
        rig.animation_data.action = bpy.data.actions[action_name]
        bone = rig.pose.bones[bone_name]
        bone.rotation_mode = "XYZ"
        bone.rotation_euler = xyz
        bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=bone_name)

    for frame, amount in ((1, 0.0), (6, 0.28), (11, 1.0), (16, -0.52), (24, 0.0)):
        if species == "lynx":
            insert("skill", "Spine", frame, (-0.22 * abs(amount), 0.0, 0.06 * amount))
            insert("skill", "Chest", frame, (0.16 * abs(amount), 0.0, -0.04 * amount))
            insert("skill", "Neck", frame, (-0.18 * amount, 0.0, 0.0))
            insert("skill", "Tail", frame, (0.0, 0.0, 0.24 * amount))
            for suffix in LIMBS:
                rear = suffix.endswith("H")
                insert("skill", f"Leg_{suffix}", frame, ((-0.48 if rear else 0.34) * amount, 0.0, 0.0))
                insert("skill", f"Lower_{suffix}", frame, ((0.72 if rear else -0.48) * abs(amount), 0.0, 0.0))
                insert("skill", f"Paw_{suffix}", frame, (-0.26 * abs(amount), 0.0, 0.0))
        elif species == "goat":
            insert("skill", "Spine", frame, (-0.12 * abs(amount), 0.0, 0.0))
            insert("skill", "Chest", frame, (0.20 * amount, 0.0, 0.0))
            insert("skill", "Neck", frame, (-0.48 * amount, 0.0, 0.0))
            insert("skill", "Head", frame, (-0.34 * amount, 0.0, 0.0))
            for suffix in LIMBS:
                rear = suffix.endswith("H")
                insert("skill", f"Leg_{suffix}", frame, ((-0.56 if rear else 0.28) * amount, 0.0, 0.0))
                insert("skill", f"Lower_{suffix}", frame, ((0.78 if rear else -0.34) * abs(amount), 0.0, 0.0))
                insert("skill", f"Paw_{suffix}", frame, (-0.24 * abs(amount), 0.0, 0.0))
        else:
            # The wolverine plants its rear paws, twists through the shoulders,
            # hooks with one forepaw and finishes with a deep tearing bite.
            insert("skill", "Spine", frame, (-0.20 * abs(amount), 0.0, 0.18 * amount))
            insert("skill", "Chest", frame, (0.16 * abs(amount), 0.0, -0.24 * amount))
            insert("skill", "Neck", frame, (0.26 * amount, 0.0, 0.10 * amount))
            insert("skill", "Head", frame, (0.30 * amount, 0.0, 0.12 * amount))
            insert("skill", "Jaw", frame, (-0.44 * max(amount, 0.0), 0.0, 0.0))
            insert("skill", "Leg_LF", frame, (-0.78 * amount, 0.0, -0.22 * amount))
            insert("skill", "Lower_LF", frame, (0.58 * abs(amount), 0.0, 0.0))
            insert("skill", "Paw_LF", frame, (-0.34 * abs(amount), 0.0, 0.0))
            insert("skill", "Leg_RF", frame, (-0.22 * amount, 0.0, 0.16 * amount))
            for suffix in ("LH", "RH"):
                insert("skill", f"Leg_{suffix}", frame, (0.22 * abs(amount), 0.0, 0.0))
                insert("skill", f"Lower_{suffix}", frame, (0.34 * abs(amount), 0.0, 0.0))
    rig.animation_data.action = bpy.data.actions["idle"]


def triangle_count(objects) -> tuple[int, int]:
    triangles = 0
    vertices = 0
    for obj in objects:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
        vertices += len(obj.data.vertices)
    return triangles, vertices


def optimize_mobile_body(body) -> None:
    """Reserve the shared 30-species budget without changing Hero quality."""
    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    modifier = body.modifiers.new("MobileSilhouetteDecimate", "DECIMATE")
    modifier.decimate_type = "COLLAPSE"
    modifier.ratio = 0.56
    modifier.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    body.select_set(False)
    body["eco_mobile_lod"] = "silhouette_decimate_0_56"


def export_species(
    species: str,
    source_dir: Path,
    output_root: Path,
    source_files: dict[str, str],
    source_reference: str,
    config_overrides: dict,
    anatomy_overrides: dict,
    tint: tuple[float, float, float],
    hero: bool,
) -> tuple[int, int, int]:
    verify_source(source_dir, source_files, species)
    PIPELINE.reset_scene()
    cfg = PIPELINE.config_for(species)
    cfg.update(config_overrides)
    cfg["v5"].update(anatomy_overrides)
    layout = PIPELINE.ground_layout(cfg)
    rig, anchors = PIPELINE.build_ground_rig(species, cfg, layout)
    parts = PIPELINE.build_ground_parts(species, hero, rig, anchors, cfg, layout)
    project_root = Path(__file__).resolve().parents[2]
    coat = coat_material(project_root, species, tint, hero, 0.86)
    accent = PIPELINE.pbr_material(f"{species}_cinematic_accent_pbr", cfg["accent"], 0.88)
    detail = PIPELINE.pbr_material(f"{species}_cinematic_detail_pbr", cfg["dark"], 0.76)
    eye = PIPELINE.pbr_material(f"{species}_cinematic_eye_pbr", cfg["eye"], 0.10)
    replace_materials(parts, coat, accent, detail, eye)
    organic_body = next(obj for obj in parts if "OrganicBodyV2" in obj.name)
    if not hero:
        optimize_mobile_body(organic_body)
    BEAR.smart_uv(organic_body)
    if species == "lynx":
        customize_lynx(parts, hero, rig, cfg, layout, coat, accent, detail)
    elif species == "goat":
        customize_goat(parts, hero, rig, cfg, layout, coat, accent, detail)
    elif species == "wolverine":
        customize_wolverine(parts, hero, rig, cfg, layout, coat, accent, detail)
    PIPELINE.validate_continuous_flesh(species, parts)
    rig.data.name = f"{species.title()}AuthoredCinematicRig"
    rig["rig_version"] = 6
    rig["skin_mode"] = "project_authored_weighted_cinematic"
    rig["source_reference"] = source_reference
    rig["anatomy_profile"] = f"adult_{species}_species_specific_v1"
    rig["locomotion_profile"] = f"authored_{species}_gait_and_skill"
    rig["surface_profile"] = f"species_tinted_fur_pbr_{species}"
    PIPELINE.create_ground_actions(rig, cfg)
    customize_actions(species, rig)
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
    config_overrides: dict,
    anatomy_overrides: dict,
    tint: tuple[float, float, float],
) -> None:
    args = parse_args(description)
    source_dir = Path(args.source_dir).resolve()
    output_root = Path(args.output_root).resolve()
    for hero in (True, False):
        triangles, vertices, bones = export_species(
            species, source_dir, output_root, source_files, source_reference,
            config_overrides, anatomy_overrides, tint, hero,
        )
        profile = "hero" if hero else "mobile"
        print(f"AUTHORED_{species.upper()}_OK: {profile} / {triangles} triangles / {vertices} vertices / {bones} bones")
