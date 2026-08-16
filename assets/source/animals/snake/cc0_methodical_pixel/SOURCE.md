# Blue-ring snake source audit

The checked-in `snake.blend` and `snake.png` are the unmodified Blender and
texture files extracted from the OpenGameArt download. Embedded scripts are
never executed: audit and build commands use Blender's `--disable-autoexec`.

Source audit at import time:

- one connected 105-vertex / 206-triangle snake mesh;
- 18 source bones spanning the complete axial body;
- three source actions: idle, walk, and a one-frame reference pose;
- one authored 256×256 RGBA UV texture;
- source skinning contains 17 deform vertex groups.

The production builder retains the connected body and UVs, smooths the final
topology, replaces the control rig with the ten-bone Godot long-body contract,
and bakes the common eight-state gameplay animation set. Rebuild with
`tools/build_realistic_vertical_slice.sh`.
