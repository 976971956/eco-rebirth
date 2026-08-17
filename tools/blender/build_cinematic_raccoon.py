from __future__ import annotations

import argparse
import importlib.util
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


SOURCE_BASENAME = "Raccoon.blend"
SOURCE_SHA256 = "033156c482437c797503814ae2047e209bb6e6fa062fd60305b60e2aed3fc181"
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
    parser = argparse.ArgumentParser(description="Build the authored cinematic adult raccoon")
    parser.add_argument("--source-dir", required=True)
    parser.add_argument("--output-root", required=True)
    return parser.parse_args(argv)


def raccoon_config() -> dict:
    cfg = PIPELINE.config_for("raccoon")
    cfg.update(width=0.51, height=0.50, length=1.22, leg=0.58, paw=0.19, head=0.45, muzzle=0.36, neck=0.34, tail=1.24, ear=0.25)
    cfg["v3"].update(
        gait="amble",
        sprint_gait="lope",
        stride=0.34,
        flex=0.51,
        stance=0.84,
        upper_thickness=1.06,
        lower_thickness=0.82,
        chest_mass=0.95,
        rump_mass=1.06,
        body_bob=0.040,
        head_bob=0.024,
        attack="swipe",
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
            (side * 0.39, 0.83, -0.48),
            (side * 0.41, 0.52, -0.37),
            (side * 0.42, 0.22, -0.50),
            (side * 0.43, 0.09, -0.75),
        )
    return (
        (side * 0.40, 0.82, 0.47),
        (side * 0.42, 0.47, 0.30),
        (side * 0.43, 0.20, 0.55),
        (side * 0.44, 0.09, 0.29),
    )


def build_raccoon_rig() -> bpy.types.Object:
    bpy.ops.object.armature_add(enter_editmode=True, location=(0.0, 0.0, 0.0))
    rig = bpy.context.active_object
    rig.name = "SpeciesSkeleton3D"
    rig.data.name = "RaccoonCinematicRig"
    edit = rig.data.edit_bones
    root = edit[0]
    root.name = "Root"
    root.head = PIPELINE.g2b((0.0, 0.05, 0.12))
    root.tail = PIPELINE.g2b((0.0, 0.36, 0.12))
    root.use_deform = False

    spine = add_bone(edit, "Spine", (0.0, 0.79, 0.58), (0.0, 0.82, 0.05), root)
    chest = add_bone(edit, "Chest", (0.0, 0.82, 0.05), (0.0, 0.87, -0.53), spine)
    neck = add_bone(edit, "Neck", (0.0, 0.87, -0.53), (0.0, 0.91, -0.89), chest)
    head = add_bone(edit, "Head", (0.0, 0.91, -0.89), (0.0, 0.84, -1.46), neck)
    jaw = add_bone(edit, "Jaw", (0.0, 0.79, -1.15), (0.0, 0.73, -1.50), head)
    jaw.use_deform = False

    for suffix in LIMBS:
        hip, joint, ankle, toe = limb_points(suffix)
        upper = add_bone(edit, f"Leg_{suffix}", hip, joint, chest if suffix.endswith("F") else spine)
        lower = add_bone(edit, f"Lower_{suffix}", joint, ankle, upper)
        add_bone(edit, f"Paw_{suffix}", ankle, toe, lower)

    for suffix, side in (("L", -1.0), ("R", 1.0)):
        add_bone(edit, f"Ear_{suffix}", (side * 0.25, 1.03, -1.14), (side * 0.34, 1.27, -1.12), head)

    tail = add_bone(edit, "Tail", (0.0, 0.80, 0.72), (0.0, 0.82, 1.34), spine)
    add_bone(edit, "TailTip", (0.0, 0.82, 1.34), (0.0, 0.90, 1.97), tail)
    bpy.ops.object.mode_set(mode="OBJECT")

    if len(rig.data.bones) != 22:
        raise RuntimeError(f"raccoon runtime rig is not the 22-bone contract: {len(rig.data.bones)}")
    rig["eco_species"] = "raccoon"
    rig["rig_version"] = 6
    rig["skin_mode"] = "project_authored_weighted_cinematic"
    rig["source_reference_sha256"] = SOURCE_SHA256
    rig["anatomy_profile"] = "adult_raccoon_arched_back_plantigrade_ring_tail_v1"
    rig["locomotion_profile"] = "low_amble_lope_with_grasping_forepaws"
    rig["surface_profile"] = "grey_guard_fur_black_mask_flush_ring_tail"
    rig["limb_segments"] = 3
    return rig


def coat_material(project_root: Path, hero: bool) -> bpy.types.Material:
    shared = project_root / "assets/textures/animals/shared"
    albedo = BEAR.tinted_fur_image(shared / "quadruped_fur_atlas_albedo.png", "raccoon_guard_fur_albedo", (0.38, 0.39, 0.37), hero)
    normal = BEAR.packed_image(shared / "quadruped_fur_atlas_normal.png", "raccoon_guard_fur_normal", "Non-Color", hero)
    roughness = BEAR.packed_image(shared / "quadruped_fur_atlas_roughness.png", "raccoon_guard_fur_roughness", "Non-Color", hero)
    material = bpy.data.materials.new("raccoon_cinematic_guard_fur_pbr")
    material.use_nodes = True
    material.diffuse_color = (0.38, 0.39, 0.37, 1.0)
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    principled = nodes.get("Principled BSDF")
    if principled is None:
        raise RuntimeError("missing Principled BSDF")
    principled.inputs["Roughness"].default_value = 0.87
    albedo_node = nodes.new("ShaderNodeTexImage")
    albedo_node.image = albedo
    links.new(albedo_node.outputs["Color"], principled.inputs["Base Color"])
    normal_node = nodes.new("ShaderNodeTexImage")
    normal_node.image = normal
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = 0.48
    links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])
    roughness_node = nodes.new("ShaderNodeTexImage")
    roughness_node.image = roughness
    links.new(roughness_node.outputs["Color"], principled.inputs["Roughness"])
    material["eco_pbr_surface"] = "authored_raccoon_guard_fur"
    return material


def subtle_guard_hair(body: bpy.types.Object, hero: bool) -> None:
    texture = bpy.data.textures.new("RaccoonGuardHairRelief", type="CLOUDS")
    texture.noise_scale = 0.058 if hero else 0.092
    texture.noise_depth = 1
    modifier = body.modifiers.new("RaccoonGuardHairRelief", "DISPLACE")
    modifier.texture = texture
    modifier.texture_coords = "GLOBAL"
    modifier.strength = 0.008 if hero else 0.005
    modifier.mid_level = 0.52
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


def skin_continuous_raccoon(body: bpy.types.Object, rig: bpy.types.Object) -> None:
    deform_names = [
        "Spine", "Chest", "Neck", "Head", "Tail", "TailTip",
        "Leg_LF", "Lower_LF", "Paw_LF", "Leg_RF", "Lower_RF", "Paw_RF",
        "Leg_LH", "Lower_LH", "Paw_LH", "Leg_RH", "Lower_RH", "Paw_RH",
    ]
    radius = {
        "Spine": 0.58, "Chest": 0.59, "Neck": 0.43, "Head": 0.44,
        "Tail": 0.38, "TailTip": 0.33,
        "Leg_LF": 0.25, "Leg_RF": 0.25, "Leg_LH": 0.26, "Leg_RH": 0.26,
        "Lower_LF": 0.19, "Lower_RF": 0.19, "Lower_LH": 0.20, "Lower_RH": 0.20,
        "Paw_LF": 0.23, "Paw_RF": 0.23, "Paw_LH": 0.23, "Paw_RH": 0.23,
    }
    weights = {name: [0.0] * len(body.data.vertices) for name in deform_names}
    for vertex in body.data.vertices:
        point = vertex.co
        candidates = []
        for name in deform_names:
            bone = rig.data.bones[name]
            distance = point_segment_distance(point, bone.head_local, bone.tail_local)
            value = math.exp(-3.5 * (distance / radius[name]) ** 2)
            if point.z > 0.58 and name.startswith(("Leg_", "Lower_", "Paw_")):
                value *= 0.28
            elif point.z < 0.52 and name in ("Spine", "Chest", "Neck", "Head", "Tail", "TailTip"):
                value *= 0.40
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


def build_raccoon_body(hero: bool, rig: bpy.types.Object, coat, pale, dark) -> bpy.types.Object:
    elements = [
        ((0.0, 0.79, 0.55), (0.50, 0.47, 0.50), 2.38),
        ((0.0, 0.84, 0.10), (0.55, 0.51, 0.62), 2.44),
        ((0.0, 0.86, -0.43), (0.53, 0.49, 0.52), 2.44),
        ((0.0, 0.91, -0.80), (0.41, 0.40, 0.38), 2.44),
        ((0.0, 0.92, -1.10), (0.43, 0.42, 0.40), 2.48),
        ((0.0, 0.85, -1.36), (0.37, 0.34, 0.34), 2.48),
        ((0.0, 0.78, -1.56), (0.25, 0.23, 0.27), 2.46),
        ((0.0, 0.80, 0.83), (0.38, 0.36, 0.36), 2.48),
        ((0.0, 0.81, 1.12), (0.35, 0.33, 0.36), 2.50),
        ((0.0, 0.83, 1.42), (0.31, 0.30, 0.36), 2.52),
        ((0.0, 0.87, 1.72), (0.27, 0.26, 0.34), 2.54),
        ((0.0, 0.91, 1.94), (0.22, 0.22, 0.26), 2.54),
    ]
    for suffix in LIMBS:
        hip, joint, ankle, toe = limb_points(suffix)
        paw_centre = Vector((toe[0], 0.12, toe[2] - 0.05))
        elements.extend([
            (tuple(Vector(hip).lerp(Vector(joint), 0.20)), (0.24, 0.25, 0.22), 2.62),
            (tuple(Vector(hip).lerp(Vector(joint), 0.58)), (0.20, 0.24, 0.18), 2.66),
            (tuple(joint), (0.18, 0.18, 0.17), 2.70),
            (tuple(Vector(joint).lerp(Vector(ankle), 0.55)), (0.145, 0.20, 0.14), 2.70),
            (tuple(ankle), (0.16, 0.15, 0.16), 2.72),
            (tuple(Vector(ankle).lerp(paw_centre, 0.58)), (0.17, 0.14, 0.20), 2.74),
            (tuple(paw_centre), (0.22, 0.15, 0.30), 2.74),
        ])
    body = PIPELINE.metaball_mesh("RaccoonOrganicBodyV2_SourceConnected", elements, coat, hero)
    body.data.name = "RaccoonOrganicBodyV2SourceMesh"
    body["eco_anatomy_contract"] = "adult_raccoon_continuous_body_limbs_and_ring_tail"
    body["eco_surface_pattern"] = "flush_mask_leg_and_ring_tail_regions"
    pale_index = PIPELINE.append_material(body, pale)
    dark_index = PIPELINE.append_material(body, dark)
    for polygon in body.data.polygons:
        centre = sum((body.data.vertices[index].co for index in polygon.vertices), Vector()) / len(polygon.vertices)
        x = centre.x
        godot_y = centre.z
        godot_z = centre.y
        if godot_z > 0.79:
            band = int(max(0.0, godot_z - 0.79) / 0.20)
            polygon.material_index = dark_index if band % 2 == 0 else pale_index
        elif godot_y < 0.34:
            polygon.material_index = dark_index
        elif godot_y < 0.59 and -0.65 < godot_z < 0.58:
            polygon.material_index = pale_index
        elif godot_z < -1.18 and 0.72 < godot_y < 1.08 and abs(x) > 0.08:
            polygon.material_index = dark_index
    subtle_guard_hair(body, hero)
    BEAR.smart_uv(body)
    skin_continuous_raccoon(body, rig)
    return body


def build_raccoon_details(hero: bool, rig: bpy.types.Object, coat, pale, dark, eye, nose, paw) -> list[bpy.types.Object]:
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

    def claw(name: str, start, end, radius, bone: str):
        obj = PIPELINE.cone_between(name, start, end, radius, paw, hero)
        PIPELINE.rigid_skin(obj, rig, bone)
        parts.append(obj)
        return obj

    for suffix, side in (("L", -1.0), ("R", 1.0)):
        ear_parts = PIPELINE.ear_leaf(
            f"RaccoonEarSilhouette_{suffix}",
            (side * 0.24, 1.02, -1.12),
            (side * 0.34, 1.28, -1.10),
            0.14,
            0.035,
            coat,
            pale,
            hero,
        )
        for obj in ear_parts:
            PIPELINE.rigid_skin(obj, rig, f"Ear_{suffix}")
            parts.append(obj)
        sphere(f"RaccoonMaskDetail_{suffix}", (side * 0.22, 0.91, -1.43), (0.25, 0.15, 0.060), dark, "Head")
        sphere(f"RaccoonEyeDetail_{suffix}", (side * 0.23, 0.94, -1.485), (0.037, 0.040, 0.025), eye, "Head")
        sphere(f"RaccoonBrowDetail_{suffix}", (side * 0.21, 1.03, -1.42), (0.17, 0.075, 0.032), pale, "Head")
        sphere(f"RaccoonCheekDetail_{suffix}", (side * 0.25, 0.82, -1.43), (0.17, 0.12, 0.045), pale, "Head")

    sphere("RaccoonWetNoseDetail", (0.0, 0.79, -1.76), (0.15, 0.11, 0.075), nose, "Head")
    capsule("RaccoonPaleMuzzleDetail", (0.0, 0.82, -1.38), (0.0, 0.76, -1.63), 0.19, pale, "Head", 0.72)
    capsule("RaccoonLowerJawDetail", (0.0, 0.74, -1.34), (0.0, 0.70, -1.59), 0.13, pale, "Jaw", 0.62)

    for suffix in LIMBS:
        _hip, _joint, _ankle, toe = limb_points(suffix)
        front = suffix.endswith("F")
        sphere(f"RaccoonPalmDetail_{suffix}", (toe[0], 0.095, toe[2] - 0.13), (0.15, 0.075, 0.18), paw, f"Paw_{suffix}")
        digit_count = 5 if hero else 3
        for digit_index in range(digit_count):
            lateral = (digit_index - (digit_count - 1) * 0.5) * (0.047 if hero else 0.065)
            length = 0.17 if front else 0.13
            claw(
                f"RaccoonFingerDetail_{suffix}_{digit_index}",
                (toe[0] + lateral, 0.105, toe[2] - 0.22),
                (toe[0] + lateral, 0.080, toe[2] - 0.22 - length),
                0.018,
                f"Paw_{suffix}",
            )
    return parts


def attach_sockets(rig: bpy.types.Object) -> None:
    PIPELINE.attach_socket("SkillSocket_Mouth", (0.0, 0.80, -1.74), rig, "Head")
    PIPELINE.attach_socket("SkillSocket_Chest", (0.0, 0.91, -0.54), rig, "Chest")


def triangle_count(objects: list[bpy.types.Object]) -> tuple[int, int]:
    triangles = 0
    vertices = 0
    for obj in objects:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
        vertices += len(obj.data.vertices)
    return triangles, vertices


def export_profile(source_dir: Path, output_root: Path, hero: bool) -> tuple[int, int, int]:
    source_file = source_dir / SOURCE_BASENAME
    if not source_file.is_file():
        raise RuntimeError(f"missing CC0 raccoon reference source: {source_file}")
    PIPELINE.reset_scene()
    cfg = raccoon_config()
    rig = build_raccoon_rig()
    project_root = Path(__file__).resolve().parents[2]
    coat = coat_material(project_root, hero)
    pale = PIPELINE.pbr_material("raccoon_cinematic_pale_fur_pbr", "#b8b7ad", 0.88)
    dark = PIPELINE.pbr_material("raccoon_cinematic_mask_pbr", "#202427", 0.90)
    eye = PIPELINE.pbr_material("raccoon_cinematic_eye_pbr", "#16130f", 0.11)
    nose = PIPELINE.pbr_material("raccoon_cinematic_nose_pbr", "#17191a", 0.25)
    paw = PIPELINE.pbr_material("raccoon_cinematic_paw_pbr", "#26282a", 0.70)
    body = build_raccoon_body(hero, rig, coat, pale, dark)
    PIPELINE.validate_continuous_flesh("raccoon", [body])
    details = build_raccoon_details(hero, rig, coat, pale, dark, eye, nose, paw)
    attach_sockets(rig)
    PIPELINE.create_ground_actions(rig, cfg)

    profile = "hero" if hero else "mobile"
    output = output_root / "raccoon" / f"raccoon_{profile}.glb"
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
    triangles, vertices = triangle_count([body, *details])
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
        print(f"CINEMATIC_RACCOON_OK: {profile} / {triangles} triangles / {vertices} vertices / {bones} bones")


if __name__ == "__main__":
    main()
