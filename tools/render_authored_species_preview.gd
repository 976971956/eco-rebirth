extends SceneTree

const ActorScript = preload("res://scripts/eco_actor.gd")
const Catalog = preload("res://scripts/species_catalog.gd")
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


var species_id := "fox"
var output_prefix := "res://docs/images/v55-fox-authored"
var display_scale := 0.78
var preview_failed := false


func _initialize() -> void:
	_parse_arguments()
	_render_all.call_deferred()


func _parse_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--preview-species="):
			species_id = argument.trim_prefix("--preview-species=")
		elif argument.begins_with("--preview-output-prefix="):
			output_prefix = argument.trim_prefix("--preview-output-prefix=")
		elif argument.begins_with("--preview-scale="):
			display_scale = clampf(argument.trim_prefix("--preview-scale=").to_float(), 0.18, 1.40)
	if species_id not in Catalog.ORDER:
		push_error("未知验收物种：%s" % species_id)
		quit(2)


func _render_all() -> void:
	var states_ok := await _render_states()
	var gait_ok := await _render_gait_cycle()
	if states_ok and gait_ok and not preview_failed:
		print("AUTHORED_SPECIES_PREVIEW_OK: %s / states + four-phase locomotion" % species_id)
		quit(0)
	else:
		push_error("无法完成 %s 的外部写实资产验收图" % species_id)
		quit(1)


func _render_states() -> bool:
	var scene := _build_scene()
	var game := ShowcaseGame.new()
	scene.add_child(game)
	var states := ["idle", "locomotion", "attack", "skill"]
	var times := [0.18, 0.38, 0.24, 0.36]
	var labels := ["待机呼吸", "物种步态", "普通攻击", "主动技能"]
	var positions := [-4.45, -1.48, 1.48, 4.45]
	for index in range(states.size()):
		_add_actor(scene, game, 100 + index, Vector3(positions[index], 0.0, 0.0), states[index], times[index])
		_add_label(scene, labels[index], Vector3(positions[index], 2.76, 0.0), 24)
	_add_label(scene, "%s · Hero 四态动作验收" % Catalog.display_name(species_id), Vector3(0.0, 3.74, 1.0), 38)
	return await _capture(scene, "%s-states.png" % output_prefix, 6.85)


func _render_gait_cycle() -> bool:
	var scene := _build_scene()
	var game := ShowcaseGame.new()
	scene.add_child(game)
	var positions := [-4.45, -1.48, 1.48, 4.45]
	var times := [0.00, 0.267, 0.533, 0.80]
	var labels := ["第一组触地", "膝肘收腿", "换组触地", "后膝回收"]
	for index in range(times.size()):
		_add_actor(scene, game, 200 + index, Vector3(positions[index], 0.0, 0.0), "locomotion", times[index])
		_add_label(scene, labels[index], Vector3(positions[index], 2.76, 0.0), 24)
	_add_label(scene, "%s · 四相行走关节验收" % Catalog.display_name(species_id), Vector3(0.0, 3.74, 1.0), 38)
	return await _capture(scene, "%s-gait.png" % output_prefix, 6.85)


func _add_actor(
	scene: Node3D,
	game: ShowcaseGame,
	actor_id: int,
	actor_position: Vector3,
	action: String,
	seek_time: float
) -> void:
	var actor: EcoActor = ActorScript.new()
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	scene.add_child(actor)
	actor.setup(game, actor_id, species_id, true, Vector3.ZERO, 0)
	actor.position = actor_position
	actor.scale = Vector3.ONE * display_scale
	actor.rotation.y = 2.09
	_hide_actor_ui(actor)
	if not is_instance_valid(actor.external_animation_player):
		preview_failed = true
		push_error("%s 没有绑定外部 AnimationPlayer" % species_id)
		return
	if not actor.external_animation_player.has_animation(action):
		preview_failed = true
		push_error("%s 缺少动作 %s" % [species_id, action])
		return
	actor.external_animation_player.play(action)
	actor.external_animation_player.seek(seek_time, true)
	actor.external_animation_player.advance(0.0)


func _build_scene() -> Node3D:
	var scene := Node3D.new()
	root.add_child(scene)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#183038")
	sky_material.sky_horizon_color = Color("#c7b389")
	sky_material.ground_horizon_color = Color("#536046")
	sky_material.ground_bottom_color = Color("#111a18")
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.92
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.04
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 1.03
	environment_node.environment = environment
	scene.add_child(environment_node)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-48.0, -30.0, 0.0)
	key_light.light_color = Color("#ffe0ae")
	key_light.light_energy = 1.30
	scene.add_child(key_light)
	var rim_light := DirectionalLight3D.new()
	rim_light.rotation_degrees = Vector3(52.0, 148.0, 0.0)
	rim_light.light_color = Color("#afd9e4")
	rim_light.light_energy = 0.60
	scene.add_child(rim_light)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30.0, 20.0)
	ground.mesh = plane
	ground.material_override = Factory.terrain_material(Color("#4c5a3c"), Color("#8b8154"), 12.0, GRASS_TEXTURE, 7.0, 0.20)
	scene.add_child(ground)
	return scene


func _capture(scene: Node3D, output_path: String, camera_size: float) -> bool:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = camera_size
	camera.position = Vector3(0.0, 8.9, -18.2)
	scene.add_child(camera)
	camera.look_at(Vector3(0.0, 1.30, 0.0), Vector3.UP)
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
