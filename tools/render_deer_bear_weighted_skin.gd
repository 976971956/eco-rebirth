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
		{"species": "deer", "id": "run", "label": "林鹿 · 轻步伸颈", "position": Vector3(5.0, 0.0, 2.55), "time": 1.15, "attack": 0.0, "hit": 0.0, "scale": 0.62},
		{"species": "deer", "id": "attack", "label": "林鹿 · 角击前压", "position": Vector3(0.0, 0.0, 2.55), "time": 1.45, "attack": 0.5, "hit": 0.0, "scale": 0.62},
		{"species": "deer", "id": "hit", "label": "林鹿 · 受击缓冲", "position": Vector3(-5.0, 0.0, 2.55), "time": 1.65, "attack": 0.0, "hit": 0.5, "scale": 0.62},
		{"species": "bear", "id": "run", "label": "棕熊 · 低频重步", "position": Vector3(5.0, 0.0, -2.85), "time": 1.15, "attack": 0.0, "hit": 0.0, "scale": 0.62},
		{"species": "bear", "id": "attack", "label": "棕熊 · 肩胸拍击", "position": Vector3(0.0, 0.0, -2.85), "time": 1.45, "attack": 0.5, "hit": 0.0, "scale": 0.62},
		{"species": "bear", "id": "hit", "label": "棕熊 · 躯干后坐", "position": Vector3(-5.0, 0.0, -2.85), "time": 1.65, "attack": 0.0, "hit": 0.5, "scale": 0.62},
	]
	for state_index in range(states.size()):
		var state_data: Dictionary = states[state_index]
		var species_id := str(state_data["species"])
		var actor: EcoActor = ActorScript.new()
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		scene.add_child(actor)
		actor.setup(game_stub, state_index + 1, species_id, true, Vector3.ZERO, 0)
		actor.position = state_data["position"]
		actor.scale = Vector3.ONE * float(state_data["scale"])
		actor.rotation.y = 0.92
		_hide_actor_ui(actor)
		SkeletonRig.apply_pose(
			actor.external_skeleton,
			str(state_data["id"]),
			float(state_data["time"]),
			0.58 if species_id == "deer" else 0.40,
			1.0,
			float(state_data["attack"]),
			float(state_data["hit"]),
			float(state_index) * 0.61,
			1.0,
			species_id
		)
		actor.external_skeleton.force_update_all_bone_transforms()
		_add_label(scene, str(state_data["label"]), actor.position + Vector3(0.0, 3.05 if species_id == "deer" else 2.45, 0.0), 30)

	_add_label(scene, "林鹿 / 棕熊连续体轴 · Hero / Mobile 共用权重 · 六种代表动物根比例已锁定", Vector3(0.0, 4.35, 4.35), 37)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 11.4
	camera.position = Vector3(0.0, 13.2, -23.0)
	scene.add_child(camera)
	camera.look_at(Vector3(0.0, 1.35, 0.0), Vector3.UP)
	camera.current = true

	for _frame in range(14):
		await process_frame
	var output_path := "res://docs/images/v37-deer-bear-weighted-scale.png"
	var image := root.get_texture().get_image()
	var result := image.save_png(output_path)
	if result == OK:
		print("DEER_BEAR_WEIGHTED_SHOWCASE_OK: %s" % ProjectSettings.globalize_path(output_path))
		quit(0)
	else:
		push_error("无法保存林鹿/棕熊连续蒙皮验收图：%s" % result)
		quit(1)


func _build_environment(scene: Node3D) -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#344f58")
	sky_material.sky_horizon_color = Color("#b9b78f")
	sky_material.ground_horizon_color = Color("#405647")
	sky_material.ground_bottom_color = Color("#102019")
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.56
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 0.96
	environment.adjustment_contrast = 1.11
	environment.adjustment_saturation = 1.02
	environment_node.environment = environment
	scene.add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	sun.light_color = Color("#ffe2b1")
	sun.light_energy = 0.94
	sun.shadow_enabled = true
	scene.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("#a9d5df")
	fill.light_energy = 0.40
	fill.rotation_degrees = Vector3(58.0, 148.0, 0.0)
	scene.add_child(fill)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(31.0, 24.0)
	ground.mesh = plane
	ground.material_override = Factory.terrain_material(Color("#334d35"), Color("#526b43"), 12.0, FOREST_GROUND_TEXTURE, 6.0, 0.24)
	scene.add_child(ground)


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
