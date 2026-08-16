from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description="Audit and preview an already-open Blender animal source")
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--name", required=True)
    parser.add_argument("--import-path", help="Import a generated glTF/GLB into an empty scene before auditing")
    return parser.parse_args(argv)


def import_generated_asset(import_path: str) -> None:
    source = Path(import_path).resolve()
    if not source.is_file():
        raise RuntimeError(f"generated asset does not exist: {source}")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))


def triangulated_count(mesh: bpy.types.Mesh) -> int:
    mesh.calc_loop_triangles()
    return len(mesh.loop_triangles)


def scene_bounds(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    points: list[Vector] = []
    for obj in objects:
        if obj.type != "MESH":
            continue
        points.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
    if not points:
        raise RuntimeError("source has no visible mesh bounds")
    minimum = Vector((min(point.x for point in points), min(point.y for point in points), min(point.z for point in points)))
    maximum = Vector((max(point.x for point in points), max(point.y for point in points), max(point.z for point in points)))
    return minimum, maximum


def audit() -> dict[str, object]:
    mesh_objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    return {
        "blender_version": bpy.app.version_string,
        "objects": [
            {
                "name": obj.name,
                "type": obj.type,
                "parent": obj.parent.name if obj.parent else "",
                "hidden_render": obj.hide_render,
            }
            for obj in bpy.context.scene.objects
        ],
        "meshes": [
            {
                "name": obj.name,
                "vertices": len(obj.data.vertices),
                "triangles": triangulated_count(obj.data),
                "materials": [slot.material.name if slot.material else "" for slot in obj.material_slots],
                "vertex_groups": len(obj.vertex_groups),
                "vertex_group_names": [group.name for group in obj.vertex_groups],
                "armature_modifiers": [modifier.object.name if modifier.object else "" for modifier in obj.modifiers if modifier.type == "ARMATURE"],
                "modifiers": [
                    {
                        "name": modifier.name,
                        "type": modifier.type,
                        "show_viewport": modifier.show_viewport,
                        "show_render": modifier.show_render,
                    }
                    for modifier in obj.modifiers
                ],
                "dimensions": [round(value, 5) for value in obj.dimensions],
                "location": [round(value, 5) for value in obj.location],
                "rotation_euler": [round(value, 5) for value in obj.rotation_euler],
                "scale": [round(value, 5) for value in obj.scale],
            }
            for obj in mesh_objects
        ],
        "armatures": [
            {
                "name": obj.name,
                "bones": len(obj.data.bones),
                "bone_names": [bone.name for bone in obj.data.bones],
                "bone_contract": [
                    {
                        "name": bone.name,
                        "parent": bone.parent.name if bone.parent else "",
                        "deform": bone.use_deform,
                        "head": [round(value, 5) for value in bone.head_local],
                        "tail": [round(value, 5) for value in bone.tail_local],
                        "constraints": [constraint.type for constraint in obj.pose.bones[bone.name].constraints],
                    }
                    for bone in obj.data.bones
                ],
                "location": [round(value, 5) for value in obj.location],
                "rotation_euler": [round(value, 5) for value in obj.rotation_euler],
                "scale": [round(value, 5) for value in obj.scale],
            }
            for obj in armatures
        ],
        "actions": [
            {
                "name": action.name,
                "frame_start": action.frame_range[0],
                "frame_end": action.frame_range[1],
                "slots": len(action.slots),
            }
            for action in bpy.data.actions
        ],
        "materials": [
            {
                "name": material.name,
                "use_nodes": material.use_nodes,
                "diffuse_color": [round(value, 5) for value in material.diffuse_color],
                "node_types": [node.bl_idname for node in material.node_tree.nodes]
                if material.use_nodes and material.node_tree
                else [],
            }
            for material in bpy.data.materials
        ],
        "images": [
            {
                "name": image.name,
                "size": list(image.size),
                "packed": image.packed_file is not None,
                "source": image.source,
                "filepath": image.filepath,
            }
            for image in bpy.data.images
        ],
    }


def add_preview_material_if_needed(mesh_objects: list[bpy.types.Object]) -> None:
    fallback = bpy.data.materials.new("AuditFallbackMaterial")
    fallback.diffuse_color = (0.42, 0.30, 0.18, 1.0)
    fallback.use_nodes = True
    principled = fallback.node_tree.nodes.get("Principled BSDF")
    if principled is not None:
        principled.inputs["Base Color"].default_value = (0.42, 0.30, 0.18, 1.0)
        principled.inputs["Roughness"].default_value = 0.82
    for obj in mesh_objects:
        if not obj.material_slots:
            obj.data.materials.append(fallback)


def extract_packed_images(output_dir: Path, asset_name: str) -> list[str]:
    extracted: list[str] = []
    for image in bpy.data.images:
        if image.source != "FILE" or image.size[0] <= 0 or image.size[1] <= 0:
            continue
        safe_name = "".join(character if character.isalnum() or character in "-_" else "_" for character in image.name)
        output_path = output_dir / f"{asset_name}-texture-{safe_name}.png"
        original_path = image.filepath_raw
        original_format = image.file_format
        image.filepath_raw = str(output_path)
        image.file_format = "PNG"
        image.save()
        image.filepath_raw = original_path
        image.file_format = original_format
        extracted.append(str(output_path))
    return extracted


def render_previews(output_dir: Path, asset_name: str) -> list[str]:
    scene = bpy.context.scene
    mesh_objects = [obj for obj in scene.objects if obj.type == "MESH" and not obj.hide_render]
    minimum, maximum = scene_bounds(mesh_objects)
    center = (minimum + maximum) * 0.5
    extent = maximum - minimum
    radius = max(extent.length * 0.58, 1.0)
    add_preview_material_if_needed(mesh_objects)

    for obj in list(scene.objects):
        if obj.type in {"CAMERA", "LIGHT"}:
            bpy.data.objects.remove(obj, do_unlink=True)

    world = bpy.data.worlds.new("AuditWorld") if scene.world is None else scene.world
    scene.world = world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    if background is not None:
        background.inputs["Color"].default_value = (0.045, 0.055, 0.070, 1.0)
        background.inputs["Strength"].default_value = 0.55

    bpy.ops.object.light_add(type="AREA", location=center + Vector((radius * 1.8, -radius * 1.6, radius * 2.1)))
    key = bpy.context.object
    key.name = "AuditKey"
    key.data.energy = 1100.0
    key.data.shape = "DISK"
    key.data.size = radius * 2.0
    key.rotation_euler = (center - key.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.light_add(type="AREA", location=center + Vector((-radius * 1.5, radius * 1.1, radius * 1.0)))
    fill = bpy.context.object
    fill.name = "AuditFill"
    fill.data.energy = 650.0
    fill.data.size = radius * 1.7
    fill.rotation_euler = (center - fill.location).to_track_quat("-Z", "Y").to_euler()

    bpy.ops.object.camera_add()
    camera = bpy.context.object
    camera.name = "AuditCamera"
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = max(extent.z * 1.35, max(extent.x, extent.y) * 1.10, 1.0)
    scene.camera = camera
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 640
    scene.render.resolution_y = 640
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False

    preview_paths: list[str] = []
    for index, angle_degrees in enumerate((35.0, 125.0, 215.0, 305.0), start=1):
        angle = math.radians(angle_degrees)
        horizontal = radius * 2.7
        camera.location = center + Vector((math.cos(angle) * horizontal, math.sin(angle) * horizontal, radius * 1.15))
        camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
        output_path = output_dir / f"{asset_name}-view-{index}.png"
        scene.render.filepath = str(output_path)
        bpy.ops.render.render(write_still=True)
        preview_paths.append(str(output_path))
    return preview_paths


def main() -> None:
    args = parse_args()
    if args.import_path:
        import_generated_asset(args.import_path)
    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    report = audit()
    report["extracted_images"] = extract_packed_images(output_dir, args.name)
    report["previews"] = render_previews(output_dir, args.name)
    report_path = output_dir / f"{args.name}-audit.json"
    report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(
        "EXTERNAL_ANIMAL_AUDIT_OK: "
        f"{sum(int(mesh['vertices']) for mesh in report['meshes'])} vertices / "
        f"{sum(int(mesh['triangles']) for mesh in report['meshes'])} triangles / "
        f"{sum(int(armature['bones']) for armature in report['armatures'])} bones / "
        f"{len(report['actions'])} actions / {report_path}"
    )


if __name__ == "__main__":
    main()
