# Crocodile source audit

The checked-in `crocodile.blend` and four texture maps are the unmodified CC0
files from OpenGameArt. Embedded scripts are never executed; source audits use
Blender's `--disable-autoexec` option.

Source audit:

- one 292-vertex / 263-polygon low-poly crocodile mesh;
- one 31-bone armature;
- four actions: idle loop, walk loop, attack and death;
- 1024-pixel diffuse, normal, height and specular maps;
- a recognizable low-poly silhouette, but insufficient jaw, foot, osteoderm
  and deformation detail for the current near-realistic runtime standard.

The production builder retains the source as a traceable proportion, scale and
motion reference. `tools/blender/build_cinematic_crocodile.py` authors a new
continuous low-slung body with a dorsoventrally flattened skull, articulated
upper/lower jaws and teeth, raised orbital tables, three osteoderm rows,
three-segment splayed limbs, separated toes, 22 runtime bones, two skill
sockets, eight base gameplay actions and a tail-driven swim action. Rebuild
with `tools/build_realistic_vertical_slice.sh`.
