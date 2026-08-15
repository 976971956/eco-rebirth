extends SceneTree

const ActorScript = preload("res://scripts/eco_actor.gd")
const Factory = preload("res://scripts/low_poly_factory.gd")
const SkeletonRig = preload("res://scripts/species_skeleton_rig.gd")
const GRASSLAND_GROUND_TEXTURE = preload("res://assets/textures/terrain/grassland_ai.jpg")


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
	_add_grass_patch(scene, Vector3(0.0, 0.04, 2.5))

	var states := [
		{"id": "run", "label": "跳跃 · 脊柱伸缩", "position": Vector3(4.55, 0.0, 2.45), "time": 1.55, "action": 0.0, "hit": 0.0},
		{"id": "forage", "label": "吃草 · 低头咀嚼", "position": Vector3(0.0, 0.0, 2.65), "time": 1.30, "action": 0.0, "hit": 0.0},
		{"id": "skill", "label": "月影折跃 · 后足蹬地", "position": Vector3(-4.55, 0.0, 2.45), "time": 1.45, "action": 0.5, "hit": 0.0},
		{"id": "attack", "label": "反击 · 前后足发力", "position": Vector3(4.35, 0.0, -2.55), "time": 1.25, "action": 0.5, "hit": 0.0},
		{"id": "hit", "label": "受击 · 头颈缓冲", "position": Vector3(0.0, 0.0, -2.85), "time": 1.65, "action": 0.0, "hit": 0.5},
		{"id": "dead", "label": "倒地 · 自然侧卧", "position": Vector3(-4.35, 0.0, -2.55), "time": 1.20, "action": 0.0, "hit": 0.0},
	]
	for state_index in range(states.size()):
		var state_data: Dictionary = states[state_index]
		var actor: EcoActor = ActorScript.new()
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		scene.add_child(actor)
		actor.setup(game_stub, state_index + 1, "rabbit", true, Vector3.ZERO, 0)
		actor.position = state_data["position"]
		actor.scale = Vector3.ONE * 0.93
		actor.rotation.y = 0.94
		_hide_actor_ui(actor)
		SkeletonRig.apply_pose(
			actor.external_skeleton,
			str(state_data["id"]),
			float(state_data["time"]),
			0.68,
			1.0,
			float(state_data["action"]),
			float(state_data["hit"]),
			float(state_index) * 0.71,
			1.0,
			"rabbit"
		)
		actor.external_skeleton.force_update_all_bone_transforms()
		_add_socket_marker(actor.external_skill_sockets.get("SkillSocket_Mouth") as Node3D, Color("#ffd778"), 0.12)
		_add_socket_marker(actor.external_skill_sockets.get("SkillSocket_Chest") as Node3D, Color("#8deaff"), 0.13)
		_add_label(scene, str(state_data["label"]), actor.position + Vector3(0.0, 2.45, 0.0), 29)

	_add_label(scene, "雪兔连续蒙皮 · 黄：吻部感知挂点  蓝：月影折跃挂点", Vector3(0.0, 4.1, 4.35), 40)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.8
	camera.position = Vector3(0.0, 12.9, -22.5)
	scene.add_child(camera)
	camera.look_at(Vector3(0.0, 1.15, 0.0), Vector3.UP)
	camera.current = true

	for _frame in range(14):
		await process_frame
	var output_path := "res://docs/images/v36-rabbit-weighted-skin.png"
	var image := root.get_texture().get_image()
	var result := image.save_png(output_path)
	if result == OK:
		print("RABBIT_WEIGHTED_SKIN_SHOWCASE_OK: %s" % ProjectSettings.globalize_path(output_path))
		quit(0)
	else:
		push_error("无法保存雪兔连续蒙皮验收图：%s" % result)
		quit(1)


func _build_environment(scene: Node3D) -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#5f93ad")
	sky_material.sky_horizon_color = Color("#d9c995")
	sky_material.ground_horizon_color = Color("#78945f")
	sky_material.ground_bottom_color = Color("#263c2a")
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 0.92
	environment.adjustment_contrast = 1.12
	environment.adjustment_saturation = 0.94
	environment_node.environment = environment
	scene.add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -34.0, 0.0)
	sun.light_color = Color("#ffe8ba")
	sun.light_energy = 0.74
	sun.shadow_enabled = true
	scene.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("#b8dff2")
	fill.light_energy = 0.28
	fill.rotation_degrees = Vector3(54.0, 138.0, 0.0)
	scene.add_child(fill)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(31.0, 23.0)
	ground.mesh = plane
	ground.material_override = Factory.terrain_material(Color("#738758"), Color("#9cab69"), 12.0, GRASSLAND_GROUND_TEXTURE, 6.0, 0.20)
	scene.add_child(ground)


func _add_grass_patch(scene: Node3D, patch_position: Vector3) -> void:
	for index in range(13):
		var angle := float(index) * TAU / 13.0
		var radius := 0.35 + float(index % 4) * 0.19
		var grass := Factory.tapered_cylinder("TenderGrass", Color("#90bd5d"), 0.035, 0.012, 0.42 + float(index % 3) * 0.08, patch_position + Vector3(cos(angle) * radius, 0.22, sin(angle) * radius), 5)
		grass.rotation.z = sin(angle) * 0.12
		scene.add_child(grass)


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
	label.modulate = Color("#f8f4df")
	label.outline_modulate = Color(0.03, 0.06, 0.03, 0.96)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.0105
	label.position = label_position
	scene.add_child(label)
