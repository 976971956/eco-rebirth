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
    "crocodile.blend": "ad6f606d67259a65b5c253ab211e8e5616b7f420e48ca08b4650bb7f5caef021",
    "croc_diffuse.png": "9d46248a51e1d1e37614cf5a23ee04480d24aa5b77b36ef4a37e0a927bae73dd",
    "croc_height.png": "9892bcf8848a754f26ad53a8d517d74a4d93162d59e44c59149fdec11177405d",
    "croc_normal.png": "8f1469421b85658ab996072e5438c5acca28ad450affe968871b8c0ae680934d",
    "croc_specular.png": "a36a9b7e7a57e03918c077409beaf2c7262e0a7545a34b5fb74cd131ebe6f616",
}
SOURCE_SHA256 = SOURCE_FILES["crocodile.blend"]
LIMBS = ("LF", "RF", "LH", "RH")


def load_pipeline_module():
    module_path = Path(__file__).resolve().with_name("build_remaining_species.py")
    spec = importlib.util.spec_from_file_location("eco_remaining_species", module_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load shared species pipeline: {module_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


PIPELINE = load_pipeline_module()


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description="Build the authored cinematic adult marsh crocodile")
    parser.add_argument("--source-dir", required=True)
    parser.add_argument("--output-root", required=True)
    return parser.parse_args(argv)


def verify_source(source_dir: Path) -> None:
    for basename, expected in SOURCE_FILES.items():
        source = source_dir / basename
        if not source.is_file():
            raise RuntimeError(f"missing CC0 crocodile reference source: {source}")
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        if digest != expected:
            raise RuntimeError(f"crocodile reference checksum mismatch for {basename}: {digest}")


def cropped_scale_image(path: Path, name: str, colorspace: str, hero: bool) -> bpy.types.Image:
    """Normalize the legacy atlas into one olive scale family for new UVs."""
    source = bpy.data.images.load(str(path), check_existing=False)
    source.colorspace_settings.name = colorspace
    size = 512 if hero else 256
    source.scale(size, size)
    if colorspace == "sRGB":
        pixels = list(source.pixels)
        for index in range(0, len(pixels), 4):
            luminance = pixels[index] * 0.24 + pixels[index + 1] * 0.64 + pixels[index + 2] * 0.12
            grain = 0.76 + luminance * 0.44
            pixels[index] = min(1.0, 0.30 * grain)
            pixels[index + 1] = min(1.0, 0.39 * grain)
            pixels[index + 2] = min(1.0, 0.18 * grain)
            pixels[index + 3] = 1.0
        source.pixels = pixels
        source.update()
    source.name = name
    source.pack()
    return source


def crocodile_scale_material(source_dir: Path, hero: bool) -> bpy.types.Material:
    diffuse = cropped_scale_image(source_dir / "croc_diffuse.png", "crocodile_scale_albedo", "sRGB", hero)
    normal = cropped_scale_image(source_dir / "croc_normal.png", "crocodile_scale_normal", "Non-Color", hero)
    material = bpy.data.materials.new("crocodile_authored_scale_pbr")
    material.use_nodes = True
    material.diffuse_color = (0.23, 0.29, 0.14, 1.0)
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    principled = nodes.get("Principled BSDF")
    if principled is None:
        raise RuntimeError("missing Principled BSDF")
    principled.inputs["Roughness"].default_value = 0.73
    if "Specular IOR Level" in principled.inputs:
        principled.inputs["Specular IOR Level"].default_value = 0.31
    diffuse_node = nodes.new("ShaderNodeTexImage")
    diffuse_node.image = diffuse
    links.new(diffuse_node.outputs["Color"], principled.inputs["Base Color"])
    normal_node = nodes.new("ShaderNodeTexImage")
    normal_node.image = normal
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = 0.68 if hero else 0.48
    links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])
    material["eco_pbr_surface"] = "cc0_scale_albedo_normal_authored_crocodile"
    return material


def add_cylindrical_uv(obj: bpy.types.Object) -> None:
    if obj.type != "MESH" or not obj.data.polygons:
        return
    uv_layer = obj.data.uv_layers.get("CrocodileScaleUV") or obj.data.uv_layers.new(name="CrocodileScaleUV")
    min_y = min(vertex.co.y for vertex in obj.data.vertices)
    max_y = max(vertex.co.y for vertex in obj.data.vertices)
    span_y = max(max_y - min_y, 0.001)
    for polygon in obj.data.polygons:
        for loop_index in polygon.loop_indices:
            vertex = obj.data.vertices[obj.data.loops[loop_index].vertex_index].co
            u = (math.atan2(vertex.z, vertex.x) / math.tau + 0.5) * 2.4
            v = ((vertex.y - min_y) / span_y) * 4.8
            uv_layer.data[loop_index].uv = (u, v)


def replace_scale_material(parts: list[bpy.types.Object], material: bpy.types.Material, belly: bpy.types.Material) -> None:
    texture_targets = (
        "OrganicBodyV2", "UpperLimb", "LowerLimb", "ElbowDetail", "WebbedFoot",
    )
    for obj in parts:
        if obj.type != "MESH" or not any(token in obj.name for token in texture_targets):
            continue
        if len(obj.data.materials) == 0:
            obj.data.materials.append(material)
        else:
            obj.data.materials[0] = material
        if "OrganicBodyV2" in obj.name:
            if len(obj.data.materials) < 2:
                obj.data.materials.append(belly)
            else:
                obj.data.materials[1] = belly
            for polygon in obj.data.polygons:
                centre = sum((obj.data.vertices[index].co for index in polygon.vertices), Vector()) / len(polygon.vertices)
                polygon.material_index = 1 if centre.z < 0.44 else 0
        add_cylindrical_uv(obj)


def remove_prototype_details(parts: list[bpy.types.Object]) -> None:
    remove_prefixes = (
        "BackScuteDetail_", "V5EyeDetail_", "V5EyeBrowDetail_",
        "V5CrocodileNostrilDetail_", "LowerJawSilhouette", "ToothDetail_",
        "CrocodileUpperLimb_", "CrocodileLowerLimb_", "CrocodileWebbedFoot_",
        "CrocodileElbowDetail_",
    )
    for obj in list(parts):
        if not obj.name.startswith(remove_prefixes):
            continue
        parts.remove(obj)
        bpy.data.objects.remove(obj, do_unlink=True)


def skin_part(obj: bpy.types.Object, rig: bpy.types.Object, bone: str, parts: list[bpy.types.Object]) -> bpy.types.Object:
    PIPELINE.rigid_skin(obj, rig, bone)
    parts.append(obj)
    return obj


def axial_bone(z_value: float) -> str:
    if z_value < -1.02:
        return "Head"
    if z_value < -0.68:
        return "Neck"
    if z_value < -0.18:
        return "Chest"
    if z_value < 0.58:
        return "Body"
    if z_value < 1.18:
        return "Tail_Base"
    if z_value < 1.92:
        return "Tail_Mid"
    return "Tail_Tip"


def add_skull_details(hero: bool, rig: bpy.types.Object, parts: list[bpy.types.Object], scale, belly, dark, tooth, eye) -> None:
    # Wide, dorsoventrally flattened snout and raised orbital tables distinguish
    # a crocodilian from the mammal-like head used by the early prototype.
    upper = PIPELINE.ellipsoid_between(
        "CrocodileBroadUpperSnout",
        (0.0, 0.65, -1.28),
        (0.0, 0.62, -2.28),
        0.36,
        scale,
        hero,
        0.54,
    )
    skin_part(upper, rig, "Head", parts)
    add_cylindrical_uv(upper)
    lower = PIPELINE.ellipsoid_between(
        "CrocodileArticulatedLowerJaw",
        (0.0, 0.49, -1.20),
        (0.0, 0.43, -2.24),
        0.32,
        belly,
        hero,
        0.42,
    )
    skin_part(lower, rig, "Jaw", parts)

    for suffix, side in (("L", -1.0), ("R", 1.0)):
        orbit = PIPELINE.uv_sphere(
            f"CrocodileRaisedOrbit_{suffix}",
            (side * 0.28, 0.78, -1.48),
            (0.125, 0.065, 0.17),
            dark,
            hero,
        )
        skin_part(orbit, rig, "Head", parts)
        pupil = PIPELINE.uv_sphere(
            f"CrocodileAmberEye_{suffix}",
            (side * 0.30, 0.825, -1.55),
            (0.046, 0.040, 0.031),
            eye,
            hero,
        )
        skin_part(pupil, rig, "Head", parts)
        nostril = PIPELINE.uv_sphere(
            f"CrocodileNostril_{suffix}",
            (side * 0.16, 0.69, -2.25),
            (0.052, 0.026, 0.040),
            dark,
            hero,
        )
        skin_part(nostril, rig, "Head", parts)

        tooth_count = 7 if hero else 4
        for index in range(tooth_count):
            fraction = index / max(tooth_count - 1, 1)
            z_value = -1.34 - fraction * 0.78
            lateral = 0.29 - fraction * 0.035
            upper_tooth = PIPELINE.cone_between(
                f"CrocodileUpperTooth_{suffix}_{index}",
                (side * lateral, 0.54, z_value),
                (side * lateral, 0.39, z_value - 0.015),
                0.035 if hero else 0.042,
                tooth,
                hero,
            )
            skin_part(upper_tooth, rig, "Head", parts)
            if index % 2 == 0:
                lower_tooth = PIPELINE.cone_between(
                    f"CrocodileLowerTooth_{suffix}_{index}",
                    (side * (lateral + 0.018), 0.40, z_value - 0.055),
                    (side * (lateral + 0.018), 0.55, z_value - 0.065),
                    0.032 if hero else 0.040,
                    tooth,
                    hero,
                )
                skin_part(lower_tooth, rig, "Jaw", parts)


def add_osteoderms(hero: bool, rig: bpy.types.Object, parts: list[bpy.types.Object], scute) -> None:
    row_count = 14 if hero else 8
    for index in range(row_count):
        fraction = index / max(row_count - 1, 1)
        z_value = -0.72 + fraction * 2.58
        height = 0.98 - max(0.0, z_value - 0.70) * 0.18
        width = 0.14 * (1.0 - max(0.0, z_value - 0.72) * 0.18)
        length = 0.16 * (1.0 - max(0.0, z_value - 0.86) * 0.16)
        for row, lateral in enumerate((-0.22, 0.0, 0.22)):
            if not hero and row != 1 and index % 2:
                continue
            plate = PIPELINE.uv_sphere(
                f"CrocodileOsteoderm_{row}_{index}",
                (lateral * (1.0 - fraction * 0.45), height, z_value),
                (max(width, 0.075), 0.055 if hero else 0.060, max(length, 0.090)),
                scute,
                hero,
            )
            skin_part(plate, rig, axial_bone(z_value), parts)


def add_articulated_feet(hero: bool, rig: bpy.types.Object, parts: list[bpy.types.Object], scale, claw) -> None:
    for suffix in LIMBS:
        side = -1.0 if suffix.startswith("L") else 1.0
        front = suffix.endswith("F")
        z_value = -0.40 if front else 0.60
        shoulder = (side * 0.46, 0.54, z_value)
        joint = (side * 0.76, 0.31, z_value + (0.12 if front else -0.10))
        ankle = (side * 0.96, 0.13, z_value + (-0.09 if front else 0.13))
        foot_end = (side * 1.07, 0.08, z_value + (-0.30 if front else 0.28))
        upper = PIPELINE.tapered_segment_between(
            f"CrocodileAuthoredUpperLimb_{suffix}", shoulder, joint,
            0.205 if hero else 0.195, 0.145 if hero else 0.138, scale, hero,
        )
        lower = PIPELINE.tapered_segment_between(
            f"CrocodileAuthoredLowerLimb_{suffix}", joint, ankle,
            0.155 if hero else 0.148, 0.095 if hero else 0.090, scale, hero,
        )
        palm = PIPELINE.ellipsoid_between(
            f"CrocodileWebbedFootAuthored_{suffix}", ankle, foot_end,
            0.125 if hero else 0.120, scale, hero, 0.50,
        )
        skin_part(upper, rig, f"Leg_{suffix}", parts)
        skin_part(lower, rig, f"Lower_{suffix}", parts)
        skin_part(palm, rig, f"Paw_{suffix}", parts)
        for obj in (upper, lower, palm):
            add_cylindrical_uv(obj)
        base_z = foot_end[2]
        claw_count = 4 if front and hero else 3 if hero else 2
        for index in range(claw_count):
            spread = (index - (claw_count - 1) * 0.5) * (0.080 if hero else 0.12)
            start = (side * (1.03 + abs(spread) * 0.12), 0.085, base_z + spread)
            end = (side * 1.11, 0.070, base_z + spread - (0.12 if front else -0.11))
            toe = PIPELINE.ellipsoid_between(
                f"CrocodileSplayedToe_{suffix}_{index}", start, end,
                0.043 if hero else 0.052, scale, hero, 0.50,
            )
            skin_part(toe, rig, f"Paw_{suffix}", parts)
            tip = Vector(end)
            claw_tip = (tip.x + side * 0.050, 0.062, tip.z + (-0.055 if front else 0.055))
            nail = PIPELINE.cone_between(
                f"CrocodileClaw_{suffix}_{index}", end, claw_tip,
                0.016 if hero else 0.020, claw, hero,
            )
            skin_part(nail, rig, f"Paw_{suffix}", parts)


def customize_actions(rig: bpy.types.Object) -> None:
    rig.animation_data_create()

    def insert(action_name: str, bone_name: str, frame: int, xyz) -> None:
        rig.animation_data.action = bpy.data.actions[action_name]
        bone = rig.pose.bones[bone_name]
        bone.rotation_mode = "XYZ"
        bone.rotation_euler = xyz
        bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=bone_name)

    # A fast jaw snap with a short lateral head correction instead of a slow
    # mammal head-bob.  The active skill is a full axial death roll.
    for frame, windup, snap in ((1, 0.0, 0.0), (6, 1.0, 0.0), (10, 0.25, 1.0), (16, 0.0, 0.0), (23, 0.0, 0.0)):
        insert("attack", "Jaw", frame, (-0.62 * windup + 0.06 * snap, 0.0, 0.0))
        insert("attack", "Head", frame, (0.0, 0.0, 0.18 * windup - 0.10 * snap))
        insert("attack", "Neck", frame, (0.0, 0.0, 0.12 * windup - 0.08 * snap))
        insert("attack", "Chest", frame, (0.0, 0.0, -0.07 * windup))

    for frame, roll, clamp in ((1, 0.0, 0.0), (7, 0.10, 1.0), (12, 1.55, 1.0), (17, 3.15, 1.0), (22, 4.75, 1.0), (28, math.tau, 0.0)):
        insert("skill", "Body", frame, (0.0, roll, 0.0))
        insert("skill", "Chest", frame, (0.0, roll * 0.16, -0.06 * clamp))
        insert("skill", "Jaw", frame, (-0.50 * (1.0 - clamp), 0.0, 0.0))
        insert("skill", "Tail_Base", frame, (0.0, 0.0, -0.20 * math.sin(roll)))
        insert("skill", "Tail_Mid", frame, (0.0, 0.0, -0.34 * math.sin(roll - 0.35)))

    # During swimming the legs fold against the flanks and the propulsive wave
    # increases toward the tail.  This makes shore crawling and swimming read
    # as two different locomotion systems.
    for index, frame in enumerate((1, 5, 9, 13, 17, 21, 25, 29, 33)):
        phase = math.tau * index / 8.0
        for suffix in LIMBS:
            side_sign = -1.0 if suffix.startswith("L") else 1.0
            insert("swim", f"Leg_{suffix}", frame, (0.05 * math.sin(phase), 0.0, side_sign * 0.36))
            insert("swim", f"Lower_{suffix}", frame, (side_sign * 0.18, 0.0, -side_sign * 0.22))
            insert("swim", f"Paw_{suffix}", frame, (-side_sign * 0.12, 0.0, side_sign * 0.18))
        insert("swim", "Body", frame, (0.0, 0.0, 0.10 * math.sin(phase)))
        insert("swim", "Tail_Base", frame, (0.0, 0.0, 0.24 * math.sin(phase - 0.38)))
        insert("swim", "Tail_Mid", frame, (0.0, 0.0, 0.40 * math.sin(phase - 0.78)))
        insert("swim", "Tail_Tip", frame, (0.0, 0.0, 0.56 * math.sin(phase - 1.18)))
    rig.animation_data.action = bpy.data.actions["idle"]


def consolidate_detail_meshes(parts: list[bpy.types.Object]) -> list[bpy.types.Object]:
    """Batch rigid detail islands while retaining four named grounded feet."""
    body = next(obj for obj in parts if "OrganicBodyV2" in obj.name)
    feet = [obj for obj in parts if "CrocodileWebbedFoot" in obj.name]
    candidates = [obj for obj in parts if obj.type == "MESH" and obj is not body and obj not in feet]
    if not candidates:
        return parts
    bpy.ops.object.select_all(action="DESELECT")
    for obj in candidates:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = candidates[0]
    bpy.ops.object.join()
    cluster = bpy.context.active_object
    cluster.name = "CrocodileAuthoredDetailCluster"
    return [body, *feet, cluster]


def triangle_count(objects: list[bpy.types.Object]) -> tuple[int, int]:
    triangles = 0
    vertices = 0
    for obj in objects:
        if obj.type != "MESH":
            continue
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
        vertices += len(obj.data.vertices)
    return triangles, vertices


def export_profile(source_dir: Path, output_root: Path, hero: bool) -> tuple[int, int, int]:
    verify_source(source_dir)
    PIPELINE.reset_scene()
    rig, parts = PIPELINE.build_long_body("crocodile", hero)
    remove_prototype_details(parts)
    scale = crocodile_scale_material(source_dir, hero)
    belly = PIPELINE.pbr_material("crocodile_authored_accent_pbr", "#59633c", 0.78)
    replace_scale_material(parts, scale, belly)
    dark = PIPELINE.pbr_material("crocodile_authored_deep_scale_pbr", "#18251a", 0.68)
    scute = PIPELINE.pbr_material("crocodile_authored_detail_pbr", "#2c3b24", 0.81)
    tooth = PIPELINE.pbr_material("crocodile_authored_keratin_pbr", "#ded6b2", 0.52)
    eye = PIPELINE.pbr_material("crocodile_authored_eye_pbr", "#d5a72f", 0.10)
    add_skull_details(hero, rig, parts, scale, belly, dark, tooth, eye)
    add_osteoderms(hero, rig, parts, scute)
    add_articulated_feet(hero, rig, parts, scale, tooth)
    customize_actions(rig)
    parts = consolidate_detail_meshes(parts)
    rig["rig_version"] = 6
    rig["skin_mode"] = "project_authored_weighted_cinematic"
    rig["source_reference_sha256"] = SOURCE_SHA256
    rig["source_attribution"] = "Crocodile by br-n518, CC0 via OpenGameArt"
    rig["anatomy_profile"] = "adult_marsh_crocodile_flat_skull_armored_back_v1"
    rig["locomotion_profile"] = "four_beat_sprawl_tail_driven_swim_and_death_roll"
    rig["surface_profile"] = "cc0_scale_pbr_three_row_osteoderms"
    PIPELINE.validate_continuous_flesh("crocodile", parts)

    profile = "hero" if hero else "mobile"
    output = output_root / "crocodile" / f"crocodile_{profile}.glb"
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
    triangles, vertices = triangle_count(parts)
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
        print(f"CINEMATIC_CROCODILE_OK: {profile} / {triangles} triangles / {vertices} vertices / {bones} bones")


if __name__ == "__main__":
    main()
