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
    cfg.update(width=0.86, height=0.82, length=1.62, leg=0.78, paw=0.27, head=0.56, muzzle=0.46, neck=0.40, tail=0.24, ear=0.18)
    cfg["v3"].update(
        gait="lumber",
        sprint_gait="charge",
        stride=0.31,
        flex=0.43,
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
            (side * 0.64, 1.43, -0.62),
            (side * 0.66, 0.87, -0.69),
            (side * 0.67, 0.29, -0.62),
            (side * 0.68, 0.11, -0.88),
        )
    return (
        (side * 0.62, 1.25, 0.58),
        (side * 0.65, 0.79, 0.42),
        (side * 0.67, 0.28, 0.69),
        (side * 0.68, 0.11, 0.43),
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

    spine = add_bone(edit, "Spine", (0.0, 1.22, 0.70), (0.0, 1.25, 0.06), root)
    chest = add_bone(edit, "Chest", (0.0, 1.25, 0.06), (0.0, 1.45, -0.62), spine)
    neck = add_bone(edit, "Neck", (0.0, 1.45, -0.62), (0.0, 1.54, -1.16), chest)
    head = add_bone(edit, "Head", (0.0, 1.54, -1.16), (0.0, 1.42, -1.96), neck)
    jaw = add_bone(edit, "Jaw", (0.0, 1.33, -1.56), (0.0, 1.28, -2.02), head)
    jaw.use_deform = False

    anchors = {
        "Spine": (0.0, 1.22, 0.56),
        "Chest": (0.0, 1.43, -0.52),
        "Neck": (0.0, 1.52, -1.02),
        "Head": (0.0, 1.49, -1.58),
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
        base = (side * 0.34, 1.72, -1.48)
        tip = (side * 0.43, 1.91, -1.46)
        add_bone(edit, f"Ear_{suffix}", base, tip, head)
        anchors[f"Ear_{suffix}"] = tuple(Vector(base).lerp(Vector(tip), 0.5))

    tail = add_bone(edit, "Tail", (0.0, 1.23, 1.05), (0.0, 1.20, 1.25), spine)
    add_bone(edit, "TailTip", (0.0, 1.20, 1.25), (0.0, 1.15, 1.39), tail)
    anchors["Tail"] = (0.0, 1.215, 1.15)
    anchors["TailTip"] = (0.0, 1.175, 1.32)
    bpy.ops.object.mode_set(mode="OBJECT")

    if len(rig.data.bones) != 22:
        raise RuntimeError(f"bear runtime rig is not the 22-bone contract: {len(rig.data.bones)}")
    rig["eco_species"] = "bear"
    rig["rig_version"] = 6
    rig["skin_mode"] = "project_authored_weighted_cinematic"
    rig["source_reference_sha256"] = SOURCE_SHA256
    rig["source_archive_sha256"] = ARCHIVE_SHA256
    rig["anatomy_profile"] = "adult_brown_bear_shouldered_plantigrade_v1"
    rig["locomotion_profile"] = "heavy_four_beat_plantigrade_with_articulated_knees"
    rig["surface_profile"] = "tinted_fur_pbr_wet_nose_keratin_claws"
    rig["limb_segments"] = 3
    return rig, anchors


def tinted_fur_image(path: Path, name: str, tint: tuple[float, float, float], hero: bool) -> bpy.types.Image:
    source = bpy.data.images.load(str(path), check_existing=False)
    source.colorspace_settings.name = "sRGB"
    size = 512 if hero else 256
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
    image.scale(512 if hero else 256, 512 if hero else 256)
    image.name = name
    image.colorspace_settings.name = colorspace
    image.pack()
    return image


def coat_material(project_root: Path, hero: bool) -> bpy.types.Material:
    shared = project_root / "assets/textures/animals/shared"
    albedo = tinted_fur_image(shared / "quadruped_fur_atlas_albedo.png", "bear_fur_albedo", (0.31, 0.205, 0.125), hero)
    normal = packed_image(shared / "quadruped_fur_atlas_normal.png", "bear_fur_normal", "Non-Color", hero)
    roughness = packed_image(shared / "quadruped_fur_atlas_roughness.png", "bear_fur_roughness", "Non-Color", hero)
    material = bpy.data.materials.new("bear_cinematic_coat_pbr")
    material.use_nodes = True
    material.diffuse_color = (0.31, 0.205, 0.125, 1.0)
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    principled = nodes.get("Principled BSDF")
    if principled is None:
        raise RuntimeError("missing Principled BSDF")
    principled.inputs["Roughness"].default_value = 0.86
    albedo_node = nodes.new("ShaderNodeTexImage")
    albedo_node.image = albedo
    links.new(albedo_node.outputs["Color"], principled.inputs["Base Color"])
    normal_node = nodes.new("ShaderNodeTexImage")
    normal_node.image = normal
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = 0.48
    links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])
    roughness_node = nodes.new("ShaderNodeTexImage")
    roughness_node.image = roughness
    links.new(roughness_node.outputs["Color"], principled.inputs["Roughness"])
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
    modifier.strength = 0.008 if hero else 0.005
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
        "Spine": 0.86, "Chest": 0.88, "Neck": 0.64, "Head": 0.58,
        "Leg_LF": 0.38, "Leg_RF": 0.38, "Leg_LH": 0.38, "Leg_RH": 0.38,
        "Lower_LF": 0.27, "Lower_RF": 0.27, "Lower_LH": 0.27, "Lower_RH": 0.27,
        "Paw_LF": 0.34, "Paw_RF": 0.34, "Paw_LH": 0.34, "Paw_RH": 0.34,
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
        ((0.0, 1.22, 0.58), (0.84, 0.70, 0.66), 2.36),
        ((0.0, 1.20, 0.04), (0.88, 0.73, 0.78), 2.42),
        ((0.0, 1.36, -0.54), (0.96, 0.86, 0.64), 2.42),
        ((0.0, 1.79, -0.52), (0.78, 0.54, 0.52), 2.28),
        ((0.0, 1.50, -0.93), (0.66, 0.62, 0.54), 2.50),
        ((0.0, 1.52, -1.30), (0.60, 0.55, 0.48), 2.46),
        ((0.0, 1.51, -1.57), (0.57, 0.50, 0.50), 2.42),
        ((0.0, 1.37, -1.83), (0.39, 0.30, 0.43), 2.48),
        ((0.0, 1.31, -2.02), (0.29, 0.22, 0.30), 2.44),
    ]
    # Build all four furred limbs and the top of every plantigrade paw into the
    # same metaball volume as the torso.  This creates one manifold coat surface
    # across shoulders, knees, heels and feet, so animation cannot reveal gaps.
    for suffix in LIMBS:
        hip, joint, ankle, toe = limb_points(suffix)
        front = suffix.endswith("F")
        upper_mid = Vector(hip).lerp(Vector(joint), 0.50)
        lower_mid = Vector(joint).lerp(Vector(ankle), 0.52)
        paw_center = Vector((toe[0], 0.13, toe[2] - (0.10 if front else 0.08)))
        elements.extend([
            (tuple(Vector(hip).lerp(Vector(joint), 0.18)), (0.37 if front else 0.35, 0.38, 0.33), 2.58),
            (tuple(upper_mid), (0.31 if front else 0.30, 0.39, 0.28), 2.62),
            (tuple(joint), (0.27, 0.27, 0.25), 2.68),
            (tuple(lower_mid), (0.225, 0.35, 0.22), 2.66),
            (tuple(ankle), (0.25, 0.21, 0.25), 2.68),
            (tuple(paw_center), (0.31, 0.16, 0.40), 2.72),
        ])
    body = PIPELINE.metaball_mesh("BearOrganicBodyV2_SourceConnected", elements, coat, hero)
    body.data.name = "BrownBearOrganicBodyV2SourceMesh"
    body["eco_anatomy_contract"] = "adult_brown_bear_continuous_torso_short_muzzle"
    body["eco_surface_pattern"] = "authored_brown_fur_pbr"
    accent_index = PIPELINE.append_material(body, accent)
    for polygon in body.data.polygons:
        centre = sum((body.data.vertices[index].co for index in polygon.vertices), Vector()) / len(polygon.vertices)
        godot_y = centre.z
        godot_z = centre.y
        if godot_z < -1.66 and godot_y < 1.48:
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
        sphere(f"BearRoundEarSilhouette_{suffix}", (side * 0.37, 1.73, -1.46), (0.23, 0.23, 0.15), coat, f"Ear_{suffix}")
        sphere(f"BearInnerEarDetail_{suffix}", (side * 0.37, 1.73, -1.57), (0.125, 0.125, 0.030), paw, f"Ear_{suffix}")

    # Brow, small deep-set eyes, broad wet nose and lower muzzle.
    for suffix, side in (("L", -1.0), ("R", 1.0)):
        sphere(f"BearBrowSilhouette_{suffix}", (side * 0.29, 1.61, -1.70), (0.16, 0.075, 0.105), coat, "Head")
        sphere(f"V5EyeDetail_{suffix}", (side * 0.34, 1.53, -1.77), (0.040, 0.043, 0.032), eye, "Head")
    sphere("BearWetNoseDetail", (0.0, 1.37, -2.19), (0.235, 0.17, 0.13), nose, "Head")
    for suffix, side in (("L", -1.0), ("R", 1.0)):
        sphere(f"BearNostrilDetail_{suffix}", (side * 0.105, 1.39, -2.295), (0.046, 0.030, 0.018), paw, "Head")
    capsule("BearLowerJawAccent", (0.0, 1.31, -1.68), (0.0, 1.24, -2.02), 0.27, accent, "Jaw", 0.70)
    capsule("BearMouthLineDetail", (0.0, 1.26, -1.84), (0.0, 1.245, -2.06), 0.022, paw, "Jaw", 0.45)

    for suffix in LIMBS:
        _hip, _joint, _ankle, toe = limb_points(suffix)
        front = suffix.endswith("F")
        paw_z = toe[2] - (0.12 if front else 0.10)
        sphere(f"BearPawPadDetail_{suffix}", (toe[0], 0.055, paw_z + 0.02), (0.22, 0.035, 0.25), paw, f"Paw_{suffix}")
        digit_count = 5 if hero else 3
        for digit_index in range(digit_count):
            lateral = (digit_index - (digit_count - 1) * 0.5) * (0.105 if hero else 0.14)
            start = (toe[0] + lateral, 0.125, paw_z - 0.20)
            end = (toe[0] + lateral, 0.090, paw_z - 0.30)
            claw(f"BearClawDetail_{suffix}_{digit_index}", start, end, 0.018 if hero else 0.021, f"Paw_{suffix}")

    capsule("BearTailBaseSilhouette", (0.0, 1.23, 1.03), (0.0, 1.19, 1.25), 0.20, coat, "Tail", 0.92)
    sphere("BearTailTipSilhouette", (0.0, 1.17, 1.32), (0.18, 0.18, 0.20), coat, "TailTip")
    return parts


def attach_sockets(rig: bpy.types.Object) -> None:
    PIPELINE.attach_socket("SkillSocket_Mouth", (0.0, 1.35, -2.23), rig, "Head")
    PIPELINE.attach_socket("SkillSocket_Chest", (0.0, 1.48, -0.58), rig, "Chest")


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
    keratin = solid_material("bear_cinematic_keratin_pbr", "#8c755e", 0.54)
    body = build_bear_body(hero, rig, anchors, cfg, coat, accent)
    PIPELINE.validate_continuous_flesh("bear", [body])
    details = build_bear_details(hero, rig, coat, accent, eye, nose, paw, keratin)
    attach_sockets(rig)
    PIPELINE.create_ground_actions(rig, cfg)

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
