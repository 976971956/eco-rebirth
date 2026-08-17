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
    "LICENSE.txt": "87caf90cbbf5c05ec663f0be4d2f2f47a4c61873a756d37e206c4a326ff058a5",
    "SOURCE.md": "33ce570fbb585dc5d53c5b5b40520478fd35318feaef1ce60f1f5ebfddb33b15",
}
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
    parser = argparse.ArgumentParser(description="Build the authored cinematic adult capybara")
    parser.add_argument("--source-dir", required=True)
    parser.add_argument("--output-root", required=True)
    return parser.parse_args(argv)


def verify_source(source_dir: Path) -> None:
    for basename, expected in SOURCE_FILES.items():
        source = source_dir / basename
        if not source.is_file():
            raise RuntimeError(f"missing CC-BY capybara reference record: {source}")
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        if digest != expected:
            raise RuntimeError(f"capybara reference record checksum mismatch for {basename}: {digest}")


def capybara_config() -> dict:
    cfg = PIPELINE.config_for("capybara")
    cfg.update(width=0.78, height=0.70, length=1.46, leg=0.55, paw=0.22, head=0.54, muzzle=0.48, neck=0.32, tail=0.04, ear=0.14)
    cfg["v3"].update(
        gait="amble",
        sprint_gait="lope",
        stride=0.25,
        flex=0.46,
        stance=0.88,
        fore_scale=0.94,
        rear_scale=0.90,
        upper_thickness=1.18,
        lower_thickness=0.88,
        chest_mass=1.02,
        rump_mass=1.13,
        body_bob=0.027,
        head_bob=0.014,
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
            (side * 0.55, 0.95, -0.58),
            (side * 0.57, 0.58, -0.49),
            (side * 0.58, 0.24, -0.59),
            (side * 0.59, 0.095, -0.83),
        )
    return (
        (side * 0.57, 0.94, 0.58),
        (side * 0.59, 0.58, 0.42),
        (side * 0.60, 0.24, 0.61),
        (side * 0.61, 0.095, 0.36),
    )


def build_capybara_rig() -> bpy.types.Object:
    bpy.ops.object.armature_add(enter_editmode=True, location=(0.0, 0.0, 0.0))
    rig = bpy.context.active_object
    rig.name = "SpeciesSkeleton3D"
    rig.data.name = "AdultCapybaraCinematicRig"
    edit = rig.data.edit_bones
    root = edit[0]
    root.name = "Root"
    root.head = PIPELINE.g2b((0.0, 0.05, 0.14))
    root.tail = PIPELINE.g2b((0.0, 0.40, 0.14))
    root.use_deform = False

    spine = add_bone(edit, "Spine", (0.0, 1.03, 0.68), (0.0, 1.07, 0.06), root)
    chest = add_bone(edit, "Chest", (0.0, 1.07, 0.06), (0.0, 1.12, -0.62), spine)
    neck = add_bone(edit, "Neck", (0.0, 1.12, -0.62), (0.0, 1.16, -0.98), chest)
    head = add_bone(edit, "Head", (0.0, 1.16, -0.98), (0.0, 1.08, -1.57), neck)
    jaw = add_bone(edit, "Jaw", (0.0, 0.99, -1.29), (0.0, 0.94, -1.66), head)
    jaw.use_deform = False

    for suffix in LIMBS:
        hip, joint, ankle, toe = limb_points(suffix)
        upper = add_bone(edit, f"Leg_{suffix}", hip, joint, chest if suffix.endswith("F") else spine)
        lower = add_bone(edit, f"Lower_{suffix}", joint, ankle, upper)
        add_bone(edit, f"Paw_{suffix}", ankle, toe, lower)

    for suffix, side in (("L", -1.0), ("R", 1.0)):
        add_bone(edit, f"Ear_{suffix}", (side * 0.31, 1.40, -1.22), (side * 0.36, 1.54, -1.20), head)

    # Capybaras have only a vestigial external tail. Keep the runtime tail
    # contract inside the rump, so shared animation code remains compatible
    # without inventing a visible tail silhouette.
    tail = add_bone(edit, "Tail", (0.0, 1.02, 0.96), (0.0, 1.00, 1.05), spine)
    add_bone(edit, "TailTip", (0.0, 1.00, 1.05), (0.0, 0.98, 1.12), tail)
    bpy.ops.object.mode_set(mode="OBJECT")

    if len(rig.data.bones) != 22:
        raise RuntimeError(f"capybara runtime rig is not the 22-bone contract: {len(rig.data.bones)}")
    rig["eco_species"] = "capybara"
    rig["rig_version"] = 6
    rig["skin_mode"] = "project_authored_weighted_cinematic"
    rig["source_reference"] = "Poly by Google / Poly Pizza / CC-BY-3.0"
    rig["anatomy_profile"] = "adult_capybara_barrel_torso_blunt_high_head_v1"
    rig["locomotion_profile"] = "calm_four_beat_amble_short_plantigrade_limbs"
    rig["surface_profile"] = "coarse_russet_fur_pbr_webbed_dark_feet"
    rig["limb_segments"] = 3
    return rig


def coat_material(project_root: Path, hero: bool) -> bpy.types.Material:
    shared = project_root / "assets/textures/animals/shared"
    albedo = BEAR.tinted_fur_image(shared / "quadruped_fur_atlas_albedo.png", "capybara_coarse_fur_albedo", (0.46, 0.31, 0.20), hero)
    normal = BEAR.packed_image(shared / "quadruped_fur_atlas_normal.png", "capybara_coarse_fur_normal", "Non-Color", hero)
    roughness = BEAR.packed_image(shared / "quadruped_fur_atlas_roughness.png", "capybara_coarse_fur_roughness", "Non-Color", hero)
    material = bpy.data.materials.new("capybara_cinematic_coat_pbr")
    material.use_nodes = True
    material.diffuse_color = (0.46, 0.31, 0.20, 1.0)
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    principled = nodes.get("Principled BSDF")
    if principled is None:
        raise RuntimeError("missing Principled BSDF")
    principled.inputs["Roughness"].default_value = 0.88
    albedo_node = nodes.new("ShaderNodeTexImage")
    albedo_node.image = albedo
    links.new(albedo_node.outputs["Color"], principled.inputs["Base Color"])
    normal_node = nodes.new("ShaderNodeTexImage")
    normal_node.image = normal
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = 0.44
    links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])
    roughness_node = nodes.new("ShaderNodeTexImage")
    roughness_node.image = roughness
    links.new(roughness_node.outputs["Color"], principled.inputs["Roughness"])
    material["eco_pbr_surface"] = "authored_capybara_coarse_fur"
    return material


def point_segment_distance(point: Vector, start: Vector, end: Vector) -> float:
    delta = end - start
    if delta.length_squared <= 0.000001:
        return (point - start).length
    amount = max(0.0, min(1.0, (point - start).dot(delta) / delta.length_squared))
    return (point - start.lerp(end, amount)).length


def skin_continuous_body(body: bpy.types.Object, rig: bpy.types.Object) -> None:
    names = [
        "Spine", "Chest", "Neck", "Head",
        "Leg_LF", "Lower_LF", "Paw_LF", "Leg_RF", "Lower_RF", "Paw_RF",
        "Leg_LH", "Lower_LH", "Paw_LH", "Leg_RH", "Lower_RH", "Paw_RH",
    ]
    radius = {
        "Spine": 0.78, "Chest": 0.78, "Neck": 0.52, "Head": 0.54,
        "Leg_LF": 0.29, "Leg_RF": 0.29, "Leg_LH": 0.30, "Leg_RH": 0.30,
        "Lower_LF": 0.21, "Lower_RF": 0.21, "Lower_LH": 0.22, "Lower_RH": 0.22,
        "Paw_LF": 0.24, "Paw_RF": 0.24, "Paw_LH": 0.25, "Paw_RH": 0.25,
    }
    weights = {name: [0.0] * len(body.data.vertices) for name in names}
    for vertex in body.data.vertices:
        point = vertex.co
        candidates = []
        for name in names:
            bone = rig.data.bones[name]
            distance = point_segment_distance(point, bone.head_local, bone.tail_local)
            value = math.exp(-3.5 * (distance / radius[name]) ** 2)
            if point.z > 0.70 and name.startswith(("Leg_", "Lower_", "Paw_")):
                value *= 0.28
            elif point.z < 0.62 and name in ("Spine", "Chest", "Neck", "Head"):
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


def build_body(hero: bool, rig: bpy.types.Object, coat, belly) -> bpy.types.Object:
    elements = [
        ((0.0, 1.02, 0.70), (0.76, 0.66, 0.62), 2.45),
        ((0.0, 1.04, 0.24), (0.80, 0.70, 0.70), 2.50),
        ((0.0, 1.08, -0.24), (0.78, 0.70, 0.68), 2.50),
        ((0.0, 1.12, -0.62), (0.70, 0.64, 0.50), 2.46),
        ((0.0, 1.16, -0.90), (0.53, 0.50, 0.40), 2.52),
        ((0.0, 1.19, -1.14), (0.50, 0.48, 0.40), 2.55),
        ((0.0, 1.15, -1.33), (0.49, 0.45, 0.41), 2.58),
        ((0.0, 1.10, -1.51), (0.46, 0.38, 0.32), 2.60),
        ((0.0, 1.05, -1.67), (0.40, 0.30, 0.23), 2.60),
    ]
    for suffix in LIMBS:
        hip, joint, ankle, toe = limb_points(suffix)
        elements.extend([
            (tuple(Vector(hip).lerp(Vector(joint), 0.18)), (0.27, 0.28, 0.27), 2.66),
            (tuple(Vector(hip).lerp(Vector(joint), 0.56)), (0.23, 0.28, 0.21), 2.68),
            (tuple(joint), (0.21, 0.21, 0.20), 2.70),
            (tuple(Vector(joint).lerp(Vector(ankle), 0.56)), (0.16, 0.25, 0.15), 2.70),
            (tuple(ankle), (0.17, 0.17, 0.17), 2.72),
            (tuple(Vector(ankle).lerp(Vector(toe), 0.36)), (0.18, 0.14, 0.20), 2.76),
            (tuple(Vector(ankle).lerp(Vector(toe), 0.70)), (0.20, 0.13, 0.24), 2.76),
            ((toe[0], 0.12, toe[2] - 0.02), (0.17, 0.10, 0.21), 2.74),
        ])
    body = PIPELINE.metaball_mesh("CapybaraOrganicBodyV2_SourceConnected", elements, coat, hero)
    body.data.name = "AdultCapybaraOrganicBodyV2SourceMesh"
    body["eco_anatomy_contract"] = "adult_capybara_continuous_barrel_torso_blunt_high_head"
    body["eco_surface_pattern"] = "authored_russet_coarse_guard_hair_and_paler_belly"
    belly_index = PIPELINE.append_material(body, belly)
    for polygon in body.data.polygons:
        centre = sum((body.data.vertices[index].co for index in polygon.vertices), Vector()) / len(polygon.vertices)
        if centre.z < 0.82 and abs(centre.x) < 0.43 and centre.y > -1.20:
            polygon.material_index = belly_index
    BEAR.subtle_fur_relief(body, hero)
    BEAR.smart_uv(body)
    skin_continuous_body(body, rig)
    return body


def build_details(hero: bool, rig: bpy.types.Object, coat, belly, dark, eye, nose, tooth) -> list[bpy.types.Object]:
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
        for ear in PIPELINE.ear_leaf(
            f"CapybaraRoundEar_{suffix}",
            (side * 0.30, 1.39, -1.20),
            (side * 0.36, 1.53, -1.19),
            0.12,
            0.025,
            coat,
            belly,
            hero,
        ):
            PIPELINE.rigid_skin(ear, rig, f"Ear_{suffix}")
            parts.append(ear)
        sphere(f"CapybaraEyeDetail_{suffix}", (side * 0.38, 1.24, -1.38), (0.044, 0.047, 0.030), eye, "Head")
        sphere(f"CapybaraBrow_{suffix}", (side * 0.34, 1.31, -1.33), (0.13, 0.055, 0.12), coat, "Head")

    capsule("CapybaraBluntUpperMuzzle", (0.0, 1.10, -1.35), (0.0, 1.04, -1.66), 0.29, belly, "Head", 0.66)
    capsule("CapybaraLowerJaw", (0.0, 1.00, -1.37), (0.0, 0.94, -1.64), 0.21, belly, "Jaw", 0.58)
    sphere("CapybaraNasalPadDetail", (0.0, 1.06, -1.78), (0.25, 0.15, 0.09), nose, "Head")
    for side in (-1.0, 1.0):
        sphere(f"CapybaraNostrilDetail_{side:+.0f}", (side * 0.095, 1.08, -1.845), (0.043, 0.025, 0.017), dark, "Head")
    if hero:
        for side in (-1.0, 1.0):
            for index in range(3):
                offset = (index - 1) * 0.052
                cone(
                    f"CapybaraWhisker_{side:+.0f}_{index}",
                    (side * 0.20, 1.03 + offset, -1.67),
                    (side * 0.52, 1.01 + offset * 1.3, -1.80 + index * 0.02),
                    0.007,
                    belly,
                    "Head",
                )
        capsule("CapybaraIncisorLeft", (-0.060, 0.955, -1.63), (-0.060, 0.91, -1.74), 0.040, tooth, "Jaw", 0.48)
        capsule("CapybaraIncisorRight", (0.060, 0.955, -1.63), (0.060, 0.91, -1.74), 0.040, tooth, "Jaw", 0.48)

    for suffix in LIMBS:
        _hip, _joint, _ankle, toe = limb_points(suffix)
        front = suffix.endswith("F")
        digit_count = 4 if front and hero else 3
        palm = sphere(f"CapybaraWebbedPalm_{suffix}", (toe[0], 0.080, toe[2] - 0.08), (0.145, 0.055, 0.16), dark, f"Paw_{suffix}")
        palm["eco_foot_contract"] = "partially_webbed_plantigrade"
        span = 0.20 if digit_count == 4 else 0.17
        digit_positions = []
        for index in range(digit_count):
            lateral = (index - (digit_count - 1) * 0.5) * span / max(1, digit_count - 1)
            digit_positions.append(lateral)
            capsule(
                f"CapybaraToe_{suffix}_{index}",
                (toe[0] + lateral, 0.074, toe[2] - 0.11),
                (toe[0] + lateral, 0.060, toe[2] - 0.25),
                0.034,
                dark,
                f"Paw_{suffix}",
                0.56,
            )
        if hero:
            for index in range(len(digit_positions) - 1):
                left = toe[0] + digit_positions[index]
                right = toe[0] + digit_positions[index + 1]
                web = PIPELINE.authored_mesh(
                    f"CapybaraWebbing_{suffix}_{index}",
                    [(left, 0.069, toe[2] - 0.12), (right, 0.069, toe[2] - 0.12), ((left + right) * 0.5, 0.061, toe[2] - 0.23)],
                    [(0, 1, 2)],
                    [dark],
                    [0],
                )
                PIPELINE.rigid_skin(web, rig, f"Paw_{suffix}")
                parts.append(web)
    return parts


def attach_sockets(rig: bpy.types.Object) -> None:
    PIPELINE.attach_socket("SkillSocket_Mouth", (0.0, 1.06, -1.78), rig, "Head")
    PIPELINE.attach_socket("SkillSocket_Chest", (0.0, 1.10, -0.58), rig, "Chest")


def customize_actions(rig: bpy.types.Object) -> None:
    rig.animation_data_create()

    def insert(action_name: str, bone_name: str, frame: int, xyz) -> None:
        rig.animation_data.action = bpy.data.actions[action_name]
        bone = rig.pose.bones[bone_name]
        bone.rotation_mode = "XYZ"
        bone.rotation_euler = xyz
        bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=bone_name)

    # Calm social display: settle the rump, lower the muzzle and softly rotate
    # both ears. This reads as reassurance rather than another attack wind-up.
    for frame, calm in ((1, 0.0), (8, 0.42), (16, 1.0), (23, 0.70), (30, 0.0)):
        insert("skill", "Spine", frame, (0.12 * calm, 0.0, 0.0))
        insert("skill", "Chest", frame, (-0.08 * calm, 0.0, 0.0))
        insert("skill", "Neck", frame, (0.20 * calm, 0.0, 0.0))
        insert("skill", "Head", frame, (0.14 * calm, 0.0, 0.0))
        insert("skill", "Ear_L", frame, (0.0, 0.0, -0.22 * calm))
        insert("skill", "Ear_R", frame, (0.0, 0.0, 0.22 * calm))
        insert("skill", "Leg_LH", frame, (-0.18 * calm, 0.0, 0.0))
        insert("skill", "Leg_RH", frame, (-0.18 * calm, 0.0, 0.0))
    for frame, shove in ((1, 0.0), (6, -0.45), (11, 1.0), (18, 0.24), (24, 0.0)):
        insert("attack", "Spine", frame, (-0.10 * shove, 0.0, 0.0))
        insert("attack", "Neck", frame, (0.34 * shove, 0.0, 0.0))
        insert("attack", "Head", frame, (0.26 * shove, 0.0, 0.0))
        insert("attack", "Jaw", frame, (-0.24 * abs(shove), 0.0, 0.0))
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
    cfg = capybara_config()
    rig = build_capybara_rig()
    project_root = Path(__file__).resolve().parents[2]
    coat = coat_material(project_root, hero)
    belly = PIPELINE.pbr_material("capybara_cinematic_belly_pbr", "#6f513b", 0.90)
    dark = PIPELINE.pbr_material("capybara_cinematic_paw_pbr", "#2c241e", 0.78)
    eye = PIPELINE.pbr_material("capybara_cinematic_eye_pbr", "#17110d", 0.10)
    nose = PIPELINE.pbr_material("capybara_cinematic_wet_nose_pbr", "#342822", 0.34)
    tooth = PIPELINE.pbr_material("capybara_cinematic_incisor_pbr", "#d4b36c", 0.52)
    body = build_body(hero, rig, coat, belly)
    PIPELINE.validate_continuous_flesh("capybara", [body])
    details = build_details(hero, rig, coat, belly, dark, eye, nose, tooth)
    attach_sockets(rig)
    PIPELINE.create_ground_actions(rig, cfg)
    customize_actions(rig)

    profile = "hero" if hero else "mobile"
    output = output_root / "capybara" / f"capybara_{profile}.glb"
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
        print(f"CINEMATIC_CAPYBARA_OK: {profile} / {triangles} triangles / {vertices} vertices / {bones} bones")


if __name__ == "__main__":
    main()
