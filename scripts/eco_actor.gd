class_name EcoActor
extends CharacterBody3D

const Catalog = preload("res://scripts/species_catalog.gd")
const Factory = preload("res://scripts/low_poly_factory.gd")
const SkillVFX = preload("res://scripts/skill_vfx.gd")

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
var last_attacker: EcoActor
var rage_timer: float = 0.0
var rage_cooldown_timer: float = 0.0
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

var ai_state: String = "wander"
var ai_target: EcoActor
var resource_target: Node3D
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
var kills: int = 0
var assists: int = 0
var spawn_protection: float = 0.0
var health_bar_root: Node3D
var health_bar_fill: MeshInstance3D
var health_bar_label: Label3D
var health_bar_visibility_timer: float = 0.0
var forced_health_bar_timer: float = 0.0


func setup(game_ref: Node, new_id: int, new_species_id: String, player_controlled: bool, spawn_position: Vector3, threat_level: int = 0) -> void:
	game = game_ref
	actor_id = new_id
	species_id = new_species_id
	is_player = player_controlled
	data = Catalog.get_data(species_id)
	name = "%s_%02d%s" % [species_id.capitalize(), actor_id, "_Player" if is_player else ""]
	var ai_health_scale: float = 1.0 if is_player else 1.0 + float(min(threat_level, 8)) * 0.06
	max_health = float(data["health"]) * ai_health_scale
	health = max_health
	max_stamina = float(data["stamina"])
	stamina = max_stamina
	position = spawn_position
	collision_layer = 1
	collision_mask = 2
	_build_collision()
	_build_visual()
	spawn_protection = 6.0 if is_player else 0.0
	decision_timer = fmod(float(actor_id) * 0.073, 0.33) + 0.05
	wander_timer = 0.1
	last_sample_position = global_position


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
		"lynx": _build_feline(false)
		"bison": _build_bison()
		"crocodile": _build_crocodile()
		"tiger": _build_feline(true)
		"moose": _build_moose()
		"rhino": _build_rhino()
		"hippo": _build_hippo()
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
	return not dead and (hidden_timer > 0.0 or (species_id in ["snake", "lynx", "crocodile"] and still_timer > 1.5))


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
		Vector3(0.12, 1.53, 2.06), Vector3(0.10, 1.79, 2.52)
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
	body_root.add_child(Factory.sphere("Chest", accent.darkened(0.12), Vector3(0.87, 0.86, 0.22), Vector3(0.0, 1.38, -1.20), 8, 5))
	body_root.add_child(Factory.sphere("Muzzle", accent, Vector3(0.59, 0.41, 0.31), Vector3(0.0, 1.92, -1.94), 9, 5))
	for side in [-1.0, 1.0]:
		body_root.add_child(Factory.sphere("Ear", color.lightened(0.05), Vector3(0.34, 0.34, 0.28), Vector3(side * 0.38, 2.47, -1.39), 8, 5))
		body_root.add_child(Factory.sphere("Brow", color.darkened(0.16), Vector3(0.22, 0.14, 0.16), Vector3(side * 0.21, 2.21, -1.77), 7, 4))
	_add_eye_pair(2.13, -1.82, 0.22, 0.09)
	body_root.add_child(Factory.sphere("Nose", Color("#241d18"), Vector3(0.25, 0.18, 0.18), Vector3(0.0, 1.94, -2.39), 8, 4))
	_add_legs(color.darkened(0.10), 0.56, 0.94, 0.68, 0.70, Color("#3e2d24"))


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
		var ear := Factory.cone("TuftedEar", color.darkened(0.12), 0.24, 0.58, Vector3(side * 0.34, 2.05, -1.43), 7)
		ear.rotation.z = side * 0.16
		body_root.add_child(ear)
		if not is_tiger:
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
			var stripe_z := -0.45 + stripe_index * 0.42
			body_root.add_child(Factory.sphere("TigerStripe", Color("#2b211b"), Vector3(0.58, 0.055, 0.105), Vector3(0.0, 1.43, stripe_z), 7, 3))
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
	body_root.add_child(Factory.box("LongJaw", color.lightened(0.04), Vector3(0.86, 0.30, 1.32), Vector3(0.0, 0.58, -2.48)))
	body_root.add_child(Factory.box("JawBelly", accent.darkened(0.12), Vector3(0.77, 0.10, 1.22), Vector3(0.0, 0.40, -2.45)))
	for plate_index in range(7):
		var plate := Factory.cone("BackPlate", color.darkened(0.25), 0.18, 0.38, Vector3(0.0, 1.04, 1.30 - plate_index * 0.50), 6)
		body_root.add_child(plate)
	for side in [-1.0, 1.0]:
		body_root.add_child(Factory.sphere("EyeRidge", color.darkened(0.16), Vector3(0.22, 0.18, 0.20), Vector3(side * 0.27, 0.86, -2.65), 7, 4))
	_add_eye_pair(0.91, -2.72, 0.28, 0.075)
	body_root.add_child(Factory.sphere("Nose", Color("#253027"), Vector3(0.36, 0.08, 0.11), Vector3(0.0, 0.63, -3.17), 7, 3))
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
	for side in [-1.0, 1.0]:
		body_root.add_child(Factory.sphere("Eye", Color("#17201d"), Vector3(size, size, size * 0.72), Vector3(side * side_x, height, forward_z), 7, 4))
		body_root.add_child(Factory.sphere("EyeLight", Color("#f2f5df"), Vector3(size * 0.32, size * 0.32, size * 0.20), Vector3(side * (side_x + 0.035), height + size * 0.26, forward_z - size * 0.52), 6, 3))


func _add_legs(color: Color, radius: float, length: float, spread_x: float, spread_z: float, paw_color: Color = Color.TRANSPARENT) -> void:
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
			pivot.add_child(Factory.sphere("PawPad", foot_color, Vector3(radius * 0.50, radius * 0.16, radius * 0.58), toe - upper + Vector3(0.0, -0.015, -0.015), 7, 3))
			leg_pivots.append(pivot)
			if species_id == "rabbit":
				leg_phases.append(0.0 if z_sign < 0.0 else PI)
				leg_stride_scales.append(0.78 if z_sign < 0.0 else 1.28)
			else:
				leg_phases.append(0.0 if x_sign == z_sign else PI)
				leg_stride_scales.append(1.0 if z_sign < 0.0 else 0.92)


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
	_try_attack()
	_update_visual_motion(delta)
	_update_health_bar_visibility(delta)


func _update_timers(delta: float) -> void:
	attack_timer = maxf(attack_timer - delta, 0.0)
	skill_timer = maxf(skill_timer - delta, 0.0)
	eat_timer = maxf(eat_timer - delta, 0.0)
	decision_timer -= delta
	wander_timer -= delta
	spawn_protection = maxf(spawn_protection - delta, 0.0)
	rage_timer = maxf(rage_timer - delta, 0.0)
	rage_cooldown_timer = maxf(rage_cooldown_timer - delta, 0.0)
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


func _update_needs(delta: float) -> void:
	hunger = minf(hunger + float(data["hunger_rate"]) * delta, 100.0)
	if hunger >= 100.0:
		health -= max_health * 0.008 * delta
		health_changed.emit(health, max_health)
		_update_health_bar()
		if is_player and starvation_warning_timer <= 0.0:
			starvation_warning_timer = 5.0
			game.show_hint("饱腹值耗尽，正在持续失去生命！快寻找食物")
		if health <= 0.0:
			die(null)
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
	if game.get("batch_mode") or not is_instance_valid(game.player):
		health_bar_root.visible = false
		return
	health_bar_root.visible = not dead and global_position.distance_to(game.player.global_position) <= 22.0


func reveal_health_bar(duration: float = 4.2) -> void:
	forced_health_bar_timer = maxf(forced_health_bar_timer, duration)
	if health_bar_root != null:
		health_bar_root.visible = not dead


func _update_player_intent() -> void:
	var input_vector: Vector2 = game.get_move_input()
	desired_direction = game.input_to_world(input_vector)
	wants_sprint = game.is_sprint_pressed() and input_vector.length() > 0.15
	attack_intent = game.is_attack_pressed()
	if game.consume_skill_request():
		use_skill(_nearest_living_actor(7.0))
	if game.consume_interact_request():
		try_consume_nearby()
	if species_id == "rabbit" and alert_cooldown <= 0.0:
		for other in game.get_living_actors():
			if other != self and other.ai_state == "hunt" and other.ai_target == self:
				game.show_hint("警觉：附近的天敌盯上了你")
				alert_cooldown = 5.0
				break


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
				var evade_side := Vector3(-away.z, 0.0, away.x) * (-1.0 if actor_id % 2 == 0 else 1.0)
				desired_direction = (away + evade_side * 0.26).normalized()
				wants_sprint = stamina > max_stamina * 0.16
				var flee_skill_range := 4.0 if species_id == "rabbit" else (5.5 if species_id in ["bison", "rhino"] else 3.4)
				if skill_timer <= 0.0 and stamina >= float(data["skill_cost"]) and global_position.distance_to(ai_target.global_position) < flee_skill_range and species_id in ["rabbit", "deer", "boar", "bison", "moose", "rhino", "hippo"]:
					use_skill(ai_target)
			else:
				ai_state = "wander"
		"hunt":
			if is_instance_valid(ai_target) and not ai_target.dead:
				var lead_time := clampf(global_position.distance_to(ai_target.global_position) * 0.035, 0.12, 0.55)
				var predicted_target := ai_target.global_position + Vector3(ai_target.velocity.x, 0.0, ai_target.velocity.z) * lead_time
				var to_target := predicted_target - global_position
				desired_direction = Vector3(to_target.x, 0.0, to_target.z).normalized()
				var distance := global_position.distance_to(ai_target.global_position)
				if species_id in ["wolf", "fox", "lynx", "tiger"] and distance > float(data["attack_range"]) * 1.35:
					var flank := Vector3(-desired_direction.z, 0.0, desired_direction.x) * (-1.0 if actor_id % 2 == 0 else 1.0)
					desired_direction = (desired_direction + flank * (0.32 if species_id == "wolf" else 0.20)).normalized()
				elif distance < float(data["attack_range"]) * 0.72:
					desired_direction = Vector3.ZERO
				wants_sprint = distance > float(data["attack_range"]) * 0.9 and stamina > max_stamina * 0.28
				attack_intent = distance <= float(data["attack_range"]) + 0.65
				if skill_timer <= 0.0 and stamina >= float(data["skill_cost"]) and distance < _skill_engage_range():
					use_skill(ai_target)
			else:
				ai_state = "wander"
		"food":
			if is_instance_valid(resource_target) and (not resource_target is FoodPatch or resource_target.active):
				var to_food := resource_target.global_position - global_position
				desired_direction = Vector3(to_food.x, 0.0, to_food.z).normalized()
				if to_food.length() < 2.0:
					desired_direction = Vector3.ZERO
					try_consume_resource(resource_target)
			else:
				ai_state = "wander"
		"rest":
			desired_direction = Vector3.ZERO
			if stamina > max_stamina * 0.72:
				ai_state = "wander"
		_:
			if wander_timer <= 0.0:
				wander_timer = 1.4 + fmod(float(actor_id) * 0.51 + Time.get_ticks_msec() * 0.001, 2.8)
				var angle := fmod(float(actor_id) * 1.83 + Time.get_ticks_msec() * 0.00037, TAU)
				wander_direction = Vector3(cos(angle), 0.0, sin(angle))
			desired_direction = wander_direction


func _think() -> void:
	var nearest_threat: EcoActor
	var threat_distance := INF
	for other in game.get_living_actors():
		if other == self or other.dead:
			continue
		if Catalog.considers_prey(other.species_id, species_id):
			var distance := global_position.distance_to(other.global_position)
			var stronger: bool = other.health / other.max_health > 0.25 or int(other.data["size"]) >= int(data["size"])
			if distance < threat_distance and stronger:
				nearest_threat = other
				threat_distance = distance
	var flee_distance := 10.0 + int(data["size"]) * 1.5
	if species_id == "rabbit":
		flee_distance += 4.0
	if is_instance_valid(last_attacker) and not last_attacker.dead and health < max_health * 0.42:
		_switch_state("flee", last_attacker)
		return

	if state_commit_timer > 0.0 and ai_state != "wander":
		return

	if is_instance_valid(nearest_threat) and threat_distance < flee_distance and (health < max_health * 0.72 or float(data["courage"]) < 0.4):
		_switch_state("flee", nearest_threat)
		return

	if stamina < max_stamina * 0.20:
		_switch_state("rest", null)
		return

	if hunger > 42.0:
		var resource := _best_food_resource()
		if is_instance_valid(resource):
			if ai_state != "food":
				state_commit_timer = 1.4
			ai_state = "food"
			resource_target = resource
			return

	var prey := _best_prey()
	var hunting_motivation := hunger / 100.0 + float(data["aggression"]) * 0.56
	if is_instance_valid(prey) and hunting_motivation > 0.44:
		_switch_state("hunt", prey)
		return
	if hunger > 25.0 and Catalog.can_eat_food(species_id):
		var plant: Node3D = game.nearest_food(global_position, 28.0, species_id)
		if is_instance_valid(plant):
			if ai_state != "food":
				state_commit_timer = 1.4
			ai_state = "food"
			resource_target = plant
			return
	ai_state = "wander"


func _switch_state(new_state: String, target: EcoActor) -> void:
	if ai_state != new_state:
		state_commit_timer = 1.4
	ai_state = new_state
	ai_target = target


func _skill_engage_range() -> float:
	match species_id:
		"fox": return 5.4
		"wolf": return 5.1
		"snake": return 2.1
		"bear": return 3.4
		"boar": return 5.8
		"lynx": return 5.9
		"bison": return 6.0
		"crocodile": return 2.9
		"tiger": return 6.5
		"moose": return 3.8
		"rhino": return 7.2
		"hippo": return 3.8
		_: return 5.2


func _best_food_resource() -> Node3D:
	var corpse: Node3D
	if Catalog.can_eat_corpse(species_id):
		var corpse_range := 34.0 * (1.4 if species_id == "fox" else (1.22 if species_id == "crocodile" else 1.0))
		corpse = game.nearest_corpse(global_position, corpse_range)
	if is_instance_valid(corpse):
		return corpse
	if Catalog.can_eat_food(species_id):
		return game.nearest_food(global_position, 30.0, species_id)
	var wild_meat: Node3D = game.nearest_food(global_position, 26.0, species_id)
	if is_instance_valid(wild_meat):
		return wild_meat
	return null


func _best_prey() -> EcoActor:
	var best: EcoActor
	var best_score := -INF
	for other in game.get_living_actors():
		if other == self or other.dead or other.spawn_protection > 0.0 or not Catalog.considers_prey(species_id, other.species_id):
			continue
		var distance := global_position.distance_to(other.global_position)
		var detect_range := 27.0 * (0.6 if other.is_stealthed() else 1.0)
		if other.scent_mark_timer > 0.0:
			detect_range *= 1.65
		if species_id in ["fox", "lynx", "tiger"] and other.health / other.max_health < 0.30:
			detect_range *= 1.6
		if distance > detect_range:
			continue
		var weakness: float = 1.0 + (1.0 - other.health / other.max_health) * 2.2
		var size_risk: float = maxf(0.35, 1.0 + float(int(data["size"]) - int(other.data["size"])) * 0.22)
		var score: float = weakness * size_risk / maxf(distance, 2.0)
		if other.scent_mark_timer > 0.0:
			score *= 2.15
		if score > best_score:
			best_score = score
			best = other
	return best


func _apply_movement(delta: float) -> void:
	var flat_direction := Vector3(desired_direction.x, 0.0, desired_direction.z).normalized()
	if not is_player and game.world != null and flat_direction.length() > 0.1:
		flat_direction = game.world.steer_around_obstacles(global_position, flat_direction, 0.52 + int(data["size"]) * 0.09, actor_id)
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
				var side_sign := -1.0 if (actor_id + int(Time.get_ticks_msec() / 1000)) % 2 == 0 else 1.0
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
	var speed := float(data["speed"])
	if slow_timer > 0.0:
		speed *= slow_multiplier
	var sprinting := wants_sprint and stamina > 0.0 and flat_direction.length() > 0.1
	if sprinting and flat_direction.dot(previous_flat_direction) > 0.9:
		straight_run_timer += delta
	else:
		straight_run_timer = 0.0
	previous_flat_direction = flat_direction
	if sprinting:
		speed *= float(data["sprint"])
		var sprint_cost := 8.5 + int(data["size"]) * 1.7
		if species_id in ["deer", "bison", "rhino"] and straight_run_timer > 2.0:
			sprint_cost *= 0.82
		stamina = maxf(stamina - sprint_cost * delta, 0.0)
	else:
		var hunger_factor := 1.0 if hunger < 70.0 else (0.85 if hunger < 90.0 else 0.65)
		stamina = minf(stamina + float(data["regen"]) * hunger_factor * delta * (1.0 if flat_direction.length() < 0.1 else 0.70), max_stamina)
	if dash_timer > 0.0:
		dash_timer -= delta
		flat_direction = dash_direction
		speed = float(data["speed"]) * 2.25
	velocity.x = move_toward(velocity.x, flat_direction.x * speed, delta * speed * 8.0)
	velocity.z = move_toward(velocity.z, flat_direction.z * speed, delta * speed * 8.0)
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.8
	move_and_slide()
	var wall_normal := Vector3.ZERO
	if not is_player:
		for collision_index in range(get_slide_collision_count()):
			var candidate_normal := get_slide_collision(collision_index).get_normal()
			if absf(candidate_normal.y) < 0.55:
				wall_normal = candidate_normal
				break
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
	if flat_direction.length() > 0.12:
		var target_angle := atan2(-flat_direction.x, -flat_direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 1.0 - exp(-delta * (7.0 if int(data["size"]) < 4 else 4.2)))
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	still_timer = still_timer + delta if flat_speed < 0.35 else 0.0
	if is_player:
		stamina_changed.emit(stamina, max_stamina)


func _try_attack() -> void:
	if not attack_intent or attack_timer > 0.0 or stamina < float(data["attack_cost"]):
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
	if species_id == "wolf":
		var nearby_pack := 0
		for other in game.get_living_actors():
			if other != self and other.species_id == "wolf" and global_position.distance_to(other.global_position) < 12.0:
				nearby_pack += 1
		attack_cost *= 1.0 - mini(nearby_pack, 3) * 0.06
	stamina -= attack_cost
	var damage := float(data["attack"])
	if not is_player:
		damage *= game.get_ai_damage_multiplier()
	if species_id in ["fox", "lynx"] and target.health / target.max_health < 0.30:
		damage *= 1.12
	if rage_timer > 0.0:
		damage *= 1.1
	target.take_damage(damage, self)
	if game.has_method("play_sfx_near"):
		game.play_sfx_near("attack", global_position, is_player)
	_play_attack_pulse()


func use_skill(target: EcoActor = null) -> bool:
	if dead or skill_timer > 0.0 or stamina < float(data["skill_cost"]):
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
	if used:
		spawn_protection = 0.0
		stamina -= float(data["skill_cost"])
		skill_timer = float(data["skill_cooldown"])
		if game.has_method("play_sfx_near"):
			game.play_sfx_near("skill_%s" % species_id, global_position, is_player)
		_play_species_skill_animation()
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


func _should_show_skill_vfx() -> bool:
	if not is_instance_valid(game) or game.get("batch_mode"):
		return false
	var game_player := game.get("player") as EcoActor
	return is_player or not is_instance_valid(game_player) or global_position.distance_to(game_player.global_position) <= 36.0


func _skill_damage(attack_factor: float) -> float:
	var result := float(data["attack"]) * attack_factor
	if not is_player:
		result *= game.get_ai_damage_multiplier()
	return result


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


func _rally_pack(target: EcoActor, radius: float) -> int:
	if not is_instance_valid(target):
		return 0
	var rallied := 0
	for other in game.get_living_actors():
		if other == self or other.dead or other.is_player or other.species_id != "wolf":
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
	var armor := float(data["armor"])
	var reduction := armor / (armor + 100.0)
	var size_scale := 1.0
	if is_instance_valid(source):
		size_scale = clampf(1.0 + (int(source.data["size"]) - int(data["size"])) * 0.12, 0.65, 1.45)
		last_attacker = source
		register_ecology_influence(source, 8.0)
		if not is_player:
			ai_target = source
			ai_state = "hunt" if health / max_health > 0.35 and float(data["courage"]) > 0.35 else "flee"
	var final_damage := maxf(raw_damage * size_scale * (1.0 - reduction), 1.0)
	health -= final_damage
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


func apply_poison(dps: float, duration: float, source: EcoActor) -> void:
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


func register_ecology_influence(source: EcoActor, duration: float) -> void:
	if not is_instance_valid(source) or source == self:
		return
	if source.is_player or not is_instance_valid(ecology_influence_source) or ecology_influence_timer <= 0.0:
		ecology_influence_source = source
		ecology_influence_timer = maxf(ecology_influence_timer, duration)


func apply_knockback(direction: Vector3, strength: float) -> void:
	if species_id == "boar" and health / max_health < 0.50:
		strength *= 0.46
	elif species_id in ["rhino", "hippo"]:
		strength *= 0.62
	velocity += Vector3(direction.x, 0.15, direction.z).normalized() * strength


func try_consume_nearby() -> bool:
	var resource := _best_food_resource()
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
	var eaten: float = resource.consume(14.0)
	if eaten <= 0.0:
		return false
	eat_timer = 1.0
	var nutrition_multiplier: float = resource.get_nutrition_multiplier() if resource is FoodPatch else 1.0
	hunger = maxf(hunger - eaten * 0.85 * nutrition_multiplier, 0.0)
	health = minf(health + eaten * ((0.28 if is_corpse else 0.12) * nutrition_multiplier), max_health)
	health_changed.emit(health, max_health)
	_update_health_bar()
	if game.has_method("play_sfx_near"):
		game.play_sfx_near("eat", global_position, is_player)
	if is_player:
		var food_name: String = str(resource.get_food_name()) if resource is FoodPatch else "猎物尸体"
		game.show_hint("进食%s，恢复了生命与饱腹" % food_name)
	return true


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
	var old_max_health := max_health
	max_health *= 1.10
	max_stamina *= 1.055
	data["attack"] = float(data["attack"]) * 1.065
	data["armor"] = float(data["armor"]) + 1.5
	data["speed"] = float(data["speed"]) * 1.012
	health = minf(max_health, health + (max_health - old_max_health) + max_health * 0.22)
	stamina = minf(max_stamina, stamina + max_stamina * 0.35)
	_update_health_bar()
	if is_player and game.has_method("on_player_level_up"):
		game.on_player_level_up(level)


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
	tween.set_parallel(true)
	tween.tween_property(visual_root, "scale", Vector3(1.2, 0.12, 1.2), 0.35)
	await get_tree().create_timer(0.38).timeout
	visible = false
	await get_tree().create_timer(1.0).timeout
	queue_free()


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
	if body_root != null:
		var bob_height := minf(flat_speed * 0.009, 0.052) * gait_blend
		body_root.position.y = (sin(move_time * 2.0) * 0.5 + 0.5) * bob_height
		body_root.rotation.z = sin(move_time) * minf(flat_speed * 0.007, 0.032) * gait_blend
		if species_id == "snake":
			body_root.rotation.y = lerp_angle(body_root.rotation.y, sin(move_time * 0.92) * 0.13 * gait_blend, 1.0 - exp(-delta * 8.0))
		else:
			body_root.rotation.y = lerp_angle(body_root.rotation.y, 0.0, 1.0 - exp(-delta * 8.0))
	if selection_ring != null:
		selection_ring.rotation.y += delta * 0.35


func _gait_stride_amplitude() -> float:
	match species_id:
		"rabbit": return 0.72
		"deer", "moose": return 0.58
		"fox", "lynx": return 0.55
		"wolf", "tiger": return 0.50
		"boar": return 0.48
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
