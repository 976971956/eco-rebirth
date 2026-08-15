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

The command first builds rabbit/wolf, then the other 28 species by skeleton
family, and finally the two forest trees. The generated GLBs live under
`assets/models_v2/`. Godot prefers V2 and falls back to the matching V1.39
asset if a V2 file is absent.

Rules:

- Run Blender with `--factory-startup`; do not depend on personal add-ons.
- Export glTF/GLB with +Y up conversion handled by the official exporter.
- Keep locomotion in-place. `EcoActor` owns world movement and hit timing.
- Hero and Mobile variants share bone, socket, action and root-scale names.
- Keep new V2 assets beside V1.39 fallbacks and run the visual, animation,
  socket, navigation and performance validation before release.
- Never put signing files, downloaded marketplace assets or unverified
  third-party content in the repository.
