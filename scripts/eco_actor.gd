class_name EcoActor
extends CharacterBody3D

const Catalog = preload("res://scripts/species_catalog.gd")
const Factory = preload("res://scripts/low_poly_factory.gd")
const SkillVFX = preload("res://scripts/skill_vfx.gd")
const ProjectileScript = preload("res://scripts/skill_projectile.gd")
const WorldRules = preload("res://scripts/eco_world.gd")
const EXPOSED_STAMINA_RATIO := 0.20
const EXHAUSTION_ENTER_RATIO := 0.10
const EXHAUSTION_EXIT_RATIO := 0.25
const OPPORTUNITY_ARMOR_FACTOR := 0.50
const OPPORTUNITY_STAMINA_DAMAGE_RATIO := 0.08
const OPPORTUNITY_COOLDOWN := 3.0
const COVER_CONCEAL_THRESHOLD := 0.58
const COVER_HIDE_DELAY := 0.72
const COVER_AMBUSH_GRACE := 0.90
const COVER_REVEAL_SECONDS := 2.20
const COVER_CLOSE_REVEAL_DISTANCE := 4.60
const SEARCH_MEMORY_SECONDS := 2.60
const AMBUSH_CREATED_EXPOSURE := 1.65
const TERRAIN_MOMENTUM_REQUIRED := 1.15
const TERRAIN_MOMENTUM_GRACE := 0.85
const TERRAIN_COUNTER_COOLDOWN := 3.40
const TERRAIN_CREATED_EXPOSURE := 1.35
const TERRAIN_AFFINITY_THRESHOLD := 0.72
const ECOLOGY_LEVERAGE_RADIUS := 10.5
const ECOLOGY_LEVERAGE_COOLDOWN := 9.0
const ECOLOGY_LEVERAGE_COMMIT := 4.8
const ECOLOGY_LEVERAGE_INFLUENCE := 12.0
const COUNTERPLAY_CHAIN_WINDOW := 18.0
const COUNTERPLAY_MASTERY_HEALTH_RATIO := 0.06
const COUNTERPLAY_MASTERY_STAMINA_RATIO := 0.18
const COUNTERPLAY_MASTERY_VISUAL_TIME := 3.2
const ECOLOGY_TRACE_INTERVAL := 1.05
const ECOLOGY_TRACE_INVESTIGATION_SECONDS := 5.2
const DANGER_MEMORY_AVOID_SECONDS := 2.6
const STAMINA_REGEN_COMBAT_DELAY := 0.8
const STARVATION_DAMAGE_PER_SECOND := 0.01 / 3.0
const AI_PACK_SHARE_RADIUS := 20.0
const AI_HERD_SHARE_RADIUS := 18.0
const AI_GROUP_ALERT_RANGE := 42.0
const AI_MIN_PREY_UTILITY := 0.105

signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal hunger_changed(current: float)
signal died(actor: EcoActor, killer: EcoActor)

var game: Node
var actor_id: int = -1
var species_id: String = "rabbit"
var data: Dictionary
var is_player: bool = false
var dead: bool = false

var health: float
var max_health: float
var stamina: float
var max_stamina: float
var hunger: float = 18.0
var level: int = 1
var experience: int = 0
const MAX_LEVEL := 8
var attack_timer: float = 0.0
var skill_timer: float = 0.0
var eat_timer: float = 0.0
var stamina_regen_delay: float = 0.0
var decision_timer: float = 0.0
var wander_timer: float = 0.0
var dash_timer: float = 0.0
var dash_direction := Vector3.ZERO
var poison_timer: float = 0.0
var poison_dps: float = 0.0
var poison_source: EcoActor
var scent_mark_timer: float = 0.0
var slow_timer: float = 0.0
var slow_multiplier: float = 1.0
var hidden_timer: float = 0.0
var panic_timer: float = 0.0
var ecology_influence_source: EcoActor
var ecology_influence_timer: float = 0.0
var ecology_influence_reason: String = "生态助攻"
var last_attacker: EcoActor
var rage_timer: float = 0.0
var rage_cooldown_timer: float = 0.0
var quill_guard_timer: float = 0.0
var shell_guard_timer: float = 0.0
var forage_speed_timer: float = 0.0
var habit_buff_timer: float = 0.0
var habit_buff_kind: String = ""
var habit_buff_name: String = ""
var habit_activation_count: int = 0
var obstacle_break_timer: float = 0.0
var flight_ground_timer: float = 0.0
var flight_dive_timer: float = 0.0
var flight_target_height: float = 0.45
var landing_target_position := Vector3.ZERO
var pending_food_resource: Node3D
var burst_exhaustion_timer: float = 0.0
var exposed_timer: float = 0.0
var opportunity_strike_timer: float = 0.0
var exhausted: bool = false
var cover_strength: float = 0.0
var cover_dwell_timer: float = 0.0
var cover_sample_timer: float = 0.0
var cover_reveal_timer: float = 0.0
var cover_ambush_timer: float = 0.0
var cover_hint_cooldown: float = 0.0
var ambush_attack_armed: bool = false
var terrain_momentum: float = 0.0
var terrain_momentum_grace_timer: float = 0.0
var terrain_counter_cooldown: float = 0.0
var terrain_hint_cooldown: float = 0.0
var terrain_attack_armed: bool = false
var environment_region_id: String = ""
var environment_affinity: float = 0.0
var ecology_leverage_cooldown: float = 0.0
var escape_intervention_actor: EcoActor
var escape_intervention_position := Vector3(INF, 0.0, INF)
var canopy_timer: float = 0.0
var canopy_anchor := Vector3.ZERO
var calm_timer: float = 0.0
var territory_center := Vector3.ZERO
var territory_radius: float = 0.0
var still_timer: float = 0.0
var straight_run_timer: float = 0.0
var previous_flat_direction := Vector3.ZERO
var alert_cooldown: float = 0.0
var avoid_timer: float = 0.0
var avoid_direction := Vector3.ZERO
var state_commit_timer: float = 0.0
var starvation_warning_timer: float = 0.0
var movement_sample_timer: float = 0.0
var stuck_duration: float = 0.0
var last_sample_position := Vector3.ZERO
var recovery_timer: float = 0.0
var recovery_direction := Vector3.ZERO
var smoothed_move_direction := Vector3.ZERO
var search_timer: float = 0.0
var search_position := Vector3.ZERO
var last_known_target_position := Vector3.ZERO
var has_last_known_target_position: bool = false
var escape_cover_position := Vector3(INF, 0.0, INF)
var escape_habitat_position := Vector3(INF, 0.0, INF)
var cover_visual_state: String = "open"

var ai_state: String = "wander"
var ai_target: EcoActor
var resource_target: Node3D
var hotspot_stalk_position := Vector3(INF, 0.0, INF)
var hotspot_event_sequence: int = -1
var ecology_trace_emit_timer: float = 0.0
var ecology_trace_last_position := Vector3.ZERO
var trace_investigation_position := Vector3(INF, 0.0, INF)
var trace_investigation_timer: float = 0.0
var last_investigated_trace_sequence: int = 0
var danger_memory_position := Vector3(INF, 0.0, INF)
var danger_memory_timer: float = 0.0
var avoided_danger_sequences: Dictionary = {}
var wander_direction := Vector3.FORWARD
var desired_direction := Vector3.ZERO
var wants_sprint: bool = false
var attack_intent: bool = false
var visual_root: Node3D
var body_root: Node3D
var selection_ring: MeshInstance3D
var base_visual_scale := Vector3.ONE
var move_time: float = 0.0
var gait_blend: float = 0.0
var leg_pivots: Array[Node3D] = []
var leg_phases: Array[float] = []
var leg_stride_scales: Array[float] = []
var wing_pivots: Array[Node3D] = []
var tail_visuals: Array[Node3D] = []
var visual_lod_elapsed: float = 0.0
var kills: int = 0
var assists: int = 0
var tactical_actions: int = 0
var counterplay_route_awards: Dictionary = {}
var counterplay_xp_by_target: Dictionary = {}
var counterplay_mastered_targets: Dictionary = {}
var counterplay_chain_target_id: int = -1
var counterplay_chain_flags: int = 0
var counterplay_chain_timer: float = 0.0
var counterplay_mastery_timer: float = 0.0
var spawn_protection: float = 0.0
var health_bar_root: Node3D
var health_bar_fill: MeshInstance3D
var health_bar_label: Label3D
var health_bar_visibility_timer: float = 0.0
var forced_health_bar_timer: float = 0.0
var behavior_rng := RandomNumberGenerator.new()
var rewarded_food_sources: Dictionary = {}
var habit_rewarded_sources: Dictionary = {}
var threat_perception_multiplier: float = 1.0
var group_escape_direction := Vector3.ZERO


func setup(game_ref: Node, new_id: int, new_species_id: String, player_controlled: bool, spawn_position: Vector3, threat_level: int = 0) -> void:
	game = game_ref
	actor_id = new_id
	species_id = new_species_id
	is_player = player_controlled
	data = Catalog.get_data(species_id)
	var world_seed_value := int(game.get("world_seed")) if is_instance_valid(game) and game.get("world_seed") != null else 1
	behavior_rng.seed = behavior_seed(world_seed_value, actor_id, species_id)
	name = "%s_%02d%s" % [species_id.capitalize(), actor_id, "_Player" if is_player else ""]
	var ai_health_scale: float = 1.0 if is_player else 1.0 + float(min(threat_level, 8)) * 0.06
	if not is_player:
		data["speed"] = float(data["speed"]) * (1.0 + float(min(threat_level, 8)) * 0.01)
		threat_perception_multiplier = 1.0 + float(min(threat_level, 8)) * 0.025
	max_health = float(data["health"]) * ai_health_scale
	health = max_health
	max_stamina = float(data["stamina"])
	stamina = max_stamina
	position = spawn_position
	if Catalog.has_trait(species_id, "flying"):
		flight_target_height = float(data.get("flight_height", 4.2))
		position.y = flight_target_height
		landing_target_position = position
	territory_center = spawn_position
	if Catalog.has_trait(species_id, "territorial"):
		territory_radius = 10.0 + float(int(data["size"])) * 1.8
	collision_layer = 1
	collision_mask = 0 if Catalog.has_trait(species_id, "flying") else 2
	_build_collision()
	_build_visual()
	spawn_protection = 6.0 if is_player else 0.0
	# Every map needs a short establishment window; dense late levels otherwise
	# let long-range skills kill an actor on the very first simulation frame.
	# Taking damage immediately ends this restraint, so a player cannot attack a
	# passive target for free.
	if not is_player and is_instance_valid(game):
		var game_level_value: Variant = game.get("current_level")
		var game_level := int(game_level_value) if game_level_value != null else 0
		calm_timer = opening_caution_seconds(game_level)
	decision_timer = fmod(float(actor_id) * 0.073, 0.33) + 0.05
	wander_timer = 0.1
	last_sample_position = global_position
	ecology_trace_last_position = global_position
	ecology_trace_emit_timer = 0.35 + fmod(float(actor_id) * 0.113, 0.62)


static func behavior_seed(seed_value: int, id_value: int, species_value: String) -> int:
	return seed_value ^ (id_value * 104729) ^ species_value.hash()


static func should_rest_for_stamina(stamina_ratio: float, nearest_threat_distance: float, attacker_distance: float) -> bool:
	return stamina_ratio < EXPOSED_STAMINA_RATIO and nearest_threat_distance >= 14.0 and attacker_distance >= 14.0


static func starvation_health_after(current_health: float, maximum_health: float, delta: float) -> float:
	if current_health <= 1.0:
		return current_health
	return maxf(current_health - maximum_health * STARVATION_DAMAGE_PER_SECOND * delta, 1.0)


static func can_regenerate_stamina(sprinting: bool, recovery_delay: float) -> bool:
	return not sprinting and recovery_delay <= 0.0


static func evaluate_prey_utility(context: Dictionary) -> float:
	var hunter_health := clampf(float(context.get("hunter_health", 1.0)), 0.0, 1.0)
	var hunter_stamina := clampf(float(context.get("hunter_stamina", 1.0)), 0.0, 1.0)
	var target_health := clampf(float(context.get("target_health", 1.0)), 0.0, 1.0)
	var target_stamina := clampf(float(context.get("target_stamina", 1.0)), 0.0, 1.0)
	var hunger_ratio := clampf(float(context.get("hunger", 0.5)), 0.0, 1.0)
	var aggression := clampf(float(context.get("aggression", 0.5)), 0.0, 1.0)
	var distance := maxf(float(context.get("distance", 0.0)), 0.0)
	var speed_ratio := maxf(float(context.get("speed_ratio", 1.0)), 0.1)
	var tier_delta := clampf(float(context.get("tier_delta", 0.0)), -4.0, 4.0)
	var size_delta := clampf(float(context.get("size_delta", 0.0)), -4.0, 4.0)
	var support := clampf(float(context.get("support", 0.0)), 0.0, 4.0)
	var target_pressure := clampf(float(context.get("target_pressure", 0.0)), 0.0, 4.0)
	var habitat_delta := clampf(float(context.get("habitat_delta", 0.0)), -1.0, 1.0)
	var threat_gap := maxi(int(context.get("threat_gap", 0)), 0)
	var target_exposed := bool(context.get("target_exposed", false))
	if hunter_health <= 0.18:
		return 0.0
	var prey_value := 0.22 + (1.0 - target_health) * 0.34 + (1.0 - target_stamina) * 0.10
	prey_value += hunger_ratio * 0.18 + aggression * 0.12
	var matchup := 0.62 + tier_delta * 0.12 + size_delta * 0.055
	matchup += support * 0.085 + target_pressure * 0.065 + habitat_delta * 0.12
	matchup -= maxf(target_health - hunter_health, 0.0) * 0.28
	if speed_ratio < 0.90 and target_health > 0.45:
		matchup -= (0.90 - speed_ratio) * 0.85
	var distance_factor := lerpf(0.48, 1.0, clampf(1.0 - distance / 42.0, 0.0, 1.0))
	var result := prey_value * clampf(matchup, 0.08, 1.35) * distance_factor
	if bool(context.get("finisher", false)):
		result *= 1.0 + (1.0 - target_health) * 0.58
	if bool(context.get("pack_hunter", false)):
		result *= 1.0 + support * 0.10
	if bool(context.get("scavenger", false)):
		result *= 1.0 + target_pressure * 0.08
	if bool(context.get("ambush_ready", false)):
		result *= 1.26
	if bool(context.get("aerial_small_prey", false)):
		result *= 1.16
	if threat_gap > 0 and not target_exposed:
		result *= maxf(0.22, 0.58 - float(threat_gap) * 0.08)
	if hunter_stamina < 0.25 and distance > float(context.get("attack_range", 2.0)) * 1.8:
		result *= 0.42
	return maxf(result, 0.0)


static func should_abandon_pursuit(utility: float, hunter_health: float, hunter_stamina: float, target_health: float, distance: float, attack_range: float, final_competition: bool) -> bool:
	if final_competition:
		return false
	if utility < AI_MIN_PREY_UTILITY:
		return true
	if hunter_health < 0.30 and target_health > 0.52:
		return true
	return hunter_stamina < 0.16 and distance > attack_range + 1.8


static func should_approach_contested_food(danger_count: int, courage: float, health_ratio: float, hunger_value: float, scavenger: bool, pack_support: int) -> bool:
	if hunger_value >= 88.0:
		return true
	if health_ratio < 0.36 and danger_count > 0:
		return false
	var tolerance := pack_support
	if scavenger:
		tolerance += 1
	if courage >= 0.72:
		tolerance += 1
	return danger_count <= tolerance


static func should_follow_hotspot_signal(hunger_value: float, aggression: float, health_ratio: float, stamina_ratio: float, prey_signals: int, can_feed: bool, territory_restricted: bool, actor_value: int, event_sequence: int) -> bool:
	if prey_signals <= 0 or can_feed or hunger_value < 20.0 or health_ratio < 0.46 or stamina_ratio < 0.30:
		return false
	if territory_restricted and hunger_value < 68.0:
		return false
	var signal_score := hunger_value / 100.0 * 0.45 + clampf(aggression, 0.0, 1.0) * 0.48 + float(mini(prey_signals, 4)) * 0.08
	var threshold := 0.62 + float(posmod(actor_value + event_sequence, 4)) * 0.025
	return signal_score >= threshold


static func should_investigate_ecology_trace(hunger_value: float, aggression: float, health_ratio: float, stamina_ratio: float, scavenger: bool, territory_restricted: bool) -> bool:
	if health_ratio < 0.55 or stamina_ratio < 0.35:
		return false
	if territory_restricted and hunger_value < 70.0:
		return false
	if hunger_value < 28.0 and not scavenger:
		return false
	var motivation := hunger_value / 100.0 * 0.46 + clampf(aggression, 0.0, 1.0) * 0.44 + (0.16 if scavenger else 0.0)
	return motivation >= 0.43


static func should_avoid_danger_memory(courage: float, hunger_value: float, health_ratio: float, size_level: int, scavenger: bool) -> bool:
	if scavenger or hunger_value >= 82.0 or courage >= 0.62 or size_level >= 5:
		return false
	return size_level <= 2 or health_ratio < 0.68 or courage < 0.46


func _build_collision() -> void:
	var size_level := int(data["size"])
	var collision := CollisionShape3D.new()
	collision.name = "BodyCollision"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.28 + size_level * 0.09
	shape.height = 0.72 + size_level * 0.20
	collision.shape = shape
	collision.position.y = shape.height * 0.5
	add_child(collision)


func _build_visual() -> void:
	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)
	body_root = Node3D.new()
	body_root.name = "Animal"
	visual_root.add_child(body_root)
	match species_id:
		"rabbit": _build_rabbit()
		"fox": _build_canine(true)
		"wolf": _build_canine(false)
		"deer": _build_deer()
		"snake": _build_snake()
		"bear": _build_bear()
		"boar": _build_boar()
		"raccoon": _build_raccoon()
		"porcupine": _build_porcupine()
		"lynx": _build_feline(false)
		"capybara": _build_capybara()
		"otter": _build_otter()
		"goat": _build_goat()
		"wolverine": _build_wolverine()
		"bison": _build_bison()
		"zebra": _build_zebra()
		"elephant": _build_elephant()
		"crocodile": _build_crocodile()
		"tiger": _build_feline(true)
		"monkey": _build_monkey()
		"owl": _build_bird(true)
		"moose": _build_moose()
		"turtle": _build_turtle()
		"cheetah": _build_cheetah()
		"rhino": _build_rhino()
		"gorilla": _build_gorilla()
		"eagle": _build_bird(false)
		"hippo": _build_hippo()
		"hyena": _build_hyena()
		"lion": _build_lion()
	_collect_tail_visuals()
	base_visual_scale = body_root.scale
	_build_health_bar()
	if is_player:
		_build_player_ring()


func _build_player_ring() -> void:
	var marker_height := 2.6 + int(data["size"]) * 0.46
	selection_ring = MeshInstance3D.new()
	selection_ring.name = "PlayerRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.82 + int(data["size"]) * 0.1
	torus.outer_radius = torus.inner_radius + 0.085
	torus.rings = 16
	torus.ring_segments = 6
	selection_ring.mesh = torus
	selection_ring.material_override = Factory.material(Color("#8ff0b1"), 0.5, Color(0.25, 0.95, 0.55, 1.0))
	selection_ring.position.y = 0.07
	add_child(selection_ring)

	var arrow := Factory.cone("PlayerArrow", Color("#73f29d"), 0.28, 0.62, Vector3(0.0, marker_height, 0.0), 8)
	arrow.rotation.x = PI
	arrow.material_override = Factory.material(Color("#73f29d"), 0.35, Color(0.18, 1.0, 0.48, 1.0))
	add_child(arrow)

	var player_label := Label3D.new()
	player_label.name = "PlayerLabel"
	player_label.text = "你 · %s" % str(data["name"])
	player_label.font = load("res://assets/fonts/NotoSansSC-VF.ttf") as Font
	player_label.font_size = 48
	player_label.outline_size = 10
	player_label.modulate = Color("#eaffdf")
	player_label.outline_modulate = Color(0.01, 0.09, 0.055, 0.95)
	player_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	player_label.no_depth_test = true
	player_label.pixel_size = 0.012
	player_label.position = Vector3(0.0, marker_height + 0.56, 0.0)
	add_child(player_label)


const HEALTH_BAR_WIDTH := 1.55


func _build_health_bar() -> void:
	var bar_height := 1.85 + int(data["size"]) * 0.5
	health_bar_root = Node3D.new()
	health_bar_root.name = "HealthBar"
	health_bar_root.position = Vector3(0.0, bar_height, 0.0)
	add_child(health_bar_root)

	var background := Factory.box("HealthBarBg", Color(0.05, 0.05, 0.05), Vector3(HEALTH_BAR_WIDTH + 0.06, 0.13, 0.02))
	background.material_override.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	health_bar_root.add_child(background)

	health_bar_fill = Factory.box("HealthBarFill", Color("#5ad16a"), Vector3(HEALTH_BAR_WIDTH, 0.10, 0.03), Vector3(0.0, 0.0, 0.01))
	health_bar_fill.material_override.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	health_bar_root.add_child(health_bar_fill)

	health_bar_label = Label3D.new()
	health_bar_label.name = "HealthBarLabel"
	health_bar_label.font = load("res://assets/fonts/NotoSansSC-VF.ttf") as Font
	health_bar_label.font_size = 38
	health_bar_label.outline_size = 8
	health_bar_label.modulate = Color("#f4fff2")
	health_bar_label.outline_modulate = Color(0.0, 0.05, 0.03, 0.95)
	health_bar_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_bar_label.no_depth_test = true
	health_bar_label.pixel_size = 0.011
	health_bar_label.position = Vector3(0.0, 0.23, 0.0)
	health_bar_root.add_child(health_bar_label)

	_update_health_bar()


func _update_health_bar() -> void:
	if health_bar_fill == null:
		return
	var ratio := clampf(health / max_health, 0.0, 1.0)
	health_bar_fill.scale.x = maxf(ratio, 0.02)
	health_bar_fill.position.x = -HEALTH_BAR_WIDTH * (1.0 - maxf(ratio, 0.02)) * 0.5
	var mat := health_bar_fill.material_override as StandardMaterial3D
	if mat != null:
		mat.albedo_color = _health_bar_color(ratio)
	if health_bar_label != null:
		health_bar_label.text = "Lv.%d %s  %d/%d" % [level, str(data["name"]), maxi(ceili(health), 0), ceili(max_health)]


func _health_bar_color(ratio: float) -> Color:
	var green := Color("#68c94f")
	var yellow := Color("#e8c34a")
	var red := Color("#d84d4d")
	if ratio >= 0.5:
		return yellow.lerp(green, (ratio - 0.5) * 2.0)
	return red.lerp(yellow, ratio * 2.0)


func is_stealthed() -> bool:
	return not dead and (hidden_timer > 0.0 or is_cover_concealed() or (Catalog.has_trait(species_id, "ambusher") and still_timer > 1.5))


func is_cover_concealed() -> bool:
	return not dead and not _collapse_competition_active() and cover_strength >= COVER_CONCEAL_THRESHOLD and cover_reveal_timer <= 0.0 and cover_ambush_timer > 0.0 and scent_mark_timer <= 0.0 and not wants_sprint


func has_cover_ambush() -> bool:
	return not dead and not _collapse_competition_active() and cover_ambush_timer > 0.0 and cover_reveal_timer <= 0.0 and scent_mark_timer <= 0.0


func tactical_cover_status_text() -> String:
	if has_cover_ambush():
		return "伏击就绪"
	if cover_strength >= COVER_CONCEAL_THRESHOLD and cover_reveal_timer <= 0.0:
		return "草丛掩护 · 停下蓄势"
	return ""


func has_terrain_momentum() -> bool:
	return not dead and not _collapse_competition_active() and terrain_counter_cooldown <= 0.0 and terrain_momentum >= TERRAIN_MOMENTUM_REQUIRED and environment_affinity >= TERRAIN_AFFINITY_THRESHOLD


func can_terrain_counter(target: EcoActor) -> bool:
	if not has_terrain_momentum() or not is_instance_valid(target) or target.dead or opportunity_strike_timer > 0.0 or game == null or game.world == null:
		return false
	if Catalog.opportunity_threat_gap(species_id, target.species_id) <= 0:
		return false
	if not game.world.has_method("terrain_counter_strength"):
		return false
	return game.world.terrain_counter_strength(species_id, global_position, target.species_id, target.global_position) >= TERRAIN_AFFINITY_THRESHOLD


func tactical_terrain_status_text() -> String:
	if environment_affinity < TERRAIN_AFFINITY_THRESHOLD or _collapse_competition_active():
		return ""
	var counter_name := "地形反制"
	if game != null and game.world != null and game.world.has_method("terrain_counter_name"):
		counter_name = game.world.terrain_counter_name(environment_region_id)
	if has_terrain_momentum():
		return "%s就绪 · 可反制客场强敌" % counter_name
	if terrain_counter_cooldown > 0.0:
		return "%s冷却 %.1fs" % [counter_name, terrain_counter_cooldown]
	if terrain_momentum > 0.0:
		return "%s蓄势 %d%%" % [counter_name, roundi(terrain_momentum / TERRAIN_MOMENTUM_REQUIRED * 100.0)]
	return "主场适应 · 持续移动可蓄势"


func environment_region_status_text() -> String:
	if environment_affinity >= 0.99:
		return "主场适应"
	if environment_affinity >= TERRAIN_AFFINITY_THRESHOLD:
		return "熟悉地形"
	return "客场环境"


func ecology_leverage_candidate(threat: EcoActor, max_distance: float = ECOLOGY_LEVERAGE_RADIUS) -> EcoActor:
	if dead or game == null or ecology_leverage_cooldown > 0.0 or _collapse_competition_active() or not is_instance_valid(threat) or threat.dead:
		return null
	if Catalog.opportunity_threat_gap(species_id, threat.species_id) <= 0:
		return null
	if threat.is_airborne():
		return null
	var threat_presence := _ecology_combat_presence(threat)
	var best: EcoActor
	var best_score := -INF
	for candidate in game.get_living_actors():
		if candidate == self or candidate == threat or candidate.dead or candidate.is_player or candidate.spawn_protection > 0.0:
			continue
		if candidate.species_id == threat.species_id or candidate.is_airborne():
			continue
		if candidate.ai_target == self or (candidate.ai_state in ["hunt", "flee"] and candidate.ai_target != threat and candidate.state_commit_timer > 0.0):
			continue
		var candidate_distance := global_position.distance_to(candidate.global_position)
		if candidate_distance > max_distance or threat.global_position.distance_to(candidate.global_position) > max_distance + 3.0:
			continue
		if candidate.health / candidate.max_health < 0.42 or candidate.stamina / candidate.max_stamina < 0.24:
			continue
		var candidate_presence := _ecology_combat_presence(candidate)
		if candidate_presence < threat_presence * 0.72:
			continue
		var willing_to_intervene := float(candidate.data["aggression"]) >= 0.48 or Catalog.has_trait(candidate.species_id, "territorial") or Catalog.has_trait(candidate.species_id, "brave_vs_large") or int(candidate.data["size"]) >= int(threat.data["size"])
		if not willing_to_intervene:
			continue
		var score := candidate_presence * 0.72 - candidate_distance * 0.12
		if Catalog.has_trait(candidate.species_id, "territorial"):
			score += 0.70
		if Catalog.considers_prey(candidate.species_id, threat.species_id):
			score += 0.38
		score -= float(candidate.actor_id) * 0.0001
		if score > best_score:
			best_score = score
			best = candidate
	return best


func can_ecology_leverage(threat: EcoActor) -> bool:
	return is_instance_valid(ecology_leverage_candidate(threat))


func ecology_leverage_status_text(threat: EcoActor = null) -> String:
	var active_threat := threat if is_instance_valid(threat) else _active_stronger_pursuer()
	if not is_instance_valid(active_threat):
		return ""
	if ecology_leverage_cooldown > 0.0:
		return "生态借力冷却 %.1fs" % ecology_leverage_cooldown
	var responder := ecology_leverage_candidate(active_threat)
	if not is_instance_valid(responder):
		return ""
	return "生态借力就绪 · 引向%s" % Catalog.display_name(responder.species_id)


func _active_stronger_pursuer() -> EcoActor:
	if is_instance_valid(last_attacker) and not last_attacker.dead and global_position.distance_to(last_attacker.global_position) <= 22.0 and Catalog.opportunity_threat_gap(species_id, last_attacker.species_id) > 0:
		return last_attacker
	var closest: EcoActor
	var closest_distance := INF
	for other in game.get_living_actors():
		if other == self or other.dead or other.ai_state != "hunt" or other.ai_target != self:
			continue
		if Catalog.opportunity_threat_gap(species_id, other.species_id) <= 0:
			continue
		var distance := global_position.distance_to(other.global_position)
		if distance < closest_distance:
			closest = other
			closest_distance = distance
	return closest


func _ecology_combat_presence(actor: EcoActor) -> float:
	if not is_instance_valid(actor):
		return 0.0
	return float(Catalog.combat_tier(actor.species_id)) + float(int(actor.data["size"])) * 0.42 + actor.health / actor.max_health * 0.75 + actor.stamina / actor.max_stamina * 0.28


func _build_rabbit() -> void:
	var color := Catalog.get_color(species_id).lerp(Color("#c9d0ca"), 0.16)
	var accent := Color.from_string(str(data["accent"]), Color.PINK)
	var body_centers := [
		Vector3(0.0, 0.84, 1.06), Vector3(0.0, 0.82, 0.62),
		Vector3(0.0, 0.82, -0.02), Vector3(0.0, 0.91, -0.61),
		Vector3(0.0, 1.22, -0.91), Vector3(0.0, 1.47, -1.21),
		Vector3(0.0, 1.39, -1.56)
	]
	var body_radii := [
		Vector2(0.33, 0.35), Vector2(0.62, 0.52), Vector2(0.61, 0.51),
		Vector2(0.48, 0.47), Vector2(0.38, 0.40), Vector2(0.45, 0.40),
		Vector2(0.23, 0.20)
	]
	body_root.add_child(Factory.loft("RabbitBody", color, body_centers, body_radii, 9))
	body_root.add_child(Factory.sphere("ChestFluff", Color("#eef0e8"), Vector3(0.58, 0.63, 0.22), Vector3(0.0, 0.91, -0.88), 8, 5))
	for side in [-1.0, 1.0]:
		var ear_centers := [
			Vector3(side * 0.25, 1.69, -1.12),
			Vector3(side * 0.31, 2.10, -1.09),
			Vector3(side * 0.37, 2.55, -1.02)
		]
		body_root.add_child(Factory.loft("Ear", color.darkened(0.025), ear_centers, [Vector2(0.19, 0.16), Vector2(0.20, 0.14), Vector2(0.035, 0.035)], 7))
		var inner_centers := [
			Vector3(side * 0.25, 1.79, -1.255),
			Vector3(side * 0.31, 2.10, -1.245),
			Vector3(side * 0.355, 2.41, -1.19)
		]
		body_root.add_child(Factory.loft("InnerEar", accent.lerp(Color.WHITE, 0.28), inner_centers, [Vector2(0.075, 0.045), Vector2(0.09, 0.035), Vector2(0.02, 0.015)], 6))
	_add_eye_pair(1.57, -1.51, 0.20, 0.105)
	body_root.add_child(Factory.sphere("Nose", Color("#664b50"), Vector3(0.17, 0.13, 0.12), Vector3(0.0, 1.38, -1.70), 7, 4))
	body_root.add_child(Factory.sphere("Tail", Color("#f8f4e8"), Vector3(0.50, 0.50, 0.50), Vector3(0.0, 1.01, 1.22), 9, 5))
	_add_legs(color.darkened(0.08), 0.36, 0.58, 0.46, 0.43, Color("#dedfd5"))


func _build_canine(is_fox: bool) -> void:
	var color := Catalog.get_color(species_id)
	var accent := Color.from_string(str(data["accent"]), Color.WHITE)
	var scale_factor := 0.88 if is_fox else 1.04
	body_root.scale = Vector3.ONE * scale_factor
	var back_color := color.darkened(0.10 if is_fox else 0.08)
	var body_centers := [
		Vector3(0.0, 1.01, 1.03), Vector3(0.0, 1.00, 0.55),
		Vector3(0.0, 1.02, -0.12), Vector3(0.0, 1.15, -0.74),
		Vector3(0.0, 1.48, -1.08), Vector3(0.0, 1.71, -1.38),
		Vector3(0.0, 1.56, -1.75), Vector3(0.0, 1.47, -2.11)
	]
	var body_radii := [
		Vector2(0.37, 0.35), Vector2(0.56, 0.43), Vector2(0.57, 0.44),
		Vector2(0.49, 0.52), Vector2(0.38, 0.40), Vector2(0.44, 0.38),
		Vector2(0.29, 0.23), Vector2(0.15, 0.13)
	]
	body_root.add_child(Factory.loft("CanineBody", color, body_centers, body_radii, 9))
	body_root.add_child(Factory.sphere("ChestBib", accent.lerp(color, 0.22), Vector3(0.57, 0.71, 0.22), Vector3(0.0, 1.07, -1.05), 8, 5))
	body_root.add_child(Factory.sphere("Cheeks", accent.lerp(color, 0.20), Vector3(0.59, 0.38, 0.31), Vector3(0.0, 1.53, -1.68), 8, 5))
	for side in [-1.0, 1.0]:
		var ear := Factory.cone("Ear", back_color, 0.29, 0.68, Vector3(side * 0.39, 2.18, -1.19), 7)
		ear.rotation.z = side * 0.12
		body_root.add_child(ear)
		var inner := Factory.cone("InnerEar", accent.darkened(0.18), 0.13, 0.40, Vector3(side * 0.39, 2.15, -1.38), 6)
		inner.rotation.z = side * 0.12
		body_root.add_child(inner)
	_add_eye_pair(1.79, -1.73, 0.21, 0.10)
	body_root.add_child(Factory.sphere("Nose", Color("#202522"), Vector3(0.20, 0.15, 0.17), Vector3(0.0, 1.43, -2.25), 8, 4))
	var tail_centers := [
		Vector3(0.0, 1.08, 0.92), Vector3(0.04, 1.22, 1.48),
		Vector3(0.12, 1.53 if is_fox else 1.22, 2.06), Vector3(0.10, 1.79 if is_fox else 1.28, 2.52)
	]
	var tail_radii := [
		Vector2(0.25, 0.24), Vector2(0.38 if is_fox else 0.31, 0.35 if is_fox else 0.29),
		Vector2(0.32 if is_fox else 0.25, 0.30 if is_fox else 0.23), Vector2(0.16, 0.15)
	]
	body_root.add_child(Factory.loft("Tail", back_color, tail_centers, tail_radii, 8))
	if is_fox:
		body_root.add_child(Factory.loft("TailTip", accent, [Vector3(0.12, 1.53, 2.06), Vector3(0.10, 1.79, 2.52), Vector3(0.08, 1.91, 2.76)], [Vector2(0.323, 0.303), Vector2(0.16, 0.15), Vector2(0.025, 0.025)], 8))
	_add_legs(back_color, 0.40, 0.82, 0.46, 0.70, Color("#302c29") if is_fox else Color("#495157"))


func _build_deer() -> void:
	var color := Catalog.get_color(species_id)
	var accent := Color.from_string(str(data["accent"]), Color.BEIGE)
	body_root.scale = Vector3.ONE * 1.08
	var body_centers := [
		Vector3(0.0, 1.38, 1.10), Vector3(0.0, 1.38, 0.62),
		Vector3(0.0, 1.40, -0.13), Vector3(0.0, 1.48, -0.73),
		Vector3(0.0, 1.83, -0.96), Vector3(0.0, 2.28, -1.16),
		Vector3(0.0, 2.73, -1.47), Vector3(0.0, 2.61, -1.93),
		Vector3(0.0, 2.57, -2.24)
	]
	var body_radii := [
		Vector2(0.31, 0.33), Vector2(0.55, 0.45), Vector2(0.58, 0.47),
		Vector2(0.50, 0.53), Vector2(0.37, 0.40), Vector2(0.29, 0.34),
		Vector2(0.34, 0.31), Vector2(0.25, 0.20), Vector2(0.14, 0.11)
	]
	body_root.add_child(Factory.loft("DeerBody", color, body_centers, body_radii, 9))
	body_root.add_child(Factory.sphere("ThroatPatch", accent.darkened(0.06), Vector3(0.37, 0.68, 0.17), Vector3(0.0, 2.04, -1.31), 8, 5))
	for side in [-1.0, 1.0]:
		body_root.add_child(Factory.loft("Ear", color, [Vector3(side * 0.24, 2.94, -1.43), Vector3(side * 0.52, 3.16, -1.32), Vector3(side * 0.74, 3.21, -1.25)], [Vector2(0.16, 0.12), Vector2(0.19, 0.12), Vector2(0.025, 0.025)], 7))
		var antler := Factory.tapered_cylinder("Antler", Color("#66513c"), 0.070, 0.040, 0.92, Vector3(side * 0.28, 3.51, -1.30), 6)
		antler.rotation.z = side * -0.22
		body_root.add_child(antler)
		var branch := Factory.tapered_cylinder("AntlerBranch", Color("#66513c"), 0.055, 0.025, 0.48, Vector3(side * 0.42, 3.66, -1.42), 6)
		branch.rotation.z = side * -0.92
		body_root.add_child(branch)
	_add_eye_pair(2.86, -1.91, 0.17, 0.09)
	body_root.add_child(Factory.sphere("Nose", Color("#29251f"), Vector3(0.18, 0.12, 0.14), Vector3(0.0, 2.56, -2.42), 7, 4))
	for side in [-1.0, 1.0]:
		for spot_index in range(3):
			body_root.add_child(Factory.sphere("CoatSpot", accent.lightened(0.16), Vector3(0.11, 0.065, 0.14), Vector3(side * 0.43, 1.57, -0.15 + spot_index * 0.48), 6, 3))
	_add_legs(color.darkened(0.15), 0.23, 1.40, 0.50, 0.90, Color("#302820"))
	body_root.add_child(Factory.sphere("Tail", accent, Vector3(0.32, 0.28, 0.48), Vector3(0.0, 1.57, 1.38), 8, 5))


func _build_snake() -> void:
	var color := Catalog.get_color(species_id)
	var accent := Color.from_string(str(data["accent"]), Color.YELLOW)
	var body_centers: Array = []
	var body_radii: Array = []
	for i in range(14):
		var t := float(i) / 13.0
		body_centers.append(Vector3(sin(float(i) * 0.78) * (0.34 + t * 0.10), 0.28 + t * 0.15, 3.25 - t * 4.20))
		var radius := lerpf(0.07, 0.31, t)
		body_radii.append(Vector2(radius, radius * 0.72))
	body_centers.append(Vector3(0.0, 0.64, -1.35))
	body_radii.append(Vector2(0.42, 0.29))
	body_centers.append(Vector3(0.0, 0.65, -1.77))
	body_radii.append(Vector2(0.29, 0.19))
	body_centers.append(Vector3(0.0, 0.63, -2.02))
	body_radii.append(Vector2(0.15, 0.11))
	body_root.add_child(Factory.loft("SnakeBody", color.darkened(0.16), body_centers, body_radii, 9))
	for mark_index in [3, 6, 9, 12]:
		var center: Vector3 = body_centers[mark_index]
		body_root.add_child(Factory.sphere("BackMark", accent.darkened(0.06), Vector3(0.24, 0.075, 0.27), center + Vector3(0.0, float(body_radii[mark_index].y) * 0.76, 0.0), 6, 3))
	_add_eye_pair(0.75, -1.78, 0.18, 0.095)
	var tongue_color := Color("#d94f69")
	body_root.add_child(Factory.loft("Tongue", tongue_color, [Vector3(0.0, 0.64, -2.01), Vector3(0.0, 0.64, -2.32)], [Vector2(0.026, 0.026), Vector2(0.020, 0.020)], 5))
	body_root.add_child(Factory.loft("TongueFork", tongue_color, [Vector3(0.0, 0.64, -2.30), Vector3(-0.09, 0.64, -2.50)], [Vector2(0.018, 0.018), Vector2(0.006, 0.006)], 5))
	body_root.add_child(Factory.loft("TongueFork", tongue_color, [Vector3(0.0, 0.64, -2.30), Vector3(0.09, 0.64, -2.50)], [Vector2(0.018, 0.018), Vector2(0.006, 0.006)], 5))


func _build_bear() -> void:
	var color := Catalog.get_color(species_id)
	var accent := Color.from_string(str(data["accent"]), Color("#a47b59"))
	body_root.scale = Vector3.ONE * 1.22
	var body_centers := [
		Vector3(0.0, 1.23, 1.10), Vector3(0.0, 1.25, 0.60),
		Vector3(0.0, 1.29, -0.08), Vector3(0.0, 1.45, -0.72),
		Vector3(0.0, 1.75, -1.07), Vector3(0.0, 2.08, -1.42),
		Vector3(0.0, 1.92, -1.83), Vector3(0.0, 1.89, -2.16)
	]
	var body_radii := [
		Vector2(0.48, 0.48), Vector2(0.72, 0.66), Vector2(0.73, 0.67),
		Vector2(0.68, 0.74), Vector2(0.53, 0.55), Vector2(0.52, 0.47),
		Vector2(0.34, 0.26), Vector2(0.17, 0.14)
	]
	body_root.add_child(Factory.loft("BearBody", color, body_centers, body_radii, 10))
	body_root.add_child(Factory.sphere("BearShoulderMass", color.darkened(0.035), Vector3(1.62, 1.32, 1.28), Vector3(0.0, 1.42, -0.48), 10, 7))
	body_root.add_child(Factory.sphere("BearRumpMass", color.lightened(0.02), Vector3(1.48, 1.14, 1.24), Vector3(0.0, 1.25, 0.55), 9, 6))
	body_root.add_child(Factory.sphere("Chest", accent.darkened(0.12), Vector3(0.87, 0.86, 0.22), Vector3(0.0, 1.38, -1.20), 8, 5))
	body_root.add_child(Factory.sphere("Muzzle", accent, Vector3(0.59, 0.41, 0.31), Vector3(0.0, 1.92, -1.94), 9, 5))
	for side in [-1.0, 1.0]:
		body_root.add_child(Factory.sphere("Ear", color.lightened(0.05), Vector3(0.34, 0.34, 0.28), Vector3(side * 0.38, 2.47, -1.39), 8, 5))
		body_root.add_child(Factory.sphere("Brow", color.darkened(0.16), Vector3(0.22, 0.14, 0.16), Vector3(side * 0.21, 2.21, -1.77), 7, 4))
	_add_eye_pair(2.13, -1.82, 0.22, 0.09)
	body_root.add_child(Factory.sphere("Nose", Color("#241d18"), Vector3(0.25, 0.18, 0.18), Vector3(0.0, 1.94, -2.39), 8, 4))
	_add_legs(color.darkened(0.10), 0.68, 0.76, 0.72, 0.72, Color("#3e2d24"))


func _build_boar() -> void:
	var color := Catalog.get_color(species_id)
	var accent := Color.from_string(str(data["accent"]), Color.BEIGE)
	body_root.scale = Vector3.ONE * 1.06
	body_root.add_child(Factory.loft("BoarBody", color, [
		Vector3(0.0, 1.00, 1.20), Vector3(0.0, 1.03, 0.55), Vector3(0.0, 1.08, -0.15),
		Vector3(0.0, 1.28, -0.78), Vector3(0.0, 1.43, -1.25), Vector3(0.0, 1.28, -1.78),
		Vector3(0.0, 1.16, -2.18)
	], [
		Vector2(0.36, 0.36), Vector2(0.69, 0.58), Vector2(0.72, 0.60),
		Vector2(0.67, 0.68), Vector2(0.48, 0.43), Vector2(0.39, 0.30), Vector2(0.20, 0.16)
	], 9))
	for ridge_index in range(5):
		var ridge := Factory.cone("BackBristle", color.darkened(0.30), 0.16, 0.48, Vector3(0.0, 1.72, -0.55 + ridge_index * 0.38), 6)
		ridge.rotation.x = -0.10
		body_root.add_child(ridge)
	body_root.add_child(Factory.sphere("Snout", accent.darkened(0.20), Vector3(0.44, 0.30, 0.42), Vector3(0.0, 1.19, -2.12), 8, 5))
	for side in [-1.0, 1.0]:
		var tusk := Factory.cone("Tusk", accent.lightened(0.32), 0.10, 0.46, Vector3(side * 0.34, 1.09, -2.36), 7)
		tusk.rotation.x = -PI * 0.56
		tusk.rotation.z = side * 0.22
		body_root.add_child(tusk)
		var ear := Factory.cone("Ear", color.darkened(0.12), 0.22, 0.48, Vector3(side * 0.39, 1.84, -1.28), 7)
		ear.rotation.z = side * 0.52
		body_root.add_child(ear)
	_add_eye_pair(1.52, -1.63, 0.28, 0.085)
	body_root.add_child(Factory.sphere("Nose", Color("#2d2725"), Vector3(0.31, 0.17, 0.12), Vector3(0.0, 1.18, -2.52), 8, 4))
	_add_legs(color.darkened(0.18), 0.42, 0.76, 0.57, 0.72, Color("#282321"))


func _build_raccoon() -> void:
	var color := Catalog.get_color(species_id)
	var accent := Color.from_string(str(data["accent"]), Color("#d5d0bc"))
	body_root.scale = Vector3.ONE * 0.88
	body_root.add_child(Factory.loft("RaccoonBody", color, [
		Vector3(0.0, 0.88, 1.02), Vector3(0.0, 0.90, 0.48), Vector3(0.0, 0.93, -0.12),
		Vector3(0.0, 1.06, -0.64), Vector3(0.0, 1.30, -0.99), Vector3(0.0, 1.43, -1.35),
		Vector3(0.0, 1.34, -1.73), Vector3(0.0, 1.27, -2.02)
	], [
		Vector2(0.33, 0.31), Vector2(0.53, 0.42), Vector2(0.54, 0.43), Vector2(0.47, 0.49),
		Vector2(0.34, 0.35), Vector2(0.40, 0.34), Vector2(0.27, 0.20), Vector2(0.14, 0.11)
	], 9))
	body_root.add_child(Factory.sphere("FaceMask", Color("#252b2d"), Vector3(0.58, 0.25, 0.16), Vector3(0.0, 1.49, -1.70), 8, 4))
	body_root.add_child(Factory.sphere("Muzzle", accent, Vector3(0.43, 0.27, 0.28), Vector3(0.0, 1.29, -1.93), 8, 5))
	for side in [-1.0, 1.0]:
		var ear := Factory.cone("RoundEar", color.darkened(0.18), 0.22, 0.45, Vector3(side * 0.34, 1.88, -1.29), 7)
		ear.rotation.z = side * 0.20
		body_root.add_child(ear)
	_add_eye_pair(1.53, -1.86, 0.22, 0.085)
	body_root.add_child(Factory.sphere("Nose", Color("#1d2221"), Vector3(0.17, 0.12, 0.12), Vector3(0.0, 1.28, -2.20), 7, 4))
	var tail_points := [
		Vector3(0.0, 0.99, 0.96), Vector3(0.12, 1.12, 1.45), Vector3(0.28, 1.38, 1.93),
		Vector3(0.38, 1.63, 2.38), Vector3(0.31, 1.76, 2.72)
	]
	for segment in range(tail_points.size()):
		var ring_color := accent.darkened(0.10) if segment % 2 == 0 else Color("#303638")
		var segment_scale := 0.30 - float(segment) * 0.035
		body_root.add_child(Factory.sphere("TailRing", ring_color, Vector3(segment_scale, segment_scale, 0.48), tail_points[segment], 8, 5))
	_add_legs(color.darkened(0.22), 0.32, 0.70, 0.46, 0.66, Color("#25292a"))


func _build_porcupine() -> void:
	var color := Catalog.get_color(species_id)
	var accent := Color.from_string(str(data["accent"]), Color("#dfcfaa"))
	body_root.scale = Vector3.ONE * 0.96
	body_root.add_child(Factory.loft("PorcupineBody", color, [
		Vector3(0.0, 0.86, 1.13), Vector3(0.0, 1.02, 0.58), Vector3(0.0, 1.16, -0.08),
		Vector3(0.0, 1.25, -0.70), Vector3(0.0, 1.20, -1.18), Vector3(0.0, 1.03, -1.60),
		Vector3(0.0, 0.94, -1.98)
	], [
		Vector2(0.38, 0.35), Vector2(0.64, 0.57), Vector2(0.69, 0.62), Vector2(0.63, 0.61),
		Vector2(0.48, 0.44), Vector2(0.30, 0.23), Vector2(0.14, 0.10)
	], 9))
	for row in [-1.0, 0.0, 1.0]:
		for quill_index in range(6):
			var quill_z := 0.82 - float(quill_index) * 0.42
			var quill_height := 0.72 + float(quill_index % 3) * 0.12
			var quill := Factory.cone("BackQuill", accent if quill_index % 2 == 0 else Color("#332c27"), 0.085, quill_height, Vector3(row * 0.34, 1.60 + (1.0 - absf(row)) * 0.14, quill_z), 6)
			quill.rotation.x = row * 0.08
			quill.rotation.z = -row * 0.22
			body_root.add_child(quill)
	body_root.add_child(Factory.sphere("SmallFace", color.darkened(0.16), Vector3(0.42, 0.35, 0.48), Vector3(0.0, 1.02, -1.72), 8, 5))
	for side in [-1.0, 1.0]:
		body_root.add_child(Factory.sphere("Ear", color.lightened(0.05), Vector3(0.18, 0.20, 0.13), Vector3(side * 0.25, 1.38, -1.47), 7, 4))
	_add_eye_pair(1.13, -1.96, 0.19, 0.075)
	body_root.add_child(Factory.sphere("Nose", Color("#201d1b"), Vector3(0.14, 0.10, 0.10), Vector3(0.0, 0.94, -2.18), 7, 4))
	_add_legs(color.darkened(0.20), 0.34, 0.58, 0.49, 0.65, Color("#2b2521"))


func _build_capybara() -> void:
	var color := Catalog.get_color(species_id)
	var accent := Color.from_string(str(data["accent"]), Color("#d6b58a"))
	body_root.scale = Vector3.ONE * 1.04
	body_root.add_child(Factory.loft("CapybaraBody", color, [
		Vector3(0.0, 0.92, 1.18), Vector3(0.0, 1.02, 0.55), Vector3(0.0, 1.07, -0.14),
		Vector3(0.0, 1.17, -0.75), Vector3(0.0, 1.29, -1.20), Vector3(0.0, 1.24, -1.70),
		Vector3(0.0, 1.15, -2.14)
	], [
		Vector2(0.42, 0.39), Vector2(0.72, 0.59), Vector2(0.75, 0.61), Vector2(0.68, 0.63),
		Vector2(0.54, 0.47), Vector2(0.46, 0.34), Vector2(0.26, 0.18)
	], 9))
	body_root.add_child(Factory.sphere("SquareMuzzle", accent.darkened(0.12), Vector3(0.50, 0.31, 0.44), Vector3(0.0, 1.18, -1.96), 8, 5))
	for side in [-1.0, 1.0]:
		body_root.add_child(Factory.sphere("SmallEar", color.darkened(0.15), Vector3(0.18, 0.18, 0.12), Vector3(side * 0.30, 1.67, -1.41), 7, 4))
		body_root.add_child(Factory.sphere("Nostril", Color("#30241e"), Vector3(0.065, 0.045, 0.055), Vector3(side * 0.15, 1.30, -2.34), 6, 3))
	_add_eye_pair(1.48, -1.86, 0.27, 0.08)
	_add_legs(color.darkened(0.15), 0.43, 0.72, 0.61, 0.77, Color("#3e3028"))


func _build_otter() -> void:
	var color := Catalog.get_color(species_id)
	var accent := Color.from_string(str(data["accent"]), Color("#e2c79b"))
	body_root.scale = Vector3.ONE * 0.92
	body_root.add_child(Factory.loft("OtterBody", color, [
		Vector3(0.0, 0.58, 1.28), Vector3(0.0, 0.64, 0.74), Vector3(0.0, 0.70, 0.08),
		Vector3(0.0, 0.77, -0.58), Vector3(0.0, 0.95, -1.02), Vector3(0.0, 1.20, -1.36),
		Vector3(0.0, 1.15, -1.76), Vector3(0.0, 1.08, -2.04)
	], [
		Vector2(0.25, 0.22), Vector2(0.48, 0.34), Vector2(0.53, 0.37), Vector2(0.45, 0.43),
		Vector2(0.32, 0.35), Vector2(0.38, 0.32), Vector2(0.27, 0.20), Vector2(0.13, 0.10)
	], 9))
	body_root.add_child(Factory.sphere("CreamThroat", accent, Vector3(0.48, 0.52, 0.19), Vector3(0.0, 0.83, -1.12), 8, 5))
	body_root.add_child(Factory.sphere("OtterMuzzle", accent.lightened(0.06), Vector3(0.43, 0.25, 0.28), Vector3(0.0, 1.10, -1.88), 8, 5))
	for side in [-1.0, 1.0]:
		body_root.add_child(Factory.sphere("RoundEar", color.darkened(0.08), Vector3(0.19, 0.19, 0.13), Vector3(side * 0.30, 1.54, -1.34), 7, 4))
		for whisker_index in range(2):
			var whisker := Factory.tapered_cylinder("Whisker", accent.lightened(0.20), 0.018, 0.006, 0.58, Vector3(side * (0.39 + whisker_index * 0.03), 1.10 + whisker_index * 0.10, -2.02), 5)
			whisker.rotation.z = side * (PI * 0.50 - 0.12 + whisker_index * 0.10)
			body_root.add_child(whisker)
	_add_eye_pair(1.34, -1.70, 0.22, 0.085)
	body_root.add_child(Factory.sphere("OtterNose", Color("#22211f"), Vector3(0.18, 0.12, 0.12), Vector3(0.0, 1.10, -2.20), 7, 4))
	body_root.add_child(Factory.loft("RudderTail", color.darkened(0.10), [
		Vector3(0.0, 0.65, 1.18), Vector3(0.08, 0.61, 1.78), Vector3(0.16, 0.56, 2.48), Vector3(0.12, 0.48, 3.16)
	], [Vector2(0.24, 0.18), Vector2(0.22, 0.15), Vector2(0.14, 0.10), Vector2(0.035, 0.025)], 8))
	_add_legs(color.darkened(0.12), 0.30, 0.48, 0.45, 0.64, accent.darkened(0.16))


func _build_turtle() -> void:
	var color := Catalog.get_color(species_id)
	var shell_color := Color.from_string(str(data["accent"]), Color("#b6a76b"))
	body_root.scale = Vector3.ONE * 0.96
	body_root.add_child(Factory.sphere("StoneShell", shell_color.darkened(0.16), Vector3(1.42, 0.66, 1.72), Vector3(0.0, 0.78, 0.05), 10, 6))
	body_root.add_child(Factory.sphere("ShellCrown", shell_color, Vector3(1.18, 0.54, 1.46), Vector3(0.0, 1.02, 0.00), 9, 5))
	for plate_index in range(7):
		var angle := TAU * float(plate_index) / 7.0
		body_root.add_child(Factory.sphere("ShellPlate", shell_color.darkened(0.08 if plate_index % 2 == 0 else 0.20), Vector3(0.28, 0.08, 0.35), Vector3(cos(angle) * 0.68, 1.28 - absf(sin(angle)) * 0.10, sin(angle) * 0.90), 7, 3))
	body_root.add_child(Factory.loft("TurtleNeck", color, [
		Vector3(0.0, 0.70, -0.82), Vector3(0.0, 0.72, -1.22), Vector3(0.0, 0.82, -1.55), Vector3(0.0, 0.82, -1.86)
	], [Vector2(0.27, 0.24), Vector2(0.25, 0.22), Vector2(0.32, 0.28), Vector2(0.18, 0.13)], 8))
	_add_eye_pair(0.96, -1.72, 0.19, 0.075)
	body_root.add_child(Factory.sphere("Beak", shell_color.lightened(0.12), Vector3(0.19, 0.11, 0.15), Vector3(0.0, 0.81, -2.01), 7, 4))
	_add_legs(color.darkened(0.08), 0.38, 0.42, 0.88, 0.88, shell_color.darkened(0.28))
	var short_tail := Factory.cone("ShortTail", color.darkened(0.12), 0.17, 0.50, Vector3(0.0, 0.62, 1.66), 7)
	short_tail.rotation.x = PI * 0.50
	body_root.add_child(short_tail)


func _build_goat() -> void:
	var color := Catalog.get_color(species_id)
	var accent := Color.from_string(str(data["accent"]), Color("#5b4a38"))
	body_root.scale = Vector3.ONE * 1.05
	body_root.add_child(Factory.loft("GoatBody", color, [
		Vector3(0.0, 1.18, 1.06), Vector3(0.0, 1.22, 0.48), Vector3(0.0, 1.25, -0.16),
		Vector3(0.0, 1.38, -0.70), Vector3(0.0, 1.72, -1.02), Vector3(0.0, 2.06, -1.30),
		Vector3(0.0, 2.18, -1.72), Vector3(0.0, 2.08, -2.05)
	], [
		Vector2(0.33, 0.34), Vector2(0.55, 0.44), Vector2(0.56, 0.45), Vector2(0.48, 0.50),
		Vector2(0.34, 0.36), Vector2(0.36, 0.33), Vector2(0.25, 0.19), Vector2(0.13, 0.10)
	], 9))
	for side in [-1.0, 1.0]:
		var horn_base := Factory.tapered_cylinder("CurvedHorn", accent, 0.11, 0.065, 0.82, Vector3(side * 0.25, 2.69, -1.45), 7)
		horn_base.rotation.z = side * -0.42
		horn_base.rotation.x = 0.18
		body_root.add_child(horn_base)
		var horn_tip := Factory.cone("HornTip", accent.darkened(0.10), 0.075, 0.55, Vector3(side * 0.43, 2.95, -1.22), 7)
		horn_tip.rotation.z = side * 0.28
		horn_tip.rotation.x = 0.30
		body_root.add_child(horn_tip)
		var ear := Factory.cone("GoatEar", color.darkened(0.08), 0.18, 0.42, Vector3(side * 0.40, 2.40, -1.55), 7)
		ear.rotation.z = side * 1.05
		body_root.add_child(ear)
	body_root.add_child(Factory.cone("Beard", accent.darkened(0.18), 0.16, 0.58, Vector3(0.0, 1.72, -1.93), 7))
	_add_eye_pair(2.28, -1.86, 0.22, 0.085)
	body_root.add_child(Factory.sphere("Nose", Color("#3b342d"), Vector3(0.19, 0.12, 0.14), Vector3(0.0, 2.05, -2.25), 7, 4))
	_add_legs(color.darkened(0.16), 0.25, 1.18, 0.50, 0.78, Color("#302a24"))


func _build_wolverine() -> void:
	var color := Catalog.get_color(species_id)
	var accent := Color.from_string(str(data["accent"]), Color("#c19a62"))
	body_root.scale = Vector3.ONE * 0.94
	body_root.add_child(Factory.loft("WolverineBody", color, [
		Vector3(0.0, 0.82, 1.35), Vector3(0.0, 0.90, 0.72), Vector3(0.0, 0.96, -0.06),
		Vector3(0.0, 1.05, -0.73), Vector3(0.0, 1.22, -1.17), Vector3(0.0, 1.35, -1.55),
		Vector3(0.0, 1.27, -1.95)
	], [
		Vector2(0.34, 0.33), Vector2(0.62, 0.49), Vector2(0.65, 0.52), Vector2(0.58, 0.56),
		Vector2(0.42, 0.40), Vector2(0.42, 0.34), Vector2(0.19, 0.14)
	], 9))
	for side in [-1.0, 1.0]:
		body_root.add_child(Factory.sphere("SideBand", accent, Vector3(0.14, 0.39, 1.18), Vector3(side * 0.58, 1.09, 0.05), 7, 5))
		body_root.add_child(Factory.sphere("Ear", color.lightened(0.10), Vector3(0.20, 0.20, 0.15), Vector3(side * 0.30, 1.72, -1.42), 7, 4))
	body_root.add_child(Factory.sphere("Muzzle", accent.darkened(0.16), Vector3(0.43, 0.28, 0.32), Vector3(0.0, 1.31, -1.92), 8, 5))
	_add_eye_pair(1.48, -1.80, 0.22, 0.08)
	body_root.add_child(Factory.sphere("Nose", Color("#191817"), Vector3(0.18, 0.12, 0.13), Vector3(0.0, 1.27, -2.23), 7, 4))
	body_root.add_child(Factory.loft("BushTail", color.darkened(0.18), [Vector3(0.0, 0.91, 1.16), Vector3(0.12, 1.08, 1.65), Vector3(0.17, 1.31, 2.05)], [Vector2(0.23, 0.22), Vector2(0.31, 0.29), Vector2(0.11, 0.10)], 8))
	_add_legs(color.darkened(0.15), 0.38, 0.62, 0.55, 0.82, Color("#211d1a"))


func _build_zebra() -> void:
	var color := Catalog.get_color(species_id)
	var accent := Color.from_string(str(data["accent"]), Color("#25282a"))
	body_root.scale = Vector3.ONE * 1.08
	body_root.add_child(Factory.loft("ZebraBody", color, [
		Vector3(0.0, 1.40, 1.15), Vector3(0.0, 1.43, 0.58), Vector3(0.0, 1.45, -0.12),
		Vector3(0.0, 1.55, -0.73), Vector3(0.0, 1.88, -1.02), Vector3(0.0, 2.33, -1.22),
		Vector3(0.0, 2.64, -1.56), Vector3(0.0, 2.54, -2.00), Vector3(0.0, 2.48, -2.30)
	], [
		Vector2(0.32, 0.34), Vector2(0.58, 0.46), Vector2(0.60, 0.48), Vector2(0.52, 0.54),
		Vector2(0.36, 0.39), Vector2(0.29, 0.34), Vector2(0.35, 0.31), Vector2(0.24, 0.18), Vector2(0.13, 0.10)
	], 9))
	for stripe_index in range(7):
		var stripe_z := 0.90 - float(stripe_index) * 0.34
		body_root.add_child(Factory.sphere("BodyStripe", accent, Vector3(0.59, 0.055, 0.11), Vector3(0.0, 1.69, stripe_z), 7, 3))
	for mane_index in range(6):
		var mane := Factory.cone("Mane", accent, 0.10, 0.38, Vector3(0.0, 2.26 + float(mane_index) * 0.10, -0.86 - float(mane_index) * 0.18), 6)
		mane.rotation.x = -0.12
		body_root.add_child(mane)
	for side in [-1.0, 1.0]:
		var ear := Factory.cone("ZebraEar", color, 0.17, 0.55, Vector3(side * 0.28, 3.08, -1.52), 7)
		ear.rotation.z = side * 0.16
		body_root.add_child(ear)
	_add_eye_pair(2.72, -1.91, 0.18, 0.085)
	body_root.add_child(Factory.sphere("DarkMuzzle", accent, Vector3(0.32, 0.19, 0.40), Vector3(0.0, 2.48, -2.18), 8, 5))
	_add_legs(color.darkened(0.05), 0.23, 1.38, 0.51, 0.90, accent)
	body_root.add_child(Factory.loft("ZebraTail", accent, [Vector3(0.0, 1.52, 1.26), Vector3(0.04, 1.23, 1.68), Vector3(0.10, 0.92, 1.98)], [Vector2(0.11, 0.11), Vector2(0.12, 0.11), Vector2(0.24, 0.22)], 7))


func _build_hyena() -> void:
	var color := Catalog.get_color(species_id)
	var accent := Color.from_string(str(data["accent"]), Color("#3f3328"))
	body_root.scale = Vector3.ONE * 1.02
	body_root.add_child(Factory.loft("HyenaBody", color, [
		Vector3(0.0, 0.92, 1.18), Vector3(0.0, 1.04, 0.58), Vector3(0.0, 1.20, -0.10),
		Vector3(0.0, 1.42, -0.70), Vector3(0.0, 1.61, -1.12), Vector3(0.0, 1.67, -1.52),
		Vector3(0.0, 1.52, -1.96), Vector3(0.0, 1.40, -2.24)
	], [
		Vector2(0.33, 0.32), Vector2(0.55, 0.43), Vector2(0.58, 0.47), Vector2(0.54, 0.56),
		Vector2(0.39, 0.40), Vector2(0.43, 0.35), Vector2(0.28, 0.20), Vector2(0.15, 0.11)
	], 9))
	for mane_index in range(6):
		var mane := Factory.cone("BackMane", accent, 0.11, 0.42, Vector3(0.0, 1.92, -0.88 + float(mane_index) * 0.28), 6)
		body_root.add_child(mane)
	for side in [-1.0, 1.0]:
		body_root.add_child(Factory.sphere("LargeEar", accent.darkened(0.05), Vector3(0.27, 0.34, 0.17), Vector3(side * 0.34, 2.12, -1.43), 8, 5))
		for spot_index in range(4):
			body_root.add_child(Factory.sphere("CoatSpot", accent, Vector3(0.09, 0.07, 0.12), Vector3(side * 0.51, 1.44, -0.40 + float(spot_index) * 0.42), 6, 3))
	_add_eye_pair(1.72, -1.93, 0.23, 0.085)
	body_root.add_child(Factory.sphere("Muzzle", accent.darkened(0.10), Vector3(0.38, 0.25, 0.41), Vector3(0.0, 1.43, -2.12), 8, 5))
	body_root.add_child(Factory.sphere("Nose", Color("#1d1b18"), Vector3(0.18, 0.12, 0.13), Vector3(0.0, 1.39, -2.48), 7, 4))
	body_root.add_child(Factory.loft("HyenaTail", accent, [Vector3(0.0, 0.98, 1.10), Vector3(0.10, 1.08, 1.55), Vector3(0.15, 1.18, 1.93)], [Vector2(0.18, 0.17), Vector2(0.24, 0.22), Vector2(0.08, 0.07)], 8))
	_add_legs(color.darkened(0.15), 0.34, 0.92, 0.52, 0.74, accent.darkened(0.18))


func _build_monkey() -> void:
	var color := Catalog.get_color(species_id)
	var accent := Color.from_string(str(data["accent"]), Color("#d0a07e"))
	body_root.scale = Vector3.ONE * 0.90
	body_root.add_child(Factory.sphere("MonkeyTorso", color, Vector3(0.88, 1.25, 0.66), Vector3(0.0, 1.30, 0.0), 9, 6))
	body_root.add_child(Factory.sphere("LightChest", accent.darkened(0.10), Vector3(0.62, 0.72, 0.18), Vector3(0.0, 1.35, -0.53), 8, 5))
	body_root.add_child(Factory.sphere("MonkeyHead", color.darkened(0.08), Vector3(0.62, 0.65, 0.56), Vector3(0.0, 2.27, -0.28), 9, 6))
	body_root.add_child(Factory.sphere("Face", accent, Vector3(0.47, 0.42, 0.24), Vector3(0.0, 2.18, -0.71), 8, 5))
	for side in [-1.0, 1.0]:
		body_root.add_child(Factory.sphere("RoundEar", accent.darkened(0.18), Vector3(0.24, 0.28, 0.14), Vector3(side * 0.52, 2.33, -0.25), 7, 4))
	_add_eye_pair(2.39, -0.82, 0.20, 0.075)
	body_root.add_child(Factory.sphere("Nose", Color("#392b25"), Vector3(0.16, 0.11, 0.10), Vector3(0.0, 2.13, -0.91), 7, 4))
	_add_primate_limbs(color.darkened(0.10), 1.38, 0.82, 0.55, 0.30, false)
	body_root.add_child(Factory.loft("LongTail", color.darkened(0.16), [
		Vector3(0.0, 1.00, 0.48), Vector3(0.20, 1.05, 1.15), Vector3(0.48, 1.35, 1.76),
		Vector3(0.58, 1.82, 2.22), Vector3(0.34, 2.20, 2.45)
	], [Vector2(0.13, 0.13), Vector2(0.15, 0.14), Vector2(0.12, 0.11), Vector2(0.085, 0.08), Vector2(0.04, 0.04)], 7))


func _build_gorilla() -> void:
	var color := Catalog.get_color(species_id)
	var accent := Color.from_string(str(data["accent"]), Color("#aeb4b2"))
	body_root.scale = Vector3.ONE * 1.24
	body_root.add_child(Factory.sphere("GorillaTorso", color, Vector3(1.18, 1.48, 0.86), Vector3(0.0, 1.48, 0.10), 10, 6))
	body_root.add_child(Factory.sphere("ShoulderMass", color.darkened(0.06), Vector3(1.46, 0.74, 0.78), Vector3(0.0, 2.00, -0.05), 10, 6))
	body_root.add_child(Factory.sphere("SilverBack", accent, Vector3(1.04, 0.84, 0.20), Vector3(0.0, 1.84, 0.76), 9, 5))
	body_root.add_child(Factory.sphere("GorillaHead", color.darkened(0.12), Vector3(0.70, 0.72, 0.62), Vector3(0.0, 2.62, -0.42), 9, 6))
	body_root.add_child(Factory.sphere("HeavyBrow", color.darkened(0.25), Vector3(0.62, 0.20, 0.18), Vector3(0.0, 2.77, -0.88), 8, 4))
	body_root.add_child(Factory.sphere("GorillaMuzzle", Color("#625a52"), Vector3(0.52, 0.38, 0.36), Vector3(0.0, 2.45, -0.91), 9, 5))
	_add_eye_pair(2.76, -0.96, 0.23, 0.075)
	body_root.add_child(Factory.sphere("FlatNose", Color("#202323"), Vector3(0.24, 0.15, 0.12), Vector3(0.0, 2.52, -1.23), 7, 4))
	_add_primate_limbs(color.darkened(0.08), 1.72, 0.96, 0.86, 0.40, true)


func _build_bird(is_owl: bool) -> void:
	var color := Catalog.get_color(species_id)
	var accent := Color.from_string(str(data["accent"]), Color("#d5c292"))
	body_root.scale = Vector3.ONE * (0.96 if is_owl else 1.02)
	if is_owl:
		body_root.add_child(Factory.sphere("OwlBody", color, Vector3(0.72, 1.02, 0.66), Vector3(0.0, 1.25, 0.05), 9, 6))
		body_root.add_child(Factory.sphere("OwlChest", accent.darkened(0.08), Vector3(0.54, 0.72, 0.18), Vector3(0.0, 1.18, -0.58), 8, 5))
		body_root.add_child(Factory.sphere("FacialDisc", accent, Vector3(0.66, 0.62, 0.22), Vector3(0.0, 2.00, -0.46), 9, 6))
		for side in [-1.0, 1.0]:
			var ear_tuft := Factory.cone("EarTuft", color.darkened(0.20), 0.16, 0.55, Vector3(side * 0.38, 2.55, -0.37), 7)
			ear_tuft.rotation.z = side * 0.16
			body_root.add_child(ear_tuft)
			body_root.add_child(Factory.sphere("AmberEye", Color("#f1b542"), Vector3(0.13, 0.15, 0.07), Vector3(side * 0.23, 2.05, -0.68), 8, 4))
			body_root.add_child(Factory.sphere("Pupil", Color("#151511"), Vector3(0.055, 0.085, 0.035), Vector3(side * 0.23, 2.05, -0.745), 7, 4))
	else:
		body_root.add_child(Factory.loft("EagleBody", color, [
			Vector3(0.0, 1.05, 0.82), Vector3(0.0, 1.14, 0.18), Vector3(0.0, 1.30, -0.48),
			Vector3(0.0, 1.48, -0.92), Vector3(0.0, 1.50, -1.34)
		], [Vector2(0.24, 0.24), Vector2(0.48, 0.40), Vector2(0.50, 0.43), Vector2(0.37, 0.34), Vector2(0.20, 0.18)], 9))
		body_root.add_child(Factory.sphere("GoldenNape", accent, Vector3(0.46, 0.43, 0.38), Vector3(0.0, 1.62, -1.20), 9, 6))
		body_root.add_child(Factory.sphere("EagleHead", color.darkened(0.08), Vector3(0.38, 0.38, 0.34), Vector3(0.0, 1.66, -1.53), 9, 6))
		_add_eye_pair(1.75, -1.83, 0.19, 0.070)
	var beak_color := Color("#d9aa3c") if is_owl else Color("#e2b64d")
	var beak := Factory.cone("HookedBeak", beak_color, 0.16 if is_owl else 0.18, 0.52, Vector3(0.0, 1.86 if is_owl else 1.55, -0.90 if is_owl else -1.91), 7)
	beak.rotation.x = -PI * 0.50
	body_root.add_child(beak)
	for side in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.name = "WingPivot"
		wing.position = Vector3(side * 0.42, 1.38, -0.05)
		body_root.add_child(wing)
		wing.add_child(Factory.sphere("WingCover", color.darkened(0.06), Vector3(1.28, 0.12, 0.48), Vector3(side * 0.82, 0.0, 0.03), 9, 4))
		for feather_index in range(4):
			var feather_length := (0.96 if is_owl else 1.18) - feather_index * 0.08
			var feather := Factory.sphere("FlightFeather", color.darkened(0.14 + feather_index * 0.025), Vector3(feather_length, 0.075, 0.13), Vector3(side * (1.20 + feather_index * 0.18), -0.04, 0.26 + feather_index * 0.18), 8, 3)
			feather.rotation.y = side * (-0.08 - feather_index * 0.035)
			wing.add_child(feather)
		wing_pivots.append(wing)
	for tail_index in range(3):
		var tail := Factory.sphere("TailFeather", accent.darkened(0.18), Vector3(0.16, 0.08, 0.72), Vector3((tail_index - 1) * 0.18, 1.02, 1.04), 8, 3)
		tail.rotation.y = (tail_index - 1) * 0.12
		body_root.add_child(tail)
	for side in [-1.0, 1.0]:
		body_root.add_child(Factory.sphere("Talon", Color("#d3ad50"), Vector3(0.14, 0.10, 0.22), Vector3(side * 0.24, 0.53, -0.22), 7, 3))


func _build_cheetah() -> void:
	var color := Catalog.get_color(species_id)
	var dark := Color.from_string(str(data["accent"]), Color("#3b2b22"))
	body_root.scale = Vector3.ONE * 1.02
	body_root.add_child(Factory.loft("CheetahBody", color, [
		Vector3(0.0, 1.08, 1.35), Vector3(0.0, 1.12, 0.70), Vector3(0.0, 1.14, -0.05),
		Vector3(0.0, 1.22, -0.72), Vector3(0.0, 1.48, -1.18), Vector3(0.0, 1.58, -1.58),
		Vector3(0.0, 1.48, -2.00)
	], [Vector2(0.28, 0.27), Vector2(0.46, 0.34), Vector2(0.47, 0.35), Vector2(0.39, 0.37), Vector2(0.29, 0.28), Vector2(0.34, 0.28), Vector2(0.13, 0.10)], 9))
	body_root.add_child(Factory.sphere("CheetahMuzzle", Color("#ead39c"), Vector3(0.38, 0.23, 0.25), Vector3(0.0, 1.48, -2.08), 8, 5))
	for side in [-1.0, 1.0]:
		body_root.add_child(Factory.sphere("RoundEar", dark, Vector3(0.17, 0.20, 0.12), Vector3(side * 0.28, 1.96, -1.48), 7, 4))
	_add_eye_pair(1.70, -1.98, 0.18, 0.075)
	body_root.add_child(Factory.sphere("CheetahNose", Color("#201b18"), Vector3(0.15, 0.10, 0.10), Vector3(0.0, 1.46, -2.34), 7, 4))
	for side in [-1.0, 1.0]:
		var tear_mark := Factory.sphere("TearMark", dark, Vector3(0.045, 0.22, 0.035), Vector3(side * 0.17, 1.57, -2.24), 7, 3)
		tear_mark.rotation.z = side * 0.18
		body_root.add_child(tear_mark)
	for spot_index in range(12):
		var row := spot_index / 4
		var column := spot_index % 4
		var side_sign := -1.0 if column < 2 else 1.0
		body_root.add_child(Factory.sphere("CheetahSpot", dark, Vector3(0.065, 0.040, 0.085), Vector3(side_sign * (0.36 + (column % 2) * 0.06), 1.20 + row * 0.10, 0.72 - row * 0.52), 6, 3))
	body_root.add_child(Factory.loft("CheetahTail", color.darkened(0.08), [
		Vector3(0.0, 1.10, 1.26), Vector3(0.16, 1.18, 1.88), Vector3(0.42, 1.38, 2.50), Vector3(0.48, 1.58, 3.10)
	], [Vector2(0.13, 0.13), Vector2(0.14, 0.13), Vector2(0.11, 0.10), Vector2(0.06, 0.06)], 8))
	body_root.add_child(Factory.sphere("TailTip", dark, Vector3(0.15, 0.14, 0.30), Vector3(0.48, 1.58, 3.18), 7, 4))
	_add_legs(color.darkened(0.07), 0.29, 1.02, 0.43, 0.78, dark)


func _build_lion() -> void:
	var color := Catalog.get_color(species_id)
	var accent := Color.from_string(str(data["accent"]), Color("#5a3926"))
	body_root.scale = Vector3.ONE * 1.22
	body_root.add_child(Factory.loft("LionBody", color, [
		Vector3(0.0, 1.05, 1.26), Vector3(0.0, 1.08, 0.62), Vector3(0.0, 1.12, -0.10),
		Vector3(0.0, 1.27, -0.76), Vector3(0.0, 1.56, -1.13), Vector3(0.0, 1.73, -1.52),
		Vector3(0.0, 1.61, -1.97), Vector3(0.0, 1.50, -2.28)
	], [
		Vector2(0.37, 0.36), Vector2(0.62, 0.46), Vector2(0.64, 0.48), Vector2(0.57, 0.58),
		Vector2(0.42, 0.42), Vector2(0.47, 0.39), Vector2(0.30, 0.22), Vector2(0.16, 0.12)
	], 9))
	body_root.add_child(Factory.sphere("LionMane", accent, Vector3(1.10, 1.18, 0.68), Vector3(0.0, 1.72, -1.35), 10, 7))
	body_root.add_child(Factory.sphere("LionFace", color.lightened(0.06), Vector3(0.62, 0.59, 0.50), Vector3(0.0, 1.76, -1.86), 9, 6))
	body_root.add_child(Factory.sphere("LionMuzzle", Color("#ddbd83"), Vector3(0.46, 0.27, 0.28), Vector3(0.0, 1.58, -2.23), 8, 5))
	for side in [-1.0, 1.0]:
		body_root.add_child(Factory.sphere("LionEar", accent.darkened(0.10), Vector3(0.25, 0.28, 0.17), Vector3(side * 0.43, 2.43, -1.54), 7, 4))
	_add_eye_pair(1.96, -2.18, 0.24, 0.09)
	body_root.add_child(Factory.sphere("LionNose", Color("#251e1b"), Vector3(0.20, 0.14, 0.13), Vector3(0.0, 1.58, -2.49), 7, 4))
	body_root.add_child(Factory.loft("LionTail", color.darkened(0.06), [
		Vector3(0.0, 1.12, 1.17), Vector3(0.16, 1.26, 1.78), Vector3(0.35, 1.51, 2.38), Vector3(0.30, 1.76, 2.88)
	], [Vector2(0.12, 0.12), Vector2(0.13, 0.12), Vector2(0.10, 0.09), Vector2(0.055, 0.05)], 8))
	body_root.add_child(Factory.sphere("TailTuft", accent, Vector3(0.23, 0.25, 0.40), Vector3(0.30, 1.76, 3.02), 8, 5))
	_add_legs(color.darkened(0.10), 0.42, 0.94, 0.57, 0.78, accent.darkened(0.18))


func _build_feline(is_tiger: bool) -> void:
	var color := Catalog.get_color(species_id)
	var accent := Color.from_string(str(data["accent"]), Color.BEIGE)
	body_root.scale = Vector3.ONE * (1.24 if is_tiger else 0.92)
	body_root.add_child(Factory.loft("FelineBody", color, [
		Vector3(0.0, 0.96, 1.20), Vector3(0.0, 0.98, 0.60), Vector3(0.0, 1.00, -0.12),
		Vector3(0.0, 1.12, -0.76), Vector3(0.0, 1.42, -1.12), Vector3(0.0, 1.64, -1.48),
		Vector3(0.0, 1.52, -1.91), Vector3(0.0, 1.42, -2.22)
	], [
		Vector2(0.34, 0.34), Vector2(0.55, 0.41), Vector2(0.56, 0.42), Vector2(0.47, 0.49),
		Vector2(0.36, 0.36), Vector2(0.43, 0.36), Vector2(0.29, 0.22), Vector2(0.15, 0.12)
	], 9))
	body_root.add_child(Factory.sphere("Muzzle", accent, Vector3(0.48, 0.29, 0.28), Vector3(0.0, 1.47, -2.05), 8, 5))
	for side in [-1.0, 1.0]:
		if is_tiger:
			body_root.add_child(Factory.sphere("TigerEar", color.darkened(0.10), Vector3(0.27, 0.30, 0.18), Vector3(side * 0.38, 2.02, -1.42), 8, 5))
			body_root.add_child(Factory.sphere("TigerCheek", accent.lightened(0.05), Vector3(0.28, 0.35, 0.22), Vector3(side * 0.40, 1.46, -1.94), 8, 5))
		else:
			var ear := Factory.cone("TuftedEar", color.darkened(0.12), 0.24, 0.58, Vector3(side * 0.34, 2.05, -1.43), 7)
			ear.rotation.z = side * 0.16
			body_root.add_child(ear)
			var tuft := Factory.cone("EarTuft", Color("#29231e"), 0.06, 0.32, Vector3(side * 0.39, 2.37, -1.42), 6)
			tuft.rotation.z = side * 0.18
			body_root.add_child(tuft)
	_add_eye_pair(1.73, -1.91, 0.22, 0.09)
	body_root.add_child(Factory.sphere("Nose", Color("#28201f"), Vector3(0.18, 0.13, 0.12), Vector3(0.0, 1.44, -2.36), 7, 4))
	var tail_length := 2.95 if is_tiger else 1.86
	var tail_centers := [
		Vector3(0.0, 1.03, 1.10), Vector3(0.12, 1.18, 1.62),
		Vector3(0.30, 1.42, 2.14) if is_tiger else Vector3(0.20, 1.42, 1.78),
		Vector3(0.18, 1.63, tail_length)
	]
	body_root.add_child(Factory.loft("CatTail", color.darkened(0.10), tail_centers, [Vector2(0.17, 0.17), Vector2(0.18, 0.17), Vector2(0.15, 0.14), Vector2(0.07, 0.07)], 8))
	if is_tiger:
		for stripe_index in range(5):
			var stripe_z := -0.58 + stripe_index * 0.42
			for side in [-1.0, 1.0]:
				var stripe := Factory.sphere("TigerStripe", Color("#2b211b"), Vector3(0.07, 0.34 - stripe_index * 0.018, 0.13), Vector3(side * 0.56, 1.37 + (stripe_index % 2) * 0.08, stripe_z), 7, 4)
				stripe.rotation.z = side * (0.16 + stripe_index * 0.025)
				body_root.add_child(stripe)
		for tail_ring_index in range(3):
			body_root.add_child(Factory.sphere("TigerTailRing", Color("#2b211b"), Vector3(0.18, 0.17, 0.12), Vector3(0.20 + tail_ring_index * 0.04, 1.42 + tail_ring_index * 0.08, 2.12 + tail_ring_index * 0.33), 7, 4))
	else:
		body_root.add_child(Factory.sphere("ShortTailTip", Color("#28231f"), Vector3(0.16, 0.17, 0.24), Vector3(0.18, 1.63, tail_length), 7, 4))
	_add_legs(color.darkened(0.12), 0.36 if is_tiger else 0.30, 0.88 if is_tiger else 0.76, 0.48, 0.72, accent.darkened(0.22))


func _build_bison() -> void:
	var color := Catalog.get_color(species_id)
	var accent := Color.from_string(str(data["accent"]), Color("#9b7652"))
	body_root.scale = Vector3.ONE * 1.30
	body_root.add_child(Factory.loft("BisonBody", color, [
		Vector3(0.0, 1.25, 1.20), Vector3(0.0, 1.34, 0.55), Vector3(0.0, 1.52, -0.18),
		Vector3(0.0, 1.90, -0.72), Vector3(0.0, 2.10, -1.12), Vector3(0.0, 1.92, -1.58),
		Vector3(0.0, 1.69, -2.02)
	], [
		Vector2(0.45, 0.48), Vector2(0.75, 0.67), Vector2(0.82, 0.75), Vector2(0.78, 0.88),
		Vector2(0.60, 0.58), Vector2(0.46, 0.36), Vector2(0.22, 0.17)
	], 10))
	body_root.add_child(Factory.sphere("ShoulderMane", color.darkened(0.18), Vector3(0.82, 0.92, 0.52), Vector3(0.0, 1.72, -0.78), 9, 6))
	body_root.add_child(Factory.sphere("Beard", color.darkened(0.28), Vector3(0.34, 0.58, 0.24), Vector3(0.0, 1.22, -1.83), 8, 5))
	for side in [-1.0, 1.0]:
		var horn := Factory.cone("Horn", Color("#ddd0ad"), 0.14, 0.72, Vector3(side * 0.56, 2.12, -1.42), 7)
		horn.rotation.z = -side * PI * 0.52
		body_root.add_child(horn)
	_add_eye_pair(1.95, -1.78, 0.30, 0.09)
	body_root.add_child(Factory.sphere("Nose", Color("#26221f"), Vector3(0.31, 0.20, 0.16), Vector3(0.0, 1.67, -2.25), 8, 4))
	_add_legs(color.darkened(0.16), 0.58, 1.02, 0.68, 0.76, Color("#28231f"))


func _build_elephant() -> void:
	var color := Catalog.get_color(species_id)
	var ivory := Color.from_string(str(data["accent"]), Color("#d9d0b6"))
	body_root.scale = Vector3.ONE * 1.48
	body_root.add_child(Factory.loft("ElephantBody", color, [
		Vector3(0.0, 1.48, 1.42), Vector3(0.0, 1.56, 0.78), Vector3(0.0, 1.68, 0.02),
		Vector3(0.0, 1.82, -0.70), Vector3(0.0, 2.02, -1.16), Vector3(0.0, 2.08, -1.65),
		Vector3(0.0, 1.92, -2.10)
	], [
		Vector2(0.52, 0.54), Vector2(0.92, 0.77), Vector2(0.98, 0.82), Vector2(0.90, 0.88),
		Vector2(0.68, 0.68), Vector2(0.58, 0.54), Vector2(0.38, 0.30)
	], 10))
	for side in [-1.0, 1.0]:
		body_root.add_child(Factory.sphere("GreatEar", color.darkened(0.08), Vector3(0.16, 0.94, 0.88), Vector3(side * 0.62, 2.05, -1.55), 9, 6))
		body_root.add_child(Factory.sphere("EarInner", color.lightened(0.07), Vector3(0.10, 0.70, 0.62), Vector3(side * 0.69, 2.02, -1.60), 8, 5))
		var tusk := Factory.cone("Tusk", ivory, 0.12, 0.92, Vector3(side * 0.30, 1.62, -2.36), 8)
		tusk.rotation.x = -PI * 0.50
		body_root.add_child(tusk)
	_add_eye_pair(2.22, -2.02, 0.34, 0.075)
	body_root.add_child(Factory.loft("Trunk", color.lightened(0.02), [
		Vector3(0.0, 1.92, -2.06), Vector3(0.0, 1.55, -2.34), Vector3(0.0, 1.05, -2.45),
		Vector3(0.0, 0.57, -2.39), Vector3(0.0, 0.34, -2.62)
	], [Vector2(0.25, 0.22), Vector2(0.23, 0.20), Vector2(0.19, 0.17), Vector2(0.15, 0.13), Vector2(0.09, 0.08)], 9))
	for side in [-1.0, 1.0]:
		body_root.add_child(Factory.sphere("TrunkNostril", Color("#343837"), Vector3(0.045, 0.035, 0.045), Vector3(side * 0.055, 0.34, -2.70), 6, 3))
	body_root.add_child(Factory.loft("ElephantTail", color.darkened(0.08), [
		Vector3(0.0, 1.56, 1.32), Vector3(0.04, 1.25, 1.80), Vector3(0.08, 0.92, 2.12)
	], [Vector2(0.09, 0.09), Vector2(0.07, 0.07), Vector2(0.035, 0.035)], 7))
	body_root.add_child(Factory.sphere("TailBrush", Color("#3f4442"), Vector3(0.16, 0.24, 0.16), Vector3(0.08, 0.82, 2.20), 7, 4))
	_add_legs(color.darkened(0.08), 0.72, 1.25, 0.76, 0.88, Color("#4d514f"))


func _build_crocodile() -> void:
	var color := Catalog.get_color(species_id)
	var accent := Color.from_string(str(data["accent"]), Color("#b4aa71"))
	body_root.scale = Vector3.ONE * 1.20
	body_root.add_child(Factory.loft("CrocodileBody", color, [
		Vector3(0.0, 0.48, 2.75), Vector3(0.0, 0.55, 1.85), Vector3(0.0, 0.66, 0.90),
		Vector3(0.0, 0.72, -0.05), Vector3(0.0, 0.66, -0.88), Vector3(0.0, 0.58, -1.52),
		Vector3(0.0, 0.49, -2.35), Vector3(0.0, 0.45, -3.05)
	], [
		Vector2(0.08, 0.07), Vector2(0.24, 0.16), Vector2(0.50, 0.30), Vector2(0.66, 0.39),
		Vector2(0.59, 0.36), Vector2(0.49, 0.30), Vector2(0.37, 0.22), Vector2(0.18, 0.11)
	], 10))
	body_root.add_child(Factory.loft("SculptedHead", color.lightened(0.035), [
		Vector3(0.0, 0.67, -1.42), Vector3(0.0, 0.69, -1.92), Vector3(0.0, 0.65, -2.48), Vector3(0.0, 0.58, -3.05), Vector3(0.0, 0.54, -3.38)
	], [
		Vector2(0.50, 0.28), Vector2(0.54, 0.27), Vector2(0.48, 0.23), Vector2(0.38, 0.17), Vector2(0.24, 0.11)
	], 10))
	body_root.add_child(Factory.loft("PaleLowerJaw", accent.darkened(0.10), [
		Vector3(0.0, 0.48, -1.73), Vector3(0.0, 0.44, -2.28), Vector3(0.0, 0.42, -2.86), Vector3(0.0, 0.43, -3.30)
	], [
		Vector2(0.46, 0.11), Vector2(0.45, 0.10), Vector2(0.36, 0.085), Vector2(0.20, 0.06)
	], 9))
	for plate_index in range(7):
		for side in [-1.0, 1.0]:
			var plate := Factory.cone("BackPlate", color.darkened(0.24), 0.14, 0.34, Vector3(side * 0.20, 1.00, 1.25 - plate_index * 0.46), 6)
			plate.rotation.z = side * 0.12
			body_root.add_child(plate)
	for side in [-1.0, 1.0]:
		body_root.add_child(Factory.sphere("EyeRidge", color.darkened(0.16), Vector3(0.23, 0.19, 0.21), Vector3(side * 0.30, 0.89, -2.44), 8, 4))
		body_root.add_child(Factory.sphere("Nostril", Color("#253027"), Vector3(0.075, 0.045, 0.065), Vector3(side * 0.18, 0.64, -3.34), 6, 3))
	_add_eye_pair(0.92, -2.53, 0.29, 0.075)
	_add_legs(color.darkened(0.15), 0.30, 0.42, 0.70, 0.83, Color("#2e392c"))


func _build_moose() -> void:
	var color := Catalog.get_color(species_id)
	var accent := Color.from_string(str(data["accent"]), Color("#c49b69"))
	body_root.scale = Vector3.ONE * 1.24
	body_root.add_child(Factory.loft("MooseBody", color, [
		Vector3(0.0, 1.55, 1.12), Vector3(0.0, 1.56, 0.55), Vector3(0.0, 1.58, -0.14),
		Vector3(0.0, 1.74, -0.75), Vector3(0.0, 2.17, -1.02), Vector3(0.0, 2.70, -1.30),
		Vector3(0.0, 3.02, -1.70), Vector3(0.0, 2.88, -2.13)
	], [
		Vector2(0.38, 0.40), Vector2(0.62, 0.51), Vector2(0.64, 0.53), Vector2(0.54, 0.58),
		Vector2(0.36, 0.42), Vector2(0.31, 0.36), Vector2(0.39, 0.34), Vector2(0.20, 0.16)
	], 9))
	body_root.add_child(Factory.sphere("MooseMuzzle", accent.darkened(0.18), Vector3(0.34, 0.25, 0.52), Vector3(0.0, 2.88, -2.08), 8, 5))
	body_root.add_child(Factory.sphere("Dewlap", color.darkened(0.20), Vector3(0.22, 0.55, 0.20), Vector3(0.0, 2.17, -1.48), 7, 4))
	for side in [-1.0, 1.0]:
		var antler_color := accent.lightened(0.08)
		var beam := Factory.tapered_cylinder("AntlerBeam", antler_color, 0.10, 0.07, 1.45, Vector3(side * 0.42, 3.72, -1.48), 7)
		beam.rotation.z = -side * 0.70
		body_root.add_child(beam)
		for tine_index in range(3):
			var tine := Factory.cone("AntlerTine", antler_color, 0.075, 0.58, Vector3(side * (0.62 + tine_index * 0.25), 4.05, -1.48 + tine_index * 0.10), 6)
			tine.rotation.z = -side * 0.25
			body_root.add_child(tine)
	_add_eye_pair(3.10, -1.91, 0.22, 0.09)
	body_root.add_child(Factory.sphere("Nose", Color("#292723"), Vector3(0.28, 0.16, 0.14), Vector3(0.0, 2.87, -2.59), 8, 4))
	_add_legs(color.darkened(0.17), 0.27, 1.57, 0.55, 0.88, Color("#2c2924"))


func _build_rhino() -> void:
	var color := Catalog.get_color(species_id)
	var accent := Color.from_string(str(data["accent"]), Color("#d5c9ae"))
	body_root.scale = Vector3.ONE * 1.34
	body_root.add_child(Factory.loft("RhinoBody", color, [
		Vector3(0.0, 1.28, 1.28), Vector3(0.0, 1.32, 0.62), Vector3(0.0, 1.36, -0.10),
		Vector3(0.0, 1.61, -0.76), Vector3(0.0, 1.84, -1.18), Vector3(0.0, 1.65, -1.74),
		Vector3(0.0, 1.44, -2.31)
	], [
		Vector2(0.45, 0.46), Vector2(0.79, 0.66), Vector2(0.82, 0.69), Vector2(0.74, 0.78),
		Vector2(0.58, 0.52), Vector2(0.50, 0.36), Vector2(0.28, 0.20)
	], 10))
	for fold_index in range(3):
		body_root.add_child(Factory.box("ArmorFold", color.darkened(0.09), Vector3(1.42, 0.07, 0.10), Vector3(0.0, 1.82, -0.50 + fold_index * 0.55)))
	var main_horn := Factory.cone("MainHorn", accent, 0.19, 1.08, Vector3(0.0, 1.72, -2.48), 8)
	main_horn.rotation.x = -PI * 0.50
	body_root.add_child(main_horn)
	var small_horn := Factory.cone("SmallHorn", accent.darkened(0.08), 0.13, 0.58, Vector3(0.0, 1.91, -1.98), 7)
	small_horn.rotation.x = -PI * 0.50
	body_root.add_child(small_horn)
	for side in [-1.0, 1.0]:
		var ear := Factory.cone("Ear", color.darkened(0.12), 0.18, 0.44, Vector3(side * 0.39, 2.18, -1.39), 7)
		ear.rotation.z = side * 0.42
		body_root.add_child(ear)
	_add_eye_pair(1.90, -1.86, 0.28, 0.08)
	_add_legs(color.darkened(0.13), 0.62, 0.98, 0.70, 0.77, Color("#474b49"))


func _build_hippo() -> void:
	var color := Catalog.get_color(species_id)
	var accent := Color.from_string(str(data["accent"]), Color("#c68d91"))
	body_root.scale = Vector3.ONE * 1.34
	body_root.add_child(Factory.loft("HippoBody", color, [
		Vector3(0.0, 1.08, 1.25), Vector3(0.0, 1.16, 0.58), Vector3(0.0, 1.20, -0.14),
		Vector3(0.0, 1.34, -0.76), Vector3(0.0, 1.53, -1.22), Vector3(0.0, 1.43, -1.82),
		Vector3(0.0, 1.25, -2.42)
	], [
		Vector2(0.52, 0.49), Vector2(0.86, 0.71), Vector2(0.89, 0.73), Vector2(0.82, 0.78),
		Vector2(0.65, 0.57), Vector2(0.62, 0.42), Vector2(0.46, 0.30)
	], 10))
	body_root.add_child(Factory.sphere("WideMuzzle", accent, Vector3(0.72, 0.37, 0.58), Vector3(0.0, 1.23, -2.23), 10, 6))
	body_root.add_child(Factory.box("MouthLine", Color("#3e292c"), Vector3(0.86, 0.05, 0.46), Vector3(0.0, 1.13, -2.57)))
	for side in [-1.0, 1.0]:
		body_root.add_child(Factory.sphere("Ear", color.lightened(0.06), Vector3(0.22, 0.22, 0.17), Vector3(side * 0.43, 1.98, -1.32), 7, 4))
		body_root.add_child(Factory.sphere("Nostril", Color("#382f31"), Vector3(0.09, 0.05, 0.07), Vector3(side * 0.22, 1.47, -2.75), 6, 3))
	_add_eye_pair(1.78, -1.82, 0.29, 0.08)
	_add_legs(color.darkened(0.10), 0.62, 0.72, 0.70, 0.77, Color("#494044"))


func _add_eye_pair(height: float, forward_z: float, side_x: float, size: float) -> void:
	var iris_color := Color("#a97732")
	match species_id:
		"rabbit", "deer", "capybara", "goat", "zebra", "moose", "bison", "elephant", "rhino", "hippo": iris_color = Color("#6f4b2d")
		"wolf", "fox", "lynx", "tiger", "cheetah", "lion", "hyena": iris_color = Color("#d59b3b")
		"owl", "eagle": iris_color = Color("#e6b740")
		"crocodile", "snake", "turtle": iris_color = Color("#b9b84a")
	var eye_scale := size * 0.88
	for side in [-1.0, 1.0]:
		body_root.add_child(Factory.sphere("EyeSocket", Color("#101715"), Vector3(eye_scale * 1.06, eye_scale, eye_scale * 0.66), Vector3(side * side_x, height, forward_z), 9, 5))
		body_root.add_child(Factory.sphere("Iris", iris_color.darkened(0.06), Vector3(eye_scale * 0.50, eye_scale * 0.54, eye_scale * 0.20), Vector3(side * (side_x + 0.014), height, forward_z - eye_scale * 0.49), 8, 4))
		body_root.add_child(Factory.sphere("Pupil", Color("#050807"), Vector3(eye_scale * 0.21, eye_scale * 0.34, eye_scale * 0.10), Vector3(side * (side_x + 0.018), height, forward_z - eye_scale * 0.61), 7, 4))
		body_root.add_child(Factory.sphere("EyeLight", Color("#f4efd7"), Vector3(eye_scale * 0.14, eye_scale * 0.14, eye_scale * 0.065), Vector3(side * (side_x + 0.030), height + eye_scale * 0.22, forward_z - eye_scale * 0.64), 6, 3))


func _add_legs(color: Color, radius: float, length: float, spread_x: float, spread_z: float, paw_color: Color = Color.TRANSPARENT) -> void:
	var hoofed := species_id in ["deer", "goat", "zebra", "bison", "moose"]
	var broad_footed := species_id in ["bear", "elephant", "rhino", "hippo", "gorilla"]
	for x_sign in [-1.0, 1.0]:
		for z_sign in [-1.0, 1.0]:
			var foot_color := color.darkened(0.12) if paw_color.a <= 0.0 else paw_color
			var upper := Vector3(x_sign * spread_x, length, z_sign * spread_z)
			var knee := Vector3(x_sign * spread_x * 1.03, length * 0.53, z_sign * spread_z + z_sign * 0.04)
			var ankle := Vector3(x_sign * spread_x, 0.18, z_sign * spread_z - 0.02)
			var toe := Vector3(x_sign * spread_x, 0.13, z_sign * spread_z - 0.20)
			var pivot := Node3D.new()
			pivot.name = "FrontLegPivot" if z_sign < 0.0 else "HindLegPivot"
			pivot.position = upper
			body_root.add_child(pivot)
			pivot.add_child(Factory.loft("Leg", color, [Vector3.ZERO, knee - upper, ankle - upper, toe - upper], [Vector2(radius * 0.44, radius * 0.44), Vector2(radius * 0.36, radius * 0.34), Vector2(radius * 0.27, radius * 0.24), Vector2(radius * 0.40, radius * 0.22)], 7))
			var foot_scale := Vector3(radius * 0.44, radius * 0.15, radius * 0.60)
			if hoofed:
				foot_scale = Vector3(radius * 0.36, radius * 0.19, radius * 0.52)
			elif broad_footed:
				foot_scale = Vector3(radius * 0.62, radius * 0.18, radius * 0.66)
			pivot.add_child(Factory.sphere("Hoof" if hoofed else "PawPad", foot_color, foot_scale, toe - upper + Vector3(0.0, -0.018, -0.035), 8, 4))
			leg_pivots.append(pivot)
			if species_id == "rabbit":
				leg_phases.append(0.0 if z_sign < 0.0 else PI)
				leg_stride_scales.append(0.78 if z_sign < 0.0 else 1.28)
			else:
				leg_phases.append(0.0 if x_sign == z_sign else PI)
				leg_stride_scales.append(1.0 if z_sign < 0.0 else 0.92)


func _collect_tail_visuals() -> void:
	tail_visuals.clear()
	var animated_tail_names := ["Tail", "CatTail", "LionTail", "CheetahTail", "RudderTail", "ElephantTail"]
	for child in body_root.get_children():
		if child is Node3D and str(child.name) in animated_tail_names:
			tail_visuals.append(child as Node3D)


func _add_primate_limbs(color: Color, arm_length: float, leg_length: float, shoulder_x: float, hip_x: float, heavy: bool) -> void:
	for side in [-1.0, 1.0]:
		var arm_pivot := Node3D.new()
		arm_pivot.name = "PrimateArmPivot"
		arm_pivot.position = Vector3(side * shoulder_x, 1.92 if heavy else 1.58, -0.12)
		body_root.add_child(arm_pivot)
		var elbow := Vector3(side * 0.13, -arm_length * 0.50, -0.12)
		var knuckle := Vector3(side * 0.08, -arm_length, -0.34)
		arm_pivot.add_child(Factory.loft("LongArm", color, [Vector3.ZERO, elbow, knuckle], [Vector2(0.28, 0.28), Vector2(0.24, 0.22), Vector2(0.18, 0.16)], 7))
		arm_pivot.add_child(Factory.sphere("Knuckle", color.darkened(0.22), Vector3(0.32 if heavy else 0.24, 0.18, 0.34), knuckle + Vector3(0.0, -0.03, -0.08), 7, 4))
		leg_pivots.append(arm_pivot)
		leg_phases.append(0.0 if side < 0.0 else PI)
		leg_stride_scales.append(0.86 if heavy else 1.0)

		var leg_pivot := Node3D.new()
		leg_pivot.name = "PrimateLegPivot"
		leg_pivot.position = Vector3(side * hip_x, 0.98 if heavy else 0.82, 0.30)
		body_root.add_child(leg_pivot)
		var knee := Vector3(side * 0.08, -leg_length * 0.50, 0.14)
		var foot := Vector3(side * 0.03, -leg_length, -0.12)
		leg_pivot.add_child(Factory.loft("PrimateLeg", color.darkened(0.05), [Vector3.ZERO, knee, foot], [Vector2(0.26, 0.25), Vector2(0.22, 0.20), Vector2(0.16, 0.14)], 7))
		leg_pivot.add_child(Factory.sphere("PrimateFoot", color.darkened(0.24), Vector3(0.25, 0.14, 0.38), foot + Vector3(0.0, -0.02, -0.12), 7, 4))
		leg_pivots.append(leg_pivot)
		leg_phases.append(PI if side < 0.0 else 0.0)
		leg_stride_scales.append(0.74 if heavy else 0.88)


func _physics_process(delta: float) -> void:
	if dead:
		return
	_update_timers(delta)
	_update_needs(delta)
	if dead:
		return
	if is_player:
		_update_player_intent()
	else:
		_update_ai(delta)
	_apply_movement(delta)
	_update_environment_state(delta)
	_update_cover_state(delta)
	_try_attack()
	_update_visual_lod(delta)
	_update_health_bar_visibility(delta)


func _update_timers(delta: float) -> void:
	attack_timer = maxf(attack_timer - delta, 0.0)
	skill_timer = maxf(skill_timer - delta, 0.0)
	eat_timer = maxf(eat_timer - delta, 0.0)
	stamina_regen_delay = maxf(stamina_regen_delay - delta, 0.0)
	decision_timer -= delta
	wander_timer -= delta
	spawn_protection = maxf(spawn_protection - delta, 0.0)
	rage_timer = maxf(rage_timer - delta, 0.0)
	rage_cooldown_timer = maxf(rage_cooldown_timer - delta, 0.0)
	quill_guard_timer = maxf(quill_guard_timer - delta, 0.0)
	shell_guard_timer = maxf(shell_guard_timer - delta, 0.0)
	forage_speed_timer = maxf(forage_speed_timer - delta, 0.0)
	if habit_buff_timer > 0.0:
		habit_buff_timer = maxf(habit_buff_timer - delta, 0.0)
		if habit_buff_timer <= 0.0:
			habit_buff_kind = ""
			habit_buff_name = ""
	obstacle_break_timer = maxf(obstacle_break_timer - delta, 0.0)
	flight_ground_timer = maxf(flight_ground_timer - delta, 0.0)
	flight_dive_timer = maxf(flight_dive_timer - delta, 0.0)
	burst_exhaustion_timer = maxf(burst_exhaustion_timer - delta, 0.0)
	exposed_timer = maxf(exposed_timer - delta, 0.0)
	opportunity_strike_timer = maxf(opportunity_strike_timer - delta, 0.0)
	cover_reveal_timer = maxf(cover_reveal_timer - delta, 0.0)
	cover_ambush_timer = maxf(cover_ambush_timer - delta, 0.0)
	cover_hint_cooldown = maxf(cover_hint_cooldown - delta, 0.0)
	terrain_momentum_grace_timer = maxf(terrain_momentum_grace_timer - delta, 0.0)
	terrain_counter_cooldown = maxf(terrain_counter_cooldown - delta, 0.0)
	terrain_hint_cooldown = maxf(terrain_hint_cooldown - delta, 0.0)
	ecology_leverage_cooldown = maxf(ecology_leverage_cooldown - delta, 0.0)
	counterplay_chain_timer = maxf(counterplay_chain_timer - delta, 0.0)
	counterplay_mastery_timer = maxf(counterplay_mastery_timer - delta, 0.0)
	if counterplay_chain_timer <= 0.0:
		counterplay_chain_target_id = -1
		counterplay_chain_flags = 0
	search_timer = maxf(search_timer - delta, 0.0)
	trace_investigation_timer = maxf(trace_investigation_timer - delta, 0.0)
	danger_memory_timer = maxf(danger_memory_timer - delta, 0.0)
	var canopy_was_active := canopy_timer > 0.0
	canopy_timer = maxf(canopy_timer - delta, 0.0)
	if Catalog.has_trait(species_id, "flying"):
		flight_target_height = 0.58 if flight_ground_timer > 0.0 or flight_dive_timer > 0.0 else float(data.get("flight_height", 4.2))
	elif Catalog.has_trait(species_id, "canopy_mover"):
		flight_target_height = 3.35 if canopy_timer > 0.0 else 0.45
		if canopy_was_active and canopy_timer <= 0.0 and game.world != null and game.world.has_method("nearest_legal_landing"):
			landing_target_position = game.world.nearest_legal_landing(global_position, 0.52)
	calm_timer = maxf(calm_timer - delta, 0.0)
	alert_cooldown = maxf(alert_cooldown - delta, 0.0)
	state_commit_timer = maxf(state_commit_timer - delta, 0.0)
	starvation_warning_timer = maxf(starvation_warning_timer - delta, 0.0)
	recovery_timer = maxf(recovery_timer - delta, 0.0)
	scent_mark_timer = maxf(scent_mark_timer - delta, 0.0)
	hidden_timer = maxf(hidden_timer - delta, 0.0)
	panic_timer = maxf(panic_timer - delta, 0.0)
	if ecology_influence_timer > 0.0:
		ecology_influence_timer = maxf(ecology_influence_timer - delta, 0.0)
		if ecology_influence_timer <= 0.0:
			ecology_influence_source = null
			ecology_influence_reason = "生态助攻"
	if slow_timer > 0.0:
		slow_timer = maxf(slow_timer - delta, 0.0)
		if slow_timer <= 0.0:
			slow_multiplier = 1.0
	if poison_timer > 0.0:
		poison_timer -= delta
		health -= poison_dps * delta
		health_changed.emit(health, max_health)
		_update_health_bar()
		if health <= 0.0:
			var valid_poison_source: EcoActor = poison_source if is_instance_valid(poison_source) else null
			die(valid_poison_source)
	_update_exhaustion_state()


func _update_exhaustion_state() -> void:
	if max_stamina <= 0.0:
		exhausted = false
		return
	var stamina_ratio := stamina / max_stamina
	if exhausted:
		if stamina_ratio >= EXHAUSTION_EXIT_RATIO:
			exhausted = false
	elif stamina_ratio <= EXHAUSTION_ENTER_RATIO:
		exhausted = true


func is_opportunity_exposed() -> bool:
	return not dead and (exposed_timer > 0.0 or stamina <= max_stamina * EXPOSED_STAMINA_RATIO)


func opportunity_status_text() -> String:
	if exhausted:
		return "力竭破绽"
	if stamina <= max_stamina * EXPOSED_STAMINA_RATIO:
		return "耐力破绽"
	if exposed_timer > 0.0:
		return "技能破绽 %.1fs" % exposed_timer
	return ""


func habit_status_text() -> String:
	if habit_buff_timer <= 0.0 or habit_buff_kind == "":
		return ""
	return "习性·%s · %s %.1fs" % [habit_buff_name, Catalog.habit_buff_display_name(habit_buff_kind), habit_buff_timer]


func has_habit_buff(buff_kind: String) -> bool:
	return habit_buff_timer > 0.0 and habit_buff_kind == buff_kind


func _update_environment_state(delta: float) -> void:
	if game == null or game.world == null or not game.world.has_method("region_id_at"):
		environment_region_id = ""
		environment_affinity = 0.0
		terrain_momentum = 0.0
		return
	environment_region_id = game.world.region_id_at(global_position)
	environment_affinity = Catalog.habitat_affinity(species_id, environment_region_id)
	if _collapse_competition_active() or is_airborne():
		terrain_momentum = 0.0
		return
	if environment_affinity >= TERRAIN_AFFINITY_THRESHOLD:
		terrain_momentum_grace_timer = TERRAIN_MOMENTUM_GRACE
		if terrain_counter_cooldown <= 0.0 and terrain_momentum < TERRAIN_MOMENTUM_REQUIRED:
			var flat_speed := Vector2(velocity.x, velocity.z).length()
			if flat_speed >= 0.72:
				var newly_ready := terrain_momentum + delta >= TERRAIN_MOMENTUM_REQUIRED
				terrain_momentum = minf(terrain_momentum + delta, TERRAIN_MOMENTUM_REQUIRED)
				if newly_ready and is_player and terrain_hint_cooldown <= 0.0 and game.has_method("show_hint"):
					terrain_hint_cooldown = 7.0
					var counter_name: String = str(game.world.terrain_counter_name(environment_region_id)) if game.world.has_method("terrain_counter_name") else "地形反制"
					game.show_hint("%s就绪：把不适应这里的强敌引入主场，用普通攻击发动逆袭" % counter_name)
			elif flat_speed < 0.30:
				terrain_momentum = maxf(terrain_momentum - delta * 0.32, 0.0)
	elif terrain_momentum_grace_timer <= 0.0:
		terrain_momentum = 0.0
	_update_cover_visual()


func _update_cover_state(delta: float) -> void:
	cover_sample_timer -= delta
	if cover_sample_timer <= 0.0:
		cover_sample_timer = 0.16 + fmod(float(maxi(actor_id, 0)) * 0.013, 0.07)
		cover_strength = 0.0
		if game != null and game.world != null and game.world.has_method("cover_strength_at"):
			cover_strength = game.world.cover_strength_at(global_position, species_id)
	if wants_sprint and (cover_dwell_timer > 0.0 or cover_ambush_timer > 0.0):
		_break_cover(0.85)
		_update_cover_visual()
		return
	var can_prepare := cover_strength >= COVER_CONCEAL_THRESHOLD and cover_reveal_timer <= 0.0 and scent_mark_timer <= 0.0 and not is_airborne()
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	if can_prepare and flat_speed <= 0.58:
		cover_dwell_timer = minf(cover_dwell_timer + delta, COVER_HIDE_DELAY)
		if cover_dwell_timer >= COVER_HIDE_DELAY:
			var newly_ready := cover_ambush_timer <= 0.0
			cover_ambush_timer = maxf(cover_ambush_timer, COVER_AMBUSH_GRACE)
			if newly_ready and is_player and cover_hint_cooldown <= 0.0 and game.has_method("show_hint"):
				cover_hint_cooldown = 6.0
				game.show_hint("伏击就绪：走出草丛后的首次普通攻击可直接触发强敌破绽")
	elif not can_prepare:
		cover_dwell_timer = 0.0
		if cover_reveal_timer > 0.0 or scent_mark_timer > 0.0:
			cover_ambush_timer = 0.0
	else:
		cover_dwell_timer = maxf(cover_dwell_timer - delta * 0.45, 0.0)
	_update_cover_visual()


func _break_cover(reveal_duration: float = COVER_REVEAL_SECONDS) -> void:
	cover_reveal_timer = maxf(cover_reveal_timer, reveal_duration)
	cover_dwell_timer = 0.0
	cover_ambush_timer = 0.0
	_update_cover_visual()


func _update_cover_visual() -> void:
	if not is_player or selection_ring == null:
		return
	var next_state := "mastery" if counterplay_mastery_timer > 0.0 else ("ambush" if has_cover_ambush() else ("terrain" if has_terrain_momentum() else ("ecology" if ecology_leverage_status_text() != "" and ecology_leverage_cooldown <= 0.0 else ("cover" if cover_strength >= COVER_CONCEAL_THRESHOLD else "open"))))
	if next_state == cover_visual_state:
		return
	cover_visual_state = next_state
	var tint: Color = {
		"mastery": Color("#ffb86b"),
		"ambush": Color("#f1d46b"),
		"terrain": Color("#70cfe8"),
		"ecology": Color("#d7a2f2"),
		"cover": Color("#65d8b2"),
		"open": Color("#8ff0b1"),
	}.get(next_state, Color("#8ff0b1"))
	var material := selection_ring.material_override as StandardMaterial3D
	if material != null:
		material.albedo_color = Color(tint, 0.82)
		material.emission = tint


func _update_needs(delta: float) -> void:
	hunger = minf(hunger + float(data["hunger_rate"]) * delta, 100.0)
	if hunger >= 100.0:
		health = starvation_health_after(health, max_health, delta)
		health_changed.emit(health, max_health)
		_update_health_bar()
		if is_player and starvation_warning_timer <= 0.0:
			starvation_warning_timer = 5.0
			game.show_hint("饱腹值耗尽，正在持续失去生命！快寻找食物")
	if is_player:
		hunger_changed.emit(hunger)


func _update_health_bar_visibility(delta: float) -> void:
	if health_bar_root == null:
		return
	forced_health_bar_timer = maxf(forced_health_bar_timer - delta, 0.0)
	if forced_health_bar_timer > 0.0:
		health_bar_root.visible = not dead
		return
	health_bar_visibility_timer -= delta
	if health_bar_visibility_timer > 0.0:
		return
	health_bar_visibility_timer = 0.22 + fmod(float(actor_id) * 0.017, 0.11)
	if is_player:
		health_bar_root.visible = true
		return
	var game_player := _game_player()
	if game.get("batch_mode") or not is_instance_valid(game_player):
		health_bar_root.visible = false
		return
	health_bar_root.visible = not dead and global_position.distance_to(game_player.global_position) <= 22.0


func reveal_health_bar(duration: float = 4.2) -> void:
	forced_health_bar_timer = maxf(forced_health_bar_timer, duration)
	if health_bar_root != null:
		health_bar_root.visible = not dead


func _update_player_intent() -> void:
	var input_vector: Vector2 = game.get_move_input()
	desired_direction = game.input_to_world(input_vector)
	wants_sprint = game.is_sprint_pressed() and input_vector.length() > 0.15
	attack_intent = game.is_attack_pressed()
	if game.has_method("on_player_action"):
		if input_vector.length() > 0.15:
			game.on_player_action("move")
		if wants_sprint:
			game.on_player_action("sprint")
		if attack_intent:
			game.on_player_action("attack")
	if Catalog.has_trait(species_id, "flying") and attack_intent:
		_request_landing(1.15)
	if game.consume_skill_request():
		if game.has_method("on_player_action"):
			game.on_player_action("skill")
		use_skill(_nearest_living_actor(_skill_engage_range()))
	if game.consume_interact_request():
		if game.has_method("on_player_action"):
			game.on_player_action("eat")
		try_consume_nearby()
	if species_id == "rabbit" and alert_cooldown <= 0.0:
		for other in game.get_living_actors():
			if other != self and other.ai_state == "hunt" and other.ai_target == self:
				game.show_hint("警觉：附近的天敌盯上了你")
				alert_cooldown = 5.0
				break


func is_airborne() -> bool:
	return (Catalog.has_trait(species_id, "flying") or Catalog.has_trait(species_id, "canopy_mover")) and global_position.y > 1.30


func is_in_canopy() -> bool:
	return Catalog.has_trait(species_id, "canopy_mover") and canopy_timer > 0.0 and global_position.y > 1.30


func movement_domain_label() -> String:
	if is_in_canopy():
		return "树冠层"
	if Catalog.has_trait(species_id, "flying"):
		return "低空接敌" if global_position.y < 1.30 else "巡航空域"
	return "地面"


func _try_enter_canopy(duration: float) -> bool:
	if not Catalog.has_trait(species_id, "canopy_mover") or game.world == null:
		return false
	if game.world.region_id_at(global_position) != "forest" or not game.world.has_method("nearest_climbable_tree"):
		return false
	var tree_position: Vector3 = game.world.nearest_climbable_tree(global_position, 4.6)
	if tree_position.x == INF:
		return false
	var away := Vector3(global_position.x - tree_position.x, 0.0, global_position.z - tree_position.z)
	if away.length() < 0.1:
		away = Vector3.RIGHT if actor_id % 2 == 0 else Vector3.LEFT
	canopy_anchor = tree_position + away.normalized() * 1.05
	landing_target_position = Vector3(canopy_anchor.x, 0.45, canopy_anchor.z)
	canopy_timer = maxf(canopy_timer, duration)
	flight_target_height = 3.35
	hidden_timer = maxf(hidden_timer, duration * 0.55)
	collision_mask = 0
	return true


func _request_landing(duration: float) -> void:
	if not Catalog.has_trait(species_id, "flying"):
		return
	flight_ground_timer = maxf(flight_ground_timer, duration)
	flight_target_height = 0.58
	var radius := 0.40 + int(data["size"]) * 0.09
	if game.world != null and game.world.has_method("nearest_legal_landing"):
		landing_target_position = game.world.nearest_legal_landing(global_position, radius)
	else:
		landing_target_position = Vector3(global_position.x, 0.45, global_position.z)


func _update_ai(delta: float) -> void:
	if decision_timer <= 0.0:
		decision_timer = 0.28 + fmod(float(actor_id) * 0.037, 0.17)
		_think()
	attack_intent = false
	wants_sprint = false
	match ai_state:
		"flee":
			if is_instance_valid(ai_target) and not ai_target.dead:
				var away := (global_position - ai_target.global_position).normalized()
				if group_escape_direction.length() > 0.1:
					away = (away * 0.78 + group_escape_direction * 0.42).normalized()
				var evade_side := Vector3(-away.z, 0.0, away.x) * (-1.0 if actor_id % 2 == 0 else 1.0)
				var cover_offset := escape_cover_position - global_position
				var habitat_offset := escape_habitat_position - global_position
				var intervention_offset := escape_intervention_position - global_position
				var seek_intervention := _has_escape_intervention(ai_target) and health / max_health > 0.38 and stamina / max_stamina > 0.20
				if seek_intervention and Vector2(intervention_offset.x, intervention_offset.z).length() > 1.45:
					var toward_intervention := Vector3(intervention_offset.x, 0.0, intervention_offset.z).normalized()
					desired_direction = (toward_intervention * 0.94 + away * 0.34 + evade_side * 0.14).normalized()
					wants_sprint = stamina > max_stamina * 0.24
				elif seek_intervention:
					desired_direction = (away * 0.58 + evade_side * 0.72).normalized()
					wants_sprint = false
				elif _has_escape_cover() and Vector2(cover_offset.x, cover_offset.z).length() > 1.15:
					var toward_cover := Vector3(cover_offset.x, 0.0, cover_offset.z).normalized()
					desired_direction = (toward_cover * 0.86 + away * 0.48 + evade_side * 0.16).normalized()
					wants_sprint = stamina > max_stamina * 0.16
				elif _has_escape_cover():
					desired_direction = Vector3.ZERO
					wants_sprint = false
				elif _has_escape_habitat() and Vector2(habitat_offset.x, habitat_offset.z).length() > 1.25:
					var toward_habitat := Vector3(habitat_offset.x, 0.0, habitat_offset.z).normalized()
					desired_direction = (toward_habitat * 0.92 + away * 0.42 + evade_side * 0.14).normalized()
					wants_sprint = stamina > max_stamina * 0.20
				else:
					desired_direction = (away + evade_side * 0.26).normalized()
					wants_sprint = stamina > max_stamina * 0.16
				var flee_skill_range := _skill_engage_range()
				var can_defend := Catalog.has_trait(species_id, "escape") or Catalog.has_trait(species_id, "retaliator") or Catalog.has_trait(species_id, "canopy_mover")
				if can_defend and skill_timer <= 0.0 and stamina >= float(data["skill_cost"]) and global_position.distance_to(ai_target.global_position) < flee_skill_range:
					use_skill(ai_target)
			else:
				ai_state = "wander"
		"search":
			var search_offset := search_position - global_position
			if search_timer <= 0.0:
				ai_state = "wander"
				desired_direction = Vector3.ZERO
			elif Vector2(search_offset.x, search_offset.z).length() > 1.4:
				desired_direction = Vector3(search_offset.x, 0.0, search_offset.z).normalized()
				wants_sprint = stamina > max_stamina * 0.42
			else:
				var search_angle := fmod(float(actor_id) * 1.71 + search_timer * 2.2, TAU)
				desired_direction = Vector3(cos(search_angle), 0.0, sin(search_angle)) * 0.34
		"trace_investigate":
			var trace_offset := trace_investigation_position - global_position
			var trace_distance := Vector2(trace_offset.x, trace_offset.z).length()
			if trace_investigation_timer <= 0.0 or trace_investigation_position.x == INF:
				ai_state = "wander"
				trace_investigation_position = Vector3(INF, 0.0, INF)
				desired_direction = Vector3.ZERO
			elif trace_distance > 1.35:
				desired_direction = Vector3(trace_offset.x, 0.0, trace_offset.z).normalized()
				wants_sprint = trace_distance > 9.0 and stamina > max_stamina * 0.50 and not exhausted
			else:
				search_position = trace_investigation_position
				search_timer = 1.85 + float(int(data["size"])) * 0.12
				ai_state = "search"
				trace_investigation_timer = 0.0
				trace_investigation_position = Vector3(INF, 0.0, INF)
				desired_direction = Vector3.ZERO
		"danger_avoid":
			if danger_memory_timer <= 0.0 or danger_memory_position.x == INF or _collapse_competition_active():
				ai_state = "wander"
				danger_memory_position = Vector3(INF, 0.0, INF)
				desired_direction = Vector3.ZERO
			else:
				var away_from_memory := Vector3(global_position.x - danger_memory_position.x, 0.0, global_position.z - danger_memory_position.z).normalized()
				if away_from_memory.length() < 0.1:
					var escape_angle := fmod(float(actor_id) * 2.13, TAU)
					away_from_memory = Vector3(cos(escape_angle), 0.0, sin(escape_angle))
				var caution_side := Vector3(-away_from_memory.z, 0.0, away_from_memory.x) * (-1.0 if actor_id % 2 == 0 else 1.0)
				desired_direction = (away_from_memory * 0.94 + caution_side * 0.28).normalized()
				wants_sprint = health < max_health * 0.48 and stamina > max_stamina * 0.38
		"hide":
			desired_direction = Vector3.ZERO
			wants_sprint = false
			if not is_cover_concealed():
				ai_state = "wander"
		"hunt":
			if is_instance_valid(ai_target) and not ai_target.dead:
				if Catalog.has_trait(species_id, "territorial") and territory_radius > 0.0 and not _collapse_competition_active():
					var target_from_territory := ai_target.global_position.distance_to(territory_center)
					if target_from_territory > territory_radius * 1.35 and hunger < 72.0:
						ai_state = "territory_return"
						ai_target = null
						return
				var lead_time := clampf(global_position.distance_to(ai_target.global_position) * 0.035, 0.12, 0.55)
				var predicted_target := ai_target.global_position + Vector3(ai_target.velocity.x, 0.0, ai_target.velocity.z) * lead_time
				var to_target := predicted_target - global_position
				desired_direction = Vector3(to_target.x, 0.0, to_target.z).normalized()
				var distance := global_position.distance_to(ai_target.global_position)
				var planar_distance := Vector2(global_position.x - ai_target.global_position.x, global_position.z - ai_target.global_position.z).length()
				var target_threat_gap := Catalog.opportunity_threat_gap(species_id, ai_target.species_id)
				# Weak animals normally kite a stronger target until it exposes itself.
				# The fully collapsed habitat is the final duel, so continued kiting
				# there would prevent the level from ever selecting one survivor.
				if target_threat_gap > 0 and not ai_target.is_opportunity_exposed() and not has_cover_ambush() and not can_terrain_counter(ai_target) and not _collapse_competition_active():
					var away_from_stronger := Vector3(global_position.x - ai_target.global_position.x, 0.0, global_position.z - ai_target.global_position.z).normalized()
					var orbit_side := Vector3(-away_from_stronger.z, 0.0, away_from_stronger.x) * (-1.0 if actor_id % 2 == 0 else 1.0)
					desired_direction = (away_from_stronger * 0.78 + orbit_side * 0.62).normalized()
					wants_sprint = distance < float(ai_target.data["attack_range"]) + 2.4 and stamina > max_stamina * 0.35 and not exhausted
					attack_intent = false
					var can_defend := Catalog.has_trait(species_id, "escape") or Catalog.has_trait(species_id, "retaliator") or Catalog.has_trait(species_id, "canopy_mover")
					if can_defend and skill_timer <= 0.0 and stamina >= float(data["skill_cost"]) and distance < _skill_engage_range():
						use_skill(ai_target)
					return
				if Catalog.has_trait(species_id, "flying"):
					if planar_distance < 4.8:
						_request_landing(1.25)
					else:
						flight_ground_timer = 0.0
				if Catalog.has_trait(species_id, "flanker") and distance > float(data["attack_range"]) * 1.35:
					var flank := Vector3(-desired_direction.z, 0.0, desired_direction.x) * (-1.0 if actor_id % 2 == 0 else 1.0)
					desired_direction = (desired_direction + flank * (0.32 if Catalog.has_trait(species_id, "pack_hunter") else 0.20)).normalized()
				elif distance < float(data["attack_range"]) * 0.72:
					desired_direction = Vector3.ZERO
				wants_sprint = distance > float(data["attack_range"]) * 0.9 and stamina > max_stamina * 0.28 and not has_cover_ambush()
				attack_intent = distance <= float(data["attack_range"]) + 0.65
				if skill_timer <= 0.0 and stamina >= float(data["skill_cost"]) and distance < _skill_engage_range():
					use_skill(ai_target)
			else:
				ai_state = "wander"
		"hotspot_stalk":
			var event: Dictionary = game.world.get_active_ecology_event() if game.world != null else {}
			if event.is_empty() or int(event.get("sequence", -1)) != hotspot_event_sequence or hotspot_stalk_position.x == INF:
				ai_state = "wander"
				hotspot_event_sequence = -1
				hotspot_stalk_position = Vector3(INF, 0.0, INF)
				desired_direction = Vector3.ZERO
			else:
				var stalk_offset := hotspot_stalk_position - global_position
				var stalk_distance := Vector2(stalk_offset.x, stalk_offset.z).length()
				if stalk_distance > 1.45:
					desired_direction = Vector3(stalk_offset.x, 0.0, stalk_offset.z).normalized()
					wants_sprint = stalk_distance > 13.0 and stamina > max_stamina * 0.52 and not exhausted
				else:
					var center: Vector3 = event.get("position", global_position)
					var outward := Vector3(global_position.x - center.x, 0.0, global_position.z - center.z).normalized()
					var tangent := Vector3(-outward.z, 0.0, outward.x) * (-1.0 if actor_id % 2 == 0 else 1.0)
					desired_direction = tangent * 0.34
					wants_sprint = false
		"food":
			if is_instance_valid(resource_target) and (not resource_target is FoodPatch or resource_target.active):
				var to_food := resource_target.global_position - global_position
				desired_direction = Vector3(to_food.x, 0.0, to_food.z).normalized()
				if Catalog.has_trait(species_id, "flying") and Vector2(to_food.x, to_food.z).length() < 5.5:
					_request_landing(3.2)
				if species_id == "raccoon" and to_food.length() < 4.2 and skill_timer <= 0.0 and stamina >= float(data["skill_cost"]):
					use_skill(_nearest_living_actor(5.0))
				if to_food.length() < 2.0:
					desired_direction = Vector3.ZERO
					try_consume_resource(resource_target)
			else:
				ai_state = "wander"
		"rest":
			desired_direction = Vector3.ZERO
			if stamina > max_stamina * 0.72:
				ai_state = "wander"
		"territory_return":
			var home_offset := territory_center - global_position
			desired_direction = Vector3(home_offset.x, 0.0, home_offset.z).normalized()
			wants_sprint = home_offset.length() > territory_radius * 0.85 and stamina > max_stamina * 0.32
			if home_offset.length() < maxf(2.0, territory_radius * 0.22):
				ai_state = "wander"
				desired_direction = Vector3.ZERO
		_:
			if wander_timer <= 0.0:
				wander_timer = behavior_rng.randf_range(1.4, 4.2)
				var angle := behavior_rng.randf_range(0.0, TAU)
				wander_direction = Vector3(cos(angle), 0.0, sin(angle))
			desired_direction = wander_direction


func _think() -> void:
	var living_actors: Array[EcoActor] = game.get_living_actors()
	var nearest_threat: EcoActor
	var threat_distance := INF
	var shared_herd_threat: EcoActor
	var shared_herd_distance := INF
	var shared_pack_target: EcoActor
	var shared_pack_distance := INF
	var pack_support := 0
	var target_pressure_counts: Dictionary = {}
	var herd_escape_sum := Vector3.ZERO
	var herd_escape_count := 0
	group_escape_direction = Vector3.ZERO
	for other in living_actors:
		if other == self or other.dead:
			continue
		var observer_distance := global_position.distance_to(other.global_position)
		if observer_distance <= AI_GROUP_ALERT_RANGE and other.ai_state == "hunt" and is_instance_valid(other.ai_target) and not other.ai_target.dead:
			var pressure_key: int = other.ai_target.actor_id
			target_pressure_counts[pressure_key] = int(target_pressure_counts.get(pressure_key, 0)) + 1
		if other.species_id == species_id:
			var group_distance := observer_distance
			if Catalog.has_trait(species_id, "pack_hunter") and group_distance <= AI_PACK_SHARE_RADIUS:
				pack_support += 1
				if other.ai_state == "hunt" and is_instance_valid(other.ai_target) and not other.ai_target.dead and other._can_detect_actor(other.ai_target):
					var pack_target_distance := global_position.distance_to(other.ai_target.global_position)
					if pack_target_distance <= AI_GROUP_ALERT_RANGE and group_distance < shared_pack_distance:
						shared_pack_target = other.ai_target
						shared_pack_distance = group_distance
			if Catalog.has_trait(species_id, "herd_mover") and group_distance <= AI_HERD_SHARE_RADIUS and other.ai_state == "flee" and is_instance_valid(other.ai_target) and not other.ai_target.dead:
				var herd_target_distance := global_position.distance_to(other.ai_target.global_position)
				if herd_target_distance <= AI_GROUP_ALERT_RANGE and group_distance < shared_herd_distance:
					shared_herd_threat = other.ai_target
					shared_herd_distance = group_distance
				if other.desired_direction.length() > 0.1:
					herd_escape_sum += other.desired_direction.normalized()
					herd_escape_count += 1
		if is_airborne() and not Catalog.has_trait(other.species_id, "flying"):
			continue
		if Catalog.considers_prey(other.species_id, species_id) and _can_detect_actor(other):
			var distance := global_position.distance_to(other.global_position)
			var stronger: bool = other.health / other.max_health > 0.25 or int(other.data["size"]) >= int(data["size"])
			if distance < threat_distance and stronger:
				nearest_threat = other
				threat_distance = distance
	if herd_escape_count > 0:
		group_escape_direction = (herd_escape_sum / float(herd_escape_count)).normalized()
	var attacker_distance := global_position.distance_to(last_attacker.global_position) if is_instance_valid(last_attacker) and not last_attacker.dead else INF
	if should_rest_for_stamina(stamina / maxf(max_stamina, 1.0), threat_distance, attacker_distance):
		_switch_state("rest", null)
		return
	# The final habitat contest overrides ordinary fear and retaliation. Without
	# this priority, wounded same-species survivors can keep fleeing from one
	# another forever after they become the only remaining group.
	var collapse_competitor := _best_collapse_competitor()
	if is_instance_valid(collapse_competitor):
		_switch_state("hunt", collapse_competitor)
		return
	if is_instance_valid(shared_herd_threat) and Catalog.considers_prey(shared_herd_threat.species_id, species_id):
		_switch_state("flee", shared_herd_threat)
		return
	if ai_state == "hunt" and is_instance_valid(ai_target) and not ai_target.dead:
		if _can_detect_actor(ai_target):
			last_known_target_position = ai_target.global_position
			has_last_known_target_position = true
			var current_utility := _prey_utility(ai_target, pack_support, int(target_pressure_counts.get(ai_target.actor_id, 0)))
			var current_distance := global_position.distance_to(ai_target.global_position)
			if should_abandon_pursuit(current_utility, health / maxf(max_health, 1.0), stamina / maxf(max_stamina, 1.0), ai_target.health / maxf(ai_target.max_health, 1.0), current_distance, float(data["attack_range"]), _collapse_competition_active()):
				var abandoned_target := ai_target
				if Catalog.considers_prey(abandoned_target.species_id, species_id) and current_distance < 18.0:
					_switch_state("flee", abandoned_target)
				elif stamina < max_stamina * 0.28:
					_switch_state("rest", null)
				else:
					_switch_state("wander", null)
				return
		else:
			search_position = last_known_target_position if has_last_known_target_position else ai_target.global_position
			search_timer = SEARCH_MEMORY_SECONDS + float(int(data["size"])) * 0.16
			ai_target = null
			ai_state = "search"
			state_commit_timer = 0.45
			return
	if ai_state == "search" and search_timer > 0.0:
		var reacquired := _best_prey(living_actors, target_pressure_counts, pack_support)
		if is_instance_valid(reacquired):
			_switch_state("hunt", reacquired)
			return
	if ai_state == "trace_investigate" and trace_investigation_timer > 0.0:
		var visible_trace_prey := _best_prey(living_actors, target_pressure_counts, pack_support)
		if is_instance_valid(visible_trace_prey):
			_switch_state("hunt", visible_trace_prey)
	if ai_state == "hide" and is_cover_concealed():
		if is_instance_valid(nearest_threat):
			var hidden_threat_gap := Catalog.opportunity_threat_gap(species_id, nearest_threat.species_id)
			var ambush_reach := float(data["speed"]) * COVER_AMBUSH_GRACE * 0.78 + float(data["attack_range"]) + 0.8
			if hidden_threat_gap > 0 and threat_distance <= ambush_reach:
				_switch_state("hunt", nearest_threat)
				return
		if not is_instance_valid(nearest_threat) or threat_distance > COVER_CLOSE_REVEAL_DISTANCE + 1.2:
			return
	if ai_state == "flee" and is_cover_concealed() and threat_distance > COVER_CLOSE_REVEAL_DISTANCE + 1.2:
		_switch_state("hide", null)
		return
	if ai_state == "flee" and is_instance_valid(nearest_threat) and can_terrain_counter(nearest_threat):
		var terrain_counter_reach := float(data["speed"]) * 0.58 + float(data["attack_range"]) + 0.8
		if threat_distance <= terrain_counter_reach:
			_switch_state("hunt", nearest_threat)
			return
	var flee_distance := 10.0 + int(data["size"]) * 1.5
	if species_id == "rabbit":
		flee_distance += 4.0
	if is_instance_valid(last_attacker) and not last_attacker.dead and health < max_health * 0.42:
		_switch_state("flee", last_attacker)
		return

	if state_commit_timer > 0.0 and ai_state not in ["wander", "hotspot_stalk", "trace_investigate", "danger_avoid"]:
		return

	var flee_health_threshold := 0.38 if Catalog.has_trait(species_id, "brave_vs_large") else 0.72
	if is_instance_valid(nearest_threat) and threat_distance < flee_distance and (health < max_health * flee_health_threshold or float(data["courage"]) < 0.4):
		_switch_state("flee", nearest_threat)
		return
	if ai_state == "trace_investigate" and trace_investigation_timer > 0.0:
		return
	if ai_state == "danger_avoid" and danger_memory_timer > 0.0 and not _collapse_competition_active():
		return
	if ai_state == "hotspot_stalk":
		var active_event: Dictionary = game.world.get_active_ecology_event() if game.world != null else {}
		if active_event.is_empty() or int(active_event.get("sequence", -1)) != hotspot_event_sequence:
			ai_state = "wander"
			hotspot_event_sequence = -1
			hotspot_stalk_position = Vector3(INF, 0.0, INF)
		elif health < max_health * 0.46:
			ai_state = "wander"
		else:
			var visible_hotspot_prey := _best_prey(living_actors, target_pressure_counts, pack_support)
			if is_instance_valid(visible_hotspot_prey):
				_switch_state("hunt", visible_hotspot_prey)
			return

	if calm_timer > 0.0 and hunger < 70.0:
		if hunger > 42.0:
			var calm_resource := _best_food_resource(living_actors)
			if is_instance_valid(calm_resource):
				ai_state = "food"
				resource_target = calm_resource
				return
		ai_state = "wander"
		ai_target = null
		return

	if Catalog.has_trait(species_id, "territorial") and territory_radius > 0.0:
		var home_distance := global_position.distance_to(territory_center)
		if home_distance > territory_radius * 1.18:
			ai_state = "territory_return"
			ai_target = null
			return
		if hunger < 68.0:
			var intruder := _best_territory_intruder()
			if is_instance_valid(intruder):
				_switch_state("hunt", intruder)
				return
	if _begin_danger_memory_avoidance():
		return
	var health_ratio := health / maxf(max_health, 1.0)
	if health_ratio <= Catalog.habit_seek_health_ratio(species_id):
		var recovery_food := _best_habit_food(34.0, living_actors)
		if is_instance_valid(recovery_food):
			if ai_state != "food" or resource_target != recovery_food:
				state_commit_timer = 1.8
			ai_state = "food"
			resource_target = recovery_food
			return

	if hunger > 42.0:
		var resource := _best_food_resource(living_actors)
		if is_instance_valid(resource):
			if ai_state != "food":
				state_commit_timer = 1.4
			ai_state = "food"
			resource_target = resource
			return

	var hunting_motivation := hunger / 100.0 + float(data["aggression"]) * 0.56
	if is_instance_valid(shared_pack_target) and hunting_motivation > 0.38:
		var shared_utility := _prey_utility(shared_pack_target, pack_support, int(target_pressure_counts.get(shared_pack_target.actor_id, 0)))
		if shared_utility >= AI_MIN_PREY_UTILITY:
			_switch_state("hunt", shared_pack_target)
			return
	var prey := _best_prey(living_actors, target_pressure_counts, pack_support)
	if is_instance_valid(prey) and hunting_motivation > 0.44:
		_switch_state("hunt", prey)
		return
	if _begin_ecology_trace_investigation():
		return
	if _begin_ecology_hotspot_stalk():
		return
	if hunger > 25.0 and Catalog.can_eat_food(species_id):
		var plant: Node3D = _best_wild_food(28.0)
		if is_instance_valid(plant):
			if ai_state != "food":
				state_commit_timer = 1.4
			ai_state = "food"
			resource_target = plant
			return
	ai_state = "wander"


func _best_collapse_competitor() -> EcoActor:
	if game.world == null or not game.world.collapse_active:
		return null
	if game.world.collapse_radius > game.world.world_size * 0.34:
		return null
	var nearest_other_species: EcoActor
	var nearest_same_species: EcoActor
	# Once the habitat has fully converged, every survivor must be able to find a
	# competitor. Limiting this search to melee-scale distances could leave two
	# animals wandering on opposite sides of the final circle indefinitely.
	var other_distance := INF
	var same_distance := INF
	for other in game.get_living_actors():
		if other == self or other.dead or other.spawn_protection > 0.0:
			continue
		var distance := global_position.distance_to(other.global_position)
		if other.species_id != species_id and distance < other_distance:
			nearest_other_species = other
			other_distance = distance
		elif other.species_id == species_id and distance < same_distance:
			nearest_same_species = other
			same_distance = distance
	return nearest_other_species if is_instance_valid(nearest_other_species) else nearest_same_species


func _collapse_competition_active() -> bool:
	return game.world != null and game.world.collapse_active and game.world.collapse_radius <= game.world.world_size * 0.34


func _best_territory_intruder() -> EcoActor:
	var closest: EcoActor
	var closest_distance: float = territory_radius * 0.76
	for other in game.get_living_actors():
		if other == self or other.dead or other.spawn_protection > 0.0 or other.species_id == species_id:
			continue
		if not _can_detect_actor(other):
			continue
		var distance_from_home: float = other.global_position.distance_to(territory_center)
		if distance_from_home >= closest_distance:
			continue
		if int(other.data["size"]) > int(data["size"]) + 1 and health < max_health * 0.78:
			continue
		closest = other
		closest_distance = distance_from_home
	return closest


func _switch_state(new_state: String, target: EcoActor) -> void:
	var changed_target := ai_target != target
	if ai_state != new_state:
		state_commit_timer = 1.4
	if new_state == "flee" and is_instance_valid(target) and (ai_state != "flee" or changed_target):
		_prepare_escape_intervention(target)
		_prepare_escape_cover(target)
		_prepare_escape_habitat(target)
	elif new_state != "flee":
		escape_intervention_actor = null
		escape_intervention_position = Vector3(INF, 0.0, INF)
		escape_cover_position = Vector3(INF, 0.0, INF)
		escape_habitat_position = Vector3(INF, 0.0, INF)
	ai_state = new_state
	ai_target = target
	if new_state != "hotspot_stalk":
		hotspot_event_sequence = -1
		hotspot_stalk_position = Vector3(INF, 0.0, INF)
	if new_state != "trace_investigate":
		trace_investigation_timer = 0.0
		trace_investigation_position = Vector3(INF, 0.0, INF)
	if new_state != "danger_avoid":
		danger_memory_timer = 0.0
		danger_memory_position = Vector3(INF, 0.0, INF)
	if new_state == "hunt" and is_instance_valid(target):
		last_known_target_position = target.global_position
		has_last_known_target_position = true


func _has_escape_cover() -> bool:
	return escape_cover_position.x != INF and not _collapse_competition_active()


func _has_escape_habitat() -> bool:
	return escape_habitat_position.x != INF and not _collapse_competition_active()


func _has_escape_intervention(threat: EcoActor) -> bool:
	return is_instance_valid(escape_intervention_actor) and not escape_intervention_actor.dead and escape_intervention_actor != threat and escape_intervention_position.x != INF and ecology_leverage_cooldown <= 0.0 and not _collapse_competition_active()


func _prepare_escape_intervention(threat: EcoActor) -> void:
	escape_intervention_actor = null
	escape_intervention_position = Vector3(INF, 0.0, INF)
	if not is_instance_valid(threat) or _collapse_competition_active():
		return
	var responder := ecology_leverage_candidate(threat, ECOLOGY_LEVERAGE_RADIUS + 4.0)
	if not is_instance_valid(responder):
		return
	escape_intervention_actor = responder
	var away_from_threat := Vector3(responder.global_position.x - threat.global_position.x, 0.0, responder.global_position.z - threat.global_position.z).normalized()
	if away_from_threat.length() < 0.1:
		away_from_threat = Vector3.RIGHT if actor_id % 2 == 0 else Vector3.LEFT
	escape_intervention_position = responder.global_position + away_from_threat * 2.2


func _prepare_escape_cover(threat: EcoActor) -> void:
	escape_cover_position = Vector3(INF, 0.0, INF)
	if not is_instance_valid(threat) or game.world == null or not game.world.has_method("best_escape_cover") or int(data["size"]) > 3 or _collapse_competition_active():
		return
	var search_radius := 12.0 + float(3 - mini(int(data["size"]), 3)) * 1.8
	escape_cover_position = game.world.best_escape_cover(global_position, threat.global_position, species_id, search_radius)


func _prepare_escape_habitat(threat: EcoActor) -> void:
	escape_habitat_position = Vector3(INF, 0.0, INF)
	if not is_instance_valid(threat) or game.world == null or not game.world.has_method("best_counter_habitat") or _collapse_competition_active():
		return
	if Catalog.opportunity_threat_gap(species_id, threat.species_id) <= 0:
		return
	var search_radius := 16.0 + float(4 - mini(int(data["size"]), 4)) * 1.5
	escape_habitat_position = game.world.best_counter_habitat(global_position, threat.global_position, species_id, threat.species_id, search_radius)


func _can_detect_actor(other: EcoActor, base_range: float = 27.0) -> bool:
	if not is_instance_valid(other) or other.dead:
		return false
	var distance := global_position.distance_to(other.global_position)
	var close_reveal := COVER_CLOSE_REVEAL_DISTANCE + float(int(data["size"])) * 0.28
	if distance <= close_reveal:
		return true
	var detect_range := base_range
	detect_range *= threat_perception_multiplier
	if game.world != null and game.world.has_method("perception_multiplier"):
		detect_range *= game.world.perception_multiplier(species_id)
	if other.is_cover_concealed():
		detect_range *= 0.36
	elif other.is_stealthed():
		detect_range *= 0.60
	if other.has_habit_buff("conceal"):
		detect_range *= 0.76
	if other.scent_mark_timer > 0.0:
		detect_range *= 1.65
	if Catalog.has_trait(species_id, "finisher") and other.health / other.max_health < 0.30:
		detect_range *= 1.6
	return distance <= detect_range


func _skill_engage_range() -> float:
	match species_id:
		"fox": return 5.4
		"wolf": return 5.1
		"snake": return 2.1
		"bear": return 3.4
		"boar": return 5.8
		"raccoon": return 4.8
		"porcupine": return 3.8
		"lynx": return 5.9
		"capybara": return 8.5
		"otter": return 5.8
		"goat": return 5.8
		"wolverine": return 5.5
		"bison": return 6.0
		"zebra": return 5.4
		"elephant": return 5.8
		"crocodile": return 2.9
		"tiger": return 6.5
		"monkey": return 8.8
		"owl": return 8.8
		"moose": return 3.8
		"turtle": return 4.2
		"cheetah": return 8.8
		"rhino": return 7.2
		"gorilla": return 4.5
		"eagle": return 10.2
		"hippo": return 3.8
		"hyena": return 5.5
		"lion": return 6.3
		_: return 5.2


func _best_food_resource(living_actors: Array[EcoActor] = []) -> Node3D:
	var candidates: Array[EcoActor] = living_actors
	if candidates.is_empty():
		candidates = game.get_living_actors()
	var corpse: Node3D
	if Catalog.can_eat_corpse(species_id):
		var corpse_range := 34.0
		if Catalog.has_trait(species_id, "scavenger"):
			corpse_range *= 1.55 if species_id == "raccoon" else 1.36
		corpse = game.nearest_corpse(global_position, corpse_range)
	if is_instance_valid(corpse) and _corpse_is_safe(corpse, candidates):
		return corpse
	if Catalog.can_eat_food(species_id):
		return _best_wild_food(30.0)
	var wild_meat: Node3D = _best_wild_food(26.0)
	if is_instance_valid(wild_meat):
		return wild_meat
	return null


func _best_habit_food(search_range: float, living_actors: Array[EcoActor] = []) -> Node3D:
	var favored_foods := Catalog.habit_favored_foods(species_id)
	if favored_foods.is_empty():
		return null
	var candidates: Array[EcoActor] = living_actors
	if candidates.is_empty():
		candidates = game.get_living_actors()
	if "corpse" in favored_foods and Catalog.can_eat_corpse(species_id):
		var corpse: Node3D = game.nearest_corpse(global_position, search_range * (1.30 if Catalog.has_trait(species_id, "scavenger") else 1.0))
		if is_instance_valid(corpse) and not habit_rewarded_sources.has(_habit_source_key(corpse)) and _corpse_is_safe(corpse, candidates):
			return corpse
	var has_patch_favorite := false
	for food_kind in favored_foods:
		if food_kind != "corpse":
			has_patch_favorite = true
			break
	if not has_patch_favorite or game.world == null or not (game.world is EcoWorld):
		return null
	var origin := global_position if is_inside_tree() else position
	var best_patch: FoodPatch
	var best_score := INF
	var hotspot_risk := str(game.ecology_hotspot_risk_level()) if game.has_method("ecology_hotspot_risk_level") else "平稳"
	var risk_averse := int(data["size"]) <= 3 and float(data["courage"]) < 0.50 and hunger < 78.0
	for candidate_node in game.world.food_patches:
		if not is_instance_valid(candidate_node) or candidate_node.is_queued_for_deletion() or not candidate_node is FoodPatch:
			continue
		var patch := candidate_node as FoodPatch
		if not patch.active or patch.food_kind not in favored_foods or not patch.can_be_eaten_by(species_id):
			continue
		if habit_rewarded_sources.has(_habit_source_key(patch)):
			continue
		if patch.ecology_hotspot and hotspot_risk == "高危" and risk_averse:
			continue
		var distance := origin.distance_to(patch.global_position)
		if distance > search_range:
			continue
		var affinity := Catalog.habitat_affinity(species_id, game.world.region_id_at(patch.global_position))
		var score := distance / (1.0 + affinity * 0.28)
		if score < best_score:
			best_score = score
			best_patch = patch
	return best_patch


func _habit_source_key(resource: Node3D) -> String:
	return str(resource.get_instance_id()) if is_instance_valid(resource) else ""


func _corpse_is_safe(corpse: Node3D, living_actors: Array[EcoActor]) -> bool:
	var danger_count := 0
	var nearby_pack := 0
	var own_presence := _ecology_combat_presence(self)
	for other in living_actors:
		if other == self or other.dead:
			continue
		var distance := corpse.global_position.distance_to(other.global_position)
		if other.species_id == species_id and distance <= 10.0:
			nearby_pack += 1
			continue
		if distance > 9.0:
			continue
		var threatens_self := Catalog.considers_prey(other.species_id, species_id)
		var stronger_competitor := Catalog.can_eat_corpse(other.species_id) and _ecology_combat_presence(other) > own_presence * 1.08
		if threatens_self or stronger_competitor:
			danger_count += 1
	return should_approach_contested_food(danger_count, float(data["courage"]), health / maxf(max_health, 1.0), hunger, Catalog.has_trait(species_id, "scavenger"), nearby_pack)


func _best_wild_food(search_range: float) -> Node3D:
	var origin := global_position if is_inside_tree() else position
	var candidate: Node3D = game.nearest_food(origin, search_range, species_id)
	if not is_instance_valid(candidate) or not candidate is FoodPatch or not candidate.ecology_hotspot:
		return candidate
	var risk := str(game.ecology_hotspot_risk_level()) if game.has_method("ecology_hotspot_risk_level") else "平稳"
	var risk_averse := int(data["size"]) <= 3 and float(data["courage"]) < 0.50 and hunger < 78.0
	if risk != "高危" or not risk_averse:
		return candidate
	var safer_food: Node3D = game.nearest_food(origin, search_range, species_id, false)
	return safer_food if is_instance_valid(safer_food) else null


func _begin_ecology_trace_investigation() -> bool:
	if game.world == null or game.world.collapse_active:
		return false
	var origin := global_position if is_inside_tree() else position
	var search_range := 22.0 + float(data["aggression"]) * 11.0
	if Catalog.has_trait(species_id, "finisher") or Catalog.has_trait(species_id, "scavenger"):
		search_range += 7.0
	var trace: Dictionary = game.world.best_prey_trace(actor_id, species_id, origin, search_range, last_investigated_trace_sequence)
	if trace.is_empty():
		return false
	var trace_position: Vector3 = trace.get("position", origin)
	var territory_restricted := Catalog.has_trait(species_id, "territorial") and territory_radius > 0.0 and territory_center.distance_to(trace_position) > territory_radius * 1.35
	if not should_investigate_ecology_trace(hunger, float(data["aggression"]), health / maxf(max_health, 1.0), stamina / maxf(max_stamina, 1.0), Catalog.has_trait(species_id, "scavenger"), territory_restricted):
		return false
	ai_state = "trace_investigate"
	ai_target = null
	resource_target = null
	trace_investigation_position = trace_position
	trace_investigation_timer = ECOLOGY_TRACE_INVESTIGATION_SECONDS
	last_investigated_trace_sequence = int(trace.get("sequence", last_investigated_trace_sequence))
	state_commit_timer = 0.65
	if game.has_method("on_ecology_trace_investigation"):
		game.on_ecology_trace_investigation(self, trace)
	return true


func _begin_danger_memory_avoidance() -> bool:
	if game.world == null or game.world.collapse_active:
		return false
	if not should_avoid_danger_memory(float(data["courage"]), hunger, health / maxf(max_health, 1.0), int(data["size"]), Catalog.has_trait(species_id, "scavenger")):
		return false
	var origin := global_position if is_inside_tree() else position
	var awareness_range := 10.0 + float(3 - mini(int(data["size"]), 3)) * 2.2
	var memory: Dictionary = game.world.nearest_danger_memory(origin, awareness_range, avoided_danger_sequences)
	if memory.is_empty():
		return false
	avoided_danger_sequences[str(int(memory.get("sequence", 0)))] = true
	danger_memory_position = memory.get("position", origin)
	danger_memory_timer = DANGER_MEMORY_AVOID_SECONDS
	ai_state = "danger_avoid"
	ai_target = null
	resource_target = null
	state_commit_timer = 0.55
	if game.has_method("on_danger_memory_avoidance"):
		game.on_danger_memory_avoidance(self, memory)
	return true


func _begin_ecology_hotspot_stalk() -> bool:
	if game.world == null or game.world.collapse_active or not game.has_method("ecology_hotspot_prey_signal_count"):
		return false
	var event: Dictionary = game.world.get_active_ecology_event()
	if event.is_empty():
		return false
	var sequence := int(event.get("sequence", -1))
	var prey_signals := int(game.ecology_hotspot_prey_signal_count(self))
	var can_feed: bool = game.world.species_can_feed_at_active_event(species_id)
	var event_position: Vector3 = event.get("position", position)
	var territory_restricted := Catalog.has_trait(species_id, "territorial") and territory_radius > 0.0 and territory_center.distance_to(event_position) > territory_radius * 1.35
	if not should_follow_hotspot_signal(hunger, float(data["aggression"]), health / maxf(max_health, 1.0), stamina / maxf(max_stamina, 1.0), prey_signals, can_feed, territory_restricted, actor_id, sequence):
		return false
	var ambush_position: Vector3 = game.world.ecology_ambush_position(actor_id)
	if ambush_position.x == INF:
		return false
	ai_state = "hotspot_stalk"
	ai_target = null
	resource_target = null
	hotspot_event_sequence = sequence
	hotspot_stalk_position = ambush_position
	state_commit_timer = 0.65
	return true


func is_migrating_to_ecology_hotspot(event_sequence: int, event_position: Vector3, event_radius: float) -> bool:
	if dead:
		return false
	if ai_state == "food" and is_instance_valid(resource_target) and resource_target is FoodPatch and resource_target.ecology_hotspot and resource_target.ecology_event_id == event_sequence:
		return true
	var origin := global_position if is_inside_tree() else position
	return origin.distance_to(event_position) <= event_radius + 3.0 and game.world != null and game.world.species_can_feed_at_active_event(species_id)


func is_stalking_ecology_hotspot(event_sequence: int) -> bool:
	return not dead and ai_state == "hotspot_stalk" and hotspot_event_sequence == event_sequence


func _best_prey(living_actors: Array[EcoActor] = [], target_pressure_counts: Dictionary = {}, pack_support: int = -1) -> EcoActor:
	var candidates: Array[EcoActor] = living_actors
	if candidates.is_empty():
		candidates = game.get_living_actors()
	var support_count := pack_support
	if support_count < 0:
		support_count = 0
		if Catalog.has_trait(species_id, "pack_hunter"):
			for candidate in candidates:
				if candidate != self and not candidate.dead and candidate.species_id == species_id and global_position.distance_to(candidate.global_position) <= AI_PACK_SHARE_RADIUS:
					support_count += 1
	var best: EcoActor
	var best_score := -INF
	for other in candidates:
		if other == self or other.dead or other.spawn_protection > 0.0:
			continue
		var considers_target: bool = Catalog.considers_prey(species_id, other.species_id)
		var brave_opportunity: bool = Catalog.has_trait(species_id, "brave_vs_large") and other.is_opportunity_exposed() and Catalog.opportunity_threat_gap(species_id, other.species_id) > 0
		if not considers_target and not brave_opportunity:
			continue
		if other.is_airborne() and not Catalog.has_trait(species_id, "flying"):
			continue
		if not _can_detect_actor(other):
			continue
		var score := _prey_utility(other, support_count, int(target_pressure_counts.get(other.actor_id, 0)))
		if other.scent_mark_timer > 0.0:
			score *= 1.35
		if other.is_opportunity_exposed():
			score *= 1.18 + float(Catalog.opportunity_threat_gap(species_id, other.species_id)) * 0.10
		if score >= AI_MIN_PREY_UTILITY and score > best_score:
			best_score = score
			best = other
	return best


func _prey_utility(target: EcoActor, pack_support: int = 0, target_pressure: int = 0) -> float:
	if not is_instance_valid(target) or target.dead:
		return 0.0
	var target_region: String = game.world.region_id_at(target.global_position) if game.world != null and game.world.has_method("region_id_at") else ""
	var habitat_delta := 0.0
	if target_region != "":
		habitat_delta = Catalog.habitat_affinity(species_id, target_region) - Catalog.habitat_affinity(target.species_id, target_region)
	var context := {
		"hunter_health": health / maxf(max_health, 1.0),
		"hunter_stamina": stamina / maxf(max_stamina, 1.0),
		"target_health": target.health / maxf(target.max_health, 1.0),
		"target_stamina": target.stamina / maxf(target.max_stamina, 1.0),
		"hunger": hunger / 100.0,
		"aggression": float(data["aggression"]),
		"distance": global_position.distance_to(target.global_position),
		"speed_ratio": float(data["speed"]) / maxf(float(target.data["speed"]), 0.1),
		"tier_delta": Catalog.combat_tier(species_id) - Catalog.combat_tier(target.species_id),
		"size_delta": int(data["size"]) - int(target.data["size"]),
		"support": pack_support,
		"target_pressure": target_pressure,
		"habitat_delta": habitat_delta,
		"threat_gap": Catalog.opportunity_threat_gap(species_id, target.species_id),
		"target_exposed": target.is_opportunity_exposed(),
		"finisher": Catalog.has_trait(species_id, "finisher"),
		"pack_hunter": Catalog.has_trait(species_id, "pack_hunter"),
		"scavenger": Catalog.has_trait(species_id, "scavenger"),
		"ambush_ready": has_cover_ambush(),
		"aerial_small_prey": Catalog.has_trait(species_id, "flying") and int(target.data["size"]) <= 2,
		"attack_range": float(data["attack_range"]),
	}
	return evaluate_prey_utility(context)


func _apply_movement(delta: float) -> void:
	var flat_direction := Vector3(desired_direction.x, 0.0, desired_direction.z).normalized()
	var is_flying := Catalog.has_trait(species_id, "flying")
	var canopy_height_active := Catalog.has_trait(species_id, "canopy_mover") and (canopy_timer > 0.0 or global_position.y > 0.58)
	var uses_height_domain := is_flying or canopy_height_active
	if uses_height_domain and flight_target_height < 1.0:
		var landing_offset := landing_target_position - global_position
		var landing_flat := Vector3(landing_offset.x, 0.0, landing_offset.z)
		if landing_flat.length() > 0.55:
			flat_direction = (flat_direction * 0.42 + landing_flat.normalized() * 0.92).normalized()
	if not is_player and game.world != null and game.world.collapse_active:
		var center_distance := Vector2(global_position.x, global_position.z).length()
		if center_distance > game.world.collapse_radius:
			var toward_center := Vector3(-global_position.x, 0.0, -global_position.z).normalized()
			flat_direction = (flat_direction + toward_center * 1.25).normalized()
	if not is_player and game.world != null and flat_direction.length() > 0.1 and (not uses_height_domain or global_position.y < 1.35):
		var steering_radius := 0.52 + int(data["size"]) * 0.09
		if Catalog.has_trait(species_id, "climber"):
			steering_radius *= 0.80
		var look_ahead_scale := 1.72 if species_id == "cheetah" else 1.0
		flat_direction = game.world.steer_around_obstacles(global_position, flat_direction, steering_radius, actor_id, look_ahead_scale)
	if avoid_timer > 0.0 and not is_player:
		avoid_timer -= delta
		flat_direction = (flat_direction + avoid_direction * 1.3).normalized()
	if not is_player:
		movement_sample_timer += delta
		if movement_sample_timer >= 0.55:
			var moved := global_position.distance_to(last_sample_position)
			if desired_direction.length() > 0.2 and moved < 0.16:
				stuck_duration += movement_sample_timer
			else:
				stuck_duration = maxf(stuck_duration - movement_sample_timer * 1.5, 0.0)
			last_sample_position = global_position
			movement_sample_timer = 0.0
			if stuck_duration > 0.85:
				var side_sign := -1.0 if behavior_rng.randi_range(0, 1) == 0 else 1.0
				recovery_direction = flat_direction.rotated(Vector3.UP, side_sign * PI * 0.62).normalized()
				recovery_timer = 0.9
				stuck_duration = 0.0
		if recovery_timer > 0.0:
			flat_direction = recovery_direction
		if flat_direction.length() > 0.05:
			smoothed_move_direction = smoothed_move_direction.lerp(flat_direction, 1.0 - exp(-delta * 7.0)).normalized()
			flat_direction = smoothed_move_direction
		else:
			smoothed_move_direction = smoothed_move_direction.lerp(Vector3.ZERO, 1.0 - exp(-delta * 10.0))
	if shell_guard_timer > 0.0:
		flat_direction = Vector3.ZERO
		wants_sprint = false
	var water_depth: float = game.world.water_depth_at(global_position) if game.world != null and game.world.has_method("water_depth_at") else 0.0
	var in_wetland: bool = water_depth > 0.01
	var speed := float(data["speed"])
	if game.world != null and game.world.has_method("movement_multiplier"):
		speed *= game.world.movement_multiplier(species_id, global_position)
	if not uses_height_domain and in_wetland and Catalog.has_trait(species_id, "wetland_swimmer"):
		speed *= float(data.get("wetland_speed", 1.0))
	elif not uses_height_domain and water_depth > 0.45:
		speed *= 0.68 if not Catalog.has_trait(species_id, "giant") else 0.84
	elif not uses_height_domain and in_wetland:
		speed *= 0.90
	if forage_speed_timer > 0.0:
		speed *= 1.16
	if has_habit_buff("escape"):
		speed *= 1.08
	if slow_timer > 0.0:
		speed *= slow_multiplier
	if species_id == "cheetah" and burst_exhaustion_timer > 0.0 and dash_timer <= 0.0:
		speed *= 0.70
	var sprinting := wants_sprint and not exhausted and stamina > 0.0 and flat_direction.length() > 0.1
	if sprinting and flat_direction.dot(previous_flat_direction) > 0.9:
		straight_run_timer += delta
	else:
		straight_run_timer = 0.0
	previous_flat_direction = flat_direction
	if sprinting:
		speed *= float(data["sprint"])
		var sprint_cost := 8.5 + int(data["size"]) * 1.7
		if Catalog.has_trait(species_id, "straight_runner") and straight_run_timer > 2.0:
			sprint_cost *= 0.82
		if has_habit_buff("escape"):
			sprint_cost *= 0.82
		if not uses_height_domain and in_wetland and Catalog.has_trait(species_id, "wetland_swimmer"):
			sprint_cost *= 0.70
		elif not uses_height_domain and water_depth > 0.45:
			sprint_cost *= 1.25
		if is_flying and game.world != null and game.world.has_method("flight_stamina_multiplier"):
			sprint_cost *= game.world.flight_stamina_multiplier()
		if game.world != null and game.world.has_method("stamina_cost_multiplier"):
			sprint_cost *= game.world.stamina_cost_multiplier(species_id, global_position)
		stamina = maxf(stamina - sprint_cost * delta, 0.0)
	elif can_regenerate_stamina(sprinting, stamina_regen_delay):
		var hunger_factor := 1.0 if hunger < 60.0 else (0.85 if hunger < 80.0 else 0.65)
		var environment_regen: float = float(game.world.stamina_regen_multiplier(species_id, global_position)) if game.world != null and game.world.has_method("stamina_regen_multiplier") else 1.0
		var habit_regen := 1.30 if has_habit_buff("recover") else 1.0
		stamina = minf(stamina + float(data["regen"]) * hunger_factor * environment_regen * habit_regen * delta * (1.0 if flat_direction.length() < 0.1 else 0.70), max_stamina)
	if dash_timer > 0.0:
		dash_timer -= delta
		flat_direction = dash_direction
		var dash_factor := 2.85 if species_id == "cheetah" else (2.55 if is_flying else 2.25)
		var environment_factor: float = game.world.movement_multiplier(species_id, global_position) if game.world != null and game.world.has_method("movement_multiplier") else 1.0
		speed = float(data["speed"]) * dash_factor * environment_factor * (float(data.get("wetland_speed", 1.0)) if in_wetland and not is_flying else 1.0)
	velocity.x = move_toward(velocity.x, flat_direction.x * speed, delta * speed * 8.0)
	velocity.z = move_toward(velocity.z, flat_direction.z * speed, delta * speed * 8.0)
	if uses_height_domain:
		var vertical_offset := flight_target_height - global_position.y
		velocity.y = move_toward(velocity.y, clampf(vertical_offset * 3.8, -6.4, 6.4), delta * 18.0)
		collision_mask = 0 if global_position.y > 1.30 or flight_target_height > 1.30 else 2
	elif not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.8
	move_and_slide()
	var wall_normal := Vector3.ZERO
	if not is_player or Catalog.has_trait(species_id, "obstacle_breaker"):
		for collision_index in range(get_slide_collision_count()):
			var candidate_normal := get_slide_collision(collision_index).get_normal()
			if absf(candidate_normal.y) < 0.55:
				wall_normal = candidate_normal
				break
	if wall_normal.length() > 0.1 and Catalog.has_trait(species_id, "obstacle_breaker") and obstacle_break_timer <= 0.0 and game.world != null and game.world.has_method("flatten_light_obstacles_near"):
		var break_origin := global_position + flat_direction * 1.25
		var flattened: int = game.world.flatten_light_obstacles_near(break_origin, 1.8, 1)
		if flattened > 0:
			obstacle_break_timer = 3.5
			if is_player:
				game.show_hint("巨体推倒了挡路的小树，新的通路已经打开")
	if wall_normal.length() > 0.1 and not is_player:
		wander_direction = wander_direction.rotated(Vector3.UP, 1.3 + actor_id * 0.07)
		wander_timer = 0.9
		if ai_state != "wander" and avoid_timer <= 0.0:
			var side := wall_normal.cross(Vector3.UP)
			if side.dot(flat_direction) < 0.0:
				side = -side
			avoid_direction = side.normalized()
			avoid_timer = 0.5
	if game.world != null:
		global_position = game.world.clamp_position(global_position)
	if uses_height_domain:
		var maximum_height := float(data.get("flight_height", 4.2)) + 0.65 if is_flying else 3.75
		global_position.y = clampf(global_position.y, 0.42, maximum_height)
		if is_instance_valid(pending_food_resource) and global_position.y < 0.92 and global_position.distance_to(pending_food_resource.global_position) <= 2.6:
			try_consume_resource(pending_food_resource)
			pending_food_resource = null
	if flat_direction.length() > 0.12:
		var target_angle := atan2(-flat_direction.x, -flat_direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 1.0 - exp(-delta * (7.0 if int(data["size"]) < 4 else 4.2)))
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	still_timer = still_timer + delta if flat_speed < 0.35 else 0.0
	_update_exhaustion_state()
	if is_player:
		stamina_changed.emit(stamina, max_stamina)
	_update_ecology_trace(delta, sprinting, flat_direction)


func _update_ecology_trace(delta: float, sprinting: bool, move_direction: Vector3) -> void:
	if game.world == null:
		return
	ecology_trace_emit_timer -= delta
	if ecology_trace_emit_timer > 0.0:
		return
	var moved_distance := global_position.distance_to(ecology_trace_last_position)
	var injured := health / maxf(max_health, 1.0) < 0.65 or poison_timer > 0.0
	var scent_marked := scent_mark_timer > 0.0
	var concealed := is_cover_concealed()
	var airborne := is_airborne()
	if WorldRules.should_record_ecology_trace(moved_distance, concealed, sprinting, injured, scent_marked, airborne):
		game.world.record_movement_trace(actor_id, species_id, global_position, move_direction, injured, sprinting, scent_marked)
	ecology_trace_last_position = global_position
	ecology_trace_emit_timer = ECOLOGY_TRACE_INTERVAL + fmod(float(actor_id) * 0.071, 0.34)


func _try_attack() -> void:
	if not attack_intent or exhausted or attack_timer > 0.0 or stamina < float(data["attack_cost"]):
		return
	if is_airborne():
		_request_landing(1.15)
		return
	if calm_timer > 0.0 and hunger < 70.0:
		attack_intent = false
		return
	if shell_guard_timer > 0.0:
		attack_intent = false
		return
	var target := ai_target if not is_player else _nearest_living_actor(float(data["attack_range"]) + 0.9)
	if not is_instance_valid(target) or target.dead:
		return
	var reach := float(data["attack_range"]) + (int(data["size"]) + int(target.data["size"])) * 0.08
	if global_position.distance_to(target.global_position) > reach:
		return
	attack_timer = float(data["attack_interval"])
	spawn_protection = 0.0
	var attack_cost := float(data["attack_cost"])
	if Catalog.has_trait(species_id, "pack_hunter"):
		var nearby_pack := 0
		for other in game.get_living_actors():
			if other != self and other.species_id == species_id and global_position.distance_to(other.global_position) < 12.0:
				nearby_pack += 1
		attack_cost *= 1.0 - mini(nearby_pack, 3) * 0.06
	stamina -= attack_cost
	stamina_regen_delay = STAMINA_REGEN_COMBAT_DELAY
	_update_exhaustion_state()
	var damage := float(data["attack"])
	if not is_player:
		damage *= game.get_ai_damage_multiplier()
	if Catalog.has_trait(species_id, "finisher") and target.health / target.max_health < 0.30:
		damage *= 1.12
	if Catalog.has_trait(species_id, "brave_vs_large") and int(target.data["size"]) > int(data["size"]):
		damage *= 1.12
	if rage_timer > 0.0:
		damage *= 1.1
	if has_habit_buff("hunt"):
		damage *= 1.08
	ambush_attack_armed = has_cover_ambush()
	terrain_attack_armed = not ambush_attack_armed and can_terrain_counter(target)
	target.take_damage(damage, self)
	ambush_attack_armed = false
	if terrain_attack_armed:
		terrain_momentum = 0.0
		terrain_counter_cooldown = TERRAIN_COUNTER_COOLDOWN
	terrain_attack_armed = false
	_break_cover()
	if game.has_method("play_sfx_near"):
		game.play_sfx_near("attack", global_position, is_player)
	_play_attack_pulse()


func use_skill(target: EcoActor = null) -> bool:
	if dead or exhausted or skill_timer > 0.0 or stamina < float(data["skill_cost"]):
		return false
	# Normal attacks already honor calm_timer. Skills must follow the same rule,
	# otherwise a fleeing animal can deal the first damage during the teaching
	# establishment window and wake the whole food chain several seconds in.
	if calm_timer > 0.0 and hunger < 70.0 and is_instance_valid(target) and target != last_attacker:
		return false
	var used := false
	var affected_count := 0
	var effect_color := Color.from_string(str(data.get("skill_color", "#9fe7bf")), Color("#9fe7bf"))
	var effect_parent := _skill_effect_parent()
	match species_id:
		"rabbit":
			var direction := desired_direction if desired_direction.length() > 0.1 else -transform.basis.z
			dash_direction = Vector3(direction.x, 0.0, direction.z).normalized()
			dash_timer = 0.38
			hidden_timer = 1.35
			for other in game.get_living_actors():
				if other != self and not other.is_player and other.ai_target == self:
					other.ai_target = null
					other.ai_state = "wander"
					other.state_commit_timer = 1.10
					affected_count += 1
			SkillVFX.dash_trail(effect_parent, global_position, dash_direction, effect_color, 3.4)
			SkillVFX.radial_burst(effect_parent, global_position, effect_color, 2.2, 10, 0.13, 0.38)
			SkillVFX.ring(effect_parent, global_position, effect_color, 0.42, 2.25, 0.34)
			used = true
		"fox":
			if is_instance_valid(target) and global_position.distance_to(target.global_position) < 5.5:
				dash_direction = (target.global_position - global_position).normalized()
				dash_timer = 0.28
				SkillVFX.dash_trail(effect_parent, global_position, dash_direction, effect_color, 3.2)
				target.take_damage(_skill_damage(1.25), self)
				target.apply_scent_mark(7.0, self, effect_color)
				affected_count = _broadcast_scent(target, 17.0, 3)
				SkillVFX.fang_strike(effect_parent, target.global_position, dash_direction, effect_color, 1.15)
				SkillVFX.radial_burst(effect_parent, target.global_position, Color("#d94d45"), 1.6, 8, 0.14, 0.34)
				used = true
		"deer":
			for other in game.get_living_actors():
				if other == self or other.dead:
					continue
				var deer_distance := global_position.distance_to(other.global_position)
				if deer_distance < 3.1:
					other.take_damage(_skill_damage(1.35), self)
					other.apply_knockback((other.global_position - global_position).normalized(), 8.2)
					used = true
				if deer_distance < 7.2 and int(other.data["size"]) <= int(data["size"]):
					other.apply_panic(self, 2.35)
					affected_count += 1
					used = true
			if used:
				SkillVFX.ring(effect_parent, global_position, effect_color, 0.55, 3.4, 0.38)
				SkillVFX.ring(effect_parent, global_position, effect_color.lightened(0.18), 0.60, 5.7, 0.48, 0.12)
				SkillVFX.radial_burst(effect_parent, global_position, effect_color, 3.1, 12, 0.18, 0.44, 0.28)
		"wolf":
			if is_instance_valid(target) and global_position.distance_to(target.global_position) < 5.2:
				dash_direction = (target.global_position - global_position).normalized()
				dash_timer = 0.32
				SkillVFX.dash_trail(effect_parent, global_position, dash_direction, effect_color, 3.5)
				target.take_damage(_skill_damage(1.40), self)
				affected_count = _rally_pack(target, 18.0)
				SkillVFX.fang_strike(effect_parent, target.global_position, dash_direction, effect_color, 1.28)
				SkillVFX.ring(effect_parent, global_position, effect_color, 0.72, 4.1, 0.42)
				SkillVFX.ring(effect_parent, global_position, effect_color, 0.72, 5.5, 0.48, 0.12)
				used = true
		"snake":
			if is_instance_valid(target) and global_position.distance_to(target.global_position) < 2.2:
				var strike_direction := (target.global_position - global_position).normalized()
				target.take_damage(_skill_damage(0.82), self)
				target.apply_poison(_skill_damage(0.42), 6.0, self)
				target.apply_slow(0.78, 4.5)
				target.apply_scent_mark(5.5, self, effect_color)
				affected_count = _broadcast_scent(target, 14.0, 2)
				SkillVFX.fang_strike(effect_parent, target.global_position, strike_direction, effect_color, 0.92)
				SkillVFX.radial_burst(effect_parent, target.global_position, effect_color, 1.9, 11, 0.12, 0.48, 0.16)
				used = true
		"bear":
			for other in game.get_living_actors():
				if other == self or other.dead:
					continue
				var bear_distance := global_position.distance_to(other.global_position)
				if bear_distance < 3.8:
					var bear_damage: float = _skill_damage(1.35)
					if rage_timer > 0.0:
						bear_damage *= 1.1
					other.take_damage(bear_damage, self)
					other.apply_knockback((other.global_position - global_position).normalized(), 9.0)
					used = true
				if bear_distance < 7.0 and int(other.data["size"]) < int(data["size"]):
					other.apply_panic(self, 2.8)
					affected_count += 1
					used = true
			if used:
				SkillVFX.ground_spokes(effect_parent, global_position, effect_color.darkened(0.24), 4.5, 11)
				SkillVFX.ring(effect_parent, global_position, effect_color, 0.75, 3.7, 0.38)
				SkillVFX.ring(effect_parent, global_position, effect_color.lightened(0.15), 0.80, 6.2, 0.56, 0.10)
				SkillVFX.radial_burst(effect_parent, global_position, Color("#9b7048"), 4.3, 14, 0.24, 0.55)
		"boar":
			if is_instance_valid(target) and global_position.distance_to(target.global_position) < 5.9:
				dash_direction = (target.global_position - global_position).normalized()
				dash_timer = 0.40
				target.take_damage(_skill_damage(1.38), self)
				target.apply_knockback(dash_direction, 8.5)
				SkillVFX.dash_trail(effect_parent, global_position, dash_direction, effect_color, 3.8)
				SkillVFX.fang_strike(effect_parent, target.global_position, dash_direction, effect_color, 1.20)
				used = true
		"raccoon":
			var stolen_resource := _best_food_resource()
			if is_instance_valid(stolen_resource) and global_position.distance_to(stolen_resource.global_position) < 4.6:
				var stolen_amount: float = stolen_resource.consume(24.0)
				if stolen_amount > 0.0:
					var nutrition: float = stolen_resource.get_nutrition_multiplier() if stolen_resource is FoodPatch else 1.0
					hunger = maxf(hunger - stolen_amount * 0.95 * nutrition, 0.0)
					health = minf(health + stolen_amount * 0.10 * nutrition, max_health)
					health_changed.emit(health, max_health)
					_update_health_bar()
					resource_target = null
					used = true
			if is_instance_valid(target) and global_position.distance_to(target.global_position) < 4.8:
				target.apply_slow(0.86, 1.2)
				affected_count += 1
				used = true
			if used:
				var escape_direction := desired_direction
				if is_instance_valid(target):
					escape_direction = global_position - target.global_position
				if escape_direction.length() < 0.1:
					escape_direction = -transform.basis.z
				dash_direction = Vector3(escape_direction.x, 0.0, escape_direction.z).normalized()
				dash_timer = 0.42
				hidden_timer = 0.75
				forage_speed_timer = 3.2
				SkillVFX.dash_trail(effect_parent, global_position, dash_direction, effect_color, 3.7)
				SkillVFX.radial_burst(effect_parent, global_position, effect_color, 2.0, 9, 0.13, 0.36)
		"porcupine":
			quill_guard_timer = 4.5
			used = true
			for other in game.get_living_actors():
				if other == self or other.dead:
					continue
				var quill_distance := global_position.distance_to(other.global_position)
				if quill_distance < 3.4:
					other.take_damage(_skill_damage(0.62), self)
					other.apply_knockback((other.global_position - global_position).normalized(), 6.4)
					affected_count += 1
			SkillVFX.ring(effect_parent, global_position, effect_color, 0.55, 3.5, 0.42)
			SkillVFX.radial_burst(effect_parent, global_position, effect_color.lightened(0.15), 3.2, 16, 0.16, 0.50, 0.24)
			if effect_parent != null:
				SkillVFX.status_aura(self, effect_color, 4.5, 0.78)
		"lynx":
			if is_instance_valid(target) and global_position.distance_to(target.global_position) < 6.0:
				dash_direction = (target.global_position - global_position).normalized()
				dash_timer = 0.34
				hidden_timer = 0.55
				target.take_damage(_skill_damage(1.48), self)
				target.apply_slow(0.72, 2.8)
				SkillVFX.dash_trail(effect_parent, global_position, dash_direction, effect_color, 4.1)
				SkillVFX.fang_strike(effect_parent, target.global_position, dash_direction, effect_color, 1.10)
				used = true
		"capybara":
			used = true
			stamina = minf(max_stamina, stamina + 12.0)
			for other in game.get_living_actors():
				if other == self or other.dead or global_position.distance_to(other.global_position) > 8.5:
					continue
				if other.hunger < 70.0:
					other.apply_calm(self, 4.2)
					affected_count += 1
				if other.species_id == "capybara":
					other.stamina = minf(other.max_stamina, other.stamina + 18.0)
			SkillVFX.ring(effect_parent, global_position, effect_color, 0.65, 4.5, 0.52)
			SkillVFX.ring(effect_parent, global_position, effect_color.lightened(0.22), 0.82, 8.2, 0.72, 0.10)
			SkillVFX.radial_burst(effect_parent, global_position, effect_color, 3.3, 12, 0.16, 0.42, 0.22)
			if effect_parent != null:
				SkillVFX.status_aura(self, effect_color, 4.2, 0.92)
		"otter":
			if is_instance_valid(target) and global_position.distance_to(target.global_position) < 5.9:
				var otter_in_wetland: bool = game.world != null and game.world.has_method("water_depth_at") and game.world.water_depth_at(global_position) > 0.01
				dash_direction = (target.global_position - global_position).normalized()
				dash_timer = 0.56 if otter_in_wetland else 0.36
				target.take_damage(_skill_damage(1.26), self)
				target.apply_slow(0.70 if otter_in_wetland else 0.78, 2.8)
				if otter_in_wetland:
					stamina = minf(max_stamina, stamina + 13.0)
					hidden_timer = 0.55
				SkillVFX.dash_trail(effect_parent, global_position, dash_direction, effect_color, 4.8 if otter_in_wetland else 3.8)
				SkillVFX.ring(effect_parent, target.global_position, effect_color, 0.36, 2.6, 0.36)
				SkillVFX.radial_burst(effect_parent, target.global_position, effect_color.lightened(0.16), 2.3, 12, 0.12, 0.38, 0.14)
				used = true
		"goat":
			if is_instance_valid(target) and global_position.distance_to(target.global_position) < 5.9:
				dash_direction = (target.global_position - global_position).normalized()
				dash_timer = 0.38
				target.take_damage(_skill_damage(1.34), self)
				target.apply_knockback(dash_direction, 8.8)
				SkillVFX.dash_trail(effect_parent, global_position, dash_direction, effect_color, 4.2)
				SkillVFX.fang_strike(effect_parent, target.global_position, dash_direction, effect_color, 1.18)
				used = true
		"wolverine":
			if is_instance_valid(target) and global_position.distance_to(target.global_position) < 5.6:
				dash_direction = (target.global_position - global_position).normalized()
				dash_timer = 0.34
				var wolverine_factor := 1.72 if int(target.data["size"]) > int(data["size"]) else 1.42
				target.take_damage(_skill_damage(wolverine_factor), self)
				target.apply_slow(0.82, 2.0)
				stamina = minf(max_stamina, stamina + 12.0)
				SkillVFX.dash_trail(effect_parent, global_position, dash_direction, effect_color, 4.0)
				SkillVFX.fang_strike(effect_parent, target.global_position, dash_direction, effect_color, 1.26)
				SkillVFX.radial_burst(effect_parent, target.global_position, effect_color, 1.8, 8, 0.13, 0.33)
				used = true
		"bison":
			if is_instance_valid(target) and global_position.distance_to(target.global_position) < 6.1:
				dash_direction = (target.global_position - global_position).normalized()
				dash_timer = 0.48
				target.take_damage(_skill_damage(1.42), self)
				target.apply_knockback(dash_direction, 10.5)
				for other in game.get_living_actors():
					if other != self and other != target and not other.dead and int(other.data["size"]) < int(data["size"]) and global_position.distance_to(other.global_position) < 6.5:
						other.apply_panic(self, 2.0)
						affected_count += 1
				SkillVFX.ground_spokes(effect_parent, global_position, effect_color.darkened(0.15), 4.8, 10)
				SkillVFX.dash_trail(effect_parent, global_position, dash_direction, effect_color, 4.6)
				used = true
		"elephant":
			for other in game.get_living_actors():
				if other == self or other.dead:
					continue
				var elephant_distance := global_position.distance_to(other.global_position)
				if elephant_distance < 5.8:
					var stomp_factor := lerpf(1.15, 0.72, clampf(elephant_distance / 5.8, 0.0, 1.0))
					other.take_damage(_skill_damage(stomp_factor), self)
					other.apply_knockback((other.global_position - global_position).normalized(), 14.0)
					affected_count += 1
					used = true
				elif elephant_distance < 9.0 and int(other.data["size"]) < int(data["size"]):
					other.apply_panic(self, 3.2)
					affected_count += 1
					used = true
			if game.world != null and game.world.has_method("flatten_light_obstacles_near"):
				var broken_trees: int = game.world.flatten_light_obstacles_near(global_position, 5.6, 3)
				affected_count += broken_trees
				used = used or broken_trees > 0
			if used:
				SkillVFX.ground_spokes(effect_parent, global_position, effect_color.darkened(0.26), 7.2, 16)
				SkillVFX.ring(effect_parent, global_position, effect_color, 0.85, 5.8, 0.52)
				SkillVFX.ring(effect_parent, global_position, effect_color.lightened(0.14), 0.92, 9.0, 0.72, 0.10)
				SkillVFX.radial_burst(effect_parent, global_position, effect_color, 5.8, 16, 0.24, 0.55, 0.18)
		"zebra":
			var zebra_direction := desired_direction
			if is_instance_valid(target):
				zebra_direction = global_position - target.global_position
			if zebra_direction.length() < 0.1:
				zebra_direction = -transform.basis.z
			dash_direction = Vector3(zebra_direction.x, 0.0, zebra_direction.z).normalized()
			dash_timer = 0.52
			hidden_timer = 0.72
			used = true
			for other in game.get_living_actors():
				if other == self or other.dead or other.is_player or other.species_id != "zebra":
					continue
				if other.global_position.distance_to(global_position) > 10.0:
					continue
				other.ai_state = "flee"
				other.ai_target = target
				other.wander_direction = dash_direction
				other.stamina = minf(other.max_stamina, other.stamina + 10.0)
				other.state_commit_timer = maxf(other.state_commit_timer, 2.4)
				affected_count += 1
			SkillVFX.dash_trail(effect_parent, global_position, dash_direction, effect_color, 5.0)
			SkillVFX.ring(effect_parent, global_position, effect_color, 0.65, 4.5, 0.40)
		"crocodile":
			if is_instance_valid(target) and global_position.distance_to(target.global_position) < 3.0:
				var roll_direction := (target.global_position - global_position).normalized()
				target.take_damage(_skill_damage(1.72), self)
				target.apply_slow(0.56, 5.0)
				target.apply_knockback(roll_direction, 2.4)
				SkillVFX.ring(effect_parent, target.global_position, effect_color, 0.45, 2.3, 0.42)
				SkillVFX.fang_strike(effect_parent, target.global_position, roll_direction, effect_color, 1.42)
				used = true
		"tiger":
			if is_instance_valid(target) and global_position.distance_to(target.global_position) < 6.6:
				dash_direction = (target.global_position - global_position).normalized()
				dash_timer = 0.42
				target.take_damage(_skill_damage(1.68), self)
				for other in game.get_living_actors():
					if other != self and other != target and not other.dead and int(other.data["size"]) < int(data["size"]) and target.global_position.distance_to(other.global_position) < 5.4:
						other.apply_panic(self, 2.2)
						affected_count += 1
				SkillVFX.dash_trail(effect_parent, global_position, dash_direction, effect_color, 5.0)
				SkillVFX.fang_strike(effect_parent, target.global_position, dash_direction, effect_color, 1.52)
				SkillVFX.radial_burst(effect_parent, target.global_position, effect_color, 2.8, 12, 0.17, 0.42)
				used = true
		"monkey":
			if is_instance_valid(target) and global_position.distance_to(target.global_position) < 8.9:
				_spawn_skill_projectile(target, _skill_damage(1.28), effect_color)
				target.apply_scent_mark(5.0, self, effect_color)
				SkillVFX.radial_burst(effect_parent, global_position + Vector3.UP * 1.25, effect_color, 1.4, 8, 0.10, 0.28)
				used = true
			var entered_canopy := _try_enter_canopy(4.8)
			if entered_canopy:
				SkillVFX.ring(effect_parent, global_position, effect_color, 0.42, 2.8, 0.34)
				SkillVFX.radial_burst(effect_parent, global_position + Vector3.UP * 2.2, effect_color.lightened(0.16), 2.0, 10, 0.11, 0.36)
				used = true
		"owl":
			if is_instance_valid(target):
				var owl_planar_distance := Vector2(global_position.x - target.global_position.x, global_position.z - target.global_position.z).length()
				if owl_planar_distance < 8.9:
					dash_direction = Vector3(target.global_position.x - global_position.x, 0.0, target.global_position.z - global_position.z).normalized()
					dash_timer = 0.46
					flight_dive_timer = 0.48
					flight_target_height = 0.72
					var night_bonus := 1.72 if game.world != null and game.world.time_phase == "night" else 1.42
					_resolve_flight_strike(target, _skill_damage(night_bonus), 0.74, 2.6, 0.0, dash_direction, 0.16)
					hidden_timer = 0.82
					SkillVFX.ring(effect_parent, target.global_position, effect_color.lightened(0.18), 0.38, 1.9, 0.22)
					SkillVFX.dash_trail(effect_parent, global_position, dash_direction, effect_color, 6.4)
					SkillVFX.fang_strike(effect_parent, target.global_position, dash_direction, effect_color, 1.34)
					SkillVFX.radial_burst(effect_parent, target.global_position, effect_color, 2.3, 10, 0.14, 0.34)
					used = true
		"moose":
			for other in game.get_living_actors():
				if other == self or other.dead:
					continue
				var moose_distance := global_position.distance_to(other.global_position)
				if moose_distance < 3.9:
					other.take_damage(_skill_damage(1.38), self)
					other.apply_knockback((other.global_position - global_position).normalized(), 9.0)
					affected_count += 1
					used = true
			if used:
				SkillVFX.ring(effect_parent, global_position, effect_color, 0.65, 4.0, 0.46)
				SkillVFX.radial_burst(effect_parent, global_position, effect_color, 3.7, 14, 0.20, 0.48)
		"turtle":
			shell_guard_timer = 2.8 if _collapse_competition_active() else 5.0
			stamina = minf(max_stamina, stamina + 8.0)
			attack_intent = false
			used = true
			SkillVFX.ring(effect_parent, global_position, effect_color, 0.55, 2.5, 0.44)
			SkillVFX.ring(effect_parent, global_position, effect_color.darkened(0.16), 0.62, 3.7, 0.60, 0.10)
			if effect_parent != null:
				SkillVFX.status_aura(self, effect_color, shell_guard_timer, 0.86)
		"cheetah":
			if is_instance_valid(target):
				var cheetah_planar_distance := Vector2(global_position.x - target.global_position.x, global_position.z - target.global_position.z).length()
				if cheetah_planar_distance < 8.9:
					dash_direction = Vector3(target.global_position.x - global_position.x, 0.0, target.global_position.z - global_position.z).normalized()
					var clear_grassland: bool = game.world != null and game.world.weather_id == "clear" and game.world.region_id_at(global_position) == "grassland"
					dash_timer = 0.76 if clear_grassland else 0.58
					burst_exhaustion_timer = 3.2
					target.take_damage(_skill_damage(1.70 if clear_grassland else 1.52), self)
					target.apply_slow(0.76, 1.8)
					SkillVFX.dash_trail(effect_parent, global_position, dash_direction, effect_color, 7.4 if clear_grassland else 5.8)
					SkillVFX.fang_strike(effect_parent, target.global_position, dash_direction, effect_color, 1.46)
					SkillVFX.ground_spokes(effect_parent, global_position, effect_color.darkened(0.20), 5.2, 10)
					used = true
		"rhino":
			if is_instance_valid(target) and global_position.distance_to(target.global_position) < 7.3:
				dash_direction = (target.global_position - global_position).normalized()
				dash_timer = 0.56
				target.take_damage(_skill_damage(1.86), self)
				target.apply_knockback(dash_direction, 14.0)
				SkillVFX.ground_spokes(effect_parent, global_position, effect_color.darkened(0.20), 5.5, 12)
				SkillVFX.dash_trail(effect_parent, global_position, dash_direction, effect_color, 6.0)
				SkillVFX.fang_strike(effect_parent, target.global_position, dash_direction, effect_color, 1.62)
				used = true
		"gorilla":
			territory_center = global_position
			territory_radius = maxf(territory_radius, 15.4)
			used = true
			for other in game.get_living_actors():
				if other == self or other.dead:
					continue
				var gorilla_distance := global_position.distance_to(other.global_position)
				if gorilla_distance < 4.5:
					other.take_damage(_skill_damage(1.42), self)
					other.apply_knockback((other.global_position - global_position).normalized(), 10.8)
					affected_count += 1
				elif gorilla_distance < 8.2 and int(other.data["size"]) < int(data["size"]):
					other.apply_panic(self, 3.0)
					affected_count += 1
			SkillVFX.ground_spokes(effect_parent, global_position, effect_color.darkened(0.28), 5.7, 14)
			SkillVFX.ring(effect_parent, global_position, effect_color, 0.78, 4.8, 0.46)
			SkillVFX.ring(effect_parent, global_position, effect_color.lightened(0.12), 0.85, 8.0, 0.64, 0.10)
		"eagle":
			if is_instance_valid(target):
				var eagle_planar_distance := Vector2(global_position.x - target.global_position.x, global_position.z - target.global_position.z).length()
				if eagle_planar_distance < 10.3:
					dash_direction = Vector3(target.global_position.x - global_position.x, 0.0, target.global_position.z - global_position.z).normalized()
					dash_timer = 0.54
					flight_dive_timer = 0.52
					flight_target_height = 0.76
					var distance_bonus := lerpf(1.48, 1.90, clampf(eagle_planar_distance / 10.3, 0.0, 1.0))
					if game.world != null and game.world.time_phase == "night":
						distance_bonus *= 0.88
					_resolve_flight_strike(target, _skill_damage(distance_bonus), 1.0, 0.0, 6.8, dash_direction, 0.20)
					SkillVFX.ring(effect_parent, target.global_position, effect_color.lightened(0.18), 0.42, 2.2, 0.26)
					SkillVFX.dash_trail(effect_parent, global_position, dash_direction, effect_color, 8.2)
					SkillVFX.fang_strike(effect_parent, target.global_position, dash_direction, effect_color, 1.58)
					SkillVFX.radial_burst(effect_parent, target.global_position, effect_color, 2.8, 12, 0.17, 0.42)
					used = true
		"hippo":
			for other in game.get_living_actors():
				if other == self or other.dead:
					continue
				var hippo_distance := global_position.distance_to(other.global_position)
				if hippo_distance < 3.9:
					other.take_damage(_skill_damage(1.62), self)
					other.apply_knockback((other.global_position - global_position).normalized(), 10.0)
					used = true
				if hippo_distance < 7.2 and int(other.data["size"]) < int(data["size"]):
					other.apply_panic(self, 2.8)
					affected_count += 1
					used = true
			if used:
				SkillVFX.ground_spokes(effect_parent, global_position, effect_color.darkened(0.22), 4.8, 12)
				SkillVFX.ring(effect_parent, global_position, effect_color, 0.70, 4.0, 0.42)
				SkillVFX.ring(effect_parent, global_position, effect_color.lightened(0.12), 0.78, 6.4, 0.58, 0.10)
		"hyena":
			if is_instance_valid(target) and global_position.distance_to(target.global_position) < 5.6:
				dash_direction = (target.global_position - global_position).normalized()
				dash_timer = 0.32
				target.take_damage(_skill_damage(1.34), self)
				target.apply_scent_mark(6.5, self, effect_color)
				affected_count = _rally_pack(target, 19.0, "hyena")
				SkillVFX.dash_trail(effect_parent, global_position, dash_direction, effect_color, 4.0)
				SkillVFX.fang_strike(effect_parent, target.global_position, dash_direction, effect_color, 1.22)
				SkillVFX.ring(effect_parent, global_position, effect_color, 0.72, 5.6, 0.48)
				used = true
		"lion":
			if is_instance_valid(target) and global_position.distance_to(target.global_position) < 6.4:
				dash_direction = (target.global_position - global_position).normalized()
				dash_timer = 0.40
				target.take_damage(_skill_damage(1.52), self)
				target.apply_scent_mark(7.5, self, effect_color)
				affected_count = _rally_pack(target, 21.0, "lion")
				for other in game.get_living_actors():
					if other == self or other == target or other.dead:
						continue
					if target.global_position.distance_to(other.global_position) < 6.5 and int(other.data["size"]) < int(data["size"]):
						other.apply_panic(self, 2.7)
						affected_count += 1
				SkillVFX.dash_trail(effect_parent, global_position, dash_direction, effect_color, 5.2)
				SkillVFX.fang_strike(effect_parent, target.global_position, dash_direction, effect_color, 1.48)
				SkillVFX.ring(effect_parent, global_position, effect_color, 0.82, 6.8, 0.58)
				used = true
	if used:
		spawn_protection = 0.0
		stamina = maxf(stamina - float(data["skill_cost"]), 0.0)
		stamina_regen_delay = STAMINA_REGEN_COMBAT_DELAY
		skill_timer = float(data["skill_cooldown"])
		exposed_timer = maxf(exposed_timer, Catalog.skill_exposure_duration(species_id))
		_update_exhaustion_state()
		if game.has_method("play_sfx_near"):
			game.play_sfx_near("skill_%s" % species_id, global_position, is_player)
		_play_species_skill_animation()
		_break_cover()
		if is_player:
			var feedback := str(data.get("skill_feedback", data["skill_hint"]))
			if affected_count > 0:
				feedback += " · 影响%d个个体" % affected_count
			game.show_hint(feedback)
	elif is_player:
		game.show_hint("技能没有找到有效目标，靠近一些再试")
	return used


func _skill_effect_parent() -> Node:
	if not _should_show_skill_vfx():
		return null
	var root := game.get("game_root") as Node if is_instance_valid(game) else null
	return root if is_instance_valid(root) else get_parent()


func _resolve_flight_strike(target: EcoActor, damage_value: float, slow_value: float, slow_duration: float, knockback_strength: float, strike_direction: Vector3, warning_time: float) -> void:
	# Delayed combat must stop with the world. Otherwise a dive can kill while a
	# pause/report modal is open and its death event is discarded by the match.
	await get_tree().create_timer(warning_time, false).timeout
	if dead or not is_instance_valid(target) or target.dead:
		return
	var planar_distance := Vector2(global_position.x - target.global_position.x, global_position.z - target.global_position.z).length()
	if planar_distance > 12.0:
		return
	target.take_damage(damage_value, self)
	if slow_duration > 0.0 and slow_value < 1.0:
		target.apply_slow(slow_value, slow_duration)
	if knockback_strength > 0.0:
		target.apply_knockback(strike_direction, knockback_strength)


func _should_show_skill_vfx() -> bool:
	if not is_instance_valid(game) or game.get("batch_mode"):
		return false
	var game_player := _game_player()
	var quality := str(game.get_quality_preset()) if game.has_method("get_quality_preset") else "medium"
	var visible_distance := 24.0 if quality == "low" else (48.0 if quality == "high" else 36.0)
	return is_player or not is_instance_valid(game_player) or global_position.distance_to(game_player.global_position) <= visible_distance


func _skill_damage(attack_factor: float) -> float:
	var result := float(data["attack"]) * attack_factor
	if not is_player:
		result *= game.get_ai_damage_multiplier()
	return result


func _spawn_skill_projectile(target: EcoActor, damage_value: float, color_value: Color) -> void:
	if not is_instance_valid(target):
		return
	var projectile := ProjectileScript.new()
	var projectile_parent := game.get("game_root") as Node if is_instance_valid(game) else null
	if not is_instance_valid(projectile_parent):
		projectile_parent = get_parent()
	projectile_parent.add_child(projectile)
	projectile.setup(self, target, global_position, damage_value, color_value)


func _broadcast_scent(target: EcoActor, radius: float, max_responders: int) -> int:
	if not is_instance_valid(target):
		return 0
	var candidates: Array[EcoActor] = []
	for other in game.get_living_actors():
		if other == self or other == target or other.dead or other.is_player:
			continue
		if not Catalog.considers_prey(other.species_id, target.species_id):
			continue
		if other.global_position.distance_to(target.global_position) <= radius:
			candidates.append(other)
	candidates.sort_custom(func(a: EcoActor, b: EcoActor) -> bool:
		return a.global_position.distance_squared_to(target.global_position) < b.global_position.distance_squared_to(target.global_position)
	)
	var responders := mini(candidates.size(), max_responders)
	for index in range(responders):
		var hunter := candidates[index]
		hunter.ai_target = target
		hunter.ai_state = "hunt"
		hunter.state_commit_timer = maxf(hunter.state_commit_timer, 2.8)
	return responders


func _rally_pack(target: EcoActor, radius: float, pack_species: String = "") -> int:
	if not is_instance_valid(target):
		return 0
	var pack_id := species_id if pack_species == "" else pack_species
	var rallied := 0
	for other in game.get_living_actors():
		if other == self or other.dead or other.is_player or other.species_id != pack_id:
			continue
		if other.global_position.distance_to(global_position) > radius:
			continue
		other.ai_target = target
		other.ai_state = "hunt"
		other.state_commit_timer = maxf(other.state_commit_timer, 3.4)
		other.stamina = minf(other.max_stamina, other.stamina + 12.0)
		rallied += 1
	return rallied


func take_damage(raw_damage: float, source: EcoActor) -> void:
	if dead:
		return
	if spawn_protection > 0.0:
		return
	var threat_gap := 0
	var opportunity_strike := false
	var ambush_strike := false
	var terrain_strike := false
	if is_instance_valid(source):
		threat_gap = Catalog.opportunity_threat_gap(source.species_id, species_id)
		ambush_strike = threat_gap > 0 and source.ambush_attack_armed
		terrain_strike = threat_gap > 0 and source.terrain_attack_armed
		opportunity_strike = threat_gap > 0 and (is_opportunity_exposed() or ambush_strike or terrain_strike) and source.opportunity_strike_timer <= 0.0
	var armor := float(data["armor"])
	if opportunity_strike:
		armor *= OPPORTUNITY_ARMOR_FACTOR
	var reduction := armor / (armor + 100.0)
	var size_scale := 1.0
	if is_instance_valid(source):
		size_scale = clampf(1.0 + (int(source.data["size"]) - int(data["size"])) * 0.12, 0.65, 1.45)
		calm_timer = 0.0
		last_attacker = source
		register_ecology_influence(source, 8.0)
		_break_cover()
		if not is_player:
			var source_gap := Catalog.opportunity_threat_gap(species_id, source.species_id)
			var safe_to_counter := source_gap <= 0 or source.is_opportunity_exposed() or Catalog.has_trait(species_id, "brave_vs_large")
			_switch_state("hunt" if health / max_health > 0.35 and float(data["courage"]) > 0.35 and safe_to_counter else "flee", source)
	var final_damage := maxf(raw_damage * size_scale * (1.0 - reduction), 1.0)
	var opportunity_bonus := 0.0
	if opportunity_strike:
		opportunity_bonus = max_health * Catalog.opportunity_health_ratio(threat_gap)
		final_damage += opportunity_bonus
		stamina = maxf(stamina - max_stamina * OPPORTUNITY_STAMINA_DAMAGE_RATIO, 0.0)
		source.opportunity_strike_timer = OPPORTUNITY_COOLDOWN
		if ambush_strike:
			exposed_timer = maxf(exposed_timer, AMBUSH_CREATED_EXPOSURE)
		elif terrain_strike:
			exposed_timer = maxf(exposed_timer, TERRAIN_CREATED_EXPOSURE)
		else:
			exposed_timer = 0.0
		apply_slow(0.84, 1.25)
		_update_exhaustion_state()
		if (ambush_strike or terrain_strike) and _should_show_skill_vfx():
			var counter_color := Color("#8fe8b7") if ambush_strike else Color("#70cfe8")
			SkillVFX.radial_burst(_skill_effect_parent(), global_position, counter_color, 2.2 + float(threat_gap) * 0.18, 10, 0.14, 0.44)
	if shell_guard_timer > 0.0:
		final_damage *= 0.42 if _collapse_competition_active() else 0.24
		final_damage = maxf(final_damage, 1.0)
	if has_habit_buff("guard"):
		final_damage *= 0.90
	if Catalog.has_trait(species_id, "giant") and is_instance_valid(source):
		if Catalog.has_trait(source.species_id, "pack_hunter") or Catalog.has_trait(source.species_id, "brave_vs_large"):
			final_damage *= 1.32
	health -= final_damage
	if health > 0.0 and is_instance_valid(source):
		_trigger_ecology_intervention(source)
	if opportunity_strike and game.has_method("on_opportunity_strike"):
		game.on_opportunity_strike(source, self, threat_gap, opportunity_bonus, ambush_strike, terrain_strike)
	if opportunity_strike and is_instance_valid(source):
		var route_id := "ambush" if ambush_strike else ("terrain" if terrain_strike else "opportunity")
		source.register_counterplay(self, route_id)
	if species_id == "bear" and rage_cooldown_timer <= 0.0:
		rage_timer = 4.0
		rage_cooldown_timer = 8.0
	health_changed.emit(health, max_health)
	_update_health_bar()
	if is_instance_valid(source) and source.is_player:
		reveal_health_bar()
		if game.has_method("show_enemy_health"):
			game.show_enemy_health(self)
	if game.has_method("play_sfx_near"):
		game.play_sfx_near("hit", global_position, is_player)
	_play_hit_pulse()
	if health <= 0.0:
		die(source)
	elif species_id == "porcupine" and is_instance_valid(source) and not source.dead and source.species_id != "porcupine" and global_position.distance_to(source.global_position) < 2.8:
		var reflection_factor := 0.48 if quill_guard_timer > 0.0 else 0.22
		source.take_damage(maxf(final_damage * reflection_factor, 3.0), self)


func apply_poison(dps: float, duration: float, source: EcoActor) -> void:
	if Catalog.has_trait(species_id, "giant"):
		dps *= 1.22
	if duration > poison_timer or dps > poison_dps:
		poison_dps = dps
		poison_timer = duration
		poison_source = source


func apply_scent_mark(duration: float, source: EcoActor, color: Color = Color("#e96a55")) -> void:
	scent_mark_timer = maxf(scent_mark_timer, duration)
	if is_instance_valid(source):
		last_attacker = source
		register_ecology_influence(source, duration + 2.0)
	if _should_show_skill_vfx():
		SkillVFX.status_aura(self, color, duration, 0.66 + int(data["size"]) * 0.08)


func apply_slow(multiplier: float, duration: float) -> void:
	slow_multiplier = minf(slow_multiplier, clampf(multiplier, 0.45, 1.0))
	slow_timer = maxf(slow_timer, duration)


func apply_panic(source: EcoActor, duration: float) -> void:
	panic_timer = maxf(panic_timer, duration)
	register_ecology_influence(source, duration + 4.0)
	if is_player or not is_instance_valid(source):
		return
	ai_target = source
	ai_state = "flee"
	state_commit_timer = maxf(state_commit_timer, duration)


func apply_calm(source: EcoActor, duration: float) -> void:
	if dead or hunger >= 70.0:
		return
	calm_timer = maxf(calm_timer, duration)
	if not is_player:
		ai_target = null
		attack_intent = false
		ai_state = "wander"
		state_commit_timer = 0.0


func claim_fresh_corpse(corpse: Node3D) -> bool:
	if is_player or dead or not is_instance_valid(corpse) or not Catalog.can_eat_corpse(species_id):
		return false
	# A successful hunter should feed instead of chaining immediately into the
	# next weak target. Six seconds allows several bites, lowers hunting drive,
	# and gives scavengers/nearby prey time to react to the new hotspot.
	resource_target = corpse
	pending_food_resource = null
	ai_target = null
	attack_intent = false
	ai_state = "food"
	state_commit_timer = maxf(state_commit_timer, 6.0)
	calm_timer = maxf(calm_timer, 6.2)
	return true


func register_ecology_influence(source: EcoActor, duration: float, reason: String = "生态助攻") -> void:
	if not is_instance_valid(source) or source == self:
		return
	if ecology_influence_source == source:
		ecology_influence_timer = maxf(ecology_influence_timer, duration)
		if reason != "生态助攻":
			ecology_influence_reason = reason
		return
	if source.is_player or not is_instance_valid(ecology_influence_source) or ecology_influence_timer <= 0.0:
		ecology_influence_source = source
		ecology_influence_timer = maxf(ecology_influence_timer, duration)
		ecology_influence_reason = reason


func _trigger_ecology_intervention(threat: EcoActor) -> EcoActor:
	var responder := ecology_leverage_candidate(threat)
	if not is_instance_valid(responder):
		return null
	ecology_leverage_cooldown = ECOLOGY_LEVERAGE_COOLDOWN
	escape_intervention_actor = null
	escape_intervention_position = Vector3(INF, 0.0, INF)
	threat.register_ecology_influence(self, ECOLOGY_LEVERAGE_INFLUENCE, "生态借力")
	responder._switch_state("hunt", threat)
	responder.state_commit_timer = maxf(responder.state_commit_timer, ECOLOGY_LEVERAGE_COMMIT)
	responder.last_known_target_position = threat.global_position
	responder.has_last_known_target_position = true
	if responder._should_show_skill_vfx():
		var leverage_color := Color("#d7a2f2")
		SkillVFX.radial_burst(responder._skill_effect_parent(), responder.global_position, leverage_color, 2.5, 10, 0.14, 0.42)
		SkillVFX.ring(responder._skill_effect_parent(), threat.global_position, leverage_color.darkened(0.12), 0.56, 2.8, 0.44)
	if game.has_method("on_ecology_intervention"):
		game.on_ecology_intervention(self, threat, responder)
	register_counterplay(threat, "ecology")
	_update_cover_visual()
	return responder


func register_counterplay(target: EcoActor, route_id: String) -> Dictionary:
	var result: Dictionary = {"xp": 0, "chain": 0, "mastery": false, "health": 0.0, "stamina": 0.0}
	if dead or not is_instance_valid(target) or target == self or target.dead:
		return result
	if Catalog.opportunity_threat_gap(species_id, target.species_id) <= 0:
		return result
	var route_flag: int = int({"opportunity": 1, "ambush": 2, "terrain": 4, "ecology": 8}.get(route_id, 0))
	if route_flag == 0:
		return result
	var target_key := str(target.actor_id)
	var award_key := "%s:%s" % [target_key, route_id]
	if not counterplay_route_awards.has(award_key):
		counterplay_route_awards[award_key] = true
		tactical_actions += 1
		var earned := int(counterplay_xp_by_target.get(target_key, 0))
		var cap: int = Catalog.counterplay_experience_cap(target.species_id, target.level)
		var xp_award: int = mini(Catalog.counterplay_experience_reward(target.species_id, target.level), maxi(cap - earned, 0))
		if level >= MAX_LEVEL:
			xp_award = 0
		if xp_award > 0:
			counterplay_xp_by_target[target_key] = earned + xp_award
			gain_experience(xp_award, target.species_id, "战术成长")
		result["xp"] = xp_award
	if counterplay_chain_target_id != target.actor_id or counterplay_chain_timer <= 0.0:
		counterplay_chain_target_id = target.actor_id
		counterplay_chain_flags = 0
	counterplay_chain_flags |= route_flag
	counterplay_chain_timer = COUNTERPLAY_CHAIN_WINDOW
	var chain_count: int = _counterplay_bit_count(counterplay_chain_flags)
	result["chain"] = chain_count
	if chain_count >= 2 and not counterplay_mastered_targets.has(target_key):
		counterplay_mastered_targets[target_key] = true
		var health_before := health
		var stamina_before := stamina
		health = minf(max_health, health + max_health * COUNTERPLAY_MASTERY_HEALTH_RATIO)
		stamina = minf(max_stamina, stamina + max_stamina * COUNTERPLAY_MASTERY_STAMINA_RATIO)
		_update_exhaustion_state()
		result["health"] = health - health_before
		result["stamina"] = stamina - stamina_before
		result["mastery"] = true
		counterplay_mastery_timer = COUNTERPLAY_MASTERY_VISUAL_TIME
		health_changed.emit(health, max_health)
		stamina_changed.emit(stamina, max_stamina)
		_update_health_bar()
		_update_cover_visual()
	if game != null and game.has_method("on_counterplay_progress"):
		game.on_counterplay_progress(self, target, route_id, int(result["xp"]), chain_count, bool(result["mastery"]), float(result["health"]), float(result["stamina"]))
	return result


func counterplay_chain_status_text(target: EcoActor = null) -> String:
	if is_instance_valid(target) and target.actor_id != counterplay_chain_target_id:
		return ""
	if counterplay_mastery_timer > 0.0:
		return "生态掌控 · 生命与耐力已恢复"
	if counterplay_chain_timer <= 0.0 or counterplay_chain_flags == 0:
		return ""
	return "战术连携 %d/2 · %.1fs" % [mini(_counterplay_bit_count(counterplay_chain_flags), 2), counterplay_chain_timer]


func _counterplay_bit_count(value: int) -> int:
	var remaining := value
	var count := 0
	while remaining > 0:
		count += remaining & 1
		remaining >>= 1
	return count


func apply_knockback(direction: Vector3, strength: float) -> void:
	if has_habit_buff("guard"):
		strength *= 0.82
	if species_id == "turtle" and shell_guard_timer > 0.0:
		strength *= 0.08
	elif species_id == "turtle":
		strength *= 0.60
	elif species_id == "boar" and health / max_health < 0.50:
		strength *= 0.46
	elif species_id == "porcupine" and quill_guard_timer > 0.0:
		strength *= 0.58
	elif species_id in ["rhino", "hippo"]:
		strength *= 0.62
	elif species_id == "elephant":
		strength *= 0.42
	velocity += Vector3(direction.x, 0.15, direction.z).normalized() * strength


func try_consume_nearby() -> bool:
	var resource := _best_food_resource()
	if Catalog.has_trait(species_id, "flying") and is_instance_valid(resource):
		var planar_distance := Vector2(global_position.x - resource.global_position.x, global_position.z - resource.global_position.z).length()
		if planar_distance <= 4.8 and global_position.y > 0.92:
			pending_food_resource = resource
			_request_landing(3.2)
			if is_player:
				game.show_hint("正在下降到安全落点，落地后会自动进食")
			return true
	if not is_instance_valid(resource) or global_position.distance_to(resource.global_position) > 3.0:
		if is_player:
			game.show_hint("附近没有适合你的食物")
		return false
	return try_consume_resource(resource)


func try_consume_resource(resource: Node3D) -> bool:
	if eat_timer > 0.0 or not is_instance_valid(resource) or global_position.distance_to(resource.global_position) > 2.5:
		return false
	var is_corpse := resource is EcoCorpse
	if is_corpse and not Catalog.can_eat_corpse(species_id):
		return false
	if resource is FoodPatch and not resource.can_be_eaten_by(species_id):
		return false
	var bite_size := 22.0 if Catalog.has_trait(species_id, "giant") else 14.0
	var eaten: float = resource.consume(bite_size)
	if eaten <= 0.0:
		return false
	eat_timer = 1.0
	var nutrition_multiplier: float = resource.get_nutrition_multiplier() if resource is FoodPatch else 1.0
	var satiety_efficiency := 0.55 if Catalog.has_trait(species_id, "giant") else 0.85
	var healing_efficiency := 0.08 if Catalog.has_trait(species_id, "giant") else (0.28 if is_corpse else 0.12)
	hunger = maxf(hunger - eaten * satiety_efficiency * nutrition_multiplier, 0.0)
	health = minf(health + eaten * healing_efficiency * nutrition_multiplier, max_health)
	var habit_result := _apply_food_habit(resource, "corpse" if is_corpse else str(resource.food_kind))
	if species_id == "raccoon":
		forage_speed_timer = 3.0
	if resource is FoodPatch:
		var source_key := str(resource.get_instance_id())
		if not rewarded_food_sources.has(source_key):
			rewarded_food_sources[source_key] = true
			var forage_xp := maxi(roundi(eaten * nutrition_multiplier * 0.24), 2)
			gain_experience(forage_xp, resource.get_food_name(), "觅食")
	if int(habit_result.get("xp", 0)) > 0:
		gain_experience(int(habit_result["xp"]), str(habit_result.get("name", "生态习性")), "觅食")
	health_changed.emit(health, max_health)
	if is_player:
		stamina_changed.emit(stamina, max_stamina)
	_update_health_bar()
	if game.has_method("play_sfx_near"):
		game.play_sfx_near("eat", global_position, is_player)
	if is_player:
		var food_name: String = str(resource.get_food_name()) if resource is FoodPatch else "猎物尸体"
		if bool(habit_result.get("triggered", false)):
			game.show_hint("进食%s触发「%s」：生命 +%d、耐力 +%d · %s" % [
				food_name, str(habit_result["name"]), ceili(float(habit_result["health"])), ceili(float(habit_result["stamina"])), Catalog.habit_buff_display_name(str(habit_result["buff"])),
			])
		else:
			game.show_hint("进食%s，恢复了生命与饱腹" % food_name)
	return true


func _apply_food_habit(resource: Node3D, food_kind: String) -> Dictionary:
	var source_key := _habit_source_key(resource)
	if source_key == "" or habit_rewarded_sources.has(source_key):
		return {}
	var region_id := environment_region_id
	var time_phase := "day"
	var weather_id := "clear"
	var in_cover := cover_strength >= 0.40
	if game != null and game.world is EcoWorld:
		var eco_world := game.world as EcoWorld
		region_id = str(eco_world.region_id_at(resource.global_position))
		in_cover = float(eco_world.cover_strength_at(resource.global_position, species_id)) >= 0.40
		time_phase = eco_world.time_phase
		weather_id = eco_world.weather_id
	var prey_size := 0
	if resource is EcoCorpse:
		prey_size = Catalog.body_size(resource.species_id)
	var effect := Catalog.habit_food_effect(species_id, food_kind, region_id, in_cover, time_phase, weather_id, health / maxf(max_health, 1.0), prey_size)
	if effect.is_empty():
		return {}
	habit_rewarded_sources[source_key] = true
	habit_activation_count += 1
	var health_before := health
	var stamina_before := stamina
	health = minf(health + max_health * float(effect.get("health_ratio", 0.0)), max_health)
	stamina = minf(stamina + max_stamina * float(effect.get("stamina_ratio", 0.0)), max_stamina)
	hunger = maxf(hunger - float(effect.get("hunger_bonus", 0.0)), 0.0)
	habit_buff_kind = str(effect.get("buff", "recover"))
	habit_buff_name = str(effect.get("name", "生态习性"))
	habit_buff_timer = maxf(habit_buff_timer, float(effect.get("duration", 4.0)))
	if _should_show_skill_vfx():
		var habit_color: Color = {
			"escape": Color("#91e8a0"),
			"recover": Color("#7ad9ce"),
			"guard": Color("#dfc27a"),
			"hunt": Color("#ef866c"),
			"conceal": Color("#a99be8"),
		}.get(habit_buff_kind, Color("#9bd8a3"))
		SkillVFX.status_aura(self, habit_color, habit_buff_timer, 0.62 + int(data["size"]) * 0.07)
		SkillVFX.radial_burst(_skill_effect_parent(), global_position + Vector3.UP * 0.18, habit_color, 1.5 + int(data["size"]) * 0.18, 8, 0.10, 0.34)
	_update_exhaustion_state()
	return {
		"triggered": true,
		"name": habit_buff_name,
		"buff": habit_buff_kind,
		"health": health - health_before,
		"stamina": stamina - stamina_before,
		"xp": int(effect.get("xp_bonus", 0)),
	}


func experience_to_next_level() -> int:
	if level >= MAX_LEVEL:
		return 0
	return 45 + (level - 1) * 32 + (level - 1) * (level - 1) * 5


func gain_experience(amount: int, defeated_species: String = "", reason: String = "击杀") -> void:
	if dead or level >= MAX_LEVEL or amount <= 0:
		return
	experience += amount
	while level < MAX_LEVEL and experience >= experience_to_next_level():
		experience -= experience_to_next_level()
		_level_up()
	if level >= MAX_LEVEL:
		experience = 0
	if is_player and game.has_method("on_player_experience_gained"):
		game.on_player_experience_gained(amount, defeated_species, reason)


func _level_up() -> void:
	level += 1
	var growth := Catalog.growth_profile(species_id)
	var old_max_health := max_health
	var old_max_stamina := max_stamina
	var old_attack := float(data["attack"])
	var old_armor := float(data["armor"])
	var old_speed := float(data["speed"])
	var old_regen := float(data["regen"])
	max_health *= 1.0 + float(growth["health"])
	max_stamina *= 1.0 + float(growth["stamina"])
	data["attack"] = old_attack * (1.0 + float(growth["attack"]))
	data["armor"] = old_armor + float(growth["armor"])
	data["speed"] = old_speed * (1.0 + float(growth["speed"]))
	data["regen"] = float(data["regen"]) * (1.0 + float(growth["regen"]))
	# Leveling grows the health pool and also restores enough current health to
	# make the power increase immediately useful during a difficult fight.
	health = minf(max_health, health + (max_health - old_max_health) + max_health * 0.30)
	stamina = minf(max_stamina, stamina + (max_stamina - old_max_stamina) + max_stamina * 0.42)
	_update_exhaustion_state()
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, max_stamina)
	_update_health_bar()
	if game.has_method("on_actor_level_up"):
		game.on_actor_level_up(self, level)
	if is_player and game.has_method("on_player_level_up"):
		game.on_player_level_up(level, {
			"profile": str(growth["name"]),
			"health": max_health - old_max_health,
			"stamina": max_stamina - old_max_stamina,
			"attack": float(data["attack"]) - old_attack,
			"armor": float(data["armor"]) - old_armor,
			"speed": float(data["speed"]) - old_speed,
			"regen": float(data["regen"]) - old_regen,
		})


func die(killer: EcoActor) -> void:
	if dead:
		return
	dead = true
	health = 0.0
	velocity = Vector3.ZERO
	if health_bar_root != null:
		health_bar_root.visible = false
	var collision := get_node_or_null("BodyCollision") as CollisionShape3D
	if collision != null:
		collision.set_deferred("disabled", true)
	if is_instance_valid(killer):
		killer.kills += 1
	died.emit(self, killer)
	var tween := create_tween()
	tween.tween_property(visual_root, "scale", Vector3(1.2, 0.12, 1.2), 0.35)
	# Player death pauses the tree when the result panel appears. An awaited
	# SceneTreeTimer here would remain suspended on a dead actor, and Web builds
	# could later dispatch its stale continuation as a null WASM function. Finish
	# the short death animation before the result delay. Keep the dead player node
	# alive (but hidden) until the result screen has read its species and run stats;
	# the next world transition owns its final cleanup.
	var release_after_animation := should_queue_free_after_death(is_player)
	tween.tween_callback(func() -> void:
		visible = false
		if release_after_animation:
			queue_free()
	)


func _nearest_living_actor(max_distance: float) -> EcoActor:
	var nearest: EcoActor
	var nearest_distance := max_distance
	for other in game.get_living_actors():
		if other == self or other.dead:
			continue
		var distance := global_position.distance_to(other.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = other
	return nearest


func _update_visual_lod(delta: float) -> void:
	if game.get("batch_mode"):
		return
	visual_lod_elapsed += delta
	var update_interval := 0.0
	var game_player := _game_player()
	if not is_player and is_instance_valid(game_player):
		var player_distance := global_position.distance_to(game_player.global_position)
		var quality := str(game.get_quality_preset()) if game.has_method("get_quality_preset") else "medium"
		if quality == "low":
			if player_distance > 42.0:
				update_interval = 0.32
			elif player_distance > 28.0:
				update_interval = 0.18
			elif player_distance > 18.0:
				update_interval = 0.09
		elif quality == "high":
			if player_distance > 68.0:
				update_interval = 0.18
			elif player_distance > 48.0:
				update_interval = 0.10
			elif player_distance > 32.0:
				update_interval = 0.05
		else:
			if player_distance > 56.0:
				update_interval = 0.24
			elif player_distance > 36.0:
				update_interval = 0.12
			elif player_distance > 24.0:
				update_interval = 0.06
	if update_interval > 0.0 and visual_lod_elapsed < update_interval:
		return
	var animation_delta := visual_lod_elapsed
	visual_lod_elapsed = 0.0
	_update_visual_motion(animation_delta)


static func safe_actor_reference(candidate: Variant) -> EcoActor:
	if not is_instance_valid(candidate) or not candidate is EcoActor:
		return null
	return candidate


static func should_queue_free_after_death(player_controlled: bool) -> bool:
	return not player_controlled


static func opening_caution_seconds(campaign_level: int) -> float:
	match campaign_level:
		1:
			return 38.0
		2:
			return 30.0
		3:
			return 27.0
		4:
			return 25.0
		5:
			return 24.0
		6:
			return 23.0
		7:
			return 22.0
		8:
			return 21.0
		9, 10:
			return 20.0
		_:
			return 0.0


func _game_player() -> EcoActor:
	if not is_instance_valid(game):
		return null
	return safe_actor_reference(game.get("player"))


func _update_visual_motion(delta: float) -> void:
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	move_time += delta * (2.0 + flat_speed * 0.75)
	var base_speed := maxf(float(data["speed"]), 0.1)
	var speed_ratio := clampf(flat_speed / base_speed, 0.0, 1.65)
	var target_gait := smoothstep(0.08, 0.55, speed_ratio)
	gait_blend = lerpf(gait_blend, target_gait, 1.0 - exp(-delta * 10.0))
	var stride_amplitude := _gait_stride_amplitude() * lerpf(0.55, 1.0, minf(speed_ratio, 1.0)) * gait_blend
	for leg_index in range(leg_pivots.size()):
		var pivot := leg_pivots[leg_index]
		if not is_instance_valid(pivot):
			continue
		var target_rotation := sin(move_time + leg_phases[leg_index]) * stride_amplitude * leg_stride_scales[leg_index]
		pivot.rotation.x = lerp_angle(pivot.rotation.x, target_rotation, 1.0 - exp(-delta * 15.0))
	for wing in wing_pivots:
		if not is_instance_valid(wing):
			continue
		var side_sign := signf(wing.position.x)
		var airborne_blend := 1.0 if is_airborne() else 0.38
		var flap := sin(move_time * 1.65) * (0.42 + minf(flat_speed / maxf(float(data["speed"]), 0.1), 1.0) * 0.28) * airborne_blend
		wing.rotation.z = lerp_angle(wing.rotation.z, -side_sign * flap, 1.0 - exp(-delta * 13.0))
		wing.rotation.x = lerp_angle(wing.rotation.x, -0.10 + sin(move_time * 0.72) * 0.06, 1.0 - exp(-delta * 9.0))
	for tail_visual in tail_visuals:
		if not is_instance_valid(tail_visual):
			continue
		var tail_swing := sin(move_time * 0.72 + float(actor_id) * 0.41) * 0.065 * gait_blend
		tail_visual.rotation.y = lerp_angle(tail_visual.rotation.y, tail_swing, 1.0 - exp(-delta * 8.0))
	if body_root != null:
		var bob_height := minf(flat_speed * 0.009, 0.052) * gait_blend
		body_root.position.y = (sin(move_time * 2.0) * 0.5 + 0.5) * bob_height
		var body_pitch_scale := 0.42 if int(data["size"]) >= 4 else 1.0
		body_root.rotation.x = sin(move_time * 2.0 + 0.65) * minf(flat_speed * 0.0038, 0.021) * gait_blend * body_pitch_scale
		body_root.rotation.z = sin(move_time) * minf(flat_speed * 0.007, 0.032) * gait_blend
		if species_id == "snake":
			body_root.rotation.y = lerp_angle(body_root.rotation.y, sin(move_time * 0.92) * 0.13 * gait_blend, 1.0 - exp(-delta * 8.0))
		else:
			body_root.rotation.y = lerp_angle(body_root.rotation.y, 0.0, 1.0 - exp(-delta * 8.0))
		if species_id == "turtle":
			var shell_scale := base_visual_scale * (Vector3(1.08, 0.72, 1.08) if shell_guard_timer > 0.0 else Vector3.ONE)
			body_root.scale = body_root.scale.lerp(shell_scale, 1.0 - exp(-delta * 12.0))
	if selection_ring != null:
		selection_ring.rotation.y += delta * 0.35
		selection_ring.position.y = -global_position.y + 0.08 if is_airborne() else 0.07


func _gait_stride_amplitude() -> float:
	match species_id:
		"rabbit": return 0.72
		"deer", "moose", "goat", "zebra": return 0.58
		"fox", "lynx", "raccoon": return 0.55
		"wolf", "tiger", "hyena", "lion": return 0.50
		"capybara": return 0.42
		"otter": return 0.56
		"monkey": return 0.62
		"cheetah": return 0.68
		"gorilla": return 0.36
		"turtle": return 0.24
		"elephant": return 0.28
		"boar", "wolverine": return 0.48
		"porcupine": return 0.40
		"bear", "bison": return 0.38
		"crocodile": return 0.28
		"rhino", "hippo": return 0.32
		_: return 0.0


func _play_attack_pulse() -> void:
	if body_root == null:
		return
	var tween := create_tween()
	tween.tween_property(body_root, "scale", base_visual_scale * Vector3(1.03, 0.94, 1.12), 0.07)
	tween.tween_property(body_root, "scale", base_visual_scale, 0.12)


func _play_species_skill_animation() -> void:
	if body_root == null:
		return
	var tween := create_tween()
	match species_id:
		"rabbit":
			tween.tween_property(body_root, "scale", base_visual_scale * Vector3(0.78, 1.14, 1.30), 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(body_root, "scale", base_visual_scale, 0.20)
		"fox":
			tween.tween_property(body_root, "scale", base_visual_scale * Vector3(0.86, 0.92, 1.34), 0.08)
			tween.tween_property(body_root, "scale", base_visual_scale, 0.21).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"deer":
			tween.tween_property(body_root, "scale", base_visual_scale * Vector3(1.06, 0.82, 0.94), 0.10)
			tween.tween_property(body_root, "scale", base_visual_scale * Vector3(0.94, 1.18, 1.02), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(body_root, "scale", base_visual_scale, 0.19)
		"wolf":
			tween.tween_property(body_root, "scale", base_visual_scale * Vector3(0.84, 0.90, 1.38), 0.09)
			tween.tween_property(body_root, "scale", base_visual_scale, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"snake":
			tween.tween_property(body_root, "scale", base_visual_scale * Vector3(0.68, 1.12, 1.46), 0.08)
			tween.tween_property(body_root, "scale", base_visual_scale, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		"bear":
			tween.tween_property(body_root, "scale", base_visual_scale * Vector3(1.18, 0.76, 1.18), 0.12)
			tween.tween_property(body_root, "scale", base_visual_scale * Vector3(0.94, 1.17, 0.94), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(body_root, "scale", base_visual_scale, 0.22)
		_:
			tween.tween_property(body_root, "scale", base_visual_scale * 1.12, 0.10)
			tween.tween_property(body_root, "scale", base_visual_scale, 0.18)


func _play_hit_pulse() -> void:
	if visual_root == null:
		return
	var tween := create_tween()
	tween.tween_property(visual_root, "scale", Vector3(1.08, 0.88, 1.08), 0.06)
	tween.tween_property(visual_root, "scale", Vector3.ONE, 0.13)
