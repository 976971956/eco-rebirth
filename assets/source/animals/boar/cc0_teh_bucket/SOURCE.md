# Wild boar source audit

The checked-in `boar_0.blend` is the unmodified OpenGameArt CC0 source. Embedded
scripts are never executed; source audits use Blender's `--disable-autoexec`
option.

Source audit:

- one 313-vertex / 572-triangle mirrored mesh;
- one material, with the legacy texture path unavailable in Blender 5.2;
- 32 bones, 26 weighted groups and three animation actions;
- a recognizable low-poly boar silhouette, but insufficient facial, bristle,
  hoof and deformation detail for the current near-realistic runtime standard.

The production builder therefore retains the source as a traceable anatomical
and animation reference. `tools/blender/build_cinematic_boar.py` authors a new
continuous adult wild-boar surface with a high shoulder shield, sloping rump,
long snout, dorsal bristles, paired tusks, split hooves, 22 runtime bones, two
skill sockets and eight gameplay actions. Rebuild with
`tools/build_realistic_vertical_slice.sh`.
