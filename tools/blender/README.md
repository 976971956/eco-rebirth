# Blender art pipeline

The V2 art pipeline uses Blender for source geometry, UV/PBR preparation,
armatures, baked animation and glTF export. Godot remains authoritative for
collision, movement, combat, AI and gameplay state.

Run the environment and schema smoke test from the repository root:

```bash
./tools/check_blender_pipeline.sh
```

The check starts Blender in background mode, validates
`pipeline_config.json`, creates a temporary skinned-pipeline probe scene and
exports a GLB to `/tmp`. It does not overwrite game assets.

Rebuild the V1.41 thirty-species Hero/Mobile set and the ancient-forest
vertical slice with:

```bash
./tools/build_realistic_vertical_slice.sh
```

The command first builds the procedural rabbit, then the licensed CC0 gray-wolf
cinematic sample, the other 28 species by skeleton family, and finally the two
forest trees. The generated GLBs live under `assets/models_v2/`. The wolf source
and provenance notice live under `assets/source/animals/wolf/cc0_newdlc/`, which
Godot ignores at import time. Godot prefers V2 and falls back to the matching
V1.39 asset if a V2 file is absent.

Animal export is fail-fast: each `OrganicBodyV2` must be one connected source
mesh island, every skinned mesh is explicitly parented to its armature, and
Blender Python exceptions return a non-zero shell status. The wolf records its
validated source island count because glTF must split UV/tangent seams into
render vertices. This prevents detached feet, ears and tails from being shipped
as a flesh model without rejecting a correctly UV-mapped asset.

Rules:

- Run Blender with `--factory-startup`; do not depend on personal add-ons.
- Export glTF/GLB with +Y up conversion handled by the official exporter.
- Keep locomotion in-place. `EcoActor` owns world movement and hit timing.
- Hero and Mobile variants share bone, socket, action and root-scale names.
- Keep new V2 assets beside V1.39 fallbacks and run the visual, animation,
  socket, navigation and performance validation before release.
- Never put signing files, downloaded marketplace assets or unverified
  third-party content in the repository. Third-party source must have a checked
  commercial-use license and an adjacent provenance notice.
