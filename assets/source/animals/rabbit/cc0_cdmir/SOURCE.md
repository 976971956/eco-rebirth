# Rabbit source audit

The checked-in `rabbit.blend` is the unmodified download from the OpenGameArt
Rabbit asset page. It is never executed with embedded scripts: the audit and
build commands use Blender's `--disable-autoexec` option.

Source audit at import time:

- 2,200 source vertices and 2,642 source triangles across the rabbit and fur
  meshes (the source ground plane is excluded);
- 37 source bones, reduced to 22 runtime bones after IK/control cleanup;
- 10 source actions were present, but the game exports eight newly authored
  clips with stable project names;
- packed 1024×1024 body/facial albedo, fur-card albedo, and normal textures,
  exported at 512 for Hero and 256 for Mobile;
- both animal meshes contain authored UVs and weights for the same armature.

Rebuild with `tools/build_realistic_vertical_slice.sh`. Re-audit an original
download before replacement with `tools/blender/audit_external_animal_source.py`.
