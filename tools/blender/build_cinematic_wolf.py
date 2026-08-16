from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Quaternion, Vector


ACTIONS = ("idle", "locomotion", "sprint", "attack", "skill", "hit", "eat", "death")
SOURCE_BASENAME = "dog2.blend"
LEG_HEIGHT_SCALE = 0.90
LEG_COMPRESSION_TOP = 1.72


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description="Build the CC0 cinematic wolf sample for Eco Rebirth")
    parser.add_argument("--source-dir", required=True)
    parser.add_argument("--output-root", required=True)
    return parser.parse_args(argv)


def load_source(source_dir: Path) -> tuple[bpy.types.Object, bpy.types.Object]:
    source_file = source_dir / SOURCE_BASENAME
    if not source_file.is_file():
        raise RuntimeError(f"missing CC0 wolf source: {source_file}")
    bpy.ops.wm.open_mainfile(filepath=str(source_file))
    rig = bpy.data.objects.get("Armature")
    mesh = bpy.data.objects.get("dog2")
    if rig is None or rig.type != "ARMATURE" or mesh is None or mesh.type != "MESH":
        raise RuntimeError("CC0 wolf source is missing its Armature or dog2 mesh")
    for obj in list(bpy.context.scene.objects):
        if obj not in (rig, mesh):
            bpy.data.objects.remove(obj, do_unlink=True)
    # Godot's existing-rig detector accepts a Skeleton3D directly or the
    # imported armature wrapper carrying this stable contract name.
    rig.name = "SpeciesSkeleton3D"
    rig.data.name = "WolfCinematicSkeleton"
    rig["species_id"] = "wolf"
    rig["rig_version"] = 5
    rig["skin_mode"] = "cc0_weighted_cinematic"
    rig["locomotion_profile"] = "canid_diagonal_trot"
    return rig, mesh


def pbr_material(source_dir: Path, texture_size: int) -> bpy.types.Material:
    material = bpy.data.materials.new("wolf_cinematic_coat_pbr")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    principled = nodes.get("Principled BSDF")
    if principled is None:
        raise RuntimeError("Blender did not create a Principled BSDF node")
    principled.inputs["Roughness"].default_value = 0.72
    principled.inputs["Base Color"].default_value = (0.72, 0.75, 0.76, 1.0)

    def texture_node(node_name: str, filename: str, colorspace: str) -> bpy.types.ShaderNodeTexImage:
        texture_path = source_dir / filename
        if not texture_path.is_file():
            raise RuntimeError(f"missing wolf texture: {texture_path}")
        image = bpy.data.images.load(str(texture_path), check_existing=True)
        image.colorspace_settings.name = colorspace
        if image.size[0] != texture_size or image.size[1] != texture_size:
            image.scale(texture_size, texture_size)
        image.pack()
        node = nodes.new("ShaderNodeTexImage")
        node.name = node_name
        node.image = image
        node.extension = "REPEAT"
        return node

    albedo = texture_node("AIGrayWolfAlbedo", "dog2Color.png", "sRGB")
    roughness = texture_node("WolfRoughness", "dog2Roughness.png", "Non-Color")
    normal = texture_node("WolfNormal", "dog2Normal.png", "Non-Color")
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = 0.62
    links.new(albedo.outputs["Color"], principled.inputs["Base Color"])
    links.new(roughness.outputs["Color"], principled.inputs["Roughness"])
    links.new(normal.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])
    material.diffuse_color = (0.72, 0.75, 0.76, 1.0)
    return material


def _smoothstep(edge_start: float, edge_end: float, value: float) -> float:
    if edge_start == edge_end:
        return 0.0
    amount = max(0.0, min(1.0, (value - edge_start) / (edge_end - edge_start)))
    return amount * amount * (3.0 - 2.0 * amount)


def _interval_weight(value: float, start: float, fade_in: float, fade_out: float, end: float) -> float:
    return _smoothstep(start, fade_in, value) * (1.0 - _smoothstep(fade_out, end, value))


def add_adult_wolf_mass(mesh: bpy.types.Object) -> None:
    """Strengthen the source dog's silhouette without scaling its face or legs.

    The CC0 source has useful anatomy and skinning, but its ribcage and waist read
    like a very light domestic dog at the game's camera distance.  Deforming in
    world space lets the profile masks stay independent of the source object's
    legacy -90 degree import rotation.
    """

    inverse_world = mesh.matrix_world.inverted()
    for vertex in mesh.data.vertices:
        world = mesh.matrix_world @ vertex.co
        body_height = _interval_weight(world.z, 0.82, 1.18, 2.40, 2.82)
        neck_height = _interval_weight(world.z, 1.42, 1.70, 2.52, 2.86)
        shoulder = _interval_weight(world.y, -1.02, -0.72, -0.12, 0.22) * body_height
        ribcage = _interval_weight(world.y, -0.58, -0.22, 0.58, 0.92) * body_height
        waist = _interval_weight(world.y, 0.34, 0.62, 0.94, 1.18) * body_height
        haunch = _interval_weight(world.y, 0.72, 0.98, 1.56, 1.88) * body_height
        neck = _interval_weight(world.y, -1.42, -1.14, -0.58, -0.34) * neck_height

        # Wolves keep a visible waist; the chest, neck and hindquarters carry
        # most of the extra volume instead of applying a generic wide scale.
        width_gain = 0.24 * shoulder + 0.19 * ribcage + 0.09 * waist + 0.18 * haunch + 0.13 * neck
        world.x *= 1.0 + width_gain

        depth_mass = max(shoulder, ribcage * 0.82, haunch * 0.68, neck * 0.45)
        if depth_mass > 0.0:
            chest_center = 1.72
            world.z = chest_center + (world.z - chest_center) * (1.0 + 0.075 * depth_mass)
        vertex.co = inverse_world @ world
    mesh.data.update()
    mesh["anatomy_profile"] = "adult_gray_wolf_balanced_mass_v2"


def _shortened_leg_world_position(position: Vector) -> Vector:
    shortened = position.copy()
    if shortened.z > 0.0:
        shortened.z = min(shortened.z, LEG_COMPRESSION_TOP) * LEG_HEIGHT_SCALE + max(
            shortened.z - LEG_COMPRESSION_TOP,
            0.0,
        )
    return shortened


def shorten_leg_proportions(rig: bpy.types.Object, mesh: bpy.types.Object) -> None:
    """Shorten the leg chain and matching skin while keeping paws grounded.

    Vertices and edit-bone endpoints use the same piecewise world-space map.
    The upper body is translated downward by the accumulated compression, so
    torso/head length and gameplay-facing forward scale stay unchanged.
    """

    inverse_mesh_world = mesh.matrix_world.inverted()
    for vertex in mesh.data.vertices:
        vertex.co = inverse_mesh_world @ _shortened_leg_world_position(mesh.matrix_world @ vertex.co)
    mesh.data.update()

    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    inverse_rig_world = rig.matrix_world.inverted()
    original_endpoints = {
        bone.name: (
            rig.matrix_world @ bone.head.copy(),
            rig.matrix_world @ bone.tail.copy(),
            bone.use_connect,
        )
        for bone in rig.data.edit_bones
    }
    # Connected edit bones propagate endpoint writes through their hierarchy.
    # Temporarily disconnect the cached rest pose so every joint is compressed
    # exactly once instead of recursively lengthening child chains.
    for bone in rig.data.edit_bones:
        bone.use_connect = False
    for bone in rig.data.edit_bones:
        head_world, tail_world, _was_connected = original_endpoints[bone.name]
        bone.head = inverse_rig_world @ _shortened_leg_world_position(head_world)
        bone.tail = inverse_rig_world @ _shortened_leg_world_position(tail_world)
    for bone in rig.data.edit_bones:
        bone.use_connect = bool(original_endpoints[bone.name][2])
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.select_set(False)
    rig["leg_height_scale"] = LEG_HEIGHT_SCALE
    rig["proportion_profile"] = "adult_gray_wolf_shorter_articulated_legs_v3"


def detail_materials(coat: bpy.types.Material) -> list[bpy.types.Material]:
    materials: list[bpy.types.Material] = []
    for slot_name, tint in (
        ("detail", (0.76, 0.77, 0.76, 1.0)),
        ("eye", (0.76, 0.67, 0.42, 1.0)),
        ("paw", (0.66, 0.64, 0.60, 1.0)),
    ):
        material = coat.copy()
        material.name = f"wolf_cinematic_{slot_name}_pbr"
        material.diffuse_color = tint
        copied_principled = material.node_tree.nodes.get("Principled BSDF") if material.node_tree is not None else None
        if copied_principled is not None:
            copied_principled.inputs["Base Color"].default_value = tint
        materials.append(material)
    return materials


def merge_terminal_toe_weights(mesh: bpy.types.Object) -> None:
    transfers = {
        "b_LeftHand03": "b_LeftHand02",
        "b_RightHand03": "b_RightHand02",
        "b_LeftFoot03": "b_LeftFoot02",
        "b_RightFoot03": "b_RightFoot02",
    }
    for source_name, target_name in transfers.items():
        source = mesh.vertex_groups.get(source_name)
        target = mesh.vertex_groups.get(target_name)
        if source is None or target is None:
            raise RuntimeError(f"missing toe weight groups: {source_name} -> {target_name}")
        weighted_vertices: list[tuple[int, float]] = []
        for vertex in mesh.data.vertices:
            for membership in vertex.groups:
                if membership.group == source.index:
                    weighted_vertices.append((vertex.index, membership.weight))
                    break
        for vertex_index, weight in weighted_vertices:
            target.add([vertex_index], weight, "ADD")
        mesh.vertex_groups.remove(source)


def remove_terminal_toe_bones(rig: bpy.types.Object) -> None:
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for bone_name in ("b_LeftHand03", "b_RightHand03", "b_LeftFoot03", "b_RightFoot03"):
        bone = rig.data.edit_bones.get(bone_name)
        if bone is None:
            raise RuntimeError(f"missing terminal toe bone: {bone_name}")
        rig.data.edit_bones.remove(bone)
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.select_set(False)


def rename_articulated_paw_bones(rig: bpy.types.Object, mesh: bpy.types.Object) -> None:
    renames = {
        "b_LeftHand01": "Paw_LF",
        "b_RightHand01": "Paw_RF",
        "b_LeftFoot01": "Paw_LH",
        "b_RightFoot01": "Paw_RH",
    }
    for old_name, new_name in renames.items():
        bone = rig.data.bones.get(old_name)
        if bone is None:
            raise RuntimeError(f"missing articulated paw mapping: {old_name}")
        bone.name = new_name
        # Blender normally propagates an armature-bone rename to the matching
        # child mesh group. Keep a deterministic fallback for older files.
        vertex_group = mesh.vertex_groups.get(new_name)
        if vertex_group is None:
            vertex_group = mesh.vertex_groups.get(old_name)
            if vertex_group is None:
                raise RuntimeError(f"missing articulated paw weight group: {old_name}")
            vertex_group.name = new_name


def split_body_and_details(
    mesh: bpy.types.Object,
    coat_material: bpy.types.Material,
    detail_slots: list[bpy.types.Material],
) -> list[bpy.types.Object]:
    for old_material in list(mesh.data.materials):
        mesh.data.materials.pop(index=0)
    mesh.data.materials.append(coat_material)
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    parts = [obj for obj in bpy.context.selected_objects if obj.type == "MESH"]
    if len(parts) < 2:
        raise RuntimeError("wolf source did not expose separable body/detail islands")
    body = max(parts, key=lambda obj: len(obj.data.vertices))
    body.name = "WolfOrganicBodyV2_SourceConnected"
    body.data.name = "WolfOrganicBodyV2Mesh"
    details = sorted((obj for obj in parts if obj != body), key=lambda obj: len(obj.data.vertices), reverse=True)
    if len(details) < len(detail_slots):
        raise RuntimeError("wolf source does not contain enough independent detail islands")
    grouped_details: list[bpy.types.Object] = []
    group_names = ("WolfFaceDetail", "WolfEyeDetail", "WolfPawDetail")
    for group_index, (group_name, group_material) in enumerate(zip(group_names, detail_slots)):
        group = details[group_index::len(detail_slots)]
        bpy.ops.object.select_all(action="DESELECT")
        for detail in group:
            while detail.data.materials:
                detail.data.materials.pop(index=0)
            detail.data.materials.append(group_material)
            detail.select_set(True)
        bpy.context.view_layer.objects.active = group[0]
        bpy.ops.object.join()
        detail_mesh = bpy.context.active_object
        detail_mesh.name = group_name
        detail_mesh.data.name = f"{group_name}Mesh"
        grouped_details.append(detail_mesh)
    for obj in [body, *grouped_details]:
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
    return [body, *grouped_details]


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


def attach_socket(name: str, world_position: tuple[float, float, float], rig: bpy.types.Object, bone_name: str) -> None:
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


def set_armature_axis_rotation(
    pose_bone: bpy.types.PoseBone,
    rotations: tuple[tuple[Vector, float], ...],
) -> None:
    """Set a pose using axes shared by the rig rather than inconsistent bone roll.

    The source limbs have their cross-body hinge near local +/-Z, not local X.
    Converting the desired armature-space axis through each rest matrix prevents
    the old walk clip from twisting legs around their length.
    """

    rest_rotation = pose_bone.bone.matrix_local.to_quaternion()
    result = Quaternion()
    for armature_axis, angle in rotations:
        local_axis = rest_rotation.inverted() @ armature_axis
        local_axis.normalize()
        result = result @ Quaternion(local_axis, angle)
    pose_bone.rotation_euler = result.to_euler("XYZ")


def set_sagittal_rotation(pose_bone: bpy.types.PoseBone, angle: float) -> None:
    set_armature_axis_rotation(pose_bone, ((Vector((1.0, 0.0, 0.0)), angle),))


def set_tail_rotation(pose_bone: bpy.types.PoseBone, pitch: float, sway: float) -> None:
    # Armature Y maps to the vertical world axis after the source rig transform.
    set_armature_axis_rotation(
        pose_bone,
        (
            (Vector((1.0, 0.0, 0.0)), pitch),
            (Vector((0.0, 1.0, 0.0)), sway),
        ),
    )


def key_rotation(rig: bpy.types.Object, bone_name: str, frame: int) -> None:
    rig.pose.bones[bone_name].keyframe_insert(data_path="rotation_euler", frame=frame, group=bone_name)


def create_actions(rig: bpy.types.Object) -> None:
    bpy.context.scene.render.fps = 30
    rig.animation_data_create()
    limb_bones = {
        "LF": ("b_LeftUpperArm", "b_LeftForeArm", "Paw_LF"),
        "RF": ("b_RightUpperArm", "b_RightForeArm", "Paw_RF"),
        "LH": ("b_LeftLeg01", "b_LeftLeg02", "Paw_LH"),
        "RH": ("b_RightLeg01", "b_RightLeg02", "Paw_RH"),
    }
    for action_name in ACTIONS:
        action = bpy.data.actions.new(action_name)
        rig.animation_data.action = action
        reset_pose(rig)
        # A relaxed wolf carries its tail below the topline. Preserve that
        # anatomical baseline in every clip and animate sway around it.
        set_tail_rotation(rig.pose.bones["b_Tail01"], -0.42, 0.0)
        set_tail_rotation(rig.pose.bones["b_Tail02"], -0.16, 0.0)
        for pose_bone in rig.pose.bones:
            pose_bone.keyframe_insert(data_path="rotation_euler", frame=1, group=pose_bone.name)

        if action_name in ("locomotion", "sprint"):
            amount = 0.34 if action_name == "locomotion" else 0.58
            front_joint_bend = 0.56 if action_name == "locomotion" else 0.80
            hind_joint_bend = 0.68 if action_name == "locomotion" else 0.94
            for index, frame in enumerate((1, 5, 9, 13, 17, 21, 25, 29, 33)):
                phase = math.tau * index / 8.0
                for suffix, (upper_name, lower_name, paw_name) in limb_bones.items():
                    if action_name == "locomotion":
                        offset = 0.0 if suffix in ("LF", "RH") else math.pi
                    else:
                        offset = {"LF": math.pi * 0.82, "RF": math.pi * 1.06, "LH": 0.0, "RH": math.pi * 0.20}[suffix]
                    stride = math.sin(phase + offset)
                    swing = max(stride, 0.0)
                    support = max(-stride, 0.0)
                    transfer = max(0.0, 1.0 - abs(stride) * 1.7)
                    upper = rig.pose.bones[upper_name]
                    lower = rig.pose.bones[lower_name]
                    paw = rig.pose.bones[paw_name]
                    # Negative cross-body rotation sends the paw toward the
                    # wolf's forward (-Y) direction. Diagonal pairs alternate
                    # between a planted stance and a compact lifted swing.
                    set_sagittal_rotation(upper, -amount * stride)
                    if suffix in ("LF", "RF"):
                        elbow_flex = front_joint_bend * (0.94 * swing + 0.10 * transfer + 0.10 * support)
                        set_sagittal_rotation(lower, -elbow_flex)
                        set_sagittal_rotation(paw, front_joint_bend * (0.44 * swing + 0.08 * transfer))
                    else:
                        knee_flex = hind_joint_bend * (0.98 * swing + 0.10 * transfer + 0.08 * support)
                        set_sagittal_rotation(lower, knee_flex)
                        set_sagittal_rotation(paw, -hind_joint_bend * (0.50 * swing + 0.08 * transfer))
                    for bone_name in (upper_name, lower_name, paw_name):
                        key_rotation(rig, bone_name, frame)
                flex = (0.045 if action_name == "locomotion" else 0.115) * math.cos(phase)
                set_sagittal_rotation(rig.pose.bones["b_Spine01"], flex)
                set_sagittal_rotation(rig.pose.bones["b_Spine03"], -flex * 0.65)
                set_sagittal_rotation(rig.pose.bones["b_Neck"], flex * 0.30)
                set_sagittal_rotation(rig.pose.bones["b_Head"], -flex * 0.20)
                for tail_index in range(1, 5):
                    tail_name = f"b_Tail0{tail_index}"
                    pitch = -0.42 if tail_index == 1 else (-0.16 if tail_index == 2 else 0.0)
                    sway = math.sin(phase * 0.5 - tail_index * 0.32) * (0.07 if action_name == "locomotion" else 0.12)
                    set_tail_rotation(rig.pose.bones[tail_name], pitch, sway)
                    key_rotation(rig, tail_name, frame)
                for bone_name in ("b_Spine01", "b_Spine03", "b_Neck", "b_Head"):
                    key_rotation(rig, bone_name, frame)
        elif action_name == "idle":
            for frame, curve in zip((1, 9, 17, 25, 33), (-1.0, 0.1, 1.0, -0.15, -1.0)):
                set_sagittal_rotation(rig.pose.bones["b_Spine03"], 0.018 * curve)
                set_sagittal_rotation(rig.pose.bones["b_Neck"], -0.012 * curve)
                rig.pose.bones["b_Head"].rotation_euler[2] = 0.018 * curve
                for tail_index in range(1, 5):
                    tail_name = f"b_Tail0{tail_index}"
                    pitch = -0.42 if tail_index == 1 else (-0.16 if tail_index == 2 else 0.0)
                    set_tail_rotation(rig.pose.bones[tail_name], pitch, 0.055 * curve * tail_index / 4.0)
                    key_rotation(rig, tail_name, frame)
                for bone_name in ("b_Spine03", "b_Neck", "b_Head"):
                    key_rotation(rig, bone_name, frame)
        elif action_name == "attack":
            for frame, curve, jaw_curve in zip((1, 5, 9, 14, 22), (0.0, 0.45, 1.0, 0.62, 0.0), (0.0, 0.78, 1.0, 0.12, 0.0)):
                rig.pose.bones["b_Spine03"].rotation_euler[0] = -0.28 * curve
                rig.pose.bones["b_Neck"].rotation_euler[0] = -0.22 * curve
                rig.pose.bones["b_Head"].rotation_euler[0] = 0.34 * curve
                rig.pose.bones["b_Jaw"].rotation_euler[0] = -0.46 * jaw_curve
                rig.pose.bones["b_LeftUpperArm"].rotation_euler[0] = -0.48 * curve
                rig.pose.bones["b_RightUpperArm"].rotation_euler[0] = -0.48 * curve
                for bone_name in ("b_Spine03", "b_Neck", "b_Head", "b_Jaw", "b_LeftUpperArm", "b_RightUpperArm"):
                    key_rotation(rig, bone_name, frame)
        elif action_name == "skill":
            for frame, curve in zip((1, 10, 20, 30), (0.0, 1.0, 0.82, 0.0)):
                rig.pose.bones["b_Spine03"].rotation_euler[0] = 0.10 * curve
                rig.pose.bones["b_Neck"].rotation_euler[0] = 0.42 * curve
                rig.pose.bones["b_Head"].rotation_euler[0] = -0.54 * curve
                rig.pose.bones["b_Jaw"].rotation_euler[0] = -0.34 * curve
                for bone_name in ("b_Spine03", "b_Neck", "b_Head", "b_Jaw"):
                    key_rotation(rig, bone_name, frame)
        elif action_name == "hit":
            for frame, curve in zip((1, 6, 15), (0.0, 1.0, 0.0)):
                rig.pose.bones["b_Spine02"].rotation_euler[2] = 0.22 * curve
                rig.pose.bones["b_Head"].rotation_euler[2] = -0.16 * curve
                key_rotation(rig, "b_Spine02", frame)
                key_rotation(rig, "b_Head", frame)
        elif action_name == "eat":
            for frame, curve, chew in zip((1, 9, 17, 25, 33), (0.0, 1.0, 0.88, 1.0, 0.0), (0.0, 0.15, 0.42, 0.12, 0.0)):
                rig.pose.bones["b_Neck"].rotation_euler[0] = -0.48 * curve
                rig.pose.bones["b_Head"].rotation_euler[0] = 0.34 * curve
                rig.pose.bones["b_Jaw"].rotation_euler[0] = -chew
                for bone_name in ("b_Neck", "b_Head", "b_Jaw"):
                    key_rotation(rig, bone_name, frame)
        elif action_name == "death":
            for frame, curve in zip((1, 18, 32), (0.0, 0.72, 1.0)):
                rig.pose.bones["b_Hip"].rotation_euler[2] = 1.18 * curve
                rig.pose.bones["b_Spine01"].rotation_euler[2] = 0.24 * curve
                key_rotation(rig, "b_Hip", frame)
                key_rotation(rig, "b_Spine01", frame)
        action.use_fake_user = True
    rig.animation_data.action = bpy.data.actions["idle"]


def mesh_island_count(obj: bpy.types.Object) -> int:
    remaining = set(range(len(obj.data.vertices)))
    adjacency = [[] for _ in obj.data.vertices]
    for edge in obj.data.edges:
        first, second = edge.vertices
        adjacency[first].append(second)
        adjacency[second].append(first)
    islands = 0
    while remaining:
        islands += 1
        stack = [remaining.pop()]
        while stack:
            for neighbour in adjacency[stack.pop()]:
                if neighbour in remaining:
                    remaining.remove(neighbour)
                    stack.append(neighbour)
    return islands


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
    rig, mesh = load_source(source_dir)
    add_adult_wolf_mass(mesh)
    shorten_leg_proportions(rig, mesh)
    merge_terminal_toe_weights(mesh)
    remove_terminal_toe_bones(rig)
    rename_articulated_paw_bones(rig, mesh)
    material = pbr_material(source_dir, 1024 if hero else 512)
    parts = split_body_and_details(mesh, material, detail_materials(material))
    body = parts[0]
    if mesh_island_count(body) != 1:
        raise RuntimeError("cinematic wolf organic body is not one connected mesh island")
    if hero:
        add_hero_subdivision(body)
    attach_socket("SkillSocket_Mouth", _shortened_leg_world_position(Vector((0.0, -1.84, 2.24))), rig, "b_Head")
    attach_socket("SkillSocket_Chest", _shortened_leg_world_position(Vector((0.0, -0.55, 1.72))), rig, "b_Spine03")
    create_actions(rig)
    profile = "hero" if hero else "mobile"
    output = output_root / "wolf" / f"wolf_{profile}.glb"
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
    triangles, vertices = evaluated_stats(parts)
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
        print(f"CINEMATIC_WOLF_OK: {profile} / {triangles} triangles / {vertices} vertices / {bones} bones")


if __name__ == "__main__":
    main()
