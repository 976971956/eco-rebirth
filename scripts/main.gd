extends Node

const Catalog = preload("res://scripts/species_catalog.gd")
const WorldScript = preload("res://scripts/eco_world.gd")
const ActorScript = preload("res://scripts/eco_actor.gd")
const CorpseScript = preload("res://scripts/corpse.gd")
const CameraScript = preload("res://scripts/camera_rig.gd")
const UIScript = preload("res://scripts/game_ui.gd")
const AudioScript = preload("res://scripts/audio_manager.gd")

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
	{"individuals": 10, "world_size": 86.0, "species_range": Vector2i(4, 5), "establishment": 45.0, "convergence_ratio": 0.40},
	{"individuals": 20, "world_size": 104.0, "species_range": Vector2i(5, 6), "establishment": 55.0, "convergence_ratio": 0.35},
	{"individuals": 30, "world_size": 118.0, "species_range": Vector2i(6, 6), "establishment": 65.0, "convergence_ratio": 0.33},
	{"individuals": 40, "world_size": 130.0, "species_range": Vector2i(6, 6), "establishment": 75.0, "convergence_ratio": 0.30},
	{"individuals": 50, "world_size": 140.0, "species_range": Vector2i(6, 6), "establishment": 85.0, "convergence_ratio": 0.28},
	{"individuals": 60, "world_size": 150.0, "species_range": Vector2i(6, 6), "establishment": 95.0, "convergence_ratio": 0.27},
	{"individuals": 70, "world_size": 158.0, "species_range": Vector2i(6, 6), "establishment": 105.0, "convergence_ratio": 0.25},
	{"individuals": 80, "world_size": 166.0, "species_range": Vector2i(6, 6), "establishment": 115.0, "convergence_ratio": 0.24},
	{"individuals": 90, "world_size": 174.0, "species_range": Vector2i(6, 6), "establishment": 120.0, "convergence_ratio": 0.22},
	{"individuals": 100, "world_size": 182.0, "species_range": Vector2i(6, 6), "establishment": 135.0, "convergence_ratio": 0.20},
]

var world_seed: int = 0
var threat_level: int = 0
var total_deaths: int = 0
var current_level: int = 1
var last_completed_level: int = 0
var roster_size: int = 10
var batch_mode: bool = false
var batch_level: int = 1
var batch_runs_remaining: int = 0
var batch_total_runs: int = 0
var level_elapsed: float = 0.0
var collapse_triggered: bool = false
var batch_deaths: Array = []
var batch_results: Array = []
var batch_log_file: FileAccess
var batch_death_log_file: FileAccess
var state: String = "menu"
var last_player_species: String = ""
var world_started_msec: int = 0
var _skill_request_latched: bool = false
var _interact_request_latched: bool = false


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
	ui.retry_requested.connect(_on_retry_requested)
	ui.menu_requested.connect(_on_menu_requested)
	ui.pause_requested.connect(_toggle_pause)
	audio.set_context("menu")
	var batch_arg := _find_cmdline_value("--batch-sim")
	if batch_arg != "":
		batch_total_runs = maxi(int(batch_arg), 1)
		batch_runs_remaining = batch_total_runs
		var level_arg := _find_cmdline_value("--batch-level")
		batch_level = clampi(int(level_arg) if level_arg != "" else 1, 1, LEVEL_CONFIG.size())
		batch_mode = true
		Engine.time_scale = 4.0
		batch_log_file = FileAccess.open("user://batch_results.csv", FileAccess.WRITE)
		if batch_log_file != null:
			batch_log_file.store_line("run,level,winner,duration_s,death_count,outcome")
		batch_death_log_file = FileAccess.open("user://batch_deaths.csv", FileAccess.WRITE)
		if batch_death_log_file != null:
			batch_death_log_file.store_line("run,victim,killer")
		_start_batch_run.call_deferred()
	elif "--autoplay" in OS.get_cmdline_user_args():
		_start_new_world.call_deferred()


func _process(delta: float) -> void:
	if state == "playing":
		level_elapsed += delta
		if not collapse_triggered:
			_check_collapse_trigger()
	if batch_mode and state == "playing":
		var living := get_living_actors()
		if living.size() <= 1 or level_elapsed > 900.0:
			_finish_batch_run(living)
			return
	if state == "playing" and is_instance_valid(player):
		var region_name := world.region_name_at(player.global_position) if is_instance_valid(world) else "未知区域"
		ui.update_hud(player, get_living_actors().size(), roster_size, region_name)
	if (state == "playing" or state == "paused") and Input.is_action_just_pressed("pause"):
		_toggle_pause()
	corpses = corpses.filter(func(item): return is_instance_valid(item) and not item.is_queued_for_deletion())


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and state == "playing":
		_toggle_pause.call_deferred()


func _on_start_requested() -> void:
	threat_level = 0
	total_deaths = 0
	current_level = 1
	_save_progress()
	_start_new_world()


func _on_retry_requested() -> void:
	if state == "paused":
		get_tree().paused = false
		state = "playing"
		ui.modal_root.hide()
		if audio != null:
			audio.set_context("game")
		return
	get_tree().paused = false
	_start_new_world()


func _on_menu_requested() -> void:
	get_tree().paused = false
	state = "menu"
	_clear_game_root()
	ui.show_menu()
	if audio != null:
		audio.set_context("menu")


func _start_new_world() -> void:
	get_tree().paused = false
	_clear_game_root()
	state = "loading"
	level_elapsed = 0.0
	collapse_triggered = false
	world_seed = int(Time.get_unix_time_from_system() * 1000.0) ^ int(Time.get_ticks_msec()) ^ (total_deaths * 7919) ^ randi()
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
	world.setup(world_seed, world_size_value)
	actor_root = Node3D.new()
	actor_root.name = "Actors"
	game_root.add_child(actor_root)
	corpse_root = Node3D.new()
	corpse_root.name = "Corpses"
	game_root.add_child(corpse_root)
	actors.clear()
	corpses.clear()

	var roster := Catalog.build_roster(rng, individual_count, species_range)
	roster_size = roster.size()
	var player_index := rng.randi_range(0, roster.size() - 1)
	if roster[player_index] == last_player_species and roster.size() > 1:
		player_index = (player_index + rng.randi_range(1, roster.size() - 1)) % roster.size()
	last_player_species = roster[player_index]
	var spawn_positions: Array[Vector3] = []
	var player_spawn := world.random_spawn([], 7.0)
	spawn_positions.resize(roster.size())
	spawn_positions[player_index] = player_spawn
	var occupied: Array[Vector3] = [player_spawn]
	for index in range(roster.size()):
		if index == player_index:
			continue
		var min_distance := 8.0
		if Catalog.considers_prey(roster[index], roster[player_index]):
			min_distance = 22.0
		var position_value := world.random_spawn(occupied, min_distance)
		spawn_positions[index] = position_value
		occupied.append(position_value)

	for index in range(roster.size()):
		var actor := ActorScript.new()
		actor_root.add_child(actor)
		actor.setup(self, index + 1, roster[index], index == player_index and not batch_mode, spawn_positions[index], threat_level)
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
		ui.show_hud(player, world_seed, threat_level, current_level)
		ui.show_species_intro(player.species_id)
		ui.add_event("第%d关 · 新的生态已经苏醒" % current_level, "#a8e3ac")
		ui.show_hint("观察冲突，利用生态活到最后")
		if audio != null:
			audio.set_context("game")
			audio.play_sfx("world")


func _clear_game_root() -> void:
	player = null
	world = null
	actors.clear()
	corpses.clear()
	if is_instance_valid(game_root):
		game_root.free()
	game_root = null


func _on_actor_died(actor: EcoActor, killer: EcoActor) -> void:
	if state != "playing" or not is_instance_valid(actor):
		return
	var corpse := CorpseScript.new()
	corpse_root.add_child(corpse)
	corpse.global_position = Vector3(actor.global_position.x, 0.0, actor.global_position.z)
	corpse.setup(actor.species_id, actor.actor_id)
	corpses.append(corpse)
	if is_instance_valid(killer) and killer != actor:
		var reward := Catalog.experience_reward(actor.species_id, actor.level)
		killer.gain_experience(reward, actor.species_id)
	elif not is_instance_valid(killer):
		pass
	if is_instance_valid(player) and not player.dead and killer != player and is_instance_valid(actor.ecology_influence_source) and actor.ecology_influence_source == player:
		var assist_reward := maxi(int(round(Catalog.experience_reward(actor.species_id, actor.level) * 0.45)), 1)
		player.assists += 1
		player.gain_experience(assist_reward, actor.species_id, "生态助攻")

	if batch_mode:
		batch_deaths.append({"victim": actor.species_id, "killer": (killer.species_id if is_instance_valid(killer) else "")})
	else:
		var victim_name := Catalog.display_name(actor.species_id)
		if is_instance_valid(killer):
			var killer_name := Catalog.display_name(killer.species_id)
			ui.add_event("%s 被 %s 击倒" % [victim_name, killer_name], "#ecc89d")
		else:
			ui.add_event("%s 没能熬过饥饿" % victim_name, "#c7c7aa")
		play_sfx_near("death", actor.global_position, actor == player)

	if actor == player:
		state = "ending"
		total_deaths += 1
		threat_level = mini(threat_level + 1, 8)
		_save_progress()
		_finish_loss(killer)
		return

	var living := get_living_actors()
	if living.size() == 1 and living[0] == player and is_instance_valid(player) and not player.dead:
		state = "ending"
		threat_level = maxi(threat_level - 2, 0)
		last_completed_level = current_level
		current_level = mini(current_level + 1, LEVEL_CONFIG.size())
		_save_progress()
		_finish_victory()


func _finish_loss(killer: EcoActor) -> void:
	await get_tree().create_timer(0.75).timeout
	if state != "ending":
		return
	var cause := "饥饿吞噬了你"
	if is_instance_valid(killer):
		cause = "%s结束了你的这次生命" % Catalog.display_name(killer.species_id)
	var seconds := float(Time.get_ticks_msec() - world_started_msec) / 1000.0
	var body := "%s\n\n物种：%s　存活：%s\n击杀：%d　生态助攻：%d　世界威胁升至：%d\n\n旧世界已经终结。下一次，你会成为另一种生命。" % [
		cause,
		Catalog.display_name(player.species_id) if is_instance_valid(player) else "未知",
		_format_time(seconds),
		player.kills if is_instance_valid(player) else 0,
		player.assists if is_instance_valid(player) else 0,
		threat_level
	]
	ui.show_result("本次生命结束", body, "轮回重生")
	if audio != null:
		audio.set_context("result")
	get_tree().paused = true
	state = "result"


func _finish_victory() -> void:
	await get_tree().create_timer(0.75).timeout
	if state != "ending" or not is_instance_valid(player):
		return
	var seconds := float(Time.get_ticks_msec() - world_started_msec) / 1000.0
	var body := "你以%s的身份成为森林中最后的战斗个体。\n\n存活：%s　直接击杀：%d　生态助攻：%d\n轮回死亡：%d　世界种子：%s\n\n%s\n\n生态没有真正的终点——这里只有暂时的幸存者。" % [
		Catalog.display_name(player.species_id),
		_format_time(seconds),
		player.kills,
		player.assists,
		total_deaths,
		world_seed,
		("已通关全部十关，下一局将继续在第十关高压力生态中轮回。" if last_completed_level >= LEVEL_CONFIG.size() else "即将进入第 %d 关：更大的地图与更多个体。" % current_level)
	]
	ui.show_result("生态胜者", body, "再启新世界")
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
	if living_ratio > ratio and level_elapsed < establishment * 5.333:
		return
	collapse_triggered = true
	if is_instance_valid(world):
		world.trigger_collapse()
	if not batch_mode:
		ui.add_event("栖息地压力上升，外圈食物不再再生", "#e8c34a")
		if audio != null:
			audio.play_sfx("collapse", -2.0)


func _start_batch_run() -> void:
	current_level = batch_level
	threat_level = 0
	batch_deaths = []
	_start_new_world()


func _finish_batch_run(living: Array[EcoActor]) -> void:
	state = "ending"
	var winner := "none"
	if living.size() == 1:
		winner = living[0].species_id
	var timed_out := level_elapsed > 900.0 and living.size() > 1
	var run_index := batch_total_runs - batch_runs_remaining + 1
	batch_results.append({
		"winner": winner,
		"duration": level_elapsed,
		"deaths": batch_deaths.duplicate(),
		"timeout": timed_out,
	})
	if batch_log_file != null:
		batch_log_file.store_line("%d,%d,%s,%.1f,%d,%s" % [run_index, batch_level, winner, level_elapsed, batch_deaths.size(), "timeout" if timed_out else "ok"])
	if batch_death_log_file != null:
		for death in batch_deaths:
			batch_death_log_file.store_line("%d,%s,%s" % [run_index, death["victim"], death["killer"]])
	print("[batch] run %d/%d done — winner=%s duration=%.1fs deaths=%d%s" % [
		run_index, batch_total_runs, winner, level_elapsed, batch_deaths.size(), " (超时)" if timed_out else ""
	])
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


func _print_batch_report() -> void:
	print("\n===== 批量模拟报告（%d 局，第 %d 关）=====" % [batch_total_runs, batch_level])
	var win_counts: Dictionary = {}
	var death_counts: Dictionary = {}
	var starvation_deaths := 0
	var combat_deaths := 0
	var total_duration := 0.0
	var timeout_runs := 0
	for result in batch_results:
		var winner: String = result["winner"]
		win_counts[winner] = int(win_counts.get(winner, 0)) + 1
		total_duration += float(result["duration"])
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
	print("死因：战斗击杀 %d　饥饿 %d" % [combat_deaths, starvation_deaths])
	print("胜率（按物种）：")
	for species_id in win_counts.keys():
		print("  %s: %d/%d (%.0f%%)" % [species_id, win_counts[species_id], batch_total_runs, 100.0 * win_counts[species_id] / batch_total_runs])
	print("死亡次数（按物种，越高越常成为猎物/牺牲品）：")
	for species_id in death_counts.keys():
		print("  %s: %d" % [species_id, death_counts[species_id]])
	print("详细数据：%s" % ProjectSettings.globalize_path("user://batch_results.csv"))
	print("========================================\n")


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


func nearest_corpse(origin: Vector3, max_distance: float) -> Node3D:
	var nearest: Node3D
	var nearest_distance := max_distance
	for corpse in corpses:
		if not is_instance_valid(corpse) or corpse.is_queued_for_deletion() or corpse.food_amount <= 0.0:
			continue
		var distance := origin.distance_to(corpse.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = corpse
	return nearest


func nearest_food(origin: Vector3, max_distance: float, eater_species: String = "") -> Node3D:
	if not is_instance_valid(world):
		return null
	var nearest: Node3D
	var nearest_distance := max_distance
	for patch in world.food_patches:
		if not is_instance_valid(patch) or not patch.active:
			continue
		if eater_species != "" and not patch.can_be_eaten_by(eater_species):
			continue
		var distance := origin.distance_to(patch.global_position)
		if distance < nearest_distance:
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
	return 1.0 + min(threat_level, 8) * 0.045


func show_hint(text_value: String) -> void:
	if ui != null:
		ui.show_hint(text_value)


func show_enemy_health(target: EcoActor) -> void:
	if ui != null and not batch_mode:
		ui.show_enemy_health(target)


func on_player_experience_gained(amount: int, defeated_species: String, reason: String = "击杀") -> void:
	if ui == null or batch_mode:
		return
	var action_text := "击倒" if reason == "击杀" else "%s ·" % reason
	ui.add_event("%s%s · 获得 %d 经验" % [action_text, Catalog.display_name(defeated_species), amount], "#8fe0b0" if reason == "击杀" else "#f0cf78")


func on_player_level_up(new_level: int) -> void:
	if ui == null or batch_mode:
		return
	ui.show_hint("等级提升至 Lv.%d！生命、攻击、耐力与护甲获得成长" % new_level)
	ui.add_event("完成生态适应 · 升至 Lv.%d" % new_level, "#f1d46b")
	if audio != null:
		audio.play_sfx("skill", 2.0)


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


func reset_game_progress() -> void:
	get_tree().paused = false
	state = "menu"
	_clear_game_root()
	threat_level = 0
	total_deaths = 0
	current_level = 1
	last_completed_level = 0
	last_player_species = ""
	world_seed = 0
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


func _save_progress() -> void:
	var config := ConfigFile.new()
	config.load("user://eco_rebirth.cfg")
	config.set_value("campaign", "threat_level", threat_level)
	config.set_value("campaign", "total_deaths", total_deaths)
	config.set_value("campaign", "last_species", last_player_species)
	config.set_value("campaign", "current_level", current_level)
	config.save("user://eco_rebirth.cfg")


func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load("user://eco_rebirth.cfg") != OK:
		return
	threat_level = int(config.get_value("campaign", "threat_level", 0))
	total_deaths = int(config.get_value("campaign", "total_deaths", 0))
	last_player_species = str(config.get_value("campaign", "last_species", ""))
	current_level = clampi(int(config.get_value("campaign", "current_level", 1)), 1, LEVEL_CONFIG.size())
