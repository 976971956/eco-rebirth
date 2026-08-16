from __future__ import annotations

import argparse
import importlib.util
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


SOURCE_BASENAME = "fox.blend"
DIFFUSE_BASENAME = "fox_diffuse.png"
NORMAL_BASENAME = "fox_normal.png"
SOURCE_SHA256 = "88bd013a69da6125337f0a7ca6f74a9c5b445e9ff387c0c7c8c05b0ea4ad4374"
ZIP_SHA256 = "9faa5b363e003363d7cb4ad32c8ceae70ed3bb4b4e73afc249e0acd9be2787a3"
ANATOMY_SCALE = 0.35
GROUND_OFFSET = 0.02


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
    parser = argparse.ArgumentParser(description="Build the authored CC0 cinematic red fox for Eco Rebirth")
    parser.add_argument("--source-dir", required=True)
    parser.add_argument("--output-root", required=True)
    return parser.parse_args(argv)


def clear_source_animation() -> None:
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)


def detach_source_body(body: bpy.types.Object) -> None:
    world_matrix = body.matrix_world.copy()
    body.parent = None
    body.matrix_world = world_matrix
    for modifier in list(body.modifiers):
        if modifier.type == "ARMATURE":
            body.modifiers.remove(modifier)


def apply_source_geometry_modifiers(body: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    for modifier in list(body.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    body.select_set(False)


def keep_only_source_body(body: bpy.types.Object) -> None:
    for obj in list(bpy.context.scene.objects):
        if obj != body:
            bpy.data.objects.remove(obj, do_unlink=True)
    for armature in list(bpy.data.armatures):
        if armature.users == 0:
            bpy.data.armatures.remove(armature)


def bake_world_transform(body: bpy.types.Object) -> None:
    world_matrix = body.matrix_world.copy()
    for vertex in body.data.vertices:
        vertex.co = world_matrix @ vertex.co
    body.matrix_world = Matrix.Identity(4)
    body.data.update()


def normalize_anatomy(body: bpy.types.Object) -> tuple[float, float]:
    minimum_z = min(vertex.co.z for vertex in body.data.vertices)
    center_x = (min(vertex.co.x for vertex in body.data.vertices) + max(vertex.co.x for vertex in body.data.vertices)) * 0.5
    ground_translation = GROUND_OFFSET - minimum_z * ANATOMY_SCALE
    for vertex in body.data.vertices:
        vertex.co = Vector(
            (
                (vertex.co.x - center_x) * ANATOMY_SCALE,
                vertex.co.y * ANATOMY_SCALE,
                vertex.co.z * ANATOMY_SCALE + ground_translation,
            )
        )
    body.data.update()
    return center_x, ground_translation


def normalized_source_point(point: Vector, center_x: float, ground_translation: float) -> Vector:
    return Vector(
        (
            (point.x - center_x) * ANATOMY_SCALE,
            point.y * ANATOMY_SCALE,
            point.z * ANATOMY_SCALE + ground_translation,
        )
    )


def _smoothstep(edge_start: float, edge_end: float, value: float) -> float:
    if edge_start == edge_end:
        return 0.0
    amount = max(0.0, min(1.0, (value - edge_start) / (edge_end - edge_start)))
    return amount * amount * (3.0 - 2.0 * amount)


def _interval_weight(value: float, start: float, fade_in: float, fade_out: float, end: float) -> float:
    return _smoothstep(start, fade_in, value) * (1.0 - _smoothstep(fade_out, end, value))


def _shortened_fox_y(value: float) -> float:
    """Keep the leg stance stable while correcting the legacy source length."""
    if value < -0.62:
        return -0.62 + (value + 0.62) * 0.82
    if value > 0.52:
        return 0.52 + (value - 0.52) * 0.72
    return value


def shape_adult_red_fox(body: bpy.types.Object) -> None:
    """Establish an adult rib cage, waist, pelvis and dense brush tail."""
    for vertex in body.data.vertices:
        point = vertex.co
        point.y = _shortened_fox_y(point.y)

        torso = _interval_weight(point.y, -0.92, -0.68, 0.66, 0.90)
        chest = _interval_weight(point.y, -0.92, -0.70, -0.26, 0.00)
        waist = _interval_weight(point.y, -0.20, 0.00, 0.28, 0.48)
        haunch = _interval_weight(point.y, 0.22, 0.42, 0.80, 1.00)
        body_height = _interval_weight(point.z, 0.56, 0.82, 1.30, 1.55)
        mass_mask = torso * body_height

        # Preserve the fox's visible tuck while ensuring the shoulder and
        # hindquarter masses remain readable at the gameplay camera distance.
        width_gain = mass_mask * (0.16 + 0.16 * chest + 0.12 * haunch - 0.06 * waist)
        point.x *= 1.0 + width_gain
        depth_gain = mass_mask * (0.11 + 0.10 * chest + 0.07 * haunch - 0.04 * waist)
        body_center_z = 1.06
        point.z = body_center_z + (point.z - body_center_z) * (1.0 + depth_gain)

        if point.y > 0.70:
            tail_amount = _smoothstep(0.70, 1.28, point.y)
            point.x *= 1.0 + 0.30 * tail_amount
            tail_center_z = 1.04
            point.z = tail_center_z + (point.z - tail_center_z) * (1.0 + 0.22 * tail_amount)

    body.data.update()
    body["anatomy_profile"] = "adult_red_fox_balanced_mass_v2"


def reshape_source_bones(source_bones: dict[str, tuple[Vector, Vector]]) -> None:
    for head, tail in source_bones.values():
        head.y = _shortened_fox_y(head.y)
        tail.y = _shortened_fox_y(tail.y)


def capture_source_bones(
    source_rig: bpy.types.Object,
    center_x: float,
    ground_translation: float,
) -> dict[str, tuple[Vector, Vector]]:
    result: dict[str, tuple[Vector, Vector]] = {}
    for bone in source_rig.data.bones:
        head = normalized_source_point(source_rig.matrix_world @ bone.head_local, center_x, ground_translation)
        tail = normalized_source_point(source_rig.matrix_world @ bone.tail_local, center_x, ground_translation)
        result[bone.name] = (head, tail)
    return result


def build_authored_runtime_rig(
    source_bones: dict[str, tuple[Vector, Vector]],
    body: bpy.types.Object,
) -> bpy.types.Object:
    bpy.ops.object.armature_add(enter_editmode=True, location=(0.0, 0.0, 0.0))
    rig = bpy.context.active_object
    rig.name = "SpeciesSkeleton3D"
    rig.data.name = "FoxCinematicSkeleton"
    edit = rig.data.edit_bones
    root = edit[0]
    root.name = "Root"
    root.head = Vector((0.0, 0.0, GROUND_OFFSET))
    root.tail = Vector((0.0, 0.0, 0.42))

    def add(name: str, head: Vector, tail: Vector, parent: bpy.types.EditBone) -> bpy.types.EditBone:
        bone = edit.new(name)
        bone.head = head
        bone.tail = tail if (tail - head).length > 0.025 else head + Vector((0.0, 0.025, 0.0))
        bone.parent = parent
        bone.use_connect = False
        return bone

    spine_head, spine_tail = source_bones["SPINE"]
    spine_mid = spine_head.lerp(spine_tail, 0.53)
    spine = add("Spine", spine_head, spine_mid, root)
    chest = add("Chest", spine_mid, spine_tail, spine)
    neck = add("Neck", *source_bones["NECK"], chest)
    head = add("Head", *source_bones["root.004"], neck)
    head_direction = head.tail - head.head
    jaw_head = head.head.lerp(head.tail, 0.57) + Vector((0.0, 0.0, -0.055))
    jaw = add("Jaw", jaw_head, jaw_head + head_direction.normalized() * max(head_direction.length * 0.32, 0.12), head)
    jaw.use_deform = False

    limb_sources = {
        "LF": ("upperarm_L", "LEG_F_L", "foot_F_L"),
        "RF": ("upperarm_R", "LEG_F_R", "foot_F_R"),
        "LH": ("thigh_L", "LEG_B_L", "foot_B_L"),
        "RH": ("thigh_R", "LEG_B_R", "foot_B_R"),
    }
    for suffix, names in limb_sources.items():
        parent = chest if suffix.endswith("F") else spine
        upper = add(f"Leg_{suffix}", *source_bones[names[0]], parent)
        lower = add(f"Lower_{suffix}", *source_bones[names[1]], upper)
        add(f"Paw_{suffix}", *source_bones[names[2]], lower)

    head_front = min(head.head.y, head.tail.y)
    maximum_z = max(vertex.co.z for vertex in body.data.vertices)
    for suffix, left in (("L", True), ("R", False)):
        candidates = [
            vertex.co.copy()
            for vertex in body.data.vertices
            if vertex.co.z > maximum_z - 0.25
            and vertex.co.y < head_front + 0.72
            and (vertex.co.x < 0.0 if left else vertex.co.x > 0.0)
        ]
        side = -1.0 if left else 1.0
        tip = max(candidates, key=lambda point: point.z) if candidates else Vector((side * 0.20, head.head.y, maximum_z))
        base = Vector((tip.x * 0.72, tip.y + 0.08, tip.z - 0.34))
        add(f"Ear_{suffix}", base, tip, head)

    tail = add("Tail", *source_bones["tailbone"], spine)
    add("TailTip", *source_bones["TAIL"], tail)
    bpy.ops.object.mode_set(mode="OBJECT")
    if len(rig.data.bones) != 22:
        raise RuntimeError(f"fox runtime rig is not the 22-bone contract: {len(rig.data.bones)}")
    return rig


def apply_authored_subdivision(body: bpy.types.Object, hero: bool) -> None:
    modifier = body.modifiers.new("AuthoredFoxSurface", "SUBSURF")
    modifier.subdivision_type = "CATMULL_CLARK"
    modifier.levels = 3 if hero else 2
    modifier.render_levels = modifier.levels
    modifier.show_only_control_edges = True
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    body.select_set(False)
    body.data.validate(verbose=True, clean_customdata=False)
    for polygon in body.data.polygons:
        polygon.use_smooth = True


def load_texture(path: Path, texture_size: int, colorspace: str) -> bpy.types.Image:
    if not path.is_file():
        raise RuntimeError(f"missing fox texture: {path}")
    image = bpy.data.images.load(str(path), check_existing=False)
    image.name = path.stem
    image.colorspace_settings.name = colorspace
    if image.size[0] != texture_size or image.size[1] != texture_size:
        image.scale(texture_size, texture_size)
    image.pack()
    return image


def textured_material(source_dir: Path, texture_size: int) -> bpy.types.Material:
    diffuse = load_texture(source_dir / DIFFUSE_BASENAME, texture_size, "sRGB")
    normal = load_texture(source_dir / NORMAL_BASENAME, texture_size, "Non-Color")
    material = bpy.data.materials.new("fox_cinematic_source_coat_pbr")
    material.use_nodes = True
    material.diffuse_color = (0.70, 0.27, 0.08, 1.0)
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    for node in list(nodes):
        nodes.remove(node)
    output = nodes.new("ShaderNodeOutputMaterial")
    principled = nodes.new("ShaderNodeBsdfPrincipled")
    principled.inputs["Roughness"].default_value = 0.82
    if "Specular IOR Level" in principled.inputs:
        principled.inputs["Specular IOR Level"].default_value = 0.30
    albedo_node = nodes.new("ShaderNodeTexImage")
    albedo_node.image = diffuse
    albedo_node.interpolation = "Linear"
    normal_node = nodes.new("ShaderNodeTexImage")
    normal_node.image = normal
    normal_node.interpolation = "Linear"
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = 0.58
    links.new(albedo_node.outputs["Color"], principled.inputs["Base Color"])
    links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])
    links.new(principled.outputs["BSDF"], output.inputs["Surface"])
    material["eco_pbr_surface"] = "cc0_authored_red_fox"
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
        if "Specular IOR Level" in principled.inputs:
            principled.inputs["Specular IOR Level"].default_value = 0.32 if roughness > 0.4 else 0.52
    material["eco_pbr_surface"] = "cc0_authored_red_fox"
    return material


def replace_materials(
    body: bpy.types.Object,
    coat: bpy.types.Material,
    tail_accent: bpy.types.Material,
) -> None:
    while body.data.materials:
        body.data.materials.pop(index=0)
    body.data.materials.append(coat)
    body.data.materials.append(tail_accent)
    maximum_y = max(vertex.co.y for vertex in body.data.vertices)
    for polygon in body.data.polygons:
        center_y = sum(body.data.vertices[index].co.y for index in polygon.vertices) / len(polygon.vertices)
        polygon.material_index = 1 if center_y > maximum_y - 0.62 else 0


def source_group_weights(body: bpy.types.Object) -> dict[str, list[float]]:
    group_names = {group.index: group.name for group in body.vertex_groups}
    result = {name: [0.0] * len(body.data.vertices) for name in group_names.values()}
    for vertex in body.data.vertices:
        for membership in vertex.groups:
            group_name = group_names.get(membership.group)
            if group_name is not None:
                result[group_name][vertex.index] = membership.weight
    return result


def mapped_runtime_weights(
    body: bpy.types.Object,
    rig: bpy.types.Object,
    source: dict[str, list[float]],
    source_bones: dict[str, tuple[Vector, Vector]],
) -> dict[str, list[float]]:
    vertex_count = len(body.data.vertices)
    runtime = {bone.name: [0.0] * vertex_count for bone in rig.data.bones if bone.use_deform}

    def add(target: str, source_name: str, multiplier: float = 1.0) -> None:
        values = source.get(source_name)
        if values is None:
            return
        for index, value in enumerate(values):
            runtime[target][index] += value * multiplier

    torso_values = source.get("SPINE", [0.0] * vertex_count)
    torso_rear_y = source_bones["SPINE"][0].y
    torso_front_y = source_bones["SPINE"][1].y
    torso_range = max(abs(torso_rear_y - torso_front_y), 0.10)
    for index, value in enumerate(torso_values):
        front_amount = min(max((torso_rear_y - body.data.vertices[index].co.y) / torso_range, 0.0), 1.0)
        runtime["Spine"][index] += value * (1.0 - front_amount)
        runtime["Chest"][index] += value * front_amount
    add("Neck", "NECK")
    add("Head", "root.004")
    add("Chest", "shoulder_L")
    add("Leg_LF", "upperarm_L")
    add("Lower_LF", "LEG_F_L")
    add("Paw_LF", "foot_F_L")
    add("Chest", "shoulder_R")
    add("Leg_RF", "upperarm_R")
    add("Lower_RF", "LEG_F_R")
    add("Paw_RF", "foot_F_R")
    add("Spine", "pelvis_L")
    add("Leg_LH", "thigh_L")
    add("Lower_LH", "LEG_B_L")
    add("Paw_LH", "foot_B_L")
    add("Spine", "pelvis_R")
    add("Leg_RH", "thigh_R")
    add("Lower_RH", "LEG_B_R")
    add("Paw_RH", "foot_B_R")
    add("Tail", "tailbone")
    add("TailTip", "TAIL")

    for vertex in body.data.vertices:
        point = vertex.co
        if point.y < min(rig.data.bones["Ear_L"].head_local.y, rig.data.bones["Ear_R"].head_local.y) + 0.28 and point.z > min(rig.data.bones["Ear_L"].head_local.z, rig.data.bones["Ear_R"].head_local.z):
            ear_name = "Ear_L" if point.x < 0.0 else "Ear_R"
            head_weight = runtime["Head"][vertex.index]
            ear_share = min(max((point.z - 1.28) / 0.52, 0.0), 0.82)
            runtime["Head"][vertex.index] = head_weight * (1.0 - ear_share)
            runtime[ear_name][vertex.index] += head_weight * ear_share

        influences = [(name, values[vertex.index]) for name, values in runtime.items() if values[vertex.index] > 0.000001]
        influences.sort(key=lambda item: item[1], reverse=True)
        retained = influences[:4]
        total = sum(value for _name, value in retained)
        if total <= 0.000001:
            nearest = min(
                ("Spine", "Chest", "Neck", "Head"),
                key=lambda name: (point - rig.data.bones[name].head_local.lerp(rig.data.bones[name].tail_local, 0.5)).length,
            )
            retained = [(nearest, 1.0)]
            total = 1.0
        retained_names = {name for name, _value in retained}
        for name, values in runtime.items():
            values[vertex.index] = values[vertex.index] / total if name in retained_names else 0.0
    return runtime


def add_rigid_detail_ellipsoid(
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
    PIPELINE.rigid_skin(obj, rig, bone_name)
    return obj


def add_authored_details(
    rig: bpy.types.Object,
    body: bpy.types.Object,
    materials: dict[str, bpy.types.Material],
    hero: bool,
) -> list[bpy.types.Object]:
    details: list[bpy.types.Object] = []
    minimum_y = min(vertex.co.y for vertex in body.data.vertices)
    nose_candidates = [
        vertex.co.copy()
        for vertex in body.data.vertices
        if vertex.co.y < minimum_y + 0.11 and vertex.co.z > 0.45 and abs(vertex.co.x) < 0.28
    ]
    nose_position = (
        sum(nose_candidates, Vector()) / len(nose_candidates)
        if nose_candidates
        else rig.data.bones["Head"].tail_local.copy()
    )
    nose_position.y -= 0.025
    details.append(
        add_rigid_detail_ellipsoid(
            "FoxWetNoseDetail",
            Vector(nose_position),
            Vector((0.080, 0.065, 0.070)),
            materials["wet"],
            rig,
            "Head",
            hero,
        )
    )
    return details


def attach_socket(name: str, position: Vector, rig: bpy.types.Object, bone_name: str) -> None:
    socket = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(socket)
    socket.empty_display_type = "SPHERE"
    socket.empty_display_size = 0.08
    socket.parent = rig
    socket.parent_type = "BONE"
    socket.parent_bone = bone_name
    socket.matrix_world = Matrix.Translation(position)


def attach_sockets(rig: bpy.types.Object) -> None:
    head = rig.data.bones["Head"]
    head_direction = (head.tail_local - head.head_local).normalized()
    attach_socket("SkillSocket_Mouth", head.tail_local + head_direction * 0.10, rig, "Head")
    chest = rig.data.bones["Chest"]
    attach_socket("SkillSocket_Chest", chest.head_local.lerp(chest.tail_local, 0.5), rig, "Chest")


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
    source_file = source_dir / SOURCE_BASENAME
    if not source_file.is_file():
        raise RuntimeError(f"missing CC0 fox source: {source_file}")
    bpy.ops.wm.open_mainfile(filepath=str(source_file))
    body = bpy.data.objects.get("Fox")
    source_rig = bpy.data.objects.get("Fox_Armature")
    if body is None or body.type != "MESH" or source_rig is None or source_rig.type != "ARMATURE":
        raise RuntimeError("CC0 fox source is missing the Fox mesh or Fox_Armature")
    detach_source_body(body)
    apply_source_geometry_modifiers(body)
    bake_world_transform(body)
    center_x, ground_translation = normalize_anatomy(body)
    source_bones = capture_source_bones(source_rig, center_x, ground_translation)
    shape_adult_red_fox(body)
    reshape_source_bones(source_bones)
    keep_only_source_body(body)
    clear_source_animation()
    apply_authored_subdivision(body, hero)
    source_weights = source_group_weights(body)

    cfg = PIPELINE.config_for("fox")
    rig = build_authored_runtime_rig(source_bones, body)
    rig["skin_mode"] = "cc0_authored_source_retarget"
    rig["source_sha256"] = SOURCE_SHA256
    rig["source_zip_sha256"] = ZIP_SHA256
    rig["anatomy_profile"] = "authored_adult_red_fox_subdivision_v2"
    body.name = "FoxOrganicBodyV2_SourceConnected"
    body.data.name = "FoxOrganicBodyV2SourceMesh"
    for group in list(body.vertex_groups):
        body.vertex_groups.remove(group)
    runtime_weights = mapped_runtime_weights(body, rig, source_weights, source_bones)
    PIPELINE.add_armature_weights(body, rig, runtime_weights)

    texture_size = 512 if hero else 256
    materials = {
        "body": textured_material(source_dir, texture_size),
        "wet": solid_material("fox_cinematic_wet_nose_pbr", (0.020, 0.024, 0.026, 1.0), 0.22),
    }
    materials["tail"] = materials["body"].copy()
    materials["tail"].name = "fox_cinematic_tail_accent_pbr"
    materials["tail"].diffuse_color = (0.92, 0.91, 0.86, 1.0)
    tail_principled = materials["tail"].node_tree.nodes.get("Principled BSDF")
    if tail_principled is not None:
        tail_principled.inputs["Roughness"].default_value = 0.88
    replace_materials(body, materials["body"], materials["tail"])
    details = add_authored_details(rig, body, materials, hero)
    attach_sockets(rig)
    PIPELINE.create_ground_actions(rig, cfg)

    profile = "hero" if hero else "mobile"
    output = output_root / "fox" / f"fox_{profile}.glb"
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
        print(f"CINEMATIC_FOX_OK: {profile} / {triangles} triangles / {vertices} vertices / {bones} bones")


if __name__ == "__main__":
    main()
