# Verification and release

## Baseline checks

Use unique `/tmp` log paths because the sandbox may not write Godot's normal user log directory.

```bash
godot --headless --log-file /tmp/eco-parse.log --path . --editor --quit
godot --headless --log-file /tmp/eco-species.log --path . --script res://tools/validate_species.gd
godot --headless --log-file /tmp/eco-release.log --path . --script res://tools/validate_release.gd
godot --headless --log-file /tmp/eco-runtime.log --path . --quit-after 1200 -- --autoplay
```

Treat a Godot parse/script error or nonzero exit as a failure. macOS certificate-store and sandboxed editor-settings warnings may be environmental only when the command exits zero and the requested validator reports success.

## Proportional checks

- Species/stats/skills/growth: run `validate_species.gd` and `report_growth_balance.gd`.
- Save/menu/settings/tutorial/audio/release behavior: run `validate_release.gd`.
- AI, hunger, combat, map, or balance: also run batch simulations for level 1 and level 10. Inspect winners, timeouts, duration, combat deaths, and hunger deaths.
- UI changes: update `tools/render_release_ui.gd`, render all affected states, and inspect the PNGs with an image viewer.
- Web-relevant changes: export Web and verify `build/web/index.html`, `.js`, `.wasm`, and `.pck` exist.

UI rendering requires the graphical macOS driver:

```bash
godot --display-driver macos --rendering-driver opengl3 --log-file /tmp/eco-ui.log --path . --script res://tools/render_release_ui.gd
```

Web export:

```bash
godot --headless --log-file /tmp/eco-web.log --path . --export-release Web build/web/index.html
```

Android/iOS changes require their installed SDK/templates. Do not claim device validation when only script parsing or Web export was performed. Never commit signing credentials, keystores, provisioning profiles, or developer passwords.

## Versioning and documentation

- Use `V1.x` for current player-visible releases.
- Keep Android `version/name`, iOS `application/short_version`, README, and BUILDING version text aligned.
- Increase Android `version/code` and iOS `application/version` monotonically, currently in increments of 10.
- Bump `SAVE_VERSION` only for persisted schema changes and add a migration test.
- Keep screenshots under `docs/images/`; include generated `.import` metadata after Godot imports new images.
- Keep `README.md` focused on the playable release and link detailed design instead of duplicating it.

## Automatic Git handoff

Before committing:

```bash
git diff --check
git status --short
git diff --stat
```

Stage an explicit path list when possible. Review `git diff --cached --check` and `git diff --cached --stat`, then commit and push. Verify synchronization with:

```bash
git rev-list --left-right --count origin/main...main
```

Expected synchronized output is `0 0`.
