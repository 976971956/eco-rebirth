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

Rebuild the V1.40 snow-hare, grey-wolf and ancient-forest vertical slice with:

```bash
./tools/build_realistic_vertical_slice.sh
```

The generated GLBs live under `assets/models_v2/`. Godot prefers a validated
V2 species and falls back to the matching V1.39 asset if the V2 file is absent.

Rules:

- Run Blender with `--factory-startup`; do not depend on personal add-ons.
- Export glTF/GLB with +Y up conversion handled by the official exporter.
- Keep locomotion in-place. `EcoActor` owns world movement and hit timing.
- Hero and Mobile variants share bone, socket, action and root-scale names.
- Add new V2 assets beside V1.39 fallbacks until Godot visual and performance
  validation passes.
- Never put signing files, downloaded marketplace assets or unverified
  third-party content in the repository.
