from __future__ import annotations

import argparse
import importlib.util
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


SOURCE_BASENAME = "boar_0.blend"
SOURCE_SHA256 = "c16625680d056f0402d1be209c41d16a63394aec94b082a63ad32f562e9f2d2d"
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
    parser = argparse.ArgumentParser(description="Build the authored cinematic adult wild boar")
    parser.add_argument("--source-dir", required=True)
    parser.add_argument("--output-root", required=True)
    return parser.parse_args(argv)


def boar_config() -> dict:
    cfg = PIPELINE.config_for("boar")
    cfg.update(width=0.78, height=0.72, length=1.58, leg=0.62, paw=0.19, head=0.50, muzzle=0.73, neck=0.40, tail=0.30, ear=0.24)
    cfg["v3"].update(
        gait="scuttle",
        sprint_gait="charge",
        stride=0.30,
        flex=0.45,
        stance=0.84,
        fore_scale=0.96,
        rear_scale=0.90,
        upper_thickness=1.22,
        lower_thickness=0.86,
        chest_mass=1.26,
        rump_mass=0.94,
        body_bob=0.038,
        head_bob=0.020,
        attack="charge",
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
            (side * 0.57, 1.20, -0.57),
            (side * 0.58, 0.72, -0.49),
            (side * 0.59, 0.25, -0.60),
            (side * 0.60, 0.10, -0.82),
        )
    return (
        (side * 0.55, 1.04, 0.58),
        (side * 0.57, 0.65, 0.42),
        (side * 0.59, 0.23, 0.61),
        (side * 0.60, 0.10, 0.39),
    )


def build_boar_rig() -> bpy.types.Object:
    bpy.ops.object.armature_add(enter_editmode=True, location=(0.0, 0.0, 0.0))
    rig = bpy.context.active_object
    rig.name = "SpeciesSkeleton3D"
    rig.data.name = "WildBoarCinematicRig"
    edit = rig.data.edit_bones
    root = edit[0]
    root.name = "Root"
    root.head = PIPELINE.g2b((0.0, 0.05, 0.14))
    root.tail = PIPELINE.g2b((0.0, 0.42, 0.14))
    root.use_deform = False

    spine = add_bone(edit, "Spine", (0.0, 1.04, 0.68), (0.0, 1.12, 0.05), root)
    chest = add_bone(edit, "Chest", (0.0, 1.12, 0.05), (0.0, 1.32, -0.62), spine)
    neck = add_bone(edit, "Neck", (0.0, 1.32, -0.62), (0.0, 1.26, -1.05), chest)
    head = add_bone(edit, "Head", (0.0, 1.26, -1.05), (0.0, 1.02, -1.72), neck)
    jaw = add_bone(edit, "Jaw", (0.0, 0.97, -1.35), (0.0, 0.88, -2.05), head)
    jaw.use_deform = False

    for suffix in LIMBS:
        hip, joint, ankle, toe = limb_points(suffix)
        upper = add_bone(edit, f"Leg_{suffix}", hip, joint, chest if suffix.endswith("F") else spine)
        lower = add_bone(edit, f"Lower_{suffix}", joint, ankle, upper)
        add_bone(edit, f"Paw_{suffix}", ankle, toe, lower)

    for suffix, side in (("L", -1.0), ("R", 1.0)):
        add_bone(edit, f"Ear_{suffix}", (side * 0.31, 1.45, -1.22), (side * 0.41, 1.70, -1.17), head)

    tail = add_bone(edit, "Tail", (0.0, 1.04, 1.08), (0.0, 1.12, 1.31), spine)
    add_bone(edit, "TailTip", (0.0, 1.12, 1.31), (0.10, 1.14, 1.46), tail)
    bpy.ops.object.mode_set(mode="OBJECT")

    if len(rig.data.bones) != 22:
        raise RuntimeError(f"boar runtime rig is not the 22-bone contract: {len(rig.data.bones)}")
    rig["eco_species"] = "boar"
    rig["rig_version"] = 6
    rig["skin_mode"] = "project_authored_weighted_cinematic"
    rig["source_reference_sha256"] = SOURCE_SHA256
    rig["anatomy_profile"] = "adult_wild_boar_wedge_shoulders_long_snout_v1"
    rig["locomotion_profile"] = "low_four_beat_scuttle_and_tusk_charge"
    rig["surface_profile"] = "bristled_brown_fur_pbr_keratin_tusks_split_hooves"
    rig["limb_segments"] = 3
    return rig


def coat_material(project_root: Path, hero: bool) -> bpy.types.Material:
    shared = project_root / "assets/textures/animals/shared"
    albedo = BEAR.tinted_fur_image(shared / "quadruped_fur_atlas_albedo.png", "boar_bristle_albedo", (0.255, 0.205, 0.155), hero)
    normal = BEAR.packed_image(shared / "quadruped_fur_atlas_normal.png", "boar_bristle_normal", "Non-Color", hero)
    roughness = BEAR.packed_image(shared / "quadruped_fur_atlas_roughness.png", "boar_bristle_roughness", "Non-Color", hero)
    material = bpy.data.materials.new("boar_cinematic_bristle_pbr")
    material.use_nodes = True
    material.diffuse_color = (0.255, 0.205, 0.155, 1.0)
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    principled = nodes.get("Principled BSDF")
    if principled is None:
        raise RuntimeError("missing Principled BSDF")
    principled.inputs["Roughness"].default_value = 0.90
    albedo_node = nodes.new("ShaderNodeTexImage")
    albedo_node.image = albedo
    links.new(albedo_node.outputs["Color"], principled.inputs["Base Color"])
    normal_node = nodes.new("ShaderNodeTexImage")
    normal_node.image = normal
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = 0.58
    links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])
    roughness_node = nodes.new("ShaderNodeTexImage")
    roughness_node.image = roughness
    links.new(roughness_node.outputs["Color"], principled.inputs["Roughness"])
    material["eco_pbr_surface"] = "authored_wild_boar_bristles"
    return material


def subtle_bristle_relief(body: bpy.types.Object, hero: bool) -> None:
    texture = bpy.data.textures.new("BoarBristleRelief", type="CLOUDS")
    texture.noise_scale = 0.052 if hero else 0.085
    texture.noise_depth = 1
    modifier = body.modifiers.new("BoarBristleRelief", "DISPLACE")
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


def skin_continuous_boar(body: bpy.types.Object, rig: bpy.types.Object) -> None:
    deform_names = [
        "Spine", "Chest", "Neck", "Head",
        "Leg_LF", "Lower_LF", "Paw_LF", "Leg_RF", "Lower_RF", "Paw_RF",
        "Leg_LH", "Lower_LH", "Paw_LH", "Leg_RH", "Lower_RH", "Paw_RH",
    ]
    radius = {
        "Spine": 0.77, "Chest": 0.82, "Neck": 0.58, "Head": 0.55,
        "Leg_LF": 0.32, "Leg_RF": 0.32, "Leg_LH": 0.30, "Leg_RH": 0.30,
        "Lower_LF": 0.22, "Lower_RF": 0.22, "Lower_LH": 0.21, "Lower_RH": 0.21,
        "Paw_LF": 0.25, "Paw_RF": 0.25, "Paw_LH": 0.24, "Paw_RH": 0.24,
    }
    weights = {name: [0.0] * len(body.data.vertices) for name in deform_names}
    for vertex in body.data.vertices:
        point = vertex.co
        candidates = []
        for name in deform_names:
            bone = rig.data.bones[name]
            distance = point_segment_distance(point, bone.head_local, bone.tail_local)
            value = math.exp(-3.4 * (distance / radius[name]) ** 2)
            if point.z > 0.70 and name.startswith(("Leg_", "Lower_", "Paw_")):
                value *= 0.30
            elif point.z < 0.64 and name in ("Spine", "Chest", "Neck", "Head"):
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


def build_boar_body(hero: bool, rig: bpy.types.Object, coat, accent) -> bpy.types.Object:
    elements = [
        ((0.0, 1.04, 0.64), (0.70, 0.62, 0.58), 2.38),
        ((0.0, 1.10, 0.12), (0.78, 0.67, 0.72), 2.44),
        ((0.0, 1.25, -0.48), (0.85, 0.78, 0.64), 2.46),
        ((0.0, 1.38, -0.76), (0.76, 0.69, 0.47), 2.46),
        ((0.0, 1.27, -1.03), (0.57, 0.56, 0.43), 2.48),
        ((0.0, 1.17, -1.33), (0.50, 0.48, 0.42), 2.50),
        ((0.0, 1.04, -1.62), (0.43, 0.39, 0.44), 2.50),
        ((0.0, 0.96, -1.91), (0.35, 0.29, 0.39), 2.50),
        ((0.0, 0.93, -2.13), (0.32, 0.24, 0.28), 2.46),
    ]
    for suffix in LIMBS:
        hip, joint, ankle, toe = limb_points(suffix)
        front = suffix.endswith("F")
        elements.extend([
            (tuple(Vector(hip).lerp(Vector(joint), 0.16)), (0.30 if front else 0.28, 0.31, 0.28), 2.62),
            (tuple(Vector(hip).lerp(Vector(joint), 0.54)), (0.25 if front else 0.24, 0.31, 0.22), 2.66),
            (tuple(joint), (0.22, 0.22, 0.21), 2.70),
            (tuple(Vector(joint).lerp(Vector(ankle), 0.54)), (0.17, 0.28, 0.16), 2.70),
            (tuple(ankle), (0.18, 0.18, 0.18), 2.72),
            ((toe[0], 0.13, toe[2] - 0.05), (0.22, 0.13, 0.29), 2.74),
        ])
    body = PIPELINE.metaball_mesh("BoarOrganicBodyV2_SourceConnected", elements, coat, hero)
    body.data.name = "WildBoarOrganicBodyV2SourceMesh"
    body["eco_anatomy_contract"] = "adult_wild_boar_continuous_wedge_torso_long_snout"
    body["eco_surface_pattern"] = "authored_dark_dorsal_bristle_and_lighter_flank"
    accent_index = PIPELINE.append_material(body, accent)
    for polygon in body.data.polygons:
        centre = sum((body.data.vertices[index].co for index in polygon.vertices), Vector()) / len(polygon.vertices)
        godot_y = centre.z
        godot_z = centre.y
        if godot_y < 0.78 and godot_z > -1.42:
            polygon.material_index = accent_index
    subtle_bristle_relief(body, hero)
    BEAR.smart_uv(body)
    skin_continuous_boar(body, rig)
    return body


def triangular_ear(name: str, side: float, outer, inner, rig: bpy.types.Object, bone: str) -> list[bpy.types.Object]:
    x = side * 0.31
    front = [
        (x - side * 0.17, 1.43, -1.24),
        (x + side * 0.20, 1.44, -1.22),
        (x + side * 0.08, 1.72, -1.17),
    ]
    vertices = front
    back = [(vx, vy, vz + 0.055) for vx, vy, vz in vertices]
    faces = [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
    obj = PIPELINE.authored_mesh(name, vertices + back, faces, [outer], [0] * len(faces))
    PIPELINE.rigid_skin(obj, rig, bone)
    inset_points = [tuple(Vector(front[0]).lerp(Vector(point), 0.74)) for point in front]
    inset = PIPELINE.authored_mesh(f"{name}Inner", inset_points, [(0, 1, 2)], [inner], [0])
    PIPELINE.rigid_skin(inset, rig, bone)
    return [obj, inset]


def build_boar_details(hero: bool, rig: bpy.types.Object, coat, accent, dark, eye, nose, keratin) -> list[bpy.types.Object]:
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
        parts.extend(triangular_ear(f"BoarTriangularEar_{suffix}", side, coat, accent, rig, f"Ear_{suffix}"))
        sphere(f"BoarEyeDetail_{suffix}", (side * 0.34, 1.22, -1.54), (0.038, 0.042, 0.030), eye, "Head")
        sphere(f"BoarBrowShield_{suffix}", (side * 0.29, 1.33, -1.45), (0.14, 0.08, 0.15), coat, "Head")

    sphere("BoarNasalDiscDetail", (0.0, 0.92, -2.29), (0.31, 0.24, 0.12), nose, "Head")
    for suffix, side in (("L", -1.0), ("R", 1.0)):
        sphere(f"BoarNostrilDetail_{suffix}", (side * 0.12, 0.94, -2.395), (0.055, 0.032, 0.018), dark, "Head")
        cone(f"BoarTuskDetailBase_{suffix}", (side * 0.28, 0.94, -1.88), (side * 0.40, 1.02, -2.02), 0.075, keratin, "Head")
        cone(f"BoarTuskDetailTip_{suffix}", (side * 0.40, 1.02, -2.02), (side * 0.35, 1.20, -2.10), 0.052, keratin, "Head")
    capsule("BoarLowerJaw", (0.0, 0.93, -1.52), (0.0, 0.84, -2.10), 0.25, accent, "Jaw", 0.72)
    capsule("BoarMouthLine", (0.0, 0.88, -1.70), (0.0, 0.84, -2.12), 0.018, dark, "Jaw", 0.40)

    mane_count = 17 if hero else 10
    for index in range(mane_count):
        amount = index / max(1, mane_count - 1)
        z = -1.15 + amount * 1.62
        y = 1.49 - max(0.0, z + 0.55) * 0.16
        height = 0.20 - abs(amount - 0.38) * 0.08
        bone = "Neck" if z < -0.72 else "Chest" if z < 0.05 else "Spine"
        cone(f"BoarDorsalBristle_{index:02d}", (0.0, y, z), (0.0, y + height, z + 0.025), 0.034 if hero else 0.044, dark, bone)

    for suffix in LIMBS:
        _hip, _joint, _ankle, toe = limb_points(suffix)
        for digit, lateral in (("Inner", -0.085), ("Outer", 0.085)):
            sphere(f"BoarSplitHoof_{suffix}_{digit}", (toe[0] + lateral, 0.105, toe[2] - 0.13), (0.085, 0.095, 0.18), dark, f"Paw_{suffix}")

    capsule("BoarTailBase", (0.0, 1.05, 1.04), (0.0, 1.12, 1.31), 0.095, coat, "Tail", 0.86)
    capsule("BoarTailTip", (0.0, 1.12, 1.29), (0.11, 1.14, 1.45), 0.070, dark, "TailTip", 0.82)
    return parts


def attach_sockets(rig: bpy.types.Object) -> None:
    PIPELINE.attach_socket("SkillSocket_Mouth", (0.0, 0.96, -2.31), rig, "Head")
    PIPELINE.attach_socket("SkillSocket_Chest", (0.0, 1.36, -0.66), rig, "Chest")


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
        raise RuntimeError(f"missing CC0 boar reference source: {source_file}")
    PIPELINE.reset_scene()
    cfg = boar_config()
    rig = build_boar_rig()
    project_root = Path(__file__).resolve().parents[2]
    coat = coat_material(project_root, hero)
    accent = PIPELINE.pbr_material("boar_cinematic_flank_pbr", "#4f4438", 0.88)
    dark = PIPELINE.pbr_material("boar_cinematic_dark_bristle_pbr", "#27231f", 0.91)
    eye = PIPELINE.pbr_material("boar_cinematic_eye_pbr", "#2c190e", 0.13)
    nose = PIPELINE.pbr_material("boar_cinematic_nose_pbr", "#332821", 0.48)
    keratin = PIPELINE.pbr_material("boar_cinematic_keratin_pbr", "#c5aa72", 0.56)
    body = build_boar_body(hero, rig, coat, accent)
    PIPELINE.validate_continuous_flesh("boar", [body])
    details = build_boar_details(hero, rig, coat, accent, dark, eye, nose, keratin)
    attach_sockets(rig)
    PIPELINE.create_ground_actions(rig, cfg)

    profile = "hero" if hero else "mobile"
    output = output_root / "boar" / f"boar_{profile}.glb"
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
        print(f"CINEMATIC_BOAR_OK: {profile} / {triangles} triangles / {vertices} vertices / {bones} bones")


if __name__ == "__main__":
    main()
