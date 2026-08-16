# Brown bear source audit

The checked-in `bear.blend` and `bear_palette.png` are the unmodified files
from the OpenGameArt CC0 archive. Embedded scripts are never executed; source
audits use Blender's `--disable-autoexec` option.

Source audit:

- one 360-vertex / 672-triangle mesh;
- no armature and no animation actions;
- one 16×16 palette texture;
- upright toy proportions unsuitable for direct gameplay use.

The production builder therefore uses the CC0 source only as a traceable shape
and palette reference. `tools/blender/build_cinematic_bear.py` creates a new
four-footed adult brown bear with a high shoulder mass, thick neck, short deep
muzzle, rounded ears, broad plantigrade paws, subtle fur relief, 22 runtime
bones, two skill sockets, and eight gameplay actions. Rebuild with
`tools/build_realistic_vertical_slice.sh`.
