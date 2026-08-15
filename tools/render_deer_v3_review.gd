extends SceneTree

const ActorScript = preload("res://scripts/eco_actor.gd")
const Factory = preload("res://scripts/low_poly_factory.gd")
const GRASS_TEXTURE = preload("res://assets/textures/terrain/grassland_ai.jpg")


class ReviewGame:
	extends Node
	var batch_mode: bool = false
	var player: EcoActor
	var world: Node
	var world_seed: int = 20260816

	func get_quality_preset() -> String:
		return "high"


func _initialize() -> void:
	_render_review.call_deferred()


func _render_review() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var game_stub := ReviewGame.new()
	scene.add_child(game_stub)
	_build_environment(scene)
	var x_positions := [-4.2, 0.0, 4.2]
	var labels := ["AI 造型·待机轮廓", "四拍步态·支撑相", "四拍步态·跨步相"]
	var phases := [0.22, 0.16, 0.68]
	for index in range(3):
		var actor: EcoActor = ActorScript.new()
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		scene.add_child(actor)
		actor.setup(game_stub, index + 1, "deer", true, Vector3(float(x_positions[index]), 0.0, 0.0), 0)
		actor.scale = Vector3.ONE * 0.82
		actor.rotation.y = -1.20 if index != 1 else -0.34
		_hide_actor_ui(actor)
		if not actor.uses_external_model or not is_instance_valid(actor.external_animation_player):
			push_error("DEER_V3_REVIEW_MISSING_EXTERNAL_MODEL")
			quit(1)
			return
		if index > 0:
			actor.velocity = Vector3(0.0, 0.0, -float(actor.data["speed"]) * 0.72)
			actor._update_visual_motion(0.016)
		actor.external_animation_player.seek(float(phases[index]), true)
		actor.external_animation_player.advance(0.0)
		_add_label(scene, labels[index], actor.position + Vector3(0.0, 3.35, 0.0), 28)
	_add_label(scene, "林鹿 V3 · AI 原创造型与物种专属步态", Vector3(0.0, 4.25, 1.5), 42)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.5
	camera.position = Vector3(0.0, 6.8, -15.5)
	scene.add_child(camera)
	camera.look_at(Vector3(0.0, 1.42, 0.0), Vector3.UP)
	camera.current = true
	for _frame in range(18):
		await process_frame
	var output_path := "res://docs/images/v49-deer-v3-anatomy-gait.png"
	var result := root.get_texture().get_image().save_png(output_path)
	if result == OK:
		print("DEER_V3_REVIEW_OK: %s" % ProjectSettings.globalize_path(output_path))
		quit(0)
	else:
		push_error("无法保存林鹿 V3 审核图：%s" % result)
		quit(1)


func _hide_actor_ui(actor: EcoActor) -> void:
	actor.health_bar_root.visible = false
	if actor.selection_ring != null:
		actor.selection_ring.visible = false
	for node_name in ["PlayerArrow", "PlayerLabel"]:
		var node := actor.get_node_or_null(node_name) as Node3D
		if node != null:
			node.visible = false


func _add_label(scene: Node3D, label_text: String, label_position: Vector3, font_size: int) -> void:
	var label := Label3D.new()
	label.text = label_text
	label.font = load("res://assets/fonts/NotoSansSC-VF.ttf") as Font
	label.font_size = font_size
	label.outline_size = 8
	label.modulate = Color("#f7f1d8")
	label.outline_modulate = Color(0.02, 0.05, 0.025, 0.96)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.0105
	label.position = label_position
	scene.add_child(label)


func _build_environment(scene: Node3D) -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#224a52")
	sky_material.sky_horizon_color = Color("#d7bd82")
	sky_material.ground_horizon_color = Color("#4d6542")
	sky_material.ground_bottom_color = Color("#111a16")
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.94
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.05
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 1.05
	environment_node.environment = environment
	scene.add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -34.0, 0.0)
	sun.light_color = Color("#ffe0ae")
	sun.light_energy = 1.20
	scene.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("#b8d9e2")
	fill.light_energy = 0.52
	fill.rotation_degrees = Vector3(55.0, 145.0, 0.0)
	scene.add_child(fill)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(22.0, 16.0)
	ground.mesh = plane
	ground.material_override = Factory.terrain_material(Color("#58633d"), Color("#8c8751"), 12.0, GRASS_TEXTURE, 7.0, 0.22)
	scene.add_child(ground)
