extends SceneTree

const ActorScript = preload("res://scripts/eco_actor.gd")
const Catalog = preload("res://scripts/species_catalog.gd")


class ProbeGame:
	extends Node
	var batch_mode: bool = false
	var player: EcoActor
	var world: Node
	var world_seed: int = 20260815

	func get_quality_preset() -> String:
		return "high"


func _initialize() -> void:
	_render_probe.call_deferred()


func _render_probe() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var game_stub := ProbeGame.new()
	scene.add_child(game_stub)
	_build_environment(scene)
	var species_list: Array[String] = ["rabbit", "wolf", "deer", "bear"]
	var x_positions := [5.4, 1.8, -1.8, -5.4]
	var display_scales := [0.98, 0.76, 0.59, 0.53]
	for row in range(2):
		for species_index in range(species_list.size()):
			var species_id: String = species_list[species_index]
			var actor: EcoActor = ActorScript.new()
			actor.process_mode = Node.PROCESS_MODE_DISABLED
			scene.add_child(actor)
			actor.setup(
				game_stub,
				100 + row * species_list.size() + species_index,
				species_id,
				true,
				Vector3(float(x_positions[species_index]), 0.0, 2.5 if row == 0 else -2.5),
				0
			)
			actor.scale = Vector3.ONE * float(display_scales[species_index])
			actor.rotation.y = 0.42
			_hide_actor_ui(actor)
			if not actor.uses_external_model or not is_instance_valid(actor.external_animation_player):
				push_error("BAKED_ANIMATION_PROBE_MISSING: %s" % species_id)
				quit(1)
				return
			if row == 1:
				actor.velocity = Vector3(0.0, 0.0, -float(actor.data["speed"]) * 0.78)
				actor._update_visual_motion(0.016)
				if actor.external_baked_animation != "locomotion":
					push_error("BAKED_ANIMATION_PROBE_RUNTIME_ROUTE_FAILED: %s" % species_id)
					quit(1)
					return
				actor.external_animation_player.seek(0.42, true)
				actor.external_animation_player.advance(0.0)
			else:
				actor.external_animation_player.seek(0.28, true)
				actor.external_animation_player.advance(0.0)
			_add_label(scene, Catalog.display_name(species_id), actor.position + Vector3(0.0, 3.25, 0.0))
	_add_label(scene, "V2 完整体表·待机", Vector3(0.0, 4.15, 2.5), 46)
	_add_label(scene, "EcoActor 实际路径·烘焙奔跑", Vector3(0.0, 4.15, -2.5), 46)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.4
	camera.position = Vector3(0.0, 12.8, -17.8)
	scene.add_child(camera)
	camera.look_at(Vector3(0.0, 1.2, 0.0), Vector3.UP)
	camera.current = true
	for _frame in range(12):
		await process_frame
	var output_path := "res://docs/images/v48-v2-runtime-baked-animation.png"
	var result := root.get_texture().get_image().save_png(output_path)
	if result == OK:
		print("V2_BAKED_ANIMATION_PROBE_OK: %s" % ProjectSettings.globalize_path(output_path))
		quit(0)
	else:
		push_error("无法保存 V2 烘焙动作探针：%s" % result)
		quit(1)


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


func _add_label(scene: Node3D, label_text: String, label_position: Vector3, font_size: int = 34) -> void:
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


func _build_environment(scene: Node3D) -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#39565d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#d9e5dc")
	environment.ambient_light_energy = 0.92
	environment_node.environment = environment
	scene.add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	sun.light_color = Color("#ffe0ae")
	sun.light_energy = 1.1
	scene.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(24.0, 18.0)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#526b43")
	material.roughness = 0.9
	ground.material_override = material
	scene.add_child(ground)
