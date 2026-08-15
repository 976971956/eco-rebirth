# Project map

## Runtime ownership

| Path | Responsibility |
|---|---|
| `scenes/main.tscn` | Main scene entry |
| `scripts/main.gd` | Game states, campaign/free mode, spawning, progression, saves, outcomes, tutorial orchestration |
| `scripts/species_catalog.gd` | All 30 species data, ecological habits, unlock pools, XP rewards, growth profiles, skills, traits, diets, preferred regions, victory guides |
| `scripts/eco_actor.gd` | Shared player/AI movement, combat, hunger, stamina, ecological habit recovery, experience, levels, animation, AI execution |
| `scripts/eco_world.gd` | Procedural four-region world, AI-painted terrain blending, biome prop kits, terrain access, food, day/night, weather, collapse, quality settings |
| `scripts/game_ui.gd` | Home, free-mode picker, HUD, live level leaderboard, rotating battle ticker/report, enemy health, touch controls, tutorial, settings, pause/result modals |
| `scripts/audio_manager.gd` | Procedural adaptive music, ambient sound, SFX pool, audio persistence |
| `scripts/low_poly_factory.gd` | Faceted procedural animal/environment meshes plus shared terrain and animated water shaders |
| `scripts/species_visual_catalog.gd` | V1 fallback and Blender V2 Hero/Mobile GLB registry, LOD and skeletal-species routing |
| `scripts/species_skeleton_rig.gd` | Rabbit/wolf/deer/bear `Skeleton3D`; imported Blender V2 lower-limb articulation, weighted body chains, sockets and species-tuned pose controller |
| `scripts/species_flight_rig.gd` | Eagle-only eight-bone `Skeleton3D`; glide/flap/dive/hit pose controller and beak/left-wing/right-wing skill sockets |
| `scripts/species_crocodile_rig.gd` | Crocodile-only weighted long-body `Skeleton3D`; land/swim/combat controller, jaw bone, three-bone tail chain, and jaw/tail-tip sockets |
| `scripts/skill_vfx.gd` and `scripts/skill_projectile.gd` | Skill presentation and projectiles |
| `tools/*.gd` | Deterministic validation, balance simulation, reports, and UI preview rendering |
| `tools/blender/*.py` and `tools/build_realistic_vertical_slice.sh` | Deterministic Blender pipeline checks and V2 animal/forest GLB generation |

## Current product contracts

- Ship 10 campaign levels with 10–100 ecological individuals and progressively larger species pools.
- Ship 30 playable species. Normal campaign chooses the player species from the generated roster and avoids immediate repeats.
- Give all 30 species one food-and-habitat ecological habit. Player and AI share the same trigger, one-source reward limit, recovery, and temporary buff rules.
- When survival pressure is high, guide the player to a nearby safe habit resource without revealing the full map. Prefer that resource for manual eating and never guide actors beyond the active collapse habitat.
- Reduce kill XP when a stronger or larger species repeatedly preys on much weaker animals; underdog kills retain the full target reward.
- Keep eating a shared risk: after food is consumed, player and AI spend one second chewing with reduced movement and no sprint, attack, or skill.
- Provide a home-page free mode that selects any level and any species. Insert the selected species into the roster when that level would not normally unlock it.
- Keep free mode at zero world threat. Free-mode victory/death must not change `campaign_level`, `last_completed_level`, `total_deaths`, `threat_level`, or `last_player_species`.
- Cap in-run level at 8. Every level improves health, current survivability, attack, speed, stamina, armor, and stamina regeneration according to the species growth profile.
- Show exact player and enemy health values, player combat statistics, experience, hunger, stamina, region, weather, level, and mode.
- Rank all living actors by level, current XP, kills, health ratio, then stable actor ID. Keep the player visible in the compact board.
- Rotate key battle events every four seconds and let click/touch open a paused, timestamped 60-entry battle report with the full living ranking.
- Show the chosen/random species stats, growth, passive, active skill, and victory guide on entry.
- Keep settings limited to audio, graphics, tutorial reset, and campaign reset. Free mode belongs on the home page.
- Keep the V1.42 all-species art path mobile/Web safe: all 30 species use versioned Hero/Mobile Blender GLBs and automatic body/detail ranges. The 26 ground species use 16-bone bodies with articulated lower limbs; owl/eagle use 10-bone two-stage wings; snake/crocodile use 8/12-bone long-body rigs. Every `OrganicBodyV2` must contain exactly one connected torso mesh island; silhouette attachments may be separate, while face, hoof and small marking meshes must remain independently distance-cullable. Every model keeps the eight core baked actions and family-specific sockets. The AI-authored deer V3 benchmark additionally owns species-specific anatomy and four-beat/gallop actions; new upgrades must follow that species-first process rather than changing all families through one generic pose patch. `EcoActor` must select and play imported `AnimationPlayer` actions; never apply standardized Godot Euler poses directly to Blender-converted rest axes, because that deforms flesh into bone-like chains. Manual pose controllers are fallback-only when an action is absent. AI and low-quality players always use Mobile, with the active 30-species Mobile total at or below 140,000 vertices (V1.42 baseline: 118,212). Missing V2 assets may fall back to V1. Collision, stats, AI and combat-event ownership remain in `EcoActor`; imported models rotate at the catalog root so visuals and sockets follow Godot -Z forward.
- Keep region navigation readable without creating blockers: forest/grassland/wetland/highland landmarks are visual-only, obstacle placement protects their clear radius, visible main trails and collision clearance share the same winding route points, and level 1/10 release validation must retain at least 97% largest-open-component coverage for a 0.85 m actor radius.

## Document routing

- Product loop and boundaries: `docs/00_GDD总览.md`
- Combat, hunger, corpses, death, threat: `docs/01_核心玩法与系统规则.md`
- Species and levels: `docs/02_物种与成长设计.md` and `docs/11_成长数值与物种攻略.md`
- Ecology AI: `docs/03_生态AI设计.md`
- World generation: `docs/04_地图与程序生成.md`
- Level details: `docs/05_十关详细设计.md`
- Godot architecture: `docs/06_Godot技术设计.md`
- Balance schema: `docs/08_数据字典与初始平衡.md`
- 30-species implementation history: `docs/09_关卡物种扩展设计.md` and `docs/10_三十种动物制作蓝图.md`
- AI art direction and runtime visual kit: `docs/12_AI美术重制方案.md`
- Ecological habits and resource routes: `docs/13_三十种生态习性设计.md`
- Gameplay loop audit and anti-snowball rules: `docs/14_玩法逻辑审计与优化.md`
- Running/exporting: `BUILDING.md`
- V2 realistic art, rig, biome and VFX production: `docs/17_写实美术与动画生产方案.md`

## Cross-platform UI rules

- Design against 1280×720 landscape and verify narrower mobile safe areas.
- Keep touch actions at least roughly 96 logical pixels and selectable controls at least 52 logical pixels tall.
- Keep the joystick summonable anywhere in the left lower half. Keep combat controls on the lower right.
- Move instructional/modal layers above touch controls and avoid relying on hover.
- Use the bundled Noto Sans SC font for Chinese text.
