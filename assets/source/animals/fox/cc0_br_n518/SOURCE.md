# Red fox source audit

The checked-in `fox.blend`, `fox_diffuse.png`, and `fox_normal.png` are
unmodified files extracted from the OpenGameArt Fox source archive. Embedded
scripts are never executed: the audit and build commands use Blender's
`--disable-autoexec` option.

Source audit at import time:

- 107 base vertices and 171 base triangles before the authored Mirror
  modifier (342 rendered source triangles);
- one connected UV body mesh, 32 source bones and 21 deform groups;
- six source clips: idle, walk, run, bite, digging, and death;
- original 1024×1024 diffuse and tangent-space normal maps;
- the runtime build applies the source Mirror first, then Catmull-Clark level
  3 for Hero and level 2 for Mobile;
- output is retargeted to 22 runtime bones and eight project actions: idle,
  locomotion, sprint, attack, skill, hit, eat, and death.

Rebuild with `tools/build_realistic_vertical_slice.sh`. Re-audit an original
download before replacement with `tools/blender/audit_external_animal_source.py`.
