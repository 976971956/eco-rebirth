extends Node

const Catalog = preload("res://scripts/species_catalog.gd")
const WorldScript = preload("res://scripts/eco_world.gd")
const ActorScript = preload("res://scripts/eco_actor.gd")
const CorpseScript = preload("res://scripts/corpse.gd")
const CameraScript = preload("res://scripts/camera_rig.gd")
const UIScript = preload("res://scripts/game_ui.gd")
const AudioScript = preload("res://scripts/audio_manager.gd")

const CONFIG_PATH := "user://eco_rebirth.cfg"
const SAVE_VERSION := 4
const RELEASE_VERSION := "1.38.0"
const RUN_HISTORY_LIMIT := 10
const QUALITY_PRESETS: Array[String] = ["low", "medium", "high"]
const TUTORIAL_STEPS := [
	{"id": "move", "title": "先熟悉移动", "desktop": "使用 WASD 或方向键移动，观察脚步和面朝方向。", "touch": "在左下区域按住并拖动摇杆，朝任意方向移动。"},
	{"id": "sprint", "title": "学会控制耐力", "desktop": "移动时按住 Shift 冲刺。冲刺、攻击和技能都会消耗耐力。", "touch": "移动时按住右侧“冲刺”。冲刺、攻击和技能都会消耗耐力。"},
	{"id": "attack", "title": "自动接敌", "desktop": "靠近其他动物并按住 J 或鼠标左键，进入距离后会自动攻击。", "touch": "靠近其他动物并按住右侧“攻击”，进入距离后会自动攻击。"},
	{"id": "skill", "title": "释放物种技能", "desktop": "按空格释放本物种的专属技能。技能效果会随物种改变。", "touch": "点击右侧绿色技能按钮。每种动物都有不同的专属能力。"},
	{"id": "eat", "title": "寻找食物", "desktop": "靠近尸体或可食用资源后按 E 进食。饱腹归零会持续损失生命。", "touch": "靠近尸体或可食用资源后点击“进食”。饱腹归零会持续损失生命。"},
]

var game_root: Node3D
var actor_root: Node3D
var corpse_root: Node3D
var world: EcoWorld
var camera_rig: EcoCameraRig
var ui: GameUI
var audio: EcoAudioManager
var actors: Array[EcoActor] = []
var corpses: Array[Node3D] = []
var player: EcoActor
var rng := RandomNumberGenerator.new()

const LEVEL_CONFIG := [
	{"individuals": 10, "world_size": 140.0, "species_range": Vector2i(4, 5), "establishment": 180.0, "forced_collapse": 300.0, "convergence_ratio": 0.30},
	{"individuals": 20, "world_size": 190.0, "species_range": Vector2i(6, 8), "establishment": 250.0, "forced_collapse": 420.0, "convergence_ratio": 0.28},
	{"individuals": 30, "world_size": 240.0, "species_range": Vector2i(8, 11), "establishment": 320.0, "forced_collapse": 540.0, "convergence_ratio": 0.27},
	{"individuals": 40, "world_size": 280.0, "species_range": Vector2i(10, 13), "establishment": 360.0, "forced_collapse": 600.0, "convergence_ratio": 0.25},
	{"individuals": 50, "world_size": 320.0, "species_range": Vector2i(12, 15), "establishment": 430.0, "forced_collapse": 720.0, "convergence_ratio": 0.24},
	{"individuals": 60, "world_size": 350.0, "species_range": Vector2i(14, 18), "establishment": 500.0, "forced_collapse": 840.0, "convergence_ratio": 0.23},
	{"individuals": 70, "world_size": 380.0, "species_range": Vector2i(16, 20), "establishment": 540.0, "forced_collapse": 900.0, "convergence_ratio": 0.22},
	{"individuals": 80, "world_size": 410.0, "species_range": Vector2i(18, 22), "establishment": 610.0, "forced_collapse": 1020.0, "convergence_ratio": 0.21},
	{"individuals": 90, "world_size": 440.0, "species_range": Vector2i(20, 25), "establishment": 650.0, "forced_collapse": 1080.0, "convergence_ratio": 0.20},
	{"individuals": 100, "world_size": 470.0, "species_range": Vector2i(22, 26), "establishment": 720.0, "forced_collapse": 1200.0, "convergence_ratio": 0.20},
]

var world_seed: int = 0
var threat_level: int = 0
var total_deaths: int = 0
var current_level: int = 1
var campaign_level: int = 1
var last_completed_level: int = 0
var roster_size: int = 10
var batch_mode: bool = false
var batch_level: int = 1
var batch_runs_remaining: int = 0
var batch_total_runs: int = 0
var level_elapsed: float = 0.0
var collapse_triggered: bool = false
var ecology_events_started: int = 0
var player_hotspots_visited: int = 0
var visited_ecology_events: Dictionary = {}
var ecology_activity_timer: float = 0.0
var ecology_hotspot_snapshot: Dictionary = {}
var ecology_hunter_peak: int = 0
var reported_hotspot_hunter_sequence: int = -1
var reported_hotspot_danger_sequence: int = -1
var ecology_trace_investigations: int = 0
var danger_memory_avoidances: int = 0
var ecology_trace_report_cooldown: float = 0.0
var danger_memory_report_cooldown: float = 0.0
var batch_deaths: Array = []
var batch_results: Array = []
var batch_log_file: FileAccess
var batch_death_log_file: FileAccess
var report_directory: String = ""
var benchmark_mode: bool = false
var benchmark_level: int = 1
var benchmark_duration: float = 20.0
var benchmark_quality: String = "medium"
var benchmark_species: String = "rabbit"
var benchmark_started_usec: int = 0
var benchmark_finished: bool = false
var benchmark_frames: int = 0
var benchmark_process_seconds: float = 0.0
var benchmark_physics_seconds: float = 0.0
var benchmark_max_frame_ms: float = 0.0
var benchmark_max_process_ms: float = 0.0
var benchmark_max_physics_ms: float = 0.0
var benchmark_max_nodes: int = 0
var benchmark_max_objects: int = 0
var benchmark_max_draw_calls: int = 0
var benchmark_max_primitives: int = 0
var benchmark_max_static_memory: int = 0
var state: String = "menu"
var last_player_species: String = ""
var world_started_msec: int = 0
var _skill_request_latched: bool = false
var _interact_request_latched: bool = false
var tutorial_completed: bool = false
var tutorial_active: bool = false
var tutorial_step: int = -1
var tutorial_world_seed: int = 0
var tutorial_advance_frame: int = -1
var quality_preset: String = "medium"
var selected_free_level: int = 1
var selected_free_species: String = "rabbit"
var run_uses_free_mode: bool = false
var discovered_species: Array[String] = []
var species_records: Dictionary = {}
var recent_runs: Array[Dictionary] = []
var new_discoveries_current_run: Array[String] = []
var leaderboard_refresh_remaining: float = 0.0
var orientation_blocked: bool = false
var world_seed_override: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("mobile") and DisplayServer.has_feature(DisplayServer.FEATURE_ORIENTATION):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	_ensure_input_map()
	_load_progress()
	audio = AudioScript.new()
	audio.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(audio)
	audio.setup()
	ui = UIScript.new()
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	ui.setup(self)
	ui.start_requested.connect(_on_start_requested)
	ui.free_mode_requested.connect(_on_free_mode_requested)
	ui.retry_requested.connect(_on_retry_requested)
	ui.menu_requested.connect(_on_menu_requested)
	ui.pause_requested.connect(_toggle_pause)
	ui.tutorial_skipped.connect(_skip_tutorial)
	ui.battle_report_opened.connect(_on_battle_report_opened)
	ui.battle_report_closed.connect(_on_battle_report_closed)
	ui.orientation_blocked_changed.connect(_on_orientation_blocked_changed)
	audio.set_context("menu")
	var batch_arg := _find_cmdline_value("--batch-sim")
	var benchmark_arg := _find_cmdline_value("--benchmark-level")
	var seed_arg := _find_cmdline_value("--world-seed")
	report_directory = _find_cmdline_value("--report-dir").strip_edges()
	if seed_arg != "":
		world_seed_override = int(seed_arg)
	if benchmark_arg != "":
		benchmark_mode = true
		benchmark_level = clampi(int(benchmark_arg), 1, LEVEL_CONFIG.size())
		benchmark_duration = clampf(float(_find_cmdline_value("--benchmark-duration")) if _find_cmdline_value("--benchmark-duration") != "" else 20.0, 5.0, 120.0)
		var requested_quality := _find_cmdline_value("--benchmark-quality")
		benchmark_quality = requested_quality if requested_quality in QUALITY_PRESETS else "medium"
		var requested_species := _find_cmdline_value("--benchmark-species")
		benchmark_species = requested_species if requested_species in Catalog.ORDER else "rabbit"
		tutorial_completed = true
		Engine.max_fps = 60
		_start_benchmark.call_deferred()
	elif batch_arg != "":
		batch_total_runs = maxi(int(batch_arg), 1)
		batch_runs_remaining = batch_total_runs
		var level_arg := _find_cmdline_value("--batch-level")
		batch_level = clampi(int(level_arg) if level_arg != "" else 1, 1, LEVEL_CONFIG.size())
		batch_mode = true
		Engine.time_scale = 8.0
		batch_log_file = _open_report_file(batch_results_filename(batch_level))
		if batch_log_file != null:
			batch_log_file.store_line("run,level,world_seed,winner,duration_s,death_count,deaths_30s,deaths_60s,first_death_s,event_count,hunter_peak,trace_hunts,danger_avoids,stuck_recoveries,route_replans,food_bites,habit_activations,distance_m,starvation_deaths,outcome")
		batch_death_log_file = _open_report_file(batch_deaths_filename(batch_level))
		if batch_death_log_file != null:
			batch_death_log_file.store_line("run,time_s,victim,killer,food_bites,habit_activations,stuck_recoveries,route_replans,distance_m")
		_start_batch_run.call_deferred()
	elif "--autoplay" in OS.get_cmdline_user_args():
		_start_new_world.call_deferred()


func _process(delta: float) -> void:
	if state == "playing" and not orientation_blocked:
		level_elapsed += delta
		ecology_trace_report_cooldown = maxf(ecology_trace_report_cooldown - delta, 0.0)
		danger_memory_report_cooldown = maxf(danger_memory_report_cooldown - delta, 0.0)
		if not collapse_triggered:
			_check_collapse_trigger()
		_refresh_ecology_hotspot_activity(delta)
	if batch_mode and state == "playing":
		var living := get_living_actors()
		if living.size() <= 1 or level_elapsed > 2100.0:
			_finish_batch_run(living)
			return
	if state == "playing" and not orientation_blocked and is_instance_valid(player):
		if is_instance_valid(world):
			world.update_weather_focus(player.global_position)
		var living_count := get_living_actors().size()
		var domain_suffix: String = "" if player.movement_domain_label() == "地面" else "\n移动层：%s" % player.movement_domain_label()
		var adaptation_suffix := " · %s" % player.environment_region_status_text() if player.has_method("environment_region_status_text") else ""
		var region_name := "%s · %s%s%s" % [world.region_name_at(player.global_position), world.condition_summary(), domain_suffix, adaptation_suffix] if is_instance_valid(world) else "未知区域"
		var ecology_status := world.ecology_event_status(player.global_position) if is_instance_valid(world) else ""
		var ecology_activity := ecology_hotspot_activity_status()
		var habit_guidance := player.habit_resource_guidance_text()
		var trace_status := habit_guidance if habit_guidance != "" else ecology_trace_status()
		ui.update_hud(player, living_count, roster_size, region_name, ecology_status, ecology_activity, trace_status)
		_update_player_ecology_hotspot()
		leaderboard_refresh_remaining -= delta
		if leaderboard_refresh_remaining <= 0.0:
			leaderboard_refresh_remaining = 0.45
			ui.update_leaderboard(_build_level_leaderboard())
		if audio != null and audio.has_method("set_game_intensity"):
			var survival_pressure := 1.0 - float(living_count - 1) / maxf(float(roster_size - 1), 1.0)
			var health_pressure := 1.0 - clampf(player.health / maxf(player.max_health, 1.0), 0.0, 1.0)
			audio.set_game_intensity(clampf(survival_pressure * 0.72 + health_pressure * 0.28, 0.0, 1.0))
	if not orientation_blocked and Input.is_action_just_pressed("pause"):
		if state == "battle_report":
			ui.hide_battle_report()
		elif state == "playing" or state == "paused":
			_toggle_pause()
	corpses = corpses.filter(func(item): return is_instance_valid(item) and not item.is_queued_for_deletion())
	if benchmark_mode:
		_tick_benchmark(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and state == "playing":
		_toggle_pause.call_deferred()


func _on_start_requested() -> void:
	_queue_world_start(false)


func _on_free_mode_requested(level: int, species_id: String) -> void:
	selected_free_level = clampi(level, 1, LEVEL_CONFIG.size())
	selected_free_species = species_id if Catalog.ORDER.has(species_id) else "rabbit"
	_save_progress()
	_queue_world_start(true)


func _on_retry_requested() -> void:
	if state == "paused":
		get_tree().paused = false
		state = "playing"
		ui.modal_root.hide()
		if audio != null:
			audio.set_context("game")
		return
	get_tree().paused = false
	_queue_world_start(run_uses_free_mode)


func _on_menu_requested() -> void:
	get_tree().paused = false
	if state == "loading":
		return
	state = "loading"
	_return_to_menu.call_deferred()


func _return_to_menu() -> void:
	state = "menu"
	tutorial_active = false
	_clear_game_root()
	run_uses_free_mode = false
	current_level = campaign_level
	ui.show_menu()
	if audio != null:
		audio.set_context("menu")


func _queue_world_start(free_mode: bool) -> void:
	# UI buttons are driven by browser/native input callbacks. Destroying and
	# rebuilding the complete 3D world inside that callback can leave WebAssembly
	# dispatching into objects that have already been freed. Defer the transition
	# and reject double taps while the new world is being assembled.
	if state == "loading":
		return
	state = "loading"
	_start_new_world.call_deferred(free_mode)


func _on_battle_report_opened() -> void:
	if state != "playing":
		return
	state = "battle_report"
	get_tree().paused = true
	if audio != null:
		audio.set_context("pause")


func _on_battle_report_closed() -> void:
	if state != "battle_report":
		return
	get_tree().paused = false
	state = "playing"
	if audio != null:
		audio.set_context("game")


func _on_orientation_blocked_changed(blocked: bool) -> void:
	orientation_blocked = blocked
	if state == "playing":
		get_tree().paused = blocked


func _start_new_world(free_mode: bool = false) -> void:
	get_tree().paused = false
	_clear_game_root()
	if not batch_mode:
		run_uses_free_mode = free_mode
		current_level = selected_free_level if run_uses_free_mode else campaign_level
	state = "loading"
	level_elapsed = 0.0
	leaderboard_refresh_remaining = 0.0
	collapse_triggered = false
	ecology_events_started = 0
	player_hotspots_visited = 0
	visited_ecology_events.clear()
	ecology_activity_timer = 0.0
	ecology_hotspot_snapshot.clear()
	ecology_hunter_peak = 0
	reported_hotspot_hunter_sequence = -1
	reported_hotspot_danger_sequence = -1
	ecology_trace_investigations = 0
	danger_memory_avoidances = 0
	ecology_trace_report_cooldown = 0.0
	danger_memory_report_cooldown = 0.0
	new_discoveries_current_run.clear()
	var batch_run_offset := batch_total_runs - batch_runs_remaining if batch_mode else 0
	world_seed = world_seed_override + batch_run_offset if world_seed_override >= 0 else int(Time.get_unix_time_from_system() * 1000.0) ^ int(Time.get_ticks_msec()) ^ (total_deaths * 7919) ^ randi()
	rng.seed = world_seed

	var level_config: Dictionary = LEVEL_CONFIG[current_level - 1]
	var individual_count: int = level_config["individuals"]
	var world_size_value: float = level_config["world_size"]
	var species_range: Vector2i = level_config["species_range"]

	game_root = Node3D.new()
	game_root.name = "GameWorld"
	add_child(game_root)
	world = WorldScript.new()
	game_root.add_child(world)
	world.setup(world_seed, world_size_value, current_level, not batch_mode, "", "", quality_preset)
	world.ecology_event_started.connect(_on_ecology_event_started)
	world.ecology_event_ended.connect(_on_ecology_event_ended)
	actor_root = Node3D.new()
	actor_root.name = "Actors"
	game_root.add_child(actor_root)
	corpse_root = Node3D.new()
	corpse_root.name = "Corpses"
	game_root.add_child(corpse_root)
	actors.clear()
	corpses.clear()

	var roster := Catalog.build_roster(rng, individual_count, species_range, current_level)
	if not batch_mode:
		_discover_roster(roster)
	roster_size = roster.size()
	var player_index := _select_player_roster_index(roster)
	var run_threat := 0 if run_uses_free_mode else threat_level
	var spawn_positions: Array[Vector3] = []
	var player_spawn := world.random_spawn_in_regions(Catalog.preferred_regions(roster[player_index]), [], 7.0)
	spawn_positions.resize(roster.size())
	spawn_positions[player_index] = player_spawn
	var occupied: Array[Vector3] = [player_spawn]
	for index in range(roster.size()):
		if index == player_index:
			continue
		var min_distance := 8.0
		if Catalog.considers_prey(roster[index], roster[player_index]):
			min_distance = 22.0
		var position_value := world.random_spawn_in_regions(Catalog.preferred_regions(roster[index]), occupied, min_distance)
		spawn_positions[index] = position_value
		occupied.append(position_value)

	for index in range(roster.size()):
		var actor := ActorScript.new()
		actor_root.add_child(actor)
		actor.setup(self, index + 1, roster[index], index == player_index and not batch_mode, spawn_positions[index], run_threat)
		actor.died.connect(_on_actor_died)
		actors.append(actor)
		if index == player_index and not batch_mode:
			player = actor

	world_started_msec = Time.get_ticks_msec()
	state = "playing"
	if not batch_mode:
		camera_rig = CameraScript.new()
		game_root.add_child(camera_rig)
		camera_rig.setup(player)
		ui.show_hud(player, world_seed, run_threat, current_level, run_uses_free_mode)
		ui.update_leaderboard(_build_level_leaderboard())
		ui.show_species_intro(player.species_id, world.current_level_profile())
		ui.add_event(("自由模式 · %s · %s" % [WorldScript.level_identity(current_level), Catalog.display_name(player.species_id)]) if run_uses_free_mode else ("%s · 新的生态已经苏醒" % WorldScript.level_identity(current_level)), "#a8e3ac")
		ui.add_event("环境：%s" % world.condition_summary(), "#a8cde3")
		ui.add_battle_report("%s已开启 · %s · %d个体进入竞争" % [WorldScript.level_identity(current_level), WorldScript.level_rule_summary(current_level), roster_size], "战场", "#a8cde3")
		var unlocked_names: Array[String] = []
		for species_id in Catalog.ORDER:
			if Catalog.unlock_level(species_id) == current_level and current_level > 1:
				unlocked_names.append(Catalog.display_name(species_id))
		if not unlocked_names.is_empty():
			ui.add_event("本关新物种：%s" % "、".join(unlocked_names), "#f0cf78")
		ui.show_hint("%s：%s" % [WorldScript.level_identity(current_level), WorldScript.level_rule_summary(current_level)])
		if audio != null:
			audio.set_context("game")
			audio.play_sfx("world")
		_on_orientation_blocked_changed(ui.is_orientation_blocked())
		_begin_tutorial_if_needed()


func _select_player_roster_index(roster: Array[String]) -> int:
	if roster.is_empty():
		return -1
	if run_uses_free_mode and not batch_mode:
		if roster.has(selected_free_species):
			return roster.find(selected_free_species)
		var replacement_index := rng.randi_range(0, roster.size() - 1)
		roster[replacement_index] = selected_free_species
		return replacement_index
	var player_index := rng.randi_range(0, roster.size() - 1)
	if roster[player_index] == last_player_species and roster.size() > 1:
		player_index = (player_index + rng.randi_range(1, roster.size() - 1)) % roster.size()
	last_player_species = roster[player_index]
	return player_index


func _clear_game_root() -> void:
	tutorial_active = false
	player = null
	world = null
	actors.clear()
	corpses.clear()
	if is_instance_valid(game_root):
		# queue_free() lets active input, tween and timer callbacks finish before
		# the old generation disappears. Disable it immediately so it cannot run
		# one more ecology tick after the arrays above are repopulated.
		game_root.process_mode = Node.PROCESS_MODE_DISABLED
		game_root.visible = false
		game_root.queue_free()
	game_root = null


func _begin_tutorial_if_needed() -> void:
	if batch_mode or tutorial_completed:
		return
	tutorial_active = false
	tutorial_step = 0
	tutorial_world_seed = world_seed
	await get_tree().create_timer(8.75, false).timeout
	if state != "playing" or tutorial_completed or tutorial_world_seed != world_seed:
		return
	tutorial_active = true
	_show_current_tutorial_step()


func _show_current_tutorial_step() -> void:
	if ui == null or not tutorial_active or tutorial_step < 0 or tutorial_step >= TUTORIAL_STEPS.size():
		return
	var step_data: Dictionary = TUTORIAL_STEPS[tutorial_step]
	var touch_layout := OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") or "--touch-preview" in OS.get_cmdline_user_args()
	ui.show_tutorial_step(
		tutorial_step + 1,
		TUTORIAL_STEPS.size(),
		str(step_data["title"]),
		str(step_data["touch"] if touch_layout else step_data["desktop"])
	)


func on_player_action(action_id: String) -> void:
	if not tutorial_active or tutorial_completed or tutorial_step < 0 or tutorial_step >= TUTORIAL_STEPS.size():
		return
	var current_frame := Engine.get_physics_frames()
	if tutorial_advance_frame == current_frame:
		return
	if str(TUTORIAL_STEPS[tutorial_step]["id"]) != action_id:
		return
	tutorial_advance_frame = current_frame
	tutorial_step += 1
	if tutorial_step >= TUTORIAL_STEPS.size():
		_complete_tutorial(false)
	else:
		_show_current_tutorial_step()


func _skip_tutorial() -> void:
	_complete_tutorial(true)


func _complete_tutorial(skipped: bool) -> void:
	if tutorial_completed:
		return
	tutorial_completed = true
	tutorial_active = false
	tutorial_step = -1
	_save_progress()
	if ui != null:
		ui.hide_tutorial()
		ui.show_hint("教学已跳过，可在设置中重新开启" if skipped else "基础教学完成！现在利用生态活到最后")
		if not skipped:
			ui.add_event("已完成新手生态适应", "#f1d46b")


func _on_actor_died(actor: EcoActor, killer: EcoActor) -> void:
	if state != "playing" or not is_instance_valid(actor):
		return
	var corpse := CorpseScript.new()
	corpse_root.add_child(corpse)
	corpse.global_position = Vector3(actor.global_position.x, 0.0, actor.global_position.z)
	corpse.setup(actor.species_id, actor.actor_id)
	corpses.append(corpse)
	if is_instance_valid(killer) and killer != actor:
		killer.claim_fresh_corpse(corpse)
	if is_instance_valid(world):
		world.record_danger_memory(actor.global_position, actor.species_id, int(actor.data["size"]), killer.species_id if is_instance_valid(killer) else "")
	if is_instance_valid(killer) and killer != actor:
		var reward := Catalog.combat_experience_reward(killer.species_id, actor.species_id, actor.level)
		killer.gain_experience(reward, actor.species_id)
	elif not is_instance_valid(killer):
		pass
	var influence_source: EcoActor = actor.ecology_influence_source if is_instance_valid(actor.ecology_influence_source) else null
	if is_instance_valid(influence_source) and not influence_source.dead and influence_source != killer:
		var assist_reward := maxi(int(round(Catalog.combat_experience_reward(influence_source.species_id, actor.species_id, actor.level) * 0.45)), 1)
		influence_source.assists += 1
		influence_source.gain_experience(assist_reward, actor.species_id, actor.ecology_influence_reason)

	if batch_mode:
		batch_deaths.append({
			"time": level_elapsed,
			"victim": actor.species_id,
			"killer": (killer.species_id if is_instance_valid(killer) else ""),
			"food_bites": actor.food_bites,
			"habit_activations": actor.habit_activation_count,
			"stuck_recoveries": actor.stuck_recoveries,
			"route_replans": actor.route_replans,
			"distance": actor.distance_travelled,
		})
	else:
		var victim_name := Catalog.display_name(actor.species_id)
		var remaining_count := get_living_actors().size()
		if is_instance_valid(killer):
			var killer_name := Catalog.display_name(killer.species_id)
			ui.add_event("%s 被 %s 击倒" % [victim_name, killer_name], "#ecc89d")
			ui.add_battle_report("Lv.%d %s%s 击倒 Lv.%d %s%s · 累计%d击杀 · 剩余%d" % [
				killer.level, ("你·" if killer == player else ""), killer_name,
				actor.level, ("你·" if actor == player else ""), victim_name,
				killer.kills, remaining_count,
			], "击杀", "#ecc89d")
		else:
			ui.add_event("%s 没能熬过饥饿" % victim_name, "#c7c7aa")
			ui.add_battle_report("Lv.%d %s%s 因饥饿倒下 · 剩余%d" % [
				actor.level, ("你·" if actor == player else ""), victim_name, remaining_count,
			], "生存", "#c7c7aa")
		ui.update_leaderboard(_build_level_leaderboard())
	play_sfx_near("death", actor.global_position, actor == player)

	if actor == player:
		state = "ending"
		if not run_uses_free_mode:
			total_deaths += 1
			threat_level = mini(threat_level + 1, 8)
		_finish_loss(killer)
		return

	var living := get_living_actors()
	if living.size() == 1 and living[0] == player and is_instance_valid(player) and not player.dead:
		state = "ending"
		if not run_uses_free_mode:
			threat_level = maxi(threat_level - 2, 0)
			last_completed_level = current_level
			campaign_level = mini(current_level + 1, LEVEL_CONFIG.size())
		_finish_victory()


func _finish_loss(killer: EcoActor) -> void:
	await get_tree().create_timer(0.75).timeout
	if state != "ending":
		return
	var cause := "饥饿吞噬了你"
	if is_instance_valid(killer):
		cause = "%s结束了你的这次生命" % Catalog.display_name(killer.species_id)
	var seconds := float(Time.get_ticks_msec() - world_started_msec) / 1000.0
	var killer_species := killer.species_id if is_instance_valid(killer) else ""
	var recap := _record_completed_run(false, cause, killer_species, seconds)
	_save_progress()
	var pressure_text := "自由模式不改变战役进度与威胁" if run_uses_free_mode else "世界威胁升至：%d" % threat_level
	var body := "%s\n\n物种：%s　关卡：%d　存活：%s　成长：Lv.%d（%d 经验）\n击杀：%d　生态助攻：%d　战术行动：%d　进食：%d\n伤害：造成 %d / 承受 %d　冲刺：%s\n生态热点：抵达 %d / 出现 %d　猎手峰值：%d\n生态踪迹：追踪 %d　危险绕行 %d\n%s\n\n复盘建议：%s%s%s\n\n旧世界已经终结。下一次，你会成为另一种生命。" % [
		cause,
		Catalog.display_name(player.species_id) if is_instance_valid(player) else "未知",
		current_level,
		_format_time(seconds),
		player.level if is_instance_valid(player) else 1,
		player.experience if is_instance_valid(player) else 0,
		player.kills if is_instance_valid(player) else 0,
		player.assists if is_instance_valid(player) else 0,
		player.tactical_actions if is_instance_valid(player) else 0,
		player.food_bites if is_instance_valid(player) else 0,
		roundi(player.damage_dealt) if is_instance_valid(player) else 0,
		roundi(player.damage_taken) if is_instance_valid(player) else 0,
		_format_time(player.sprint_seconds if is_instance_valid(player) else 0.0),
		player_hotspots_visited,
		ecology_events_started,
		ecology_hunter_peak,
		ecology_trace_investigations,
		danger_memory_avoidances,
		pressure_text,
		str(recap.get("advice", "")),
		_new_discovery_recap(),
		_recent_battle_recap(),
	]
	ui.show_result("本次生命结束", body, "重新自由挑战" if run_uses_free_mode else "轮回重生")
	if audio != null:
		audio.set_context("result")
	get_tree().paused = true
	state = "result"


func _finish_victory() -> void:
	await get_tree().create_timer(0.75).timeout
	if state != "ending" or not is_instance_valid(player):
		return
	var seconds := float(Time.get_ticks_msec() - world_started_msec) / 1000.0
	var recap := _record_completed_run(true, "成为最后的存活物种", "", seconds)
	_save_progress()
	var progression_text := "自由模式第 %d 关挑战完成；战役进度保持不变。" % current_level if run_uses_free_mode else ("已通关全部十关，下一局将继续在第十关高压力生态中轮回。" if last_completed_level >= LEVEL_CONFIG.size() else "即将进入第 %d 关：更大的地图与更多个体。" % campaign_level)
	var body := "你以%s的身份成为最后的战斗个体。\n\n关卡：%d　存活：%s　成长：Lv.%d（%d 经验）\n直接击杀：%d　生态助攻：%d　战术行动：%d　进食：%d\n伤害：造成 %d / 承受 %d　冲刺：%s\n生态热点：抵达 %d / 出现 %d　猎手峰值：%d\n生态踪迹：追踪 %d　危险绕行 %d\n轮回死亡：%d　世界种子：%s\n\n%s\n下一局建议：%s%s%s\n\n生态没有真正的终点——这里只有暂时的幸存者。" % [
		Catalog.display_name(player.species_id),
		current_level,
		_format_time(seconds),
		player.level,
		player.experience,
		player.kills,
		player.assists,
		player.tactical_actions,
		player.food_bites,
		roundi(player.damage_dealt),
		roundi(player.damage_taken),
		_format_time(player.sprint_seconds),
		player_hotspots_visited,
		ecology_events_started,
		ecology_hunter_peak,
		ecology_trace_investigations,
		danger_memory_avoidances,
		total_deaths,
		world_seed,
		progression_text,
		str(recap.get("advice", "")),
		_new_discovery_recap(),
		_recent_battle_recap(),
	]
	ui.show_result("生态胜者", body, "再次自由挑战" if run_uses_free_mode else "再启新世界")
	if audio != null:
		audio.set_context("result")
		audio.play_sfx("victory")
	get_tree().paused = true
	state = "victory"


func _check_collapse_trigger() -> void:
	var level_config: Dictionary = LEVEL_CONFIG[current_level - 1]
	var establishment: float = level_config["establishment"]
	if level_elapsed < establishment:
		return
	var ratio: float = level_config["convergence_ratio"]
	var living_ratio := float(get_living_actors().size()) / maxf(float(roster_size), 1.0)
	var forced_collapse: float = float(level_config["forced_collapse"])
	if living_ratio > ratio and level_elapsed < forced_collapse:
		return
	collapse_triggered = true
	if is_instance_valid(world):
		world.trigger_collapse()
	if not batch_mode:
		ui.add_event("栖息地压力上升，外圈食物停止再生，幸存者将争夺中央领地", "#e8c34a")
		ui.add_battle_report("栖息地开始收缩，幸存者将争夺中央领地", "环境", "#e8c34a")
		if audio != null:
			audio.play_sfx("collapse", -2.0)


func _on_ecology_event_started(event: Dictionary) -> void:
	ecology_events_started += 1
	ecology_activity_timer = 0.0
	if batch_mode or ui == null:
		return
	var title := str(event.get("title", "生态热点"))
	var region_name := str(event.get("region_name", "未知区域"))
	var description := str(event.get("description", "新的资源正在聚集"))
	var color := str(event.get("color", "#e6c66f"))
	ui.show_hint("%s · %s：%s" % [title, region_name, description])
	ui.add_event("生态热点 · %s在%s出现" % [title, region_name], color)
	ui.add_battle_report("%s在%s形成，附近动物开始迁徙" % [title, region_name], "热点", color)
	if audio != null:
		audio.play_sfx("world", -1.5)


func _on_ecology_event_ended(event: Dictionary) -> void:
	ecology_hotspot_snapshot.clear()
	if batch_mode or ui == null:
		return
	var title := str(event.get("title", "生态热点"))
	ui.add_event("%s已经平息" % title, "#a9bca5")
	ui.add_battle_report("%s结束，迁徙动物重新评估食物与威胁" % title, "环境", "#a9bca5")


func _update_player_ecology_hotspot() -> void:
	if not is_instance_valid(world) or not is_instance_valid(player):
		return
	var event := world.get_active_ecology_event()
	if event.is_empty():
		return
	var sequence := int(event.get("sequence", -1))
	if visited_ecology_events.has(sequence):
		return
	var hotspot_position: Vector3 = event.get("position", Vector3(INF, 0.0, INF))
	var visit_radius := float(event.get("radius", 6.0)) + 2.0
	if Vector2(player.global_position.x - hotspot_position.x, player.global_position.z - hotspot_position.z).length() > visit_radius:
		return
	visited_ecology_events[sequence] = true
	player_hotspots_visited += 1
	var title := str(event.get("title", "生态热点"))
	ui.show_hint("抵达%s：观察争食者、伏击路线和可利用的第三方" % title)
	ui.add_event("已抵达%s · 本局第%d处热点" % [title, player_hotspots_visited], "#f0cf78")
	ui.add_battle_report("你·%s抵达%s，进入资源争夺区" % [Catalog.display_name(player.species_id), title], "探索", "#f0cf78")


func _refresh_ecology_hotspot_activity(delta: float) -> void:
	ecology_activity_timer -= delta
	if ecology_activity_timer > 0.0:
		return
	ecology_activity_timer = 0.45
	if not is_instance_valid(world):
		ecology_hotspot_snapshot.clear()
		return
	var event := world.get_active_ecology_event()
	if event.is_empty():
		ecology_hotspot_snapshot.clear()
		return
	var sequence := int(event.get("sequence", -1))
	var migrants := 0
	var hunters := 0
	for actor in get_living_actors():
		if _actor_is_hotspot_migrant(actor, event):
			migrants += 1
		if _actor_is_hotspot_hunter(actor, event):
			hunters += 1
	var risk := WorldScript.ecology_activity_risk(migrants, hunters)
	ecology_hotspot_snapshot = {"sequence": sequence, "migrants": migrants, "hunters": hunters, "risk": risk}
	ecology_hunter_peak = maxi(ecology_hunter_peak, hunters)
	world.update_ecology_event_activity(migrants, hunters)
	if batch_mode or ui == null:
		return
	var title := str(event.get("title", "生态热点"))
	if hunters > 0 and reported_hotspot_hunter_sequence != sequence:
		reported_hotspot_hunter_sequence = sequence
		ui.add_event("%s出现猎手 · 补给点转为围猎区" % title, "#f0b46f")
		ui.add_battle_report("%d名猎手正在%s外围追踪迁徙猎物" % [hunters, title], "围猎", "#f0b46f")
	if risk == "高危" and reported_hotspot_danger_sequence != sequence:
		reported_hotspot_danger_sequence = sequence
		ui.show_hint("%s已成高危围猎区：弱小物种应绕行、等待混战或寻找其他食物" % title)
		ui.add_battle_report("%s猎手密度过高，谨慎迁徙" % title, "高危", "#ef7d68")


func _actor_is_hotspot_migrant(actor: EcoActor, event: Dictionary) -> bool:
	if not is_instance_valid(actor) or actor.dead:
		return false
	return actor.is_migrating_to_ecology_hotspot(int(event.get("sequence", -1)), event.get("position", Vector3.ZERO), float(event.get("radius", 7.0)))


func _actor_is_hotspot_hunter(actor: EcoActor, event: Dictionary) -> bool:
	if not is_instance_valid(actor) or actor.dead:
		return false
	var sequence := int(event.get("sequence", -1))
	if actor.is_stalking_ecology_hotspot(sequence):
		return true
	if actor.ai_state != "hunt" or not is_instance_valid(actor.ai_target):
		return false
	var center: Vector3 = event.get("position", Vector3.ZERO)
	var hunt_radius := float(event.get("radius", 7.0)) + 12.0
	return actor.global_position.distance_to(center) <= hunt_radius and actor.ai_target.global_position.distance_to(center) <= hunt_radius


func ecology_hotspot_prey_signal_count(hunter: EcoActor) -> int:
	if not is_instance_valid(world) or not is_instance_valid(hunter):
		return 0
	var event := world.get_active_ecology_event()
	if event.is_empty():
		return 0
	var count := 0
	for candidate in get_living_actors():
		if candidate == hunter or not Catalog.considers_prey(hunter.species_id, candidate.species_id):
			continue
		if _actor_is_hotspot_migrant(candidate, event):
			count += 1
	return count


func ecology_hotspot_risk_level() -> String:
	return str(ecology_hotspot_snapshot.get("risk", "平稳"))


func ecology_hotspot_activity_status() -> String:
	if ecology_hotspot_snapshot.is_empty():
		return "迁徙监测 · 尚无活动"
	return WorldScript.ecology_activity_status(int(ecology_hotspot_snapshot.get("migrants", 0)), int(ecology_hotspot_snapshot.get("hunters", 0)))


func ecology_trace_status() -> String:
	if not is_instance_valid(world) or not is_instance_valid(player):
		return "生态踪迹 · 暂无线索"
	return world.ecology_trace_status(player.actor_id, player.species_id, player.global_position)


func on_ecology_trace_investigation(actor: EcoActor, trace: Dictionary) -> void:
	ecology_trace_investigations += 1
	if batch_mode or ui == null or ecology_trace_report_cooldown > 0.0 or not is_instance_valid(actor):
		return
	ecology_trace_report_cooldown = 9.0
	var prey_name := Catalog.display_name(str(trace.get("species_id", "未知")))
	var hunter_name := Catalog.display_name(actor.species_id)
	ui.add_event("%s循着%s的%s展开追踪" % [hunter_name, prey_name, str(trace.get("kind", "足迹"))], "#d5b27a")
	ui.add_battle_report("%s只获得过去位置，正在调查%s留下的%s" % [hunter_name, prey_name, str(trace.get("kind", "足迹"))], "追踪", "#d5b27a")


func on_danger_memory_avoidance(actor: EcoActor, memory: Dictionary) -> void:
	danger_memory_avoidances += 1
	if batch_mode or ui == null or danger_memory_report_cooldown > 0.0 or not is_instance_valid(actor):
		return
	danger_memory_report_cooldown = 11.0
	var actor_name := Catalog.display_name(actor.species_id)
	ui.add_event("%s察觉危险残迹并改变路线" % actor_name, "#8fd0c2")
	ui.add_battle_report("%s避开%s；极度饥饿时会重新冒险" % [actor_name, str(memory.get("kind", "危险地点"))], "避险", "#8fd0c2")


func _start_batch_run() -> void:
	current_level = batch_level
	threat_level = 0
	batch_deaths = []
	_start_new_world()


func _start_benchmark() -> void:
	selected_free_level = benchmark_level
	selected_free_species = benchmark_species
	quality_preset = benchmark_quality
	if world_seed_override < 0:
		world_seed_override = 133700 + benchmark_level
	benchmark_finished = false
	benchmark_frames = 0
	benchmark_process_seconds = 0.0
	benchmark_physics_seconds = 0.0
	benchmark_max_frame_ms = 0.0
	benchmark_max_process_ms = 0.0
	benchmark_max_physics_ms = 0.0
	benchmark_max_nodes = 0
	benchmark_max_objects = 0
	benchmark_max_draw_calls = 0
	benchmark_max_primitives = 0
	benchmark_max_static_memory = 0
	_start_new_world(true)
	benchmark_started_usec = Time.get_ticks_usec()
	print("[benchmark] 第%d关 · %s画质 · %s · 目标%.1f秒" % [benchmark_level, benchmark_quality, benchmark_species, benchmark_duration])


func _tick_benchmark(delta: float) -> void:
	if benchmark_finished or benchmark_started_usec <= 0:
		return
	if state == "playing":
		var process_seconds := float(Performance.get_monitor(Performance.TIME_PROCESS))
		var physics_seconds := float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
		benchmark_frames += 1
		benchmark_process_seconds += process_seconds
		benchmark_physics_seconds += physics_seconds
		benchmark_max_frame_ms = maxf(benchmark_max_frame_ms, delta * 1000.0)
		benchmark_max_process_ms = maxf(benchmark_max_process_ms, process_seconds * 1000.0)
		benchmark_max_physics_ms = maxf(benchmark_max_physics_ms, physics_seconds * 1000.0)
		benchmark_max_nodes = maxi(benchmark_max_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		benchmark_max_objects = maxi(benchmark_max_objects, int(Performance.get_monitor(Performance.OBJECT_COUNT)))
		benchmark_max_draw_calls = maxi(benchmark_max_draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		benchmark_max_primitives = maxi(benchmark_max_primitives, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		benchmark_max_static_memory = maxi(benchmark_max_static_memory, int(Performance.get_monitor(Performance.MEMORY_STATIC)))
		if level_elapsed >= benchmark_duration:
			_finish_benchmark("duration_complete")
	elif state in ["ending", "result", "victory"]:
		_finish_benchmark("run_ended_early")


func _finish_benchmark(outcome: String) -> void:
	if benchmark_finished:
		return
	benchmark_finished = true
	var wall_seconds := maxf(float(Time.get_ticks_usec() - benchmark_started_usec) / 1000000.0, 0.001)
	var sampled_frames := maxi(benchmark_frames, 1)
	var report := {
		"schema_version": 1,
		"game_version": RELEASE_VERSION,
		"level": benchmark_level,
		"quality": benchmark_quality,
		"species": benchmark_species,
		"world_seed": world_seed,
		"target_simulation_seconds": benchmark_duration,
		"sampled_simulation_seconds": level_elapsed,
		"wall_seconds": wall_seconds,
		"sampled_frames": benchmark_frames,
		"wall_fps": float(benchmark_frames) / wall_seconds,
		"average_process_ms": benchmark_process_seconds * 1000.0 / float(sampled_frames),
		"average_physics_ms": benchmark_physics_seconds * 1000.0 / float(sampled_frames),
		"max_frame_ms": benchmark_max_frame_ms,
		"max_process_ms": benchmark_max_process_ms,
		"max_physics_ms": benchmark_max_physics_ms,
		"max_nodes": benchmark_max_nodes,
		"max_objects": benchmark_max_objects,
		"max_draw_calls": benchmark_max_draw_calls,
		"max_primitives": benchmark_max_primitives,
		"max_static_memory_bytes": benchmark_max_static_memory,
		"living_actors_at_end": get_living_actors().size(),
		"outcome": outcome,
		"display_driver": DisplayServer.get_name(),
		"rendering_method": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "gl_compatibility")),
	}
	var output_path := _report_path(benchmark_report_filename(benchmark_level, benchmark_quality))
	var report_file := FileAccess.open(output_path, FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(JSON.stringify(report, "\t"))
		report_file.close()
	else:
		push_error("[benchmark] 无法写入性能报告：%s" % output_path)
	print("[benchmark] 完成 · wall FPS %.1f · process avg/max %.2f/%.2f ms · physics avg/max %.2f/%.2f ms · nodes %d · memory %.1f MiB" % [
		float(report["wall_fps"]), float(report["average_process_ms"]), float(report["max_process_ms"]),
		float(report["average_physics_ms"]), float(report["max_physics_ms"]), benchmark_max_nodes,
		float(benchmark_max_static_memory) / 1048576.0,
	])
	print("[benchmark] 报告：%s" % ProjectSettings.globalize_path(output_path))
	state = "ending"
	_quit_after_benchmark_cleanup.call_deferred()


func _quit_after_benchmark_cleanup() -> void:
	_clear_game_root()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()


func _collect_batch_actor_metrics(living: Array[EcoActor]) -> Dictionary:
	var totals := {"stuck_recoveries": 0, "route_replans": 0, "food_bites": 0, "habit_activations": 0, "distance": 0.0}
	for death in batch_deaths:
		for key in ["stuck_recoveries", "route_replans", "food_bites", "habit_activations"]:
			totals[key] = int(totals[key]) + int(death.get(key, 0))
		totals["distance"] = float(totals["distance"]) + float(death.get("distance", 0.0))
	for actor in living:
		if not is_instance_valid(actor):
			continue
		totals["stuck_recoveries"] = int(totals["stuck_recoveries"]) + actor.stuck_recoveries
		totals["route_replans"] = int(totals["route_replans"]) + actor.route_replans
		totals["food_bites"] = int(totals["food_bites"]) + actor.food_bites
		totals["habit_activations"] = int(totals["habit_activations"]) + actor.habit_activation_count
		totals["distance"] = float(totals["distance"]) + actor.distance_travelled
	return totals


func _finish_batch_run(living: Array[EcoActor]) -> void:
	state = "ending"
	var winner := "none"
	if living.size() == 1:
		winner = living[0].species_id
	var timed_out := level_elapsed > 2100.0 and living.size() > 1
	var run_index := batch_total_runs - batch_runs_remaining + 1
	var deaths_30s := _count_batch_deaths_by(30.0)
	var deaths_60s := _count_batch_deaths_by(60.0)
	var first_death_s := float(batch_deaths[0].get("time", -1.0)) if not batch_deaths.is_empty() else -1.0
	var actor_metrics := _collect_batch_actor_metrics(living)
	var starvation_deaths := 0
	for death in batch_deaths:
		if str(death.get("killer", "")) == "":
			starvation_deaths += 1
	batch_results.append({
		"world_seed": world_seed,
		"winner": winner,
		"duration": level_elapsed,
		"deaths": batch_deaths.duplicate(),
		"events": ecology_events_started,
		"hunter_peak": ecology_hunter_peak,
		"trace_hunts": ecology_trace_investigations,
		"danger_avoids": danger_memory_avoidances,
		"deaths_30s": deaths_30s,
		"deaths_60s": deaths_60s,
		"first_death_s": first_death_s,
		"stuck_recoveries": int(actor_metrics["stuck_recoveries"]),
		"route_replans": int(actor_metrics["route_replans"]),
		"food_bites": int(actor_metrics["food_bites"]),
		"habit_activations": int(actor_metrics["habit_activations"]),
		"distance": float(actor_metrics["distance"]),
		"starvation_deaths": starvation_deaths,
		"timeout": timed_out,
	})
	if batch_log_file != null:
		batch_log_file.store_line("%d,%d,%d,%s,%.1f,%d,%d,%d,%.1f,%d,%d,%d,%d,%d,%d,%d,%d,%.1f,%d,%s" % [run_index, batch_level, world_seed, winner, level_elapsed, batch_deaths.size(), deaths_30s, deaths_60s, first_death_s, ecology_events_started, ecology_hunter_peak, ecology_trace_investigations, danger_memory_avoidances, int(actor_metrics["stuck_recoveries"]), int(actor_metrics["route_replans"]), int(actor_metrics["food_bites"]), int(actor_metrics["habit_activations"]), float(actor_metrics["distance"]), starvation_deaths, "timeout" if timed_out else "ok"])
	if batch_death_log_file != null:
		for death in batch_deaths:
			batch_death_log_file.store_line("%d,%.1f,%s,%s,%d,%d,%d,%d,%.1f" % [run_index, float(death.get("time", -1.0)), death["victim"], death["killer"], int(death.get("food_bites", 0)), int(death.get("habit_activations", 0)), int(death.get("stuck_recoveries", 0)), int(death.get("route_replans", 0)), float(death.get("distance", 0.0))])
	print("[batch] run %d/%d done — seed=%d winner=%s duration=%.1fs deaths=%d early=30s:%d/60s:%d first=%.1fs events=%d hunter_peak=%d trace_hunts=%d danger_avoids=%d stuck=%d/replans=%d food=%d/habits=%d%s" % [
		run_index, batch_total_runs, world_seed, winner, level_elapsed, batch_deaths.size(), deaths_30s, deaths_60s, first_death_s, ecology_events_started, ecology_hunter_peak, ecology_trace_investigations, danger_memory_avoidances, int(actor_metrics["stuck_recoveries"]), int(actor_metrics["route_replans"]), int(actor_metrics["food_bites"]), int(actor_metrics["habit_activations"]), " (超时)" if timed_out else ""
	])
	if timed_out:
		var survivor_details: Array[String] = []
		for survivor in living:
			survivor_details.append("%s(HP %.0f, %.1f/%.1f, %s)" % [
				survivor.species_id, survivor.health, survivor.global_position.x, survivor.global_position.z, survivor.ai_state
			])
		print("[batch] survivors: %s" % ", ".join(survivor_details))
	batch_runs_remaining -= 1
	if batch_runs_remaining > 0:
		_start_batch_run()
	else:
		_print_batch_report()
		if batch_log_file != null:
			batch_log_file.close()
		if batch_death_log_file != null:
			batch_death_log_file.close()
		get_tree().quit()


func _count_batch_deaths_by(cutoff_seconds: float) -> int:
	var count := 0
	for death in batch_deaths:
		if float(death.get("time", INF)) <= cutoff_seconds:
			count += 1
	return count


func _print_batch_report() -> void:
	print("\n===== 批量模拟报告（%d 局，第 %d 关）=====" % [batch_total_runs, batch_level])
	var win_counts: Dictionary = {}
	var death_counts: Dictionary = {}
	var starvation_deaths := 0
	var combat_deaths := 0
	var total_duration := 0.0
	var total_events := 0
	var total_hunter_peak := 0
	var total_trace_hunts := 0
	var total_danger_avoids := 0
	var total_stuck_recoveries := 0
	var total_route_replans := 0
	var total_food_bites := 0
	var total_habit_activations := 0
	var total_distance := 0.0
	var total_deaths_30s := 0
	var total_deaths_60s := 0
	var total_first_death_s := 0.0
	var runs_with_deaths := 0
	var timeout_runs := 0
	for result in batch_results:
		var winner: String = result["winner"]
		win_counts[winner] = int(win_counts.get(winner, 0)) + 1
		total_duration += float(result["duration"])
		total_events += int(result.get("events", 0))
		total_hunter_peak += int(result.get("hunter_peak", 0))
		total_trace_hunts += int(result.get("trace_hunts", 0))
		total_danger_avoids += int(result.get("danger_avoids", 0))
		total_stuck_recoveries += int(result.get("stuck_recoveries", 0))
		total_route_replans += int(result.get("route_replans", 0))
		total_food_bites += int(result.get("food_bites", 0))
		total_habit_activations += int(result.get("habit_activations", 0))
		total_distance += float(result.get("distance", 0.0))
		total_deaths_30s += int(result.get("deaths_30s", 0))
		total_deaths_60s += int(result.get("deaths_60s", 0))
		var first_death_s := float(result.get("first_death_s", -1.0))
		if first_death_s >= 0.0:
			total_first_death_s += first_death_s
			runs_with_deaths += 1
		if result["timeout"]:
			timeout_runs += 1
		for death in result["deaths"]:
			var victim: String = death["victim"]
			death_counts[victim] = int(death_counts.get(victim, 0)) + 1
			if death["killer"] == "":
				starvation_deaths += 1
			else:
				combat_deaths += 1
	print("平均局长：%.1fs　超时未分胜负：%d/%d" % [total_duration / maxf(float(batch_results.size()), 1.0), timeout_runs, batch_total_runs])
	print("开局死亡：30秒内 %.1f 只/局　60秒内 %.1f 只/局　平均首例 %.1fs" % [
		float(total_deaths_30s) / maxf(float(batch_results.size()), 1.0),
		float(total_deaths_60s) / maxf(float(batch_results.size()), 1.0),
		total_first_death_s / maxf(float(runs_with_deaths), 1.0),
	])
	print("平均生态热点：%.1f 次/局" % [float(total_events) / maxf(float(batch_results.size()), 1.0)])
	print("平均热点猎手峰值：%.1f" % [float(total_hunter_peak) / maxf(float(batch_results.size()), 1.0)])
	print("平均踪迹追踪：%.1f　平均危险绕行：%.1f" % [float(total_trace_hunts) / maxf(float(batch_results.size()), 1.0), float(total_danger_avoids) / maxf(float(batch_results.size()), 1.0)])
	print("AI路径：平均脱困 %.1f　改道 %.1f　总移动 %.0fm/局" % [float(total_stuck_recoveries) / maxf(float(batch_results.size()), 1.0), float(total_route_replans) / maxf(float(batch_results.size()), 1.0), total_distance / maxf(float(batch_results.size()), 1.0)])
	print("生存行为：平均进食 %.1f 次/局　习性触发 %.1f 次/局" % [float(total_food_bites) / maxf(float(batch_results.size()), 1.0), float(total_habit_activations) / maxf(float(batch_results.size()), 1.0)])
	print("死因：战斗击杀 %d　饥饿 %d" % [combat_deaths, starvation_deaths])
	print("胜率（按物种）：")
	for species_id in win_counts.keys():
		print("  %s: %d/%d (%.0f%%)" % [species_id, win_counts[species_id], batch_total_runs, 100.0 * win_counts[species_id] / batch_total_runs])
	print("死亡次数（按物种，越高越常成为猎物/牺牲品）：")
	for species_id in death_counts.keys():
		print("  %s: %d" % [species_id, death_counts[species_id]])
	print("详细数据：%s" % ProjectSettings.globalize_path(_report_path(batch_results_filename(batch_level))))
	print("========================================\n")


static func batch_results_filename(level: int) -> String:
	return "batch_level_%02d_results.csv" % clampi(level, 1, LEVEL_CONFIG.size())


static func batch_deaths_filename(level: int) -> String:
	return "batch_level_%02d_deaths.csv" % clampi(level, 1, LEVEL_CONFIG.size())


static func benchmark_report_filename(level: int, quality: String) -> String:
	var safe_quality := quality if quality in QUALITY_PRESETS else "medium"
	return "benchmark_level_%02d_%s.json" % [clampi(level, 1, LEVEL_CONFIG.size()), safe_quality]


func _open_report_file(filename: String) -> FileAccess:
	return FileAccess.open(_report_path(filename), FileAccess.WRITE)


func _report_path(filename: String) -> String:
	if report_directory.is_empty():
		return "user://%s" % filename
	var directory := report_directory
	if directory.begins_with("user://") or directory.begins_with("res://"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		return directory.path_join(filename)
	if not directory.is_absolute_path():
		directory = ProjectSettings.globalize_path("res://").path_join(directory)
	DirAccess.make_dir_recursive_absolute(directory)
	return directory.path_join(filename)


func _find_cmdline_value(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix + "="):
			return arg.substr(prefix.length() + 1)
	return ""


func _toggle_pause() -> void:
	if state == "playing":
		state = "paused"
		ui.show_pause()
		if audio != null:
			audio.set_context("pause")
		get_tree().paused = true
	elif state == "paused":
		get_tree().paused = false
		state = "playing"
		ui.modal_root.hide()
		if audio != null:
			audio.set_context("game")


func get_living_actors() -> Array[EcoActor]:
	var living: Array[EcoActor] = []
	for actor in actors:
		if is_instance_valid(actor) and not actor.dead and not actor.is_queued_for_deletion():
			living.append(actor)
	return living


func _build_level_leaderboard() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for actor in get_living_actors():
		entries.append({
			"actor_id": actor.actor_id,
			"species_id": actor.species_id,
			"name": Catalog.display_name(actor.species_id),
			"level": actor.level,
			"experience": actor.experience,
			"kills": actor.kills,
			"health_ratio": clampf(actor.health / maxf(actor.max_health, 1.0), 0.0, 1.0),
			"is_player": actor == player,
		})
	return rank_level_entries(entries)


static func rank_level_entries(entries: Array[Dictionary]) -> Array[Dictionary]:
	var ranked: Array[Dictionary] = entries.duplicate(true)
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("level", 1)) != int(b.get("level", 1)):
			return int(a.get("level", 1)) > int(b.get("level", 1))
		if int(a.get("experience", 0)) != int(b.get("experience", 0)):
			return int(a.get("experience", 0)) > int(b.get("experience", 0))
		if int(a.get("kills", 0)) != int(b.get("kills", 0)):
			return int(a.get("kills", 0)) > int(b.get("kills", 0))
		if not is_equal_approx(float(a.get("health_ratio", 0.0)), float(b.get("health_ratio", 0.0))):
			return float(a.get("health_ratio", 0.0)) > float(b.get("health_ratio", 0.0))
		return int(a.get("actor_id", 0)) < int(b.get("actor_id", 0))
	)
	for index in range(ranked.size()):
		ranked[index]["rank"] = index + 1
	return ranked


func nearest_corpse(origin: Vector3, max_distance: float, excluded_instance_id: int = 0) -> Node3D:
	var nearest: Node3D
	var nearest_distance := max_distance
	for corpse in corpses:
		if not is_instance_valid(corpse) or corpse.is_queued_for_deletion() or corpse.food_amount <= 0.0:
			continue
		if excluded_instance_id != 0 and corpse.get_instance_id() == excluded_instance_id:
			continue
		var distance := origin.distance_to(corpse.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = corpse
	return nearest


func get_available_corpses() -> Array[Node3D]:
	var available: Array[Node3D] = []
	for corpse in corpses:
		if is_instance_valid(corpse) and not corpse.is_queued_for_deletion() and corpse.food_amount > 0.0:
			available.append(corpse)
	return available


func nearest_food(origin: Vector3, max_distance: float, eater_species: String = "", include_hotspots: bool = true, excluded_instance_id: int = 0) -> Node3D:
	if not is_instance_valid(world):
		return null
	var nearest: Node3D
	var nearest_distance := INF
	for patch in world.food_patches:
		if not is_instance_valid(patch) or patch.is_queued_for_deletion() or not patch.active:
			continue
		if excluded_instance_id != 0 and patch.get_instance_id() == excluded_instance_id:
			continue
		if not include_hotspots and patch.ecology_hotspot:
			continue
		if eater_species != "" and not patch.can_be_eaten_by(eater_species):
			continue
		var patch_position: Vector3 = patch.global_position if patch.is_inside_tree() else patch.position
		var distance := origin.distance_to(patch_position)
		var search_distance := world.ecology_event_attraction_radius() if patch.ecology_hotspot else max_distance
		if distance <= search_distance and distance < nearest_distance:
			nearest_distance = distance
			nearest = patch
	return nearest


func get_move_input() -> Vector2:
	if "--camera-test" in OS.get_cmdline_user_args():
		return Vector2(0.72, -0.46)
	var keyboard := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var touch := ui.get_touch_move() if ui != null else Vector2.ZERO
	return touch if touch.length() > keyboard.length() else keyboard


func input_to_world(input_vector: Vector2) -> Vector3:
	return camera_rig.input_to_world(input_vector) if is_instance_valid(camera_rig) else Vector3(input_vector.x, 0.0, input_vector.y)


func is_attack_pressed() -> bool:
	return Input.is_action_pressed("attack") or (ui != null and ui.attack_held)


func is_sprint_pressed() -> bool:
	return Input.is_action_pressed("sprint") or (ui != null and ui.sprint_held)


func consume_skill_request() -> bool:
	if Input.is_action_just_pressed("skill"):
		return true
	return ui.consume_skill() if ui != null else false


func consume_interact_request() -> bool:
	if Input.is_action_just_pressed("interact"):
		return true
	return ui.consume_interact() if ui != null else false


func get_ai_damage_multiplier() -> float:
	return 1.0 if run_uses_free_mode else 1.0 + min(threat_level, 8) * 0.045


func show_hint(text_value: String) -> void:
	if ui != null:
		ui.show_hint(text_value)


func show_enemy_health(target: EcoActor) -> void:
	if ui != null and not batch_mode:
		ui.show_enemy_health(target)


func on_opportunity_strike(attacker: EcoActor, target: EcoActor, threat_gap: int, bonus_damage: float, ambush_strike: bool = false, terrain_strike: bool = false) -> void:
	if ui == null or batch_mode or not is_instance_valid(attacker) or not is_instance_valid(target):
		return
	if attacker == player:
		ui.show_enemy_health(target)
		var strike_name := "草丛伏击" if ambush_strike else ("主场反制" if terrain_strike else "抓住破绽")
		var event_name := "伏击逆袭" if ambush_strike else ("地形逆袭" if terrain_strike else "逆袭")
		var event_color := "#8fe8b7" if ambush_strike else ("#70cfe8" if terrain_strike else "#f1d46b")
		ui.show_hint("%s！无视部分护甲，额外造成 %d 伤害" % [strike_name, roundi(bonus_damage)])
		ui.add_event("%s命中%s · 威胁差%d级" % [event_name, Catalog.display_name(target.species_id), threat_gap], event_color)
		if ambush_strike:
			ui.add_battle_report("你·%s从草丛伏击%s，直接制造破绽" % [Catalog.display_name(attacker.species_id), Catalog.display_name(target.species_id)], "伏击", "#8fe8b7")
		elif terrain_strike:
			ui.add_battle_report("你·%s利用主场地形反制%s，制造追击破绽" % [Catalog.display_name(attacker.species_id), Catalog.display_name(target.species_id)], "地形", "#70cfe8")
	elif target == player:
		ui.show_hint("你遭到草丛伏击！先拉开距离" if ambush_strike else ("你在对方主场遭到地形反制！尽快换区" if terrain_strike else "你在破绽状态遭到逆袭！停止攻击并恢复耐力"))


func on_ecology_intervention(bait: EcoActor, aggressor: EcoActor, responder: EcoActor) -> void:
	if ui == null or batch_mode or not is_instance_valid(bait) or not is_instance_valid(aggressor) or not is_instance_valid(responder):
		return
	var bait_name := Catalog.display_name(bait.species_id)
	var aggressor_name := Catalog.display_name(aggressor.species_id)
	var responder_name := Catalog.display_name(responder.species_id)
	if bait == player:
		ui.show_hint("生态借力成功：%s已被%s接战，趁机脱离或等待助攻" % [aggressor_name, responder_name])
		ui.add_event("引导%s与%s发生冲突" % [aggressor_name, responder_name], "#d7a2f2")
		ui.add_battle_report("你·%s借势引战，%s转而迎击%s" % [bait_name, responder_name, aggressor_name], "借力", "#d7a2f2")
	elif aggressor == player:
		ui.show_hint("你的攻击惊动了%s，它正在介入战斗" % responder_name)
		ui.add_battle_report("你·%s追击%s时惊动%s，第三方冲突形成" % [aggressor_name, bait_name, responder_name], "借力", "#d7a2f2")
	elif is_instance_valid(player) and player.global_position.distance_to(bait.global_position) <= 28.0:
		ui.add_battle_report("%s把%s引向%s，附近形成第三方冲突" % [bait_name, aggressor_name, responder_name], "借力", "#c49be0")


func on_counterplay_progress(actor: EcoActor, target: EcoActor, route_id: String, xp_award: int, chain_count: int, mastery_triggered: bool, health_restored: float, stamina_restored: float) -> void:
	if ui == null or batch_mode or not is_instance_valid(actor) or not is_instance_valid(target):
		return
	var route_names := {"opportunity": "破绽逆袭", "ambush": "草丛伏击", "terrain": "主场反制", "ecology": "生态借力"}
	var route_colors := {"opportunity": "#f1d46b", "ambush": "#8fe8b7", "terrain": "#70cfe8", "ecology": "#d7a2f2"}
	var route_name := str(route_names.get(route_id, "战术行动"))
	var route_color := str(route_colors.get(route_id, "#f0cf78"))
	if actor == player:
		if mastery_triggered:
			ui.show_hint("生态掌控！两种战术完成连携，恢复 %d 生命 / %d 耐力" % [roundi(health_restored), roundi(stamina_restored)])
			ui.add_event("生态掌控 · 对%s完成战术连携" % Catalog.display_name(target.species_id), "#ffb86b")
			ui.add_battle_report("你用不同战术掌控%s · 恢复生命与耐力" % Catalog.display_name(target.species_id), "掌控", "#ffb86b")
		elif xp_award > 0:
			ui.add_battle_report("你对%s完成%s · 连携%d/2 · +%d经验" % [Catalog.display_name(target.species_id), route_name, mini(chain_count, 2), xp_award], "战术", route_color)
	elif mastery_triggered and is_instance_valid(player) and player.global_position.distance_to(actor.global_position) <= 28.0:
		ui.add_battle_report("%s以不同战术掌控%s，恢复战斗节奏" % [Catalog.display_name(actor.species_id), Catalog.display_name(target.species_id)], "掌控", "#ffb86b")


func on_player_experience_gained(amount: int, defeated_species: String, reason: String = "击杀") -> void:
	if ui == null or batch_mode:
		return
	if reason == "觅食":
		ui.add_event("觅食%s · 获得 %d 经验" % [defeated_species, amount], "#8fe0b0")
		return
	var action_text := "击倒" if reason == "击杀" else "%s ·" % reason
	ui.add_event("%s%s · 获得 %d 经验" % [action_text, Catalog.display_name(defeated_species), amount], "#8fe0b0" if reason == "击杀" else "#f0cf78")
	if reason != "击杀" and reason != "战术成长":
		ui.add_battle_report("你对%s形成%s，获得%d经验" % [Catalog.display_name(defeated_species), reason, amount], "助攻", "#f0cf78")


func on_actor_level_up(actor: EcoActor, new_level: int) -> void:
	if ui == null or batch_mode or not is_instance_valid(actor) or actor == player:
		return
	ui.add_battle_report("%s 升至 Lv.%d，生存能力完成进化" % [Catalog.display_name(actor.species_id), new_level], "成长", "#9fd7e8")
	ui.update_leaderboard(_build_level_leaderboard())


func on_player_level_up(new_level: int, gains: Dictionary = {}) -> void:
	if ui == null or batch_mode:
		return
	var growth_text := "生命、攻击、速度、耐力与护甲提升"
	if not gains.is_empty():
		growth_text = "生命+%d　攻击+%.1f　速度+%.2f　耐力+%d　护甲+%.1f　恢复+%.1f" % [
			ceili(float(gains.get("health", 0.0))),
			float(gains.get("attack", 0.0)),
			float(gains.get("speed", 0.0)),
			ceili(float(gains.get("stamina", 0.0))),
			float(gains.get("armor", 0.0)),
			float(gains.get("regen", 0.0)),
		]
	ui.show_hint("提升至 Lv.%d！%s" % [new_level, growth_text])
	ui.add_event("%s · Lv.%d · %s" % [str(gains.get("profile", "生态适应")), new_level, growth_text], "#f1d46b")
	ui.add_battle_report("你·%s 升至 Lv.%d · %s" % [Catalog.display_name(player.species_id), new_level, str(gains.get("profile", "生态适应"))], "成长", "#f1d46b")
	ui.update_leaderboard(_build_level_leaderboard())
	if audio != null:
		audio.play_sfx("level_up", 1.0)


func play_ui_sound() -> void:
	if audio != null:
		audio.play_sfx("ui")


func play_sfx_near(effect_name: String, source_position: Vector3, important: bool = false) -> void:
	if audio == null or batch_mode:
		return
	var gain_db := 0.0
	if not important and is_instance_valid(player):
		var distance := player.global_position.distance_to(source_position)
		if distance > 28.0:
			return
		gain_db = -distance * 0.32
	audio.play_sfx(effect_name, gain_db)


func is_music_enabled() -> bool:
	return audio != null and audio.music_enabled


func is_sfx_enabled() -> bool:
	return audio != null and audio.sfx_enabled


func set_music_enabled(value: bool) -> void:
	if audio != null:
		audio.set_music_enabled(value)


func set_sfx_enabled(value: bool) -> void:
	if audio != null:
		audio.set_sfx_enabled(value)
		if value:
			audio.play_sfx("ui")


func has_campaign_progress() -> bool:
	return campaign_level > 1 or total_deaths > 0 or threat_level > 0


func menu_start_text() -> String:
	return "继续轮回" if has_campaign_progress() else "开始轮回"


func bestiary_progress_text() -> String:
	return "生态图鉴　发现 %d / %d" % [discovered_species.size(), Catalog.ORDER.size()]


func get_bestiary_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for species_id in Catalog.ORDER:
		var discovered := species_id in discovered_species
		var record: Dictionary = species_records.get(species_id, {})
		if not discovered:
			entries.append({
				"species_id": species_id,
				"discovered": false,
				"name": "未发现物种",
				"list_text": "？？？　·　第 %d 关起可能出现" % Catalog.unlock_level(species_id),
				"detail": "继续进入第 %d 关及之后的生态世界，在阵容中遇见它即可记录。\n\n图鉴只解锁知识与战绩，不会永久增加任何属性。" % Catalog.unlock_level(species_id),
			})
			continue
		var data := Catalog.get_data(species_id)
		var record_text := "尚未以该物种完成一局"
		if not record.is_empty():
			record_text = "出战 %d　获胜 %d　最高挑战第 %d 关\n最佳存活 %s　最高 Lv.%d　单局最多击杀 %d" % [
				int(record.get("runs", 0)), int(record.get("wins", 0)), int(record.get("best_level", 0)),
				_format_time(float(record.get("best_survival", 0.0))), int(record.get("best_player_level", 1)), int(record.get("most_kills", 0)),
			]
		var diet_name: String = str({"herbivore": "植食", "omnivore": "杂食", "carnivore": "肉食"}.get(str(data.get("diet", "omnivore")), "杂食"))
		entries.append({
			"species_id": species_id,
			"discovered": true,
			"name": str(data["name"]),
			"list_text": "%s　·　%s　·　战斗阶位 %d" % [str(data["name"]), diet_name, Catalog.combat_tier(species_id)],
			"detail": "%s · %s\n%s　体型 %d　生命 %d　攻击 %.1f　速度 %.2f\n\n%s\n%s\n偏爱食物：%s\n反制组合：%s\n\n战斗被动：%s — %s\n主动技能：%s — %s\n\n获胜攻略：%s\n\n个人记录\n%s" % [
				str(data["name"]), str(data["subtitle"]), diet_name, int(data["size"]), int(data["health"]), float(data["attack"]), float(data["speed"]),
				Catalog.habitat_description(species_id), Catalog.habit_description(species_id), Catalog.habit_foods_display_text(species_id), Catalog.counterplay_plan(species_id),
				str(data["passive"]), str(data["passive_hint"]), str(data["skill"]), str(data["skill_hint"]), Catalog.victory_guide(species_id), record_text,
			],
		})
	return entries


func get_recent_runs() -> Array[Dictionary]:
	return recent_runs.duplicate(true)


func _discover_roster(roster: Array[String], persist: bool = true) -> void:
	var changed := false
	for species_id in roster:
		if species_id not in discovered_species:
			discovered_species.append(species_id)
			new_discoveries_current_run.append(species_id)
			changed = true
	discovered_species.sort_custom(func(a: String, b: String): return Catalog.ORDER.find(a) < Catalog.ORDER.find(b))
	if changed and persist:
		_save_progress()


func _record_completed_run(won: bool, cause: String, killer_species: String, seconds: float) -> Dictionary:
	if not is_instance_valid(player):
		return {}
	var species_id := player.species_id
	var record: Dictionary = species_records.get(species_id, {})
	record["runs"] = int(record.get("runs", 0)) + 1
	record["wins"] = int(record.get("wins", 0)) + (1 if won else 0)
	record["campaign_runs"] = int(record.get("campaign_runs", 0)) + (0 if run_uses_free_mode else 1)
	record["free_runs"] = int(record.get("free_runs", 0)) + (1 if run_uses_free_mode else 0)
	record["best_level"] = maxi(int(record.get("best_level", 0)), current_level)
	record["best_survival"] = maxf(float(record.get("best_survival", 0.0)), seconds)
	record["best_player_level"] = maxi(int(record.get("best_player_level", 1)), player.level)
	record["most_kills"] = maxi(int(record.get("most_kills", 0)), player.kills)
	record["most_assists"] = maxi(int(record.get("most_assists", 0)), player.assists)
	record["most_tactical_actions"] = maxi(int(record.get("most_tactical_actions", 0)), player.tactical_actions)
	species_records[species_id] = record
	var starvation := killer_species == "" and not won
	var advice := _run_advice(species_id, killer_species, starvation, won)
	var summary := {
		"species_id": species_id,
		"level": current_level,
		"won": won,
		"free_mode": run_uses_free_mode,
		"survival": seconds,
		"player_level": player.level,
		"experience": player.experience,
		"kills": player.kills,
		"assists": player.assists,
		"tactical_actions": player.tactical_actions,
		"food_bites": player.food_bites,
		"damage_dealt": player.damage_dealt,
		"damage_taken": player.damage_taken,
		"sprint_seconds": player.sprint_seconds,
		"cause": cause,
		"killer_species": killer_species,
		"advice": advice,
		"world_seed": world_seed,
		"new_discoveries": new_discoveries_current_run.duplicate(),
	}
	recent_runs.push_front(summary)
	if recent_runs.size() > RUN_HISTORY_LIMIT:
		recent_runs.resize(RUN_HISTORY_LIMIT)
	return summary


func _run_advice(species_id: String, killer_species: String, starvation: bool, won: bool) -> String:
	if won:
		return "%s 下次可尝试更高压力或不同反制路线。" % Catalog.victory_guide(species_id)
	if starvation:
		return "饱腹归零后会持续掉血。优先沿%s寻找%s，并在生命低于习性阈值前脱离战斗。" % [
			Catalog.habitat_description(species_id).trim_prefix("环境适应："), Catalog.habit_foods_display_text(species_id),
		]
	if killer_species != "":
		return "面对%s不要正面对耗。%s" % [Catalog.display_name(killer_species), Catalog.counterplay_plan(species_id)]
	return Catalog.victory_guide(species_id)


func _new_discovery_recap() -> String:
	if new_discoveries_current_run.is_empty():
		return ""
	var names: Array[String] = []
	for species_id in new_discoveries_current_run:
		names.append(Catalog.display_name(species_id))
	return "\n新发现：%s（已写入生态图鉴）" % "、".join(names)


func _recent_battle_recap() -> String:
	if ui == null or not ui.has_method("recent_battle_report_lines"):
		return ""
	var lines: Array[String] = ui.recent_battle_report_lines(10, 3)
	return "" if lines.is_empty() else "\n最后 10 秒：%s" % "；".join(lines)


func get_selected_free_level() -> int:
	return selected_free_level


func set_selected_free_level(value: int) -> void:
	selected_free_level = clampi(value, 1, LEVEL_CONFIG.size())
	_save_progress()


func get_selected_free_species() -> String:
	return selected_free_species


func set_selected_free_species(species_id: String) -> void:
	selected_free_species = species_id if Catalog.ORDER.has(species_id) else "rabbit"
	_save_progress()


func get_quality_preset() -> String:
	return quality_preset


func set_quality_preset(value: String) -> void:
	quality_preset = _sanitize_quality(value)
	if is_instance_valid(world) and world.has_method("apply_quality_preset"):
		world.apply_quality_preset(quality_preset)
	_save_progress()
	if ui != null:
		ui.show_hint("画质已切换为%s" % quality_display_name(quality_preset))


func quality_display_name(value: String) -> String:
	return {"low": "性能", "medium": "平衡", "high": "高画质"}.get(_sanitize_quality(value), "平衡")


func reset_tutorial_progress() -> void:
	tutorial_completed = false
	tutorial_active = false
	tutorial_step = -1
	_save_progress()
	if ui != null:
		ui.hide_tutorial()
		ui.show_hint("新手教学已重新开启，将在下一局显示")


func reset_game_progress() -> void:
	get_tree().paused = false
	state = "menu"
	_clear_game_root()
	threat_level = 0
	total_deaths = 0
	current_level = 1
	campaign_level = 1
	last_completed_level = 0
	last_player_species = ""
	world_seed = 0
	tutorial_completed = false
	tutorial_active = false
	tutorial_step = -1
	selected_free_level = 1
	selected_free_species = "rabbit"
	run_uses_free_mode = false
	discovered_species.clear()
	species_records.clear()
	recent_runs.clear()
	new_discoveries_current_run.clear()
	_save_progress()
	if audio != null:
		audio.set_context("menu")
		audio.play_sfx("reset")
	if ui != null:
		ui.show_menu()
		ui.show_hint("游戏进度已重置")


func _format_time(seconds_value: float) -> String:
	var total := int(seconds_value)
	return "%02d:%02d" % [total / 60, total % 60]


func _ensure_input_map() -> void:
	_add_key_action("move_up", [KEY_W, KEY_UP])
	_add_key_action("move_down", [KEY_S, KEY_DOWN])
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("sprint", [KEY_SHIFT])
	_add_key_action("skill", [KEY_SPACE])
	_add_key_action("interact", [KEY_E])
	_add_key_action("pause", [KEY_ESCAPE])
	_add_key_action("attack", [KEY_J])
	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	if not InputMap.action_has_event("attack", mouse_event):
		InputMap.action_add_event("attack", mouse_event)


func _add_key_action(action_name: StringName, keys: Array[Key]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for key_code in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key_code
		if not InputMap.action_has_event(action_name, event):
			InputMap.action_add_event(action_name, event)


func _save_progress(path: String = CONFIG_PATH) -> void:
	var config := ConfigFile.new()
	config.load(path)
	config.set_value("meta", "save_version", SAVE_VERSION)
	config.set_value("campaign", "threat_level", threat_level)
	config.set_value("campaign", "total_deaths", total_deaths)
	config.set_value("campaign", "last_species", last_player_species)
	config.set_value("campaign", "current_level", campaign_level)
	config.set_value("campaign", "campaign_level", campaign_level)
	config.set_value("campaign", "last_completed_level", last_completed_level)
	config.set_value("onboarding", "tutorial_completed", tutorial_completed)
	config.set_value("video", "quality_preset", quality_preset)
	config.set_value("gameplay", "selected_free_level", selected_free_level)
	config.set_value("gameplay", "selected_free_species", selected_free_species)
	config.set_value("bestiary", "discovered_species", discovered_species)
	config.set_value("bestiary", "species_records", species_records)
	config.set_value("bestiary", "recent_runs", recent_runs)
	if config.has_section_key("gameplay", "all_levels_unlocked"):
		config.erase_section_key("gameplay", "all_levels_unlocked")
	config.save(path)


func _load_progress(path: String = CONFIG_PATH) -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	var loaded_version := int(config.get_value("meta", "save_version", 0))
	threat_level = clampi(int(config.get_value("campaign", "threat_level", 0)), 0, 8)
	total_deaths = maxi(int(config.get_value("campaign", "total_deaths", 0)), 0)
	last_player_species = str(config.get_value("campaign", "last_species", ""))
	if not Catalog.ORDER.has(last_player_species):
		last_player_species = ""
	campaign_level = clampi(int(config.get_value("campaign", "campaign_level", config.get_value("campaign", "current_level", 1))), 1, LEVEL_CONFIG.size())
	last_completed_level = clampi(int(config.get_value("campaign", "last_completed_level", maxi(campaign_level - 1, 0))), 0, LEVEL_CONFIG.size())
	tutorial_completed = bool(config.get_value("onboarding", "tutorial_completed", false))
	quality_preset = _sanitize_quality(str(config.get_value("video", "quality_preset", quality_preset)))
	selected_free_level = clampi(int(config.get_value("gameplay", "selected_free_level", campaign_level)), 1, LEVEL_CONFIG.size())
	selected_free_species = str(config.get_value("gameplay", "selected_free_species", "rabbit"))
	if not Catalog.ORDER.has(selected_free_species):
		selected_free_species = "rabbit"
	discovered_species.clear()
	var loaded_discoveries: Array = config.get_value("bestiary", "discovered_species", [])
	for species_id_value in loaded_discoveries:
		var species_id := str(species_id_value)
		if Catalog.ORDER.has(species_id) and species_id not in discovered_species:
			discovered_species.append(species_id)
	discovered_species.sort_custom(func(a: String, b: String): return Catalog.ORDER.find(a) < Catalog.ORDER.find(b))
	species_records = _sanitize_species_records(config.get_value("bestiary", "species_records", {}))
	recent_runs = _sanitize_recent_runs(config.get_value("bestiary", "recent_runs", []))
	current_level = campaign_level
	if loaded_version < SAVE_VERSION:
		_save_progress(path)


func _sanitize_quality(value: String) -> String:
	return value if QUALITY_PRESETS.has(value) else "medium"


func _sanitize_species_records(value: Variant) -> Dictionary:
	var sanitized: Dictionary = {}
	if not value is Dictionary:
		return sanitized
	for species_id_value in value:
		var species_id := str(species_id_value)
		var raw_record: Variant = value[species_id_value]
		if not Catalog.ORDER.has(species_id) or not raw_record is Dictionary:
			continue
		var raw: Dictionary = raw_record
		sanitized[species_id] = {
			"runs": maxi(int(raw.get("runs", 0)), 0),
			"wins": maxi(int(raw.get("wins", 0)), 0),
			"campaign_runs": maxi(int(raw.get("campaign_runs", 0)), 0),
			"free_runs": maxi(int(raw.get("free_runs", 0)), 0),
			"best_level": clampi(int(raw.get("best_level", 0)), 0, LEVEL_CONFIG.size()),
			"best_survival": clampf(float(raw.get("best_survival", 0.0)), 0.0, 86400.0),
			"best_player_level": clampi(int(raw.get("best_player_level", 1)), 1, 8),
			"most_kills": maxi(int(raw.get("most_kills", 0)), 0),
			"most_assists": maxi(int(raw.get("most_assists", 0)), 0),
			"most_tactical_actions": maxi(int(raw.get("most_tactical_actions", 0)), 0),
		}
		if int(sanitized[species_id]["wins"]) > int(sanitized[species_id]["runs"]):
			sanitized[species_id]["wins"] = sanitized[species_id]["runs"]
	return sanitized


func _sanitize_recent_runs(value: Variant) -> Array[Dictionary]:
	var sanitized: Array[Dictionary] = []
	if not value is Array:
		return sanitized
	for item in value:
		if not item is Dictionary:
			continue
		var raw: Dictionary = item
		var species_id := str(raw.get("species_id", ""))
		if not Catalog.ORDER.has(species_id):
			continue
		var safe_new_discoveries: Array[String] = []
		var raw_new_discoveries: Variant = raw.get("new_discoveries", [])
		if raw_new_discoveries is Array:
			for discovered_id_value in raw_new_discoveries:
				var discovered_id := str(discovered_id_value)
				if Catalog.ORDER.has(discovered_id) and discovered_id not in safe_new_discoveries:
					safe_new_discoveries.append(discovered_id)
		sanitized.append({
			"species_id": species_id,
			"level": clampi(int(raw.get("level", 1)), 1, LEVEL_CONFIG.size()),
			"won": bool(raw.get("won", false)),
			"free_mode": bool(raw.get("free_mode", false)),
			"survival": clampf(float(raw.get("survival", 0.0)), 0.0, 86400.0),
			"player_level": clampi(int(raw.get("player_level", 1)), 1, 8),
			"experience": maxi(int(raw.get("experience", 0)), 0),
			"kills": maxi(int(raw.get("kills", 0)), 0),
			"assists": maxi(int(raw.get("assists", 0)), 0),
			"tactical_actions": maxi(int(raw.get("tactical_actions", 0)), 0),
			"food_bites": maxi(int(raw.get("food_bites", 0)), 0),
			"damage_dealt": maxf(float(raw.get("damage_dealt", 0.0)), 0.0),
			"damage_taken": maxf(float(raw.get("damage_taken", 0.0)), 0.0),
			"sprint_seconds": clampf(float(raw.get("sprint_seconds", 0.0)), 0.0, 86400.0),
			"cause": str(raw.get("cause", "")),
			"killer_species": str(raw.get("killer_species", "")) if Catalog.ORDER.has(str(raw.get("killer_species", ""))) else "",
			"advice": str(raw.get("advice", "")),
			"world_seed": int(raw.get("world_seed", 0)),
			"new_discoveries": safe_new_discoveries,
		})
		if sanitized.size() >= RUN_HISTORY_LIMIT:
			break
	return sanitized
