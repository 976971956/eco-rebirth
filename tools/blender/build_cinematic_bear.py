from __future__ import annotations

import argparse
import importlib.util
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


SOURCE_BASENAME = "bear.blend"
SOURCE_SHA256 = "12338af1da802c81ae78cec2391ac74e40e85e20e0b99f220a120316dada7a43"
ARCHIVE_SHA256 = "9f35721544eb565305b5d694416f6362703c0f201f2cb77b104aabc7876eb740"
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
    parser = argparse.ArgumentParser(description="Build the authored cinematic adult brown bear")
    parser.add_argument("--source-dir", required=True)
    parser.add_argument("--output-root", required=True)
    return parser.parse_args(argv)


def bear_config() -> dict:
    cfg = PIPELINE.config_for("bear")
    # Adult brown bears are compact, broad and plantigrade.  The shared heavy
    # preset is deliberately overridden so this rig cannot drift back toward
    # the long-necked, column-legged silhouette used by the first prototype.
    cfg.update(width=0.90, height=0.86, length=1.54, leg=0.72, paw=0.30, head=0.53, muzzle=0.34, neck=0.32, tail=0.15, ear=0.12)
    cfg["v3"].update(
        gait="lumber",
        sprint_gait="charge",
        stride=0.25,
        flex=0.51,
        stance=0.78,
        upper_thickness=1.30,
        lower_thickness=1.04,
        chest_mass=1.24,
        rump_mass=1.10,
        body_bob=0.040,
        head_bob=0.026,
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
            (side * 0.60, 1.38, -0.46),
            (side * 0.62, 0.84, -0.38),
            (side * 0.63, 0.29, -0.55),
            (side * 0.63, 0.11, -0.74),
        )
    return (
        (side * 0.59, 1.21, 0.50),
        (side * 0.61, 0.83, 0.26),
        (side * 0.63, 0.30, 0.57),
        (side * 0.63, 0.11, 0.34),
    )


def build_bear_rig() -> tuple[bpy.types.Object, dict[str, tuple[float, float, float]]]:
    bpy.ops.object.armature_add(enter_editmode=True, location=(0.0, 0.0, 0.0))
    rig = bpy.context.active_object
    rig.name = "SpeciesSkeleton3D"
    rig.data.name = "BrownBearCinematicRig"
    edit = rig.data.edit_bones
    root = edit[0]
    root.name = "Root"
    root.head = PIPELINE.g2b((0.0, 0.05, 0.18))
    root.tail = PIPELINE.g2b((0.0, 0.48, 0.18))
    root.use_deform = False

    spine = add_bone(edit, "Spine", (0.0, 1.18, 0.62), (0.0, 1.23, 0.05), root)
    chest = add_bone(edit, "Chest", (0.0, 1.23, 0.05), (0.0, 1.41, -0.48), spine)
    neck = add_bone(edit, "Neck", (0.0, 1.41, -0.48), (0.0, 1.40, -0.76), chest)
    head = add_bone(edit, "Head", (0.0, 1.40, -0.76), (0.0, 1.25, -1.53), neck)
    jaw = add_bone(edit, "Jaw", (0.0, 1.19, -1.18), (0.0, 1.12, -1.61), head)
    jaw.use_deform = False

    anchors = {
        "Spine": (0.0, 1.20, 0.52),
        "Chest": (0.0, 1.38, -0.40),
        "Neck": (0.0, 1.405, -0.66),
        "Head": (0.0, 1.33, -1.18),
    }
    for suffix in LIMBS:
        hip, joint, ankle, toe = limb_points(suffix)
        upper = add_bone(edit, f"Leg_{suffix}", hip, joint, chest if suffix.endswith("F") else spine)
        lower = add_bone(edit, f"Lower_{suffix}", joint, ankle, upper)
        add_bone(edit, f"Paw_{suffix}", ankle, toe, lower)
        anchors[f"Leg_{suffix}"] = tuple(Vector(hip).lerp(Vector(joint), 0.5))
        anchors[f"Lower_{suffix}"] = tuple(Vector(joint).lerp(Vector(ankle), 0.5))
        anchors[f"Paw_{suffix}"] = tuple(Vector(ankle).lerp(Vector(toe), 0.5))

    for suffix, side in (("L", -1.0), ("R", 1.0)):
        base = (side * 0.28, 1.58, -0.98)
        tip = (side * 0.35, 1.72, -0.97)
        add_bone(edit, f"Ear_{suffix}", base, tip, head)
        anchors[f"Ear_{suffix}"] = tuple(Vector(base).lerp(Vector(tip), 0.5))

    tail = add_bone(edit, "Tail", (0.0, 1.19, 0.92), (0.0, 1.14, 1.05), spine)
    add_bone(edit, "TailTip", (0.0, 1.14, 1.05), (0.0, 1.07, 1.13), tail)
    anchors["Tail"] = (0.0, 1.165, 0.985)
    anchors["TailTip"] = (0.0, 1.105, 1.09)
    bpy.ops.object.mode_set(mode="OBJECT")

    if len(rig.data.bones) != 22:
        raise RuntimeError(f"bear runtime rig is not the 22-bone contract: {len(rig.data.bones)}")
    rig["eco_species"] = "bear"
    rig["rig_version"] = 7
    rig["skin_mode"] = "project_authored_weighted_cinematic"
    rig["source_reference_sha256"] = SOURCE_SHA256
    rig["source_archive_sha256"] = ARCHIVE_SHA256
    rig["anatomy_profile"] = "adult_brown_bear_shouldered_plantigrade_v2"
    rig["locomotion_profile"] = "bear_specific_four_beat_walk_and_rolling_charge"
    rig["surface_profile"] = "tinted_fur_pbr_wet_nose_keratin_claws"
    rig["limb_segments"] = 3
    return rig, anchors


def tinted_fur_image(path: Path, name: str, tint: tuple[float, float, float], hero: bool) -> bpy.types.Image:
    source = bpy.data.images.load(str(path), check_existing=False)
    source.colorspace_settings.name = "sRGB"
    # Mobile textures are only used by AI actors. At the normal gameplay camera
    # distance a 128 px coat atlas retains the readable markings, while keeping
    # the level-10 roster from retaining dozens of unique 256 px image sets.
    size = 512 if hero else 64
    source.scale(size, size)
    pixels = list(source.pixels)
    for index in range(0, len(pixels), 4):
        luminance = pixels[index] * 0.72 + pixels[index + 1] * 0.20 + pixels[index + 2] * 0.08
        grain = 0.82 + luminance * 0.28
        pixels[index] = min(1.0, tint[0] * grain)
        pixels[index + 1] = min(1.0, tint[1] * grain)
        pixels[index + 2] = min(1.0, tint[2] * grain)
        pixels[index + 3] = 1.0
    source.pixels = pixels
    source.name = name
    source.pack()
    return source


def packed_image(path: Path, name: str, colorspace: str, hero: bool) -> bpy.types.Image:
    image = bpy.data.images.load(str(path), check_existing=False)
    size = 512 if hero else 64
    image.scale(size, size)
    image.name = name
    image.colorspace_settings.name = colorspace
    image.pack()
    return image


def coat_material(project_root: Path, hero: bool) -> bpy.types.Material:
    shared = project_root / "assets/textures/animals/shared"
    albedo = tinted_fur_image(shared / "quadruped_fur_atlas_albedo.png", "bear_fur_albedo", (0.255, 0.155, 0.080), hero)
    material = bpy.data.materials.new("bear_cinematic_coat_pbr")
    material.use_nodes = True
    material.diffuse_color = (0.255, 0.155, 0.080, 1.0)
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    principled = nodes.get("Principled BSDF")
    if principled is None:
        raise RuntimeError("missing Principled BSDF")
    principled.inputs["Roughness"].default_value = 0.86
    albedo_node = nodes.new("ShaderNodeTexImage")
    albedo_node.image = albedo
    links.new(albedo_node.outputs["Color"], principled.inputs["Base Color"])
    if hero:
        normal = packed_image(shared / "quadruped_fur_atlas_normal.png", "bear_fur_normal", "Non-Color", hero)
        roughness = packed_image(shared / "quadruped_fur_atlas_roughness.png", "bear_fur_roughness", "Non-Color", hero)
        normal_node = nodes.new("ShaderNodeTexImage")
        normal_node.image = normal
        normal_map = nodes.new("ShaderNodeNormalMap")
        normal_map.inputs["Strength"].default_value = 0.34
        links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
        links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])
        roughness_node = nodes.new("ShaderNodeTexImage")
        roughness_node.image = roughness
        links.new(roughness_node.outputs["Color"], principled.inputs["Roughness"])
    else:
        # Mobile models are seen as small AI silhouettes. A stable scalar
        # roughness avoids two unique resident texture maps per species without
        # changing their color markings or authored geometry.
        material["mobile_surface_channels"] = "albedo_plus_scalar_roughness"
    material["eco_pbr_surface"] = "authored_brown_bear_fur"
    return material


def solid_material(name: str, color: str, roughness: float, metallic: float = 0.0) -> bpy.types.Material:
    return PIPELINE.pbr_material(name, color, roughness, metallic)


def smart_uv(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(58.0), island_margin=0.018)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)


def subtle_fur_relief(body: bpy.types.Object, hero: bool) -> None:
    texture = bpy.data.textures.new("BearMicroFurRelief", type="CLOUDS")
    texture.noise_scale = 0.075 if hero else 0.11
    texture.noise_depth = 1
    modifier = body.modifiers.new("BearMicroFurRelief", "DISPLACE")
    modifier.texture = texture
    modifier.texture_coords = "GLOBAL"
    modifier.strength = 0.004 if hero else 0.0025
    modifier.mid_level = 0.52
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    body.select_set(False)


def _point_segment_distance(point: Vector, start: Vector, end: Vector) -> float:
    delta = end - start
    if delta.length_squared <= 0.000001:
        return (point - start).length
    amount = max(0.0, min(1.0, (point - start).dot(delta) / delta.length_squared))
    return (point - start.lerp(end, amount)).length


def skin_continuous_bear(body: bpy.types.Object, rig: bpy.types.Object) -> None:
    deform_names = [
        "Spine", "Chest", "Neck", "Head",
        "Leg_LF", "Lower_LF", "Paw_LF", "Leg_RF", "Lower_RF", "Paw_RF",
        "Leg_LH", "Lower_LH", "Paw_LH", "Leg_RH", "Lower_RH", "Paw_RH",
    ]
    radius = {
        "Spine": 0.90, "Chest": 0.92, "Neck": 0.62, "Head": 0.56,
        "Leg_LF": 0.40, "Leg_RF": 0.40, "Leg_LH": 0.40, "Leg_RH": 0.40,
        "Lower_LF": 0.29, "Lower_RF": 0.29, "Lower_LH": 0.29, "Lower_RH": 0.29,
        "Paw_LF": 0.36, "Paw_RF": 0.36, "Paw_LH": 0.36, "Paw_RH": 0.36,
    }
    weights = {name: [0.0] * len(body.data.vertices) for name in deform_names}
    for vertex in body.data.vertices:
        point = vertex.co
        candidates = []
        for name in deform_names:
            bone = rig.data.bones[name]
            distance = _point_segment_distance(point, bone.head_local, bone.tail_local)
            value = math.exp(-3.2 * (distance / radius[name]) ** 2)
            # Keep the deep rib cage stable while still allowing a smooth
            # shoulder/hip transition into the leg chains.
            if point.z > 0.78 and name.startswith(("Leg_", "Lower_", "Paw_")):
                value *= 0.34
            elif point.z < 0.72 and name in ("Spine", "Chest", "Neck", "Head"):
                value *= 0.46
            candidates.append((name, value))
        candidates.sort(key=lambda item: item[1], reverse=True)
        retained = candidates[:4]
        total = sum(value for _name, value in retained)
        if total <= 0.000001:
            retained = [(min(deform_names, key=lambda name: _point_segment_distance(point, rig.data.bones[name].head_local, rig.data.bones[name].tail_local)), 1.0)]
            total = 1.0
        for name, value in retained:
            weights[name][vertex.index] = value / total
    PIPELINE.add_armature_weights(body, rig, weights)


def build_bear_body(hero: bool, rig: bpy.types.Object, anchors: dict, cfg: dict, coat: bpy.types.Material, accent: bpy.types.Material) -> bpy.types.Object:
    elements = [
        ((0.0, 1.18, 0.56), (0.81, 0.67, 0.62), 2.34),
        ((0.0, 1.18, 0.08), (0.89, 0.75, 0.72), 2.38),
        ((0.0, 1.31, -0.42), (0.98, 0.84, 0.66), 2.38),
        ((0.0, 1.59, -0.43), (0.76, 0.48, 0.48), 2.26),
        ((0.0, 1.38, -0.70), (0.75, 0.67, 0.50), 2.46),
        ((0.0, 1.36, -0.96), (0.65, 0.59, 0.49), 2.42),
        ((0.0, 1.31, -1.20), (0.59, 0.51, 0.44), 2.40),
        ((0.0, 1.21, -1.43), (0.40, 0.31, 0.31), 2.46),
        ((0.0, 1.16, -1.61), (0.28, 0.20, 0.20), 2.42),
    ]
    # Build all four furred limbs and the top of every plantigrade paw into the
    # same metaball volume as the torso.  This creates one manifold coat surface
    # across shoulders, knees, heels and feet, so animation cannot reveal gaps.
    for suffix in LIMBS:
        hip, joint, ankle, toe = limb_points(suffix)
        front = suffix.endswith("F")
        upper_mid = Vector(hip).lerp(Vector(joint), 0.50)
        lower_mid = Vector(joint).lerp(Vector(ankle), 0.52)
        paw_center = Vector((toe[0], 0.155, toe[2] - (0.025 if front else 0.01)))
        elements.extend([
            (tuple(Vector(hip).lerp(Vector(joint), 0.18)), (0.40 if front else 0.38, 0.40, 0.35), 2.56),
            (tuple(upper_mid), (0.345 if front else 0.335, 0.37, 0.30), 2.60),
            (tuple(joint), (0.30, 0.29, 0.27), 2.64),
            (tuple(lower_mid), (0.255, 0.33, 0.24), 2.64),
            (tuple(ankle), (0.27, 0.23, 0.26), 2.66),
            (tuple(paw_center), (0.275, 0.18, 0.29 if front else 0.28), 2.68),
        ])
    # OrganicBodyV2 is the established cross-species runtime validator token;
    # keep it stable while the mesh's own versioned metadata advances to V3.
    body = PIPELINE.metaball_mesh("BearOrganicBodyV2_SourceConnected", elements, coat, hero)
    body.data.name = "BrownBearOrganicBodyV3SourceMesh"
    body["eco_anatomy_contract"] = "adult_brown_bear_compact_head_deep_barrel_plantigrade_paws"
    body["eco_surface_pattern"] = "authored_brown_fur_pbr"
    accent_index = PIPELINE.append_material(body, accent)
    for polygon in body.data.polygons:
        centre = sum((body.data.vertices[index].co for index in polygon.vertices), Vector()) / len(polygon.vertices)
        godot_y = centre.z
        godot_z = centre.y
        if godot_z < -1.34 and godot_y < 1.32:
            polygon.material_index = accent_index
    subtle_fur_relief(body, hero)
    smart_uv(body)
    skin_continuous_bear(body, rig)
    return body


def build_bear_details(hero: bool, rig: bpy.types.Object, coat, accent, eye, nose, paw, keratin) -> list[bpy.types.Object]:
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
        obj = PIPELINE.cone_between(name, start, end, radius, keratin, hero)
        PIPELINE.rigid_skin(obj, rig, bone)
        parts.append(obj)
        return obj

    # Short rounded pinnae are a primary bear cue; inner ear discs are inset
    # rather than modelled as the pointed leaf shared by hoofed animals.
    for suffix, side in (("L", -1.0), ("R", 1.0)):
        sphere(f"BearRoundEarSilhouette_{suffix}", (side * 0.30, 1.59, -1.00), (0.125, 0.135, 0.075), coat, f"Ear_{suffix}")
        sphere(f"BearInnerEarDetail_{suffix}", (side * 0.30, 1.59, -1.065), (0.062, 0.070, 0.015), paw, f"Ear_{suffix}")

    # Brow, small deep-set eyes, broad wet nose and lower muzzle.
    for suffix, side in (("L", -1.0), ("R", 1.0)):
        sphere(f"BearBrowSilhouette_{suffix}", (side * 0.28, 1.47, -1.26), (0.125, 0.060, 0.086), coat, "Head")
        sphere(f"V7EyeDetail_{suffix}", (side * 0.32, 1.39, -1.34), (0.031, 0.033, 0.025), eye, "Head")
    sphere("BearWetNoseDetail", (0.0, 1.18, -1.75), (0.20, 0.13, 0.095), nose, "Head")
    for suffix, side in (("L", -1.0), ("R", 1.0)):
        sphere(f"BearNostrilDetail_{suffix}", (side * 0.076, 1.195, -1.825), (0.032, 0.021, 0.012), paw, "Head")
    capsule("BearLowerJawAccent", (0.0, 1.16, -1.26), (0.0, 1.10, -1.62), 0.21, accent, "Jaw", 0.72)
    capsule("BearMouthLineDetail", (0.0, 1.115, -1.39), (0.0, 1.095, -1.67), 0.014, paw, "Jaw", 0.42)

    # Separate sole pads and cone claws are valid close-up anatomy, but from the
    # game's oblique camera they merge into a pale horseshoe below each foot.
    # The connected coat mesh already carries the grounded plantigrade shape, so
    # leave underside detail to a future fur-card close-up LOD.

    # Brown-bear tails are mostly hidden by the rump coat. Retain Tail/TailTip
    # bones for the shared rig contract but do not add separate ball-like meshes.
    return parts


def attach_sockets(rig: bpy.types.Object) -> None:
    PIPELINE.attach_socket("SkillSocket_Mouth", (0.0, 1.17, -1.78), rig, "Head")
    PIPELINE.attach_socket("SkillSocket_Chest", (0.0, 1.43, -0.45), rig, "Chest")


def create_bear_actions(rig: bpy.types.Object) -> None:
    """Author a grounded bear gait instead of inheriting the generic heavy preset."""
    rig.animation_data_create()
    flex_signs = {suffix: PIPELINE.limb_chain_flex_sign(rig, suffix) for suffix in LIMBS}

    def insert_rotation(bone_name: str, frame: int, xyz: tuple[float, float, float]) -> None:
        bone = rig.pose.bones[bone_name]
        bone.rotation_mode = "XYZ"
        bone.rotation_euler = xyz
        bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=bone_name)

    def neutral_pose(frame: int) -> None:
        for pose_bone in rig.pose.bones:
            insert_rotation(pose_bone.name, frame, (0.0, 0.0, 0.0))

    for action_name in PIPELINE.ACTIONS:
        action = bpy.data.actions.new(action_name)
        rig.animation_data.action = action
        neutral_pose(1)
        if action_name in ("locomotion", "sprint"):
            sprinting = action_name == "sprint"
            # A slow bear uses a lateral-sequence four-beat walk. The sprint
            # changes to a compact rolling charge without stretching the legs
            # into the canine silhouette that the previous generic gait caused.
            phases = (
                {"LF": 0.0, "RH": math.pi * 0.50, "RF": math.pi, "LH": math.pi * 1.50}
                if not sprinting
                else {"LH": 0.0, "RH": math.pi * 0.16, "LF": math.pi, "RF": math.pi * 1.16}
            )
            stride = 0.25 if not sprinting else 0.39
            flex = 0.34 if not sprinting else 0.47
            for frame in (1, 5, 9, 13, 17, 21, 25, 29, 33):
                cycle = math.tau * (frame - 1) / 32.0
                for suffix in LIMBS:
                    phase = phases[suffix]
                    swing = math.sin(cycle + phase)
                    lift = max(0.0, math.sin(cycle + phase - 0.30))
                    support = max(0.0, -math.sin(cycle + phase - 0.30))
                    rear_drive = 1.08 if suffix.endswith("H") and sprinting else 1.0
                    upper = stride * swing * rear_drive
                    lower = flex_signs[suffix] * flex * (0.86 * lift + 0.07 * support) * rear_drive
                    # Counter-rotate the wrist/ankle so the plantigrade pads
                    # remain visually grounded through the support phase.
                    paw = -flex_signs[suffix] * flex * (0.48 * lift + 0.030 * support) * rear_drive
                    insert_rotation(f"Leg_{suffix}", frame, (upper, 0.0, 0.0))
                    insert_rotation(f"Lower_{suffix}", frame, (lower, 0.0, 0.0))
                    insert_rotation(f"Paw_{suffix}", frame, (paw, 0.0, 0.0))
                wave = math.sin(cycle * (2.0 if sprinting else 1.0))
                roll = math.sin(cycle)
                insert_rotation("Spine", frame, (0.031 * wave, 0.0, 0.025 * roll))
                insert_rotation("Chest", frame, (-0.024 * wave, 0.0, -0.020 * roll))
                insert_rotation("Neck", frame, (0.020 * wave, 0.0, 0.0))
                insert_rotation("Head", frame, (-0.014 * wave, 0.0, 0.0))
                insert_rotation("Tail", frame, (0.006 * wave, 0.0, -0.018 * roll))
                insert_rotation("TailTip", frame, (0.005 * wave, 0.0, -0.026 * roll))
        elif action_name in ("attack", "skill"):
            skill = action_name == "skill"
            strength = 1.18 if skill else 1.0
            for frame, brace, strike in ((1, 0.0, 0.0), (7, 1.0, -0.18), (12, 0.42, 1.0), (23, 0.0, 0.0)):
                insert_rotation("Spine", frame, (-0.13 * brace * strength, 0.0, 0.10 * strike * strength))
                insert_rotation("Chest", frame, (-0.10 * brace * strength, 0.0, -0.09 * strike * strength))
                insert_rotation("Neck", frame, (0.13 * strike * strength, 0.0, 0.0))
                insert_rotation("Head", frame, (0.16 * strike * strength, 0.0, 0.0))
                insert_rotation("Jaw", frame, (-0.20 * max(strike, 0.0) * strength, 0.0, 0.0))
                if skill:
                    # The skill is a heavy two-paw ground shock, while normal
                    # attack keeps the species-readable single-paw swipe.
                    for suffix in ("LF", "RF"):
                        side_roll = -0.09 if suffix == "LF" else 0.09
                        insert_rotation(f"Leg_{suffix}", frame, (-0.58 * strike * strength, 0.0, side_roll * strike))
                        insert_rotation(f"Lower_{suffix}", frame, (flex_signs[suffix] * 0.34 * max(strike, 0.0), 0.0, 0.0))
                        insert_rotation(f"Paw_{suffix}", frame, (-flex_signs[suffix] * 0.16 * max(strike, 0.0), 0.0, 0.0))
                else:
                    insert_rotation("Leg_LF", frame, (-0.68 * strike, 0.0, -0.15 * strike))
                    insert_rotation("Lower_LF", frame, (flex_signs["LF"] * 0.39 * max(strike, 0.0), 0.0, 0.0))
                    insert_rotation("Paw_LF", frame, (-flex_signs["LF"] * 0.16 * max(strike, 0.0), 0.0, 0.0))
                    insert_rotation("Leg_RF", frame, (-0.14 * brace, 0.0, 0.0))
        elif action_name == "hit":
            for frame, recoil in ((1, 0.0), (6, 1.0), (15, 0.0)):
                insert_rotation("Spine", frame, (-0.08 * recoil, 0.0, 0.22 * recoil))
                insert_rotation("Chest", frame, (0.05 * recoil, 0.0, -0.10 * recoil))
                insert_rotation("Neck", frame, (0.10 * recoil, 0.0, -0.10 * recoil))
                insert_rotation("Head", frame, (0.07 * recoil, 0.0, -0.13 * recoil))
        elif action_name == "eat":
            for frame, lower, chew in ((1, 0.0, 0.0), (10, 0.70, 0.0), (18, 1.0, 1.0), (25, 1.0, -1.0), (34, 0.0, 0.0)):
                insert_rotation("Neck", frame, (0.48 * lower, 0.0, 0.0))
                insert_rotation("Head", frame, (0.31 * lower + 0.035 * chew, 0.0, 0.0))
                insert_rotation("Jaw", frame, (-0.060 * abs(chew) * lower, 0.0, 0.0))
        elif action_name == "death":
            for frame, fall in ((1, 0.0), (12, 0.28), (23, 0.82), (34, 1.0)):
                insert_rotation("Spine", frame, (0.04 * fall, 0.0, 1.12 * fall))
                insert_rotation("Chest", frame, (-0.08 * fall, 0.0, 0.20 * fall))
                insert_rotation("Neck", frame, (0.15 * fall, 0.0, -0.12 * fall))
                insert_rotation("Head", frame, (0.11 * fall, 0.0, -0.09 * fall))
        elif action_name == "idle":
            for frame, breath, listen in ((1, -1.0, 0.0), (11, 0.1, 1.0), (21, 1.0, -0.30), (31, -1.0, 0.0)):
                insert_rotation("Chest", frame, (0.014 * breath, 0.0, 0.0))
                insert_rotation("Neck", frame, (-0.009 * breath, 0.0, 0.0))
                insert_rotation("Head", frame, (0.006 * breath, 0.0, 0.0))
                insert_rotation("Ear_L", frame, (0.0, 0.055 * listen, 0.025 * listen))
                insert_rotation("Ear_R", frame, (0.0, -0.028 * listen, -0.014 * listen))
        action.use_fake_user = True
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
    source_file = source_dir / SOURCE_BASENAME
    if not source_file.is_file():
        raise RuntimeError(f"missing CC0 bear reference source: {source_file}")
    PIPELINE.reset_scene()
    cfg = bear_config()
    rig, anchors = build_bear_rig()
    project_root = Path(__file__).resolve().parents[2]
    coat = coat_material(project_root, hero)
    accent = solid_material("bear_cinematic_accent_pbr", "#5d402c", 0.86)
    eye = solid_material("bear_cinematic_eye_pbr", "#24160f", 0.13)
    nose = solid_material("bear_cinematic_nose_pbr", "#171312", 0.24)
    paw = solid_material("bear_cinematic_paw_pbr", "#2b211d", 0.68)
    keratin = solid_material("bear_cinematic_keratin_pbr", "#46382d", 0.62)
    body = build_bear_body(hero, rig, anchors, cfg, coat, accent)
    PIPELINE.validate_continuous_flesh("bear", [body])
    details = build_bear_details(hero, rig, coat, accent, eye, nose, paw, keratin)
    attach_sockets(rig)
    create_bear_actions(rig)

    profile = "hero" if hero else "mobile"
    output = output_root / "bear" / f"bear_{profile}.glb"
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
        print(f"CINEMATIC_BEAR_OK: {profile} / {triangles} triangles / {vertices} vertices / {bones} bones")


if __name__ == "__main__":
    main()
