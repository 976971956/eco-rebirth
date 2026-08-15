from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

import bpy


REQUIRED_SPECIES = [
    "rabbit", "fox", "deer", "wolf", "snake", "bear",
    "boar", "raccoon", "porcupine", "crocodile", "capybara", "otter",
    "lynx", "goat", "wolverine", "bison", "zebra", "elephant", "tiger",
    "monkey", "owl", "moose", "turtle", "cheetah", "rhino", "gorilla",
    "eagle", "hippo", "hyena", "lion",
]
REQUIRED_ACTIONS = {"idle", "locomotion", "sprint", "attack", "skill", "hit", "eat", "death"}
VALID_RIGS = {
    "lagomorph", "canid_small", "canid_pack", "felid", "ungulate",
    "heavy_quadruped", "primate", "avian", "long_body", "chelonians",
}


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description="Validate Eco Rebirth Blender art pipeline")
    parser.add_argument("--config", required=True)
    parser.add_argument("--smoke-output", required=True)
    return parser.parse_args(argv)


def validate_config(config: dict) -> None:
    if config.get("schema_version") != 1:
        raise RuntimeError("pipeline_config.json must use schema_version 1")
    if config.get("godot_version") != "4.7.1":
        raise RuntimeError("pipeline must target Godot 4.7.1")
    minimum_version = tuple(int(part) for part in str(config.get("blender_min_version", "0.0.0")).split("."))
    if bpy.app.version < minimum_version:
        raise RuntimeError(
            f"Blender {bpy.app.version_string} is older than the required "
            f"{config.get('blender_min_version')}"
        )

    budgets = config.get("budgets", {})
    hero = budgets.get("hero", {})
    mobile = budgets.get("mobile", {})
    if not (18000 <= int(hero.get("triangles_min", 0)) < int(hero.get("triangles_max", 0)) <= 35000):
        raise RuntimeError("Hero triangle budget must remain inside 18k-35k")
    if not (3000 <= int(mobile.get("triangles_min", 0)) < int(mobile.get("triangles_max", 0)) <= 8000):
        raise RuntimeError("Mobile triangle budget must remain inside 3k-8k")
    if int(hero.get("material_slots_max", 0)) > 4 or int(mobile.get("material_slots_max", 0)) > 3:
        raise RuntimeError("material-slot budget exceeds the cross-platform contract")

    rig_families = config.get("rig_families", {})
    if set(rig_families) != VALID_RIGS:
        raise RuntimeError("rig family list is incomplete")
    for rig_id, rig_data in rig_families.items():
        actions = set(rig_data.get("actions", []))
        if not REQUIRED_ACTIONS.issubset(actions):
            missing = sorted(REQUIRED_ACTIONS - actions)
            raise RuntimeError(f"{rig_id} is missing actions: {missing}")

    species = config.get("species", [])
    ids = [entry.get("id", "") for entry in species]
    if ids != REQUIRED_SPECIES or len(set(ids)) != len(ids):
        raise RuntimeError("species list must match the canonical 30-species order")
    for entry in species:
        if entry.get("rig") not in VALID_RIGS:
            raise RuntimeError(f"{entry.get('id')} has an invalid rig family")
        if not entry.get("silhouette"):
            raise RuntimeError(f"{entry.get('id')} needs a silhouette contract")


def smoke_export(output_path: Path) -> tuple[int, int]:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=(0.0, 0.0, 1.0))
    body = bpy.context.active_object
    body.name = "PipelineProbeBody"
    for polygon in body.data.polygons:
        polygon.use_smooth = True

    material = bpy.data.materials.new("PipelineProbePBR")
    material.diffuse_color = (0.20, 0.32, 0.24, 1.0)
    material.use_nodes = True
    principled = material.node_tree.nodes.get("Principled BSDF")
    if principled is not None:
        principled.inputs["Base Color"].default_value = (0.20, 0.32, 0.24, 1.0)
        principled.inputs["Roughness"].default_value = 0.72
    body.data.materials.append(material)

    bpy.ops.object.armature_add(enter_editmode=True, location=(0.0, 0.0, 0.0))
    armature = bpy.context.active_object
    armature.name = "PipelineProbeRig"
    armature.data.name = "PipelineProbeArmature"
    root_bone = armature.data.edit_bones[0]
    root_bone.name = "Root"
    root_bone.head = (0.0, 0.0, 0.0)
    root_bone.tail = (0.0, 0.0, 1.0)
    spine = armature.data.edit_bones.new("Spine")
    spine.parent = root_bone
    spine.use_connect = True
    spine.head = root_bone.tail
    spine.tail = (0.0, 0.0, 2.0)
    bpy.ops.object.mode_set(mode="OBJECT")

    world_transform = body.matrix_world.copy()
    body.parent = armature
    body.matrix_world = world_transform
    modifier = body.modifiers.new("Armature", "ARMATURE")
    modifier.object = armature
    group = body.vertex_groups.new(name="Spine")
    group.add(range(len(body.data.vertices)), 1.0, "REPLACE")

    action = bpy.data.actions.new("idle")
    armature.animation_data_create()
    armature.animation_data.action = action
    pose_bone = armature.pose.bones["Spine"]
    pose_bone.rotation_mode = "XYZ"
    pose_bone.rotation_euler[2] = -0.035
    pose_bone.keyframe_insert(data_path="rotation_euler", frame=1)
    pose_bone.rotation_euler[2] = 0.035
    pose_bone.keyframe_insert(data_path="rotation_euler", frame=16)
    pose_bone.rotation_euler[2] = -0.035
    pose_bone.keyframe_insert(data_path="rotation_euler", frame=31)

    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
    output_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(output_path),
        export_format="GLB",
        use_selection=True,
        export_animations=True,
        export_skins=True,
        export_yup=True,
    )
    if not output_path.is_file() or output_path.stat().st_size < 1024:
        raise RuntimeError("official Blender glTF exporter did not produce a valid GLB")
    return len(body.data.polygons), len(armature.data.bones)


def main() -> None:
    args = parse_args()
    config_path = Path(args.config).resolve()
    output_path = Path(args.smoke_output).resolve()
    with config_path.open("r", encoding="utf-8") as handle:
        config = json.load(handle)
    validate_config(config)
    polygons, bones = smoke_export(output_path)
    print(
        "BLENDER_PIPELINE_OK: "
        f"Blender {bpy.app.version_string} / 30 species / 10 rigs / "
        f"probe {polygons} polygons, {bones} bones / {output_path}"
    )


if __name__ == "__main__":
    main()
