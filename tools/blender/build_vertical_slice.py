from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


ACTIONS = ("idle", "locomotion", "sprint", "attack", "skill", "hit", "eat", "death")
LIMBS = ("LF", "RF", "LH", "RH")


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description="Build the Eco Rebirth realistic vertical slice")
    parser.add_argument("--output-root", required=True)
    return parser.parse_args(argv)


def g2b(value: tuple[float, float, float]) -> tuple[float, float, float]:
    """Godot (+Y up, -Z forward) to Blender (+Z up, -Y forward)."""
    return value[0], value[2], value[1]


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.metaballs, bpy.data.armatures, bpy.data.materials, bpy.data.actions):
        for datablock in list(datablocks):
            datablocks.remove(datablock)


def pbr_material(name: str, color: tuple[float, float, float, float], roughness: float, metallic: float = 0.0) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = color
    material.use_nodes = True
    principled = material.node_tree.nodes.get("Principled BSDF")
    if principled is not None:
        principled.inputs["Base Color"].default_value = color
        principled.inputs["Roughness"].default_value = roughness
        principled.inputs["Metallic"].default_value = metallic
    return material


def metaball_mesh(
    name: str,
    elements: list[tuple[tuple[float, float, float], tuple[float, float, float], float]],
    material: bpy.types.Material,
    resolution: float,
) -> bpy.types.Object:
    data = bpy.data.metaballs.new(f"{name}Surface")
    data.resolution = resolution
    data.render_resolution = max(resolution * 0.72, 0.025)
    # A lower fusion threshold keeps the procedural flesh connected around
    # joints.  The former 0.62 value left visible gaps between body sections.
    data.threshold = 0.46
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    for position, scale, stiffness in elements:
        element = data.elements.new(type="ELLIPSOID")
        element.co = g2b(position)
        element.radius = 1.0
        # Scale values are radii in Godot space. Blender Y/Z are swapped.
        element.size_x = scale[0]
        element.size_y = scale[2]
        element.size_z = scale[1]
        element.stiffness = stiffness
    obj.data.materials.append(material)
    # The armature from the current build can remain selected. Conversion should
    # only target the new metaball, otherwise Blender reports harmless but noisy
    # unsupported-object warnings in the deterministic build log.
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.active_object
    obj.name = name
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def uv_sphere(
    name: str,
    position: tuple[float, float, float],
    scale: tuple[float, float, float],
    material: bpy.types.Material,
    hero: bool,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=20 if hero else 12,
        ring_count=12 if hero else 8,
        location=g2b(position),
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (scale[0], scale[2], scale[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def bone(edit_bones: bpy.types.ArmatureEditBones, name: str, head: tuple[float, float, float], tail: tuple[float, float, float], parent=None):
    result = edit_bones.new(name)
    result.head = g2b(head)
    result.tail = g2b(tail)
    result.parent = parent
    return result


def build_rig(species: str) -> bpy.types.Object:
    bpy.ops.object.armature_add(enter_editmode=True, location=(0.0, 0.0, 0.0))
    rig = bpy.context.active_object
    rig.name = "SpeciesSkeleton3D"
    rig.data.name = f"{species.title()}V3Rig"
    edit = rig.data.edit_bones
    root = edit[0]
    root.name = "Root"
    root.head = g2b((0.0, 0.05, 0.70))
    root.tail = g2b((0.0, 0.05, 1.20))

    if species == "rabbit":
        spine = bone(edit, "Spine", (0.0, 1.04, 0.86), (0.0, 1.10, -0.18), root)
        chest = bone(edit, "Chest", (0.0, 1.10, -0.18), (0.0, 1.24, -0.88), spine)
        neck = bone(edit, "Neck", (0.0, 1.24, -0.88), (0.0, 1.39, -1.30), chest)
        head = bone(edit, "Head", (0.0, 1.39, -1.30), (0.0, 1.35, -1.94), neck)
        leg_anchors = {
            "LF": ((-0.34, 1.02, -0.62), (-0.33, 0.57, -0.70), (-0.34, 0.20, -0.92)),
            "RF": ((0.34, 1.02, -0.62), (0.33, 0.57, -0.70), (0.34, 0.20, -0.92)),
            "LH": ((-0.46, 1.00, 0.62), (-0.50, 0.52, 0.42), (-0.50, 0.18, -0.02)),
            "RH": ((0.46, 1.00, 0.62), (0.50, 0.52, 0.42), (0.50, 0.18, -0.02)),
        }
        ear_anchors = {
            "L": ((-0.20, 1.59, -1.28), (-0.24, 2.70, -1.17)),
            "R": ((0.20, 1.59, -1.28), (0.24, 2.65, -1.18)),
        }
        tail_points = ((0.0, 1.15, 0.88), (0.0, 1.16, 1.42))
    else:
        spine = bone(edit, "Spine", (0.0, 1.25, 1.12), (0.0, 1.34, 0.10), root)
        chest = bone(edit, "Chest", (0.0, 1.34, 0.10), (0.0, 1.52, -0.72), spine)
        neck = bone(edit, "Neck", (0.0, 1.52, -0.72), (0.0, 1.68, -1.38), chest)
        head = bone(edit, "Head", (0.0, 1.68, -1.38), (0.0, 1.58, -2.38), neck)
        leg_anchors = {
            "LF": ((-0.47, 1.24, -0.57), (-0.48, 0.70, -0.68), (-0.48, 0.18, -0.87)),
            "RF": ((0.47, 1.24, -0.57), (0.48, 0.70, -0.68), (0.48, 0.18, -0.87)),
            "LH": ((-0.46, 1.18, 0.66), (-0.47, 0.68, 0.53), (-0.47, 0.18, 0.25)),
            "RH": ((0.46, 1.18, 0.66), (0.47, 0.68, 0.53), (0.47, 0.18, 0.25)),
        }
        ear_anchors = {
            "L": ((-0.27, 1.91, -1.43), (-0.31, 2.43, -1.34)),
            "R": ((0.27, 1.91, -1.43), (0.31, 2.43, -1.34)),
        }
        tail_points = ((0.0, 1.29, 1.08), (0.08, 0.83, 2.40))

    for suffix, (upper, joint, paw) in leg_anchors.items():
        upper_bone = bone(edit, f"Leg_{suffix}", upper, joint, chest if suffix.endswith("F") else spine)
        bone(edit, f"Paw_{suffix}", joint, paw, upper_bone)
    for suffix, points in ear_anchors.items():
        bone(edit, f"Ear_{suffix}", points[0], points[1], head)
    bone(edit, "Tail", tail_points[0], tail_points[1], spine)
    bpy.ops.object.mode_set(mode="OBJECT")
    rig["eco_species"] = species
    rig["eco_rig_family"] = "lagomorph_v3" if species == "rabbit" else "canid_v3"
    return rig


def add_armature_weights(obj: bpy.types.Object, rig: bpy.types.Object, weights: dict[str, list[float]]) -> None:
    world_transform = obj.matrix_world.copy()
    obj.parent = rig
    obj.matrix_world = world_transform
    modifier = obj.modifiers.new("SpeciesArmature", "ARMATURE")
    modifier.object = rig
    vertex_count = len(obj.data.vertices)
    for bone_name, values in weights.items():
        group = obj.vertex_groups.new(name=bone_name)
        for vertex_index, value in enumerate(values):
            if value > 0.001:
                group.add([vertex_index], value, "REPLACE")
    # Normalise explicitly so malformed authoring data can never amplify deformation.
    for vertex_index in range(vertex_count):
        total = sum(values[vertex_index] for values in weights.values())
        if total > 0.001 and not math.isclose(total, 1.0, abs_tol=0.001):
            for group in obj.vertex_groups:
                try:
                    current = group.weight(vertex_index)
                except RuntimeError:
                    continue
                group.add([vertex_index], current / total, "REPLACE")


def rigid_skin(obj: bpy.types.Object, rig: bpy.types.Object, bone_name: str) -> None:
    add_armature_weights(obj, rig, {bone_name: [1.0] * len(obj.data.vertices)})


def body_skin(obj: bpy.types.Object, rig: bpy.types.Object, species: str) -> None:
    anchors = {
        "rabbit": {"Spine": 0.48, "Chest": -0.35, "Neck": -0.96, "Head": -1.58},
        "wolf": {"Spine": 0.62, "Chest": -0.34, "Neck": -1.05, "Head": -1.82},
    }[species]
    body_names = ["Spine", "Chest", "Neck", "Head"]
    appendage_anchors = {
        "rabbit": {
            "Leg_LF": (-0.34, 0.79, -0.62, 0.32, 0.50, 0.34),
            "Leg_RF": (0.34, 0.79, -0.62, 0.32, 0.50, 0.34),
            "Leg_LH": (-0.45, 0.78, 0.57, 0.40, 0.53, 0.45),
            "Leg_RH": (0.45, 0.78, 0.57, 0.40, 0.53, 0.45),
            "Paw_LF": (-0.34, 0.27, -0.84, 0.28, 0.42, 0.40),
            "Paw_RF": (0.34, 0.27, -0.84, 0.28, 0.42, 0.40),
            "Paw_LH": (-0.49, 0.27, 0.08, 0.34, 0.43, 0.62),
            "Paw_RH": (0.49, 0.27, 0.08, 0.34, 0.43, 0.62),
            "Ear_L": (-0.23, 2.15, -1.25, 0.24, 0.75, 0.27),
            "Ear_R": (0.23, 2.15, -1.25, 0.24, 0.75, 0.27),
            "Tail": (0.0, 1.18, 1.30, 0.42, 0.42, 0.46),
        },
        "wolf": {
            "Leg_LF": (-0.47, 0.95, -0.58, 0.34, 0.55, 0.37),
            "Leg_RF": (0.47, 0.95, -0.58, 0.34, 0.55, 0.37),
            "Leg_LH": (-0.47, 0.92, 0.65, 0.34, 0.55, 0.37),
            "Leg_RH": (0.47, 0.92, 0.65, 0.34, 0.55, 0.37),
            "Paw_LF": (-0.48, 0.30, -0.74, 0.30, 0.49, 0.43),
            "Paw_RF": (0.48, 0.30, -0.74, 0.30, 0.49, 0.43),
            "Paw_LH": (-0.47, 0.30, 0.48, 0.30, 0.49, 0.43),
            "Paw_RH": (0.47, 0.30, 0.48, 0.30, 0.49, 0.43),
            "Ear_L": (-0.30, 2.19, -1.42, 0.28, 0.49, 0.27),
            "Ear_R": (0.30, 2.19, -1.42, 0.28, 0.49, 0.27),
            "Tail": (0.07, 1.02, 1.72, 0.40, 0.60, 0.78),
        },
    }[species]
    names = body_names + list(appendage_anchors)
    weights = {name: [] for name in names}
    for vertex in obj.data.vertices:
        godot_x = vertex.co.x
        godot_y = vertex.co.z
        godot_z = vertex.co.y
        raw: dict[str, float] = {}
        for name in body_names:
            distance = abs(godot_z - anchors[name])
            raw[name] = max(0.0, 1.0 - distance / (0.92 if name in ("Spine", "Chest") else 0.72)) ** 2
        for name, (anchor_x, anchor_y, anchor_z, range_x, range_y, range_z) in appendage_anchors.items():
            distance = math.sqrt(
                ((godot_x - anchor_x) / range_x) ** 2
                + ((godot_y - anchor_y) / range_y) ** 2
                + ((godot_z - anchor_z) / range_z) ** 2
            )
            raw[name] = max(0.0, 1.0 - distance) ** 2 * 5.5
        total = sum(raw.values())
        if total <= 0.0001:
            nearest = min(body_names, key=lambda item: abs(godot_z - anchors[item]))
            raw[nearest] = 1.0
            total = 1.0
        for name in names:
            weights[name].append(raw[name] / total)
    add_armature_weights(obj, rig, weights)


def attach_socket(name: str, position: tuple[float, float, float], rig: bpy.types.Object, bone_name: str) -> bpy.types.Object:
    socket = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(socket)
    socket.empty_display_type = "SPHERE"
    socket.empty_display_size = 0.08
    socket.parent = rig
    socket.parent_type = "BONE"
    socket.parent_bone = bone_name
    socket.matrix_world = Matrix.Translation(g2b(position))
    return socket


def build_parts(species: str, hero: bool, rig: bpy.types.Object) -> list[bpy.types.Object]:
    profile = "hero" if hero else "mobile"
    resolution = 0.045 if hero else 0.075
    if species == "rabbit":
        coat = pbr_material("rabbit_coat_pbr", (0.68, 0.72, 0.71, 1.0), 0.84)
        coat_light = pbr_material("rabbit_light_coat_pbr", (0.89, 0.88, 0.82, 1.0), 0.88)
        skin = pbr_material("rabbit_nose_pbr", (0.47, 0.28, 0.30, 1.0), 0.58)
        eye = pbr_material("rabbit_eye_pbr", (0.10, 0.055, 0.025, 1.0), 0.18)
        body_elements = [
            ((0.0, 1.04, 0.54), (0.70, 0.72, 0.88), 2.25),
            ((0.0, 1.13, -0.25), (0.58, 0.63, 0.70), 2.15),
            ((0.0, 1.29, -0.87), (0.45, 0.50, 0.48), 2.05),
            ((0.0, 1.42, -1.35), (0.43, 0.45, 0.50), 2.15),
            ((0.0, 1.32, -1.76), (0.34, 0.28, 0.42), 2.05),
        ]
        leg_data = {
            "LF": [((-0.34, 0.84, -0.62), (0.20, 0.42, 0.21), 2.1)],
            "RF": [((0.34, 0.84, -0.62), (0.20, 0.42, 0.21), 2.1)],
            "LH": [((-0.45, 0.78, 0.57), (0.34, 0.52, 0.40), 2.2)],
            "RH": [((0.45, 0.78, 0.57), (0.34, 0.52, 0.40), 2.2)],
        }
        paw_data = {
            "LF": [((-0.34, 0.39, -0.74), (0.16, 0.37, 0.18), 2.0), ((-0.34, 0.15, -0.94), (0.20, 0.13, 0.34), 2.0)],
            "RF": [((0.34, 0.39, -0.74), (0.16, 0.37, 0.18), 2.0), ((0.34, 0.15, -0.94), (0.20, 0.13, 0.34), 2.0)],
            "LH": [((-0.49, 0.38, 0.30), (0.22, 0.40, 0.25), 2.0), ((-0.49, 0.14, -0.11), (0.27, 0.14, 0.54), 2.0)],
            "RH": [((0.49, 0.38, 0.30), (0.22, 0.40, 0.25), 2.0), ((0.49, 0.14, -0.11), (0.27, 0.14, 0.54), 2.0)],
        }
        for suffix in LIMBS:
            body_elements.extend(leg_data[suffix])
            body_elements.extend(paw_data[suffix])
            side = -1.0 if suffix.startswith("L") else 1.0
            front = suffix.endswith("F")
            leg_z = -0.68 if front else 0.42
            body_elements.extend([
                ((side * (0.30 if front else 0.39), 0.96, leg_z), (0.34 if front else 0.42, 0.35, 0.38), 2.1),
                ((side * (0.34 if front else 0.49), 0.34, -0.82 if front else 0.12), (0.23 if front else 0.31, 0.28, 0.38 if front else 0.50), 2.0),
            ])
        for side in (-1.0, 1.0):
            body_elements.extend([
                ((side * 0.21, 1.88, -1.31), (0.20, 0.48, 0.18), 2.0),
                ((side * 0.24, 2.42, -1.22), (0.15, 0.45, 0.12), 2.0),
            ])
        body_elements.append(((0.0, 1.18, 1.32), (0.34, 0.34, 0.37), 2.2))
        body = metaball_mesh("RabbitOrganicBodyV2", body_elements, coat, resolution)
        body_skin(body, rig, species)
        parts = [body]
        for suffix, side in (("L", -1.0), ("R", 1.0)):
            if hero:
                inner = uv_sphere(f"InnerEarDetail_{suffix}", (side * 0.245, 2.16, -1.34), (0.105, 0.48, 0.045), skin, hero)
                rigid_skin(inner, rig, f"Ear_{suffix}")
                parts.append(inner)
        chest = uv_sphere("ChestRuffDetail", (0.0, 1.14, -0.76), (0.40, 0.44, 0.16), coat_light, hero)
        rigid_skin(chest, rig, "Chest")
        parts.append(chest)
        nose = uv_sphere("NoseDetail", (0.0, 1.33, -2.13), (0.13, 0.09, 0.10), skin, hero)
        rigid_skin(nose, rig, "Head")
        parts.append(nose)
        for side in (-1.0, 1.0):
            eyeball = uv_sphere(f"EyeDetail_{'L' if side < 0 else 'R'}", (side * 0.305, 1.52, -1.67), (0.095, 0.105, 0.075), eye, hero)
            rigid_skin(eyeball, rig, "Head")
            parts.append(eyeball)
        attach_socket("SkillSocket_Mouth", (0.0, 1.34, -2.19), rig, "Head")
        attach_socket("SkillSocket_Chest", (0.0, 1.20, -0.47), rig, "Chest")
        return parts

    coat = pbr_material("wolf_coat_pbr", (0.27, 0.31, 0.33, 1.0), 0.82)
    dark = pbr_material("wolf_dark_coat_pbr", (0.075, 0.09, 0.095, 1.0), 0.86)
    light = pbr_material("wolf_light_coat_pbr", (0.55, 0.56, 0.53, 1.0), 0.84)
    skin = pbr_material("wolf_nose_pbr", (0.035, 0.045, 0.047, 1.0), 0.30)
    eye = pbr_material("wolf_eye_pbr", (0.62, 0.31, 0.055, 1.0), 0.16)
    body_elements = [
        ((0.0, 1.28, 0.68), (0.64, 0.66, 0.86), 2.2),
        ((0.0, 1.42, -0.08), (0.73, 0.75, 0.76), 2.2),
        ((0.0, 1.55, -0.75), (0.61, 0.70, 0.66), 2.15),
        ((0.0, 1.72, -1.35), (0.51, 0.51, 0.54), 2.1),
        ((0.0, 1.63, -1.88), (0.40, 0.34, 0.54), 2.05),
        ((0.0, 1.55, -2.28), (0.27, 0.23, 0.40), 2.0),
    ]
    for suffix in LIMBS:
        side = -1.0 if suffix.startswith("L") else 1.0
        front = suffix.endswith("F")
        z = -0.57 if front else 0.66
        body_elements.extend([
            ((side * 0.47, 0.96, z), (0.24, 0.43, 0.25), 2.1),
            ((side * 0.48, 0.46, z - (0.08 if front else 0.10)), (0.19, 0.38, 0.18), 2.0),
            ((side * 0.48, 0.14, z - 0.24), (0.24, 0.13, 0.34), 2.0),
            ((side * 0.39, 1.18, z), (0.42, 0.40, 0.42), 2.1),
            ((side * 0.48, 0.34, z - (0.16 if front else 0.12)), (0.25, 0.28, 0.38), 2.0),
        ])
    for side in (-1.0, 1.0):
        body_elements.extend([
            ((side * 0.28, 2.05, -1.46), (0.24, 0.32, 0.17), 2.0),
            ((side * 0.31, 2.32, -1.39), (0.15, 0.30, 0.11), 2.0),
        ])
    body_elements.extend([
            ((0.0, 1.23, 1.25), (0.31, 0.30, 0.42), 2.0),
            ((0.03, 1.12, 1.49), (0.30, 0.29, 0.42), 2.0),
            ((0.06, 1.02, 1.72), (0.27, 0.27, 0.48), 2.0),
            ((0.09, 0.90, 1.95), (0.24, 0.24, 0.40), 2.0),
            ((0.11, 0.79, 2.17), (0.19, 0.20, 0.43), 2.0),
    ])
    body = metaball_mesh("WolfOrganicBodyV2", body_elements, coat, resolution)
    body_skin(body, rig, species)
    parts = [body]
    chest = uv_sphere("ChestRuffDetail", (0.0, 1.36, -0.86), (0.56, 0.61, 0.25), light, hero)
    rigid_skin(chest, rig, "Chest")
    parts.append(chest)
    nose = uv_sphere("NoseDetail", (0.0, 1.55, -2.69), (0.18, 0.13, 0.14), skin, hero)
    rigid_skin(nose, rig, "Head")
    parts.append(nose)
    for side in (-1.0, 1.0):
        eyeball = uv_sphere(f"EyeDetail_{'L' if side < 0 else 'R'}", (side * 0.30, 1.83, -1.95), (0.090, 0.100, 0.070), eye, hero)
        rigid_skin(eyeball, rig, "Head")
        parts.append(eyeball)
    attach_socket("SkillSocket_Mouth", (0.0, 1.56, -2.72), rig, "Head")
    attach_socket("SkillSocket_Chest", (0.0, 1.46, -0.55), rig, "Chest")
    return parts


def create_actions(rig: bpy.types.Object, species: str) -> None:
    rig.animation_data_create()
    for action_name in ACTIONS:
        action = bpy.data.actions.new(action_name)
        rig.animation_data.action = action
        for pose_bone in rig.pose.bones:
            pose_bone.rotation_mode = "XYZ"
            pose_bone.rotation_euler = (0.0, 0.0, 0.0)
            pose_bone.keyframe_insert(data_path="rotation_euler", frame=1, group=pose_bone.name)
        frames = (1, 9, 17, 25, 33)
        if action_name in ("locomotion", "sprint"):
            cycle_frames = (1, 5, 9, 13, 17, 21, 25, 29, 33)
            amount = (0.62 if action_name == "locomotion" else 0.92) if species == "rabbit" else (0.42 if action_name == "locomotion" else 0.70)
            for frame_index, frame in enumerate(cycle_frames):
                phase = math.tau * frame_index / (len(cycle_frames) - 1)
                for index, suffix in enumerate(LIMBS):
                    upper = rig.pose.bones[f"Leg_{suffix}"]
                    lower = rig.pose.bones[f"Paw_{suffix}"]
                    if species == "rabbit":
                        is_hind = suffix.endswith("H")
                        curve = math.sin(phase + (0.0 if is_hind else math.pi * 0.78))
                        upper.rotation_euler[0] = amount * curve * (1.0 if is_hind else 0.66)
                        lower.rotation_euler[0] = -amount * (0.62 if is_hind else 0.38) * max(curve, -0.18)
                    else:
                        diagonal_phase = 0.0 if index in (0, 3) else math.pi
                        curve = math.sin(phase + diagonal_phase)
                        upper.rotation_euler[0] = amount * curve
                        lower.rotation_euler[0] = -amount * 0.52 * max(curve, -0.22)
                    upper.keyframe_insert(data_path="rotation_euler", frame=frame, group=upper.name)
                    lower.keyframe_insert(data_path="rotation_euler", frame=frame, group=lower.name)
                rig.pose.bones["Spine"].rotation_euler[0] = (0.10 if species == "rabbit" else 0.045) * math.cos(phase)
                rig.pose.bones["Chest"].rotation_euler[0] = -(0.07 if species == "rabbit" else 0.028) * math.cos(phase)
                rig.pose.bones["Spine"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Spine")
                rig.pose.bones["Chest"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Chest")
        elif action_name == "attack":
            for frame, curve in zip((1, 8, 18), (0.0, 1.0, 0.0)):
                rig.pose.bones["Chest"].rotation_euler[0] = (-0.12 if species == "rabbit" else -0.24) * curve
                rig.pose.bones["Head"].rotation_euler[0] = (0.12 if species == "rabbit" else 0.24) * curve
                for suffix in ("LF", "RF"):
                    rig.pose.bones[f"Leg_{suffix}"].rotation_euler[0] = (-0.38 if species == "rabbit" else -0.68) * curve
                for name in ("Chest", "Head", "Leg_LF", "Leg_RF"):
                    rig.pose.bones[name].keyframe_insert(data_path="rotation_euler", frame=frame, group=name)
        elif action_name == "skill":
            for frame, curve in zip((1, 10, 22), (0.0, 1.0, 0.0)):
                rig.pose.bones["Spine"].rotation_euler[0] = (-0.44 if species == "rabbit" else -0.28) * curve
                for suffix in ("LH", "RH"):
                    rig.pose.bones[f"Leg_{suffix}"].rotation_euler[0] = (1.02 if species == "rabbit" else 0.78) * curve
                    rig.pose.bones[f"Paw_{suffix}"].rotation_euler[0] = (-0.72 if species == "rabbit" else -0.50) * curve
                for name in ("Spine", "Leg_LH", "Leg_RH", "Paw_LH", "Paw_RH"):
                    rig.pose.bones[name].keyframe_insert(data_path="rotation_euler", frame=frame, group=name)
        elif action_name == "hit":
            for frame, curve in zip((1, 6, 15), (0.0, 1.0, 0.0)):
                rig.pose.bones["Spine"].rotation_euler[2] = 0.26 * curve
                rig.pose.bones["Spine"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Spine")
        elif action_name == "eat":
            for frame, curve in zip(frames, (0.0, 1.0, 0.0)):
                rig.pose.bones["Neck"].rotation_euler[0] = 0.56 * curve
                rig.pose.bones["Head"].rotation_euler[0] = 0.30 * curve
                rig.pose.bones["Neck"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Neck")
                rig.pose.bones["Head"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Head")
        elif action_name == "death":
            for frame, curve in zip((1, 18, 32), (0.0, 0.75, 1.0)):
                rig.pose.bones["Spine"].rotation_euler[2] = 1.22 * curve
                rig.pose.bones["Spine"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Spine")
        elif action_name == "idle":
            for frame, curve in zip(frames, (-1.0, 0.25, 1.0, -0.20, -1.0)):
                rig.pose.bones["Chest"].rotation_euler[0] = 0.018 * curve
                rig.pose.bones["Chest"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Chest")
                ear_amount = (0.13 if species == "rabbit" else 0.07) * curve
                rig.pose.bones["Ear_L"].rotation_euler[1] = ear_amount
                rig.pose.bones["Ear_R"].rotation_euler[1] = -ear_amount * 0.55
                rig.pose.bones["Tail"].rotation_euler[1] = (0.035 if species == "rabbit" else 0.11) * curve
                for name in ("Ear_L", "Ear_R", "Tail"):
                    rig.pose.bones[name].keyframe_insert(data_path="rotation_euler", frame=frame, group=name)
        action.use_fake_user = True
    rig.animation_data.action = bpy.data.actions["idle"]


def mesh_island_count(obj: bpy.types.Object) -> int:
    vertex_count = len(obj.data.vertices)
    if vertex_count == 0:
        return 0
    adjacency = [[] for _ in range(vertex_count)]
    for edge in obj.data.edges:
        first, second = edge.vertices
        adjacency[first].append(second)
        adjacency[second].append(first)
    remaining = set(range(vertex_count))
    islands = 0
    while remaining:
        islands += 1
        stack = [remaining.pop()]
        while stack:
            vertex_index = stack.pop()
            for neighbour in adjacency[vertex_index]:
                if neighbour in remaining:
                    remaining.remove(neighbour)
                    stack.append(neighbour)
    return islands


def export_species(species: str, hero: bool, output_root: Path) -> tuple[int, int, int]:
    reset_scene()
    rig = build_rig(species)
    parts = build_parts(species, hero, rig)
    create_actions(rig, species)
    organic_body = next(obj for obj in parts if obj.name.endswith("OrganicBodyV2"))
    island_count = mesh_island_count(organic_body)
    if island_count != 1:
        raise RuntimeError(f"{species}: OrganicBodyV2 has {island_count} disconnected mesh islands")
    profile = "hero" if hero else "mobile"
    output = output_root / species / f"{species}_{profile}.glb"
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
    triangles = sum(len(obj.data.loop_triangles) or (obj.data.calc_loop_triangles() or len(obj.data.loop_triangles)) for obj in parts)
    vertices = sum(len(obj.data.vertices) for obj in parts)
    if not output.is_file() or output.stat().st_size < 4096:
        raise RuntimeError(f"failed to export {output}")
    return triangles, vertices, len(rig.data.bones)


def main() -> None:
    args = parse_args()
    output_root = Path(args.output_root).resolve()
    for species in ("rabbit", "wolf"):
        for hero in (True, False):
            triangles, vertices, bones = export_species(species, hero, output_root)
            print(
                f"VERTICAL_SLICE_MODEL_OK: {species} / {'hero' if hero else 'mobile'} / "
                f"{triangles} triangles / {vertices} vertices / {bones} bones"
            )


if __name__ == "__main__":
    main()
