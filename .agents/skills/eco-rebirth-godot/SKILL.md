---
name: eco-rebirth-godot
description: Maintain and extend the Eco Rebirth (《生态轮回》) Godot 4 game. Use whenever Codex works in this repository on GDScript, gameplay loops, the 30 species, 10 levels, ecology AI, procedural maps, combat, growth, touch UI, audio, saves, balancing, testing, Web/Android/iOS export, project documentation, or validated GitHub release commits.
---

# Eco Rebirth Godot

## Start every task

1. Locate the repository root containing `project.godot` and work from it.
2. Inspect `git status --short`; preserve unrelated user changes and never stage them.
3. Read [references/project-map.md](references/project-map.md) before changing code. Load only the linked GDD files relevant to the requested system.
4. Read [references/verification-and-release.md](references/verification-and-release.md) before validating, exporting, versioning, or committing.
5. Use `rg`/`rg --files` for discovery and `apply_patch` for manual file edits.

## Preserve game invariants

- Keep normal campaign and free mode separate. Campaign uses progression, random player species, deaths, and world threat. Free mode selects any of 10 levels and 30 species, uses zero threat, and must not mutate campaign progress or campaign species history.
- Keep the player and AI on the same `EcoActor` implementation and species data. Avoid player-only combat statistics unless the design explicitly requires them.
- Keep `SpeciesCatalog` as the current source of truth for species stats, unlocks, growth profiles, experience, skills, traits, diets, regions, and victory guides.
- Keep the game compatible with Godot 4.7.1 Compatibility rendering, 1280×720 landscape UI, dynamic mobile joystick, large touch targets, Web, Android, iOS, and desktop.
- Increment `SAVE_VERSION` and add migration/sanitization whenever persisted fields change. Preserve audio and video preferences when resetting campaign progress.
- Prefer existing procedural low-poly factories, effects, UI styles, fonts, and test tools. Add dependencies or large external assets only with explicit user approval.
- Update documentation and generated UI previews when player-visible behavior changes.

## Implement changes

1. Trace the existing state and signal flow before editing.
2. Make the smallest coherent change across data, runtime logic, UI, save migration, and validation.
3. Add or extend deterministic checks for new contracts. Extract a small testable helper when full scene setup would make validation fragile.
4. For player-visible releases, update `README.md`, `BUILDING.md`, the relevant GDD, `export_presets.cfg`, release validation text, and version numbers together.
5. Render important UI at 1280×720 and visually inspect it. Ensure mobile controls do not cover instructions or modal content.
6. Run the proportional validation set from the release reference. Do not report completion while parse errors, failed validators, broken exports, or material runtime errors remain.

## Commit automatically

After every successfully completed modification request:

1. Run `git diff --check` and review `git status --short` plus the staged scope.
2. Stage only files belonging to the completed request; exclude `build/`, `.godot/`, credentials, signing files, and unrelated user work.
3. Create one concise conventional commit describing the outcome.
4. Push the current branch to its configured GitHub remote; this repository normally uses `main` and `origin`.
5. Verify the branch and remote are synchronized, then report the commit hash.

Do not commit or push when the user explicitly opts out, required validation fails, credentials/approval are unavailable, or unrelated overlapping changes make a safe scoped commit impossible. Explain the blocker instead.

## Route detailed context

- Use [references/project-map.md](references/project-map.md) for code ownership, gameplay invariants, and GDD routing.
- Use [references/verification-and-release.md](references/verification-and-release.md) for checks, UI rendering, balance simulation, exports, versioning, and Git handoff.
