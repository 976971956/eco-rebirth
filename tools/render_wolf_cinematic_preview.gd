extends SceneTree

const ActorScript = preload("res://scripts/eco_actor.gd")
const Factory = preload("res://scripts/low_poly_factory.gd")
const GRASS_TEXTURE = preload("res://assets/textures/terrain/grassland_ai.jpg")


class ShowcaseGame:
	extends Node
	var batch_mode := false
	var player: EcoActor
	var world: Node
	var world_seed := 20260816

	func get_quality_preset() -> String:
		return "high"


func _initialize() -> void:
	_render_all.call_deferred()


func _render_all() -> void:
	var anatomy_ok := await _render_anatomy()
	var motion_ok := await _render_motion()
	var gait_ok := await _render_gait_cycle()
	var closeup_ok := await _render_closeup()
	if anatomy_ok and motion_ok and gait_ok and closeup_ok:
		print("WOLF_CINEMATIC_PREVIEW_OK: closeup + hero/mobile + articulated four-phase trot + bite")
		quit(0)
	else:
		push_error("无法保存灰狼影视化样板验收图")
		quit(1)


func _render_anatomy() -> bool:
	var scene := _build_scene()
	var game := ShowcaseGame.new()
	scene.add_child(game)
	_add_wolf(scene, game, 1, true, Vector3(-2.65, 0.0, 0.0), "idle", 0.16, 0.88)
	_add_wolf(scene, game, 2, false, Vector3(2.65, 0.0, 0.0), "idle", 0.16, 0.88)
	_add_label(scene, "Hero · 20,348 面 · 32 骨骼", Vector3(-2.65, 3.10, 0.0), 25)
	_add_label(scene, "Mobile · 5,358 面 · 32 骨骼", Vector3(2.65, 3.10, 0.0), 25)
	_add_label(scene, "灰狼影视化样板 · 同骨架双档运行资产", Vector3(0.0, 4.05, 1.2), 40)
	return await _capture(scene, "res://docs/images/v51-wolf-cinematic-anatomy.png", 7.25)


func _render_motion() -> bool:
	var scene := _build_scene()
	var game := ShowcaseGame.new()
	scene.add_child(game)
	_add_wolf(scene, game, 11, true, Vector3(-3.85, 0.0, 0.0), "idle", 0.16, 0.70)
	_add_wolf(scene, game, 12, true, Vector3(0.0, 0.0, 0.0), "locomotion", 0.38, 0.70)
	_add_wolf(scene, game, 13, true, Vector3(3.85, 0.0, 0.0), "attack", 0.24, 0.70)
	_add_label(scene, "待机呼吸", Vector3(-3.85, 3.05, 0.0), 28)
	_add_label(scene, "对角小跑", Vector3(0.0, 3.05, 0.0), 28)
	_add_label(scene, "张颌扑咬", Vector3(3.85, 3.05, 0.0), 28)
	_add_label(scene, "灰狼 Hero · 真实 EcoActor 动画路径", Vector3(0.0, 4.05, 1.2), 40)
	return await _capture(scene, "res://docs/images/v51-wolf-cinematic-motion.png", 7.65)


func _render_gait_cycle() -> bool:
	var scene := _build_scene()
	var game := ShowcaseGame.new()
	scene.add_child(game)
	var positions := [-4.65, -1.55, 1.55, 4.65]
	var times := [0.0, 0.267, 0.533, 0.8]
	var labels := ["对角触地", "前腕屈曲", "换组触地", "后膝收腿"]
	for index in range(4):
		_add_wolf(scene, game, 31 + index, true, Vector3(positions[index], 0.0, 0.0), "locomotion", times[index], 0.62, 2.09)
		_add_label(scene, labels[index], Vector3(positions[index], 2.92, 0.0), 24)
	_add_label(scene, "灰狼屈膝步态验收 · 前腕与后膝独立弯曲 · 对角小跑", Vector3(0.0, 3.92, 1.2), 38)
	return await _capture(scene, "res://docs/images/v52-wolf-balanced-gait.png", 7.35)


func _render_closeup() -> bool:
	var scene := _build_scene()
	var game := ShowcaseGame.new()
	scene.add_child(game)
	_add_wolf(scene, game, 21, true, Vector3(0.0, 0.0, 0.0), "idle", 0.16, 1.18)
	_add_label(scene, "灰狼 Hero 近景 · AI 毛色 · PBR 法线 · 可张合下颌", Vector3(0.0, 3.78, 0.7), 34)
	return await _capture(scene, "res://docs/images/v51-wolf-cinematic-closeup.png", 5.75)


func _build_scene() -> Node3D:
	var scene := Node3D.new()
	root.add_child(scene)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#17282f")
	sky_material.sky_horizon_color = Color("#b9a77f")
	sky_material.ground_horizon_color = Color("#526053")
	sky_material.ground_bottom_color = Color("#111a18")
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.90
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.04
	environment.adjustment_contrast = 1.10
	environment.adjustment_saturation = 1.02
	environment_node.environment = environment
	scene.add_child(environment_node)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	key_light.light_color = Color("#ffe0ad")
	key_light.light_energy = 1.35
	scene.add_child(key_light)
	var rim_light := DirectionalLight3D.new()
	rim_light.rotation_degrees = Vector3(42.0, 145.0, 0.0)
	rim_light.light_color = Color("#a7d5e3")
	rim_light.light_energy = 0.68
	scene.add_child(rim_light)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(26.0, 18.0)
	ground.mesh = plane
	ground.material_override = Factory.terrain_material(Color("#4a563c"), Color("#827a50"), 12.0, GRASS_TEXTURE, 7.0, 0.18)
	scene.add_child(ground)
	return scene


func _add_wolf(
	scene: Node3D,
	game: ShowcaseGame,
	actor_id: int,
	player_controlled: bool,
	position: Vector3,
	animation_name: String,
	seek_time: float,
	display_scale: float,
	yaw: float = 0.52
) -> void:
	var actor: EcoActor = ActorScript.new()
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	scene.add_child(actor)
	actor.setup(game, actor_id, "wolf", player_controlled, Vector3.ZERO, 0)
	actor.position = position
	actor.scale = Vector3.ONE * display_scale
	actor.rotation.y = yaw
	_hide_actor_ui(actor)
	if not is_instance_valid(actor.external_animation_player):
		push_error("灰狼没有绑定导入动画")
		return
	if not actor.external_animation_player.has_animation(animation_name):
		push_error("灰狼缺少动作 %s" % animation_name)
		return
	actor.external_animation_player.play(animation_name)
	actor.external_animation_player.seek(seek_time, true)


func _capture(scene: Node3D, output_path: String, camera_size: float) -> bool:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = camera_size
	camera.position = Vector3(0.0, 8.8, -17.8)
	scene.add_child(camera)
	camera.look_at(Vector3(0.0, 1.45, 0.0), Vector3.UP)
	camera.current = true
	for _frame in range(24):
		await process_frame
	var result := root.get_texture().get_image().save_png(output_path)
	scene.queue_free()
	for _frame in range(4):
		await process_frame
	return result == OK


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
