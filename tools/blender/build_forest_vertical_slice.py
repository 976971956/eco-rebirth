from __future__ import annotations

import argparse
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description="Build the ancient-forest vertical-slice kit")
    parser.add_argument("--output-root", required=True)
    return parser.parse_args(argv)


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials):
        for datablock in list(datablocks):
            datablocks.remove(datablock)


def material(name: str, color: tuple[float, float, float, float], roughness: float) -> bpy.types.Material:
    result = bpy.data.materials.new(name)
    result.diffuse_color = color
    result.use_nodes = True
    principled = result.node_tree.nodes.get("Principled BSDF")
    if principled is not None:
        principled.inputs["Base Color"].default_value = color
        principled.inputs["Roughness"].default_value = roughness
    return result


def cylinder_between(name: str, start: Vector, end: Vector, radius_a: float, radius_b: float, mat: bpy.types.Material, vertices: int = 10) -> bpy.types.Object:
    midpoint = (start + end) * 0.5
    direction = end - start
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices,
        radius1=radius_a,
        radius2=radius_b,
        depth=direction.length,
        location=midpoint,
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0.0, 0.0, 1.0)).rotation_difference(direction.normalized())
    obj.data.materials.append(mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def join_objects(objects: list[bpy.types.Object], name: str) -> bpy.types.Object:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    result = bpy.context.active_object
    result.name = name
    return result


def leaf_cluster(name: str, location: Vector, scale: tuple[float, float, float], mat: bpy.types.Material, hero: bool) -> bpy.types.Object:
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2 if hero else 1, radius=1.0, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def build_tree(variant: int, output_root: Path) -> None:
    reset_scene()
    rng = random.Random(20260815 + variant * 103)
    bark = material("ancient_bark_pbr", (0.16, 0.105, 0.065, 1.0), 0.93)
    leaves = material("forest_leaf_pbr", (0.12 + variant * 0.012, 0.255, 0.105, 1.0), 0.88)
    moss = material("tree_moss_pbr", (0.18, 0.33, 0.105, 1.0), 0.96)

    trunk_parts = [cylinder_between("AncientTrunk", Vector((0.0, 0.0, 0.0)), Vector((0.0, 0.08, 5.4)), 0.72, 0.34, bark, 14)]
    for root_index in range(6):
        angle = math.tau * root_index / 6.0 + rng.uniform(-0.18, 0.18)
        end = Vector((math.cos(angle) * rng.uniform(1.20, 1.58), math.sin(angle) * rng.uniform(1.20, 1.58), 0.04))
        trunk_parts.append(cylinder_between("RootFlare", Vector((0.0, 0.0, 0.38)), end, 0.25, 0.055, bark, 9))

    branch_ends: list[Vector] = []
    for branch_index in range(7):
        angle = math.tau * branch_index / 7.0 + rng.uniform(-0.32, 0.32)
        start = Vector((0.0, 0.0, 2.75 + branch_index * 0.28))
        length = rng.uniform(1.45, 2.25)
        end = Vector((math.cos(angle) * length, math.sin(angle) * length, start.z + rng.uniform(0.72, 1.28)))
        trunk_parts.append(cylinder_between("CrownBranch", start, end, 0.18, 0.055, bark, 9))
        branch_ends.append(end)
    trunk = join_objects(trunk_parts, "AncientTreeTrunkV2")

    leaf_parts: list[bpy.types.Object] = []
    for index, end in enumerate(branch_ends):
        for cluster_index in range(2):
            offset = Vector((
                rng.uniform(-0.50, 0.50),
                rng.uniform(-0.50, 0.50),
                rng.uniform(-0.10, 0.72),
            ))
            scale = (rng.uniform(0.88, 1.24), rng.uniform(0.72, 1.10), rng.uniform(0.72, 1.04))
            leaf_parts.append(leaf_cluster(f"LeafCluster_{index}_{cluster_index}", end + offset, scale, leaves, True))
    leaf_parts.append(leaf_cluster("CrownHeart", Vector((0.0, 0.0, 5.72)), (1.38, 1.24, 1.16), leaves, True))
    foliage = join_objects(leaf_parts, "AncientTreeCanopyV2")

    moss_parts: list[bpy.types.Object] = []
    for moss_index in range(5):
        angle = math.tau * moss_index / 5.0 + rng.uniform(-0.25, 0.25)
        moss_parts.append(leaf_cluster(
            f"BarkMoss_{moss_index}",
            Vector((math.cos(angle) * 0.64, math.sin(angle) * 0.64, 0.34 + moss_index * 0.18)),
            (0.32, 0.16, 0.12), moss, False,
        ))
    join_objects(moss_parts, "AncientTreeMossV2")

    output = output_root / f"ancient_tree_{variant}.glb"
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = trunk
    bpy.ops.export_scene.gltf(
        filepath=str(output), export_format="GLB", use_selection=True,
        export_animations=False, export_yup=True, export_apply=True,
    )
    triangles = 0
    for obj in (trunk, foliage):
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
    if not output.is_file() or output.stat().st_size < 4096:
        raise RuntimeError(f"failed to export {output}")
    print(f"FOREST_VERTICAL_SLICE_OK: tree {variant} / {triangles} main triangles / {output}")


def main() -> None:
    args = parse_args()
    output_root = Path(args.output_root).resolve()
    for variant in (1, 2):
        build_tree(variant, output_root)


if __name__ == "__main__":
    main()
