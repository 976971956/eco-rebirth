from __future__ import annotations

import argparse
import hashlib
import importlib.util
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


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


def parse_args(description: str) -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=description)
    parser.add_argument("--source-dir", required=True)
    parser.add_argument("--output-root", required=True)
    return parser.parse_args(argv)


def verify_source(source_dir: Path, source_files: dict[str, str], species: str) -> None:
    for basename, expected in source_files.items():
        source = source_dir / basename
        if not source.is_file():
            raise RuntimeError(f"missing {species} reference record: {source}")
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        if digest != expected:
            raise RuntimeError(f"{species} reference checksum mismatch for {basename}: {digest}")


def coat_material(project_root: Path, species: str, tint: tuple[float, float, float], hero: bool, roughness: float):
    shared = project_root / "assets/textures/animals/shared"
    albedo = BEAR.tinted_fur_image(shared / "quadruped_fur_atlas_albedo.png", f"{species}_dense_fur_albedo", tint, hero)
    normal = BEAR.packed_image(shared / "quadruped_fur_atlas_normal.png", f"{species}_dense_fur_normal", "Non-Color", hero)
    roughness_image = BEAR.packed_image(shared / "quadruped_fur_atlas_roughness.png", f"{species}_dense_fur_roughness", "Non-Color", hero)
    material = bpy.data.materials.new(f"{species}_cinematic_coat_pbr")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    principled = nodes.get("Principled BSDF")
    if principled is None:
        raise RuntimeError("missing Principled BSDF")
    principled.inputs["Roughness"].default_value = roughness
    albedo_node = nodes.new("ShaderNodeTexImage")
    albedo_node.image = albedo
    links.new(albedo_node.outputs["Color"], principled.inputs["Base Color"])
    normal_node = nodes.new("ShaderNodeTexImage")
    normal_node.image = normal
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = 0.34
    links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])
    roughness_node = nodes.new("ShaderNodeTexImage")
    roughness_node.image = roughness_image
    links.new(roughness_node.outputs["Color"], principled.inputs["Roughness"])
    material["eco_pbr_surface"] = f"authored_{species}_fur"
    return material


def replace_materials(parts, coat, accent, detail, eye) -> None:
    for obj in parts:
        for index, material in enumerate(obj.data.materials):
            name = material.name.lower()
            if "_coat_pbr" in name:
                obj.data.materials[index] = coat
            elif "_accent_pbr" in name:
                obj.data.materials[index] = accent
            elif "_detail_pbr" in name or "_keratin_pbr" in name:
                obj.data.materials[index] = detail
            elif "_eye_pbr" in name:
                obj.data.materials[index] = eye


def remove_named(parts, prefixes: tuple[str, ...]) -> None:
    for obj in list(parts):
        if obj.name.startswith(prefixes):
            parts.remove(obj)
            bpy.data.objects.remove(obj, do_unlink=True)


def connected_tail(
    name: str,
    hero: bool,
    rig,
    start: tuple[float, float, float],
    end: tuple[float, float, float],
    base_radius: float,
    tip_radius: float,
    material,
    flatten: float = 0.82,
):
    ring_count = 9 if hero else 6
    sides = 10 if hero else 7
    vertices = []
    faces = []
    tail_weights = []
    tip_weights = []
    start_v = Vector(start)
    end_v = Vector(end)
    for ring in range(ring_count):
        amount = ring / (ring_count - 1)
        centre = start_v.lerp(end_v, amount)
        radius = base_radius * (1.0 - amount) + tip_radius * amount
        for side in range(sides):
            angle = math.tau * side / sides
            vertices.append((centre.x + math.cos(angle) * radius, centre.y + math.sin(angle) * radius * flatten, centre.z))
            blend = max(0.0, min(1.0, (amount - 0.30) / 0.40))
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
    result = PIPELINE.authored_mesh(name, vertices, faces, [material], [0] * len(faces))
    for polygon in result.data.polygons:
        polygon.use_smooth = True
    PIPELINE.add_armature_weights(result, rig, {"Tail": tail_weights, "TailTip": tip_weights})
    BEAR.smart_uv(result)
    return result


def connected_weighted_tube(
    name: str,
    hero: bool,
    rig,
    points: list[tuple[float, float, float]],
    radii: list[float],
    material,
    root_bone: str,
    tip_bone: str,
    flatten: float = 1.0,
):
    """Create a curved, closed appendage with a stable frame and two-bone skin."""
    if len(points) < 2 or len(points) != len(radii):
        raise RuntimeError(f"invalid tube guide for {name}")
    sides = 12 if hero else 7
    vertices = []
    faces = []
    root_weights = []
    tip_weights = []
    centres = [Vector(point) for point in points]
    for ring, centre in enumerate(centres):
        amount = ring / (len(centres) - 1)
        if ring == 0:
            tangent = (centres[1] - centre).normalized()
        elif ring == len(centres) - 1:
            tangent = (centre - centres[ring - 1]).normalized()
        else:
            tangent = (centres[ring + 1] - centres[ring - 1]).normalized()
        reference = Vector((0.0, 0.0, 1.0))
        if abs(tangent.dot(reference)) > 0.92:
            reference = Vector((1.0, 0.0, 0.0))
        axis_a = tangent.cross(reference).normalized()
        axis_b = tangent.cross(axis_a).normalized()
        for side in range(sides):
            angle = math.tau * side / sides
            point = centre + axis_a * math.cos(angle) * radii[ring] + axis_b * math.sin(angle) * radii[ring] * flatten
            vertices.append(tuple(point))
            blend = max(0.0, min(1.0, (amount - 0.22) / 0.62))
            root_weights.append(1.0 - blend)
            tip_weights.append(blend)
    for ring in range(len(centres) - 1):
        for side in range(sides):
            next_side = (side + 1) % sides
            a = ring * sides + side
            b = ring * sides + next_side
            c = (ring + 1) * sides + next_side
            d = (ring + 1) * sides + side
            faces.append((a, b, c, d))
    faces.append(tuple(reversed(range(sides))))
    last = (len(centres) - 1) * sides
    faces.append(tuple(last + side for side in range(sides)))
    result = PIPELINE.authored_mesh(name, vertices, faces, [material], [0] * len(faces))
    for polygon in result.data.polygons:
        polygon.use_smooth = True
    weights = (
        {root_bone: [1.0] * len(vertices)}
        if root_bone == tip_bone
        else {root_bone: root_weights, tip_bone: tip_weights}
    )
    PIPELINE.add_armature_weights(result, rig, weights)
    BEAR.smart_uv(result)
    return result


def customize_lynx(parts, hero: bool, rig, cfg: dict, layout: dict, coat, accent, detail) -> None:
    remove_named(parts, ("CheekRuffDetail", "V5TailBaseSilhouette", "V5TailTipSilhouette"))
    for side in (-1.0, 1.0):
        count = 3 if hero else 2
        for index in range(count):
            start = (side * cfg["head"] * (0.54 + index * 0.04), layout["head_y"] - 0.01, layout["head_z"] + cfg["head"] * (0.04 - index * 0.11))
            end = (side * cfg["head"] * (0.93 + index * 0.05), layout["head_y"] - cfg["head"] * (0.08 + index * 0.02), layout["head_z"] + cfg["head"] * (0.02 - index * 0.14))
            tuft = PIPELINE.ellipsoid_between(f"LynxCheekRuffDetail_{side:+.0f}_{index}", start, end, cfg["head"] * (0.105 - index * 0.012), accent if index == 0 else coat, hero, 0.56)
            PIPELINE.rigid_skin(tuft, rig, "Head")
            parts.append(tuft)
    tail_start = (0.0, layout["body_y"], cfg["length"] * 0.58)
    tail_end = (0.0, layout["body_y"] + 0.04, cfg["length"] * 0.58 + cfg["tail"] * 1.15)
    tail = connected_tail("LynxConnectedBobTailSilhouette", hero, rig, tail_start, tail_end, 0.14, 0.085, coat, 0.88)
    tail.data.materials.append(detail)
    for polygon in tail.data.polygons:
        if sum(tail.data.vertices[index].co.y for index in polygon.vertices) / len(polygon.vertices) > PIPELINE.g2b(tail_start)[1] + cfg["tail"] * 0.72:
            polygon.material_index = 1
    tail["eco_tail_contract"] = "single_connected_short_black_tipped_bobtail"
    parts.append(tail)
    for obj in parts:
        if obj.name.startswith("V5FootDetail"):
            obj.scale.x *= 1.22
            obj.scale.y *= 1.06
            obj["eco_paw_contract"] = "wide_furred_snowshoe_paw"


def customize_goat(parts, hero: bool, rig, cfg: dict, layout: dict, coat, accent, detail) -> None:
    remove_named(parts, ("HornDetail", "BeardDetail"))
    for side in (-1.0, 1.0):
        points = [
            (side * cfg["head"] * 0.34, layout["head_y"] + cfg["head"] * 0.38, layout["head_z"] + 0.04),
            (side * cfg["head"] * 0.58, layout["head_y"] + cfg["head"] * 0.76, layout["head_z"] + cfg["head"] * 0.12),
            (side * cfg["head"] * 0.66, layout["head_y"] + cfg["head"] * 1.02, layout["head_z"] + cfg["head"] * 0.34),
            (side * cfg["head"] * 0.56, layout["head_y"] + cfg["head"] * 1.08, layout["head_z"] + cfg["head"] * 0.62),
        ]
        for index in range(3):
            horn = PIPELINE.cone_between(
                f"GoatSweptHornDetail_{side:+.0f}_{index}", points[index], points[index + 1],
                cfg["head"] * (0.105 - index * 0.022), detail, hero,
            )
            PIPELINE.rigid_skin(horn, rig, "Head")
            parts.append(horn)
    beard_top = (0.0, layout["head_y"] - cfg["head"] * 0.40, layout["head_z"] - cfg["head"] * 0.12)
    beard_mid = (0.0, beard_top[1] - cfg["head"] * 0.28, beard_top[2] + cfg["head"] * 0.06)
    beard_tip = (0.0, beard_top[1] - cfg["head"] * 0.54, beard_top[2] + cfg["head"] * 0.13)
    for index, (start, end, radius) in enumerate(((beard_top, beard_mid, 0.105), (beard_mid, beard_tip, 0.070))):
        beard = PIPELINE.ellipsoid_between(f"GoatTaperedBeardDetail_{index}", start, end, cfg["head"] * radius, detail, hero, 0.62)
        PIPELINE.rigid_skin(beard, rig, "Head")
        parts.append(beard)


def customize_wolverine(parts, hero: bool, rig, cfg: dict, layout: dict, coat, accent, detail) -> None:
    """Replace generic canid details with a compact mustelid silhouette."""
    remove_named(parts, ("V5EarSilhouette", "V5TailBaseSilhouette", "V5TailTipSilhouette"))
    for suffix, side in (("L", -1.0), ("R", 1.0)):
        ear_position = (
            side * cfg["head"] * 0.48,
            layout["head_y"] + cfg["head"] * 0.44,
            layout["head_z"] + cfg["head"] * 0.10,
        )
        ear = PIPELINE.uv_sphere(
            f"WolverineRoundedEarSilhouette_{suffix}", ear_position,
            (cfg["head"] * 0.18, cfg["head"] * 0.20, cfg["head"] * 0.105),
            coat, hero,
        )
        PIPELINE.rigid_skin(ear, rig, f"Ear_{suffix}")
        parts.append(ear)
        if hero:
            inner = PIPELINE.uv_sphere(
                f"WolverineRoundedEarInnerDetail_{suffix}",
                (ear_position[0], ear_position[1] + cfg["head"] * 0.018, ear_position[2] - cfg["head"] * 0.070),
                (cfg["head"] * 0.105, cfg["head"] * 0.115, cfg["head"] * 0.035),
                accent, hero,
            )
            PIPELINE.rigid_skin(inner, rig, f"Ear_{suffix}")
            parts.append(inner)

    tail_start = (0.0, layout["body_y"] - 0.02, cfg["length"] * 0.60)
    tail_end = (0.0, max(0.20, layout["body_y"] - cfg["tail"] * 0.30), cfg["length"] * 0.60 + cfg["tail"] * 1.06)
    tail = connected_tail(
        "WolverineConnectedBrushTailSilhouette", hero, rig, tail_start, tail_end,
        cfg["paw"] * 1.12, cfg["paw"] * 0.54, coat, 0.86,
    )
    tail["eco_tail_contract"] = "single_connected_low_tapered_mustelid_tail"
    parts.append(tail)

    for obj in parts:
        if obj.name.startswith("V5FootDetail"):
            obj.scale.x *= 1.20
            obj.scale.y *= 0.68
            obj.scale.z *= 0.92
            obj["eco_paw_contract"] = "broad_five_toed_digging_paw"

    # Flush shoulder colouring is already painted on the torso. These two
    # short ruffs add the heavy neck/shoulder transition without floating fur.
    for side in (-1.0, 1.0):
        ruff = PIPELINE.ellipsoid_between(
            f"WolverineShoulderRuffDetail_{side:+.0f}",
            (side * cfg["width"] * 0.54, layout["shoulder_y"] + 0.05, layout["front_z"] + 0.12),
            (side * cfg["width"] * 0.60, layout["shoulder_y"] - 0.04, layout["front_z"] + 0.48),
            cfg["head"] * 0.13, accent, hero, 0.55,
        )
        PIPELINE.rigid_skin(ruff, rig, "Chest")
        parts.append(ruff)


def customize_bison(parts, hero: bool, rig, cfg: dict, layout: dict, coat, accent, detail) -> None:
    """Build the front-heavy wool, low brow and compact horns of a bull bison."""
    remove_named(parts, ("HornDetail", "BeardDetail", "ManeQuillDetail"))
    for obj in parts:
        if obj.name.startswith("V5FootDetail"):
            obj.scale.y *= 0.70
            obj["eco_hoof_contract"] = "compact_load_bearing_split_hoof"
    forelock = PIPELINE.ellipsoid_between(
        "BisonCompactForelockDetail",
        (0.0, layout["head_y"] + cfg["head"] * 0.40, layout["head_z"] + cfg["head"] * 0.22),
        (0.0, layout["head_y"] + cfg["head"] * 0.30, layout["head_z"] - cfg["head"] * 0.18),
        cfg["head"] * 0.25, coat, hero, 0.72,
    )
    PIPELINE.rigid_skin(forelock, rig, "Head")
    parts.append(forelock)
    for side in (-1.0, 1.0):
        points = [
            (side * cfg["head"] * 0.42, layout["head_y"] + cfg["head"] * 0.35, layout["head_z"] + 0.02),
            (side * cfg["head"] * 0.78, layout["head_y"] + cfg["head"] * 0.30, layout["head_z"] - cfg["head"] * 0.04),
            (side * cfg["head"] * 1.02, layout["head_y"] + cfg["head"] * 0.56, layout["head_z"] - cfg["head"] * 0.12),
        ]
        for index in range(2):
            horn = PIPELINE.cone_between(
                f"BisonCompactHornDetail_{side:+.0f}_{index}", points[index], points[index + 1],
                cfg["head"] * (0.15 - index * 0.05), detail, hero,
            )
            PIPELINE.rigid_skin(horn, rig, "Head")
            parts.append(horn)

    beard_top = (0.0, layout["head_y"] - cfg["head"] * 0.42, layout["head_z"] - cfg["head"] * 0.05)
    beard_mid = (0.0, beard_top[1] - cfg["head"] * 0.38, beard_top[2] + cfg["head"] * 0.12)
    beard_tip = (0.0, beard_top[1] - cfg["head"] * 0.72, beard_top[2] + cfg["head"] * 0.20)
    for index, (start, end, radius) in enumerate(((beard_top, beard_mid, 0.17), (beard_mid, beard_tip, 0.12))):
        beard = PIPELINE.ellipsoid_between(
            f"BisonTaperedBeardSilhouette_{index}", start, end, cfg["head"] * radius,
            detail, hero, 0.72,
        )
        PIPELINE.rigid_skin(beard, rig, "Head")
        parts.append(beard)

    fringe_count = 3 if hero else 2
    for side in (-1.0, 1.0):
        for index in range(fringe_count):
            amount = index / max(fringe_count - 1, 1)
            start = (
                side * cfg["width"] * (0.48 + amount * 0.10),
                layout["shoulder_y"] - cfg["height"] * (0.12 + amount * 0.12),
                layout["front_z"] + cfg["length"] * (0.04 + amount * 0.15),
            )
            end = (start[0], start[1] - cfg["height"] * (0.25 - amount * 0.05), start[2] + 0.06)
            fringe = PIPELINE.ellipsoid_between(
                f"BisonForequarterFringeDetail_{side:+.0f}_{index}", start, end,
                cfg["paw"] * (0.28 - amount * 0.035), detail, hero, 0.68,
            )
            PIPELINE.rigid_skin(fringe, rig, "Chest")
            parts.append(fringe)


def customize_zebra(parts, hero: bool, rig, cfg: dict, layout: dict, coat, accent, detail) -> None:
    """Extend flush torso stripes over the articulated equine silhouette."""
    remove_named(parts, ("ManeQuillDetail", "V5TailBaseSilhouette", "V5TailTipSilhouette"))
    for obj in parts:
        if not obj.name.startswith(("V3UpperLimb", "V4LowerLimb", "V4Metapodial")):
            continue
        dark_index = PIPELINE.append_material(obj, detail)
        z_values = [vertex.co.z for vertex in obj.data.vertices]
        minimum = min(z_values)
        span = max(max(z_values) - minimum, 0.001)
        for polygon in obj.data.polygons:
            centre = sum(obj.data.vertices[index].co.z for index in polygon.vertices) / len(polygon.vertices)
            band = int((centre - minimum) / span * (4 if hero else 3))
            if band % 2 == 1:
                polygon.material_index = dark_index
        obj["eco_stripe_contract"] = "flush_articulated_leg_bands"

    mane_points = [
        (0.0, layout["head_y"] + cfg["head"] * 0.50, layout["head_z"] + cfg["head"] * 0.18),
        (0.0, (layout["head_y"] + layout["shoulder_y"]) * 0.62 + cfg["head"] * 0.28, (layout["head_z"] + layout["front_z"]) * 0.58),
        (0.0, layout["shoulder_y"] + cfg["height"] * 0.54, layout["front_z"] + cfg["length"] * 0.12),
        (0.0, layout["body_y"] + cfg["height"] * 0.54, layout["front_z"] + cfg["length"] * 0.32),
    ]
    for index in range(len(mane_points) - 1):
        mane = PIPELINE.ellipsoid_between(
            f"ZebraUprightManeSilhouette_{index}", mane_points[index], mane_points[index + 1],
            cfg["head"] * (0.12 - index * 0.012), detail, hero, 0.20,
        )
        PIPELINE.rigid_skin(mane, rig, "Neck" if index < 2 else "Chest")
        parts.append(mane)

    tail_start = (0.0, layout["body_y"], cfg["length"] * 0.62)
    tail_end = (0.0, max(0.18, layout["body_y"] - cfg["tail"] * 0.48), cfg["length"] * 0.62 + cfg["tail"] * 1.04)
    tail = connected_tail(
        "ZebraConnectedTailSilhouette", hero, rig, tail_start, tail_end,
        cfg["paw"] * 0.78, cfg["paw"] * 0.36, coat, 0.74,
    )
    parts.append(tail)
    switch = PIPELINE.ellipsoid_between(
        "ZebraBlackTailSwitchDetail",
        tuple(Vector(tail_start).lerp(Vector(tail_end), 0.74)), tail_end,
        cfg["paw"] * 0.74, detail, hero, 0.58,
    )
    PIPELINE.rigid_skin(switch, rig, "TailTip")
    parts.append(switch)

    for obj in parts:
        if obj.name.startswith("V5FootDetail"):
            obj.scale.y *= 0.64
            obj.scale.x *= 0.82
            obj["eco_hoof_contract"] = "compact_single_equine_hoof"


def customize_elephant(parts, hero: bool, rig, cfg: dict, layout: dict, coat, accent, detail) -> None:
    """Replace generic heavy-animal details with an African elephant silhouette."""
    remove_named(parts, (
        "TrunkDetail", "TuskDetail", "V5FootDetail", "ClawDetail", "V5Muscle", "V5Joint",
        "V5EarFanSilhouette",
        "V5TailBaseSilhouette", "V5TailTipSilhouette",
    ))

    for suffix, side in (("L", -1.0), ("R", 1.0)):
        centre = (
            side * cfg["head"] * 0.48,
            layout["head_y"] - cfg["head"] * 0.02,
            layout["head_z"] + cfg["head"] * 0.16,
        )
        ear_parts = PIPELINE.elephant_ear_fan(
            f"ElephantAngledEarFanSilhouette_{suffix}", side, centre,
            cfg["ear"] * 1.05, coat, accent, hero,
        )
        angle = side * 0.38
        cosine = math.cos(angle)
        sine = math.sin(angle)
        for ear_part in ear_parts:
            for vertex in ear_part.data.vertices:
                # Blender coordinates are X, Godot-Z, Godot-Y. Rotate the
                # ear around the vertical axis so a three-quarter game camera
                # reads its fan area instead of only the paper-thin edge.
                dx = vertex.co.x - centre[0]
                dz = vertex.co.y - centre[2]
                vertex.co.x = centre[0] + dx * cosine + dz * sine
                vertex.co.y = centre[2] - dx * sine + dz * cosine
            PIPELINE.rigid_skin(ear_part, rig, f"Ear_{suffix}")
            ear_part["eco_ear_contract"] = "broad_angled_african_elephant_fan"
            parts.append(ear_part)

    trunk_points = [
        (0.0, layout["head_y"] - cfg["head"] * 0.08, layout["muzzle_z"] - cfg["muzzle"] * 0.12),
        (0.0, layout["head_y"] - cfg["head"] * 0.42, layout["muzzle_z"] - cfg["muzzle"] * 0.28),
        (0.0, layout["head_y"] - cfg["head"] * 0.80, layout["muzzle_z"] - cfg["muzzle"] * 0.30),
        (0.0, layout["head_y"] - cfg["head"] * 1.18, layout["muzzle_z"] - cfg["muzzle"] * 0.20),
        (0.0, max(0.24, layout["head_y"] - cfg["head"] * 1.52), layout["muzzle_z"] + cfg["muzzle"] * 0.02),
    ]
    trunk = connected_weighted_tube(
        "ElephantConnectedTrunkSilhouette", hero, rig, trunk_points,
        [cfg["head"] * value for value in (0.25, 0.225, 0.185, 0.145, 0.105)],
        coat, "Head", "Jaw", 0.88,
    )
    trunk["eco_trunk_contract"] = "single_connected_tapered_head_jaw_skinned_trunk"
    parts.append(trunk)
    if hero:
        for side in (-1.0, 1.0):
            nostril = PIPELINE.uv_sphere(
                f"ElephantTrunkNostrilDetail_{side:+.0f}",
                (side * cfg["head"] * 0.045, trunk_points[-1][1] - cfg["head"] * 0.015, trunk_points[-1][2] - cfg["head"] * 0.075),
                (cfg["head"] * 0.035, cfg["head"] * 0.020, cfg["head"] * 0.048),
                detail, hero,
            )
            PIPELINE.rigid_skin(nostril, rig, "Jaw")
            parts.append(nostril)

    ivory = PIPELINE.pbr_material("elephant_authored_ivory_pbr", "#d9d0b6", 0.54)
    for side in (-1.0, 1.0):
        tusk_points = [
            (side * cfg["head"] * 0.34, layout["head_y"] - cfg["head"] * 0.18, layout["muzzle_z"] - cfg["muzzle"] * 0.10),
            (side * cfg["head"] * 0.40, layout["head_y"] - cfg["head"] * 0.40, layout["muzzle_z"] - cfg["head"] * 0.32),
            (side * cfg["head"] * 0.44, layout["head_y"] - cfg["head"] * 0.34, layout["muzzle_z"] - cfg["head"] * 0.66),
            (side * cfg["head"] * 0.46, layout["head_y"] - cfg["head"] * 0.14, layout["muzzle_z"] - cfg["head"] * 0.96),
        ]
        tusk = connected_weighted_tube(
            f"ElephantConnectedTuskDetail_{side:+.0f}", hero, rig, tusk_points,
            [cfg["head"] * value for value in (0.105, 0.082, 0.050, 0.014)],
            ivory, "Head", "Head", 0.94,
        )
        tusk["eco_tusk_contract"] = "single_connected_upcurved_ivory_tusk"
        parts.append(tusk)

    for suffix in LIMBS:
        _, _, _, toe = PIPELINE.ground_limb_points(cfg, layout, suffix)
        pad = PIPELINE.uv_sphere(
            f"ElephantRoundFootPadSilhouette_{suffix}",
            (toe[0], 0.115, toe[2] - cfg["paw"] * 0.04),
            (cfg["paw"] * 0.82, cfg["paw"] * 0.40, cfg["paw"] * 0.72),
            coat, hero,
        )
        PIPELINE.rigid_skin(pad, rig, f"Paw_{suffix}")
        pad["eco_foot_contract"] = "round_columnar_elephant_foot_pad"
        parts.append(pad)
        if hero:
            for nail_index in range(3):
                offset = (nail_index - 1) * cfg["paw"] * 0.34
                nail = PIPELINE.uv_sphere(
                    f"ElephantToenailDetail_{suffix}_{nail_index}",
                    (toe[0] + offset, 0.090, toe[2] - cfg["paw"] * 0.62),
                    (cfg["paw"] * 0.115, cfg["paw"] * 0.075, cfg["paw"] * 0.11),
                    detail, hero,
                )
                PIPELINE.rigid_skin(nail, rig, f"Paw_{suffix}")
                parts.append(nail)

    tail_start = (0.0, layout["body_y"] + cfg["height"] * 0.02, cfg["length"] * 0.60)
    tail_end = (0.0, max(0.30, layout["body_y"] - cfg["tail"] * 0.88), cfg["length"] * 0.60 + cfg["tail"] * 0.55)
    tail = connected_tail(
        "ElephantConnectedTailSilhouette", hero, rig, tail_start, tail_end,
        cfg["paw"] * 0.28, cfg["paw"] * 0.12, coat, 0.88,
    )
    parts.append(tail)
    tuft = PIPELINE.ellipsoid_between(
        "ElephantTailTuftDetail", tuple(Vector(tail_start).lerp(Vector(tail_end), 0.78)), tail_end,
        cfg["paw"] * 0.28, detail, hero, 0.62,
    )
    PIPELINE.rigid_skin(tuft, rig, "TailTip")
    parts.append(tuft)


def customize_tiger(parts, hero: bool, rig, cfg: dict, layout: dict, coat, accent, detail) -> None:
    """Build the tiger's rounded face, broad paws and flush striped tail."""
    remove_named(parts, (
        "V5EarSilhouette", "V5TailBaseSilhouette", "V5TailTipSilhouette",
        "ChestRuffDetail", "V5FootDetail", "ClawDetail",
    ))

    for suffix, side in (("L", -1.0), ("R", 1.0)):
        ear_position = (
            side * cfg["head"] * 0.49,
            layout["head_y"] + cfg["head"] * 0.47,
            layout["head_z"] + cfg["head"] * 0.08,
        )
        outer = PIPELINE.uv_sphere(
            f"TigerRoundedDarkEarSilhouette_{suffix}", ear_position,
            (cfg["head"] * 0.22, cfg["head"] * 0.25, cfg["head"] * 0.10),
            detail, hero,
        )
        PIPELINE.rigid_skin(outer, rig, f"Ear_{suffix}")
        parts.append(outer)
        inner = PIPELINE.uv_sphere(
            f"TigerRoundedEarInnerDetail_{suffix}",
            (ear_position[0], ear_position[1] - cfg["head"] * 0.02, ear_position[2] - cfg["head"] * 0.08),
            (cfg["head"] * 0.125, cfg["head"] * 0.145, cfg["head"] * 0.035),
            accent, hero,
        )
        PIPELINE.rigid_skin(inner, rig, f"Ear_{suffix}")
        parts.append(inner)

        cheek = PIPELINE.ellipsoid_between(
            f"TigerWhiteCheekRuffDetail_{side:+.0f}",
            (side * cfg["head"] * 0.52, layout["head_y"] - cfg["head"] * 0.04, layout["head_z"] - cfg["head"] * 0.30),
            (side * cfg["head"] * 0.74, layout["head_y"] - cfg["head"] * 0.20, layout["head_z"] - cfg["head"] * 0.10),
            cfg["head"] * 0.13, accent, hero, 0.58,
        )
        PIPELINE.rigid_skin(cheek, rig, "Head")
        parts.append(cheek)

    for obj in parts:
        if obj.name.startswith(("V3UpperLimb", "V4LowerLimb", "V4Metapodial")):
            dark_index = PIPELINE.append_material(obj, detail)
            z_values = [vertex.co.z for vertex in obj.data.vertices]
            minimum = min(z_values)
            span = max(max(z_values) - minimum, 0.001)
            for polygon in obj.data.polygons:
                centre = sum(obj.data.vertices[index].co.z for index in polygon.vertices) / len(polygon.vertices)
                band = int((centre - minimum) / span * (4 if hero else 3))
                if band == 1 or (hero and band == 3):
                    polygon.material_index = dark_index
            obj["eco_stripe_contract"] = "flush_tiger_leg_bands"
    for suffix in LIMBS:
        _, _, _, toe = PIPELINE.ground_limb_points(cfg, layout, suffix)
        paw = PIPELINE.uv_sphere(
            f"TigerRoundPawSilhouette_{suffix}",
            (toe[0], 0.095, toe[2] - cfg["paw"] * 0.20),
            (cfg["paw"] * 0.72, cfg["paw"] * 0.35, cfg["paw"] * 0.92),
            coat, hero,
        )
        PIPELINE.rigid_skin(paw, rig, f"Paw_{suffix}")
        paw["eco_paw_contract"] = "broad_round_retractile_claw_ambush_paw"
        parts.append(paw)
        if hero:
            for digit in range(3):
                offset = (digit - 1) * cfg["paw"] * 0.30
                toe_pad = PIPELINE.uv_sphere(
                    f"TigerToeDetail_{suffix}_{digit}",
                    (toe[0] + offset, 0.075, toe[2] - cfg["paw"] * 0.76),
                    (cfg["paw"] * 0.11, cfg["paw"] * 0.075, cfg["paw"] * 0.13),
                    detail, hero,
                )
                PIPELINE.rigid_skin(toe_pad, rig, f"Paw_{suffix}")
                parts.append(toe_pad)

    tail_start = (0.0, layout["body_y"], cfg["length"] * 0.62)
    tail_end = (0.0, max(0.30, layout["body_y"] - cfg["tail"] * 0.28), cfg["length"] * 0.62 + cfg["tail"] * 1.08)
    tail = connected_tail(
        "TigerConnectedRingedTailSilhouette", hero, rig, tail_start, tail_end,
        cfg["paw"] * 1.18, cfg["paw"] * 0.62, coat, 0.84,
    )
    dark_index = PIPELINE.append_material(tail, detail)
    start_b = Vector(PIPELINE.g2b(tail_start))
    end_b = Vector(PIPELINE.g2b(tail_end))
    direction = end_b - start_b
    denominator = max(direction.length_squared, 0.001)
    for polygon in tail.data.polygons:
        centre = sum((tail.data.vertices[index].co for index in polygon.vertices), Vector()) / len(polygon.vertices)
        amount = max(0.0, min(1.0, (centre - start_b).dot(direction) / denominator))
        band = int(amount * (8 if hero else 6))
        if band % 2 == 1 and amount > 0.24:
            polygon.material_index = dark_index
    tail["eco_tail_contract"] = "single_connected_flush_ringed_tiger_tail"
    parts.append(tail)


def customize_monkey(parts, hero: bool, rig, cfg: dict, layout: dict, coat, accent, detail) -> None:
    """Build macaque ears and a curved, connected balancing tail."""
    remove_named(parts, (
        "V5EarSilhouette", "V5TailBaseSilhouette", "V5TailTipSilhouette",
        "MuzzlePatchDetail", "V4LowerJawDetail", "V5FootDetail", "ClawDetail",
    ))
    face = PIPELINE.uv_sphere(
        "MacaqueCompactBareFaceSilhouette",
        (0.0, layout["head_y"] - cfg["head"] * 0.04, layout["muzzle_z"] - cfg["muzzle"] * 0.16),
        (cfg["head"] * 0.40, cfg["head"] * 0.37, cfg["muzzle"] * 0.45),
        accent, hero,
    )
    PIPELINE.rigid_skin(face, rig, "Head")
    parts.append(face)
    for suffix, side in (("L", -1.0), ("R", 1.0)):
        ear = PIPELINE.uv_sphere(
            f"MacaqueRoundEarSilhouette_{suffix}",
            (side * cfg["head"] * 0.55, layout["head_y"] + cfg["head"] * 0.12, layout["head_z"] + cfg["head"] * 0.05),
            (cfg["head"] * 0.18, cfg["head"] * 0.20, cfg["head"] * 0.075),
            accent, hero,
        )
        PIPELINE.rigid_skin(ear, rig, f"Ear_{suffix}")
        parts.append(ear)

    tail_base = (0.0, layout["body_y"] + cfg["height"] * 0.05, cfg["length"] * 0.42)
    tail_points = [
        tail_base,
        (0.0, layout["body_y"] + cfg["tail"] * 0.18, cfg["length"] * 0.58 + cfg["tail"] * 0.18),
        (0.0, layout["body_y"] + cfg["tail"] * 0.28, cfg["length"] * 0.56 + cfg["tail"] * 0.48),
        (0.0, layout["body_y"] + cfg["tail"] * 0.14, cfg["length"] * 0.48 + cfg["tail"] * 0.78),
        (0.0, layout["body_y"] - cfg["tail"] * 0.12, cfg["length"] * 0.42 + cfg["tail"] * 1.02),
    ]
    tail = connected_weighted_tube(
        "MacaqueConnectedCurvedTailSilhouette", hero, rig, tail_points,
        [cfg["paw"] * value for value in (0.48, 0.43, 0.34, 0.25, 0.15)],
        coat, "Tail", "TailTip", 0.88,
    )
    tail["eco_tail_contract"] = "single_connected_curved_macaque_balance_tail"
    parts.append(tail)

    for suffix in LIMBS:
        _, _, _, toe = PIPELINE.ground_limb_points(cfg, layout, suffix)
        palm = PIPELINE.uv_sphere(
            f"MacaqueGraspingPalmSilhouette_{suffix}",
            (toe[0], 0.085, toe[2] - cfg["paw"] * 0.14),
            (cfg["paw"] * 0.56, cfg["paw"] * 0.30, cfg["paw"] * 0.86),
            accent, hero,
        )
        PIPELINE.rigid_skin(palm, rig, f"Paw_{suffix}")
        palm["eco_hand_foot_contract"] = "compact_grasping_primate_hand_or_foot"
        parts.append(palm)


def customize_moose(parts, hero: bool, rig, cfg: dict, layout: dict, coat, accent, detail) -> None:
    """Replace branch-like deer antlers with broad bull-moose palms."""
    remove_named(parts, ("AntlerDetail", "AntlerBranchDetail", "BeardDetail"))
    for suffix, side in (("L", -1.0), ("R", 1.0)):
        root = (side * cfg["head"] * 0.38, layout["head_y"] + cfg["head"] * 0.40, layout["head_z"] + 0.02)
        beam_points = [
            root,
            (side * cfg["head"] * 0.66, layout["head_y"] + cfg["head"] * 0.78, layout["head_z"] + 0.02),
            (side * cfg["head"] * 1.02, layout["head_y"] + cfg["head"] * 1.08, layout["head_z"] + 0.04),
        ]
        beam = connected_weighted_tube(
            f"MooseAntlerBeamSilhouette_{suffix}", hero, rig, beam_points,
            [cfg["head"] * 0.105, cfg["head"] * 0.088, cfg["head"] * 0.068],
            detail, "Head", "Head", 0.88,
        )
        parts.append(beam)
        palm_start = beam_points[-1]
        palm_end = (
            side * cfg["head"] * 1.78,
            layout["head_y"] + cfg["head"] * 1.25,
            layout["head_z"] + cfg["head"] * 0.10,
        )
        palm = PIPELINE.ellipsoid_between(
            f"MoosePalmateAntlerSilhouette_{suffix}", palm_start, palm_end,
            cfg["head"] * 0.27, detail, hero, 0.28,
        )
        PIPELINE.rigid_skin(palm, rig, "Head")
        palm["eco_antler_contract"] = "broad_flat_bull_moose_palm"
        parts.append(palm)
        tine_count = 4 if hero else 3
        for index in range(tine_count):
            amount = (index + 0.32) / tine_count
            tine_start = tuple(Vector(palm_start).lerp(Vector(palm_end), amount))
            tine_end = (
                tine_start[0] + side * cfg["head"] * (0.20 + index * 0.035),
                tine_start[1] + cfg["head"] * (0.42 + index * 0.035),
                tine_start[2] - cfg["head"] * (0.08 + index * 0.025),
            )
            tine = PIPELINE.cone_between(
                f"MoosePalmTineDetail_{suffix}_{index}", tine_start, tine_end,
                cfg["head"] * (0.066 - index * 0.006), detail, hero,
            )
            PIPELINE.rigid_skin(tine, rig, "Head")
            parts.append(tine)
    bell_top = (0.0, layout["head_y"] - cfg["head"] * 0.42, layout["head_z"] - cfg["head"] * 0.08)
    bell_tip = (0.0, bell_top[1] - cfg["head"] * 0.78, bell_top[2] + cfg["head"] * 0.06)
    bell = PIPELINE.ellipsoid_between(
        "MooseThroatBellSilhouette", bell_top, bell_tip,
        cfg["head"] * 0.16, detail, hero, 0.48,
    )
    PIPELINE.rigid_skin(bell, rig, "Head")
    parts.append(bell)


def customize_cheetah(parts, hero: bool, rig, cfg: dict, layout: dict, coat, accent, detail) -> None:
    """Give the cursorial cat one continuously skinned counterbalance tail."""
    remove_named(parts, ("V5TailBaseSilhouette", "V5TailTipSilhouette"))
    tail_start = (0.0, layout["body_y"], cfg["length"] * 0.62)
    tail_end = (0.0, max(0.27, layout["body_y"] - cfg["tail"] * 0.24), cfg["length"] * 0.62 + cfg["tail"] * 1.10)
    tail = connected_tail(
        "CheetahConnectedBalanceTailSilhouette", hero, rig, tail_start, tail_end,
        cfg["paw"] * 0.94, cfg["paw"] * 0.48, coat, 0.82,
    )
    dark_index = PIPELINE.append_material(tail, detail)
    start_b = Vector(PIPELINE.g2b(tail_start))
    end_b = Vector(PIPELINE.g2b(tail_end))
    direction = end_b - start_b
    denominator = max(direction.length_squared, 0.001)
    for polygon in tail.data.polygons:
        centre = sum((tail.data.vertices[index].co for index in polygon.vertices), Vector()) / len(polygon.vertices)
        amount = max(0.0, min(1.0, (centre - start_b).dot(direction) / denominator))
        if amount > 0.72 and int(amount * (10 if hero else 8)) % 2 == 1:
            polygon.material_index = dark_index
    tail["eco_tail_contract"] = "single_connected_ring_tipped_cheetah_balance_tail"
    parts.append(tail)


def customize_hyena(parts, hero: bool, rig, cfg: dict, layout: dict, coat, accent, detail) -> None:
    remove_named(parts, ("V5TailBaseSilhouette", "V5TailTipSilhouette", "ManeQuillDetail"))
    tail_start = (0.0, layout["body_y"], cfg["length"] * 0.61)
    tail_end = (0.0, 0.31, cfg["length"] * 0.61 + cfg["tail"] * 0.96)
    tail = connected_tail(
        "HyenaConnectedCoarseTailSilhouette", hero, rig, tail_start, tail_end,
        cfg["paw"] * 0.82, cfg["paw"] * 0.40, coat, 0.88,
    )
    tail["eco_tail_contract"] = "single_connected_coarse_spotted_hyena_tail"
    parts.append(tail)
    ridge_count = 6 if hero else 4
    for index in range(ridge_count):
        amount = index / max(ridge_count - 1, 1)
        z = layout["front_z"] + cfg["length"] * (0.08 + amount * 0.76)
        ridge = PIPELINE.uv_sphere(
            f"HyenaFlushRidgeManeDetail_{index}",
            (0.0, layout["body_y"] + cfg["height"] * (0.61 - amount * 0.12), z),
            (cfg["width"] * 0.10, cfg["height"] * 0.19, cfg["length"] * 0.14),
            detail, hero,
        )
        PIPELINE.rigid_skin(ridge, rig, "Chest" if amount < 0.55 else "Spine")
        parts.append(ridge)


def customize_lion(parts, hero: bool, rig, cfg: dict, layout: dict, coat, accent, detail) -> None:
    remove_named(parts, (
        "V5TailBaseSilhouette", "V5TailTipSilhouette", "TailTipDetail",
        "ManeSilhouette", "ChestRuffDetail",
    ))
    mane_y = (layout["head_y"] + layout["shoulder_y"]) * 0.50
    mane_z = layout["head_z"] + cfg["head"] * 0.16
    mane_parts = [
        ("LionNeckManeSilhouette", (0.0, mane_y, mane_z), (cfg["head"] * 0.88, cfg["head"] * 0.90, cfg["head"] * 0.64)),
        ("LionCheekManeSilhouette_L", (-cfg["head"] * 0.42, mane_y - cfg["head"] * 0.04, mane_z - cfg["head"] * 0.08), (cfg["head"] * 0.38, cfg["head"] * 0.62, cfg["head"] * 0.36)),
        ("LionCheekManeSilhouette_R", (cfg["head"] * 0.42, mane_y - cfg["head"] * 0.04, mane_z - cfg["head"] * 0.08), (cfg["head"] * 0.38, cfg["head"] * 0.62, cfg["head"] * 0.36)),
        ("LionChestManeSilhouette", (0.0, layout["shoulder_y"] + cfg["height"] * 0.14, layout["front_z"] - cfg["head"] * 0.02), (cfg["head"] * 0.42, cfg["head"] * 0.38, cfg["head"] * 0.24)),
    ]
    for name, position, scale in mane_parts:
        mane = PIPELINE.uv_sphere(name, position, scale, detail, hero)
        PIPELINE.rigid_skin(mane, rig, "Neck" if "Chest" not in name else "Chest")
        parts.append(mane)
    tail_start = (0.0, layout["body_y"], cfg["length"] * 0.61)
    tail_end = (0.0, max(0.30, layout["body_y"] - cfg["tail"] * 0.30), cfg["length"] * 0.61 + cfg["tail"] * 1.06)
    tail = connected_tail(
        "LionConnectedTuftedTailSilhouette", hero, rig, tail_start, tail_end,
        cfg["paw"] * 0.54, cfg["paw"] * 0.24, coat, 0.84,
    )
    tail["eco_tail_contract"] = "single_connected_lion_tail_with_compact_tuft"
    parts.append(tail)
    tuft = PIPELINE.uv_sphere(
        "LionCompactTailTuftDetail", tail_end,
        (cfg["paw"] * 0.34, cfg["paw"] * 0.40, cfg["paw"] * 0.48),
        detail, hero,
    )
    PIPELINE.rigid_skin(tuft, rig, "TailTip")
    parts.append(tuft)


def customize_actions(species: str, rig) -> None:
    if species not in ("lynx", "goat", "wolverine", "bison", "zebra", "elephant", "tiger", "monkey", "moose"):
        return
    rig.animation_data_create()

    def insert(action_name: str, bone_name: str, frame: int, xyz) -> None:
        rig.animation_data.action = bpy.data.actions[action_name]
        bone = rig.pose.bones[bone_name]
        bone.rotation_mode = "XYZ"
        bone.rotation_euler = xyz
        bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=bone_name)

    for frame, amount in ((1, 0.0), (6, 0.28), (11, 1.0), (16, -0.52), (24, 0.0)):
        if species == "lynx":
            insert("skill", "Spine", frame, (-0.22 * abs(amount), 0.0, 0.06 * amount))
            insert("skill", "Chest", frame, (0.16 * abs(amount), 0.0, -0.04 * amount))
            insert("skill", "Neck", frame, (-0.18 * amount, 0.0, 0.0))
            insert("skill", "Tail", frame, (0.0, 0.0, 0.24 * amount))
            for suffix in LIMBS:
                rear = suffix.endswith("H")
                insert("skill", f"Leg_{suffix}", frame, ((-0.48 if rear else 0.34) * amount, 0.0, 0.0))
                insert("skill", f"Lower_{suffix}", frame, ((0.72 if rear else -0.48) * abs(amount), 0.0, 0.0))
                insert("skill", f"Paw_{suffix}", frame, (-0.26 * abs(amount), 0.0, 0.0))
        elif species == "goat":
            insert("skill", "Spine", frame, (-0.12 * abs(amount), 0.0, 0.0))
            insert("skill", "Chest", frame, (0.20 * amount, 0.0, 0.0))
            insert("skill", "Neck", frame, (-0.48 * amount, 0.0, 0.0))
            insert("skill", "Head", frame, (-0.34 * amount, 0.0, 0.0))
            for suffix in LIMBS:
                rear = suffix.endswith("H")
                insert("skill", f"Leg_{suffix}", frame, ((-0.56 if rear else 0.28) * amount, 0.0, 0.0))
                insert("skill", f"Lower_{suffix}", frame, ((0.78 if rear else -0.34) * abs(amount), 0.0, 0.0))
                insert("skill", f"Paw_{suffix}", frame, (-0.24 * abs(amount), 0.0, 0.0))
        elif species == "wolverine":
            # The wolverine plants its rear paws, twists through the shoulders,
            # hooks with one forepaw and finishes with a deep tearing bite.
            insert("skill", "Spine", frame, (-0.20 * abs(amount), 0.0, 0.18 * amount))
            insert("skill", "Chest", frame, (0.16 * abs(amount), 0.0, -0.24 * amount))
            insert("skill", "Neck", frame, (0.26 * amount, 0.0, 0.10 * amount))
            insert("skill", "Head", frame, (0.30 * amount, 0.0, 0.12 * amount))
            insert("skill", "Jaw", frame, (-0.44 * max(amount, 0.0), 0.0, 0.0))
            insert("skill", "Leg_LF", frame, (-0.78 * amount, 0.0, -0.22 * amount))
            insert("skill", "Lower_LF", frame, (0.58 * abs(amount), 0.0, 0.0))
            insert("skill", "Paw_LF", frame, (-0.34 * abs(amount), 0.0, 0.0))
            insert("skill", "Leg_RF", frame, (-0.22 * amount, 0.0, 0.16 * amount))
            for suffix in ("LH", "RH"):
                insert("skill", f"Leg_{suffix}", frame, (0.22 * abs(amount), 0.0, 0.0))
                insert("skill", f"Lower_{suffix}", frame, (0.34 * abs(amount), 0.0, 0.0))
        elif species == "bison":
            # A bison drops the head behind the shoulder mass, braces the
            # forequarters, then drives and hooks upward through both horns.
            drive = max(amount, 0.0)
            insert("skill", "Spine", frame, (-0.10 * abs(amount), 0.0, 0.0))
            insert("skill", "Chest", frame, (0.12 * drive, 0.0, 0.0))
            insert("skill", "Neck", frame, (0.52 * amount, 0.0, 0.0))
            insert("skill", "Head", frame, (0.46 * amount, 0.0, 0.0))
            for suffix in ("LF", "RF"):
                insert("skill", f"Leg_{suffix}", frame, (-0.24 * abs(amount), 0.0, 0.0))
                insert("skill", f"Lower_{suffix}", frame, (0.30 * abs(amount), 0.0, 0.0))
                insert("skill", f"Paw_{suffix}", frame, (-0.16 * abs(amount), 0.0, 0.0))
            for suffix in ("LH", "RH"):
                insert("skill", f"Leg_{suffix}", frame, (0.36 * drive, 0.0, 0.0))
                insert("skill", f"Lower_{suffix}", frame, (0.42 * drive, 0.0, 0.0))
            insert("skill", "Tail", frame, (0.0, 0.0, 0.18 * amount))
        elif species == "zebra":
            # The zebra shifts onto both forelegs, gathers the hocks, then
            # extends both hind hooves in a compact defensive double kick.
            kick = max(amount, 0.0)
            insert("skill", "Spine", frame, (-0.18 * kick, 0.0, 0.0))
            insert("skill", "Chest", frame, (0.14 * kick, 0.0, 0.0))
            insert("skill", "Neck", frame, (-0.12 * amount, 0.0, 0.0))
            insert("skill", "Head", frame, (0.08 * amount, 0.0, 0.0))
            for suffix in ("LF", "RF"):
                insert("skill", f"Leg_{suffix}", frame, (0.20 * kick, 0.0, 0.0))
                insert("skill", f"Lower_{suffix}", frame, (-0.18 * kick, 0.0, 0.0))
            for suffix in ("LH", "RH"):
                insert("skill", f"Leg_{suffix}", frame, (-0.88 * amount, 0.0, 0.0))
                insert("skill", f"Lower_{suffix}", frame, (0.64 * abs(amount), 0.0, 0.0))
                insert("skill", f"Paw_{suffix}", frame, (-0.30 * abs(amount), 0.0, 0.0))
            insert("skill", "Tail", frame, (0.0, 0.0, 0.24 * amount))
        elif species == "elephant":
            # The elephant gathers its weight, lifts both forefeet, then
            # stamps through the chest while the trunk recoils from the shock.
            stomp = max(amount, 0.0)
            insert("skill", "Spine", frame, (-0.08 * stomp, 0.0, 0.0))
            insert("skill", "Chest", frame, (0.18 * amount, 0.0, 0.0))
            insert("skill", "Neck", frame, (-0.20 * amount, 0.0, 0.0))
            insert("skill", "Head", frame, (-0.28 * amount, 0.0, 0.0))
            insert("skill", "Jaw", frame, (0.36 * amount, 0.0, 0.0))
            for suffix in ("LF", "RF"):
                insert("skill", f"Leg_{suffix}", frame, (-0.42 * stomp, 0.0, 0.0))
                insert("skill", f"Lower_{suffix}", frame, (0.34 * stomp, 0.0, 0.0))
                insert("skill", f"Paw_{suffix}", frame, (-0.18 * stomp, 0.0, 0.0))
            for suffix in ("LH", "RH"):
                insert("skill", f"Leg_{suffix}", frame, (0.12 * stomp, 0.0, 0.0))
                insert("skill", f"Lower_{suffix}", frame, (0.16 * stomp, 0.0, 0.0))
            insert("skill", "Tail", frame, (0.0, 0.0, 0.14 * amount))
        elif species == "tiger":
            # A tiger compresses low through the pelvis, launches both rear
            # legs, reaches with the forepaws and finishes in a jaw clamp.
            launch = max(amount, 0.0)
            insert("skill", "Spine", frame, (-0.28 * abs(amount), 0.0, 0.08 * amount))
            insert("skill", "Chest", frame, (0.24 * launch, 0.0, -0.06 * amount))
            insert("skill", "Neck", frame, (-0.26 * amount, 0.0, 0.0))
            insert("skill", "Head", frame, (-0.18 * amount, 0.0, 0.0))
            insert("skill", "Jaw", frame, (-0.48 * launch, 0.0, 0.0))
            for suffix in ("LF", "RF"):
                insert("skill", f"Leg_{suffix}", frame, (-0.66 * amount, 0.0, 0.0))
                insert("skill", f"Lower_{suffix}", frame, (0.38 * abs(amount), 0.0, 0.0))
                insert("skill", f"Paw_{suffix}", frame, (-0.20 * abs(amount), 0.0, 0.0))
            for suffix in ("LH", "RH"):
                insert("skill", f"Leg_{suffix}", frame, (0.72 * amount, 0.0, 0.0))
                insert("skill", f"Lower_{suffix}", frame, (0.76 * abs(amount), 0.0, 0.0))
                insert("skill", f"Paw_{suffix}", frame, (-0.30 * abs(amount), 0.0, 0.0))
            insert("skill", "Tail", frame, (0.0, 0.0, -0.20 * amount))
        elif species == "monkey":
            # The macaque braces on three limbs, coils through the torso and
            # whips the right arm forward to release a fruit projectile.
            throw = max(amount, 0.0)
            insert("skill", "Spine", frame, (-0.10 * abs(amount), 0.0, -0.28 * amount))
            insert("skill", "Chest", frame, (0.12 * throw, 0.0, 0.36 * amount))
            insert("skill", "Neck", frame, (-0.10 * amount, 0.0, -0.12 * amount))
            insert("skill", "Head", frame, (0.08 * amount, 0.0, -0.16 * amount))
            insert("skill", "Leg_RF", frame, (-1.02 * amount, 0.0, 0.30 * amount))
            insert("skill", "Lower_RF", frame, (0.82 * abs(amount), 0.0, 0.0))
            insert("skill", "Paw_RF", frame, (-0.42 * throw, 0.0, 0.0))
            insert("skill", "Leg_LF", frame, (0.20 * throw, 0.0, -0.18 * amount))
            for suffix in ("LH", "RH"):
                insert("skill", f"Leg_{suffix}", frame, (0.26 * throw, 0.0, 0.0))
                insert("skill", f"Lower_{suffix}", frame, (0.30 * throw, 0.0, 0.0))
            insert("skill", "Tail", frame, (0.0, 0.0, 0.32 * amount))
        else:
            drive = max(amount, 0.0)
            insert("skill", "Spine", frame, (-0.12 * abs(amount), 0.0, 0.0))
            insert("skill", "Chest", frame, (0.18 * drive, 0.0, 0.0))
            insert("skill", "Neck", frame, (0.58 * amount, 0.0, 0.0))
            insert("skill", "Head", frame, (0.42 * amount, 0.0, 0.0))
            for suffix in ("LF", "RF"):
                insert("skill", f"Leg_{suffix}", frame, (-0.28 * abs(amount), 0.0, 0.0))
                insert("skill", f"Lower_{suffix}", frame, (0.38 * abs(amount), 0.0, 0.0))
                insert("skill", f"Paw_{suffix}", frame, (-0.18 * abs(amount), 0.0, 0.0))
            for suffix in ("LH", "RH"):
                insert("skill", f"Leg_{suffix}", frame, (0.42 * drive, 0.0, 0.0))
                insert("skill", f"Lower_{suffix}", frame, (0.48 * drive, 0.0, 0.0))
    rig.animation_data.action = bpy.data.actions["idle"]


def triangle_count(objects) -> tuple[int, int]:
    triangles = 0
    vertices = 0
    for obj in objects:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
        vertices += len(obj.data.vertices)
    return triangles, vertices


def optimize_mobile_body(body) -> None:
    """Reserve the shared 30-species budget without changing Hero quality."""
    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    modifier = body.modifiers.new("MobileSilhouetteDecimate", "DECIMATE")
    modifier.decimate_type = "COLLAPSE"
    modifier.ratio = 0.56
    modifier.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    body.select_set(False)
    body["eco_mobile_lod"] = "silhouette_decimate_0_56"


def export_species(
    species: str,
    source_dir: Path,
    output_root: Path,
    source_files: dict[str, str],
    source_reference: str,
    config_overrides: dict,
    anatomy_overrides: dict,
    tint: tuple[float, float, float],
    hero: bool,
) -> tuple[int, int, int]:
    verify_source(source_dir, source_files, species)
    PIPELINE.reset_scene()
    cfg = PIPELINE.config_for(species)
    cfg.update(config_overrides)
    cfg["v5"].update(anatomy_overrides)
    layout = PIPELINE.ground_layout(cfg)
    if species == "bison":
        layout["head_y"] -= cfg["height"] * 0.28
    rig, anchors = PIPELINE.build_ground_rig(species, cfg, layout)
    parts = PIPELINE.build_ground_parts(species, hero, rig, anchors, cfg, layout)
    project_root = Path(__file__).resolve().parents[2]
    skin_species = species in ("elephant", "turtle", "rhino", "hippo")
    coat = (
        PIPELINE.pbr_material(f"{species}_cinematic_coat_pbr", cfg["coat"], 0.94 if species != "turtle" else 0.82)
        if skin_species else coat_material(project_root, species, tint, hero, 0.86)
    )
    accent = PIPELINE.pbr_material(f"{species}_cinematic_accent_pbr", cfg["accent"], 0.88)
    detail = PIPELINE.pbr_material(f"{species}_cinematic_detail_pbr", cfg["dark"], 0.76)
    eye = PIPELINE.pbr_material(f"{species}_cinematic_eye_pbr", cfg["eye"], 0.10)
    replace_materials(parts, coat, accent, detail, eye)
    organic_body = next(obj for obj in parts if "OrganicBodyV2" in obj.name)
    if not hero:
        optimize_mobile_body(organic_body)
    BEAR.smart_uv(organic_body)
    if species == "lynx":
        customize_lynx(parts, hero, rig, cfg, layout, coat, accent, detail)
    elif species == "goat":
        customize_goat(parts, hero, rig, cfg, layout, coat, accent, detail)
    elif species == "wolverine":
        customize_wolverine(parts, hero, rig, cfg, layout, coat, accent, detail)
    elif species == "bison":
        customize_bison(parts, hero, rig, cfg, layout, coat, accent, detail)
    elif species == "zebra":
        customize_zebra(parts, hero, rig, cfg, layout, coat, accent, detail)
    elif species == "elephant":
        customize_elephant(parts, hero, rig, cfg, layout, coat, accent, detail)
    elif species == "tiger":
        customize_tiger(parts, hero, rig, cfg, layout, coat, accent, detail)
    elif species == "monkey":
        customize_monkey(parts, hero, rig, cfg, layout, coat, accent, detail)
    elif species == "moose":
        customize_moose(parts, hero, rig, cfg, layout, coat, accent, detail)
    elif species == "cheetah":
        customize_cheetah(parts, hero, rig, cfg, layout, coat, accent, detail)
    elif species == "hyena":
        customize_hyena(parts, hero, rig, cfg, layout, coat, accent, detail)
    elif species == "lion":
        customize_lion(parts, hero, rig, cfg, layout, coat, accent, detail)
    PIPELINE.validate_continuous_flesh(species, parts)
    rig.data.name = f"{species.title()}AuthoredCinematicRig"
    rig["rig_version"] = 6
    rig["skin_mode"] = "project_authored_weighted_cinematic"
    rig["source_reference"] = source_reference
    rig["anatomy_profile"] = f"adult_{species}_species_specific_v1"
    rig["locomotion_profile"] = f"authored_{species}_gait_and_skill"
    rig["surface_profile"] = f"species_authored_{'skin_or_shell' if skin_species else 'tinted_fur'}_pbr_{species}"
    PIPELINE.create_ground_actions(rig, cfg)
    customize_actions(species, rig)
    profile = "hero" if hero else "mobile"
    output = output_root / species / f"{species}_{profile}.glb"
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(
        filepath=str(output), export_format="GLB", use_selection=True,
        export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
        export_yup=True, export_apply=True,
    )
    triangles, vertices = triangle_count(parts)
    if not output.is_file() or output.stat().st_size < 4096:
        raise RuntimeError(f"failed to export {output}")
    return triangles, vertices, len(rig.data.bones)


def run_species(
    species: str,
    description: str,
    source_files: dict[str, str],
    source_reference: str,
    config_overrides: dict,
    anatomy_overrides: dict,
    tint: tuple[float, float, float],
) -> None:
    args = parse_args(description)
    source_dir = Path(args.source_dir).resolve()
    output_root = Path(args.output_root).resolve()
    for hero in (True, False):
        triangles, vertices, bones = export_species(
            species, source_dir, output_root, source_files, source_reference,
            config_overrides, anatomy_overrides, tint, hero,
        )
        profile = "hero" if hero else "mobile"
        print(f"AUTHORED_{species.upper()}_OK: {profile} / {triangles} triangles / {vertices} vertices / {bones} bones")
