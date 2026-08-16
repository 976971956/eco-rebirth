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
    parser.add_argument("--species", choices=("rabbit", "wolf"), action="append")
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


def attach_albedo_texture(material: bpy.types.Material, texture_path: Path) -> None:
    if not texture_path.is_file() or material.node_tree is None:
        return
    principled = material.node_tree.nodes.get("Principled BSDF")
    if principled is None:
        return
    image = bpy.data.images.load(str(texture_path), check_existing=True)
    image.colorspace_settings.name = "sRGB"
    texture = material.node_tree.nodes.new("ShaderNodeTexImage")
    texture.name = "AIWolfFurAlbedo"
    texture.image = image
    texture.extension = "REPEAT"
    material.node_tree.links.new(texture.outputs["Color"], principled.inputs["Base Color"])


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


def authored_mesh(
    name: str,
    vertices: list[tuple[float, float, float]],
    faces: list[tuple[int, ...]],
    materials: list[bpy.types.Material],
    material_indices: list[int] | None = None,
    subdivision: int = 0,
) -> bpy.types.Object:
    """Create a smooth authored mesh in Godot coordinates.

    The V3 metaball body was useful as a robust mobile baseline, but it rounded
    away the wolf's rib cage, waist, muzzle and digitigrade silhouette.  The
    cinematic sample uses explicit cross sections and keeps that topology as the
    deterministic source of truth.
    """
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata([g2b(vertex) for vertex in vertices], [], faces)
    mesh.validate(clean_customdata=False)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for material in materials:
        mesh.materials.append(material)
    if material_indices is not None:
        for polygon, material_index in zip(mesh.polygons, material_indices):
            polygon.material_index = max(0, min(material_index, len(materials) - 1))
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    if subdivision > 0:
        modifier = obj.modifiers.new("CinematicSubdivision", "SUBSURF")
        modifier.subdivision_type = "CATMULL_CLARK"
        modifier.levels = subdivision
        modifier.render_levels = subdivision
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.select_set(False)
    return obj


def lofted_body(
    name: str,
    rings: list[tuple[float, float, float, float]],
    materials: list[bpy.types.Material],
    hero: bool,
) -> bpy.types.Object:
    """Build one connected head/neck/torso surface from anatomical sections."""
    radial = 28 if hero else 16
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, ...]] = []
    material_indices: list[int] = []
    face_uvs: list[list[tuple[float, float]]] = []
    for z, center_y, radius_x, radius_y in rings:
        for radial_index in range(radial):
            angle = math.tau * radial_index / radial
            vertices.append((math.cos(angle) * radius_x, center_y + math.sin(angle) * radius_y, z))
    for ring_index in range(len(rings) - 1):
        for radial_index in range(radial):
            next_radial = (radial_index + 1) % radial
            current = ring_index * radial + radial_index
            next_on_ring = ring_index * radial + next_radial
            next_ring = (ring_index + 1) * radial + radial_index
            next_ring_next = (ring_index + 1) * radial + next_radial
            faces.append((current, next_ring, next_ring_next, next_on_ring))
            u0 = radial_index / radial * 3.0
            u1 = (radial_index + 1) / radial * 3.0
            v0 = ring_index / (len(rings) - 1) * 4.0
            v1 = (ring_index + 1) / (len(rings) - 1) * 4.0
            face_uvs.append([(u0, v0), (u0, v1), (u1, v1), (u1, v0)])
            angle = math.tau * (radial_index + 0.5) / radial
            average_z = (rings[ring_index][0] + rings[ring_index + 1][0]) * 0.5
            # Keep the textured coat continuous over the back. A former hard
            # charcoal cap made the animal read like an orca in gameplay views.
            # The light material is now limited to the throat and lower belly.
            if math.sin(angle) < -0.78 or (-2.30 < average_z < -1.84 and math.sin(angle) < -0.18):
                material_indices.append(2)  # cream throat, belly and muzzle
            else:
                material_indices.append(0)
    rear_center = len(vertices)
    vertices.append((0.0, rings[0][1], rings[0][0]))
    front_center = len(vertices)
    vertices.append((0.0, rings[-1][1], rings[-1][0]))
    for radial_index in range(radial):
        next_radial = (radial_index + 1) % radial
        faces.append((rear_center, next_radial, radial_index))
        material_indices.append(0)
        face_uvs.append([(0.5, 0.5), (1.0, 0.0), (0.0, 0.0)])
        last_ring = (len(rings) - 1) * radial
        faces.append((front_center, last_ring + radial_index, last_ring + next_radial))
        material_indices.append(2)
        face_uvs.append([(0.5, 0.5), (0.0, 1.0), (1.0, 1.0)])
    obj = authored_mesh(name, vertices, faces, materials, material_indices, 0)
    uv_layer = obj.data.uv_layers.new(name="UVMap")
    for polygon, polygon_uvs in zip(obj.data.polygons, face_uvs):
        for loop_index, uv in zip(polygon.loop_indices, polygon_uvs):
            uv_layer.data[loop_index].uv = uv
    modifier = obj.modifiers.new("CinematicSubdivision", "SUBSURF")
    modifier.subdivision_type = "CATMULL_CLARK"
    modifier.levels = 2 if hero else 1
    modifier.render_levels = modifier.levels
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)
    return obj


def tapered_limb(
    name: str,
    start: tuple[float, float, float],
    end: tuple[float, float, float],
    start_radius: float,
    end_radius: float,
    material: bpy.types.Material,
    hero: bool,
) -> bpy.types.Object:
    start_blender = Vector(g2b(start))
    end_blender = Vector(g2b(end))
    direction = end_blender - start_blender
    bpy.ops.mesh.primitive_cone_add(
        vertices=20 if hero else 12,
        radius1=end_radius,
        radius2=start_radius,
        depth=max(direction.length, 0.01),
        end_fill_type="NGON",
        location=(start_blender + end_blender) * 0.5,
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0.0, 0.0, 1.0)).rotation_difference(direction.normalized())
    obj.data.materials.append(material)
    bevel = obj.modifiers.new("AnatomyBevel", "BEVEL")
    bevel.width = min(start_radius, end_radius) * 0.38
    bevel.segments = 3 if hero else 1
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def curved_tube(
    name: str,
    points: list[tuple[tuple[float, float, float], float]],
    material: bpy.types.Material,
    hero: bool,
) -> bpy.types.Object:
    radial = 18 if hero else 10
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, ...]] = []
    for (center_x, center_y, center_z), radius in points:
        for radial_index in range(radial):
            angle = math.tau * radial_index / radial
            vertices.append((center_x + math.cos(angle) * radius, center_y + math.sin(angle) * radius, center_z))
    for point_index in range(len(points) - 1):
        for radial_index in range(radial):
            next_radial = (radial_index + 1) % radial
            current = point_index * radial + radial_index
            next_ring = (point_index + 1) * radial + radial_index
            faces.append((current, next_ring, (point_index + 1) * radial + next_radial, point_index * radial + next_radial))
    return authored_mesh(name, vertices, faces, [material], [0] * len(faces), 1 if hero else 0)


def triangular_ear(
    name: str,
    side: float,
    outer: bpy.types.Material,
    inner: bpy.types.Material,
    hero: bool,
) -> list[bpy.types.Object]:
    center_x = side * 0.285
    base_y, base_z = 1.99, -1.52
    tip_y, tip_z = 2.52, -1.45
    half_width = 0.22
    thickness = 0.105
    vertices = [
        (center_x - half_width, base_y, base_z - thickness),
        (center_x + half_width, base_y, base_z - thickness),
        (center_x, tip_y, tip_z - thickness * 0.45),
        (center_x - half_width, base_y, base_z + thickness),
        (center_x + half_width, base_y, base_z + thickness),
        (center_x, tip_y, tip_z + thickness * 0.45),
    ]
    faces = [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
    ear = authored_mesh(name, vertices, faces, [outer], [0] * len(faces), 1 if hero else 0)
    result = [ear]
    if hero:
        inner_vertices = [
            (center_x - half_width * 0.56, base_y + 0.045, base_z - thickness * 1.04),
            (center_x + half_width * 0.56, base_y + 0.045, base_z - thickness * 1.04),
            (center_x, tip_y - 0.12, tip_z - thickness * 0.54),
        ]
        inner_panel = authored_mesh(f"{name}InnerDetail", inner_vertices, [(0, 1, 2)], [inner], [0], 1)
        result.append(inner_panel)
    return result


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
        bone(edit, "Jaw", (0.0, 1.31, -1.56), (0.0, 1.25, -2.02), head)
        leg_anchors = {
            "LF": ((-0.34, 1.02, -0.62), (-0.33, 0.64, -0.54), (-0.34, 0.25, -0.76), (-0.34, 0.10, -1.02)),
            "RF": ((0.34, 1.02, -0.62), (0.33, 0.64, -0.54), (0.34, 0.25, -0.76), (0.34, 0.10, -1.02)),
            "LH": ((-0.46, 1.00, 0.62), (-0.50, 0.61, 0.30), (-0.50, 0.24, 0.67), (-0.50, 0.10, -0.10)),
            "RH": ((0.46, 1.00, 0.62), (0.50, 0.61, 0.30), (0.50, 0.24, 0.67), (0.50, 0.10, -0.10)),
        }
        ear_anchors = {
            "L": ((-0.20, 1.59, -1.28), (-0.24, 2.70, -1.17)),
            "R": ((0.20, 1.59, -1.28), (0.24, 2.65, -1.18)),
        }
        tail_points = ((0.0, 1.15, 0.88), (0.0, 1.17, 1.16), (0.0, 1.16, 1.42))
    else:
        spine = bone(edit, "Spine", (0.0, 1.30, 1.10), (0.0, 1.39, 0.10), root)
        chest = bone(edit, "Chest", (0.0, 1.39, 0.10), (0.0, 1.55, -0.78), spine)
        neck = bone(edit, "Neck", (0.0, 1.55, -0.78), (0.0, 1.76, -1.42), chest)
        head = bone(edit, "Head", (0.0, 1.76, -1.42), (0.0, 1.60, -2.48), neck)
        bone(edit, "Jaw", (0.0, 1.61, -1.78), (0.0, 1.48, -2.48), head)
        leg_anchors = {
            "LF": ((-0.51, 1.43, -0.61), (-0.50, 0.76, -0.57), (-0.49, 0.15, -0.88)),
            "RF": ((0.51, 1.43, -0.61), (0.50, 0.76, -0.57), (0.49, 0.15, -0.88)),
            "LH": ((-0.47, 1.32, 0.66), (-0.50, 0.88, 0.42), (-0.48, 0.15, 0.34)),
            "RH": ((0.47, 1.32, 0.66), (0.50, 0.88, 0.42), (0.48, 0.15, 0.34)),
        }
        ear_anchors = {
            "L": ((-0.28, 1.99, -1.52), (-0.28, 2.52, -1.45)),
            "R": ((0.28, 1.99, -1.52), (0.28, 2.52, -1.45)),
        }
        tail_points = ((0.0, 1.34, 1.02), (0.10, 0.50, 2.48))

    for suffix, points in leg_anchors.items():
        upper, joint = points[0], points[1]
        upper_bone = bone(edit, f"Leg_{suffix}", upper, joint, chest if suffix.endswith("F") else spine)
        if len(points) == 4:
            ankle, paw = points[2], points[3]
            lower_bone = bone(edit, f"Lower_{suffix}", joint, ankle, upper_bone)
            bone(edit, f"Paw_{suffix}", ankle, paw, lower_bone)
        else:
            bone(edit, f"Paw_{suffix}", joint, points[2], upper_bone)
    for suffix, points in ear_anchors.items():
        bone(edit, f"Ear_{suffix}", points[0], points[1], head)
    if len(tail_points) == 3:
        tail = bone(edit, "Tail", tail_points[0], tail_points[1], spine)
        bone(edit, "TailTip", tail_points[1], tail_points[2], tail)
    else:
        bone(edit, "Tail", tail_points[0], tail_points[1], spine)
    bpy.ops.object.mode_set(mode="OBJECT")
    rig["eco_species"] = species
    rig["eco_rig_family"] = "lagomorph_v3" if species == "rabbit" else "canid_cinematic_v1"
    if species == "rabbit":
        rig["anatomy_profile"] = "v4_lagomorph_three_segment_limbs"
        rig["limb_segments"] = 3
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
            "Leg_LF": (-0.34, 0.83, -0.59, 0.31, 0.42, 0.33),
            "Leg_RF": (0.34, 0.83, -0.59, 0.31, 0.42, 0.33),
            "Leg_LH": (-0.46, 0.82, 0.48, 0.40, 0.48, 0.43),
            "Leg_RH": (0.46, 0.82, 0.48, 0.40, 0.48, 0.43),
            "Lower_LF": (-0.34, 0.44, -0.65, 0.27, 0.38, 0.36),
            "Lower_RF": (0.34, 0.44, -0.65, 0.27, 0.38, 0.36),
            "Lower_LH": (-0.50, 0.42, 0.49, 0.33, 0.40, 0.48),
            "Lower_RH": (0.50, 0.42, 0.49, 0.33, 0.40, 0.48),
            "Paw_LF": (-0.34, 0.16, -0.93, 0.26, 0.25, 0.40),
            "Paw_RF": (0.34, 0.16, -0.93, 0.26, 0.25, 0.40),
            "Paw_LH": (-0.50, 0.16, 0.17, 0.32, 0.28, 0.64),
            "Paw_RH": (0.50, 0.16, 0.17, 0.32, 0.28, 0.64),
            "Ear_L": (-0.23, 2.15, -1.25, 0.24, 0.75, 0.27),
            "Ear_R": (0.23, 2.15, -1.25, 0.24, 0.75, 0.27),
            "Tail": (0.0, 1.17, 1.10, 0.38, 0.38, 0.32),
            "TailTip": (0.0, 1.17, 1.34, 0.38, 0.38, 0.34),
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


def cinematic_wolf_body_skin(obj: bpy.types.Object, rig: bpy.types.Object) -> None:
    anchors = {"Spine": 0.58, "Chest": -0.34, "Neck": -1.18, "Head": -2.08}
    ranges = {"Spine": 1.05, "Chest": 0.92, "Neck": 0.70, "Head": 0.92}
    weights = {name: [] for name in anchors}
    for vertex in obj.data.vertices:
        godot_z = vertex.co.y
        raw = {
            name: max(0.0, 1.0 - abs(godot_z - anchor) / ranges[name]) ** 2.3
            for name, anchor in anchors.items()
        }
        if godot_z < -1.72:
            raw["Head"] *= 1.75
        elif godot_z < -1.05:
            raw["Neck"] *= 1.38
        total = sum(raw.values())
        if total <= 0.0001:
            nearest = min(anchors, key=lambda item: abs(godot_z - anchors[item]))
            raw[nearest] = 1.0
            total = 1.0
        for name in anchors:
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


def build_cinematic_wolf_parts(hero: bool, rig: bpy.types.Object) -> list[bpy.types.Object]:
    coat = pbr_material("wolf_cinematic_coat_pbr", (0.285, 0.30, 0.295, 1.0), 0.80)
    dark = pbr_material("wolf_cinematic_saddle_pbr", (0.070, 0.080, 0.085, 1.0), 0.86)
    light = pbr_material("wolf_cinematic_cream_pbr", (0.61, 0.59, 0.53, 1.0), 0.84)
    inner_ear = pbr_material("wolf_cinematic_inner_ear_pbr", (0.24, 0.15, 0.14, 1.0), 0.74)
    skin = pbr_material("wolf_cinematic_nose_pbr", (0.018, 0.021, 0.022, 1.0), 0.22)
    amber = pbr_material("wolf_cinematic_iris_pbr", (0.72, 0.35, 0.055, 1.0), 0.14)
    pupil = pbr_material("wolf_cinematic_pupil_pbr", (0.005, 0.006, 0.005, 1.0), 0.10)
    catchlight = pbr_material("wolf_cinematic_catchlight_pbr", (0.96, 0.93, 0.82, 1.0), 0.04)
    attach_albedo_texture(
        coat,
        Path(__file__).resolve().parents[2] / "assets/textures/animals/wolf/wolf_cinematic_fur_albedo.png",
    )

    # Sections follow the reference sheet from rump to nose.  The shoulder peak,
    # deep rib cage, tucked waist and long narrow muzzle are authored separately
    # instead of being inferred from one generic quadruped capsule.
    rings = [
        (1.10, 1.31, 0.36, 0.40),
        (0.82, 1.35, 0.48, 0.50),
        (0.48, 1.39, 0.52, 0.53),
        (0.16, 1.44, 0.47, 0.49),
        (-0.18, 1.47, 0.54, 0.59),
        (-0.52, 1.53, 0.60, 0.64),
        (-0.78, 1.61, 0.56, 0.59),
        (-1.04, 1.70, 0.45, 0.52),
        (-1.28, 1.79, 0.41, 0.44),
        (-1.52, 1.82, 0.40, 0.39),
        (-1.76, 1.78, 0.36, 0.32),
        (-2.00, 1.70, 0.30, 0.25),
        (-2.24, 1.63, 0.25, 0.20),
        (-2.46, 1.59, 0.20, 0.15),
        (-2.58, 1.59, 0.14, 0.11),
    ]
    body = lofted_body("WolfOrganicBodyV2", rings, [coat, dark, light], hero)
    cinematic_wolf_body_skin(body, rig)
    parts = [body]

    def add_sphere(name: str, position, scale, material, bone_name: str) -> bpy.types.Object:
        obj = uv_sphere(name, position, scale, material, hero)
        rigid_skin(obj, rig, bone_name)
        parts.append(obj)
        return obj

    def add_limb(name: str, start, end, start_radius, end_radius, material, bone_name: str) -> bpy.types.Object:
        obj = tapered_limb(name, start, end, start_radius, end_radius, material, hero)
        rigid_skin(obj, rig, bone_name)
        parts.append(obj)
        return obj

    leg_layout = {
        "LF": ((-0.51, 1.43, -0.61), (-0.50, 0.76, -0.57), (-0.49, 0.31, -0.70), (-0.49, 0.13, -0.90)),
        "RF": ((0.51, 1.43, -0.61), (0.50, 0.76, -0.57), (0.49, 0.31, -0.70), (0.49, 0.13, -0.90)),
        "LH": ((-0.47, 1.32, 0.66), (-0.50, 0.88, 0.42), (-0.50, 0.38, 0.73), (-0.48, 0.13, 0.34)),
        "RH": ((0.47, 1.32, 0.66), (0.50, 0.88, 0.42), (0.50, 0.38, 0.73), (0.48, 0.13, 0.34)),
    }
    for suffix, (hip, knee, hock, paw_center) in leg_layout.items():
        front = suffix.endswith("F")
        upper_bone = f"Leg_{suffix}"
        lower_bone = f"Lower_{suffix}"
        paw_bone = f"Paw_{suffix}"
        add_limb(f"UpperLeg_{suffix}", hip, knee, 0.175 if front else 0.205, 0.115, coat, upper_bone)
        add_limb(f"LowerLegA_{suffix}", knee, hock, 0.125, 0.084, light if front else coat, lower_bone)
        add_limb(f"LowerLegB_{suffix}", hock, paw_center, 0.092, 0.065, light, paw_bone)
        add_sphere(f"KneeJoint_{suffix}", knee, (0.125, 0.14, 0.125), coat, lower_bone)
        if hero:
            add_sphere(f"HockJoint_{suffix}", hock, (0.092, 0.105, 0.092), light, paw_bone)
        paw_z = paw_center[2] - (0.09 if front else 0.13)
        add_sphere(f"PawBody_{suffix}", (paw_center[0], 0.09, paw_z), (0.165, 0.085, 0.235), light, paw_bone)
        toe_offsets = (-0.075, 0.0, 0.075) if hero else (-0.052, 0.052)
        for toe_index, toe_offset in enumerate(toe_offsets):
            toe_position = (paw_center[0] + toe_offset, 0.075, paw_z - 0.155)
            add_sphere(f"ToeDetail_{suffix}_{toe_index}", toe_position, (0.050, 0.048, 0.090), light, paw_bone)
            if hero:
                add_limb(
                    f"ClawDetail_{suffix}_{toe_index}",
                    (toe_position[0], 0.082, toe_position[2] - 0.055),
                    (toe_position[0], 0.066, toe_position[2] - 0.125),
                    0.017,
                    0.006,
                    skin,
                    paw_bone,
                )

    tail_points = [
        ((0.0, 1.34, 1.00), 0.30),
        ((0.0, 1.27, 1.30), 0.32),
        ((0.02, 1.13, 1.62), 0.30),
        ((0.04, 0.95, 1.92), 0.27),
        ((0.07, 0.74, 2.20), 0.22),
        ((0.10, 0.53, 2.45), 0.14),
        ((0.12, 0.42, 2.60), 0.055),
    ]
    tail = curved_tube("TailSilhouette", tail_points, dark, hero)
    rigid_skin(tail, rig, "Tail")
    parts.append(tail)

    for suffix, side in (("L", -1.0), ("R", 1.0)):
        for ear_part in triangular_ear(f"EarSilhouette_{suffix}", side, dark, inner_ear, hero):
            rigid_skin(ear_part, rig, f"Ear_{suffix}")
            parts.append(ear_part)

    # A separate lower jaw makes the bite readable while the continuous muzzle
    # keeps the resting silhouette closed and free of visible rig gaps.
    add_limb("LowerJawDetail", (0.0, 1.52, -1.94), (0.0, 1.47, -2.48), 0.15, 0.082, light, "Jaw")
    add_sphere("NoseDetail", (0.0, 1.59, -2.66), (0.145, 0.105, 0.11), skin, "Head")
    for suffix, side in (("L", -1.0), ("R", 1.0)):
        add_sphere(f"MuzzlePadDetail_{suffix}", (side * 0.125, 1.58, -2.35), (0.155, 0.125, 0.20), light, "Head")
        add_sphere(f"EyeIrisDetail_{suffix}", (side * 0.27, 1.85, -1.91), (0.060, 0.068, 0.038), amber, "Head")
        add_sphere(f"EyePupilDetail_{suffix}", (side * 0.27, 1.85, -1.947), (0.020, 0.038, 0.013), pupil, "Head")
        if hero:
            add_sphere(f"EyeCatchlightDetail_{suffix}", (side * 0.258, 1.873, -1.958), (0.009, 0.009, 0.006), catchlight, "Head")

    ruff_count = 11 if hero else 6
    for index in range(ruff_count):
        angle = -1.12 + 2.24 * index / max(ruff_count - 1, 1)
        start = (math.sin(angle) * 0.46, 1.54 + math.cos(angle) * 0.13, -0.92)
        end = (math.sin(angle) * 0.62, 1.39 + math.cos(angle) * 0.18, -0.97)
        add_limb(f"ChestRuffDetail_{index}", start, end, 0.075, 0.012, light, "Chest")

    attach_socket("SkillSocket_Mouth", (0.0, 1.54, -2.78), rig, "Head")
    attach_socket("SkillSocket_Chest", (0.0, 1.50, -0.62), rig, "Chest")
    return parts


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
        jaw = tapered_limb("RabbitLowerJawDetail", (0.0, 1.28, -1.60), (0.0, 1.23, -2.04), 0.13, 0.075, coat_light, hero)
        rigid_skin(jaw, rig, "Jaw")
        parts.append(jaw)
        for side in (-1.0, 1.0):
            eyeball = uv_sphere(f"EyeDetail_{'L' if side < 0 else 'R'}", (side * 0.305, 1.52, -1.67), (0.095, 0.105, 0.075), eye, hero)
            rigid_skin(eyeball, rig, "Head")
            parts.append(eyeball)
        attach_socket("SkillSocket_Mouth", (0.0, 1.34, -2.19), rig, "Head")
        attach_socket("SkillSocket_Chest", (0.0, 1.20, -0.47), rig, "Chest")
        return parts

    return build_cinematic_wolf_parts(hero, rig)


def limb_chain_flex_sign(rig: bpy.types.Object, suffix: str) -> float:
    upper = rig.data.bones[f"Leg_{suffix}"]
    lower = rig.data.bones[f"Lower_{suffix}"]
    upper_vector = (upper.tail_local - upper.head_local).normalized()
    lower_vector = (lower.tail_local - lower.head_local).normalized()
    cross_body = Vector((1.0, 0.0, 0.0))
    signed_angle = math.atan2(cross_body.dot(upper_vector.cross(lower_vector)), upper_vector.dot(lower_vector))
    return 1.0 if signed_angle >= 0.0 else -1.0


def create_actions(rig: bpy.types.Object, species: str) -> None:
    rig.animation_data_create()
    flex_signs = {suffix: limb_chain_flex_sign(rig, suffix) for suffix in LIMBS} if species == "rabbit" else {}
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
            amount = (0.62 if action_name == "locomotion" else 0.92) if species == "rabbit" else (0.46 if action_name == "locomotion" else 0.84)
            for frame_index, frame in enumerate(cycle_frames):
                phase = math.tau * frame_index / (len(cycle_frames) - 1)
                for index, suffix in enumerate(LIMBS):
                    upper = rig.pose.bones[f"Leg_{suffix}"]
                    lower = rig.pose.bones[f"Lower_{suffix}"] if species == "rabbit" else rig.pose.bones[f"Paw_{suffix}"]
                    paw = rig.pose.bones[f"Paw_{suffix}"]
                    if species == "rabbit":
                        is_hind = suffix.endswith("H")
                        curve = math.sin(phase + (0.0 if is_hind else math.pi * 0.78))
                        lift = max(0.0, curve)
                        support = max(0.0, -curve)
                        upper.rotation_euler[0] = amount * curve * (1.0 if is_hind else 0.66)
                        bend = amount * (0.76 if is_hind else 0.52) * (0.95 * lift + 0.08 * support)
                        lower.rotation_euler[0] = flex_signs[suffix] * bend
                        paw.rotation_euler[0] = -flex_signs[suffix] * bend * (0.52 if is_hind else 0.44)
                    else:
                        if action_name == "sprint":
                            gallop_phase = {"LF": math.pi * 0.88, "RF": math.pi * 1.08, "LH": 0.0, "RH": math.pi * 0.18}[suffix]
                            curve = math.sin(phase + gallop_phase)
                            upper.rotation_euler[0] = amount * curve * (1.08 if suffix.endswith("H") else 0.92)
                            lower.rotation_euler[0] = -amount * 0.64 * max(curve, -0.34)
                        else:
                            diagonal_phase = 0.0 if index in (0, 3) else math.pi
                            curve = math.sin(phase + diagonal_phase)
                            upper.rotation_euler[0] = amount * curve
                            lower.rotation_euler[0] = -amount * 0.56 * max(curve, -0.24)
                    upper.keyframe_insert(data_path="rotation_euler", frame=frame, group=upper.name)
                    lower.keyframe_insert(data_path="rotation_euler", frame=frame, group=lower.name)
                    if species == "rabbit":
                        paw.keyframe_insert(data_path="rotation_euler", frame=frame, group=paw.name)
                flex = (0.10 if species == "rabbit" else 0.055 if action_name == "locomotion" else 0.15) * math.cos(phase)
                rig.pose.bones["Spine"].rotation_euler[0] = flex
                rig.pose.bones["Chest"].rotation_euler[0] = -flex * (0.70 if species == "rabbit" else 0.56)
                for name in ("Spine", "Chest"):
                    rig.pose.bones[name].keyframe_insert(data_path="rotation_euler", frame=frame, group=name)
                if species == "wolf":
                    rig.pose.bones["Neck"].rotation_euler[0] = -flex * 0.30
                    rig.pose.bones["Head"].rotation_euler[0] = flex * 0.18
                    rig.pose.bones["Tail"].rotation_euler[1] = math.sin(phase * 0.5) * (0.08 if action_name == "locomotion" else 0.15)
                    for name in ("Neck", "Head", "Tail"):
                        rig.pose.bones[name].keyframe_insert(data_path="rotation_euler", frame=frame, group=name)
        elif action_name == "attack":
            attack_frames = (1, 5, 9, 14, 22) if species == "wolf" else (1, 8, 18)
            attack_curves = (0.0, 0.52, 1.0, 0.64, 0.0) if species == "wolf" else (0.0, 1.0, 0.0)
            for frame, curve in zip(attack_frames, attack_curves):
                rig.pose.bones["Chest"].rotation_euler[0] = (-0.12 if species == "rabbit" else -0.32) * curve
                rig.pose.bones["Neck"].rotation_euler[0] = (-0.04 if species == "rabbit" else -0.18) * curve
                rig.pose.bones["Head"].rotation_euler[0] = (0.12 if species == "rabbit" else 0.34) * curve
                for suffix in ("LF", "RF"):
                    rig.pose.bones[f"Leg_{suffix}"].rotation_euler[0] = (-0.38 if species == "rabbit" else -0.72) * curve
                keyed_names = ["Chest", "Neck", "Head", "Leg_LF", "Leg_RF"]
                if species == "wolf":
                    rig.pose.bones["Jaw"].rotation_euler[0] = -0.46 * math.sin(math.pi * curve)
                    keyed_names.append("Jaw")
                for name in keyed_names:
                    rig.pose.bones[name].keyframe_insert(data_path="rotation_euler", frame=frame, group=name)
        elif action_name == "skill":
            for frame, curve in zip((1, 10, 22), (0.0, 1.0, 0.0)):
                rig.pose.bones["Spine"].rotation_euler[0] = (-0.44 if species == "rabbit" else -0.28) * curve
                for suffix in ("LH", "RH"):
                    rig.pose.bones[f"Leg_{suffix}"].rotation_euler[0] = (1.02 if species == "rabbit" else 0.78) * curve
                    if species == "rabbit":
                        rig.pose.bones[f"Lower_{suffix}"].rotation_euler[0] = flex_signs[suffix] * 0.82 * curve
                        rig.pose.bones[f"Paw_{suffix}"].rotation_euler[0] = -flex_signs[suffix] * 0.42 * curve
                    else:
                        rig.pose.bones[f"Paw_{suffix}"].rotation_euler[0] = -0.50 * curve
                keyed_skill_bones = ["Spine", "Leg_LH", "Leg_RH", "Paw_LH", "Paw_RH"]
                if species == "rabbit":
                    keyed_skill_bones.extend(["Lower_LH", "Lower_RH"])
                for name in keyed_skill_bones:
                    rig.pose.bones[name].keyframe_insert(data_path="rotation_euler", frame=frame, group=name)
                if species == "wolf":
                    rig.pose.bones["Neck"].rotation_euler[0] = -0.22 * curve
                    rig.pose.bones["Head"].rotation_euler[0] = 0.30 * curve
                    rig.pose.bones["Jaw"].rotation_euler[0] = -0.36 * curve
                    for name in ("Neck", "Head", "Jaw"):
                        rig.pose.bones[name].keyframe_insert(data_path="rotation_euler", frame=frame, group=name)
        elif action_name == "hit":
            for frame, curve in zip((1, 6, 15), (0.0, 1.0, 0.0)):
                rig.pose.bones["Spine"].rotation_euler[2] = 0.26 * curve
                rig.pose.bones["Spine"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Spine")
        elif action_name == "eat":
            for frame, curve in zip(frames, (0.0, 1.0, 0.82, 1.0, 0.0)):
                rig.pose.bones["Neck"].rotation_euler[0] = 0.56 * curve
                rig.pose.bones["Head"].rotation_euler[0] = 0.30 * curve
                rig.pose.bones["Neck"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Neck")
                rig.pose.bones["Head"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Head")
                if species == "rabbit":
                    rig.pose.bones["Jaw"].rotation_euler[0] = -0.055 * curve * (1.0 - abs(math.sin(frame * 0.42)))
                    rig.pose.bones["Jaw"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Jaw")
                if species == "wolf":
                    rig.pose.bones["Jaw"].rotation_euler[0] = -0.16 * (1.0 - abs(math.sin(frame * 0.42))) * curve
                    rig.pose.bones["Jaw"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Jaw")
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
                if species == "rabbit":
                    rig.pose.bones["TailTip"].rotation_euler[1] = 0.065 * curve
                    rig.pose.bones["TailTip"].keyframe_insert(data_path="rotation_euler", frame=frame, group="TailTip")
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
    species_targets = tuple(args.species) if args.species else ("rabbit", "wolf")
    for species in species_targets:
        for hero in (True, False):
            triangles, vertices, bones = export_species(species, hero, output_root)
            print(
                f"VERTICAL_SLICE_MODEL_OK: {species} / {'hero' if hero else 'mobile'} / "
                f"{triangles} triangles / {vertices} vertices / {bones} bones"
            )


if __name__ == "__main__":
    main()
