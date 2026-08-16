# Forest deer source audit

The checked-in `doe.blend` is the unmodified download from the OpenGameArt
Deer Female page. Embedded scripts are never executed: audit and build commands
use Blender's `--disable-autoexec` option.

Source audit at import time:

- 2,441 animal vertices and 4,784 animal triangles across connected body,
  head, and eye meshes (the four-vertex source ground plane is excluded);
- 31 source bones, including IK/control bones, reduced to 22 runtime bones;
- 11 source actions and two packed 1024×1024 photographic fur textures;
- authored UVs and weights shared by the same source armature;
- output uses eight project clips: idle, locomotion, sprint, attack, skill,
  hit, eat, and death.

Rebuild with `tools/build_realistic_vertical_slice.sh`. Re-audit an original
download before replacement with `tools/blender/audit_external_animal_source.py`.
