extends SceneTree

const ActorScript = preload("res://scripts/eco_actor.gd")
const Factory = preload("res://scripts/low_poly_factory.gd")
const CrocodileRig = preload("res://scripts/species_crocodile_rig.gd")
const WETLAND_GROUND_TEXTURE = preload("res://assets/textures/terrain/wetland_ai.jpg")

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
	_add_water_patch(scene, Vector3(0.0, 0.04, 2.75))

	var states := [
		{"id": "crawl", "label": "爬行 · 低姿对角步", "position": Vector3(5.1, 0.0, 2.75), "time": 1.35, "attack": 0.0, "roll": 0.0, "hit": 0.0},
		{"id": "swim", "label": "游动 · 三段尾推进", "position": Vector3(0.0, 0.12, 2.75), "time": 1.10, "attack": 0.0, "roll": 0.0, "hit": 0.0},
		{"id": "attack", "label": "咬击 · 颌骨张合", "position": Vector3(-5.1, 0.0, 2.75), "time": 1.35, "attack": 0.5, "roll": 0.0, "hit": 0.0},
		{"id": "roll", "label": "死亡翻滚 · 躯干侧卷", "position": Vector3(3.0, 0.0, -3.15), "time": 1.55, "attack": 0.0, "roll": 0.5, "hit": 0.0},
		{"id": "hit", "label": "受击 · 头尾缓冲", "position": Vector3(-3.0, 0.0, -3.15), "time": 1.70, "attack": 0.0, "roll": 0.0, "hit": 0.5},
	]
	for state_index in range(states.size()):
		var state_data: Dictionary = states[state_index]
		var actor: EcoActor = ActorScript.new()
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		scene.add_child(actor)
		actor.setup(game_stub, state_index + 1, "crocodile", true, Vector3.ZERO, 0)
		actor.position = state_data["position"]
		actor.scale = Vector3.ONE * 0.65
		actor.rotation.y = 1.02
		_hide_actor_ui(actor)
		CrocodileRig.apply_pose(
			actor.external_skeleton,
			str(state_data["id"]),
			float(state_data["time"]),
			1.0,
			float(state_data["attack"]),
			float(state_data["roll"]),
			float(state_data["hit"]),
			float(state_index) * 0.71,
			1.0
		)
		actor.external_skeleton.force_update_all_bone_transforms()
		_add_socket_marker(actor.external_skill_sockets.get("SkillSocket_Jaw") as Node3D, Color("#ffd469"), 0.19)
		_add_socket_marker(actor.external_skill_sockets.get("SkillSocket_TailTip") as Node3D, Color("#66dcff"), 0.18)
		_add_label(scene, str(state_data["label"]), actor.position + Vector3(0.0, 1.72, 0.0), 30)

	_add_label(scene, "沼泽鳄连续长躯干骨架 · 黄：吻部咬合挂点  蓝：尾端水流挂点", Vector3(0.0, 4.0, 4.6), 40)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.4
	camera.position = Vector3(0.0, 13.8, -23.0)
	scene.add_child(camera)
	camera.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)
	camera.current = true

	for _frame in range(14):
		await process_frame
	var output_path := "res://docs/images/v35-crocodile-long-body-rig.png"
	var image := root.get_texture().get_image()
	var result := image.save_png(output_path)
	if result == OK:
		print("CROCODILE_RIG_SHOWCASE_OK: %s" % ProjectSettings.globalize_path(output_path))
		quit(0)
	else:
		push_error("无法保存沼泽鳄长躯干骨架验收图：%s" % result)
		quit(1)


func _build_environment(scene: Node3D) -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#294a54")
	sky_material.sky_horizon_color = Color("#a9b996")
	sky_material.ground_horizon_color = Color("#405f4b")
	sky_material.ground_bottom_color = Color("#10251f")
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.68
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.0
	environment.adjustment_contrast = 1.11
	environment.adjustment_saturation = 1.04
	environment_node.environment = environment
	scene.add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -28.0, 0.0)
	sun.light_color = Color("#ffe3ae")
	sun.light_energy = 1.02
	sun.shadow_enabled = true
	scene.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("#9ed9df")
	fill.light_energy = 0.46
	fill.rotation_degrees = Vector3(56.0, 146.0, 0.0)
	scene.add_child(fill)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(31.0, 24.0)
	ground.mesh = plane
	ground.material_override = Factory.terrain_material(Color("#334d3c"), Color("#55705b"), 12.0, WETLAND_GROUND_TEXTURE, 6.0, 0.22)
	scene.add_child(ground)


func _add_water_patch(scene: Node3D, patch_position: Vector3) -> void:
	var patch := MeshInstance3D.new()
	patch.name = "ShallowWaterPatch"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 2.45
	cylinder.bottom_radius = 2.45
	cylinder.height = 0.035
	cylinder.radial_segments = 32
	patch.mesh = cylinder
	patch.position = patch_position
	var water_material := Factory.material(Color(0.18, 0.48, 0.52, 0.30), 0.22, Color(0.04, 0.20, 0.24, 0.12))
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	patch.material_override = water_material
	scene.add_child(patch)


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
	label.modulate = Color("#f5f1d7")
	label.outline_modulate = Color(0.02, 0.05, 0.03, 0.96)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.0105
	label.position = label_position
	scene.add_child(label)
