from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Quaternion, Vector


ACTIONS = ("idle", "locomotion", "sprint", "attack", "skill", "hit", "eat", "death")
SOURCE_BASENAME = "rabbit.blend"
ANATOMY_SCALE = Vector((0.13, 0.17, 0.15))
GROUND_OFFSET = 0.02
RUNTIME_BONES = {
    "Root",
    "Spine_Rear",
    "Spine",
    "Chest",
    "Neck",
    "Head",
    "Jaw",
    "Leg_LF",
    "Lower_LF",
    "Paw_LF",
    "Leg_RF",
    "Lower_RF",
    "Paw_RF",
    "Leg_LH",
    "Lower_LH",
    "Paw_LH",
    "Leg_RH",
    "Lower_RH",
    "Paw_RH",
    "Ear_L",
    "Ear_R",
    "Tail",
}


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description="Build the CC0 cinematic snow rabbit for Eco Rebirth")
    parser.add_argument("--source-dir", required=True)
    parser.add_argument("--output-root", required=True)
    return parser.parse_args(argv)


def clear_pose_and_source_actions(rig: bpy.types.Object) -> None:
    if rig.animation_data is not None:
        rig.animation_data_clear()
    rig.data.pose_position = "POSE"
    for pose_bone in rig.pose.bones:
        for constraint in list(pose_bone.constraints):
            pose_bone.constraints.remove(constraint)
        pose_bone.rotation_mode = "XYZ"
        pose_bone.rotation_euler = (0.0, 0.0, 0.0)
        pose_bone.location = (0.0, 0.0, 0.0)
        pose_bone.scale = (1.0, 1.0, 1.0)
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)


def load_source(source_dir: Path) -> tuple[bpy.types.Object, bpy.types.Object, bpy.types.Object]:
    source_file = source_dir / SOURCE_BASENAME
    if not source_file.is_file():
        raise RuntimeError(f"missing CC0 rabbit source: {source_file}")
    bpy.ops.wm.open_mainfile(filepath=str(source_file))
    rig = bpy.data.objects.get("Armature")
    body = bpy.data.objects.get("Rabbit")
    fur = bpy.data.objects.get("Fur")
    if rig is None or rig.type != "ARMATURE" or body is None or body.type != "MESH" or fur is None or fur.type != "MESH":
        raise RuntimeError("CC0 rabbit source is missing Armature, Rabbit or Fur")
    for obj in list(bpy.context.scene.objects):
        if obj not in (rig, body, fur):
            bpy.data.objects.remove(obj, do_unlink=True)
    clear_pose_and_source_actions(rig)
    rig.name = "SpeciesSkeleton3D"
    rig.data.name = "RabbitCinematicSkeleton"
    rig["species_id"] = "rabbit"
    rig["rig_version"] = 6
    rig["skin_mode"] = "cc0_weighted_cinematic"
    rig["locomotion_profile"] = "lagomorph_pair_bound"
    rig["source_sha256"] = "bb6deef1ee91b21380355138374cae87946451ce864502b1af68eb60f4750843"
    return rig, body, fur


def normalized_position(position: Vector, ground_translation: float) -> Vector:
    return Vector(
        (
            position.x * ANATOMY_SCALE.x,
            position.y * ANATOMY_SCALE.y,
            position.z * ANATOMY_SCALE.z + ground_translation,
        )
    )


def normalize_anatomy(rig: bpy.types.Object, meshes: tuple[bpy.types.Object, ...]) -> None:
    source_minimum_z = min((mesh.matrix_world @ vertex.co).z for mesh in meshes for vertex in mesh.data.vertices)
    ground_translation = GROUND_OFFSET - source_minimum_z * ANATOMY_SCALE.z
    for mesh in meshes:
        inverse_world = mesh.matrix_world.inverted()
        for vertex in mesh.data.vertices:
            vertex.co = inverse_world @ normalized_position(mesh.matrix_world @ vertex.co, ground_translation)
        mesh.data.update()

    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    inverse_world = rig.matrix_world.inverted()
    endpoints = {
        bone.name: (rig.matrix_world @ bone.head.copy(), rig.matrix_world @ bone.tail.copy())
        for bone in rig.data.edit_bones
    }
    for bone in rig.data.edit_bones:
        bone.use_connect = False
    for bone in rig.data.edit_bones:
        head, tail = endpoints[bone.name]
        bone.head = inverse_world @ normalized_position(head, ground_translation)
        bone.tail = inverse_world @ normalized_position(tail, ground_translation)
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.select_set(False)
    rig["anatomy_profile"] = "authored_european_rabbit_crouched_v1"


def transfer_vertex_group(mesh: bpy.types.Object, source_name: str, target_name: str) -> None:
    source = mesh.vertex_groups.get(source_name)
    if source is None:
        return
    target = mesh.vertex_groups.get(target_name)
    if target is None:
        target = mesh.vertex_groups.new(name=target_name)
    weights: list[tuple[int, float]] = []
    for vertex in mesh.data.vertices:
        for membership in vertex.groups:
            if membership.group == source.index:
                weights.append((vertex.index, membership.weight))
                break
    for vertex_index, weight in weights:
        target.add([vertex_index], weight, "ADD")
    mesh.vertex_groups.remove(source)


def rebuild_runtime_rig(rig: bpy.types.Object, meshes: tuple[bpy.types.Object, ...]) -> None:
    for mesh in meshes:
        transfer_vertex_group(mesh, "BackLeg_L.001", "BackLeg_L")
        transfer_vertex_group(mesh, "BackLeg_R.001", "BackLeg_R")

    renames = {
        "Main": "Root",
        "Hips": "Spine_Rear",
        "Spine.001": "Chest",
        "FrontUpLeg_L": "Leg_LF",
        "FrontLeg_L": "Lower_LF",
        "FrontPaw_L": "Paw_LF",
        "FrontUpLeg_R": "Leg_RF",
        "FrontLeg_R": "Lower_RF",
        "FrontPaw_R": "Paw_RF",
        "BackUpLeg_L": "Leg_LH",
        "BackLeg_L": "Lower_LH",
        "BackPaw_L": "Paw_LH",
        "BackUpLeg_R": "Leg_RH",
        "BackLeg_R": "Lower_RH",
        "BackPaw_R": "Paw_RH",
    }
    for source_name, target_name in renames.items():
        bone = rig.data.bones.get(source_name)
        if bone is None:
            raise RuntimeError(f"missing rabbit runtime bone mapping: {source_name}")
        bone.name = target_name

    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    bones = rig.data.edit_bones
    for bone in list(bones):
        if bone.name not in RUNTIME_BONES:
            bones.remove(bone)
    if bones.get("Jaw") is None:
        head = bones.get("Head")
        if head is None:
            raise RuntimeError("rabbit head bone missing while adding Jaw")
        jaw = bones.new("Jaw")
        jaw.head = head.head.lerp(head.tail, 0.42) + Vector((0.0, -0.025, -0.075))
        jaw.tail = jaw.head + Vector((0.0, -0.18, -0.055))
        jaw.parent = head
        jaw.use_deform = False

    parent_contract = {
        "Spine_Rear": "Root",
        "Spine": "Spine_Rear",
        "Chest": "Spine",
        "Neck": "Chest",
        "Head": "Neck",
        "Jaw": "Head",
        "Ear_L": "Head",
        "Ear_R": "Head",
        "Tail": "Spine_Rear",
        "Leg_LF": "Chest",
        "Lower_LF": "Leg_LF",
        "Paw_LF": "Lower_LF",
        "Leg_RF": "Chest",
        "Lower_RF": "Leg_RF",
        "Paw_RF": "Lower_RF",
        "Leg_LH": "Spine_Rear",
        "Lower_LH": "Leg_LH",
        "Paw_LH": "Lower_LH",
        "Leg_RH": "Spine_Rear",
        "Lower_RH": "Leg_RH",
        "Paw_RH": "Lower_RH",
    }
    for child_name, parent_name in parent_contract.items():
        child = bones.get(child_name)
        parent = bones.get(parent_name)
        if child is None or parent is None:
            raise RuntimeError(f"rabbit parent contract is missing {child_name} -> {parent_name}")
        child.parent = parent
        child.use_connect = False
    bones["Root"].use_deform = False
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.select_set(False)
    if len(rig.data.bones) != 22 or set(bone.name for bone in rig.data.bones) != RUNTIME_BONES:
        raise RuntimeError(f"rabbit runtime rig is not the 22-bone contract: {len(rig.data.bones)}")


def normalize_runtime_weights(mesh: bpy.types.Object, rig: bpy.types.Object) -> None:
    deform_names = {bone.name for bone in rig.data.bones if bone.use_deform}
    group_by_index = {group.index: group for group in mesh.vertex_groups if group.name in deform_names}
    for vertex in mesh.data.vertices:
        influences = [
            (group_by_index[membership.group], membership.weight)
            for membership in vertex.groups
            if membership.group in group_by_index and membership.weight > 0.000001
        ]
        influences.sort(key=lambda item: item[1], reverse=True)
        retained = influences[:4]
        for group, _weight in influences[4:]:
            group.remove([vertex.index])
        total = sum(weight for _group, weight in retained)
        if total <= 0.000001:
            raise RuntimeError(f"rabbit vertex {vertex.index} has no runtime skin weight")
        for group, weight in retained:
            group.add([vertex.index], min(max(weight / total, 0.0), 1.0), "REPLACE")


def packed_image(name: str, texture_size: int, colorspace: str) -> bpy.types.Image:
    image = bpy.data.images.get(name)
    if image is None or image.size[0] <= 0 or image.size[1] <= 0:
        raise RuntimeError(f"missing packed rabbit image: {name}")
    image.colorspace_settings.name = colorspace
    if image.size[0] != texture_size or image.size[1] != texture_size:
        image.scale(texture_size, texture_size)
    image.pack()
    return image


def textured_material(
    name: str,
    albedo: bpy.types.Image,
    normal: bpy.types.Image | None,
    roughness: float,
    tint: tuple[float, float, float, float],
    alpha: bool = False,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.diffuse_color = tint
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    principled = nodes.get("Principled BSDF")
    if principled is None:
        raise RuntimeError("Blender did not create a Principled BSDF node")
    principled.inputs["Base Color"].default_value = tint
    principled.inputs["Roughness"].default_value = roughness
    albedo_node = nodes.new("ShaderNodeTexImage")
    albedo_node.name = f"{name}_albedo"
    albedo_node.image = albedo
    links.new(albedo_node.outputs["Color"], principled.inputs["Base Color"])
    if alpha:
        links.new(albedo_node.outputs["Alpha"], principled.inputs["Alpha"])
        try:
            material.surface_render_method = "DITHERED"
        except (AttributeError, TypeError):
            pass
    if normal is not None:
        normal_node = nodes.new("ShaderNodeTexImage")
        normal_node.name = f"{name}_normal"
        normal_node.image = normal
        normal_map = nodes.new("ShaderNodeNormalMap")
        normal_map.inputs["Strength"].default_value = 0.68
        links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
        links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])
    return material


def solid_material(name: str, color: tuple[float, float, float, float], roughness: float) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.diffuse_color = color
    principled = material.node_tree.nodes.get("Principled BSDF")
    if principled is not None:
        principled.inputs["Base Color"].default_value = color
        principled.inputs["Roughness"].default_value = roughness
    return material


def build_materials(texture_size: int) -> dict[str, bpy.types.Material]:
    body_albedo = packed_image("rabbot-skinn", texture_size, "sRGB")
    fur_albedo = packed_image("Fur-skin", texture_size, "sRGB")
    normal = packed_image("rabbit-NORM", texture_size, "Non-Color")
    return {
        "body": textured_material("rabbit_cinematic_body_coat_pbr", body_albedo, normal, 0.78, (0.62, 0.53, 0.43, 1.0)),
        "fur": textured_material("rabbit_cinematic_fur_detail_pbr", fur_albedo, None, 0.86, (0.66, 0.58, 0.49, 1.0), True),
        "ear": solid_material("rabbit_cinematic_inner_ear_accent_pbr", (0.56, 0.31, 0.29, 1.0), 0.74),
    }


def replace_material(obj: bpy.types.Object, material: bpy.types.Material) -> None:
    while obj.data.materials:
        obj.data.materials.pop(index=0)
    obj.data.materials.append(material)


def add_hero_subdivision(body: bpy.types.Object) -> None:
    modifier = body.modifiers.new("HeroSubdivision", "SUBSURF")
    modifier.subdivision_type = "CATMULL_CLARK"
    modifier.levels = 1
    modifier.render_levels = 1
    body.modifiers.move(len(body.modifiers) - 1, 0)
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    body.select_set(False)


def join_authored_coat(body: bpy.types.Object, fur: bpy.types.Object) -> bpy.types.Object:
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    fur.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    body = bpy.context.active_object
    body.name = "RabbitOrganicBodyV2_SourceConnected"
    body.data.name = "RabbitOrganicBodyV2Mesh"
    body.data.validate(verbose=True, clean_customdata=False)
    for polygon in body.data.polygons:
        polygon.use_smooth = True
    return body


def add_bone_detail_ellipsoid(
    name: str,
    position: Vector,
    scale: Vector,
    material: bpy.types.Material,
    rig: bpy.types.Object,
    bone_name: str,
    hero: bool,
    direction: Vector | None = None,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=16 if hero else 10,
        ring_count=10 if hero else 6,
        location=position,
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.name = f"{name}Mesh"
    obj.scale = scale
    if direction is not None and direction.length_squared > 0.000001:
        obj.rotation_euler = direction.normalized().to_track_quat("Z", "Y").to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    world_matrix = obj.matrix_world.copy()
    obj.parent = rig
    obj.parent_type = "BONE"
    obj.parent_bone = bone_name
    obj.matrix_world = world_matrix
    return obj


def add_authored_details(rig: bpy.types.Object, materials: dict[str, bpy.types.Material], hero: bool) -> list[bpy.types.Object]:
    details: list[bpy.types.Object] = []
    for side, bone_name in (("L", "Ear_L"), ("R", "Ear_R")):
        bone = rig.data.bones[bone_name]
        center = bone.head_local.lerp(bone.tail_local, 0.57) + Vector((0.0, -0.018, 0.0))
        direction = bone.tail_local - bone.head_local
        details.append(
            add_bone_detail_ellipsoid(
                f"V5RabbitInnerEarDetail_{side}",
                center,
                Vector((0.105, 0.024, direction.length * 0.34)),
                materials["ear"],
                rig,
                bone_name,
                hero,
                direction,
            )
        )
    return details


def attach_socket(name: str, world_position: Vector, rig: bpy.types.Object, bone_name: str) -> None:
    socket = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(socket)
    socket.empty_display_type = "SPHERE"
    socket.empty_display_size = 0.07
    socket.parent = rig
    socket.parent_type = "BONE"
    socket.parent_bone = bone_name
    socket.matrix_world = Matrix.Translation(world_position)


def reset_pose(rig: bpy.types.Object) -> None:
    for pose_bone in rig.pose.bones:
        pose_bone.rotation_mode = "XYZ"
        pose_bone.rotation_euler = (0.0, 0.0, 0.0)
        pose_bone.location = (0.0, 0.0, 0.0)
        pose_bone.scale = (1.0, 1.0, 1.0)


def set_armature_axis_rotation(pose_bone: bpy.types.PoseBone, rotations: tuple[tuple[Vector, float], ...]) -> None:
    rest_rotation = pose_bone.bone.matrix_local.to_quaternion()
    result = Quaternion()
    for armature_axis, angle in rotations:
        local_axis = rest_rotation.inverted() @ armature_axis
        local_axis.normalize()
        result = result @ Quaternion(local_axis, angle)
    pose_bone.rotation_euler = result.to_euler("XYZ")


def set_sagittal_rotation(pose_bone: bpy.types.PoseBone, angle: float) -> None:
    set_armature_axis_rotation(pose_bone, ((Vector((1.0, 0.0, 0.0)), angle),))


def set_roll_rotation(pose_bone: bpy.types.PoseBone, angle: float) -> None:
    set_armature_axis_rotation(pose_bone, ((Vector((0.0, 1.0, 0.0)), angle),))


def key_rotation(rig: bpy.types.Object, bone_name: str, frame: int) -> None:
    rig.pose.bones[bone_name].keyframe_insert(data_path="rotation_euler", frame=frame, group=bone_name)


def create_actions(rig: bpy.types.Object) -> None:
    bpy.context.scene.render.fps = 30
    rig.animation_data_create()
    limbs = {
        "LF": ("Leg_LF", "Lower_LF", "Paw_LF"),
        "RF": ("Leg_RF", "Lower_RF", "Paw_RF"),
        "LH": ("Leg_LH", "Lower_LH", "Paw_LH"),
        "RH": ("Leg_RH", "Lower_RH", "Paw_RH"),
    }
    for action_name in ACTIONS:
        action = bpy.data.actions.new(action_name)
        rig.animation_data.action = action
        reset_pose(rig)
        for pose_bone in rig.pose.bones:
            pose_bone.keyframe_insert(data_path="rotation_euler", frame=1, group=pose_bone.name)

        if action_name in ("locomotion", "sprint"):
            bound_amount = 0.46 if action_name == "locomotion" else 0.78
            for index, frame in enumerate((1, 5, 9, 13, 17, 21, 25, 29, 33)):
                phase = math.tau * index / 8.0
                for suffix, (upper_name, lower_name, paw_name) in limbs.items():
                    is_hind = suffix.endswith("H")
                    side_delay = 0.08 if suffix in ("RF", "RH") else -0.08
                    stride = math.sin(phase + (0.0 if is_hind else math.pi) + side_delay)
                    swing = max(stride, 0.0)
                    recovery = max(-stride, 0.0)
                    upper_amount = bound_amount * (1.20 if is_hind else 0.74)
                    set_sagittal_rotation(rig.pose.bones[upper_name], -upper_amount * stride)
                    if is_hind:
                        set_sagittal_rotation(rig.pose.bones[lower_name], 0.20 * recovery + (0.92 if action_name == "locomotion" else 1.24) * swing)
                        set_sagittal_rotation(rig.pose.bones[paw_name], -0.16 * recovery - (0.56 if action_name == "locomotion" else 0.78) * swing)
                    else:
                        set_sagittal_rotation(rig.pose.bones[lower_name], -0.12 * recovery - (0.58 if action_name == "locomotion" else 0.82) * swing)
                        set_sagittal_rotation(rig.pose.bones[paw_name], 0.10 * recovery + (0.36 if action_name == "locomotion" else 0.52) * swing)
                    for bone_name in (upper_name, lower_name, paw_name):
                        key_rotation(rig, bone_name, frame)
                compression = math.cos(phase) * (0.065 if action_name == "locomotion" else 0.115)
                set_sagittal_rotation(rig.pose.bones["Spine"], compression)
                set_sagittal_rotation(rig.pose.bones["Chest"], -compression * 0.82)
                set_sagittal_rotation(rig.pose.bones["Neck"], compression * 0.32)
                set_sagittal_rotation(rig.pose.bones["Head"], -compression * 0.24)
                set_sagittal_rotation(rig.pose.bones["Ear_L"], 0.10 + compression * 1.7)
                set_sagittal_rotation(rig.pose.bones["Ear_R"], 0.12 + compression * 1.5)
                set_sagittal_rotation(rig.pose.bones["Tail"], -0.10 - compression * 0.8)
                for bone_name in ("Spine", "Chest", "Neck", "Head", "Ear_L", "Ear_R", "Tail"):
                    key_rotation(rig, bone_name, frame)
        elif action_name == "idle":
            for frame, curve in zip((1, 9, 17, 25, 33), (0.0, 1.0, 0.0, -1.0, 0.0)):
                set_sagittal_rotation(rig.pose.bones["Chest"], 0.018 * curve)
                set_sagittal_rotation(rig.pose.bones["Neck"], -0.012 * curve)
                set_armature_axis_rotation(rig.pose.bones["Ear_L"], ((Vector((1.0, 0.0, 0.0)), 0.035 * curve), (Vector((0.0, 0.0, 1.0)), 0.030 * curve)))
                set_armature_axis_rotation(rig.pose.bones["Ear_R"], ((Vector((1.0, 0.0, 0.0)), -0.025 * curve), (Vector((0.0, 0.0, 1.0)), -0.026 * curve)))
                set_roll_rotation(rig.pose.bones["Head"], 0.012 * curve)
                for bone_name in ("Chest", "Neck", "Head", "Ear_L", "Ear_R"):
                    key_rotation(rig, bone_name, frame)
        elif action_name == "attack":
            for frame, curve in zip((1, 5, 9, 15, 22), (0.0, -0.28, 1.0, 0.48, 0.0)):
                set_sagittal_rotation(rig.pose.bones["Spine"], -0.26 * curve)
                set_sagittal_rotation(rig.pose.bones["Chest"], -0.32 * curve)
                set_sagittal_rotation(rig.pose.bones["Neck"], 0.18 * curve)
                set_sagittal_rotation(rig.pose.bones["Head"], -0.10 * curve)
                set_sagittal_rotation(rig.pose.bones["Leg_LF"], -0.58 * curve)
                set_sagittal_rotation(rig.pose.bones["Lower_LF"], -0.62 * max(curve, 0.0))
                set_sagittal_rotation(rig.pose.bones["Paw_LF"], 0.42 * max(curve, 0.0))
                for bone_name in ("Spine", "Chest", "Neck", "Head", "Leg_LF", "Lower_LF", "Paw_LF"):
                    key_rotation(rig, bone_name, frame)
        elif action_name == "skill":
            for frame, curve in zip((1, 8, 15, 23, 31), (0.0, -0.30, 1.0, 0.62, 0.0)):
                set_sagittal_rotation(rig.pose.bones["Spine_Rear"], -0.34 * curve)
                set_sagittal_rotation(rig.pose.bones["Spine"], -0.46 * curve)
                set_sagittal_rotation(rig.pose.bones["Chest"], 0.24 * curve)
                for suffix in ("LH", "RH"):
                    set_sagittal_rotation(rig.pose.bones[f"Leg_{suffix}"], -0.88 * curve)
                    set_sagittal_rotation(rig.pose.bones[f"Lower_{suffix}"], 1.08 * curve)
                    set_sagittal_rotation(rig.pose.bones[f"Paw_{suffix}"], -0.62 * curve)
                    for prefix in ("Leg", "Lower", "Paw"):
                        key_rotation(rig, f"{prefix}_{suffix}", frame)
                for bone_name in ("Spine_Rear", "Spine", "Chest"):
                    key_rotation(rig, bone_name, frame)
        elif action_name == "hit":
            for frame, curve in zip((1, 6, 14), (0.0, 1.0, 0.0)):
                set_roll_rotation(rig.pose.bones["Spine"], 0.24 * curve)
                set_roll_rotation(rig.pose.bones["Chest"], -0.17 * curve)
                set_roll_rotation(rig.pose.bones["Head"], -0.15 * curve)
                for bone_name in ("Spine", "Chest", "Head"):
                    key_rotation(rig, bone_name, frame)
        elif action_name == "eat":
            for frame, dip, chew in zip((1, 8, 15, 22, 30), (0.0, 1.0, 0.82, 1.0, 0.0), (0.0, 0.08, 0.24, 0.10, 0.0)):
                set_sagittal_rotation(rig.pose.bones["Chest"], -0.22 * dip)
                set_sagittal_rotation(rig.pose.bones["Neck"], -0.62 * dip)
                set_sagittal_rotation(rig.pose.bones["Head"], 0.38 * dip + chew)
                set_sagittal_rotation(rig.pose.bones["Jaw"], -0.28 * chew)
                for bone_name in ("Chest", "Neck", "Head", "Jaw"):
                    key_rotation(rig, bone_name, frame)
        elif action_name == "death":
            for frame, curve in zip((1, 15, 30), (0.0, 0.72, 1.0)):
                set_roll_rotation(rig.pose.bones["Spine_Rear"], 1.34 * curve)
                set_roll_rotation(rig.pose.bones["Spine"], 0.22 * curve)
                set_sagittal_rotation(rig.pose.bones["Neck"], 0.18 * curve)
                for bone_name in ("Spine_Rear", "Spine", "Neck"):
                    key_rotation(rig, bone_name, frame)
        action.use_fake_user = True
    rig.animation_data.action = bpy.data.actions["idle"]


def evaluated_stats(objects: list[bpy.types.Object]) -> tuple[int, int]:
    depsgraph = bpy.context.evaluated_depsgraph_get()
    triangles = 0
    vertices = 0
    for obj in objects:
        evaluated = obj.evaluated_get(depsgraph)
        evaluated_mesh = evaluated.to_mesh()
        evaluated_mesh.calc_loop_triangles()
        triangles += len(evaluated_mesh.loop_triangles)
        vertices += len(evaluated_mesh.vertices)
        evaluated.to_mesh_clear()
    return triangles, vertices


def export_profile(source_dir: Path, output_root: Path, hero: bool) -> tuple[int, int, int]:
    rig, body, fur = load_source(source_dir)
    normalize_anatomy(rig, (body, fur))
    rebuild_runtime_rig(rig, (body, fur))
    materials = build_materials(512 if hero else 256)
    replace_material(body, materials["body"])
    replace_material(fur, materials["fur"])
    if hero:
        add_hero_subdivision(body)
    normalize_runtime_weights(body, rig)
    normalize_runtime_weights(fur, rig)
    coat = join_authored_coat(body, fur)
    details = add_authored_details(rig, materials, hero)
    attach_socket("SkillSocket_Mouth", Vector((0.0, -1.96, 1.29)), rig, "Head")
    attach_socket("SkillSocket_Chest", Vector((0.0, -0.76, 1.20)), rig, "Chest")
    create_actions(rig)

    profile = "hero" if hero else "mobile"
    output = output_root / "rabbit" / f"rabbit_{profile}.glb"
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
    triangles, vertices = evaluated_stats([coat, *details])
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
        print(f"CINEMATIC_RABBIT_OK: {profile} / {triangles} triangles / {vertices} vertices / {bones} bones")


if __name__ == "__main__":
    main()
