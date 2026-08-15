from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


ACTIONS = ("idle", "locomotion", "sprint", "attack", "skill", "hit", "eat", "death")
LIMBS = ("LF", "RF", "LH", "RH")
BIRDS = ("owl", "eagle")
LONG_BODY = ("snake", "crocodile")
REMAINING_SPECIES = (
    "fox", "deer", "snake", "bear", "boar", "raccoon", "porcupine", "crocodile",
    "capybara", "otter", "lynx", "goat", "wolverine", "bison", "zebra", "elephant",
    "tiger", "monkey", "owl", "moose", "turtle", "cheetah", "rhino", "gorilla",
    "eagle", "hippo", "hyena", "lion",
)


FAMILY_BASE = {
    "canid": dict(width=0.55, height=0.58, length=1.42, leg=0.86, paw=0.18, head=0.43, muzzle=0.50, neck=0.42, tail=1.30, ear=0.34),
    "felid": dict(width=0.62, height=0.62, length=1.58, leg=0.90, paw=0.20, head=0.45, muzzle=0.36, neck=0.40, tail=1.55, ear=0.27),
    "ungulate": dict(width=0.63, height=0.68, length=1.58, leg=1.22, paw=0.14, head=0.42, muzzle=0.50, neck=0.68, tail=0.58, ear=0.32),
    "heavy": dict(width=0.82, height=0.80, length=1.62, leg=0.78, paw=0.25, head=0.55, muzzle=0.48, neck=0.46, tail=0.36, ear=0.22),
    "primate": dict(width=0.72, height=0.78, length=1.12, leg=0.82, paw=0.26, head=0.48, muzzle=0.30, neck=0.30, tail=0.95, ear=0.20),
    "chelonian": dict(width=0.84, height=0.52, length=1.24, leg=0.42, paw=0.24, head=0.32, muzzle=0.24, neck=0.44, tail=0.18, ear=0.0),
}


SPECIES = {
    "fox": dict(family="canid", coat="#bb5d28", accent="#efe3ce", dark="#282523", eye="#d39a38", width=0.48, height=0.50, length=1.30, leg=0.76, tail=1.62, ear=0.43, features=("chest", "black_legs", "tail_tip")),
    "deer": dict(family="ungulate", coat="#8a5533", accent="#e4d0aa", dark="#3e2b21", eye="#39200e", leg=1.34, neck=0.82, tail=0.42, features=("chest", "antlers", "hoof")),
    "bear": dict(family="heavy", coat="#4c3327", accent="#80634c", dark="#1d1816", eye="#25130b", width=0.96, height=0.92, length=1.66, leg=0.72, head=0.62, features=("shoulder_hump", "muzzle_patch", "claws")),
    "boar": dict(family="heavy", coat="#55483b", accent="#8e7459", dark="#24201c", eye="#352014", width=0.78, height=0.70, length=1.55, leg=0.62, head=0.48, muzzle=0.66, tail=0.30, features=("tusks", "ridge_mane", "snout")),
    "raccoon": dict(family="canid", coat="#72736e", accent="#c5c2b3", dark="#202428", eye="#d2a84b", width=0.49, height=0.48, length=1.10, leg=0.58, head=0.44, muzzle=0.34, tail=1.10, ear=0.25, features=("mask", "tail_rings", "hands")),
    "porcupine": dict(family="heavy", coat="#514337", accent="#d7c49b", dark="#28231f", eye="#3a2416", width=0.75, height=0.62, length=1.34, leg=0.48, head=0.40, muzzle=0.40, tail=0.40, features=("quills", "muzzle_patch")),
    "capybara": dict(family="heavy", coat="#936943", accent="#bc956c", dark="#3f3127", eye="#2a160d", width=0.74, height=0.66, length=1.42, leg=0.58, head=0.53, muzzle=0.48, tail=0.08, ear=0.16, features=("muzzle_patch",)),
    "otter": dict(family="canid", coat="#493a2d", accent="#a58b69", dark="#17191a", eye="#392211", width=0.43, height=0.42, length=1.36, leg=0.42, head=0.40, muzzle=0.34, tail=1.34, ear=0.14, features=("chest", "webbed_paws")),
    "lynx": dict(family="felid", coat="#a7794b", accent="#d5bd94", dark="#2d2924", eye="#c9ae42", width=0.53, height=0.57, length=1.20, leg=0.92, tail=0.32, ear=0.42, features=("spots", "ear_tufts", "cheek_ruff")),
    "goat": dict(family="ungulate", coat="#9a8d78", accent="#ded2bc", dark="#433c34", eye="#a88d45", width=0.50, height=0.56, length=1.20, leg=0.90, neck=0.55, tail=0.30, features=("horns", "beard", "hoof")),
    "wolverine": dict(family="canid", coat="#322b27", accent="#b18a58", dark="#121416", eye="#7f5523", width=0.64, height=0.58, length=1.24, leg=0.56, head=0.48, muzzle=0.40, tail=0.72, ear=0.18, features=("side_band", "claws")),
    "bison": dict(family="ungulate", coat="#4a3526", accent="#8b6b47", dark="#1d1a17", eye="#26150c", width=0.92, height=0.98, length=1.66, leg=0.94, head=0.57, muzzle=0.55, neck=0.58, tail=0.70, features=("shoulder_hump", "horns", "ridge_mane", "beard", "hoof")),
    "zebra": dict(family="ungulate", coat="#d7d3c6", accent="#eee9da", dark="#26282a", eye="#39261a", width=0.58, height=0.64, length=1.50, leg=1.20, neck=0.76, tail=0.78, features=("stripes", "ridge_mane", "hoof")),
    "elephant": dict(family="heavy", coat="#777a78", accent="#9a8e86", dark="#343739", eye="#4a2b18", width=1.12, height=1.10, length=1.72, leg=1.16, paw=0.34, head=0.76, muzzle=0.20, neck=0.28, tail=0.72, ear=0.74, features=("trunk", "tusks", "elephant_ears")),
    "tiger": dict(family="felid", coat="#bc6a2f", accent="#e8cfaa", dark="#1b1d1e", eye="#e0b54d", width=0.68, height=0.68, length=1.70, leg=0.90, head=0.49, tail=1.52, features=("stripes", "chest")),
    "monkey": dict(family="primate", coat="#75513b", accent="#c49a75", dark="#28211e", eye="#3a2014", width=0.50, height=0.62, length=0.94, leg=0.72, head=0.43, tail=1.42, features=("face_patch", "hands", "long_arms")),
    "moose": dict(family="ungulate", coat="#4c3a2e", accent="#8e735a", dark="#211d1a", eye="#352015", width=0.74, height=0.78, length=1.66, leg=1.48, head=0.52, muzzle=0.62, neck=0.82, tail=0.24, ear=0.37, features=("palm_antlers", "dewlap", "hoof")),
    "turtle": dict(family="chelonian", coat="#66734f", accent="#9a8652", dark="#323a2b", eye="#19170d", features=("shell", "beak")),
    "cheetah": dict(family="felid", coat="#c59b55", accent="#e8d5a9", dark="#252525", eye="#bf9a3c", width=0.50, height=0.54, length=1.58, leg=1.02, head=0.39, muzzle=0.32, tail=1.70, features=("spots", "tear_marks")),
    "rhino": dict(family="heavy", coat="#77766e", accent="#99978d", dark="#3f403c", eye="#322218", width=1.03, height=0.94, length=1.78, leg=0.82, paw=0.30, head=0.64, muzzle=0.70, neck=0.44, tail=0.42, ear=0.20, features=("rhino_horns", "armor_folds")),
    "gorilla": dict(family="primate", coat="#24282a", accent="#777a78", dark="#111314", eye="#4b2d19", width=0.96, height=0.98, length=1.10, leg=0.78, head=0.56, tail=0.0, features=("silverback", "hands", "long_arms", "brow")),
    "hippo": dict(family="heavy", coat="#756d70", accent="#a77d80", dark="#343135", eye="#3d261b", width=1.18, height=0.92, length=1.72, leg=0.56, paw=0.32, head=0.76, muzzle=0.78, neck=0.30, tail=0.24, ear=0.16, features=("wide_muzzle", "tusks")),
    "hyena": dict(family="canid", coat="#9b7445", accent="#c6a66c", dark="#2b2924", eye="#9e6b27", width=0.61, height=0.68, length=1.42, leg=0.82, head=0.50, muzzle=0.46, tail=0.70, ear=0.39, features=("spots", "ridge_mane", "high_shoulders")),
    "lion": dict(family="felid", coat="#b58a4b", accent="#d8bc83", dark="#5b3b24", eye="#d1a13d", width=0.74, height=0.74, length=1.66, leg=0.92, head=0.54, tail=1.50, features=("mane", "chest", "tail_tuft")),
}


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description="Build the remaining Eco Rebirth V2 species")
    parser.add_argument("--output-root", required=True)
    parser.add_argument("--species", nargs="*", choices=REMAINING_SPECIES)
    return parser.parse_args(argv)


def g2b(value: tuple[float, float, float]) -> tuple[float, float, float]:
    return value[0], value[2], value[1]


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.metaballs, bpy.data.armatures, bpy.data.materials, bpy.data.actions):
        for datablock in list(datablocks):
            datablocks.remove(datablock)


def rgba(value: str) -> tuple[float, float, float, float]:
    value = value.removeprefix("#")
    return tuple(int(value[index:index + 2], 16) / 255.0 for index in (0, 2, 4)) + (1.0,)


def pbr_material(name: str, color: str, roughness: float, metallic: float = 0.0) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = rgba(color)
    material.use_nodes = True
    principled = material.node_tree.nodes.get("Principled BSDF")
    if principled is not None:
        principled.inputs["Base Color"].default_value = rgba(color)
        principled.inputs["Roughness"].default_value = roughness
        principled.inputs["Metallic"].default_value = metallic
    return material


def metaball_mesh(name: str, elements: list[tuple[tuple[float, float, float], tuple[float, float, float], float]], material: bpy.types.Material, hero: bool) -> bpy.types.Object:
    data = bpy.data.metaballs.new(f"{name}Surface")
    data.resolution = 0.050 if hero else 0.095
    data.render_resolution = 0.038 if hero else 0.070
    data.threshold = 0.62
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    for position, scale, stiffness in elements:
        element = data.elements.new(type="ELLIPSOID")
        element.co = g2b(position)
        element.radius = 1.0
        element.size_x, element.size_y, element.size_z = scale[0], scale[2], scale[1]
        element.stiffness = stiffness
    obj.data.materials.append(material)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.active_object
    obj.name = name
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def uv_sphere(name: str, position: tuple[float, float, float], scale: tuple[float, float, float], material: bpy.types.Material, hero: bool) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16 if hero else 10, ring_count=10 if hero else 6, location=g2b(position))
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (scale[0], scale[2], scale[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def cone_between(name: str, start: tuple[float, float, float], end: tuple[float, float, float], radius: float, material: bpy.types.Material, hero: bool) -> bpy.types.Object:
    start_b = Vector(g2b(start))
    end_b = Vector(g2b(end))
    delta = end_b - start_b
    bpy.ops.mesh.primitive_cone_add(vertices=10 if hero else 7, radius1=radius, radius2=radius * 0.08, depth=delta.length, location=(start_b + end_b) * 0.5)
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = delta.to_track_quat("Z", "Y")
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def add_bone(edit_bones, name: str, head: tuple[float, float, float], tail: tuple[float, float, float], parent=None):
    result = edit_bones.new(name)
    result.head = g2b(head)
    result.tail = g2b(tail)
    result.parent = parent
    return result


def add_armature_weights(obj: bpy.types.Object, rig: bpy.types.Object, weights: dict[str, list[float]]) -> None:
    modifier = obj.modifiers.new("SpeciesArmature", "ARMATURE")
    modifier.object = rig
    for bone_name, values in weights.items():
        group = obj.vertex_groups.new(name=bone_name)
        for vertex_index, value in enumerate(values):
            if value > 0.001:
                group.add([vertex_index], value, "REPLACE")


def rigid_skin(obj: bpy.types.Object, rig: bpy.types.Object, bone_name: str) -> None:
    add_armature_weights(obj, rig, {bone_name: [1.0] * len(obj.data.vertices)})


def attach_socket(name: str, position: tuple[float, float, float], rig: bpy.types.Object, bone_name: str) -> bpy.types.Object:
    socket = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(socket)
    socket.empty_display_type = "SPHERE"
    socket.empty_display_size = 0.08
    socket.parent = rig
    socket.parent_type = "BONE"
    socket.parent_bone = bone_name
    # Bone parenting changes the empty's local basis. Assign the desired world
    # transform afterwards so Godot receives a true bone-relative socket instead
    # of interpreting a model-space position a second time.
    socket.matrix_world = Matrix.Translation(g2b(position))
    return socket


def config_for(species: str) -> dict:
    specific = SPECIES[species]
    result = dict(FAMILY_BASE[specific["family"]])
    result.update(specific)
    result["features"] = set(result.get("features", ()))
    return result


def ground_layout(cfg: dict) -> dict:
    body_y = cfg["leg"] + cfg["height"] * 0.72
    shoulder_y = body_y + (0.18 if "high_shoulders" in cfg["features"] or "shoulder_hump" in cfg["features"] else 0.04)
    front_z = -cfg["length"] * 0.36
    rear_z = cfg["length"] * 0.36
    neck_z = -cfg["length"] * 0.78
    head_z = neck_z - cfg["neck"] * 0.62
    head_y = shoulder_y + cfg["neck"] * (0.68 if cfg["family"] != "chelonian" else 0.18)
    muzzle_z = head_z - cfg["muzzle"]
    return dict(body_y=body_y, shoulder_y=shoulder_y, front_z=front_z, rear_z=rear_z, neck_z=neck_z, head_z=head_z, head_y=head_y, muzzle_z=muzzle_z)


def build_ground_rig(species: str, cfg: dict, layout: dict) -> tuple[bpy.types.Object, dict[str, tuple[float, float, float]]]:
    bpy.ops.object.armature_add(enter_editmode=True, location=(0.0, 0.0, 0.0))
    rig = bpy.context.active_object
    rig.name = "SpeciesSkeleton3D"
    rig.data.name = f"{species.title()}V2Rig"
    edit = rig.data.edit_bones
    root = edit[0]
    root.name = "Root"
    root.head = g2b((0.0, 0.05, 0.25))
    root.tail = g2b((0.0, 0.55, 0.25))
    anchors: dict[str, tuple[float, float, float]] = {}
    spine = add_bone(edit, "Spine", (0.0, layout["body_y"], cfg["length"] * 0.42), (0.0, layout["body_y"], 0.06), root)
    chest = add_bone(edit, "Chest", (0.0, layout["body_y"], 0.06), (0.0, layout["shoulder_y"], layout["front_z"]), spine)
    neck = add_bone(edit, "Neck", (0.0, layout["shoulder_y"], layout["front_z"]), (0.0, layout["head_y"], layout["neck_z"]), chest)
    head = add_bone(edit, "Head", (0.0, layout["head_y"], layout["neck_z"]), (0.0, layout["head_y"], layout["muzzle_z"] - 0.12), neck)
    anchors.update(Spine=(0.0, layout["body_y"], layout["rear_z"]), Chest=(0.0, layout["shoulder_y"], layout["front_z"]), Neck=(0.0, layout["head_y"], layout["neck_z"]), Head=(0.0, layout["head_y"], layout["head_z"] - cfg["muzzle"] * 0.30))
    arm_scale = 1.25 if "long_arms" in cfg["features"] else 1.0
    for suffix in LIMBS:
        side = -1.0 if suffix.startswith("L") else 1.0
        front = suffix.endswith("F")
        z = layout["front_z"] if front else layout["rear_z"]
        leg_length = cfg["leg"] * (arm_scale if front else 1.0)
        hip_y = layout["shoulder_y"] if front else layout["body_y"]
        hip = (side * cfg["width"] * 0.72, hip_y, z)
        joint = (side * cfg["width"] * 0.78, max(0.38, hip_y - leg_length * 0.56), z + (-0.05 if front else 0.10))
        paw = (side * cfg["width"] * 0.80, 0.14, z - cfg["paw"] * (1.25 if front else 0.50))
        upper = add_bone(edit, f"Leg_{suffix}", hip, joint, chest if front else spine)
        add_bone(edit, f"Paw_{suffix}", joint, paw, upper)
        anchors[f"Leg_{suffix}"] = tuple((Vector(hip) + Vector(joint)) * 0.5)
        anchors[f"Paw_{suffix}"] = tuple((Vector(joint) + Vector(paw)) * 0.5)
    for suffix, side in (("L", -1.0), ("R", 1.0)):
        ear_base = (side * cfg["head"] * 0.52, layout["head_y"] + cfg["head"] * 0.42, layout["head_z"] + cfg["head"] * 0.12)
        ear_tip = (side * cfg["head"] * 0.64, ear_base[1] + max(cfg["ear"], 0.08), ear_base[2] + 0.04)
        add_bone(edit, f"Ear_{suffix}", ear_base, ear_tip, head)
        anchors[f"Ear_{suffix}"] = tuple((Vector(ear_base) + Vector(ear_tip)) * 0.5)
    tail_base = (0.0, layout["body_y"], cfg["length"] * 0.67)
    tail_tip = (0.0, max(0.24, layout["body_y"] - cfg["tail"] * 0.32), tail_base[2] + max(cfg["tail"], 0.15))
    add_bone(edit, "Tail", tail_base, tail_tip, spine)
    anchors["Tail"] = tuple((Vector(tail_base) + Vector(tail_tip)) * 0.5)
    bpy.ops.object.mode_set(mode="OBJECT")
    rig["eco_species"] = species
    rig["eco_rig_family"] = cfg["family"]
    return rig, anchors


def skin_ground_body(body: bpy.types.Object, rig: bpy.types.Object, anchors: dict[str, tuple[float, float, float]], cfg: dict) -> None:
    weights = {name: [] for name in anchors}
    for vertex in body.data.vertices:
        point = Vector((vertex.co.x, vertex.co.z, vertex.co.y))
        raw = {}
        for name, anchor in anchors.items():
            delta = point - Vector(anchor)
            if name.startswith("Leg_") or name.startswith("Paw_"):
                scale = Vector((cfg["width"] * 0.38, cfg["leg"] * 0.52, cfg["paw"] * 2.2))
                boost = 5.4
            elif name.startswith("Ear_"):
                scale = Vector((cfg["head"] * 0.42, max(cfg["ear"], 0.12) * 0.70, cfg["head"] * 0.38))
                boost = 5.0
            elif name == "Tail":
                scale = Vector((max(cfg["paw"], 0.18) * 1.8, max(cfg["tail"], 0.2) * 0.55, max(cfg["tail"], 0.2) * 0.72))
                boost = 4.8
            else:
                scale = Vector((cfg["width"] * 1.15, cfg["height"] * 1.05, cfg["length"] * 0.54))
                boost = 1.0
            distance = math.sqrt(sum((delta[index] / max(scale[index], 0.08)) ** 2 for index in range(3)))
            raw[name] = max(0.0, 1.0 - distance) ** 2 * boost
        total = sum(raw.values())
        if total < 0.0001:
            nearest = min(("Spine", "Chest", "Neck", "Head"), key=lambda name: (point - Vector(anchors[name])).length)
            raw[nearest] = 1.0
            total = 1.0
        for name in anchors:
            weights[name].append(raw[name] / total)
    add_armature_weights(body, rig, weights)


def build_ground_parts(species: str, hero: bool, rig: bpy.types.Object, anchors: dict, cfg: dict, layout: dict) -> list[bpy.types.Object]:
    coat = pbr_material(f"{species}_coat_pbr", cfg["coat"], 0.80)
    accent = pbr_material(f"{species}_accent_pbr", cfg["accent"], 0.74)
    dark = pbr_material(f"{species}_detail_pbr", cfg["dark"], 0.47)
    eye = pbr_material(f"{species}_eye_pbr", cfg["eye"], 0.15)
    horn = pbr_material(f"{species}_keratin_pbr", "#b9aa87", 0.62)
    elements = [
        ((0.0, layout["body_y"], layout["rear_z"]), (cfg["width"], cfg["height"], cfg["length"] * 0.58), 2.25),
        ((0.0, layout["shoulder_y"], layout["front_z"]), (cfg["width"] * 1.03, cfg["height"] * 1.02, cfg["length"] * 0.48), 2.25),
        ((0.0, (layout["shoulder_y"] + layout["head_y"]) * 0.5, layout["neck_z"]), (cfg["head"] * 0.70, cfg["neck"] * 0.72, cfg["neck"] * 0.68), 2.05),
        ((0.0, layout["head_y"], layout["head_z"]), (cfg["head"], cfg["head"] * 0.92, cfg["head"] * 0.98), 2.15),
        ((0.0, layout["head_y"] - cfg["head"] * 0.08, layout["muzzle_z"]), (cfg["head"] * 0.68, cfg["head"] * 0.55, cfg["muzzle"] * 0.72), 2.05),
    ]
    if "shoulder_hump" in cfg["features"]:
        elements.append(((0.0, layout["shoulder_y"] + cfg["height"] * 0.46, layout["front_z"] + 0.18), (cfg["width"] * 0.84, cfg["height"] * 0.56, cfg["length"] * 0.34), 2.2))
    for suffix in LIMBS:
        side = -1.0 if suffix.startswith("L") else 1.0
        front = suffix.endswith("F")
        z = layout["front_z"] if front else layout["rear_z"]
        leg_length = cfg["leg"] * (1.25 if front and "long_arms" in cfg["features"] else 1.0)
        hip_y = layout["shoulder_y"] if front else layout["body_y"]
        elements.extend([
            ((side * cfg["width"] * 0.74, hip_y - leg_length * 0.28, z), (cfg["paw"] * 1.20, leg_length * 0.42, cfg["paw"] * 1.12), 2.1),
            ((side * cfg["width"] * 0.79, max(0.32, hip_y - leg_length * 0.70), z - (0.05 if front else -0.08)), (cfg["paw"] * 0.92, leg_length * 0.36, cfg["paw"] * 0.88), 2.0),
            ((side * cfg["width"] * 0.80, 0.13, z - cfg["paw"]), (cfg["paw"] * 1.22, 0.13, cfg["paw"] * 1.62), 2.0),
        ])
    if cfg["ear"] > 0.02:
        for side in (-1.0, 1.0):
            elements.append(((side * cfg["head"] * 0.55, layout["head_y"] + cfg["head"] * 0.60 + cfg["ear"] * 0.28, layout["head_z"] + 0.04), (cfg["head"] * 0.25, cfg["ear"] * 0.66, cfg["head"] * 0.20), 2.0))
    if cfg["tail"] > 0.12:
        tail_base_z = cfg["length"] * 0.68
        for index in range(3):
            progress = (index + 1) / 3.0
            elements.append(((0.04 * math.sin(progress * 1.7), layout["body_y"] - cfg["tail"] * 0.30 * progress, tail_base_z + cfg["tail"] * progress), (max(cfg["paw"] * (1.35 - progress * 0.42), 0.12), max(cfg["paw"] * (1.45 - progress * 0.35), 0.12), max(cfg["tail"] * 0.25, 0.18)), 2.0))
    body = metaball_mesh(f"{species.title()}OrganicBodyV2", elements, coat, hero)
    skin_ground_body(body, rig, anchors, cfg)
    parts = [body]

    def sphere(name: str, pos, scale, material=accent, bone_name="Head"):
        obj = uv_sphere(name, pos, scale, material, hero)
        rigid_skin(obj, rig, bone_name)
        parts.append(obj)
        return obj

    def cone(name: str, start, end, radius, material=horn, bone_name="Head"):
        obj = cone_between(name, start, end, radius, material, hero)
        rigid_skin(obj, rig, bone_name)
        parts.append(obj)
        return obj

    for side in (-1.0, 1.0):
        sphere(f"EyeDetail_{'L' if side < 0 else 'R'}", (side * cfg["head"] * 0.72, layout["head_y"] + cfg["head"] * 0.12, layout["head_z"] - cfg["head"] * 0.38), (cfg["head"] * 0.105, cfg["head"] * 0.115, cfg["head"] * 0.075), eye)
    sphere("NoseDetail", (0.0, layout["head_y"] - cfg["head"] * 0.10, layout["muzzle_z"] - cfg["muzzle"] * 0.68), (cfg["head"] * 0.24, cfg["head"] * 0.16, cfg["head"] * 0.18), dark)
    features = cfg["features"]
    if features & {"chest", "muzzle_patch", "face_patch", "wide_muzzle"}:
        if "chest" in features:
            sphere("ChestRuffDetail", (0.0, layout["shoulder_y"], layout["front_z"] - cfg["length"] * 0.18), (cfg["width"] * 0.72, cfg["height"] * 0.72, 0.18), accent, "Chest")
        if features & {"muzzle_patch", "face_patch", "wide_muzzle"}:
            sphere("MuzzlePatchDetail", (0.0, layout["head_y"] - cfg["head"] * 0.10, layout["muzzle_z"] - cfg["muzzle"] * 0.30), (cfg["head"] * (0.90 if "wide_muzzle" in features else 0.70), cfg["head"] * 0.48, cfg["muzzle"] * 0.58), accent)
    if "black_legs" in features:
        for suffix in LIMBS:
            side = -1.0 if suffix.startswith("L") else 1.0
            z = layout["front_z"] if suffix.endswith("F") else layout["rear_z"]
            sphere(f"BlackLegDetail_{suffix}", (side * cfg["width"] * 0.80, 0.25, z - cfg["paw"] * 0.55), (cfg["paw"] * 1.10, 0.26, cfg["paw"] * 1.12), dark, f"Paw_{suffix}")
    if "mask" in features or "tear_marks" in features:
        for side in (-1.0, 1.0):
            sphere(f"FaceMaskDetail_{side:+.0f}", (side * cfg["head"] * 0.61, layout["head_y"] + 0.02, layout["head_z"] - cfg["head"] * 0.42), (cfg["head"] * (0.34 if "mask" in features else 0.12), cfg["head"] * 0.24, cfg["head"] * 0.10), dark)
    if features & {"mane", "ridge_mane", "cheek_ruff"}:
        count = 7 if hero else 4
        for index in range(count):
            angle = -1.1 + 2.2 * index / max(count - 1, 1)
            if "mane" in features:
                pos = (math.sin(angle) * cfg["head"] * 0.82, layout["head_y"] + math.cos(angle) * cfg["head"] * 0.72, layout["head_z"] + cfg["head"] * 0.12)
                sphere(f"ManeDetail_{index}", pos, (cfg["head"] * 0.38, cfg["head"] * 0.46, cfg["head"] * 0.28), dark, "Neck")
            elif "cheek_ruff" in features:
                side = -1.0 if index % 2 == 0 else 1.0
                sphere(f"CheekRuffDetail_{index}", (side * cfg["head"] * 0.72, layout["head_y"] - 0.02 + index * 0.015, layout["head_z"] + 0.02), (0.18, 0.25, 0.17), accent)
            else:
                z = layout["rear_z"] - cfg["length"] * 0.72 * index / max(count - 1, 1)
                cone(f"ManeQuillDetail_{index}", (0.0, layout["body_y"] + cfg["height"] * 0.62, z), (0.0, layout["body_y"] + cfg["height"] * 1.02, z + 0.03), cfg["paw"] * 0.32, dark, "Spine" if z > 0.0 else "Chest")
    if "quills" in features:
        rows = 16 if hero else 9
        for index in range(rows):
            z = layout["rear_z"] - cfg["length"] * 0.95 * index / max(rows - 1, 1)
            for side in (-1.0, 1.0):
                cone(f"QuillDetail_{index}_{side:+.0f}", (side * cfg["width"] * 0.40, layout["body_y"] + cfg["height"] * 0.42, z), (side * cfg["width"] * 0.85, layout["body_y"] + cfg["height"] * 1.02, z + 0.18), 0.045, horn, "Spine" if z > 0.0 else "Chest")
    if features & {"stripes", "spots", "side_band", "silverback", "armor_folds"}:
        if "side_band" in features or "silverback" in features:
            sphere("CoatBandDetail", (0.0, layout["body_y"] + cfg["height"] * 0.35, 0.12), (cfg["width"] * 0.95, cfg["height"] * 0.34, cfg["length"] * 0.56), accent, "Spine")
        elif "armor_folds" in features:
            for index in range(3):
                sphere(f"ArmorFoldDetail_{index}", (0.0, layout["body_y"] + 0.12, -0.40 + index * 0.42), (cfg["width"] * 1.02, 0.08, 0.12), accent, "Chest" if index < 2 else "Spine")
        else:
            count = (12 if "stripes" in features else 16) if hero else (7 if "stripes" in features else 9)
            for index in range(count):
                side = -1.0 if index % 2 == 0 else 1.0
                z = layout["rear_z"] - cfg["length"] * 1.18 * index / max(count - 1, 1)
                scale = (0.06 if "stripes" in features else 0.09, cfg["height"] * (0.48 if "stripes" in features else 0.13), 0.20 if "stripes" in features else 0.12)
                sphere(f"{'Stripe' if 'stripes' in features else 'Spot'}Detail_{index}", (side * cfg["width"] * 0.94, layout["body_y"] + (index % 3 - 1) * 0.13, z), scale, dark, "Spine" if z > 0.0 else "Chest")
    if features & {"horns", "antlers", "palm_antlers", "rhino_horns", "tusks"}:
        for side in (-1.0, 1.0):
            if "rhino_horns" in features:
                continue
            if "tusks" in features:
                start = (side * cfg["head"] * 0.38, layout["head_y"] - cfg["head"] * 0.30, layout["muzzle_z"] - cfg["muzzle"] * 0.30)
                end = (side * cfg["head"] * 0.52, layout["head_y"] + cfg["head"] * 0.06, layout["muzzle_z"] - cfg["muzzle"] * 0.76)
                cone(f"TuskDetail_{side:+.0f}", start, end, cfg["head"] * 0.10)
            if "horns" in features:
                start = (side * cfg["head"] * 0.43, layout["head_y"] + cfg["head"] * 0.43, layout["head_z"] + 0.04)
                end = (side * cfg["head"] * 0.92, layout["head_y"] + cfg["head"] * 0.85, layout["head_z"] - 0.04)
                cone(f"HornDetail_{side:+.0f}", start, end, cfg["head"] * 0.13)
            if "antlers" in features or "palm_antlers" in features:
                start = (side * cfg["head"] * 0.42, layout["head_y"] + cfg["head"] * 0.45, layout["head_z"] + 0.02)
                crown = (side * cfg["head"] * (1.00 if "palm_antlers" in features else 0.70), layout["head_y"] + cfg["head"] * 1.38, layout["head_z"] + 0.08)
                cone(f"AntlerDetail_{side:+.0f}", start, crown, cfg["head"] * 0.10)
                branch_count = 3 if hero else 2
                for branch_index in range(branch_count):
                    p = (branch_index + 1) / (branch_count + 1)
                    branch_start = tuple(Vector(start).lerp(Vector(crown), p))
                    branch_end = (branch_start[0] + side * cfg["head"] * (0.45 + p * 0.20), branch_start[1] + cfg["head"] * 0.34, branch_start[2] - cfg["head"] * (0.15 + p * 0.10))
                    cone(f"AntlerBranchDetail_{side:+.0f}_{branch_index}", branch_start, branch_end, cfg["head"] * 0.075)
    if "rhino_horns" in features:
        cone("NasalHornDetail", (0.0, layout["head_y"] + cfg["head"] * 0.12, layout["muzzle_z"] - cfg["muzzle"] * 0.16), (0.0, layout["head_y"] + cfg["head"] * 1.18, layout["muzzle_z"] - cfg["muzzle"] * 0.40), cfg["head"] * 0.18)
        cone("SecondHornDetail", (0.0, layout["head_y"] + cfg["head"] * 0.38, layout["head_z"] - 0.12), (0.0, layout["head_y"] + cfg["head"] * 0.92, layout["head_z"] - 0.22), cfg["head"] * 0.13)
    if "elephant_ears" in features:
        for side in (-1.0, 1.0):
            sphere(f"EarFanDetail_{side:+.0f}", (side * cfg["head"] * 0.88, layout["head_y"] - 0.04, layout["head_z"] + 0.20), (0.10, cfg["ear"] * 0.88, cfg["ear"] * 0.68), accent, f"Ear_{'L' if side < 0 else 'R'}")
    if "trunk" in features:
        trunk_elements = []
        for index in range(4):
            progress = index / 3.0
            trunk_elements.append(((0.0, layout["head_y"] - cfg["head"] * (0.20 + progress * 1.15), layout["muzzle_z"] - cfg["muzzle"] * (0.42 + progress * 0.15)), (cfg["head"] * (0.25 - progress * 0.07), cfg["head"] * 0.36, cfg["head"] * 0.20), 2.0))
        trunk = metaball_mesh("TrunkDetail", trunk_elements, accent, hero)
        rigid_skin(trunk, rig, "Head")
        parts.append(trunk)
    if "shell" in features:
        sphere("ShellDetail", (0.0, layout["body_y"] + cfg["height"] * 0.52, 0.10), (cfg["width"] * 1.10, cfg["height"] * 0.92, cfg["length"] * 0.72), accent, "Spine")
        if hero:
            for index in range(7):
                angle = index / 7.0 * math.tau
                sphere(f"ShellPlateDetail_{index}", (math.sin(angle) * cfg["width"] * 0.62, layout["body_y"] + cfg["height"] * 1.04, 0.10 + math.cos(angle) * cfg["length"] * 0.38), (0.22, 0.045, 0.27), dark, "Spine")
    if "tail_tip" in features or "tail_tuft" in features:
        sphere("TailTipDetail", (0.0, max(0.24, layout["body_y"] - cfg["tail"] * 0.32), cfg["length"] * 0.68 + cfg["tail"]), (cfg["paw"] * 1.55, cfg["paw"] * 1.45, cfg["paw"] * 1.72), accent if "tail_tip" in features else dark, "Tail")
    if "beard" in features or "dewlap" in features:
        sphere("BeardDetail", (0.0, layout["head_y"] - cfg["head"] * 0.66, layout["head_z"] - cfg["head"] * 0.18), (cfg["head"] * 0.30, cfg["head"] * (0.62 if "dewlap" in features else 0.40), cfg["head"] * 0.26), dark)
    if "ear_tufts" in features:
        for side in (-1.0, 1.0):
            cone(f"EarTuftDetail_{side:+.0f}", (side * cfg["head"] * 0.55, layout["head_y"] + cfg["head"] * 0.88, layout["head_z"] + 0.02), (side * cfg["head"] * 0.62, layout["head_y"] + cfg["head"] * 1.30, layout["head_z"] + 0.02), 0.045, dark, f"Ear_{'L' if side < 0 else 'R'}")
    attach_socket("SkillSocket_Mouth", (0.0, layout["head_y"], layout["muzzle_z"] - cfg["muzzle"] * 0.86), rig, "Head")
    attach_socket("SkillSocket_Chest", (0.0, layout["shoulder_y"], layout["front_z"]), rig, "Chest")
    return parts


def create_ground_actions(rig: bpy.types.Object, cfg: dict) -> None:
    rig.animation_data_create()
    gait = "pace" if cfg["family"] in ("heavy", "primate", "chelonian") else "bound" if cfg["family"] == "felid" else "trot"
    rate = 0.76 if cfg["family"] in ("heavy", "chelonian") else 1.18 if cfg["family"] in ("felid", "canid") else 1.0
    for action_name in ACTIONS:
        action = bpy.data.actions.new(action_name)
        rig.animation_data.action = action
        for pose_bone in rig.pose.bones:
            pose_bone.rotation_mode = "XYZ"
            pose_bone.rotation_euler = (0.0, 0.0, 0.0)
            pose_bone.keyframe_insert(data_path="rotation_euler", frame=1, group=pose_bone.name)
        if action_name in ("locomotion", "sprint"):
            amount = (0.46 if action_name == "locomotion" else 0.76) * rate
            phases = (1.0, -1.0, -1.0, 1.0) if gait != "pace" else (1.0, -1.0, 1.0, -1.0)
            for suffix, phase in zip(LIMBS, phases):
                upper, lower = rig.pose.bones[f"Leg_{suffix}"], rig.pose.bones[f"Paw_{suffix}"]
                for frame, curve in zip((1, 16, 31), (phase, -phase, phase)):
                    upper.rotation_euler[0] = amount * curve
                    lower.rotation_euler[0] = -max(0.0, amount * curve) * 0.62
                    upper.keyframe_insert(data_path="rotation_euler", frame=frame, group=upper.name)
                    lower.keyframe_insert(data_path="rotation_euler", frame=frame, group=lower.name)
        elif action_name in ("attack", "skill"):
            multiplier = 1.0 if action_name == "attack" else 1.28
            for frame, curve in zip((1, 9, 21), (0.0, 1.0, 0.0)):
                rig.pose.bones["Spine"].rotation_euler[0] = -0.18 * curve * multiplier
                rig.pose.bones["Chest"].rotation_euler[0] = -0.12 * curve
                rig.pose.bones["Head"].rotation_euler[0] = 0.16 * curve
                for suffix in ("LF", "RF"):
                    rig.pose.bones[f"Leg_{suffix}"].rotation_euler[0] = -0.48 * curve * multiplier
                for name in ("Spine", "Chest", "Head", "Leg_LF", "Leg_RF"):
                    rig.pose.bones[name].keyframe_insert(data_path="rotation_euler", frame=frame, group=name)
        elif action_name == "hit":
            for frame, curve in zip((1, 6, 15), (0.0, 1.0, 0.0)):
                rig.pose.bones["Spine"].rotation_euler[2] = 0.28 * curve
                rig.pose.bones["Head"].rotation_euler[2] = -0.18 * curve
                rig.pose.bones["Spine"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Spine")
                rig.pose.bones["Head"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Head")
        elif action_name == "eat":
            for frame, curve in zip((1, 16, 31), (0.0, 1.0, 0.0)):
                rig.pose.bones["Neck"].rotation_euler[0] = 0.52 * curve
                rig.pose.bones["Head"].rotation_euler[0] = 0.30 * curve
                rig.pose.bones["Neck"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Neck")
                rig.pose.bones["Head"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Head")
        elif action_name == "death":
            for frame, curve in zip((1, 18, 32), (0.0, 0.78, 1.0)):
                rig.pose.bones["Spine"].rotation_euler[2] = 1.20 * curve
                rig.pose.bones["Spine"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Spine")
        elif action_name == "idle":
            for frame, curve in zip((1, 16, 31), (-1.0, 1.0, -1.0)):
                rig.pose.bones["Chest"].rotation_euler[0] = 0.020 * curve
                rig.pose.bones["Ear_L"].rotation_euler[1] = 0.035 * curve
                rig.pose.bones["Chest"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Chest")
                rig.pose.bones["Ear_L"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Ear_L")
        action.use_fake_user = True
    rig.animation_data.action = bpy.data.actions["idle"]


def build_bird(species: str, hero: bool) -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    owl = species == "owl"
    coat = pbr_material(f"{species}_feather_pbr", "#d8d6ce" if owl else "#493729", 0.76)
    accent = pbr_material(f"{species}_accent_pbr", "#8e8173" if owl else "#d0a743", 0.66)
    dark = pbr_material(f"{species}_detail_pbr", "#34383d" if owl else "#211c18", 0.43)
    eye = pbr_material(f"{species}_eye_pbr", "#e0bc42", 0.14)
    bpy.ops.object.armature_add(enter_editmode=True)
    rig = bpy.context.active_object
    rig.name = "SpeciesFlightSkeleton3D"
    rig.data.name = f"{species.title()}V2FlightRig"
    edit = rig.data.edit_bones
    root = edit[0]
    root.name = "Root"
    root.head, root.tail = g2b((0.0, 0.40, 0.10)), g2b((0.0, 0.90, 0.10))
    body = add_bone(edit, "Body", (0.0, 1.05, 0.40), (0.0, 1.30, -0.38), root)
    head = add_bone(edit, "Head", (0.0, 1.30, -0.38), (0.0, 1.42, -1.05), body)
    for suffix, side in (("L", -1.0), ("R", 1.0)):
        wing = add_bone(edit, f"Wing_{suffix}", (side * 0.34, 1.18, -0.10), (side * 1.48, 1.16, 0.20), body)
        add_bone(edit, f"WingTip_{suffix}", (side * 1.48, 1.16, 0.20), (side * 2.70, 1.02, 0.68), wing)
        add_bone(edit, f"Talon_{suffix}", (side * 0.25, 0.92, -0.15), (side * 0.28, 0.46, -0.35), body)
    add_bone(edit, "Tail", (0.0, 1.04, 0.58), (0.0, 0.98, 1.50), body)
    bpy.ops.object.mode_set(mode="OBJECT")
    body_elements = [
        ((0.0, 1.10, 0.25), (0.62 if owl else 0.56, 0.75, 0.82), 2.2),
        ((0.0, 1.38, -0.48), (0.53 if owl else 0.43, 0.52, 0.54), 2.1),
        ((0.0, 1.42, -0.91), (0.38 if owl else 0.28, 0.35, 0.35), 2.0),
    ]
    organic = metaball_mesh(f"{species.title()}OrganicBodyV2", body_elements, coat, hero)
    weights = {"Body": [], "Head": []}
    for vertex in organic.data.vertices:
        z = vertex.co.y
        head_weight = max(0.0, min(1.0, (-z - 0.20) / 0.92))
        weights["Body"].append(1.0 - head_weight)
        weights["Head"].append(head_weight)
    add_armature_weights(organic, rig, weights)
    parts = [organic]
    for suffix, side in (("L", -1.0), ("R", 1.0)):
        wing_base = uv_sphere(f"WingBodyDetail_{suffix}", (side * 1.02, 1.16, 0.18), (1.18, 0.12, 0.52), coat, hero)
        rigid_skin(wing_base, rig, f"Wing_{suffix}")
        parts.append(wing_base)
        wing_tip = uv_sphere(f"WingFeatherDetail_{suffix}", (side * 2.08, 1.06, 0.55), (1.28, 0.08, 0.46), dark if owl else coat, hero)
        rigid_skin(wing_tip, rig, f"WingTip_{suffix}")
        parts.append(wing_tip)
        talon = cone_between(f"TalonDetail_{suffix}", (side * 0.27, 0.62, -0.28), (side * 0.31, 0.35, -0.56), 0.07, accent, hero)
        rigid_skin(talon, rig, f"Talon_{suffix}")
        parts.append(talon)
        attach_socket(f"SkillSocket_Wing_{suffix}", (side * 2.45, 1.06, 0.66), rig, f"WingTip_{suffix}")
    tail = uv_sphere("TailFeatherDetail", (0.0, 1.00, 1.18), (0.52, 0.10, 0.76), coat, hero)
    rigid_skin(tail, rig, "Tail")
    parts.append(tail)
    beak = cone_between("BeakDetail", (0.0, 1.38, -1.08), (0.0, 1.28, -1.48), 0.16 if owl else 0.13, accent, hero)
    rigid_skin(beak, rig, "Head")
    parts.append(beak)
    for side in (-1.0, 1.0):
        eyeball = uv_sphere(f"EyeDetail_{side:+.0f}", (side * (0.31 if owl else 0.23), 1.51, -0.98), (0.105, 0.11, 0.07), eye, hero)
        rigid_skin(eyeball, rig, "Head")
        parts.append(eyeball)
    attach_socket("SkillSocket_Beak", (0.0, 1.32, -1.48), rig, "Head")
    rig["eco_species"] = species
    rig["eco_rig_family"] = "avian"
    create_bird_actions(rig)
    return rig, parts


def create_bird_actions(rig: bpy.types.Object) -> None:
    names = ACTIONS + ("glide", "flap", "dive", "land")
    rig.animation_data_create()
    for action_name in names:
        action = bpy.data.actions.new(action_name)
        rig.animation_data.action = action
        for pose_bone in rig.pose.bones:
            pose_bone.rotation_mode = "XYZ"
            pose_bone.rotation_euler = (0.0, 0.0, 0.0)
            pose_bone.keyframe_insert(data_path="rotation_euler", frame=1, group=pose_bone.name)
        if action_name in ("locomotion", "sprint", "flap"):
            amount = 0.68 if action_name == "locomotion" else 0.92
            for frame, curve in zip((1, 10, 20), (-1.0, 1.0, -1.0)):
                for suffix, side in (("L", -1.0), ("R", 1.0)):
                    rig.pose.bones[f"Wing_{suffix}"].rotation_euler[1] = side * amount * curve
                    rig.pose.bones[f"WingTip_{suffix}"].rotation_euler[1] = side * amount * 0.42 * curve
                    rig.pose.bones[f"Wing_{suffix}"].keyframe_insert(data_path="rotation_euler", frame=frame, group=f"Wing_{suffix}")
                    rig.pose.bones[f"WingTip_{suffix}"].keyframe_insert(data_path="rotation_euler", frame=frame, group=f"WingTip_{suffix}")
        elif action_name in ("attack", "skill", "dive"):
            for frame, curve in zip((1, 9, 20), (0.0, 1.0, 0.0)):
                rig.pose.bones["Body"].rotation_euler[0] = -0.34 * curve
                rig.pose.bones["Head"].rotation_euler[0] = 0.22 * curve
                for suffix, side in (("L", -1.0), ("R", 1.0)):
                    rig.pose.bones[f"Wing_{suffix}"].rotation_euler[1] = side * 0.44 * curve
                    rig.pose.bones[f"Talon_{suffix}"].rotation_euler[0] = -0.52 * curve
                for name in ("Body", "Head", "Wing_L", "Wing_R", "Talon_L", "Talon_R"):
                    rig.pose.bones[name].keyframe_insert(data_path="rotation_euler", frame=frame, group=name)
        elif action_name == "hit":
            for frame, curve in zip((1, 6, 15), (0.0, 1.0, 0.0)):
                rig.pose.bones["Body"].rotation_euler[2] = 0.32 * curve
                rig.pose.bones["Body"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Body")
        elif action_name == "eat":
            for frame, curve in zip((1, 16, 31), (0.0, 1.0, 0.0)):
                rig.pose.bones["Head"].rotation_euler[0] = 0.48 * curve
                rig.pose.bones["Head"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Head")
        elif action_name in ("death", "land"):
            for frame, curve in zip((1, 18, 32), (0.0, 0.76, 1.0)):
                rig.pose.bones["Body"].rotation_euler[2] = 1.16 * curve if action_name == "death" else 0.0
                rig.pose.bones["Wing_L"].rotation_euler[1] = -0.72 * curve
                rig.pose.bones["Wing_R"].rotation_euler[1] = 0.72 * curve
                for name in ("Body", "Wing_L", "Wing_R"):
                    rig.pose.bones[name].keyframe_insert(data_path="rotation_euler", frame=frame, group=name)
        action.use_fake_user = True
    rig.animation_data.action = bpy.data.actions["idle"]


def build_long_body(species: str, hero: bool) -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    crocodile = species == "crocodile"
    coat = pbr_material(f"{species}_scale_pbr", "#526245" if crocodile else "#315a55", 0.66)
    accent = pbr_material(f"{species}_accent_pbr", "#a0a16c" if crocodile else "#62b9ac", 0.58)
    dark = pbr_material(f"{species}_detail_pbr", "#202b24" if crocodile else "#152522", 0.38)
    eye = pbr_material(f"{species}_eye_pbr", "#d0a13a", 0.14)
    bpy.ops.object.armature_add(enter_editmode=True)
    rig = bpy.context.active_object
    rig.name = "SpeciesCrocodileSkeleton3D"
    rig.data.name = f"{species.title()}V2LongRig"
    edit = rig.data.edit_bones
    root = edit[0]
    root.name = "Root"
    root.head, root.tail = g2b((0.0, 0.18, 0.10)), g2b((0.0, 0.58, 0.10))
    body = add_bone(edit, "Body", (0.0, 0.58, 0.45), (0.0, 0.62, -0.35), root)
    neck = add_bone(edit, "Neck", (0.0, 0.62, -0.35), (0.0, 0.68, -1.05), body)
    head = add_bone(edit, "Head", (0.0, 0.68, -1.05), (0.0, 0.62, -1.78), neck)
    add_bone(edit, "Jaw", (0.0, 0.53, -1.05), (0.0, 0.50, -1.82), head)
    tail_base = add_bone(edit, "Tail_Base", (0.0, 0.58, 0.45), (0.0, 0.54, 1.18), body)
    tail_mid = add_bone(edit, "Tail_Mid", (0.0, 0.54, 1.18), (0.0, 0.48, 1.92), tail_base)
    add_bone(edit, "Tail_Tip", (0.0, 0.48, 1.92), (0.0, 0.42, 2.72), tail_mid)
    if crocodile:
        for suffix in LIMBS:
            side = -1.0 if suffix.startswith("L") else 1.0
            z = -0.34 if suffix.endswith("F") else 0.58
            add_bone(edit, f"Leg_{suffix}", (side * 0.48, 0.56, z), (side * 0.78, 0.20, z - 0.02), body)
    bpy.ops.object.mode_set(mode="OBJECT")
    elements = []
    if crocodile:
        chain = [(0.40, 0.76, 0.72), (-0.32, 0.74, 0.68), (-1.02, 0.60, 0.58), (-1.62, 0.48, 0.48), (1.10, 0.50, 0.62), (1.78, 0.36, 0.56), (2.42, 0.20, 0.48)]
        for z, width, length in chain:
            elements.append(((0.0, 0.58, z), (width, 0.40 if z < 1.0 else 0.28, length), 2.1))
        for suffix in LIMBS:
            side = -1.0 if suffix.startswith("L") else 1.0
            z = -0.34 if suffix.endswith("F") else 0.58
            elements.extend([((side * 0.55, 0.38, z), (0.34, 0.20, 0.25), 2.0), ((side * 0.82, 0.12, z - 0.10), (0.38, 0.10, 0.22), 2.0)])
    else:
        for index in range(11):
            z = -1.65 + index * 0.40
            width = 0.28 * (1.0 - max(0.0, index - 5) * 0.09)
            y = 0.30 + 0.07 * math.sin(index * 0.78)
            elements.append(((0.12 * math.sin(index * 0.82), y, z), (max(width, 0.10), max(width * 0.90, 0.10), 0.48), 2.0))
        elements.append(((0.0, 0.48, -1.78), (0.40, 0.28, 0.46), 2.1))
    organic = metaball_mesh(f"{species.title()}OrganicBodyV2", elements, coat, hero)
    chain_anchors = {"Body": 0.15, "Neck": -0.72, "Head": -1.48, "Tail_Base": 0.88, "Tail_Mid": 1.62, "Tail_Tip": 2.36}
    weights = {name: [] for name in chain_anchors}
    for vertex in organic.data.vertices:
        z = vertex.co.y
        raw = {name: max(0.0, 1.0 - abs(z - anchor) / 0.92) ** 2 for name, anchor in chain_anchors.items()}
        total = sum(raw.values()) or 1.0
        for name in chain_anchors:
            weights[name].append(raw[name] / total)
    add_armature_weights(organic, rig, weights)
    parts = [organic]
    for side in (-1.0, 1.0):
        eyeball = uv_sphere(f"EyeDetail_{side:+.0f}", (side * (0.31 if crocodile else 0.22), 0.78 if crocodile else 0.58, -1.62), (0.09, 0.09, 0.07), eye, hero)
        rigid_skin(eyeball, rig, "Head")
        parts.append(eyeball)
    if crocodile:
        scute_count = 13 if hero else 7
        for index in range(scute_count):
            z = -0.90 + index * (2.55 / max(scute_count - 1, 1))
            scute = cone_between(f"BackScuteDetail_{index}", (0.0, 0.90, z), (0.0, 1.16, z + 0.03), 0.10, dark, hero)
            target = "Head" if z < -0.8 else "Neck" if z < -0.2 else "Body" if z < 0.55 else "Tail_Base" if z < 1.25 else "Tail_Mid"
            rigid_skin(scute, rig, target)
            parts.append(scute)
        for side in (-1.0, 1.0):
            tooth = cone_between(f"ToothDetail_{side:+.0f}", (side * 0.30, 0.49, -1.76), (side * 0.31, 0.28, -1.82), 0.07, accent, hero)
            rigid_skin(tooth, rig, "Jaw")
            parts.append(tooth)
    else:
        ring_count = 14 if hero else 8
        for index in range(ring_count):
            z = -1.20 + index * 0.27
            ring = uv_sphere(f"ScaleBandDetail_{index}", (0.0, 0.34, z), (0.30, 0.04, 0.09), accent if index % 2 == 0 else dark, hero)
            target = min(chain_anchors, key=lambda name: abs(z - chain_anchors[name]))
            rigid_skin(ring, rig, target)
            parts.append(ring)
    attach_socket("SkillSocket_Jaw", (0.0, 0.48, -1.92), rig, "Jaw")
    attach_socket("SkillSocket_TailTip", (0.0, 0.42, 2.75), rig, "Tail_Tip")
    rig["eco_species"] = species
    rig["eco_rig_family"] = "long_body"
    create_long_actions(rig, crocodile)
    return rig, parts


def create_long_actions(rig: bpy.types.Object, crocodile: bool) -> None:
    names = ACTIONS + ("swim",)
    rig.animation_data_create()
    for action_name in names:
        action = bpy.data.actions.new(action_name)
        rig.animation_data.action = action
        for pose_bone in rig.pose.bones:
            pose_bone.rotation_mode = "XYZ"
            pose_bone.rotation_euler = (0.0, 0.0, 0.0)
            pose_bone.keyframe_insert(data_path="rotation_euler", frame=1, group=pose_bone.name)
        if action_name in ("locomotion", "sprint", "swim"):
            amount = 0.20 if action_name == "locomotion" else 0.38
            for frame, curve in zip((1, 10, 20), (-1.0, 1.0, -1.0)):
                for index, name in enumerate(("Body", "Neck", "Tail_Base", "Tail_Mid", "Tail_Tip")):
                    rig.pose.bones[name].rotation_euler[1] = amount * math.sin(curve + index * 0.62)
                    rig.pose.bones[name].keyframe_insert(data_path="rotation_euler", frame=frame, group=name)
                if crocodile:
                    for limb_index, suffix in enumerate(LIMBS):
                        rig.pose.bones[f"Leg_{suffix}"].rotation_euler[0] = amount * (1.0 if limb_index in (0, 3) else -1.0) * curve
                        rig.pose.bones[f"Leg_{suffix}"].keyframe_insert(data_path="rotation_euler", frame=frame, group=f"Leg_{suffix}")
        elif action_name in ("attack", "skill"):
            for frame, curve in zip((1, 9, 21), (0.0, 1.0, 0.0)):
                rig.pose.bones["Jaw"].rotation_euler[0] = -0.46 * curve
                rig.pose.bones["Head"].rotation_euler[1] = 0.18 * curve
                rig.pose.bones["Tail_Mid"].rotation_euler[1] = -0.42 * curve
                for name in ("Jaw", "Head", "Tail_Mid"):
                    rig.pose.bones[name].keyframe_insert(data_path="rotation_euler", frame=frame, group=name)
        elif action_name == "hit":
            for frame, curve in zip((1, 6, 15), (0.0, 1.0, 0.0)):
                rig.pose.bones["Body"].rotation_euler[2] = 0.24 * curve
                rig.pose.bones["Body"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Body")
        elif action_name == "eat":
            for frame, curve in zip((1, 16, 31), (0.0, 1.0, 0.0)):
                rig.pose.bones["Head"].rotation_euler[0] = 0.26 * curve
                rig.pose.bones["Jaw"].rotation_euler[0] = -0.22 * curve
                rig.pose.bones["Head"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Head")
                rig.pose.bones["Jaw"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Jaw")
        elif action_name == "death":
            for frame, curve in zip((1, 18, 32), (0.0, 0.76, 1.0)):
                rig.pose.bones["Body"].rotation_euler[2] = 0.82 * curve
                rig.pose.bones["Body"].keyframe_insert(data_path="rotation_euler", frame=frame, group="Body")
        action.use_fake_user = True
    rig.animation_data.action = bpy.data.actions["idle"]


def triangle_count(objects: list[bpy.types.Object]) -> int:
    total = 0
    for obj in objects:
        obj.data.calc_loop_triangles()
        total += len(obj.data.loop_triangles)
    return total


def export_species(species: str, hero: bool, output_root: Path) -> tuple[int, int, int]:
    reset_scene()
    if species in BIRDS:
        rig, parts = build_bird(species, hero)
    elif species in LONG_BODY:
        rig, parts = build_long_body(species, hero)
    else:
        cfg = config_for(species)
        layout = ground_layout(cfg)
        rig, anchors = build_ground_rig(species, cfg, layout)
        parts = build_ground_parts(species, hero, rig, anchors, cfg, layout)
        create_ground_actions(rig, cfg)
    profile = "hero" if hero else "mobile"
    output = output_root / species / f"{species}_{profile}.glb"
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(
        filepath=str(output), export_format="GLB", use_selection=True,
        export_animations=True, export_animation_mode="ACTIONS",
        export_skins=True, export_yup=True, export_apply=True,
    )
    triangles = triangle_count(parts)
    vertices = sum(len(obj.data.vertices) for obj in parts)
    if not output.is_file() or output.stat().st_size < 4096:
        raise RuntimeError(f"failed to export {output}")
    return triangles, vertices, len(rig.data.bones)


def main() -> None:
    args = parse_args()
    output_root = Path(args.output_root).resolve()
    requested = tuple(args.species) if args.species else REMAINING_SPECIES
    for species in requested:
        for hero in (True, False):
            triangles, vertices, bones = export_species(species, hero, output_root)
            print(f"V2_SPECIES_MODEL_OK: {species} / {'hero' if hero else 'mobile'} / {triangles} triangles / {vertices} vertices / {bones} bones")


if __name__ == "__main__":
    main()
