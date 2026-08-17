from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Quaternion, Vector


ACTIONS = ("idle", "locomotion", "sprint", "attack", "skill", "hit", "eat", "death")
SOURCE_BASENAME = "snake.blend"
SOURCE_TEXTURE = "snake.png"
SOURCE_ARCHIVE_SHA256 = "fcadd98c732e39d44af150034d7ba02f9ffe26680ec7e879331f103fa8d279f9"
RUNTIME_BONES = (
    "Root", "Spine_Rear", "Body", "Chest", "Neck", "Head", "Jaw",
    "Tail_Base", "Tail_Mid", "Tail_Tip",
)
DEFORM_BONES = ("Spine_Rear", "Body", "Chest", "Neck", "Head", "Tail_Base", "Tail_Mid", "Tail_Tip")
AXIAL_CHAIN = ("Head", "Neck", "Chest", "Body", "Spine_Rear", "Tail_Base", "Tail_Mid", "Tail_Tip")
ANCHORS = {
    "Head": -1.90,
    "Neck": -1.42,
    "Chest": -0.92,
    "Body": -0.42,
    "Spine_Rear": 0.14,
    "Tail_Base": 0.72,
    "Tail_Mid": 1.30,
    "Tail_Tip": 1.86,
}


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description="Build the authored CC0 cinematic blue-ring snake")
    parser.add_argument("--source-dir", required=True)
    parser.add_argument("--output-root", required=True)
    return parser.parse_args(argv)


def load_source(source_dir: Path) -> bpy.types.Object:
    source_file = source_dir / SOURCE_BASENAME
    if not source_file.is_file() or not (source_dir / SOURCE_TEXTURE).is_file():
        raise RuntimeError(f"missing CC0 snake source in {source_dir}")
    bpy.ops.wm.open_mainfile(filepath=str(source_file))
    mesh = bpy.data.objects.get("snake")
    if mesh is None or mesh.type != "MESH":
        raise RuntimeError("CC0 snake source is missing its continuous snake mesh")
    for obj in list(bpy.context.scene.objects):
        if obj != mesh:
            bpy.data.objects.remove(obj, do_unlink=True)
    for modifier in list(mesh.modifiers):
        mesh.modifiers.remove(modifier)
    for group in list(mesh.vertex_groups):
        mesh.vertex_groups.remove(group)
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    mesh.parent = None
    mesh.matrix_world = Matrix.Identity(4)
    mesh.rotation_euler = (0.0, 0.0, 0.0)
    mesh.scale = (1.0, 1.0, 1.0)
    return mesh


def normalize_anatomy(mesh: bpy.types.Object) -> None:
    # The CC0 control cage has the correct long-bodied silhouette but is only
    # 206 triangles.  Preserve its topology/UVs while converting the tiny,
    # flattened source into a grounded adult colubrid silhouette.
    transformed: list[Vector] = []
    for vertex in mesh.data.vertices:
        source = vertex.co.copy()
        length_position = source.y * 4.36
        head_gain = 1.0 + 0.22 * max(0.0, min(1.0, (-source.y - 0.36) / 0.14))
        resting_curve = 0.13 * math.sin((length_position + 1.95) * 1.72)
        transformed.append(Vector((source.x * 2.72 * head_gain + resting_curve, length_position, source.z * 6.15 * head_gain)))
    minimum_z = min(vertex.z for vertex in transformed)
    ground_lift = 0.055 - minimum_z
    for vertex, position in zip(mesh.data.vertices, transformed):
        vertex.co = position + Vector((0.0, 0.0, ground_lift))
    mesh.data.update()
    mesh.name = "SnakeOrganicBodyV2_SourceConnected"
    mesh.data.name = "SnakeOrganicBodyV2SourceMesh"
    mesh["eco_anatomy_contract"] = "authored_cc0_colubrid_continuous_body_v1"
    mesh["eco_surface_pattern"] = "authored_uv_blue_ring_scale_pbr"


def create_rig() -> bpy.types.Object:
    bpy.ops.object.armature_add(enter_editmode=True, location=(0.0, 0.0, 0.0))
    rig = bpy.context.active_object
    rig.name = "SpeciesCrocodileSkeleton3D"
    rig.data.name = "SnakeCinematicLongBodyRig"
    bones = rig.data.edit_bones
    root = bones[0]
    root.name = "Root"
    root.head = Vector((0.0, 0.08, 0.09))
    root.tail = Vector((0.0, 0.08, 0.39))
    root.use_deform = False

    def add(name: str, head: tuple[float, float, float], tail: tuple[float, float, float], parent: bpy.types.EditBone) -> bpy.types.EditBone:
        bone = bones.new(name)
        bone.head = Vector(head)
        bone.tail = Vector(tail)
        bone.parent = parent
        bone.use_connect = False
        return bone

    spine = add("Spine_Rear", (0.0, 0.34, 0.16), (0.0, -0.18, 0.16), root)
    body = add("Body", (0.0, -0.18, 0.16), (0.0, -0.68, 0.16), spine)
    chest = add("Chest", (0.0, -0.68, 0.16), (0.0, -1.16, 0.16), body)
    neck = add("Neck", (0.0, -1.16, 0.16), (0.0, -1.57, 0.17), chest)
    head = add("Head", (0.0, -1.57, 0.17), (0.0, -2.13, 0.17), neck)
    jaw = add("Jaw", (0.0, -1.65, 0.12), (0.0, -2.12, 0.10), head)
    jaw.use_deform = False
    tail_base = add("Tail_Base", (0.0, 0.34, 0.16), (0.0, 0.94, 0.15), spine)
    tail_mid = add("Tail_Mid", (0.0, 0.94, 0.15), (0.0, 1.53, 0.13), tail_base)
    add("Tail_Tip", (0.0, 1.53, 0.13), (0.0, 2.18, 0.09), tail_mid)
    bpy.ops.object.mode_set(mode="OBJECT")
    rig["species_id"] = "snake"
    rig["rig_version"] = 6
    rig["skin_mode"] = "cc0_weighted_cinematic_long_body"
    rig["locomotion_profile"] = "serpentine_travelling_wave"
    rig["source_archive_sha256"] = SOURCE_ARCHIVE_SHA256
    rig["anatomy_profile"] = "authored_japanese_striped_snake_blue_ring_variant"
    rig["surface_profile"] = "authored_uv_scale_albedo_normal_roughness"
    rig["axial_segments"] = 8
    return rig


def apply_subdivision(mesh: bpy.types.Object, level: int) -> None:
    modifier = mesh.modifiers.new("CinematicSubdivision", "SUBSURF")
    modifier.subdivision_type = "CATMULL_CLARK"
    modifier.levels = level
    modifier.render_levels = level
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    mesh.select_set(False)
    for polygon in mesh.data.polygons:
        polygon.use_smooth = True


def apply_axial_weights(mesh: bpy.types.Object, rig: bpy.types.Object) -> None:
    for group in list(mesh.vertex_groups):
        mesh.vertex_groups.remove(group)
    groups = {name: mesh.vertex_groups.new(name=name) for name in DEFORM_BONES}
    ordered = sorted(ANCHORS, key=lambda name: ANCHORS[name])
    for vertex in mesh.data.vertices:
        y = vertex.co.y
        if y <= ANCHORS[ordered[0]]:
            influences = ((ordered[0], 1.0),)
        elif y >= ANCHORS[ordered[-1]]:
            influences = ((ordered[-1], 1.0),)
        else:
            influences = ((ordered[0], 1.0),)
            for left, right in zip(ordered, ordered[1:]):
                if ANCHORS[left] <= y <= ANCHORS[right]:
                    span = max(ANCHORS[right] - ANCHORS[left], 0.0001)
                    blend = (y - ANCHORS[left]) / span
                    smooth = blend * blend * (3.0 - 2.0 * blend)
                    influences = ((left, 1.0 - smooth), (right, smooth))
                    break
        for name, weight in influences:
            if weight > 0.000001:
                groups[name].add([vertex.index], weight, "REPLACE")
    modifier = mesh.modifiers.new("SnakeArmature", "ARMATURE")
    modifier.object = rig
    mesh.parent = rig


def production_scale_images(source_dir: Path, texture_size: int) -> tuple[bpy.types.Image, bpy.types.Image, bpy.types.Image]:
    images: list[bpy.types.Image] = []
    for suffix, colorspace in (("albedo", "sRGB"), ("normal", "Non-Color"), ("roughness", "Non-Color")):
        path = source_dir / f"snake_scale_{suffix}.png"
        if not path.is_file():
            raise RuntimeError(f"missing authored snake PBR map: {path}")
        image = bpy.data.images.load(str(path), check_existing=False)
        image.name = f"snake_{texture_size}_scale_{suffix}"
        image.colorspace_settings.name = colorspace
        if image.size[0] != texture_size or image.size[1] != texture_size:
            image.scale(texture_size, texture_size)
        image.pack()
        images.append(image)
    return images[0], images[1], images[2]


def scale_material(images: tuple[bpy.types.Image, bpy.types.Image, bpy.types.Image], hero: bool) -> bpy.types.Material:
    albedo_image, normal_image, roughness_image = images
    material = bpy.data.materials.new("snake_cinematic_scale_pbr")
    material.use_nodes = True
    material.diffuse_color = (0.08, 0.34, 0.29, 1.0)
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    principled = nodes.get("Principled BSDF")
    if principled is None:
        raise RuntimeError("Blender did not create a Principled BSDF node")
    if "Specular IOR Level" in principled.inputs:
        principled.inputs["Specular IOR Level"].default_value = 0.30
    albedo = nodes.new("ShaderNodeTexImage")
    albedo.image = albedo_image
    links.new(albedo.outputs["Color"], principled.inputs["Base Color"])
    if hero:
        normal_texture = nodes.new("ShaderNodeTexImage")
        normal_texture.image = normal_image
        normal_texture.image.colorspace_settings.name = "Non-Color"
        normal_map = nodes.new("ShaderNodeNormalMap")
        normal_map.inputs["Strength"].default_value = 0.62
        links.new(normal_texture.outputs["Color"], normal_map.inputs["Color"])
        links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])
        roughness = nodes.new("ShaderNodeTexImage")
        roughness.image = roughness_image
        roughness.image.colorspace_settings.name = "Non-Color"
        links.new(roughness.outputs["Color"], principled.inputs["Roughness"])
    else:
        principled.inputs["Roughness"].default_value = 0.72
        material["mobile_surface_channels"] = "albedo_plus_scalar_roughness"
    material["eco_pbr_surface"] = "cc0_authored_blue_ring_scales"
    return material


def solid_material(name: str, color: tuple[float, float, float, float], roughness: float, metallic: float = 0.0) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.diffuse_color = color
    principled = material.node_tree.nodes.get("Principled BSDF")
    if principled is not None:
        principled.inputs["Base Color"].default_value = color
        principled.inputs["Roughness"].default_value = roughness
        principled.inputs["Metallic"].default_value = metallic
    material["eco_pbr_surface"] = "cc0_authored_blue_ring_scales"
    return material


def replace_material(mesh: bpy.types.Object, material: bpy.types.Material) -> None:
    while mesh.data.materials:
        mesh.data.materials.pop(index=0)
    mesh.data.materials.append(material)
    for polygon in mesh.data.polygons:
        polygon.material_index = 0
        polygon.use_smooth = True


def add_flush_underbelly(mesh: bpy.types.Object, material: bpy.types.Material) -> None:
    accent_index = len(mesh.data.materials)
    mesh.data.materials.append(material)
    for polygon in mesh.data.polygons:
        centre = sum((mesh.data.vertices[index].co for index in polygon.vertices), Vector()) / len(polygon.vertices)
        if centre.z < 0.105:
            polygon.material_index = accent_index


def parent_to_bone(obj: bpy.types.Object, rig: bpy.types.Object, bone_name: str) -> None:
    world = obj.matrix_world.copy()
    obj.parent = rig
    obj.parent_type = "BONE"
    obj.parent_bone = bone_name
    obj.matrix_world = world


def add_ellipsoid(name: str, location: tuple[float, float, float], scale: tuple[float, float, float], material: bpy.types.Material, rig: bpy.types.Object, bone: str, hero: bool) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=20 if hero else 12,
        ring_count=12 if hero else 8,
        location=location,
    )
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    parent_to_bone(obj, rig, bone)
    return obj


def add_cone_between(name: str, start: Vector, end: Vector, radius: float, material: bpy.types.Material, rig: bpy.types.Object, bone: str, hero: bool) -> bpy.types.Object:
    direction = end - start
    bpy.ops.mesh.primitive_cone_add(
        vertices=10 if hero else 7,
        radius1=radius,
        radius2=radius * 0.08,
        depth=direction.length,
        location=start.lerp(end, 0.5),
    )
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = direction.normalized().to_track_quat("Z", "Y").to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.data.materials.append(material)
    parent_to_bone(obj, rig, bone)
    return obj


def add_head_details(rig: bpy.types.Object, materials: dict[str, bpy.types.Material], hero: bool) -> list[bpy.types.Object]:
    parts: list[bpy.types.Object] = []
    parts.append(add_ellipsoid("SnakeJawSilhouette", (0.0, -2.02, 0.115), (0.145, 0.21, 0.045), materials["accent"], rig, "Jaw", hero))
    for side, suffix in ((-1.0, "L"), (1.0, "R")):
        eye_position = (side * 0.125, -2.005, 0.195)
        parts.append(add_ellipsoid(f"V5EyeDetail_{suffix}", eye_position, (0.030, 0.025, 0.032), materials["eye"], rig, "Head", hero))
        parts.append(add_ellipsoid(f"V5NostrilDetail_{suffix}", (side * 0.082, -2.145, 0.185), (0.014, 0.009, 0.009), materials["detail"], rig, "Head", hero))
        fang_start = Vector((side * 0.115, -2.005, 0.115))
        fang_end = Vector((side * 0.112, -2.055, 0.035))
        parts.append(add_cone_between(f"SnakeFangDetail_{suffix}", fang_start, fang_end, 0.025, materials["keratin"], rig, "Jaw", hero))
    tongue_base = Vector((0.0, -2.18, 0.105))
    for side, suffix in ((-1.0, "L"), (1.0, "R")):
        parts.append(add_cone_between(f"ForkedTongueDetail_{suffix}", tongue_base, Vector((side * 0.06, -2.44, 0.095)), 0.014, materials["mouth"], rig, "Jaw", hero))
    return parts


def attach_socket(name: str, world_position: Vector, rig: bpy.types.Object, bone_name: str) -> None:
    socket = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(socket)
    socket.empty_display_type = "SPHERE"
    socket.empty_display_size = 0.06
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


def set_axis_rotation(pose_bone: bpy.types.PoseBone, axis: Vector, angle: float) -> None:
    rest_rotation = pose_bone.bone.matrix_local.to_quaternion()
    local_axis = rest_rotation.inverted() @ axis
    local_axis.normalize()
    pose_bone.rotation_euler = Quaternion(local_axis, angle).to_euler("XYZ")


def key_axis(rig: bpy.types.Object, bone_name: str, frame: int, axis: Vector, angle: float) -> None:
    pose_bone = rig.pose.bones[bone_name]
    set_axis_rotation(pose_bone, axis, angle)
    pose_bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=bone_name)


def key_wave(rig: bpy.types.Object, frame: int, phase: float, strength: float, vertical: float = 0.0) -> None:
    for index, bone_name in enumerate(AXIAL_CHAIN):
        wave = math.sin(phase - index * 0.74)
        key_axis(rig, bone_name, frame, Vector((0.0, 0.0, 1.0)), strength * wave)
        if vertical != 0.0:
            lift = math.sin(phase * 0.5 - index * 0.42)
            pose_bone = rig.pose.bones[bone_name]
            current = Quaternion(pose_bone.rotation_euler)
            rest_rotation = pose_bone.bone.matrix_local.to_quaternion()
            local_x = (rest_rotation.inverted() @ Vector((1.0, 0.0, 0.0))).normalized()
            pose_bone.rotation_euler = (current @ Quaternion(local_x, vertical * lift)).to_euler("XYZ")
            pose_bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=bone_name)


def create_actions(rig: bpy.types.Object) -> None:
    bpy.context.scene.render.fps = 30
    rig.animation_data_create()
    for action_name in ACTIONS:
        action = bpy.data.actions.new(action_name)
        rig.animation_data.action = action
        reset_pose(rig)
        for pose_bone in rig.pose.bones:
            pose_bone.keyframe_insert(data_path="rotation_euler", frame=1, group=pose_bone.name)

        if action_name in ("locomotion", "sprint"):
            strength = 0.22 if action_name == "locomotion" else 0.36
            for frame in (1, 5, 9, 13, 17, 21, 25, 29, 33):
                phase = math.tau * (frame - 1) / 32.0
                key_wave(rig, frame, phase, strength, 0.018 if action_name == "locomotion" else 0.035)
        elif action_name == "idle":
            for frame, phase in ((1, 0.0), (12, math.pi * 0.5), (23, math.pi), (34, math.tau)):
                key_wave(rig, frame, phase, 0.045, 0.012)
        elif action_name in ("attack", "skill"):
            strength = 1.0 if action_name == "attack" else 1.28
            for frame, coil, strike in ((1, 0.0, 0.0), (7, 1.0, -0.18), (12, 0.34, 1.0), (22, 0.0, 0.0)):
                key_axis(rig, "Spine_Rear", frame, Vector((0.0, 0.0, 1.0)), -0.22 * coil * strength)
                key_axis(rig, "Body", frame, Vector((0.0, 0.0, 1.0)), 0.34 * coil * strength)
                key_axis(rig, "Chest", frame, Vector((0.0, 0.0, 1.0)), -0.31 * coil * strength)
                key_axis(rig, "Neck", frame, Vector((1.0, 0.0, 0.0)), -0.28 * strike * strength)
                key_axis(rig, "Head", frame, Vector((1.0, 0.0, 0.0)), 0.30 * strike * strength)
                key_axis(rig, "Jaw", frame, Vector((1.0, 0.0, 0.0)), -0.48 * max(strike, 0.0))
                key_axis(rig, "Tail_Mid", frame, Vector((0.0, 0.0, 1.0)), 0.24 * coil)
                key_axis(rig, "Tail_Tip", frame, Vector((0.0, 0.0, 1.0)), -0.36 * coil)
        elif action_name == "hit":
            for frame, amount in ((1, 0.0), (5, 1.0), (14, 0.0)):
                key_axis(rig, "Spine_Rear", frame, Vector((0.0, 1.0, 0.0)), 0.32 * amount)
                key_axis(rig, "Chest", frame, Vector((0.0, 0.0, 1.0)), -0.38 * amount)
                key_axis(rig, "Head", frame, Vector((0.0, 0.0, 1.0)), 0.44 * amount)
        elif action_name == "eat":
            for frame, lower, chew in ((1, 0.0, 0.0), (9, 1.0, 0.0), (16, 0.85, 1.0), (23, 0.85, -1.0), (32, 0.0, 0.0)):
                key_axis(rig, "Neck", frame, Vector((1.0, 0.0, 0.0)), -0.32 * lower)
                key_axis(rig, "Head", frame, Vector((1.0, 0.0, 0.0)), 0.20 * lower + 0.04 * chew)
                key_axis(rig, "Jaw", frame, Vector((1.0, 0.0, 0.0)), -0.32 * abs(chew) * lower)
        elif action_name == "death":
            for frame, fall in ((1, 0.0), (11, 0.28), (23, 0.78), (36, 1.0)):
                key_axis(rig, "Spine_Rear", frame, Vector((0.0, 1.0, 0.0)), 1.05 * fall)
                key_axis(rig, "Body", frame, Vector((0.0, 0.0, 1.0)), 0.48 * fall)
                key_axis(rig, "Chest", frame, Vector((0.0, 0.0, 1.0)), -0.42 * fall)
                key_axis(rig, "Neck", frame, Vector((1.0, 0.0, 0.0)), 0.34 * fall)
                key_axis(rig, "Tail_Base", frame, Vector((0.0, 0.0, 1.0)), -0.44 * fall)
                key_axis(rig, "Tail_Mid", frame, Vector((0.0, 0.0, 1.0)), 0.58 * fall)
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
    body = load_source(source_dir)
    normalize_anatomy(body)
    apply_subdivision(body, 3 if hero else 2)
    rig = create_rig()
    apply_axial_weights(body, rig)
    texture_size = 512 if hero else 128
    profile = "hero" if hero else "mobile"
    output_dir = output_root / "snake"
    output_dir.mkdir(parents=True, exist_ok=True)
    materials = {
        "scale": scale_material(production_scale_images(source_dir, texture_size), hero),
        "eye": solid_material("snake_cinematic_eye_pbr", (0.76, 0.46, 0.08, 1.0), 0.15),
        "accent": solid_material("snake_cinematic_accent_pbr", (0.08, 0.30, 0.24, 1.0), 0.70),
        "mouth": solid_material("snake_cinematic_detail_pbr", (0.34, 0.025, 0.045, 1.0), 0.54),
        "detail": solid_material("snake_cinematic_nose_pbr", (0.008, 0.012, 0.010, 1.0), 0.42),
        "keratin": solid_material("snake_cinematic_keratin_pbr", (0.82, 0.78, 0.62, 1.0), 0.48),
    }
    replace_material(body, materials["scale"])
    add_flush_underbelly(body, materials["accent"])
    details = add_head_details(rig, materials, hero)
    attach_socket("SkillSocket_Jaw", Vector((0.0, -2.28, 0.13)), rig, "Jaw")
    attach_socket("SkillSocket_TailTip", Vector((0.0, 2.15, 0.09)), rig, "Tail_Tip")
    create_actions(rig)

    if len(rig.data.bones) != 10 or set(bone.name for bone in rig.data.bones) != set(RUNTIME_BONES):
        raise RuntimeError(f"snake runtime rig is not the 10-bone contract: {len(rig.data.bones)}")
    output = output_dir / f"snake_{profile}.glb"
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
    triangles, vertices = evaluated_stats([body, *details])
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
        print(f"CINEMATIC_SNAKE_OK: {profile} / {triangles} triangles / {vertices} vertices / {bones} bones")


if __name__ == "__main__":
    main()
