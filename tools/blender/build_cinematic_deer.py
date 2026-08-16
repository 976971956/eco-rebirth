from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Quaternion, Vector


ACTIONS = ("idle", "locomotion", "sprint", "attack", "skill", "hit", "eat", "death")
SOURCE_BASENAME = "doe.blend"
SOURCE_SHA256 = "577b9e48ce7cee955c6dac1b0a70333eccdfcad3f11eaa1f96a15900b64ca25e"
ANATOMY_SCALE = 0.46
GROUND_OFFSET = 0.02
RUNTIME_BONES = {
    "Root", "Spine", "Chest", "Neck", "Head", "Jaw",
    "Leg_LF", "Lower_LF", "Paw_LF", "Leg_RF", "Lower_RF", "Paw_RF",
    "Leg_LH", "Lower_LH", "Paw_LH", "Leg_RH", "Lower_RH", "Paw_RH",
    "Ear_L", "Ear_R", "Tail", "TailTip",
}


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description="Build the authored CC0 cinematic forest deer")
    parser.add_argument("--source-dir", required=True)
    parser.add_argument("--output-root", required=True)
    return parser.parse_args(argv)


def clear_source_animation(rig: bpy.types.Object) -> None:
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


def load_source(source_dir: Path) -> tuple[bpy.types.Object, bpy.types.Object, bpy.types.Object, bpy.types.Object]:
    source_file = source_dir / SOURCE_BASENAME
    if not source_file.is_file():
        raise RuntimeError(f"missing CC0 deer source: {source_file}")
    bpy.ops.wm.open_mainfile(filepath=str(source_file))
    rig = bpy.data.objects.get("Armature")
    body = bpy.data.objects.get("Body")
    head = bpy.data.objects.get("Head")
    eyes = bpy.data.objects.get("Eyes")
    if rig is None or rig.type != "ARMATURE":
        raise RuntimeError("CC0 deer source is missing Armature")
    if any(obj is None or obj.type != "MESH" for obj in (body, head, eyes)):
        raise RuntimeError("CC0 deer source is missing Body, Head or Eyes")
    active = bpy.context.view_layer.objects.active
    if active is not None and active.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for obj in list(bpy.context.scene.objects):
        if obj not in (rig, body, head, eyes):
            bpy.data.objects.remove(obj, do_unlink=True)
    clear_source_animation(rig)
    rig.name = "SpeciesSkeleton3D"
    rig.data.name = "DeerCinematicSkeleton"
    rig["species_id"] = "deer"
    rig["rig_version"] = 6
    rig["skin_mode"] = "cc0_weighted_cinematic"
    rig["locomotion_profile"] = "cervid_four_beat_and_gallop"
    rig["source_sha256"] = SOURCE_SHA256
    return rig, body, head, eyes


def normalized_position(position: Vector, ground_translation: float) -> Vector:
    return Vector(
        (
            position.x * ANATOMY_SCALE,
            position.y * ANATOMY_SCALE,
            position.z * ANATOMY_SCALE + ground_translation,
        )
    )


def normalize_anatomy(rig: bpy.types.Object, meshes: tuple[bpy.types.Object, ...]) -> None:
    source_minimum_z = min((mesh.matrix_world @ vertex.co).z for mesh in meshes for vertex in mesh.data.vertices)
    ground_translation = GROUND_OFFSET - source_minimum_z * ANATOMY_SCALE
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
    rig["anatomy_profile"] = "authored_red_deer_adult_stag_v1"


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
    # The source Main group only carries root-adjacent body weights; move those
    # to the deforming pelvis before Root becomes a control-only bone. Merge the
    # extra short shoulder vertebra into Chest to keep the 22-bone contract.
    for mesh in meshes:
        transfer_vertex_group(mesh, "Main", "Hip")
        transfer_vertex_group(mesh, "Backbone.001", "Backbone")

    renames = {
        "Main": "Root",
        "Hip": "Spine",
        "Backbone": "Chest",
        "Backbone.002": "Neck",
        "Head": "Head",
        "Head_L.001": "Ear_L",
        "Head_R.001": "Ear_R",
        "Frontleg_L": "Leg_LF",
        "Frontleg_L.001": "Lower_LF",
        "Frontleg_L.002": "Paw_LF",
        "Frontleg_R": "Leg_RF",
        "Frontleg_R.001": "Lower_RF",
        "Frontleg_R.002": "Paw_RF",
        "Backleg_L": "Leg_LH",
        "Backleg_L.001": "Lower_LH",
        "Backleg_L.002": "Paw_LH",
        "Backleg_R": "Leg_RH",
        "Backleg_R.001": "Lower_RH",
        "Backleg_R.002": "Paw_RH",
    }
    for source_name, target_name in renames.items():
        bone = rig.data.bones.get(source_name)
        if bone is None:
            raise RuntimeError(f"missing deer runtime bone mapping: {source_name}")
        bone.name = target_name

    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    bones = rig.data.edit_bones
    for bone in list(bones):
        if bone.name not in RUNTIME_BONES:
            bones.remove(bone)

    head = bones.get("Head")
    spine = bones.get("Spine")
    if head is None or spine is None:
        raise RuntimeError("deer head or spine missing while adding runtime details")
    jaw = bones.new("Jaw")
    jaw.head = Vector((0.0, -1.56, 2.10))
    jaw.tail = Vector((0.0, -1.88, 2.01))
    jaw.parent = head
    jaw.use_connect = False
    jaw.use_deform = False
    tail = bones.new("Tail")
    tail.head = Vector((0.0, 0.49, 1.72))
    tail.tail = Vector((0.0, 0.73, 1.80))
    tail.parent = spine
    tail.use_connect = False
    tail_tip = bones.new("TailTip")
    tail_tip.head = tail.tail
    tail_tip.tail = Vector((0.0, 0.94, 1.69))
    tail_tip.parent = tail
    tail_tip.use_connect = False

    parent_contract = {
        "Spine": "Root", "Chest": "Spine", "Neck": "Chest", "Head": "Neck", "Jaw": "Head",
        "Ear_L": "Head", "Ear_R": "Head", "Tail": "Spine", "TailTip": "Tail",
        "Leg_LF": "Chest", "Lower_LF": "Leg_LF", "Paw_LF": "Lower_LF",
        "Leg_RF": "Chest", "Lower_RF": "Leg_RF", "Paw_RF": "Lower_RF",
        "Leg_LH": "Spine", "Lower_LH": "Leg_LH", "Paw_LH": "Lower_LH",
        "Leg_RH": "Spine", "Lower_RH": "Leg_RH", "Paw_RH": "Lower_RH",
    }
    for child_name, parent_name in parent_contract.items():
        child = bones.get(child_name)
        parent = bones.get(parent_name)
        if child is None or parent is None:
            raise RuntimeError(f"deer parent contract is missing {child_name} -> {parent_name}")
        child.parent = parent
        child.use_connect = False
    bones["Root"].use_deform = False
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.select_set(False)

    for mesh in meshes:
        for group in list(mesh.vertex_groups):
            if group.name not in RUNTIME_BONES:
                mesh.vertex_groups.remove(group)
    if len(rig.data.bones) != 22 or set(bone.name for bone in rig.data.bones) != RUNTIME_BONES:
        raise RuntimeError(f"deer runtime rig is not the 22-bone contract: {len(rig.data.bones)}")


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
            nearest_name = min(
                ("Spine", "Chest", "Neck", "Head"),
                key=lambda name: (vertex.co - rig.data.bones[name].head_local.lerp(rig.data.bones[name].tail_local, 0.5)).length,
            )
            nearest = mesh.vertex_groups.get(nearest_name)
            if nearest is None:
                nearest = mesh.vertex_groups.new(name=nearest_name)
            nearest.add([vertex.index], 1.0, "REPLACE")
            continue
        for group, weight in retained:
            group.add([vertex.index], min(max(weight / total, 0.0), 1.0), "REPLACE")


def packed_image(name: str, texture_size: int) -> bpy.types.Image:
    image = bpy.data.images.get(name)
    if image is None or image.size[0] <= 0 or image.size[1] <= 0:
        raise RuntimeError(f"missing packed deer image: {name}")
    image.colorspace_settings.name = "sRGB"
    if image.size[0] != texture_size or image.size[1] != texture_size:
        image.scale(texture_size, texture_size)
    image.pack()
    return image


def textured_material(name: str, image: bpy.types.Image, roughness: float) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.diffuse_color = (0.52, 0.31, 0.17, 1.0)
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    principled = nodes.get("Principled BSDF")
    if principled is None:
        raise RuntimeError("Blender did not create a Principled BSDF node")
    principled.inputs["Roughness"].default_value = roughness
    if "Specular IOR Level" in principled.inputs:
        principled.inputs["Specular IOR Level"].default_value = 0.28
    albedo = nodes.new("ShaderNodeTexImage")
    albedo.image = image
    albedo.interpolation = "Linear"
    links.new(albedo.outputs["Color"], principled.inputs["Base Color"])
    material["eco_pbr_surface"] = "cc0_authored_red_deer"
    material["source_sha256"] = SOURCE_SHA256
    return material


def solid_material(name: str, color: tuple[float, float, float, float], roughness: float) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.diffuse_color = color
    principled = material.node_tree.nodes.get("Principled BSDF")
    if principled is not None:
        principled.inputs["Base Color"].default_value = color
        principled.inputs["Roughness"].default_value = roughness
    material["eco_pbr_surface"] = "cc0_authored_red_deer"
    return material


def replace_material(mesh: bpy.types.Object, material: bpy.types.Material) -> None:
    while mesh.data.materials:
        mesh.data.materials.pop(index=0)
    mesh.data.materials.append(material)
    for polygon in mesh.data.polygons:
        polygon.material_index = 0
        polygon.use_smooth = True


def add_hero_subdivision(mesh: bpy.types.Object) -> None:
    modifier = mesh.modifiers.new("HeroSubdivision", "SUBSURF")
    modifier.subdivision_type = "CATMULL_CLARK"
    modifier.levels = 1
    modifier.render_levels = 1
    mesh.modifiers.move(len(mesh.modifiers) - 1, 0)
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    mesh.select_set(False)


def add_antler_branch(
    name: str,
    start: Vector,
    end: Vector,
    start_radius: float,
    end_radius: float,
    material: bpy.types.Material,
    rig: bpy.types.Object,
    hero: bool,
) -> bpy.types.Object:
    direction = end - start
    bpy.ops.mesh.primitive_cone_add(
        vertices=12 if hero else 8,
        radius1=start_radius,
        radius2=end_radius,
        depth=direction.length,
        location=start.lerp(end, 0.5),
    )
    branch = bpy.context.object
    branch.name = name
    branch.data.name = f"{name}Mesh"
    branch.rotation_euler = direction.normalized().to_track_quat("Z", "Y").to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    branch.data.materials.append(material)
    for polygon in branch.data.polygons:
        polygon.use_smooth = True
    world_matrix = branch.matrix_world.copy()
    branch.parent = rig
    branch.parent_type = "BONE"
    branch.parent_bone = "Head"
    branch.matrix_world = world_matrix
    return branch


def add_authored_antlers(rig: bpy.types.Object, material: bpy.types.Material, hero: bool) -> list[bpy.types.Object]:
    branches: list[bpy.types.Object] = []
    for side, suffix in ((-1.0, "L"), (1.0, "R")):
        base = Vector((side * 0.19, -1.51, 2.34))
        p1 = Vector((side * 0.24, -1.37, 2.62))
        p2 = Vector((side * 0.31, -1.17, 2.86))
        p3 = Vector((side * 0.39, -0.94, 3.08))
        segments = [
            (base, p1, 0.070, 0.058),
            (p1, p2, 0.058, 0.047),
            (p2, p3, 0.047, 0.024),
            (p1, Vector((side * 0.41, -1.53, 2.81)), 0.040, 0.014),
            (p2, Vector((side * 0.51, -1.20, 3.08)), 0.035, 0.012),
            (p3, Vector((side * 0.49, -0.79, 3.28)), 0.030, 0.010),
        ]
        if not hero:
            segments = segments[:5]
        for index, (start, end, radius1, radius2) in enumerate(segments):
            branches.append(
                add_antler_branch(
                    f"DeerAntlerBranchDetail_{suffix}_{index + 1}",
                    start,
                    end,
                    radius1,
                    radius2,
                    material,
                    rig,
                    hero,
                )
            )
    return branches


def attach_socket(name: str, world_position: Vector, rig: bpy.types.Object, bone_name: str) -> None:
    socket = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(socket)
    socket.empty_display_type = "SPHERE"
    socket.empty_display_size = 0.08
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


def set_armature_axis_rotation(pose_bone: bpy.types.PoseBone, axis: Vector, angle: float) -> None:
    rest_rotation = pose_bone.bone.matrix_local.to_quaternion()
    local_axis = rest_rotation.inverted() @ axis
    local_axis.normalize()
    pose_bone.rotation_euler = Quaternion(local_axis, angle).to_euler("XYZ")


def key_sagittal(rig: bpy.types.Object, bone_name: str, frame: int, angle: float) -> None:
    pose_bone = rig.pose.bones[bone_name]
    set_armature_axis_rotation(pose_bone, Vector((1.0, 0.0, 0.0)), angle)
    pose_bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=bone_name)


def key_roll(rig: bpy.types.Object, bone_name: str, frame: int, angle: float) -> None:
    pose_bone = rig.pose.bones[bone_name]
    set_armature_axis_rotation(pose_bone, Vector((0.0, 1.0, 0.0)), angle)
    pose_bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=bone_name)


def limb_flex_sign(rig: bpy.types.Object, suffix: str) -> float:
    upper = rig.data.bones[f"Leg_{suffix}"]
    lower = rig.data.bones[f"Lower_{suffix}"]
    upper_vector = (upper.tail_local - upper.head_local).normalized()
    lower_vector = (lower.tail_local - lower.head_local).normalized()
    signed_angle = math.atan2(Vector((1.0, 0.0, 0.0)).dot(upper_vector.cross(lower_vector)), upper_vector.dot(lower_vector))
    if abs(signed_angle) < 0.035:
        return 1.0 if suffix.endswith("F") else -1.0
    return 1.0 if signed_angle >= 0.0 else -1.0


def create_actions(rig: bpy.types.Object) -> None:
    bpy.context.scene.render.fps = 30
    rig.animation_data_create()
    flex_signs = {suffix: limb_flex_sign(rig, suffix) for suffix in ("LF", "RF", "LH", "RH")}
    for action_name in ACTIONS:
        action = bpy.data.actions.new(action_name)
        rig.animation_data.action = action
        reset_pose(rig)
        for pose_bone in rig.pose.bones:
            pose_bone.keyframe_insert(data_path="rotation_euler", frame=1, group=pose_bone.name)

        if action_name in ("locomotion", "sprint"):
            phases = (
                {"LF": 0.0, "RH": math.pi * 0.5, "RF": math.pi, "LH": math.pi * 1.5}
                if action_name == "locomotion"
                else {"LF": math.pi * 1.10, "RF": math.pi * 0.90, "LH": math.pi * 0.10, "RH": 0.0}
            )
            stride = 0.34 if action_name == "locomotion" else 0.66
            flex = 0.46 if action_name == "locomotion" else 0.74
            for frame in (1, 5, 9, 13, 17, 21, 25, 29, 33):
                cycle = math.tau * (frame - 1) / 32.0
                for suffix in ("LF", "RF", "LH", "RH"):
                    phase = phases[suffix]
                    swing = math.sin(cycle + phase)
                    lift = max(0.0, math.sin(cycle + phase - 0.34))
                    support = max(0.0, -math.sin(cycle + phase - 0.34))
                    rear_gain = 1.08 if suffix.endswith("H") else 1.0
                    key_sagittal(rig, f"Leg_{suffix}", frame, stride * swing * rear_gain)
                    key_sagittal(rig, f"Lower_{suffix}", frame, flex_signs[suffix] * flex * (0.94 * lift + 0.08 * support) * rear_gain)
                    key_sagittal(rig, f"Paw_{suffix}", frame, -flex_signs[suffix] * flex * (0.42 * lift + 0.05 * support) * rear_gain)
                wave = math.sin(cycle * (2.0 if action_name == "sprint" else 1.0))
                key_sagittal(rig, "Spine", frame, 0.030 * wave)
                key_sagittal(rig, "Chest", frame, -0.038 * wave)
                key_sagittal(rig, "Neck", frame, 0.026 * wave)
                key_sagittal(rig, "Head", frame, -0.018 * wave)
                key_roll(rig, "Tail", frame, -0.055 * math.sin(cycle))
                key_roll(rig, "TailTip", frame, -0.085 * math.sin(cycle))
        elif action_name == "idle":
            for frame, breath in ((1, -1.0), (11, 0.2), (21, 1.0), (31, -1.0)):
                key_sagittal(rig, "Chest", frame, 0.018 * breath)
                key_sagittal(rig, "Neck", frame, -0.012 * breath)
                key_roll(rig, "Ear_L", frame, 0.055 * breath)
                key_roll(rig, "Ear_R", frame, -0.035 * breath)
        elif action_name in ("attack", "skill"):
            strength = 1.0 if action_name == "attack" else 1.30
            for frame, brace, strike in ((1, 0.0, 0.0), (7, 1.0, -0.20), (12, 0.55, 1.0), (22, 0.0, 0.0)):
                key_sagittal(rig, "Spine", frame, -0.10 * brace * strength)
                key_sagittal(rig, "Chest", frame, -0.15 * brace * strength)
                key_sagittal(rig, "Neck", frame, 0.30 * strike * strength)
                key_sagittal(rig, "Head", frame, 0.34 * strike * strength)
                key_sagittal(rig, "Leg_LF", frame, -0.18 * brace)
                key_sagittal(rig, "Leg_RF", frame, -0.18 * brace)
        elif action_name == "hit":
            for frame, curve in ((1, 0.0), (5, 1.0), (14, 0.0)):
                key_roll(rig, "Spine", frame, 0.22 * curve)
                key_roll(rig, "Neck", frame, -0.14 * curve)
                key_roll(rig, "Head", frame, -0.18 * curve)
        elif action_name == "eat":
            for frame, lower, chew in ((1, 0.0, 0.0), (10, 0.72, 0.0), (18, 1.0, 1.0), (25, 1.0, -1.0), (34, 0.0, 0.0)):
                key_sagittal(rig, "Chest", frame, -0.18 * lower)
                key_sagittal(rig, "Neck", frame, -0.72 * lower)
                key_sagittal(rig, "Head", frame, 0.42 * lower + 0.05 * chew)
                key_sagittal(rig, "Jaw", frame, -0.08 * abs(chew) * lower)
        elif action_name == "death":
            for frame, fall in ((1, 0.0), (12, 0.30), (23, 0.82), (34, 1.0)):
                key_roll(rig, "Spine", frame, 1.26 * fall)
                key_roll(rig, "Chest", frame, 0.22 * fall)
                key_sagittal(rig, "Neck", frame, 0.20 * fall)
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
    rig, body, head, eyes = load_source(source_dir)
    meshes = (body, head, eyes)
    normalize_anatomy(rig, meshes)
    rebuild_runtime_rig(rig, meshes)
    for mesh in meshes:
        normalize_runtime_weights(mesh, rig)

    texture_size = 512 if hero else 256
    materials = {
        "body": textured_material("deer_cinematic_body_coat_pbr", packed_image("doe-body", texture_size), 0.84),
        "head": textured_material("deer_cinematic_head_accent_pbr", packed_image("doe-head", texture_size), 0.82),
        "eye": solid_material("deer_cinematic_eye_pbr", (0.035, 0.024, 0.016, 1.0), 0.16),
        "antler": solid_material("deer_cinematic_antler_keratin_pbr", (0.30, 0.22, 0.14, 1.0), 0.68),
    }
    replace_material(body, materials["body"])
    replace_material(head, materials["head"])
    replace_material(eyes, materials["eye"])
    body.name = "DeerOrganicBodyV2_SourceConnected"
    body.data.name = "DeerOrganicBodyV2SourceMesh"
    head.name = "DeerHeadSourceSilhouette"
    eyes.name = "DeerEyeSourceDetail"
    if hero:
        add_hero_subdivision(body)
        add_hero_subdivision(head)
        # Subdivision interpolates every source vertex group and can recreate
        # a fifth tiny influence even when the control cage was normalized.
        # Re-apply the runtime limit before glTF export on the final topology.
        normalize_runtime_weights(body, rig)
        normalize_runtime_weights(head, rig)
    antlers = add_authored_antlers(rig, materials["antler"], hero)
    attach_socket("SkillSocket_Mouth", Vector((0.0, -1.93, 1.98)), rig, "Head")
    attach_socket("SkillSocket_Chest", Vector((0.0, -0.66, 1.48)), rig, "Chest")
    create_actions(rig)

    profile = "hero" if hero else "mobile"
    output = output_root / "deer" / f"deer_{profile}.glb"
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
    triangles, vertices = evaluated_stats([body, head, eyes, *antlers])
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
        print(f"CINEMATIC_DEER_OK: {profile} / {triangles} triangles / {vertices} vertices / {bones} bones")


if __name__ == "__main__":
    main()
