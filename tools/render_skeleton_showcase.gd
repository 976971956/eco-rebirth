extends SceneTree

const ActorScript = preload("res://scripts/eco_actor.gd")
const Catalog = preload("res://scripts/species_catalog.gd")
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

	var states: Array[String] = ["idle", "run", "attack", "hit"]
	var state_names: Array[String] = ["待机", "奔跑", "攻击", "受击"]
	# The camera faces +Z, so positive world X appears on the left of the image.
	var x_positions := [6.0, 2.0, -2.0, -6.0]
	var species_rows := [
		{"id": "rabbit", "z": 3.0, "scale": 1.08},
		{"id": "wolf", "z": -2.2, "scale": 0.86},
	]
	var actor_index := 0
	for row in species_rows:
		for state_index in range(states.size()):
			var species_id := str(row["id"])
			var actor: EcoActor = ActorScript.new()
			actor.process_mode = Node.PROCESS_MODE_DISABLED
			scene.add_child(actor)
			actor.setup(game_stub, actor_index + 1, species_id, true, Vector3(x_positions[state_index], 0.0, float(row["z"])), 0)
			actor.scale = Vector3.ONE * float(row["scale"])
			actor.rotation.y = 0.23
			_hide_actor_ui(actor)
			var state: String = states[state_index]
			SkeletonRig.apply_pose(
				actor.external_skeleton,
				state,
				1.15 + state_index * 0.62,
				0.68,
				1.0,
				0.5 if state == "attack" else 0.0,
				0.5 if state == "hit" else 0.0,
				float(actor_index) * 0.47,
				1.0
			)
			var label_offset := Vector3(0.0, 3.25, 0.0) if species_id == "rabbit" else Vector3(0.0, 0.18, -0.82)
			_add_label(
				scene,
				"%s · %s" % [Catalog.display_name(species_id), state_names[state_index]],
				actor.position + label_offset
			)
			actor_index += 1

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 11.3
	camera.position = Vector3(0.0, 11.8, -20.5)
	scene.add_child(camera)
	camera.look_at(Vector3(0.0, 1.35, 0.8), Vector3.UP)
	camera.current = true

	for _frame in range(10):
		await process_frame
	var output_path := "res://docs/images/v31-skeleton-animation-phase2.png"
	var image := root.get_texture().get_image()
	var result := image.save_png(output_path)
	if result == OK:
		print("SKELETON_SHOWCASE_OK: %s" % ProjectSettings.globalize_path(output_path))
		quit(0)
	else:
		push_error("无法保存骨骼动画验收图：%s" % result)
		quit(1)


func _build_environment(scene: Node3D) -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#334d55")
	sky_material.sky_horizon_color = Color("#b5b28c")
	sky_material.ground_horizon_color = Color("#405448")
	sky_material.ground_bottom_color = Color("#101f1a")
	sky_material.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.58
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 0.96
	environment.adjustment_contrast = 1.12
	environment.adjustment_saturation = 1.05
	environment_node.environment = environment
	scene.add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -28.0, 0.0)
	sun.light_color = Color("#ffe1b0")
	sun.light_energy = 0.96
	sun.shadow_enabled = true
	scene.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("#a9d5df")
	fill.light_energy = 0.48
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


func _add_label(scene: Node3D, label_text: String, label_position: Vector3) -> void:
	var label := Label3D.new()
	label.text = label_text
	label.font = load("res://assets/fonts/NotoSansSC-VF.ttf") as Font
	label.font_size = 42
	label.outline_size = 8
	label.modulate = Color("#f5f1d8")
	label.outline_modulate = Color(0.02, 0.05, 0.025, 0.96)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.0105
	label.position = label_position
	scene.add_child(label)
