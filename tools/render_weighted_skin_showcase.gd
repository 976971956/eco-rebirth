extends SceneTree

const ActorScript = preload("res://scripts/eco_actor.gd")
const Factory = preload("res://scripts/low_poly_factory.gd")
const SkeletonRig = preload("res://scripts/species_skeleton_rig.gd")
const FOREST_GROUND_TEXTURE = preload("res://assets/textures/terrain/forest_floor_ai.jpg")

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
		{"id": "idle", "label": "待机 · 头颈稳定", "time": 0.9, "attack": 0.0, "hit": 0.0},
		{"id": "run", "label": "小跑 · 肩胛摆动", "time": 1.8, "attack": 0.0, "hit": 0.0},
		{"id": "attack", "label": "扑咬 · 躯干伸展", "time": 1.2, "attack": 0.5, "hit": 0.0},
		{"id": "hit", "label": "受击 · 颈部缓冲", "time": 1.2, "attack": 0.0, "hit": 0.5},
	]
	var x_positions := [5.55, 1.85, -1.85, -5.55]
	for state_index in range(states.size()):
		var state_data: Dictionary = states[state_index]
		var actor: EcoActor = ActorScript.new()
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		scene.add_child(actor)
		actor.setup(game_stub, state_index + 1, "wolf", true, Vector3(x_positions[state_index], 0.0, 0.0), 0)
		actor.scale = Vector3.ONE * 0.86
		actor.rotation.y = 0.18
		_hide_actor_ui(actor)
		SkeletonRig.apply_pose(
			actor.external_skeleton,
			str(state_data["id"]),
			float(state_data["time"]),
			0.72,
			1.0,
			float(state_data["attack"]),
			float(state_data["hit"]),
			float(state_index) * 0.73,
			1.0,
			"wolf"
		)
		actor.external_skeleton.force_update_all_bone_transforms()
		_add_socket_marker(actor.external_skill_sockets.get("SkillSocket_Mouth") as Node3D, Color("#ffd46a"), 0.15)
		_add_socket_marker(actor.external_skill_sockets.get("SkillSocket_Chest") as Node3D, Color("#70ddff"), 0.17)
		_add_label(scene, str(state_data["label"]), actor.position + Vector3(0.0, 3.18, 0.0), 30)

	_add_label(scene, "灰狼连续权重蒙皮原型 · 黄：扑咬挂点  蓝：群体号召挂点", Vector3(0.0, 4.55, 0.0), 40)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 9.1
	camera.position = Vector3(0.0, 8.8, -20.5)
	scene.add_child(camera)
	camera.look_at(Vector3(0.0, 1.55, 0.0), Vector3.UP)
	camera.current = true

	for _frame in range(12):
		await process_frame
	var output_path := "res://docs/images/v33-wolf-weighted-skin.png"
	var image := root.get_texture().get_image()
	var result := image.save_png(output_path)
	if result == OK:
		print("WEIGHTED_SKIN_SHOWCASE_OK: %s" % ProjectSettings.globalize_path(output_path))
		quit(0)
	else:
		push_error("无法保存连续蒙皮验收图：%s" % result)
		quit(1)


func _build_environment(scene: Node3D) -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#263e48")
	sky_material.sky_horizon_color = Color("#b9b28c")
	sky_material.ground_horizon_color = Color("#3c5544")
	sky_material.ground_bottom_color = Color("#101e19")
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 0.98
	environment.adjustment_contrast = 1.12
	environment.adjustment_saturation = 1.06
	environment_node.environment = environment
	scene.add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -31.0, 0.0)
	sun.light_color = Color("#ffe0aa")
	sun.light_energy = 1.02
	sun.shadow_enabled = true
	scene.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("#9fd8e6")
	fill.light_energy = 0.46
	fill.rotation_degrees = Vector3(54.0, 146.0, 0.0)
	scene.add_child(fill)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30.0, 16.0)
	ground.mesh = plane
	ground.material_override = Factory.terrain_material(Color("#314c35"), Color("#526d47"), 12.0, FOREST_GROUND_TEXTURE, 6.0, 0.24)
	scene.add_child(ground)


func _add_socket_marker(socket: Node3D, color: Color, radius: float) -> void:
	if socket == null:
		return
	var marker := Factory.sphere("SocketMarker", color, Vector3.ONE * radius, Vector3.ZERO, 8, 5)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var marker_material := Factory.material(color, 0.25, color)
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
	label.modulate = Color("#f5f1d8")
	label.outline_modulate = Color(0.02, 0.05, 0.025, 0.96)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.0105
	label.position = label_position
	scene.add_child(label)
