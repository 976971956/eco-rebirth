from __future__ import annotations

import argparse
import hashlib
import importlib.util
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


SOURCE_FILES = {
    "Porcupine.gltf": "bb1753540ed3911124428f0409aed968a1ea482b2eb88a4cef67825fbbda7def",
    "Porcupine.bin": "43918a831b23d766d7f52c9c21c055b61d0572633d09864dce63c0b279fab13a",
    "Porcupine_BaseColor.png": "fce8af2a251f508f7dd5104ca975c5b145fb92d8c98277711182788fd04124ec",
}
SOURCE_SHA256 = SOURCE_FILES["Porcupine.gltf"]
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


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description="Build the authored cinematic adult crested porcupine")
    parser.add_argument("--source-dir", required=True)
    parser.add_argument("--output-root", required=True)
    return parser.parse_args(argv)


def verify_source(source_dir: Path) -> None:
    for basename, expected in SOURCE_FILES.items():
        source = source_dir / basename
        if not source.is_file():
            raise RuntimeError(f"missing CC-BY porcupine reference source: {source}")
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        if digest != expected:
            raise RuntimeError(f"porcupine reference checksum mismatch for {basename}: {digest}")


def porcupine_config() -> dict:
    cfg = PIPELINE.config_for("porcupine")
    cfg.update(width=0.67, height=0.61, length=1.42, leg=0.52, paw=0.20, head=0.43, muzzle=0.51, neck=0.32, tail=0.34, ear=0.16)
    cfg["v3"].update(
        gait="shuffle",
        sprint_gait="scuttle",
        stride=0.25,
        flex=0.43,
        stance=0.86,
        upper_thickness=1.10,
        lower_thickness=0.84,
        chest_mass=0.96,
        rump_mass=1.13,
        body_bob=0.030,
        head_bob=0.018,
        attack="bash",
    )
    return cfg


def add_bone(edit, name: str, head, tail, parent=None):
    bone = edit.new(name)
    bone.head = PIPELINE.g2b(head)
    bone.tail = PIPELINE.g2b(tail)
    bone.parent = parent
    bone.use_connect = False
    return bone


def limb_points(suffix: str):
    side = -1.0 if suffix.startswith("L") else 1.0
    if suffix.endswith("F"):
        return (
            (side * 0.46, 0.77, -0.48),
            (side * 0.48, 0.48, -0.39),
            (side * 0.49, 0.21, -0.51),
            (side * 0.50, 0.09, -0.72),
        )
    return (
        (side * 0.48, 0.80, 0.49),
        (side * 0.50, 0.50, 0.33),
        (side * 0.51, 0.21, 0.55),
        (side * 0.52, 0.09, 0.34),
    )


def build_porcupine_rig() -> bpy.types.Object:
    bpy.ops.object.armature_add(enter_editmode=True, location=(0.0, 0.0, 0.0))
    rig = bpy.context.active_object
    rig.name = "SpeciesSkeleton3D"
    rig.data.name = "CrestedPorcupineCinematicRig"
    edit = rig.data.edit_bones
    root = edit[0]
    root.name = "Root"
    root.head = PIPELINE.g2b((0.0, 0.05, 0.14))
    root.tail = PIPELINE.g2b((0.0, 0.37, 0.14))
    root.use_deform = False

    spine = add_bone(edit, "Spine", (0.0, 0.87, 0.66), (0.0, 0.91, 0.08), root)
    chest = add_bone(edit, "Chest", (0.0, 0.91, 0.08), (0.0, 0.89, -0.58), spine)
    neck = add_bone(edit, "Neck", (0.0, 0.89, -0.58), (0.0, 0.84, -0.91), chest)
    head = add_bone(edit, "Head", (0.0, 0.84, -0.91), (0.0, 0.72, -1.48), neck)
    jaw = add_bone(edit, "Jaw", (0.0, 0.70, -1.19), (0.0, 0.64, -1.61), head)
    jaw.use_deform = False

    for suffix in LIMBS:
        hip, joint, ankle, toe = limb_points(suffix)
        upper = add_bone(edit, f"Leg_{suffix}", hip, joint, chest if suffix.endswith("F") else spine)
        lower = add_bone(edit, f"Lower_{suffix}", joint, ankle, upper)
        add_bone(edit, f"Paw_{suffix}", ankle, toe, lower)

    for suffix, side in (("L", -1.0), ("R", 1.0)):
        add_bone(edit, f"Ear_{suffix}", (side * 0.22, 0.94, -1.12), (side * 0.29, 1.09, -1.09), head)

    tail = add_bone(edit, "Tail", (0.0, 0.82, 0.90), (0.0, 0.77, 1.16), spine)
    add_bone(edit, "TailTip", (0.0, 0.77, 1.16), (0.0, 0.69, 1.42), tail)
    bpy.ops.object.mode_set(mode="OBJECT")

    if len(rig.data.bones) != 22:
        raise RuntimeError(f"porcupine runtime rig is not the 22-bone contract: {len(rig.data.bones)}")
    rig["eco_species"] = "porcupine"
    rig["rig_version"] = 6
    rig["skin_mode"] = "project_authored_weighted_cinematic"
    rig["source_reference_sha256"] = SOURCE_SHA256
    rig["source_attribution"] = "Porcupine by Poly by Google, CC BY"
    rig["anatomy_profile"] = "adult_crested_porcupine_deep_rump_long_muzzle_v1"
    rig["locomotion_profile"] = "short_leg_four_beat_shuffle_and_defensive_scuttle"
    rig["surface_profile"] = "coarse_black_brown_guard_fur_layered_banded_quills"
    rig["limb_segments"] = 3
    return rig


def coat_material(project_root: Path, hero: bool) -> bpy.types.Material:
    shared = project_root / "assets/textures/animals/shared"
    albedo = BEAR.tinted_fur_image(shared / "quadruped_fur_atlas_albedo.png", "porcupine_coarse_fur_albedo", (0.20, 0.16, 0.12), hero)
    normal = BEAR.packed_image(shared / "quadruped_fur_atlas_normal.png", "porcupine_coarse_fur_normal", "Non-Color", hero)
    roughness = BEAR.packed_image(shared / "quadruped_fur_atlas_roughness.png", "porcupine_coarse_fur_roughness", "Non-Color", hero)
    material = bpy.data.materials.new("porcupine_cinematic_coarse_fur_pbr")
    material.use_nodes = True
    material.diffuse_color = (0.20, 0.16, 0.12, 1.0)
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    principled = nodes.get("Principled BSDF")
    if principled is None:
        raise RuntimeError("missing Principled BSDF")
    principled.inputs["Roughness"].default_value = 0.91
    albedo_node = nodes.new("ShaderNodeTexImage")
    albedo_node.image = albedo
    links.new(albedo_node.outputs["Color"], principled.inputs["Base Color"])
    normal_node = nodes.new("ShaderNodeTexImage")
    normal_node.image = normal
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = 0.64
    links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])
    roughness_node = nodes.new("ShaderNodeTexImage")
    roughness_node.image = roughness
    links.new(roughness_node.outputs["Color"], principled.inputs["Roughness"])
    material["eco_pbr_surface"] = "authored_porcupine_coarse_guard_fur"
    return material


def subtle_guard_hair(body: bpy.types.Object, hero: bool) -> None:
    texture = bpy.data.textures.new("PorcupineGuardHairRelief", type="CLOUDS")
    texture.noise_scale = 0.050 if hero else 0.082
    texture.noise_depth = 1
    modifier = body.modifiers.new("PorcupineGuardHairRelief", "DISPLACE")
    modifier.texture = texture
    modifier.texture_coords = "GLOBAL"
    modifier.strength = 0.010 if hero else 0.006
    modifier.mid_level = 0.51
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    body.select_set(False)


def point_segment_distance(point: Vector, start: Vector, end: Vector) -> float:
    delta = end - start
    if delta.length_squared <= 0.000001:
        return (point - start).length
    amount = max(0.0, min(1.0, (point - start).dot(delta) / delta.length_squared))
    return (point - start.lerp(end, amount)).length


def skin_continuous_porcupine(body: bpy.types.Object, rig: bpy.types.Object) -> None:
    deform_names = [
        "Spine", "Chest", "Neck", "Head", "Tail", "TailTip",
        "Leg_LF", "Lower_LF", "Paw_LF", "Leg_RF", "Lower_RF", "Paw_RF",
        "Leg_LH", "Lower_LH", "Paw_LH", "Leg_RH", "Lower_RH", "Paw_RH",
    ]
    radius = {
        "Spine": 0.70, "Chest": 0.66, "Neck": 0.43, "Head": 0.45,
        "Tail": 0.31, "TailTip": 0.25,
        "Leg_LF": 0.26, "Leg_RF": 0.26, "Leg_LH": 0.28, "Leg_RH": 0.28,
        "Lower_LF": 0.19, "Lower_RF": 0.19, "Lower_LH": 0.20, "Lower_RH": 0.20,
        "Paw_LF": 0.23, "Paw_RF": 0.23, "Paw_LH": 0.24, "Paw_RH": 0.24,
    }
    weights = {name: [0.0] * len(body.data.vertices) for name in deform_names}
    for vertex in body.data.vertices:
        point = vertex.co
        candidates = []
        for name in deform_names:
            bone = rig.data.bones[name]
            distance = point_segment_distance(point, bone.head_local, bone.tail_local)
            value = math.exp(-3.5 * (distance / radius[name]) ** 2)
            if point.z > 0.64 and name.startswith(("Leg_", "Lower_", "Paw_")):
                value *= 0.28
            elif point.z < 0.56 and name in ("Spine", "Chest", "Neck", "Head", "Tail", "TailTip"):
                value *= 0.42
            candidates.append((name, value))
        candidates.sort(key=lambda item: item[1], reverse=True)
        retained = candidates[:4]
        total = sum(value for _name, value in retained)
        if total <= 0.000001:
            retained = [("Chest", 1.0)]
            total = 1.0
        for name, value in retained:
            weights[name][vertex.index] = value / total
    PIPELINE.add_armature_weights(body, rig, weights)


def build_porcupine_body(hero: bool, rig: bpy.types.Object, coat, pale) -> bpy.types.Object:
    elements = [
        ((0.0, 0.86, 0.62), (0.64, 0.55, 0.56), 2.40),
        ((0.0, 0.90, 0.16), (0.69, 0.59, 0.65), 2.45),
        ((0.0, 0.89, -0.36), (0.61, 0.54, 0.55), 2.44),
        ((0.0, 0.86, -0.70), (0.44, 0.42, 0.38), 2.46),
        ((0.0, 0.83, -0.96), (0.42, 0.40, 0.38), 2.48),
        ((0.0, 0.77, -1.22), (0.36, 0.34, 0.36), 2.50),
        ((0.0, 0.70, -1.48), (0.27, 0.25, 0.31), 2.52),
        ((0.0, 0.65, -1.68), (0.18, 0.16, 0.22), 2.54),
        ((0.0, 0.82, 0.89), (0.43, 0.39, 0.38), 2.48),
        ((0.0, 0.77, 1.13), (0.30, 0.27, 0.29), 2.50),
        ((0.0, 0.69, 1.35), (0.20, 0.18, 0.24), 2.52),
    ]
    for suffix in LIMBS:
        hip, joint, ankle, toe = limb_points(suffix)
        paw_centre = Vector((toe[0], 0.12, toe[2] - 0.04))
        elements.extend([
            (tuple(Vector(hip).lerp(Vector(joint), 0.18)), (0.27, 0.25, 0.23), 2.62),
            (tuple(Vector(hip).lerp(Vector(joint), 0.57)), (0.21, 0.23, 0.18), 2.66),
            (tuple(joint), (0.19, 0.18, 0.17), 2.70),
            (tuple(Vector(joint).lerp(Vector(ankle), 0.54)), (0.15, 0.20, 0.14), 2.72),
            (tuple(ankle), (0.16, 0.15, 0.16), 2.74),
            (tuple(Vector(ankle).lerp(paw_centre, 0.58)), (0.18, 0.14, 0.20), 2.76),
            (tuple(paw_centre), (0.23, 0.15, 0.30), 2.76),
        ])
    body = PIPELINE.metaball_mesh("PorcupineOrganicBodyV2_SourceConnected", elements, coat, hero)
    body.data.name = "PorcupineOrganicBodyV2SourceMesh"
    body["eco_anatomy_contract"] = "adult_crested_porcupine_continuous_body_limbs_and_tail"
    body["eco_surface_pattern"] = "coarse_dark_guard_fur_with_flush_pale_underjaw"
    pale_index = PIPELINE.append_material(body, pale)
    for polygon in body.data.polygons:
        centre = sum((body.data.vertices[index].co for index in polygon.vertices), Vector()) / len(polygon.vertices)
        godot_y = centre.z
        godot_z = centre.y
        if godot_y < 0.57 and godot_z < -0.82:
            polygon.material_index = pale_index
    subtle_guard_hair(body, hero)
    BEAR.smart_uv(body)
    skin_continuous_porcupine(body, rig)
    return body


def build_quills(hero: bool, rig: bpy.types.Object, dark, pale) -> list[bpy.types.Object]:
    parts: list[bpy.types.Object] = []
    rows = (-0.78, -0.56, -0.34, -0.12, 0.10, 0.32, 0.54, 0.76, 0.98) if hero else (-0.68, -0.34, 0.00, 0.34, 0.68, 0.98)
    laterals = (-0.92, -0.62, -0.31, 0.0, 0.31, 0.62, 0.92) if hero else (-0.66, 0.0, 0.66)

    def banded_quill(name: str, base: Vector, end: Vector, radius: float, bone: str) -> None:
        pale_start = base.lerp(end, 0.63)
        dark_tip = base.lerp(end, 0.88)
        for suffix, start, finish, segment_radius, material in (
            ("DarkBase", base, pale_start, radius, dark),
            ("PaleBand", pale_start, dark_tip, radius * 0.52, pale),
            ("DarkTip", dark_tip, end, radius * 0.27, dark),
        ):
            quill = PIPELINE.cone_between(f"{name}{suffix}", tuple(start), tuple(finish), segment_radius, material, hero)
            PIPELINE.rigid_skin(quill, rig, bone)
            parts.append(quill)

    for row_index, z_value in enumerate(rows):
        longitudinal = (z_value + 0.78) / 1.76
        body_radius = 0.56 + 0.10 * math.sin(longitudinal * math.pi)
        row_length = (0.78 + 0.39 * math.sin(longitudinal * math.pi)) * (1.0 if hero else 0.91)
        for side_index, lateral in enumerate(laterals):
            width_factor = max(0.34, 1.0 - abs(lateral) * 0.35)
            base = Vector((lateral * body_radius, 1.13 - abs(lateral) * 0.20, z_value))
            length = row_length * (0.90 + width_factor * 0.10)
            stagger = 0.035 * math.sin(row_index * 1.91 + side_index * 2.37)
            direction = Vector((lateral * 0.34, 0.44 - abs(lateral) * 0.13, 0.91 + stagger)).normalized()
            end = base + direction * length
            bone = "Chest" if z_value < 0.16 else "Spine"
            banded_quill(f"PorcupineQuill_{row_index}_{side_index}_", base, end, 0.040 if hero else 0.044, bone)

    # The rump fan creates the unmistakable crested-porcupine silhouette from
    # the gameplay camera without requiring hundreds of mobile quills.
    fan_sides = (-0.78, -0.52, -0.26, 0.0, 0.26, 0.52, 0.78) if hero else (-0.52, 0.0, 0.52)
    for index, lateral in enumerate(fan_sides):
        base = Vector((lateral * 0.53, 1.03 - abs(lateral) * 0.15, 0.90))
        end = base + Vector((lateral * 0.29, 0.28, 0.96)).normalized() * (0.96 if hero else 0.82)
        banded_quill(f"PorcupineTailQuill_{index}_", base, end, 0.042 if hero else 0.047, "Tail")
    return parts


def build_porcupine_details(hero: bool, rig: bpy.types.Object, coat, pale, dark, eye, nose, paw) -> list[bpy.types.Object]:
    parts: list[bpy.types.Object] = []

    def sphere(name: str, position, scale, material, bone: str):
        obj = PIPELINE.uv_sphere(name, position, scale, material, hero)
        PIPELINE.rigid_skin(obj, rig, bone)
        parts.append(obj)
        return obj

    def capsule(name: str, start, end, radius, material, bone: str, flatten=1.0):
        obj = PIPELINE.ellipsoid_between(name, start, end, radius, material, hero, flatten)
        PIPELINE.rigid_skin(obj, rig, bone)
        parts.append(obj)
        return obj

    def cone(name: str, start, end, radius, material, bone: str):
        obj = PIPELINE.cone_between(name, start, end, radius, material, hero)
        PIPELINE.rigid_skin(obj, rig, bone)
        parts.append(obj)
        return obj

    for suffix, side in (("L", -1.0), ("R", 1.0)):
        ear_parts = PIPELINE.ear_leaf(
            f"PorcupineEarSilhouette_{suffix}",
            (side * 0.20, 0.93, -1.13),
            (side * 0.28, 1.08, -1.10),
            0.105,
            0.028,
            coat,
            pale,
            hero,
        )
        for obj in ear_parts:
            PIPELINE.rigid_skin(obj, rig, f"Ear_{suffix}")
            parts.append(obj)
        sphere(f"PorcupineEyeDetail_{suffix}", (side * 0.235, 0.85, -1.39), (0.040, 0.044, 0.030), eye, "Head")
        if hero:
            sphere(f"PorcupineEyelidDetail_{suffix}", (side * 0.235, 0.884, -1.378), (0.058, 0.022, 0.040), coat, "Head")

    capsule("PorcupinePaleMuzzleDetail", (0.0, 0.72, -1.25), (0.0, 0.66, -1.62), 0.185, pale, "Head", 0.68)
    capsule("PorcupineLowerJawDetail", (0.0, 0.64, -1.31), (0.0, 0.60, -1.60), 0.120, pale, "Jaw", 0.58)
    sphere("PorcupineWetNoseDetail", (0.0, 0.67, -1.79), (0.145, 0.105, 0.085), nose, "Head")
    for side in (-1.0, 1.0):
        whisker_count = 3 if hero else 1
        for index in range(whisker_count):
            y_offset = (index - (whisker_count - 1) * 0.5) * 0.055
            cone(
                f"PorcupineWhiskerDetail_{side:+.0f}_{index}",
                (side * 0.12, 0.68 + y_offset, -1.62),
                (side * (0.50 if hero else 0.39), 0.66 + y_offset * 1.2, -1.75 + index * 0.025),
                0.009 if hero else 0.012,
                pale,
                "Head",
            )

    for suffix in LIMBS:
        _hip, _joint, _ankle, toe = limb_points(suffix)
        sphere(f"PorcupinePalmDetail_{suffix}", (toe[0], 0.090, toe[2] - 0.11), (0.17, 0.075, 0.20), paw, f"Paw_{suffix}")
        claw_count = 4 if hero else 2
        for claw_index in range(claw_count):
            lateral = (claw_index - (claw_count - 1) * 0.5) * (0.055 if hero else 0.085)
            cone(
                f"PorcupineClawDetail_{suffix}_{claw_index}",
                (toe[0] + lateral, 0.090, toe[2] - 0.19),
                (toe[0] + lateral, 0.072, toe[2] - 0.31),
                0.020,
                dark,
                f"Paw_{suffix}",
            )
    return parts


def attach_sockets(rig: bpy.types.Object) -> None:
    PIPELINE.attach_socket("SkillSocket_Mouth", (0.0, 0.67, -1.78), rig, "Head")
    PIPELINE.attach_socket("SkillSocket_Chest", (0.0, 1.04, -0.34), rig, "Chest")


def customize_defensive_actions(rig: bpy.types.Object) -> None:
    rig.animation_data_create()

    def insert(action_name: str, bone_name: str, frame: int, xyz) -> None:
        rig.animation_data.action = bpy.data.actions[action_name]
        bone = rig.pose.bones[bone_name]
        bone.rotation_mode = "XYZ"
        bone.rotation_euler = xyz
        bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=bone_name)

    for frame, flare in ((1, 0.0), (7, 0.45), (12, 1.0), (20, 0.62), (28, 0.0)):
        insert("skill", "Spine", frame, (-0.25 * flare, 0.0, 0.0))
        insert("skill", "Chest", frame, (0.32 * flare, 0.0, 0.0))
        insert("skill", "Neck", frame, (0.18 * flare, 0.0, 0.0))
        insert("skill", "Tail", frame, (-0.30 * flare, 0.0, 0.0))
        insert("skill", "TailTip", frame, (-0.22 * flare, 0.0, 0.0))
    for frame, bash in ((1, 0.0), (7, -0.35), (12, 1.0), (22, 0.0)):
        insert("attack", "Spine", frame, (-0.12 * bash, 0.0, 0.0))
        insert("attack", "Neck", frame, (0.35 * bash, 0.0, 0.0))
        insert("attack", "Head", frame, (0.30 * bash, 0.0, 0.0))
    rig.animation_data.action = bpy.data.actions["idle"]


def triangle_count(objects: list[bpy.types.Object]) -> tuple[int, int]:
    triangles = 0
    vertices = 0
    for obj in objects:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
        vertices += len(obj.data.vertices)
    return triangles, vertices


def export_profile(source_dir: Path, output_root: Path, hero: bool) -> tuple[int, int, int]:
    verify_source(source_dir)
    PIPELINE.reset_scene()
    cfg = porcupine_config()
    rig = build_porcupine_rig()
    project_root = Path(__file__).resolve().parents[2]
    coat = coat_material(project_root, hero)
    pale = PIPELINE.pbr_material("porcupine_cinematic_pale_fur_pbr", "#d1c2a4", 0.88)
    dark = PIPELINE.pbr_material("porcupine_cinematic_quill_dark_pbr", "#24211d", 0.74)
    quill_pale = PIPELINE.pbr_material("porcupine_cinematic_quill_pale_pbr", "#ddd2b5", 0.69)
    eye = PIPELINE.pbr_material("porcupine_cinematic_eye_pbr", "#15100c", 0.10)
    nose = PIPELINE.pbr_material("porcupine_cinematic_nose_pbr", "#171819", 0.24)
    paw = PIPELINE.pbr_material("porcupine_cinematic_paw_pbr", "#292521", 0.72)
    body = build_porcupine_body(hero, rig, coat, pale)
    PIPELINE.validate_continuous_flesh("porcupine", [body])
    quills = build_quills(hero, rig, dark, quill_pale)
    details = build_porcupine_details(hero, rig, coat, pale, dark, eye, nose, paw)
    attach_sockets(rig)
    PIPELINE.create_ground_actions(rig, cfg)
    customize_defensive_actions(rig)

    profile = "hero" if hero else "mobile"
    output = output_root / "porcupine" / f"porcupine_{profile}.glb"
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLB",
        use_selection=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_skins=True,
        export_yup=True,
        export_apply=True,
    )
    triangles, vertices = triangle_count([body, *quills, *details])
    if not output.is_file() or output.stat().st_size < 4096:
        raise RuntimeError(f"failed to export {output}")
    return triangles, vertices, len(rig.data.bones)


def main() -> None:
    args = parse_args()
    source_dir = Path(args.source_dir).resolve()
    output_root = Path(args.output_root).resolve()
    for hero in (True, False):
        triangles, vertices, bones = export_profile(source_dir, output_root, hero)
        profile = "hero" if hero else "mobile"
        print(f"CINEMATIC_PORCUPINE_OK: {profile} / {triangles} triangles / {vertices} vertices / {bones} bones")


if __name__ == "__main__":
    main()
