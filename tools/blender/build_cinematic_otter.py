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
    "LICENSE.txt": "b7030967cc0250d851795e5513239527a3cedb71a7d48e9ce82bb52872c20eef",
    "SOURCE.md": "00313230d2a5f71e7705e65817221e9ca6663ae07cba7f1d4892c783a5e220dd",
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
    parser = argparse.ArgumentParser(description="Build the authored cinematic adult river otter")
    parser.add_argument("--source-dir", required=True)
    parser.add_argument("--output-root", required=True)
    return parser.parse_args(argv)


def verify_source(source_dir: Path) -> None:
    for basename, expected in SOURCE_FILES.items():
        source = source_dir / basename
        if not source.is_file():
            raise RuntimeError(f"missing CC-BY otter reference record: {source}")
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        if digest != expected:
            raise RuntimeError(f"otter reference record checksum mismatch for {basename}: {digest}")


def otter_config() -> dict:
    cfg = PIPELINE.config_for("otter")
    cfg.update(width=0.46, height=0.44, length=1.48, leg=0.44, paw=0.17, head=0.41, muzzle=0.31, neck=0.32, tail=1.50, ear=0.11)
    cfg["v3"].update(
        gait="lope",
        sprint_gait="bound",
        stride=0.34,
        flex=0.56,
        stance=0.72,
        fore_scale=0.88,
        rear_scale=0.94,
        upper_thickness=0.94,
        lower_thickness=0.76,
        chest_mass=0.91,
        rump_mass=1.01,
        body_bob=0.050,
        head_bob=0.026,
        attack="pounce",
    )
    cfg["features"] = {"webbed_paws"}
    cfg["v5"].update(
        rib=0.90,
        waist=0.78,
        pelvis=0.96,
        belly=0.82,
        skull_width=1.06,
        skull_height=0.88,
        skull_length=0.84,
        muzzle_width=0.90,
        muzzle_height=0.54,
        muzzle_length=0.72,
        eye_scale=0.047,
        ear_width=0.34,
        muscle=0.67,
        foot_width=0.92,
    )
    return cfg


def coat_material(project_root: Path, hero: bool) -> bpy.types.Material:
    shared = project_root / "assets/textures/animals/shared"
    albedo = BEAR.tinted_fur_image(shared / "quadruped_fur_atlas_albedo.png", "otter_dense_fur_albedo", (0.255, 0.195, 0.145), hero)
    normal = BEAR.packed_image(shared / "quadruped_fur_atlas_normal.png", "otter_dense_fur_normal", "Non-Color", hero)
    roughness = BEAR.packed_image(shared / "quadruped_fur_atlas_roughness.png", "otter_dense_fur_roughness", "Non-Color", hero)
    material = bpy.data.materials.new("otter_cinematic_coat_pbr")
    material.use_nodes = True
    material.diffuse_color = (0.255, 0.195, 0.145, 1.0)
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    principled = nodes.get("Principled BSDF")
    if principled is None:
        raise RuntimeError("missing Principled BSDF")
    principled.inputs["Roughness"].default_value = 0.82
    albedo_node = nodes.new("ShaderNodeTexImage")
    albedo_node.image = albedo
    links.new(albedo_node.outputs["Color"], principled.inputs["Base Color"])
    normal_node = nodes.new("ShaderNodeTexImage")
    normal_node.image = normal
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = 0.38
    links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])
    roughness_node = nodes.new("ShaderNodeTexImage")
    roughness_node.image = roughness
    links.new(roughness_node.outputs["Color"], principled.inputs["Roughness"])
    material["eco_pbr_surface"] = "authored_river_otter_dense_waterproof_fur"
    return material


def replace_materials(parts: list[bpy.types.Object], coat, accent, paw, eye) -> None:
    for obj in parts:
        for index, material in enumerate(obj.data.materials):
            name = material.name.lower()
            if "_coat_pbr" in name:
                obj.data.materials[index] = coat
            elif "_accent_pbr" in name:
                obj.data.materials[index] = accent
            elif "_detail_pbr" in name:
                obj.data.materials[index] = paw
            elif "_eye_pbr" in name:
                obj.data.materials[index] = eye


def remove_old_feet(parts: list[bpy.types.Object]) -> None:
    for obj in list(parts):
        if obj.name.startswith("V5FootDetail") or obj.name.startswith("ClawDetail"):
            parts.remove(obj)
            bpy.data.objects.remove(obj, do_unlink=True)


def foot_position(cfg: dict, layout: dict, suffix: str) -> tuple[float, float, float]:
    _hip, _joint, _ankle, toe = PIPELINE.ground_limb_points(cfg, layout, suffix)
    return toe


def build_webbed_feet(hero: bool, rig: bpy.types.Object, cfg: dict, layout: dict, paw) -> list[bpy.types.Object]:
    parts: list[bpy.types.Object] = []
    for suffix in LIMBS:
        toe = foot_position(cfg, layout, suffix)
        front = suffix.endswith("F")
        length = 0.29 if front else 0.34
        width = 0.16 if front else 0.18
        foot = PIPELINE.ellipsoid_between(
            f"OtterWebbedFootDetail_{suffix}",
            (toe[0], 0.082, toe[2] + 0.03),
            (toe[0], 0.068, toe[2] - length),
            width,
            paw,
            hero,
            0.40,
        )
        PIPELINE.rigid_skin(foot, rig, f"Paw_{suffix}")
        parts.append(foot)
        digit_count = 5 if hero else 3
        lateral_positions = []
        for index in range(digit_count):
            lateral = (index - (digit_count - 1) * 0.5) * width * 1.45 / max(1, digit_count - 1)
            lateral_positions.append(lateral)
            toe_mesh = PIPELINE.ellipsoid_between(
                f"OtterToeDetail_{suffix}_{index}",
                (toe[0] + lateral, 0.071, toe[2] - length * 0.46),
                (toe[0] + lateral, 0.058, toe[2] - length * (0.88 + abs(lateral) * 0.22)),
                0.027 if hero else 0.032,
                paw,
                hero,
                0.46,
            )
            PIPELINE.rigid_skin(toe_mesh, rig, f"Paw_{suffix}")
            parts.append(toe_mesh)
        if hero:
            for index in range(len(lateral_positions) - 1):
                left = toe[0] + lateral_positions[index]
                right = toe[0] + lateral_positions[index + 1]
                web = PIPELINE.authored_mesh(
                    f"OtterWebbingDetail_{suffix}_{index}",
                    [
                        (left, 0.067, toe[2] - length * 0.42),
                        (right, 0.067, toe[2] - length * 0.42),
                        ((left + right) * 0.5, 0.059, toe[2] - length * 0.82),
                    ],
                    [(0, 1, 2)],
                    [paw],
                    [0],
                )
                PIPELINE.rigid_skin(web, rig, f"Paw_{suffix}")
                parts.append(web)
    return parts


def remove_old_tail_and_ears(parts: list[bpy.types.Object]) -> None:
    for obj in list(parts):
        if obj.name.startswith("V5Tail") or obj.name.startswith("V5EarSilhouette"):
            parts.remove(obj)
            bpy.data.objects.remove(obj, do_unlink=True)


def build_connected_rudder_tail(hero: bool, rig: bpy.types.Object, cfg: dict, layout: dict, coat) -> bpy.types.Object:
    ring_count = 13 if hero else 9
    sides = 12 if hero else 8
    vertices = []
    faces = []
    tail_weights = []
    tip_weights = []
    base_z = cfg["length"] * 0.61
    for ring in range(ring_count):
        amount = ring / (ring_count - 1)
        centre_y = layout["body_y"] - cfg["height"] * (0.02 + amount * 0.20)
        centre_z = base_z + cfg["tail"] * amount
        radius = 0.235 * (1.0 - amount * 0.72) + 0.022
        vertical_radius = radius * (0.60 - amount * 0.10)
        for side in range(sides):
            angle = math.tau * side / sides
            vertices.append((math.cos(angle) * radius, centre_y + math.sin(angle) * vertical_radius, centre_z))
            blend = max(0.0, min(1.0, (amount - 0.34) / 0.34))
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
    tail = PIPELINE.authored_mesh("OtterConnectedRudderTailSilhouette", vertices, faces, [coat], [0] * len(faces))
    for polygon in tail.data.polygons:
        polygon.use_smooth = True
    PIPELINE.add_armature_weights(tail, rig, {"Tail": tail_weights, "TailTip": tip_weights})
    BEAR.smart_uv(tail)
    tail["eco_tail_contract"] = "single_connected_broad_dorsoventrally_flattened_rudder"
    return tail


def build_round_ears(hero: bool, rig: bpy.types.Object, cfg: dict, layout: dict, coat, accent) -> list[bpy.types.Object]:
    ears = []
    for suffix, side in (("L", -1.0), ("R", 1.0)):
        ear = PIPELINE.uv_sphere(
            f"OtterRoundEarSilhouette_{suffix}",
            (side * cfg["head"] * 0.62, layout["head_y"] + cfg["head"] * 0.31, layout["head_z"] + cfg["head"] * 0.04),
            (cfg["head"] * 0.16, cfg["head"] * 0.17, cfg["head"] * 0.085),
            coat,
            hero,
        )
        PIPELINE.rigid_skin(ear, rig, f"Ear_{suffix}")
        ears.append(ear)
        if hero:
            inner = PIPELINE.uv_sphere(
                f"OtterRoundEarInnerDetail_{suffix}",
                (side * cfg["head"] * 0.665, layout["head_y"] + cfg["head"] * 0.315, layout["head_z"] + cfg["head"] * 0.02),
                (cfg["head"] * 0.075, cfg["head"] * 0.115, cfg["head"] * 0.055),
                accent,
                hero,
            )
            PIPELINE.rigid_skin(inner, rig, f"Ear_{suffix}")
            ears.append(inner)
    return ears


def add_face_details(hero: bool, rig: bpy.types.Object, paw) -> list[bpy.types.Object]:
    parts: list[bpy.types.Object] = []
    if not hero:
        return parts
    for side in (-1.0, 1.0):
        for index in range(3):
            offset = (index - 1.0) * 0.032
            whisker = PIPELINE.cone_between(
                f"OtterWhiskerDetail_{side:+.0f}_{index}",
                (side * 0.16, 0.92 + offset, -1.76),
                (side * 0.43, 0.91 + offset * 0.65, -1.82 + index * 0.014),
                0.004,
                paw,
                hero,
            )
            PIPELINE.rigid_skin(whisker, rig, "Head")
            parts.append(whisker)
    nose_bridge = PIPELINE.uv_sphere("OtterWetNoseDetail", (0.0, 0.96, -1.91), (0.13, 0.08, 0.07), paw, hero)
    PIPELINE.rigid_skin(nose_bridge, rig, "Head")
    parts.append(nose_bridge)
    return parts


def customize_actions(rig: bpy.types.Object) -> None:
    rig.animation_data_create()

    def insert(action_name: str, bone_name: str, frame: int, xyz) -> None:
        rig.animation_data.action = bpy.data.actions[action_name]
        bone = rig.pose.bones[bone_name]
        bone.rotation_mode = "XYZ"
        bone.rotation_euler = xyz
        bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=bone_name)

    # Both land lope and shallow-water swimming propagate a supple body wave
    # into the muscular tail instead of wagging only the tip.
    for action_name, strength in (("locomotion", 1.0), ("sprint", 1.45)):
        for frame in (1, 5, 9, 13, 17, 21, 25, 29, 33):
            cycle = math.tau * (frame - 1) / 32.0
            wave = math.sin(cycle)
            insert(action_name, "Spine", frame, (0.045 * wave * strength, 0.0, 0.075 * wave))
            insert(action_name, "Chest", frame, (-0.035 * wave * strength, 0.0, -0.060 * wave))
            insert(action_name, "Tail", frame, (-0.025 * wave, 0.0, -0.18 * wave * strength))
            insert(action_name, "TailTip", frame, (-0.020 * wave, 0.0, -0.28 * wave * strength))
    # 旋水突袭: tuck the paws, roll the long torso and sweep the rudder tail.
    for frame, surge in ((1, 0.0), (6, 0.42), (11, 1.0), (17, -0.72), (24, 0.0)):
        insert("skill", "Spine", frame, (-0.16 * abs(surge), 0.0, 0.46 * surge))
        insert("skill", "Chest", frame, (-0.10 * abs(surge), 0.0, -0.34 * surge))
        insert("skill", "Neck", frame, (0.12 * abs(surge), 0.0, -0.15 * surge))
        insert("skill", "Tail", frame, (0.0, 0.0, -0.62 * surge))
        insert("skill", "TailTip", frame, (0.0, 0.0, -0.78 * surge))
        for suffix in LIMBS:
            side = -1.0 if suffix.startswith("L") else 1.0
            insert("skill", f"Leg_{suffix}", frame, (-0.30 * abs(surge), 0.0, side * 0.18 * surge))
            insert("skill", f"Lower_{suffix}", frame, (0.52 * abs(surge), 0.0, 0.0))
            insert("skill", f"Paw_{suffix}", frame, (-0.28 * abs(surge), 0.0, 0.0))
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
    cfg = otter_config()
    layout = PIPELINE.ground_layout(cfg)
    rig, anchors = PIPELINE.build_ground_rig("otter", cfg, layout)
    parts = PIPELINE.build_ground_parts("otter", hero, rig, anchors, cfg, layout)
    project_root = Path(__file__).resolve().parents[2]
    coat = coat_material(project_root, hero)
    accent = PIPELINE.pbr_material("otter_cinematic_accent_pbr", "#6f543c", 0.90)
    paw = PIPELINE.pbr_material("otter_cinematic_paw_pbr", "#15110f", 0.93)
    eye = PIPELINE.pbr_material("otter_cinematic_eye_pbr", "#22140c", 0.10)
    replace_materials(parts, coat, accent, paw, eye)
    organic_body = next(obj for obj in parts if "OrganicBodyV2" in obj.name)
    BEAR.smart_uv(organic_body)
    remove_old_feet(parts)
    remove_old_tail_and_ears(parts)
    parts.extend(build_webbed_feet(hero, rig, cfg, layout, paw))
    parts.append(build_connected_rudder_tail(hero, rig, cfg, layout, coat))
    parts.extend(build_round_ears(hero, rig, cfg, layout, coat, accent))
    parts.extend(add_face_details(hero, rig, paw))
    PIPELINE.validate_continuous_flesh("otter", parts)
    rig.data.name = "AdultRiverOtterCinematicRig"
    rig["rig_version"] = 6
    rig["skin_mode"] = "project_authored_weighted_cinematic"
    rig["source_reference"] = "Poly by Google / Poly Pizza / CC-BY-3.0"
    rig["anatomy_profile"] = "adult_river_otter_streamlined_body_rudder_tail_v1"
    rig["locomotion_profile"] = "supple_land_lope_and_tail_driven_shallow_swim"
    rig["surface_profile"] = "dense_brown_waterproof_fur_pbr_webbed_dark_feet"
    PIPELINE.create_ground_actions(rig, cfg)
    customize_actions(rig)

    profile = "hero" if hero else "mobile"
    output = output_root / "otter" / f"otter_{profile}.glb"
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
        print(f"CINEMATIC_OTTER_OK: {profile} / {triangles} triangles / {vertices} vertices / {bones} bones")


if __name__ == "__main__":
    main()
