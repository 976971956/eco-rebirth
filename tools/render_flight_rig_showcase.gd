extends SceneTree

const ActorScript = preload("res://scripts/eco_actor.gd")
const Factory = preload("res://scripts/low_poly_factory.gd")
const FlightRig = preload("res://scripts/species_flight_rig.gd")
const HIGHLAND_GROUND_TEXTURE = preload("res://assets/textures/terrain/forest_floor_ai.jpg")

class ShowcaseGame:
	extends Node
	var batch_mode: bool = false
	var player: EcoActor
	var world: Node
	var world_seed: int = 20260815

	func get_quality_preset() -> String:
		return "high"


func _initialize() -> void:
	_build_showcase.call_deferred()


func _build_showcase() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var game_stub := ShowcaseGame.new()
	scene.add_child(game_stub)
	_build_environment(scene)

	var states := [
		{"id": "glide", "label": "滑翔 · 展翼巡航", "time": 0.4, "speed": 0.12, "dive": 0.0, "hit": 0.0},
		{"id": "flap", "label": "振翅 · 对称升力", "time": 0.95, "speed": 0.88, "dive": 0.0, "hit": 0.0},
		{"id": "dive", "label": "俯冲 · 收翼伸爪", "time": 1.25, "speed": 1.0, "dive": 0.5, "hit": 0.0},
		{"id": "hit", "label": "受击 · 失衡修正", "time": 1.6, "speed": 0.32, "dive": 0.0, "hit": 0.5},
	]
	# The camera faces +Z, so positive world X appears on the left of the image.
	var positions := [
		Vector3(4.05, 2.0, 2.45),
		Vector3(-4.05, 2.0, 2.45),
		Vector3(4.05, 1.85, -2.75),
		Vector3(-4.05, 1.85, -2.75),
	]
	for state_index in range(states.size()):
		var state_data: Dictionary = states[state_index]
		var actor: EcoActor = ActorScript.new()
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		scene.add_child(actor)
		actor.setup(game_stub, state_index + 1, "eagle", true, Vector3.ZERO, 0)
		actor.position = positions[state_index]
		actor.scale = Vector3.ONE * 0.82
		actor.rotation.y = 0.18
		_hide_actor_ui(actor)
		FlightRig.apply_pose(
			actor.external_skeleton,
			str(state_data["id"]),
			float(state_data["time"]),
			float(state_data["speed"]),
			float(state_data["dive"]),
			float(state_data["hit"]),
			float(state_index) * 0.73,
			1.0
		)
		actor.external_skeleton.force_update_all_bone_transforms()
		_add_socket_marker(actor.external_skill_sockets.get("SkillSocket_Beak") as Node3D, Color("#ffd46a"), 0.18)
		_add_socket_marker(actor.external_skill_sockets.get("SkillSocket_Wing_L") as Node3D, Color("#66dcff"), 0.16)
		_add_socket_marker(actor.external_skill_sockets.get("SkillSocket_Wing_R") as Node3D, Color("#66dcff"), 0.16)
		var label_height := 1.75 if state_index < 2 else 3.0
		_add_label(scene, str(state_data["label"]), actor.position + Vector3(0.0, label_height, 0.0), 34)

	_add_label(scene, "高原金雕飞行骨架 · 黄：俯冲喙击挂点  蓝：双翼尾流挂点", Vector3(0.0, 6.15, 2.8), 42)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 11.8
	camera.position = Vector3(0.0, 12.4, -23.5)
	scene.add_child(camera)
	camera.look_at(Vector3(0.0, 2.05, 0.15), Vector3.UP)
	camera.current = true

	for _frame in range(12):
		await process_frame
	var output_path := "res://docs/images/v34-eagle-flight-rig.png"
	var image := root.get_texture().get_image()
	var result := image.save_png(output_path)
	if result == OK:
		print("FLIGHT_RIG_SHOWCASE_OK: %s" % ProjectSettings.globalize_path(output_path))
		quit(0)
	else:
		push_error("无法保存飞行骨架验收图：%s" % result)
		quit(1)


func _build_environment(scene: Node3D) -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#203f54")
	sky_material.sky_horizon_color = Color("#d4bf87")
	sky_material.ground_horizon_color = Color("#556044")
	sky_material.ground_bottom_color = Color("#162319")
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.66
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.0
	environment.adjustment_contrast = 1.12
	environment.adjustment_saturation = 1.06
	environment_node.environment = environment
	scene.add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-47.0, -34.0, 0.0)
	sun.light_color = Color("#ffe0a4")
	sun.light_energy = 1.08
	sun.shadow_enabled = true
	scene.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("#9fdcf2")
	fill.light_energy = 0.48
	fill.rotation_degrees = Vector3(55.0, 148.0, 0.0)
	scene.add_child(fill)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30.0, 22.0)
	ground.mesh = plane
	ground.material_override = Factory.terrain_material(Color("#384a32"), Color("#697048"), 12.0, HIGHLAND_GROUND_TEXTURE, 6.0, 0.22)
	scene.add_child(ground)


func _add_socket_marker(socket: Node3D, color: Color, radius: float) -> void:
	if socket == null:
		return
	var marker := Factory.sphere("SocketMarker", color, Vector3.ONE * radius, Vector3.ZERO, 8, 5)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var marker_material := Factory.material(color, 0.24, color)
	marker_material.no_depth_test = true
	marker.material_override = marker_material
	socket.add_child(marker)


func _hide_actor_ui(actor: EcoActor) -> void:
	actor.health_bar_root.visible = false
	if actor.selection_ring != null:
		actor.selection_ring.visible = false
	var player_arrow := actor.get_node_or_null("PlayerArrow") as Node3D
	if player_arrow != null:
		player_arrow.visible = false
	var player_label := actor.get_node_or_null("PlayerLabel") as Label3D
	if player_label != null:
		player_label.visible = false


func _add_label(scene: Node3D, label_text: String, label_position: Vector3, font_size: int) -> void:
	var label := Label3D.new()
	label.text = label_text
	label.font = load("res://assets/fonts/NotoSansSC-VF.ttf") as Font
	label.font_size = font_size
	label.outline_size = 8
	label.modulate = Color("#f8f1d6")
	label.outline_modulate = Color(0.02, 0.04, 0.025, 0.96)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.0105
	label.position = label_position
	scene.add_child(label)
